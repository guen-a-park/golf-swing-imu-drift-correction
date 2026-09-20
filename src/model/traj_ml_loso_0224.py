# -*- coding: utf-8 -*-
"""
Impact-only anchor/trajectory learner
- Train: per-(subject, club) first K trials
- Val  : specific (subject, club, [start..end]) only
"""

import os, time
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

import numpy as np
import scipy.io as sio
import pandas as pd
import matplotlib.pyplot as plt

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import argparse

# ========================
# Config
# ========================
USE_VAL_DURING_TRAIN = False

MAT_PATH      = "./swingData_2508_forML.mat"
DEVICE        = 'cuda' if torch.cuda.is_available() else 'cpu'
BASE_LR       = 1e-3
WARMUP_EPOCHS = 5
EPOCHS        = 100
BATCH_SIZE    = 16
LAMBDA_IMP    = 0  # impact anchor loss weight
LAMBDA_TRAJ   = 1  # trajectory loss weight
USE_EARLY_STOP= True
FEAT_MODE     = 'acc+gyro'  # 'pos' | 'vel' | 'acc' | 'pos+vel' | 'pos+vel+acc' | 'acc+gyro'
output_dir    = "runs_1119_acc450710_3"
os.makedirs(output_dir, exist_ok=True)

# video version
INPUT_SPEC = {
    "acc": ("apdm", slice(0,3)),
    "vel": ("vel_integration", slice(0,3)),
    "pos": ("traj_integration", slice(0,3)),
    "gyro": ("apdm", slice(3,6)),
}
# imuphase
FIELD_MAP = {
    "imp_idx":    "imp_imu1",
    "anchor_imp": ("rel", slice(0,3)),
    "traj_gt":    ("traj_integration", slice(9,12)),
}
# markerphase
# FIELD_MAP = {
#     "imp_idx":    "imp",
#     "anchor_imp": ("rel", slice(0,3)),
#     "traj_gt":    ("traj_integration", slice(9,12)),
# }

# # orientation0 version
# INPUT_SPEC = {
#     "acc": ("apdm", slice(0,3)),
#     "vel": ("vel_integration", slice(0,3)),
#     "pos": ("traj_integration", slice(0,3)),
#     "gyro": ("apdm", slice(3,6)),
# }
# FIELD_MAP = {
#     "imp_idx":    "imp",
#     "anchor_imp": ("rel", slice(3,6)),
#     "traj_gt":    ("traj_integration", slice(12,15)),
# }

# raw imu version
# INPUT_SPEC = {
#     "acc": ("apdm", slice(6,9)),
#     "vel": ("vel_integration", slice(0,3)),
#     "pos": ("traj_integration", slice(0,3)),
#     "gyro": ("apdm", slice(9,12)),
# }
# FIELD_MAP = {
#     "imp_idx":    "imp",
#     "anchor_imp": ("rel", slice(3,6)),
#     "traj_gt":    ("traj_integration", slice(12,15)),
# }

# TIME_CROP = dict(
#     mode='fixed',
#     t_slice=slice(320, 850),
#     pre=60, post=10, step=1
# )

TIME_CROP = dict(
    mode='fixed',
    t_slice=slice(400, 800),
    pre=60, post=10, step=1
)


# ========================
# data diagnostic function for debugging (not used in main at present)
# ========================
def diagnose_data_availability(mat_path, time_crop_cfg=None):
    """
    check the data length of each subject/club/trial and
    diagnose whether the time_crop range can be applied
    """
    print("\n" + "="*80)
    print("DATA AVAILABILITY DIAGNOSIS")
    print("="*80)
    
    md = sio.loadmat(mat_path, struct_as_record=True, squeeze_me=False)
    SD = md['swingData_2508']
    
    if time_crop_cfg and time_crop_cfg.get('mode') == 'fixed':
        t_slice = time_crop_cfg.get('t_slice', slice(None))
        crop_start = t_slice.start if t_slice.start else 0
        crop_end = t_slice.stop if t_slice.stop else float('inf')
        print(f"Time crop requested: [{crop_start}, {crop_end})")
    else:
        crop_start = 0
        crop_end = float('inf')
        print("No time crop requested")
    
    print("\n" + "-"*80)
    
    total_trials = 0
    valid_trials = 0
    too_short_trials = []
    
    for si in range(SD.size):
        subj = _mat_get(SD, si)
        clubN = _field(subj, 'clubN')
        
        print(f"\nSubject {si+1}:")
        
        for ci in range(clubN.size):
            club = _mat_get(clubN, ci)
            trialN = _field(club, 'trialN')
            
            print(f"  Club {ci+1}: {trialN.size} trials")
            
            for ti in range(trialN.size):
                tr = _mat_get(trialN, ti)
                total_trials += 1
                
                try:
                    pos_field = INPUT_SPEC['pos'][0]
                    pos_data = _field(tr, pos_field)
                    pos_len = pos_data.shape[0] if hasattr(pos_data, 'shape') else 0
                    
                    vel_field = INPUT_SPEC['vel'][0]
                    vel_data = _field(tr, vel_field)
                    vel_len = vel_data.shape[0] if hasattr(vel_data, 'shape') else 0
                    
                    acc_field = INPUT_SPEC['acc'][0]
                    acc_data = _field(tr, acc_field)
                    acc_len = acc_data.shape[0] if hasattr(acc_data, 'shape') else 0
                    
                    min_len = min([l for l in [pos_len, vel_len, acc_len] if l > 0])
                    
                    if min_len < crop_end:
                        too_short_trials.append({
                            'subject': si+1,
                            'club': ci+1,
                            'trial': ti+1,
                            'data_length': min_len,
                            'crop_end': crop_end,
                            'shortage': crop_end - min_len
                        })
                        print(f"    Trial {ti+1}: Too short (length={min_len}, need={crop_end})")
                    else:
                        valid_trials += 1
                        if ti < 5:
                            print(f"    Trial {ti+1}: OK (length={min_len})")
                    
                except Exception as e:
                    print(f"    Trial {ti+1}: Error reading data: {e}")
    
    print("\n" + "-"*80)
    print(f"SUMMARY:")
    print(f"  Total trials: {total_trials}")
    print(f"  Valid trials: {valid_trials}")
    print(f"  Too short trials: {len(too_short_trials)}")
    
    if too_short_trials:
        print(f"\n  Details of too short trials:")
        for item in too_short_trials[:10]:
            print(f"    S{item['subject']}/C{item['club']}/T{item['trial']}: "
                  f"length={item['data_length']}, shortage={item['shortage']}")
        if len(too_short_trials) > 10:
            print(f"    ... and {len(too_short_trials)-10} more")
    
    print("="*80 + "\n")
    
    return valid_trials, too_short_trials

