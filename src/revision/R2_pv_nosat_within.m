%% R2_pv_nosat_within.m
%  Pairs and compares the trajectory error of saturated and non-saturated trials within the same participant.
%  Output : revision/results/R2_pv_nosat_within.csv

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

Dref = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));
e = local_phase(S, Dref, SEG);
ie = local_impact(S, Dref);

u = unique(sj(isfinite(sj)));
rows = {};
fprintf('\n===== saturated vs non-saturated, within-participant paired comparison (trajectory error, cm) =====\n');
for q = 1:5
    if q <= 4, v = e(:,q); lab = SEGKR{q}; else, v = ie; lab = 'impact'; end
    a = nan(numel(u),1); b = nan(numel(u),1);
    for i = 1:numel(u)
        m = sj == u(i);
        a(i) = mean(v(m & ~sat), 'omitnan');   % non-saturated
        b(i) = mean(v(m &  sat), 'omitnan');   % saturated
    end
    ok = isfinite(a) & isfinite(b);
    [~, p, ~, stt] = ttest(a(ok), b(ok));
    fprintf('  %-10s non-saturated %5.1f  saturated %5.1f  diff %+5.1f  t(%d) = %5.2f, p = %.4f  (%d participants)\n', ...
            lab, mean(a(ok)), mean(b(ok)), mean(b(ok)-a(ok)), stt.df, stt.tstat, p, sum(ok));
    rows(end+1,:) = {lab, mean(a(ok)), mean(b(ok)), mean(b(ok)-a(ok)), stt.tstat, p, sum(ok)}; %#ok<AGROW>
end

writetable(cell2table(rows, 'VariableNames', ...
    {'segment','non-saturated','saturated','diff','t','p','n'}), ...
    fullfile(RES, 'R2_pv_nosat_within.csv'));
fprintf('\nsaved: results/R2_pv_nosat_within.csv\n');

%% helpers
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
function ie = local_impact(S, Dm)
    n = numel(S); ie = nan(n,1);
    for k = 1:n
        st = S(k);
        D = squeeze(Dm(st.subj, st.trial-20, :))';
        if any(isnan(D)), continue; end
        c = local_correct(st.imu_trajCal, D, st.add, st.imp, st.fin);
        ie(k) = norm(st.Mtraj(st.imp,:) - c(st.imp,:))/10;
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
