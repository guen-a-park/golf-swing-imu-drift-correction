"""
[R2-4] R2_04_inference_time.py

Response to manuscript R2-4: measure the inference time per swing.

Loads the trained model, repeatedly runs inference only on test swings, and
reports the time taken per swing on GPU and on CPU.

Usage:
  python R2_04_inference_time.py --mat ./swingData_2508_forML_ori7.mat \
                                 --ckpt runs_0112_accgyro_400800_ori7traj2/last_model.pt

2026-08-28
"""
import argparse
import importlib.util
import os
import sys
import time

import numpy as np
import torch
from torch.utils.data import DataLoader

SPEC_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "traj_ml_withtraj_matrevised_3d_1216.py")
spec = importlib.util.spec_from_file_location("trainmod", SPEC_PATH)
trainmod = importlib.util.module_from_spec(spec)
sys.modules["trainmod"] = trainmod
spec.loader.exec_module(trainmod)


def bench(model, samples, device, batch_size, n_rep=20, warmup=5):
    model.to(device).eval()
    ds = trainmod.ImpactDataset(samples)
    dl = DataLoader(ds, batch_size=batch_size, shuffle=False,
                    collate_fn=trainmod.collate_pad)
    batches = [b["X"].to(device) for b in dl]
    n_swing = sum(b.shape[0] for b in batches)

    with torch.no_grad():
        for _ in range(warmup):
            for X in batches:
                model(X)
        if device == 'cuda':
            torch.cuda.synchronize()
        t0 = time.perf_counter()
        for _ in range(n_rep):
            for X in batches:
                model(X)
        if device == 'cuda':
            torch.cuda.synchronize()
        t1 = time.perf_counter()

    total_s = (t1 - t0) / n_rep
    return total_s, n_swing, total_s / n_swing * 1000.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mat", required=True)
    ap.add_argument("--ckpt", required=True)
    args = ap.parse_args()

    train_specs = [{"subj": i, "club": 1, "start": 1, "end": 20} for i in range(1, 11)]
    test_specs = [{"subj": i, "club": 1, "start": 21, "end": 30} for i in range(1, 11)]
    ban = [(8, 1, 30), (5, 3, 5), (9, 3, 8)]
    kw = dict(ban_triples=ban, feat_mode=trainmod.FEAT_MODE,
              time_crop_cfg=trainmod.TIME_CROP)

    tr = trainmod.build_val_from_specs(args.mat, trainmod.INPUT_SPEC,
                                       trainmod.FIELD_MAP, val_specs=train_specs, **kw)
    x_mean, x_std = trainmod.compute_input_stats(tr)
    te = trainmod.build_val_from_specs(args.mat, trainmod.INPUT_SPEC,
                                       trainmod.FIELD_MAP, val_specs=test_specs, **kw)
    trainmod.apply_input_norm(te, x_mean, x_std)

    ck = torch.load(args.ckpt, map_location='cpu')
    model = trainmod.BiLSTMTraj(ck["in_dim"], hidden=128, layers=2, bidir=True)
    model.load_state_dict(ck["model"])
    nparam = sum(p.numel() for p in model.parameters())

    print("=" * 62)
    print("[R2-4] Inference time per swing")
    print("=" * 62)
    print(f"  model parameters : {nparam:,}")
    print(f"  test swings      : {len(te)}")
    if torch.cuda.is_available():
        print(f"  GPU              : {torch.cuda.get_device_name(0)}")
    print()

    for dev in (['cuda', 'cpu'] if torch.cuda.is_available() else ['cpu']):
        # batch inference (several swings at once)
        tot, n, per = bench(model, te, dev, trainmod.BATCH_SIZE)
        print(f"  {dev.upper():4s} batched (batch={trainmod.BATCH_SIZE}) : "
              f"{per:.3f} ms per swing  ({tot*1000:.1f} ms for {n} swings)")
        # single swing (real-use scenario: processed right after one swing ends)
        tot1, n1, per1 = bench(model, te[:1], dev, 1, n_rep=100, warmup=20)
        print(f"  {dev.upper():4s} single swing            : {per1:.3f} ms per swing")
    print("=" * 62)


if __name__ == "__main__":
    main()
