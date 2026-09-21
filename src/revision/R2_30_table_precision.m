%% [R2-30] R2_30_table_precision.m
%  Recomputes the reported table values at full precision before rounding.
%  Output : results/R2_30_table2_precision.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
RES = fullfile(thisDir, 'results');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;

ML = fullfile(fileparts(fileparts(baseDir)), 'multimodal', ...
              'runs_0112_accgyro_400800_ori7traj2');
Dml = nan(10, 10, 3);
for su = 1:10
    f = fullfile(ML, sprintf('subj%d_driver_test_est.csv', su));
    if ~isfile(f), continue; end
    T = readtable(f); m = min(height(T), 10);
    Dml(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
end

nS = numel(S);
subj = nan(nS,1);
evtP = nan(nS,3,3); evtU = nan(nS,3,3);   % [trial x event(BST,IMP,FIN) x axis]
segP = nan(nS,4);                          % [trial x segment]
EV   = {'bst','imp','fin'};
AX   = 'XYZ';
SEG  = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
        'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

for k = 1:nS
    st = S(k); subj(k) = st.subj;
    d = squeeze(Dml(st.subj, st.trial-20, :))';
    if any(~isfinite(d)), continue; end

    traj = st.imu_trajCal;                       % uncorrected IMU integration
    dm   = st.imu_trajCal(st.imp,:) - d;
    for kk = st.add:st.fin
        wgt = (kk - st.add)/(st.imp - st.add);
        traj(kk,:) = st.imu_trajCal(kk,:) - wgt*dm;   % proposed method
    end

    for e = 1:3
        i = st.(EV{e});
        evtP(k,e,:) = abs(st.Mtraj(i,:) - traj(i,:))/10;
        evtU(k,e,:) = abs(st.Mtraj(i,:) - st.imu_trajCal(i,:))/10;
    end
    for r = 1:4
        i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
        segP(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
    end
end

%% Table 2
rows = {};
fprintf('\n===== [R2-30] Table 2, full precision (cm) =====\n');
for e = 1:3
    for a = 1:3
        p = local_agg(evtP(:,e,a), subj);
        u = local_agg(evtU(:,e,a), subj);
        fprintf('%s %s : Proposed %.4f +- %.4f  -> %.1f +- %.1f | Uncorrected %.4f +- %.4f -> %.1f +- %.1f\n', ...
            upper(EV{e}), AX(a), p(1), p(2), p(1), p(2), u(1), u(2), u(1), u(2));
        rows(end+1,:) = {upper(EV{e}), AX(a), p(1), p(2), u(1), u(2)}; %#ok<SAGROW>
    end
end
writetable(cell2table(rows, 'VariableNames', ...
    {'event','axis','proposed_mean','proposed_sd','uncorrected_mean','uncorrected_sd'}), ...
    fullfile(RES, 'R2_30_table2_precision.csv'));

%% Table 3
rows = {};
fprintf('\n===== [R2-30] Table 3, full precision (cm) =====\n');
for r = 1:4
    p = local_agg(segP(:,r), subj);
    fprintf('%-14s : %.4f +- %.4f  -> %.1f +- %.1f\n', SEG{r,1}, p(1), p(2), p(1), p(2));
    rows(end+1,:) = {SEG{r,1}, p(1), p(2)}; %#ok<SAGROW>
end
writetable(cell2table(rows, 'VariableNames', {'segment','mean','sd'}), ...
    fullfile(RES, 'R2_30_table3_precision.csv'));

fprintf('\nsaved to %s\n', RES);

function m = local_agg(v, subj)
    su = unique(subj);
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    m  = [mean(sm) std(sm)];
end
