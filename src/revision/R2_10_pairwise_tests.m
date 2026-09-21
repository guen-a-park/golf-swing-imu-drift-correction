%% [R2-10] R2_10_pairwise_tests.m
%  Computes in one pass the paired tests for the places where the response only said "decreased / increased".
%  Output : revision/results/R2_10_pairwise_tests.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M  = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
TW = readtable(fullfile(RES, 'gyro_saturation_trialwise.csv'));
TW = TW(strcmp(string(TW.clubName), "driver"), :);

SEG = {'backswing','add','bst'; 'downswing','bst','imp'; ...
       'follow-through','imp','fin'; 'whole swing','add','fin'};
n = numel(S); sj = nan(n,1); sat = false(n,1);
for k = 1:n
    sj(k) = S(k).subj;
    t = TW(TW.subj == S(k).subj & TW.trial == S(k).trial, :);
    if ~isempty(t), sat(k) = logical(t.isSaturated(1)); end
end
rows = {};

%% (1) [A2] constant club length vs measured distance
fprintf([NL '===== (1) [A2] constant club length vs measured distance =====' NL]);
eC = nan(n,1); eT = nan(n,1); tC = nan(n,4); tT = nan(n,4);
for k = 1:n
    st = S(k);
    r = Md(Md.subj == st.subj & Md.trial == st.trial, :);
    if isempty(r), continue; end
    Dref = [r.Dref_x(1) r.Dref_y(1) r.Dref_z(1)];
    Dvid = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
    eC(k) = norm(Dvid - Dref)/10;
    cC = local_correct(st.imu_trajCal, Dvid, st.add, st.imp, st.fin);
    cT = local_correct(st.imu_trajCal, Dref, st.add, st.imp, st.fin);
    for q = 1:4
        i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
        tC(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - cC(i0:i1,:), 2, 2))/10;
        tT(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - cT(i0:i1,:), 2, 2))/10;
    end
end
for q = 1:4
    rows = [rows; local_pair(sprintf('[A2] video D vs mocap D, %s', SEG{q,1}), ...
        tC(:,q), tT(:,q), sj, true(n,1))]; %#ok<AGROW>
end

%% (2) [A6] velocity anchor
fprintf([NL '===== (2) [A6] velocity anchor target 0 vs measured velocity =====' NL]);
Dml = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));
eZ = nan(n,4); eV = nan(n,4); fs = 200; ts = 1/fs;
for k = 1:n
    st = S(k);
    r = Md(Md.subj == st.subj & Md.trial == st.trial, :);
    if isempty(r), continue; end
    D = squeeze(Dml(st.subj, st.trial-20, :))';
    if any(isnan(D)), continue; end
    vmB = [r.vBST_x(1) r.vBST_y(1) r.vBST_z(1)];
    vmF = [r.vFIN_x(1) r.vFIN_y(1) r.vFIN_z(1)];
    N = size(st.imu_trajCal,1); d = zeros(N,3);
    i1 = st.add:st.bst; w1 = (i1-st.add)'/(st.bst-st.add); d(i1,:) = -w1.*vmB;
    i2 = st.bst:st.fin; w2 = (i2-st.bst)'/(st.fin-st.bst); d(i2,:) = -vmB + w2.*(vmB-vmF);
    dx = cumtrapz(ts, d); dx = dx - dx(st.add,:);
    cZ = local_correct(st.imu_trajCal,      D, st.add, st.imp, st.fin);
    cV = local_correct(st.imu_trajCal - dx, D, st.add, st.imp, st.fin);
    for q = 1:4
        i0 = st.(SEG{q,2}); i9 = st.(SEG{q,3});
        eZ(k,q) = mean(vecnorm(st.Mtraj(i0:i9,:) - cZ(i0:i9,:), 2, 2))/10;
        eV(k,q) = mean(vecnorm(st.Mtraj(i0:i9,:) - cV(i0:i9,:), 2, 2))/10;
    end
