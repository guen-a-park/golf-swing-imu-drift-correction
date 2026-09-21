%% [R2-10] R2_10_loso_vs_mean.m
%  "Could a general model work without per-participant calibration?" This is the question answered here.
%  Output : revision/results/R2_10_loso_vs_mean.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

load(fullfile(OUT, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M  = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
ref = [Md.Dref_x Md.Dref_y Md.Dref_z];
g   = mean(ref, 1, 'omitnan');

Dp = local_load(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'), false);
Dl = local_load(fullfile(ML, 'runs_0224_accgyro_400800_loso3'),     true);

COND = {'group mean D D', 'D_Infer', 'D_Infer LOSO'};
QN   = {'impact', 'downswing', 'entire swing'};
n = numel(S); E = nan(n, 3, 3); dErr = nan(n, 3); subj = nan(n, 1);

for k = 1:n
    st = S(k);
    r = find(Md.subj == st.subj & Md.trial == st.trial, 1);
    if isempty(r) || any(~isfinite(ref(r,:))), continue; end
    subj(k) = st.subj;
    DS = {g, squeeze(Dp(st.subj, st.trial-20, :))', squeeze(Dl(st.subj, st.trial-20, :))'};
    for c = 1:3
        if any(~isfinite(DS{c})), continue; end
        dErr(k,c) = norm(DS{c} - ref(r,:)) / 10;
        T = local_correct(st.imu_trajCal, DS{c}, st.add, st.imp, st.fin);
        E(k,1,c) = norm(st.Mtraj(st.imp,:) - T(st.imp,:)) / 10;
        E(k,2,c) = mean(vecnorm(st.Mtraj(st.bst:st.imp,:) - T(st.bst:st.imp,:), 2, 2)) / 10;
        E(k,3,c) = mean(vecnorm(st.Mtraj(st.add:st.fin,:) - T(st.add:st.fin,:), 2, 2)) / 10;
    end
end

u = unique(subj(isfinite(subj)));
V = nan(numel(u), 3, 3); DE = nan(numel(u), 3);
fprintf([NL '%-16s %12s %10s %10s %10s' NL], 'condition', 'constraint err', 'impact', 'downswing', 'entire swing');
rows = {};
for c = 1:3
    DE(:,c) = arrayfun(@(x) mean(dErr(subj==x,c), 'omitnan'), u);
    for q = 1:3
        V(:,q,c) = arrayfun(@(x) mean(E(subj==x,q,c), 'omitnan'), u);
    end
    fprintf('%-16s %12.1f %10.1f %10.1f %10.1f%s', COND{c}, mean(DE(:,c)), ...
            mean(V(:,1,c)), mean(V(:,2,c)), mean(V(:,3,c)), NL);
    rows = [rows; {COND{c}, mean(DE(:,c)), mean(V(:,1,c)), mean(V(:,2,c)), mean(V(:,3,c))}]; %#ok<AGROW>
end

fprintf([NL 'group mean D vs LOSO (paired t-test on per-participant means, n = %d), n = %d)' NL], numel(u));
[~, pd] = ttest(DE(:,1), DE(:,3));
fprintf('  %-10s %5.1f vs %5.1f   p = %.4f%s', 'constraint err', mean(DE(:,1)), mean(DE(:,3)), pd, NL);
for q = 1:3
    [~, p] = ttest(V(:,q,1), V(:,q,3));
    fprintf('  %-10s %5.1f vs %5.1f   p = %.4f%s', QN{q}, mean(V(:,q,1)), mean(V(:,q,3)), p, NL);
end

T = cell2table(rows, 'VariableNames', {'condition','D_error_cm','impact_cm','downswing_cm','entire_cm'});
writetable(T, fullfile(OUT, 'R2_10_loso_vs_mean.csv'));
fprintf([NL 'saved: results/R2_10_loso_vs_mean.csv' NL]);

%% helper functions
function D = local_load(runDir, isLoso)
    D = nan(10,10,3);
    for su = 1:10
        if isLoso
            f = fullfile(runDir, sprintf('fold_subj%d', su), ...
                         sprintf('subj%d_driver_test_est.csv', su));
        else
            f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        end
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T), 10);
        D(su,1:m,:) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end
function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
