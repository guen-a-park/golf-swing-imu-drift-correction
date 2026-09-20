%% R2_pv_nosat.m
%  Tests whether the trajectory error obtained after retraining with saturated trials excluded from both
%  training and evaluation differs significantly from the original condition. Same procedure as R2_09_nosat_traj.m, but
%  participant-level values are kept so that a paired t-test can be performed.
%
%  Comparison : (A) original model, all trials   (B) retrained model, non-saturated trials
%         Retraining uses the mean over 5 seeds.
%
%  Output : revision/results/R2_pv_nosat.csv
%
%  2026-09-10
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
TW = readtable(fullfile(RES, 'gyro_saturation_trialwise.csv'));

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
SEGKR = {'backswing','downswing','follow-through','whole swing'};

n = numel(S); sj = nan(n,1); sat = false(n,1);
for k = 1:n
    st = S(k); sj(k) = st.subj;
    r = TW(TW.subj == st.subj & TW.trial == st.trial, :);
    if ~isempty(r), sat(k) = logical(r.isSaturated(1)); end
end

% (A) original model
Dref = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));
eA = local_phase(S, Dref, SEG);

% (B) retrained model, mean over 5 seeds
eB = nan(n, 4, 5);
for s = 1:5
    T = readtable(fullfile(RES, sprintf('R2_09_nosat_Dml_seed%d.csv', s)));
    Dm = nan(10,10,3);
    for r = 1:height(T)
        Dm(T.subj(r), T.trial(r)-20, :) = [T.px(r) T.py(r) T.pz(r)];
    end
    eB(:,:,s) = local_phase(S, Dm, SEG);
end
eBm = mean(eB, 3, 'omitnan');

%% ----- participant-level paired t-test --------------------------------------
rows = {};
fprintf('\n===== saturation excluded + retrained (participant-level paired t-test, cm) =====\n');
for q = 1:4
    a = agg(eA(:,q), sj, true(n,1));      % original model, all trials
    b = agg(eBm(:,q), sj, ~sat);          % retrained model, non-saturated trials
    ok = isfinite(a) & isfinite(b);
    [~, p, ~, stt] = ttest(a(ok), b(ok));
    fprintf('  %-10s %5.1f -> %5.1f   t(%d) = %5.2f, p = %.4f  (%d participants)\n', ...
            SEGKR{q}, mean(a(ok)), mean(b(ok)), stt.df, stt.tstat, p, sum(ok));
    rows(end+1,:) = {SEGKR{q}, mean(a(ok)), mean(b(ok)), stt.tstat, p, sum(ok)}; %#ok<AGROW>
end

writetable(cell2table(rows, 'VariableNames', {'segment','total','sat_excluded_retrained','t','p','n'}), ...
    fullfile(RES, 'R2_pv_nosat.csv'));
fprintf('\nsaved: results/R2_pv_nosat.csv\n');

%% ===== helpers =====
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
function v = agg(x, subj, keep)
    x = x(:); keep = keep(:);
    u = unique(subj);
    v = arrayfun(@(q) mean(x(subj == q & keep), 'omitnan'), u);
end