# ========================
# Utils / losses
# ========================
def ensure_dir(p): os.makedirs(p, exist_ok=True)
def _np(x):  return np.asarray(x)
def _f32(x): return np.asarray(x, dtype=np.float32)

sl1_mean = nn.SmoothL1Loss(reduction='mean')
sl1_none = nn.SmoothL1Loss(reduction='none')

# ========================
# Standardization helpers
# ========================
def compute_input_stats(samples):
    Xs = [s["X"].reshape(-1, s["X"].shape[-1]) for s in samples]
    Xcat = np.concatenate(Xs, axis=0)
    m = Xcat.mean(axis=0); s = Xcat.std(axis=0); s[s < 1e-6] = 1.0
    return m.astype(np.float32), s.astype(np.float32)

def apply_input_norm(samples, mean, std):
    for s in samples:
        if s["X"].shape[1] != len(mean):
            raise ValueError(
                f"Dimension mismatch in apply_input_norm: "
                f"X has {s['X'].shape[1]} features, but mean/std have {len(mean)} features"
            )
        s["X"] = ((s["X"] - mean) / std).astype(np.float32)

def compute_anchor_stats(samples):
    A = np.stack([s["imp_p"] for s in samples], axis=0)
    m = A.mean(axis=0); s = A.std(axis=0); s[s < 1e-6] = 1.0
    return m.astype(np.float32), s.astype(np.float32)

def zscore_anchor_for_loss(pred_imp, true_imp, a_mean, a_std):
    if not torch.is_tensor(a_mean): a_mean = torch.as_tensor(a_mean, device=pred_imp.device, dtype=pred_imp.dtype)
    if not torch.is_tensor(a_std):  a_std  = torch.as_tensor(a_std,  device=pred_imp.device, dtype=pred_imp.dtype)
    return (pred_imp - a_mean) / a_std, (true_imp - a_mean) / a_std

# ========================
# Time crop
# ========================
def apply_time_crop(pos, vel, acc, gyro, traj, mask, imp_idx, cfg, debug_info=None):
    if cfg is None or cfg.get('mode') in (None, 'none'):
        return pos, vel, acc, gyro, traj, mask, imp_idx, True

    T = pos.shape[0]; step = int(cfg.get('step', 1))

    if cfg['mode'] == 'fixed':
        sl = cfg.get('t_slice', slice(None))
        sl = slice(sl.start, sl.stop, step if sl.step is None else sl.step)
        t0 = 0 if sl.start is None else max(0, sl.start)
        t1 = T if sl.stop  is None else min(T, sl.stop)

        if debug_info and T < t1:
            print(f"    [DEBUG] {debug_info}: Data too short. T={T}, crop=[{t0},{t1})")

        if t0 >= t1:
            return pos, vel, acc, gyro, traj, mask, imp_idx, False

        step_eff = sl.step or 1
        slicer = slice(t0, t1, step_eff)

        def cut(x): return None if x is None else x[slicer]
        pos, vel, acc, gyro, traj, mask = cut(pos), cut(vel), cut(acc), cut(gyro), cut(traj), cut(mask)

        T_new = pos.shape[0] if pos is not None else (traj.shape[0] if traj is not None else T)
        if T_new <= 0:
            return pos, vel, acc, gyro, traj, mask, imp_idx, False

        new_imp_raw = (imp_idx - t0) // step_eff
        new_imp = max(0, min(T_new - 1, new_imp_raw))

    elif cfg['mode'] == 'around_imp':
        pre = int(cfg.get('pre', 0)); post = int(cfg.get('post', 0))
        t0 = max(0, imp_idx - pre); t1 = min(T, imp_idx + post + 1)
        if t0 >= t1:
            return pos, vel, acc, gyro, traj, mask, imp_idx, False
        step_eff = step
        new_imp = (imp_idx - t0) // step_eff
        slicer = slice(t0, t1, step_eff)

        def cut(x): return None if x is None else x[slicer]
        pos, vel, acc, gyro, traj, mask = cut(pos), cut(vel), cut(acc), cut(gyro), cut(traj), cut(mask)

        T_new = pos.shape[0] if pos is not None else (traj.shape[0] if traj is not None else T)
        if T_new <= 0:
            return pos, vel, acc, gyro, traj, mask, imp_idx, False
        new_imp = max(0, min(T_new - 1, new_imp))

    else:
        return pos, vel, acc, gyro, traj, mask, imp_idx, True

    return pos, vel, acc, gyro, traj, mask, int(new_imp), True

