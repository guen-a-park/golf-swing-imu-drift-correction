"""
[R2-6c] R2_06c_anchor_sd.py

Recomputes the per-participant segment errors of R2_06c_velocity_anchor_conditions.m to report their standard deviations.

Output : revision/results/R2_06c_velocity_anchor_subject.csv
"""

import csv, io, os, sys
import numpy as np
import h5py

BASE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(BASE, "results")
RUN = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(BASE))),
                   "multimodal", "runs_0112_accgyro_400800_ori7traj2")
OUT = os.path.join(RES, "R2_06c_velocity_anchor_subject.csv")

FS = 200.0
SEG = [("Backswing", "add", "bst"), ("Downswing", "bst", "imp"),
       ("FollowThrough", "imp", "fin"), ("EntireSwing", "add", "fin")]

def load_dml():
    D = np.full((10, 10, 3), np.nan)
    for su in range(1, 11):
        p = os.path.join(RUN, "subj%d_driver_test_est.csv" % su)
        if not os.path.isfile(p):
            continue
        rows = list(csv.DictReader(io.open(p, encoding="utf-8-sig")))[:10]
        for j, r in enumerate(rows):
            D[su - 1, j] = [float(r["pred_x"]), float(r["pred_y"]), float(r["pred_z"])]
    return D

def load_metrics():
    out = {}
    for r in csv.DictReader(io.open(os.path.join(RES, "R2_common_mocap_metrics.csv"),
                                    encoding="utf-8-sig")):
        if int(float(r["club"])) != 1:
            continue
        t = int(float(r["trial"]))
        if not 21 <= t <= 30:
            continue
        out[(int(float(r["subj"])), t)] = r
    return out

def correct(traj0, D, add, imp, fin):
    traj = traj0.copy()
    dm = traj0[imp] - D
    kk = np.arange(add, fin + 1)
    w = (kk - add) / float(imp - add)
    traj[kk] = traj0[kk] - w[:, None] * dm
    return traj

def seg_err(Mtraj, traj, i0, i9):
    return np.linalg.norm(Mtraj[i0:i9 + 1] - traj[i0:i9 + 1], axis=1).mean() / 10.0

def main():
    f = h5py.File(os.path.join(RES, "R2_03_traj_store_ori7.mat"), "r")
    st = f["R2_03_store"]
    n = st["subj"].shape[0]
    M = load_metrics()
    Dml = load_dml()

    def g(k, i):
        return np.array(f[st[k][i, 0]])

    recs = []
    for i in range(n):
        subj = int(g("subj", i).flat[0])
        trial = int(g("trial", i).flat[0])
        r = M.get((subj, trial))
        if r is None:
            continue
        add = int(g("add", i).flat[0]) - 1
        bst = int(g("bst", i).flat[0]) - 1
        imp = int(g("imp", i).flat[0]) - 1
        fin = int(g("fin", i).flat[0]) - 1
        Mtraj = g("Mtraj", i).T
        trajZ = g("imu_trajCal", i).T

        vmBST = np.array([float(r["vBST_x"]), float(r["vBST_y"]), float(r["vBST_z"])])
        vmFIN = np.array([float(r["vFIN_x"]), float(r["vFIN_y"]), float(r["vFIN_z"])])

        d = np.zeros_like(trajZ)
        i1 = np.arange(add, bst + 1)
        d[i1] = -((i1 - add) / float(bst - add))[:, None] * vmBST
        i2 = np.arange(bst, fin + 1)
        d[i2] = -vmBST + ((i2 - bst) / float(fin - bst))[:, None] * (vmBST - vmFIN)
        dx = np.concatenate([[np.zeros(3)],
                             np.cumsum((d[1:] + d[:-1]) / 2.0, axis=0) / FS])
        dx -= dx[add]
        trajMv = trajZ - dx

        idx = {"add": add, "bst": bst, "imp": imp, "fin": fin}
        rec = {"subj": subj, "trial": trial}
        for name, a, b in SEG:
            rec["noD_zero_" + name] = seg_err(Mtraj, trajZ, idx[a], idx[b])
            rec["noD_meas_" + name] = seg_err(Mtraj, trajMv, idx[a], idx[b])
        rec["noD_zero_Impact"] = np.linalg.norm(Mtraj[imp] - trajZ[imp]) / 10.0
        rec["noD_meas_Impact"] = np.linalg.norm(Mtraj[imp] - trajMv[imp]) / 10.0

        D = Dml[subj - 1, trial - 21]
        if not np.any(np.isnan(D)):
            cZ = correct(trajZ, D, add, imp, fin)
            cMv = correct(trajMv, D, add, imp, fin)
            for name, a, b in SEG:
                rec["InferD_zero_" + name] = seg_err(Mtraj, cZ, idx[a], idx[b])
                rec["InferD_meas_" + name] = seg_err(Mtraj, cMv, idx[a], idx[b])
            rec["InferD_zero_Impact"] = np.linalg.norm(Mtraj[imp] - cZ[imp]) / 10.0
            rec["InferD_meas_Impact"] = np.linalg.norm(Mtraj[imp] - cMv[imp]) / 10.0
        recs.append(rec)

    keys = [k for k in recs[0] if k not in ("subj", "trial")]
    subjects = sorted({r["subj"] for r in recs})
    per = []
    for s in subjects:
        mine = [r for r in recs if r["subj"] == s]
        row = {"subj": s}
        for k in keys:
            v = [r[k] for r in mine if k in r]
            row[k] = float(np.mean(v)) if v else float("nan")
        per.append(row)

    with io.open(OUT, "w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=["subj"] + keys)
        w.writeheader()
        w.writerows(per)

    print("saved:", os.path.basename(OUT), " participants: %d" % len(per))
    print()
    print("%-26s %16s %16s" % ("", "0 (approximate zero velocity)", "measured velocity"))
    for tag, lab in (("noD", "no displacement constraint"), ("InferD", "constraint = D_Infer")):
        print("--- %s" % lab)
        for name in [s[0] for s in SEG] + ["Impact"]:
            a = np.array([r["%s_zero_%s" % (tag, name)] for r in per])
            b = np.array([r["%s_meas_%s" % (tag, name)] for r in per])
            a, b = a[np.isfinite(a)], b[np.isfinite(b)]
            print("  %-24s %7.1f ± %-6.1f %7.1f ± %-6.1f"
                  % (name, a.mean(), a.std(ddof=1), b.mean(), b.std(ddof=1)))

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
