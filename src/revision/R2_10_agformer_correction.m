%% [R2-10] R2_10_agformer_correction.m
%  MotionAGFormer -estimated constraints are used for drift correction and the outcome is examined.
%
%  The manuscript compared the two methods only by the correlation of the constraint itself. But the constraint exists to correct the IMU-integrated
%  trajectory, so keeping everything else identical and changing only the applied constraint to compare the final
%  trajectory error shows the contribution directly.
%
%  Conditions   : no constraint / motion capture D D / D_Vision / D_Infer / D_AGFormer
%
%  Prerequisite : R2_03_traj_store_ori7.mat, R2_common_mocap_metrics.csv
%  Output       : revision/results/R2_10_agformer_correction.csv
%
%  2026-09-05
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

load(fullfile(OUT, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M  = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
Dml = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));

SEG  = {'backswing','add','bst'; 'downswing','bst','imp'; ...
        'follow-through','imp','fin'; 'entire swing','add','fin'};
COND = {'no constraint','motion capture D D','D_Vision','D_Infer','D_AGFormer'};
n = numel(S);
E = nan(n, 4, 5);            % [trial x segment x condition]
Eimp = nan(n, 5);
subj = nan(n, 1);

for k = 1:n
    st = S(k);
    r = Md(Md.subj == st.subj & Md.trial == st.trial, :);
    if isempty(r), continue; end
    subj(k) = st.subj;

    Dref = [r.Dref_x(1) r.Dref_y(1) r.Dref_z(1)];
    Dvid = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
    Dag  = [r.Dag_x(1)  r.Dag_y(1)  r.Dag_z(1) ];
    Dinf = squeeze(Dml(st.subj, st.trial-20, :))';
    if any(~isfinite([Dref Dvid Dag Dinf])), continue; end

    T = {st.imu_trajCal, ...
         local_correct(st.imu_trajCal, Dref, st.add, st.imp, st.fin), ...
         local_correct(st.imu_trajCal, Dvid, st.add, st.imp, st.fin), ...
         local_correct(st.imu_trajCal, Dinf, st.add, st.imp, st.fin), ...
         local_correct(st.imu_trajCal, Dag,  st.add, st.imp, st.fin)};

    for c = 1:5
        for q = 1:4
            i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
            E(k,q,c) = mean(vecnorm(st.Mtraj(i0:i1,:) - T{c}(i0:i1,:), 2, 2)) / 10;
        end
        Eimp(k,c) = norm(st.Mtraj(st.imp,:) - T{c}(st.imp,:)) / 10;
    end
end

%% ===== average per participant first, then summarise across participants =====
u = unique(subj(isfinite(subj)));
fprintf([NL 'driver evaluation, %d trials, %d participants' NL], sum(isfinite(subj)), numel(u));
fprintf([NL '%-10s', repmat(' %13s', 1, 5), NL], 'interval', COND{:});
rows = {};
Msub = nan(numel(u), 5, 5);          % [subj x (4 seg + impact) x cond]
for q = 1:5
    line = sprintf('%-10s', ternary(q<5, SEG{min(q,4),1}, 'impact'));
    for c = 1:5
        if q < 5, v = arrayfun(@(x) mean(E(subj==x,q,c),'omitnan'), u);
        else,     v = arrayfun(@(x) mean(Eimp(subj==x,c),'omitnan'), u);
        end
        Msub(:,q,c) = v;
        line = [line sprintf(' %6.1f ± %4.1f', mean(v), std(v))]; %#ok<AGROW>
        rows = [rows; {ternary(q<5, SEG{min(q,4),1}, 'impact'), COND{c}, mean(v), std(v)}]; %#ok<AGROW>
    end
    fprintf([line NL]);
end

%% ===== D_Vision vs D_AGFormer paired test =====
fprintf([NL 'D~Vision~ vs D~AGFormer~ (paired t-test on per-participant means)' NL]);
name = [SEG(:,1); {'impact'}];
for q = 1:5
    a = Msub(:,q,3); b = Msub(:,q,5);
    [~, p, ~, stt] = ttest(a, b);
    fprintf('  %-10s %5.1f vs %5.1f cm   diff %+5.1f   t = %5.2f   p = %.4f%s', ...
            name{q}, mean(a), mean(b), mean(b)-mean(a), stt.tstat, p, NL);
    rows = [rows; {name{q}, 'p(Vision vs AGFormer)', p, NaN}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'segment','condition','value','sd'});
writetable(T, fullfile(OUT, 'R2_10_agformer_correction.csv'));
fprintf([NL 'saved: results/R2_10_agformer_correction.csv' NL]);

%% ===== helper functions =====
function out = ternary(c, a, b)
    if c, out = a; else, out = b; end
end
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
