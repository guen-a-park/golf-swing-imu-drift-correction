%% [R2-9] R2_09_exclusion_impact.m
%  checks how the manuscript numbers change when the saturated trials are excluded entirely.
%  Output : revision/results/R2_09_exclusion_impact.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

M  = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
TW = readtable(fullfile(RES, 'gyro_saturation_trialwise.csv'));
load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;

TW = TW(strcmp(string(TW.clubName), "driver"), :);
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

sat = false(height(Md),1);
for k = 1:height(Md)
    t = TW(TW.subj == Md.subj(k) & TW.trial == Md.trial(k), :);
    if ~isempty(t), sat(k) = logical(t.isSaturated(1)); end
end
NL = char(10);
fprintf([NL 'among %d evaluation trials, %d are saturated' NL], height(Md), sum(sat));

%% (1) motion capture D
fprintf([NL '===== (1) motion capture D (cm) =====' NL]);
fprintf(['%-14s %18s %18s' NL], 'item', 'all', 'excl. saturated');
lbl = {'fore-aft X','left-right Y','up-down Z'};
col = {'Dref_x','Dref_y','Dref_z'};
for a = 1:3
    [m1,s1] = local_ms(Md.(col{a})/10, Md.subj, true(height(Md),1));
    [m2,s2] = local_ms(Md.(col{a})/10, Md.subj, ~sat);
    fprintf(['%-14s %8.1f ± %-7.1f %8.1f ± %-7.1f' NL], lbl{a}, m1, s1, m2, s2);
end
fprintf([NL 'within-participant variation (SD, cm)' NL]);
for a = 1:3
    v1 = local_within(Md.(col{a})/10, Md.subj, true(height(Md),1));
    v2 = local_within(Md.(col{a})/10, Md.subj, ~sat);
    fprintf(['%-14s %8.2f ± %-7.2f %8.2f ± %-7.2f' NL], lbl{a}, ...
        mean(v1), std(v1), mean(v2,'omitnan'), std(v2,'omitnan'));
end

%% (2) mocap D vs video D correlation
fprintf([NL '===== (2) mocap D vs video D correlation (Pearson) =====' NL]);
vcol = {'Dvid_x','Dvid_y','Dvid_z'};
fprintf(['%-14s %18s %18s' NL], 'axis', 'all', 'excl. saturated');
for a = 1:3
    [r1,p1] = corr(Md.(col{a}), Md.(vcol{a}));
    [r2,p2] = corr(Md.(col{a})(~sat), Md.(vcol{a})(~sat));
    fprintf(['%-14s   R=%.2f (p=%.3f)   R=%.2f (p=%.3f)' NL], lbl{a}, r1, p1, r2, p2);
end

%% (3) video D error
fprintf([NL '===== (3) error of the video D (cm) =====' NL]);
E = [Md.Dvid_x - Md.Dref_x, Md.Dvid_y - Md.Dref_y, Md.Dvid_z - Md.Dref_z]/10;
En = vecnorm(E, 2, 2);
fprintf(['%-14s %18s %18s' NL], 'axis', 'all', 'excl. saturated');
for a = 1:3
    [m1,s1] = local_ms(abs(E(:,a)), Md.subj, true(height(Md),1));
    [m2,s2] = local_ms(abs(E(:,a)), Md.subj, ~sat);
    fprintf(['%-14s %8.1f ± %-7.1f %8.1f ± %-7.1f' NL], lbl{a}, m1, s1, m2, s2);
end
[m1,s1] = local_ms(En, Md.subj, true(height(Md),1));
[m2,s2] = local_ms(En, Md.subj, ~sat);
fprintf(['%-14s %8.1f ± %-7.1f %8.1f ± %-7.1f' NL], '3D magnitude', m1, s1, m2, s2);

%% (4) trajectory error per phase (video D)
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
n = numel(S); sj = nan(n,1); st2 = false(n,1); eV = nan(n,4);
for k = 1:n
    s0 = S(k); sj(k) = s0.subj;
    r = Md(Md.subj == s0.subj & Md.trial == s0.trial, :);
    if isempty(r), continue; end
    st2(k) = sat(find(Md.subj == s0.subj & Md.trial == s0.trial, 1));
    D = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
    c = local_correct(s0.imu_trajCal, D, s0.add, s0.imp, s0.fin);
    for q = 1:4
        i0 = s0.(SEG{q,2}); i1 = s0.(SEG{q,3});
        eV(k,q) = mean(vecnorm(s0.Mtraj(i0:i1,:) - c(i0:i1,:), 2, 2))/10;
    end
end
fprintf([NL '===== (4) trajectory error per phase, video D correction (cm) =====' NL]);
fprintf(['%-14s %18s %18s' NL], 'phase', 'all', 'excl. saturated');
for q = 1:4
    [m1,s1] = local_ms(eV(:,q), sj, true(n,1));
    [m2,s2] = local_ms(eV(:,q), sj, ~st2);
    fprintf(['%-14s %8.1f ± %-7.1f %8.1f ± %-7.1f' NL], SEG{q,1}, m1, s1, m2, s2);
end

%% helper functions
function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
function [m, s] = local_ms(x, subj, keep)
    x = x(:); keep = keep(:);
    u = unique(subj);
    v = arrayfun(@(q) mean(x(subj == q & keep), 'omitnan'), u);
    v = v(isfinite(v)); m = mean(v); s = std(v);
end
function v = local_within(x, subj, keep)
    x = x(:); keep = keep(:);
    u = unique(subj);
    v = arrayfun(@(q) std(x(subj == q & keep), 'omitnan'), u);
    v = v(isfinite(v));
end
