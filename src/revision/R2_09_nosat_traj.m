%% [R2-9] R2_09_nosat_traj.m
%  Phase-wise trajectory error of a model retrained with saturated trials excluded from both training and evaluation.
%  Output : revision/results/R2_09_nosat_traj.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
TW = readtable(fullfile(RES, 'gyro_saturation_trialwise.csv'));
TW = TW(strcmp(string(TW.clubName), "driver"), :);

Dref = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
n = numel(S); sj = nan(n,1); sat = false(n,1);
for k = 1:n
    st = S(k); sj(k) = st.subj;
    t = TW(TW.subj == st.subj & TW.trial == st.trial, :);
    if ~isempty(t), sat(k) = logical(t.isSaturated(1)); end
end

NL = char(10);
fprintf([NL '===== [R2-9] retraining result with saturation excluded (cm) =====' NL]);
fprintf(['Of %d driver test trials, %d saturated, %d remaining' NL NL], n, sum(sat), sum(~sat));

eA = local_phase(S, Dref, SEG);
fprintf(['%-24s %10s %10s %10s %10s' NL], 'Condition','Backswing','Downswing','Follow-through','Entire');
fprintf(['%-24s %10.1f %10.1f %10.1f %10.1f' NL], 'Manuscript model / all 99', ...
    arrayfun(@(q) local_agg(eA(:,q), sj, true(n,1)), 1:4));
fprintf(['%-24s %10.1f %10.1f %10.1f %10.1f' NL], 'Manuscript model / remaining 77', ...
    arrayfun(@(q) local_agg(eA(:,q), sj, ~sat), 1:4));

V = nan(5,4);
for s = 1:5
    T = readtable(fullfile(RES, sprintf('R2_09_nosat_Dml_seed%d.csv', s)));
    Dm = nan(10,10,3);
    for r = 1:height(T)
        Dm(T.subj(r), T.trial(r)-20, :) = [T.px(r) T.py(r) T.pz(r)];
    end
    e = local_phase(S, Dm, SEG);
    V(s,:) = arrayfun(@(q) local_agg(e(:,q), sj, ~sat), 1:4);
    fprintf(['%-24s %10.1f %10.1f %10.1f %10.1f' NL], ...
        sprintf('Retrained seed%d / 77', s), V(s,:));
end
fprintf([NL '%-24s %10.1f %10.1f %10.1f %10.1f' NL], 'Retrained median', median(V,1));

writetable(array2table(V, 'VariableNames', {'Backswing','Downswing','FollowThrough','EntireSwing'}), ...
    fullfile(RES, 'R2_09_nosat_traj.csv'));
fprintf(['saved: results/R2_09_nosat_traj.csv' NL]);

%% Helper functions
function e = local_phase(S, Dm, SEG)
    n = numel(S); e = nan(n,4);
    for k = 1:n
        st = S(k);
        D = squeeze(Dm(st.subj, st.trial-20, :))';
        if any(isnan(D)), continue; end
        c = local_correct(st.imu_trajCal, D, st.add, st.imp, st.fin);
        for q = 1:4
            i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
            e(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - c(i0:i1,:), 2, 2))/10;
        end
    end
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
function m = local_agg(x, subj, keep)
    x = x(:); keep = keep(:);
    u = unique(subj);
    v = arrayfun(@(q) mean(x(subj == q & keep), 'omitnan'), u);
    v = v(isfinite(v)); m = mean(v);
end
