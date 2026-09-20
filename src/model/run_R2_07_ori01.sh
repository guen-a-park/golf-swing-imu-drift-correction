#!/bin/sh
# [R2-7] run the OrientationMethod 0 / 1 training with seeds 1-5 each.
#   ori1 : give the address orientation as reference values for roll/pitch/yaw, then gyro integration
#   ori0 : marker orientation over the whole interval (zero orientation error, upper bound of improvement)
# matched to the same conditions as ori8 (train_end 20, epochs default).
PY="${PYTHON:-python}"
for M in 1 0; do
  for S in 1 2 3 4 5; do
    D="runs_R2_07_ori${M}_seed${S}"
    if [ -d "$D" ]; then echo "skip $D"; continue; fi
    echo "=== $D"
    "$PY" traj_ml_withtraj_matrevised_3d_1216.py \
        --output_dir "$D" --seed "$S" --train_end 20 \
        --mat_path "./swingData_2508_forML_ori${M}.mat" || exit 1
  done
done
echo "[R2-7] all done"
