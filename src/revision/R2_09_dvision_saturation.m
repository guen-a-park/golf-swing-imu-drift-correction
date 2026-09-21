%% [R2-9] R2_09_dvision_saturation.m
%  Computes the per-segment trajectory error before and after excluding saturated trials, under the
%  Output      : revision/results/R2_09_dvision_saturation.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
L = load(fullfile(RES, 'gyro_saturation_mask.mat'));
SF = L.satFlag;                       % per-participant struct

Dml = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
n = numel(S);
sj = nan(n,1); sat = false(n,1);
eV = nan(n,4); eI = nan(n,4);

satMap = containers.Map('KeyType','char','ValueType','logical');
for su = 1:numel(SF)
    s = SF(su);
    fn = fieldnames(s);
    for f = 1:numel(fn)
        v = s.(fn{f});
        if isnumeric(v) || islogical(v)
        end
    end
end

TW = readtable(fullfile(RES, 'gyro_saturation_trialwise.csv'));
TW = TW(strcmp(string(TW.clubName), "driver") & TW.trial >= 21, :);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    r = M(M.subj == st.subj & M.trial == st.trial, :);
    t = TW(TW.subj == st.subj & TW.trial == st.trial, :);
    if isempty(r) || isempty(t), continue; end
    sat(k) = logical(t.isSaturated(1));

    Dv = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
    Di = squeeze(Dml(st.subj, st.trial - 20, :))';
    cV = local_correct(st.imu_trajCal, Dv, st.add, st.imp, st.fin);
    cI = local_correct(st.imu_trajCal, Di, st.add, st.imp, st.fin);
    for q = 1:4
        i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
        eV(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - cV(i0:i1,:), 2, 2))/10;
        eI(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - cI(i0:i1,:), 2, 2))/10;
    end
end

NL = char(10);
fprintf([NL '===== [R2-9] per-segment trajectory error before and after excluding saturation (cm) =====' NL]);
fprintf(['of %d driver evaluation trials, %d saturated, %d kept' NL NL], ...
    sum(isfinite(sj)), sum(sat), sum(~sat & isfinite(sj)));

rows = {};
for c = 1:2
    if c == 1, E = eV; lab = 'video D_Vision'; else, E = eI; lab = 'IMU-inferred D_Infer'; end
    fprintf(['--- %s ---' NL], lab);
    fprintf(['%-14s %11s %11s %11s %11s' NL], 'condition','backswing','downswing','follow-through','total');
    a = arrayfun(@(q) local_agg(E(:,q), sj, true(n,1)), 1:4);
    b = arrayfun(@(q) local_agg(E(:,q), sj, ~sat), 1:4);
    fprintf(['%-14s %11.1f %11.1f %11.1f %11.1f' NL], 'all trials', a);
    fprintf(['%-14s %11.1f %11.1f %11.1f %11.1f' NL NL], 'saturation excluded', b);
    rows = [rows; {lab,'all',a(1),a(2),a(3),a(4)}; {lab,'excl',b(1),b(2),b(3),b(4)}]; %#ok<AGROW>
end

writetable(cell2table(rows, 'VariableNames', ...
    {'constraint','set','Backswing','Downswing','FollowThrough','EntireSwing'}), ...
    fullfile(RES, 'R2_09_dvision_saturation.csv'));
fprintf(['saved: results/R2_09_dvision_saturation.csv' NL]);

%% helper functions
function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end

function D = local_load_Dml(runDir)
    D = nan(10,10,3);
    for su = 1:10
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T),10);
        D(su,1:m,:) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end

function m = local_agg(x, subj, keep)
    x = x(:); keep = keep(:);
    s = unique(subj(isfinite(subj)));
    v = arrayfun(@(q) mean(x(subj == q & keep), 'omitnan'), s);
    v = v(isfinite(v));
    if isempty(v), m = NaN; else, m = mean(v); end
end