# ========================
# MAT helpers
# ========================
def _mat_get(arr, i):
    arr = np.asarray(arr)
    if arr.dtype == object:
        return arr.flat[i]
    if arr.dtype.names is not None:
        return arr.reshape(-1)[i]
    return arr.reshape(-1)[i]

def _field(tr, key):
    if isinstance(tr, np.void):
        return np.asarray(tr[key]).squeeze()

    if hasattr(tr, key):
        return np.asarray(getattr(tr, key)).squeeze()

    if isinstance(tr, dict) and key in tr:
        return np.asarray(tr[key]).squeeze()

    if isinstance(tr, np.ndarray):
        if tr.dtype == object and tr.size == 1:
            return _field(tr.item(), key)
        if tr.dtype.names is not None and tr.size == 1:
            return np.asarray(tr.reshape(1)[0][key]).squeeze()

    raise KeyError(f"field '{key}' not found in type {type(tr)}")

def _determine_T(tr, INPUT_SPEC):
    T_cands = []
    for k in ['pos','vel','acc','gyro']:
        spec = INPUT_SPEC.get(k)
        if spec is None: 
            continue
        field_name = spec[0]
        arr = _field(tr, field_name)
        arr = np.asarray(arr)
        if arr.ndim == 0 or arr.size == 0:
            continue
        T_cands.append(arr.shape[0])
    return int(max(T_cands)) if T_cands else 0


def _build_one_sample(tr, INPUT_SPEC, FIELD_MAP, imp_idx, T, feat_mode, time_crop_cfg, debug_id=None):
    def fetch_T2(field, cols, T_target=None):
        raw = _field(tr, field)
        X = np.asarray(raw, dtype=np.float32)
        if X.ndim == 1: 
            X = X[:, None]
        if cols is not None: 
            X = X[:, cols]
        
        if X.shape[1] < 3:
            pad = np.zeros((X.shape[0], 3 - X.shape[1]), np.float32)
            X = np.concatenate([X, pad], axis=1)
        elif X.shape[1] > 3:
            X = X[:, :3]
        
        if (T_target is not None) and (X.shape[0] != T_target):
            if X.shape[0] > T_target: 
                X = X[:T_target]
            else: 
                X = np.vstack([X, np.zeros((T_target - X.shape[0], 3), np.float32)])
        return X

    pos = fetch_T2(*INPUT_SPEC['pos'], T) if INPUT_SPEC.get('pos') else None
    vel = fetch_T2(*INPUT_SPEC['vel'], T) if INPUT_SPEC.get('vel') else None
    acc = fetch_T2(*INPUT_SPEC['acc'], T) if INPUT_SPEC.get('acc') else None
    gyro = fetch_T2(*INPUT_SPEC['gyro'], T) if INPUT_SPEC.get('gyro') else None

    traj_spec = FIELD_MAP.get('traj_gt', None)
    if traj_spec is None:
        traj = np.zeros((T,3), np.float32); mask = np.zeros((T,1), np.float32)
    else:
        traj = fetch_T2(traj_spec[0], traj_spec[1], T) if isinstance(traj_spec, tuple) else fetch_T2(traj_spec, slice(0,3), T)
        mask = np.ones((T,1), np.float32)

    def _get_anchor_vec(tr, anchor_spec):
        if anchor_spec is None:
            return None
        if isinstance(anchor_spec, str):
            arr = _np(_field(tr, anchor_spec)).reshape(-1)
            return _f32(arr[-3:]) if arr.size >= 3 else None
        if isinstance(anchor_spec, tuple) and len(anchor_spec) == 2:
            field, cols = anchor_spec
            arr = _np(_field(tr, field)).reshape(-1)
            if isinstance(cols, slice):
                sel = arr[cols]
            elif isinstance(cols, (list, tuple, np.ndarray)):
                sel = arr[list(cols)]
            elif isinstance(cols, (int, np.integer)):
                sel = arr[[int(cols)]]
            else:
                sel = arr
            return _f32(sel).reshape(-1) if sel.size == 3 else None
        return None

    imp_p = _get_anchor_vec(tr, FIELD_MAP.get('anchor_imp'))
    if imp_p is None or imp_p.size != 3:
        imp_p = traj[imp_idx] if mask[imp_idx, 0] > 0.5 else np.zeros(2, np.float32)

    if pos is None: pos = np.zeros((T,3), np.float32)

    if time_crop_cfg is not None:
        pos, vel, acc, gyro, traj, mask, imp_idx_new, keep = apply_time_crop(
            pos, vel, acc, gyro, traj, mask, imp_idx, time_crop_cfg, debug_info=debug_id
        )
        if not keep: 
            return None
        imp_idx = imp_idx_new; T = pos.shape[0]

    if feat_mode == 'pos':
        X = pos
    elif feat_mode == 'acc+gyro':
        G = gyro if gyro is not None else np.zeros_like(acc)
        A = acc if acc is not None else np.zeros_like(pos)
        X = np.concatenate([A, G], axis=-1)
    elif feat_mode == 'vel':
        X = vel
    elif feat_mode == 'acc':
        X = acc
    elif feat_mode == 'pos+vel':
        V = vel if vel is not None else np.zeros_like(pos)
        X = np.concatenate([pos, V], axis=-1)
    else:
        V = vel if vel is not None else np.zeros_like(pos)
        A = acc if acc is not None else np.zeros_like(pos)
        X = np.concatenate([pos, V, A], axis=-1)

    return {
        'X':   X.astype(np.float32),
        'traj': traj.astype(np.float32),
        'mask': mask.astype(np.float32),
        'imp_p': imp_p.astype(np.float32),
        'imp_idx': int(imp_idx),
        'T': T,
    }

