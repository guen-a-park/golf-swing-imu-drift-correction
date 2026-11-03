# Personalized kinematic constraint-based drift correction for 3D golf swing trajectory monitoring with a wrist-worn IMU

Code accompanying the manuscript submitted to *Scientific Reports*.

The framework reconstructs the 3D wrist trajectory of a golf swing from a single
wrist-worn IMU. Integration drift is corrected with a **subject-specific kinematic
constraint** — the wrist displacement between address and impact — which is obtained
once per person from monocular video during a calibration session and thereafter
inferred from the IMU signals alone.

| symbol in the manuscript | name in the code | meaning |
|---|---|---|
| `d_video` | `D_Vision`, `Dvid` | displacement reconstructed from the monocular video (calibration only) |
| `d_IMU`   | `D_Infer`, `Dml`   | displacement taken at impact from the trajectory that the BiLSTM predicts from the IMU signals — the one used for correction |
| `d_mocap` | `Dref`             | displacement measured by motion capture (reference) |

Each is a single 3D vector per trial, not a time-varying trajectory.

## Layout

```
src/video/      monocular video → 3D wrist position → D_Vision
src/imu/        IMU preprocessing, orientation estimation, velocity and
                displacement correction, trajectory reconstruction
src/model/      BiLSTM that predicts the wrist trajectory from the IMU signals,
                from which D_Infer is taken at impact (PyTorch)
src/figures/    scripts that produce the manuscript figures
src/revision/   analyses added during peer review (prefixed R2_ / R3_ by
                reviewer and comment number, R2r2_ for the second round)
lib/            shared MATLAB helpers (quaternion algebra, filtering, geometry)
```

## Requirements

- MATLAB R2024a, the version used for the reported analyses, with the Signal
  Processing Toolbox and the Statistics and Machine Learning Toolbox
- Python 3.9+ with PyTorch 1.13+, NumPy, SciPy, pandas
- 2D wrist keypoints are obtained with HRNet-W48 pretrained on COCO, used as
  published and not modified here

## Configuring paths

No absolute paths are hard-coded. Two locations are resolved at run time:

| helper | environment variable | contents |
|---|---|---|
| `lib/dataRoot.m` | `GOLF_DATA_ROOT` | `imu/`, `mocap/`, `video/`, each with one folder per participant (`S01` … `S10`) |
| `lib/runsRoot.m` | `GOLF_RUNS_ROOT` | trained-model run directories written by `src/model/` |

```matlab
setenv('GOLF_DATA_ROOT', 'D:\golf\data');
setenv('GOLF_RUNS_ROOT', 'D:\golf\runs');
addpath(genpath('lib'), genpath('src'));
```

Paths that appear inside commented-out lines are left as `<DATA_ROOT>` and
`<RUNS_ROOT>` placeholders; they record alternatives that were explored and are
not executed.

## Pipeline

1. **`src/imu/matProcess0902.m`** — reads the raw IMU, motion capture and video
   exports, synchronises them and writes the per-trial structure used downstream.
2. **`src/video/clublength_3d_1110.m`** — reconstructs the 3D wrist position at
   address and at impact by intersecting the camera ray with a sphere of radius
   equal to the club length centred on the ball, and returns `D_Vision`.
3. **`src/model/traj_ml_withtraj_matrevised_3d_1216.py`** — trains the BiLSTM on
   the calibration swings, with the trajectories corrected by `D_Vision` as
   labels, and takes `D_Infer` from the predicted trajectory at impact.
   `traj_ml_loso_0224.py` runs the
   leave-one-subject-out condition.
4. **`src/imu/swing1127_withml_3d_0304.m`** — estimates orientation, applies the
   approximate zero-velocity correction at address, top of backswing and finish,
   applies the displacement correction with `D_Infer`, and evaluates the
   reconstructed trajectory against motion capture.
5. **`src/figures/`** — regenerates the manuscript figures from the saved results.

## Data

The dataset is **not** distributed with this repository. It consists of
synchronised wrist-worn IMU, optical motion capture and monocular video
recordings of ten participants, and the video in particular identifies the
participants, so it falls outside the scope of the consent obtained.

The data are available from the corresponding author on reasonable request.
Participant identifiers in this code are anonymised as `S01` … `S10`.

## Excluded trials

Five trials were excluded because the IMU recording could not be used.

| participant | condition | trial |
|---|---|---|
| 2 | driver, training | 10 |
| 6 | driver, training | 3 |
| 8 | driver, test | 30 |
| 5 | faster than preferred | 5 |
| 9 | faster than preferred | 8 |

This leaves 198 driver training trials, 99 driver test trials and 98
faster-than-preferred trials, 395 in total.

The exclusion is applied once in `src/imu/swing1127_withml_3d_0304.m`, which
builds the `swingData_2508_forML*.mat` used for training, so the excluded
trials never reach the model. The `ban_triples` list in
`src/model/traj_ml_withtraj_matrevised_3d_1216.py` repeats only the three that
could otherwise be reached through a different entry point, and
`src/revision/R2_common_mocap_extract.m` carries the full list for the
revision analyses.

## Citation

See `CITATION.cff`. The archived release carries a DOI issued by Zenodo.

## License

MIT — see `LICENSE`.
