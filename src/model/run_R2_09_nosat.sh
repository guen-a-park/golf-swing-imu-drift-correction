#!/bin/bash
# [R2-9] retrain with saturated trials excluded from both training and evaluation
BAN="../golfClubHead/250819_golf/revision/results/saturated_ban_triples.csv"
for S in 1 2 3 4 5; do
  D="runs_R2_09_nosat_seed${S}"
  echo "=== $D ==="
  python traj_ml_withtraj_matrevised_3d_1216.py \
    --output_dir "$D" --seed "$S" --train_end 20 --ban_file "$BAN"
done