# ---------- (1) Train: first K per (subject, club) ----------
def build_train_firstk(
    mat_path: str,
    INPUT_SPEC: dict,
    FIELD_MAP: dict,
    subj_sel: Optional[List[int]],
    club_sel: Optional[List[int]],
    first_k: int,
    ban_triples: Optional[List[Tuple[int,int,int]]] = None,
    feat_mode: Optional[str] = None,
    time_crop_cfg: Optional[dict] = None,
) -> List[Dict[str,Any]]:

    if feat_mode is None:
        feat_mode = FEAT_MODE

    md = sio.loadmat(mat_path, struct_as_record=True, squeeze_me=False)
    assert 'swingData_2508' in md, "MAT variable swingData_2508 not found."
    SD = md['swingData_2508']

    def to0(lst):
        if lst is None: return None
        return sorted(set([int(x)-1 for x in lst if int(x) > 0]))

    subj_idx = to0(subj_sel) or list(range(SD.size))
    ban = set()
    if ban_triples:
        for s,c,t in ban_triples: ban.add((s-1, c-1, t-1))

    samples = []
    skipped_count = 0
    for si in subj_idx:
        subj = _mat_get(SD, si)
        clubN = _field(subj, 'clubN'); C = clubN.size
        club_idx = to0(club_sel) or list(range(C))
        for ci in club_idx:
            club = _mat_get(clubN, ci)
            trialN = _field(club, 'trialN'); Tn = trialN.size
            if Tn == 0: continue
            trials = [ti for ti in range(min(first_k, Tn)) if (si,ci,ti) not in ban]
            for ti in trials:
                tr = _mat_get(trialN, ti)
                T = _determine_T(tr, INPUT_SPEC); 
                if T <= 0: continue
                imp_idx_raw = _field(tr, FIELD_MAP['imp_idx'])
                if _np(imp_idx_raw).size == 0: continue
                imp_idx = int(np.clip(int(_np(imp_idx_raw).reshape(-1)[0]) - 1, 0, T-1))
                
                debug_id = f"S{si+1}/C{ci+1}/T{ti+1}"
                s = _build_one_sample(tr, INPUT_SPEC, FIELD_MAP, imp_idx, T, feat_mode, time_crop_cfg, debug_id)
                if s is not None: 
                    samples.append(s)
                else:
                    skipped_count += 1
                    
    if skipped_count > 0:
        print(f"  [INFO] Skipped {skipped_count} samples due to time crop constraints")
                    
    return samples

# ---------- (2) Val: specific (subject, club, [start..end]) list ----------
def build_val_from_specs(
    mat_path: str,
    INPUT_SPEC: dict,
    FIELD_MAP: dict,
    val_specs: List[Dict[str,int]],
    ban_triples: Optional[List[Tuple[int,int,int]]] = None,
    feat_mode: Optional[str] = None,
    time_crop_cfg: Optional[dict] = None,
) -> List[Dict[str,Any]]:

    if feat_mode is None:
        feat_mode = FEAT_MODE

    md = sio.loadmat(mat_path, struct_as_record=True, squeeze_me=False)
    assert 'swingData_2508' in md, "MAT variable swingData_2508 not found."
    SD = md['swingData_2508']

    ban = set()
    if ban_triples:
        for s,c,t in ban_triples: ban.add((s-1, c-1, t-1))

    samples = []
    skipped_count = 0
    for spec in val_specs:
        si = int(spec["subj"]) - 1
        ci = int(spec["club"]) - 1
        st1 = int(spec["start"]); ed1 = int(spec["end"])
        assert st1 >= 1 and ed1 >= st1, "start/end(1-based) range error"

        subj  = _mat_get(SD, si)
        clubN = _field(subj, 'clubN')
        club  = _mat_get(clubN, ci)
        trialN = _field(club, 'trialN'); Tn = trialN.size
        if Tn == 0: continue

        a = max(0, st1-1); b = min(Tn-1, ed1-1)
        for ti in range(a, b+1):
            if (si,ci,ti) in ban: continue
            tr = _mat_get(trialN, ti)
            T = _determine_T(tr, INPUT_SPEC)
            if T <= 0: continue
            imp_idx_raw = _field(tr, FIELD_MAP['imp_idx'])
            if _np(imp_idx_raw).size == 0: continue
            imp_idx = int(np.clip(int(_np(imp_idx_raw).reshape(-1)[0]) - 1, 0, T-1))
            
            debug_id = f"S{si+1}/C{ci+1}/T{ti+1}"
            s = _build_one_sample(tr, INPUT_SPEC, FIELD_MAP, imp_idx, T, feat_mode, time_crop_cfg, debug_id)
            if s is not None: 
                samples.append(s)
            else:
                skipped_count += 1
                
    if skipped_count > 0:
        print(f"  [INFO] Skipped {skipped_count} samples due to time crop constraints")
        
    return samples

# ========================
# variability evaluation
# ========================
@torch.no_grad()
def std_ratio_report(model, loader, device='cpu', tag=''):
    model.eval()
    preds, trues = [], []
    for b in loader:
        X = b["X"].to(device)
        idx = torch.tensor(b["imp_idx"], device=device, dtype=torch.long)
        imp_p = b["imp_p"].to(device)
        Y, _ = model(X)
        pred_i = Y[torch.arange(X.size(0), device=device), idx]
        preds.append(pred_i.detach().cpu().numpy())
        trues.append(imp_p.detach().cpu().numpy())

    P = np.vstack(preds)
    T = np.vstack(trues)
    pred_std = P.std(0)
    true_std = T.std(0)
    ratio = pred_std / np.maximum(true_std, 1e-6)

    msg = f"[STD{(' ' + tag) if tag else ''}] pred_std={np.round(pred_std,3)} | true_std={np.round(true_std,3)} | ratio={np.round(ratio,3)}"
    print(msg)
    return pred_std, true_std, ratio