end
for q = 1:4
    rows = [rows; local_pair(sprintf('[A6] zero velocity vs measured velocity, %s', SEG{q,1}), ...
        eZ(:,q), eV(:,q), sj, true(n,1))]; %#ok<AGROW>
end

%% (3) [A8] heading alignment
fprintf([NL '===== (3) [A8] magnetometer heading vs aligned heading =====' NL]);
O7 = readtable(fullfile(RES, 'orientation_saturation_trialwise.csv'));
O8 = readtable(fullfile(RES, 'R2_08_ori8_trialwise.csv'));
ocol = {'errBackswing','errDownswing','errFollowThrough','errEntireSwing'};
for q = 1:4
    rows = [rows; local_pair(sprintf('[A8] orientation error %s (deg)', SEG{q,1}), ...
        O7.(ocol{q}), O8.(ocol{q}), O7.subj, true(height(O7),1))]; %#ok<AGROW>
end
E7 = local_seg(fullfile(RES, 'R2_08_traj_error_seg_ori7_seed3.csv'), SEG);
E8 = local_seg(fullfile(RES, 'R2_08_traj_error_seg_ori8_seed3.csv'), SEG);
for q = 1:4
    rows = [rows; local_pair(sprintf('[A8] trajectory error %s', SEG{q,1}), ...
        E7(:,q), E8(:,q), (1:10)', true(10,1))]; %#ok<AGROW>
end

%% (4) [A9] saturation excluded
fprintf([NL '===== (4) [A9] saturation included vs excluded =====' NL]);
both = [];
for su = unique(O7.subj)'
    if any(O7.isSaturated(O7.subj==su)) && any(~O7.isSaturated(O7.subj==su))
        both(end+1) = su; %#ok<AGROW>
    end
end
fprintf(['participants having both saturated and non-saturated: %s' NL], mat2str(both));
for q = 1:4
    a = arrayfun(@(s) mean(O7.(ocol{q})(O7.subj==s & ~O7.isSaturated)), both)';
    b = arrayfun(@(s) mean(O7.(ocol{q})(O7.subj==s &  O7.isSaturated)), both)';
    rows = [rows; local_pair2(sprintf('[A9] orientation error %s (deg), non-saturated vs saturated', SEG{q,1}), a, b)]; %#ok<AGROW>
end

%% save
T = cell2table(rows, 'VariableNames', {'comparison','n','mean1','mean2','diff','t','p'});
writetable(T, fullfile(RES, 'R2_10_pairwise_tests.csv'));
fprintf([NL 'saved: results/R2_10_pairwise_tests.csv' NL]);

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
function V = local_seg(f, SEG)
    T = readtable(f); V = nan(10,4);
    key = {'Backswing','Downswing','FollowThrough','EntireSwing'};
    for su = 1:10
        for q = 1:4
            m = T.subj == su & strcmp(string(T.segment), key{q});
            V(su,q) = mean(T.err_norm_cm(m), 'omitnan');
        end
    end
end
function r = local_pair(name, x, y, subj, keep)
    x = x(:); y = y(:); keep = keep(:);
    u = unique(subj);
    a = arrayfun(@(s) mean(x(subj==s & keep), 'omitnan'), u);
    b = arrayfun(@(s) mean(y(subj==s & keep), 'omitnan'), u);
    ok = isfinite(a) & isfinite(b); a = a(ok); b = b(ok);
    r = local_pair2(name, a, b);
end
function r = local_pair2(name, a, b)
    [~, p, ~, st] = ttest(a, b);
    fprintf('%-42s n=%2d  %6.2f -> %6.2f  (%+.2f)  t=%6.2f  p=%.4f\n', ...
        name, numel(a), mean(a), mean(b), mean(b)-mean(a), st.tstat, p);
    r = {name, numel(a), mean(a), mean(b), mean(b)-mean(a), st.tstat, p};
end
