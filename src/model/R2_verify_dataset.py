"""
[verification] R2_verify_dataset.py

Checks whether the regenerated ori7 ML dataset is the same as the dataset that produced
the manuscript run (runs_0112_accgyro_400800_ori7traj2).

Method: without any training, load last_model.pt from the manuscript run as is,
      run inference only on the regenerated dataset and compare against the manuscript CSV.
      if the datasets are identical, pred/true must both match.

Usage:
  python R2_verify_dataset.py --mat ./swingData_2508_forML_ori7.mat \
                              --ref_dir runs_0112_accgyro_400800_ori7traj2 \
                              --ckpt   runs_0112_accgyro_400800_ori7traj2/last_model.pt

2026-08-28
"""
import argparse
import os

import numpy as np
import pandas as pd
import torch
from torch.utils.data import DataLoader

# reuse the components of the training script as is (guarantees identical preprocessing)
import importlib.util
import sys

SPEC_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "traj_ml_withtraj_matrevised_3d_1216.py")
spec = importlib.util.spec_from_file_location("trainmod", SPEC_PATH)
trainmod = importlib.util.module_from_spec(spec)
sys.modules["trainmod"] = trainmod
spec.loader.exec_module(trainmod)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mat", required=True, help="ML dataset mat to verify")
    ap.add_argument("--ref_dir", required=True, help="manuscript run folder (for CSV comparison)")
    ap.add_argument("--ckpt", required=True, help="last_model.pt of the manuscript run")
    ap.add_argument("--out_dir", default="runs_R2verify", help="folder to save the inference results")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    dev = trainmod.DEVICE

    # ---- the same spec as during training ----
    train_specs = [{"subj": i, "club": 1, "start": 1, "end": 20} for i in range(1, 11)]
    test_specs = ([{"subj": i, "club": 1, "start": 21, "end": 30} for i in range(1, 11)]
                  + [{"subj": i, "club": 3, "start": 1, "end": 10} for i in range(1, 11)])
    ban = [(8, 1, 30), (5, 3, 5), (9, 3, 8)]

    kw = dict(ban_triples=ban, feat_mode=trainmod.FEAT_MODE,
              time_crop_cfg=trainmod.TIME_CROP)

    # the input normalisation statistics are computed from the training set (same procedure as the training script)
    train_samples = trainmod.build_val_from_specs(
        args.mat, trainmod.INPUT_SPEC, trainmod.FIELD_MAP,
        val_specs=train_specs, **kw)
    if len(train_samples) == 0:
        raise RuntimeError("failed to load the training set — check the mat path/structure")
    x_mean, x_std = trainmod.compute_input_stats(train_samples)
    print(f"train samples = {len(train_samples)}, in_dim = {train_samples[0]['X'].shape[-1]}")

    # ---- model loading ----
    ck = torch.load(args.ckpt, map_location=dev)
    in_dim = ck["in_dim"]
    model = trainmod.BiLSTMTraj(in_dim, hidden=128, layers=2, bidir=True).to(dev)
    model.load_state_dict(ck["model"])
    model.eval()
    print(f"loaded checkpoint: {args.ckpt} (in_dim={in_dim})")

    club_map = {1: "driver", 2: "iron", 3: "fast"}
    rows = []
    for sp in test_specs:
        s = trainmod.build_val_from_specs(args.mat, trainmod.INPUT_SPEC,
                                          trainmod.FIELD_MAP, val_specs=[sp], **kw)
        if len(s) == 0:
            continue
        trainmod.apply_input_norm(s, x_mean, x_std)
        dl = DataLoader(trainmod.ImpactDataset(s), batch_size=trainmod.BATCH_SIZE,
                        shuffle=False, collate_fn=trainmod.collate_pad)

        name = f"subj{sp['subj']}_{club_map[sp['club']]}_test_est.csv"
        out_csv = os.path.join(args.out_dir, name)
        trainmod.save_anchor_csv(model, dl, device=dev, out_csv=out_csv)

        ref_csv = os.path.join(args.ref_dir, name)
        if not os.path.isfile(ref_csv):
            print(f"[WARN] manuscript CSV missing: {ref_csv}")
            continue
        new = pd.read_csv(out_csv)
        ref = pd.read_csv(ref_csv)
        n = min(len(new), len(ref))
        cols_t = ["true_x", "true_y", "true_z"]
        cols_p = ["pred_x", "pred_y", "pred_z"]
        dt = np.abs(new[cols_t].values[:n] - ref[cols_t].values[:n]).max()
        dp = np.abs(new[cols_p].values[:n] - ref[cols_p].values[:n]).max()
        rows.append({"file": name, "n": n, "max_true_diff": dt, "max_pred_diff": dp})

    R = pd.DataFrame(rows)
    R.to_csv(os.path.join(args.out_dir, "verify_summary.csv"), index=False)

    print("\n" + "=" * 64)
    print("dataset identity verification result")
    print("=" * 64)
    print(f"  true(D_Vision) max absolute difference : {R['max_true_diff'].max():.6f} mm")
    print(f"  pred(D_Infer)  max absolute difference : {R['max_pred_diff'].max():.6f} mm")
    if R["max_true_diff"].max() < 1e-3 and R["max_pred_diff"].max() < 1e-2:
        print("\n  => the regenerated dataset is identical to the manuscript dataset.")
    else:
        print("\n  => there are differences. Check the per-file results below:")
        print(R.sort_values("max_true_diff", ascending=False).head(10).to_string(index=False))
    print("=" * 64)


if __name__ == "__main__":
    main()