# ========================
# Dataset / collate
# ========================
class ImpactDataset(Dataset):
    def __init__(self, samples: List[Dict[str, Any]]): self.S = samples
    def __len__(self): return len(self.S)
    def __getitem__(self, i):
        s = self.S[i]
        return {
            "X": _f32(s["X"]),
            "traj": s["traj"],
            "mask": s["mask"],
            "imp_p": s["imp_p"],
            "imp_idx": s["imp_idx"],
            "T": s["T"],
        }

def collate_pad(batch):
    Tm = max(b["T"] for b in batch); B = len(batch)
    Cx = batch[0]["X"].shape[1]
    X = torch.zeros(B, Tm, Cx); traj = torch.zeros(B, Tm, 3); mask = torch.zeros(B, Tm, 1)
    imp_p=[]; imp_idx=[]
    for i,b in enumerate(batch):
        T = b["T"]
        X[i,:T]    = torch.from_numpy(b["X"])
        traj[i,:T] = torch.from_numpy(b["traj"])
        mask[i,:T] = torch.from_numpy(b["mask"])
        imp_p.append(torch.from_numpy(b["imp_p"]))
        imp_idx.append(b["imp_idx"])
    imp_p = torch.stack(imp_p,0)
    lengths = torch.tensor([b["T"] for b in batch], dtype=torch.long)
    return {"X":X, "traj":traj, "mask":mask,
            "imp_p":imp_p, "imp_idx":imp_idx, "lengths":lengths}

# ========================
# Model
# ========================
class BiLSTMTraj(nn.Module):
    def __init__(self, in_dim, hidden=128, layers=2, bidir=True,
                 lstm_dropout=0.2, input_dropout=0.05, use_layernorm=True):
        super().__init__()
        self.ln = nn.LayerNorm(in_dim) if use_layernorm else nn.Identity()
        self.in_drop = nn.Dropout(input_dropout) if input_dropout > 0 else nn.Identity()
        self.lstm = nn.LSTM(in_dim, hidden, num_layers=layers,
                            batch_first=True, bidirectional=bidir,
                            dropout=(lstm_dropout if layers > 1 else 0.0))
        d = hidden * (2 if bidir else 1)
        self.head = nn.Sequential(nn.Linear(d, d), nn.ReLU(), nn.Linear(d, 3))
    def forward(self, X):
        X = self.ln(X); X = self.in_drop(X)
        H,_ = self.lstm(X)
        pos_hat = self.head(H)
        return pos_hat, H

# ========================
# Train / Eval
# ========================
def train_epoch(model, loader, optim, device, a_mean, a_std):
    model.train(); tot=0; n=0
    for b in loader:
        X=b["X"].to(device); traj=b["traj"].to(device); mask=b["mask"].to(device)
        imp_p=b["imp_p"].to(device)

        optim.zero_grad()
        pos_hat,_ = model(X)
        B,T,_ = pos_hat.shape
        idx_i = torch.tensor(b["imp_idx"], device=device, dtype=torch.long)
        pred_i = pos_hat[torch.arange(B, device=device), idx_i]

        # Impact loss
        if LAMBDA_IMP > 0:
            pred_z, true_z = zscore_anchor_for_loss(pred_i, imp_p, a_mean, a_std)
            loss_imp = sl1_mean(pred_z, true_z)
        else:
            loss_imp = torch.tensor(0., device=device)

        # Trajectory loss
        if LAMBDA_TRAJ > 0:
            per_elem = sl1_none(pos_hat, traj)
            w = mask.expand_as(per_elem)
            valid = w.sum()
            loss_traj = (per_elem * w).sum() / valid.clamp_min(1.0)
        else:
            loss_traj = torch.tensor(0., device=device)

        # warn if both are 0
        if LAMBDA_IMP == 0 and LAMBDA_TRAJ == 0:
            raise ValueError("training is impossible when both LAMBDA_IMP and LAMBDA_TRAJ are 0.")

        loss = LAMBDA_IMP * loss_imp + LAMBDA_TRAJ * loss_traj
        loss.backward(); nn.utils.clip_grad_norm_(model.parameters(), 1.0); optim.step()
        tot += loss.item() * B; n += B
    return tot/max(1,n)

@torch.no_grad()
def evaluate(model, loader, device, a_mean, a_std):
    model.eval(); tot=0; n=0; ie=0
    for b in loader:
        X=b["X"].to(device); traj=b["traj"].to(device); mask=b["mask"].to(device)
        imp_p=b["imp_p"].to(device)
        pos_hat,_ = model(X)
        B = X.size(0)
        idx_i = torch.tensor(b["imp_idx"], device=device, dtype=torch.long)
        pred_i = pos_hat[torch.arange(B, device=device), idx_i]

        # Impact loss
        if LAMBDA_IMP > 0:
            pred_z, true_z = zscore_anchor_for_loss(pred_i, imp_p, a_mean, a_std)
            loss_imp = sl1_mean(pred_z, true_z)
        else:
            loss_imp = torch.tensor(0., device=device)

        # Trajectory loss
        if LAMBDA_TRAJ > 0:
            per_elem = sl1_none(pos_hat, traj)
            w = mask.expand_as(per_elem)
            valid = w.sum()
            loss_traj = (per_elem * w).sum() / valid.clamp_min(1.0)
        else:
            loss_traj = torch.tensor(0., device=device)

        loss = LAMBDA_IMP * loss_imp + LAMBDA_TRAJ * loss_traj
        tot += loss.item()*B; n += B
        ie += torch.linalg.norm(pred_i-imp_p, dim=1).mean().item()*B
    return tot/max(1,n), ie/max(1,n)


# ========================
# History & CSV
# ========================
def save_history_and_plot(hist, out_dir="runs", prefix="impact_only"):
    ensure_dir(out_dir)
    df = pd.DataFrame(hist)
    csv_path = os.path.join(out_dir, f"{prefix}_history.csv")
    df.to_csv(csv_path, index=False)
    fig, ax1 = plt.subplots(figsize=(7,4))
    ax1.plot(df["epoch"], df["train_loss"], label="train loss")
    if "val_loss" in df.columns and df["val_loss"].notna().any():
        ax1.plot(df["epoch"], df["val_loss"], label="val loss")
    ax1.set_xlabel("epoch"); ax1.set_ylabel("loss"); ax1.grid(True, alpha=0.3)
    ax2 = ax1.twinx()
    if "imp_err" in df.columns and df["imp_err"].notna().any():
        ax2.plot(df["epoch"], df["imp_err"], linestyle="--", label="ImpE (L2)")
    ax2.set_ylabel("impact error (L2)")
    lines, labels  = ax1.get_legend_handles_labels()
    lines2, labels2= ax2.get_legend_handles_labels()
    ax1.legend(lines+lines2, labels+labels2, loc="upper center", ncol=3)
    png_path = os.path.join(out_dir, f"{prefix}_loss_curve.png")
    plt.tight_layout(); plt.savefig(png_path, dpi=150); plt.close(fig)
    print(f"[INFO] history: {csv_path} / plot: {png_path}")

@torch.no_grad()
def save_anchor_csv(model, loader, device='cpu', out_csv='runs/impact_anchor_preds.csv'):
    model.eval(); rows=[]; trial_counter=0
    for b in loader:
        X=b["X"].to(device); imp_p=b["imp_p"].to(device)
        idx_i = torch.tensor(b["imp_idx"], device=device, dtype=torch.long)
        pos_hat,_ = model(X)
        B = X.size(0)
        pred_i = pos_hat[torch.arange(B, device=device), idx_i]
        err = torch.linalg.norm(pred_i - imp_p, dim=1)
        for k in range(B):
            rows.append({
                "trial_idx": trial_counter,
                "imp_idx": int(b["imp_idx"][k]),
                "pred_x": float(pred_i[k,0].cpu()),
                "pred_y": float(pred_i[k,1].cpu()),
                "pred_z": float(pred_i[k,2].cpu()),
                "true_x": float(imp_p[k,0].cpu()),
                "true_y": float(imp_p[k,1].cpu()),
                "true_z": float(imp_p[k,2].cpu()),
                "L2_err": float(err[k].cpu())
            })
            trial_counter += 1
    Path(Path(out_csv).parent).mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(out_csv, index=False)
    print(f"[SAVE] anchor preds -> {out_csv}")

@torch.no_grad()
def save_traj_csv(model, loader, device='cpu', out_csv='runs/impact_traj_preds.csv', save_mask=True):
    model.eval(); rows=[]; trial_counter=0
    for b in loader:
        X=b["X"].to(device); traj=b["traj"].to(device); mask=b["mask"].to(device)
        lengths=b["lengths"]; imp_idx_list=b["imp_idx"]
        pos_hat,_ = model(X)
        B, T, _ = pos_hat.shape
        for k in range(B):
            T_k = int(lengths[k].item()); imp_k = int(imp_idx_list[k])
            for t in range(T_k):
                rows.append({
                    "trial_idx": trial_counter, "t": t,
                    "pred_x": float(pos_hat[k,t,0].cpu()),
                    "pred_y": float(pos_hat[k,t,1].cpu()),
                    "pred_z": float(pos_hat[k,t,2].cpu()),
                    "gt_x": float(traj[k,t,0].cpu()),
                    "gt_y": float(traj[k,t,1].cpu()),
                    "gt_z": float(traj[k,t,2].cpu()),
                    "mask": int(mask[k,t,0].cpu()) if save_mask else 1,
                    "is_imp": 1 if t==imp_k else 0
                })
            trial_counter += 1
    Path(Path(out_csv).parent).mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(out_csv, index=False)
    print(f"[SAVE] trajectory preds -> {out_csv}")

# ========================
# EarlyStopping & Warmup
# ========================
class EarlyStopping:
    def __init__(self, patience=20, min_delta=1e-3):
        self.patience = int(patience); self.min_delta = float(min_delta)
        self.best = None; self.bad_epochs = 0; self.should_stop = False
    def step(self, val):
        if self.best is None or val < self.best - self.min_delta:
            self.best = val; self.bad_epochs = 0
        else:
            self.bad_epochs += 1
            if self.bad_epochs >= self.patience: self.should_stop = True

def lr_warmup_set(optim, base_lr, epoch, warmup_epochs):
    if warmup_epochs <= 0: return
    if epoch <= warmup_epochs:
        scale = epoch / float(max(1, warmup_epochs))
        for g in optim.param_groups:
            g["lr"] = base_lr * max(1e-3, scale)

# ========================
# Main
# ========================
def train_one_fold(fold_subj, all_subjects, ban_triples, fold_output_dir):
    """
    run one LOSO fold: train excluding fold_subj, test on fold_subj
    
    Args:
        fold_subj: participant number to exclude (1-based)
        all_subjects: list of all participants [1..10]
        ban_triples: (subj, club, trial) triples to exclude
        fold_output_dir: output directory for this fold
    """
    os.makedirs(fold_output_dir, exist_ok=True)

    # ---- Train: club1, trial 1-20 of the remaining participants excluding fold_subj ----
    train_specs = [
        {"subj": i, "club": 1, "start": 1, "end": 20}
        for i in all_subjects
        if i != fold_subj
    ]

    # ---- Test: club1 (21-30) + club3 (1-10) of fold_subj ----
    test_specs = [
        {"subj": fold_subj, "club": 1, "start": 21, "end": 30},
        {"subj": fold_subj, "club": 3, "start": 1,  "end": 10},
    ]

    # ---- data loading ----
    train_samples = build_val_from_specs(
        MAT_PATH, INPUT_SPEC, FIELD_MAP,
        val_specs=train_specs,
        ban_triples=ban_triples,
        feat_mode=FEAT_MODE,
        time_crop_cfg=TIME_CROP
    )

    test_samples = build_val_from_specs(
        MAT_PATH, INPUT_SPEC, FIELD_MAP,
        val_specs=test_specs,
        ban_triples=ban_triples,
        feat_mode=FEAT_MODE,
        time_crop_cfg=TIME_CROP
    )

    print(f"  Train samples: {len(train_samples)} (subj {fold_subj} excluded)")
    print(f"  Test  samples: {len(test_samples)} (subj {fold_subj} only)")

    if len(train_samples) == 0:
        print(f"  [ERROR] No training samples. Skipping fold {fold_subj}.")
        return None

    # ---- Feature dimension check ----
    train_dim = train_samples[0]['X'].shape[1]
    expected_dim = {'pos':3, 'vel':3, 'acc':3, 'acc+gyro':6,
                    'pos+vel':6, 'pos+vel+acc':9}.get(FEAT_MODE, 0)
    if train_dim != expected_dim:
        raise ValueError(f"Feature dim mismatch: got {train_dim}, expected {expected_dim}")

    # ---- standardisation (based on train) ----
    x_mean, x_std = compute_input_stats(train_samples)
    apply_input_norm(train_samples, x_mean, x_std)
    if len(test_samples) > 0:
        apply_input_norm(test_samples, x_mean, x_std)
    a_mean, a_std = compute_anchor_stats(train_samples)

    # ---- DataLoader ----
    train_ds = ImpactDataset(train_samples)
    train_dl = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_pad)

    test_dl = None
    if len(test_samples) > 0:
        test_ds = ImpactDataset(test_samples)
        test_dl = DataLoader(test_ds, batch_size=BATCH_SIZE, shuffle=False, collate_fn=collate_pad)

    # ---- model creation ----
    in_dim = train_samples[0]['X'].shape[1]
    model = BiLSTMTraj(in_dim, hidden=128, layers=2, bidir=True,
                       lstm_dropout=0.2, input_dropout=0.05, use_layernorm=True).to(DEVICE)

    head_params = list(model.head.parameters())
    body_params = [p for n,p in model.named_parameters() if not n.startswith('head.')]

    optim = torch.optim.AdamW([
        {"params": body_params, "lr": BASE_LR, "weight_decay": 1e-4},
        {"params": head_params, "lr": BASE_LR, "weight_decay": 0.0},
    ])
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optim, mode='min', factor=0.5, patience=8, min_lr=1e-5, verbose=True
    )
    early = EarlyStopping(patience=20, min_delta=1e-3)

    # ---- training loop ----
    history = {"epoch":[], "train_loss":[], "val_loss":[], "imp_err":[], "lr":[]}
    best = float('inf')
    best_state = None

    for ep in range(1, EPOCHS+1):
        lr_warmup_set(optim, BASE_LR, ep, WARMUP_EPOCHS)
        tr = train_epoch(model, train_dl, optim, device=DEVICE, a_mean=a_mean, a_std=a_std)

        history["epoch"].append(ep)
        history["train_loss"].append(float(tr))
        history["lr"].append(optim.param_groups[0]["lr"])

        if USE_VAL_DURING_TRAIN and test_dl is not None:
            va, ierr = evaluate(model, test_dl, device=DEVICE, a_mean=a_mean, a_std=a_std)
            history["val_loss"].append(float(va))
            history["imp_err"].append(float(ierr))
            print(f"  [{ep:03d}] train {tr:.3f} | val {va:.3f} | impE {ierr:.2f} | lr {optim.param_groups[0]['lr']:.2e}")

            if ep > WARMUP_EPOCHS:
                scheduler.step(va)
            if va < best:
                best = va
                best_state = {"model": model.state_dict(), "in_dim": model.lstm.input_size}
            if USE_EARLY_STOP:
                early.step(va)
                if early.should_stop:
                    print(f"  [EarlyStopping] Stopped at epoch {ep}.")
                    break
        else:
            history["val_loss"].append(None)
            history["imp_err"].append(None)
            if ep % 10 == 0 or ep == EPOCHS:
                print(f"  [{ep:03d}] train {tr:.3f} | lr {optim.param_groups[0]['lr']:.2e}")

    # ---- model saving ----
    if USE_VAL_DURING_TRAIN and best_state is not None:
        model_path = os.path.join(fold_output_dir, f"best_model_loso_subj{fold_subj}.pt")
        torch.save(best_state, model_path)
        model.load_state_dict(best_state["model"])
        print(f"  [SAVE] Best model (val loss: {best:.3f}) -> {model_path}")
    else:
        model_path = os.path.join(fold_output_dir, f"last_model_loso_subj{fold_subj}.pt")
        torch.save({"model": model.state_dict(), "in_dim": model.lstm.input_size}, model_path)
        print(f"  [SAVE] Last model -> {model_path}")

    save_history_and_plot(history, out_dir=fold_output_dir,
                         prefix=f"training_history_subj{fold_subj}")

    # ---- test ----
    fold_result = None
    if test_dl is not None:
        test_loss, test_impE = evaluate(model, test_dl, device=DEVICE, a_mean=a_mean, a_std=a_std)
        print(f"  [TEST] subj{fold_subj} overall | loss {test_loss:.3f} | impE {test_impE:.2f}")
        std_ratio_report(model, test_dl, device=DEVICE, tag=f"LOSO_subj{fold_subj}")

        fold_result = {"subj": fold_subj, "test_loss": test_loss, "test_impE": test_impE}

        club_map = {1: "driver", 2: "iron", 3: "fast"}

        for spec in test_specs:
            one_test_samples = build_val_from_specs(
                MAT_PATH, INPUT_SPEC, FIELD_MAP,
                val_specs=[spec],
                ban_triples=ban_triples,
                feat_mode=FEAT_MODE,
                time_crop_cfg=TIME_CROP
            )
            if len(one_test_samples) == 0:
                print(f"  [WARN] Empty test for spec={spec}")
                continue

            apply_input_norm(one_test_samples, x_mean, x_std)
            one_test_ds = ImpactDataset(one_test_samples)
            one_test_dl = DataLoader(one_test_ds, batch_size=BATCH_SIZE, shuffle=False, collate_fn=collate_pad)

            spec_loss, spec_impE = evaluate(model, one_test_dl, device=DEVICE, a_mean=a_mean, a_std=a_std)
            std_ratio_report(model, one_test_dl, device=DEVICE,
                            tag=f"subj{spec['subj']}_club{spec['club']}_({spec['start']}-{spec['end']})")
            print(f"  [TEST] subj{spec['subj']} club{spec['club']} | loss {spec_loss:.3f} | impE {spec_impE:.2f}")

            subj_id = int(spec["subj"])
            club_id = int(spec["club"])
            club_name = club_map.get(club_id, f"club{club_id}")
            
            anchor_csv = os.path.join(fold_output_dir, f"subj{subj_id}_{club_name}_test_est.csv")
            traj_csv   = os.path.join(fold_output_dir, f"subj{subj_id}_{club_name}_test_traj_est.csv")

            save_anchor_csv(model, one_test_dl, device=DEVICE, out_csv=anchor_csv)
            save_traj_csv(model, one_test_dl, device=DEVICE, out_csv=traj_csv, save_mask=True)

    return fold_result


def main():
    parser = argparse.ArgumentParser(description='LOSO BiLSTM Trajectory Model')
    parser.add_argument('--output_dir', type=str, required=True,
                        help='Output directory for saving results')
    args = parser.parse_args()

    global output_dir
    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)

    print("=" * 60)
    print("LOSO (Leave-One-Subject-Out) CROSS-VALIDATION")
    print("=" * 60)
    print(f"FEAT_MODE: {FEAT_MODE}")
    print(f"USE_VAL_DURING_TRAIN: {USE_VAL_DURING_TRAIN}")
    print(f"TIME_CROP: {TIME_CROP}")
    print(f"EPOCHS: {EPOCHS}")
    print(f"BATCH_SIZE: {BATCH_SIZE}")
    print(f"LAMBDA_IMP: {LAMBDA_IMP}")
    print(f"LAMBDA_TRAJ: {LAMBDA_TRAJ}")
    print(f"INPUT_SPEC:")
    for key, val in INPUT_SPEC.items():
        print(f"  {key}: {val}")
    print("=" * 60)

    all_subjects = list(range(1, 11))  # participants 1~10
    ban_triples = [(8,1,30), (5,3,5), (9,3,8)]

    all_results = []
    total_start = time.time()

    for fold_subj in all_subjects:
        fold_start = time.time()
        print("\n" + "#" * 60)
        print(f"# FOLD {fold_subj}/10 — Leave out Subject {fold_subj}")
        print("#" * 60)

        fold_output_dir = os.path.join(output_dir, f"fold_subj{fold_subj}")

        result = train_one_fold(
            fold_subj=fold_subj,
            all_subjects=all_subjects,
            ban_triples=ban_triples,
            fold_output_dir=fold_output_dir
        )

        fold_elapsed = time.time() - fold_start
        print(f"  Fold {fold_subj} elapsed: {fold_elapsed:.1f}s")

        if result is not None:
            result["elapsed_s"] = fold_elapsed
            all_results.append(result)

    # ---- overall summary ----
    total_elapsed = time.time() - total_start
    print("\n" + "=" * 60)
    print("LOSO SUMMARY")
    print("=" * 60)

    if len(all_results) > 0:
        df_summary = pd.DataFrame(all_results)
        summary_csv = os.path.join(output_dir, "loso_summary.csv")
        df_summary.to_csv(summary_csv, index=False)
        print(f"\n{'Subj':>6} {'Loss':>10} {'ImpE':>10} {'Time(s)':>10}")
        print("-" * 40)
        for r in all_results:
            print(f"{r['subj']:>6d} {r['test_loss']:>10.3f} {r['test_impE']:>10.2f} {r['elapsed_s']:>10.1f}")
        print("-" * 40)
        mean_loss = df_summary["test_loss"].mean()
        mean_impE = df_summary["test_impE"].mean()
        std_impE  = df_summary["test_impE"].std()
        print(f"{'Mean':>6} {mean_loss:>10.3f} {mean_impE:>10.2f}")
        print(f"{'Std':>6} {'':>10} {std_impE:>10.2f}")
        print(f"\n[SAVE] Summary -> {summary_csv}")

    print(f"\nTotal elapsed: {total_elapsed:.1f}s")
    print("\n" + "=" * 60)
    print("LOSO COMPLETED!")
    print("=" * 60)


if __name__ == "__main__":
    main()