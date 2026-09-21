%% [R2-1] R2_01_target_uncertainty.m
%  Quantifies how much the uncertainty of the training target (D_Vision) propagates into the final IMU-based correction.
%  Output : revision/results/R2_01_target_uncertainty.csv        (error by interval)

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
RES = fullfile(thisDir, 'results');

%% materials
load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1, :);

ML = fullfile(fileparts(fileparts(baseDir)), 'multimodal', ...
              'runs_0112_accgyro_400800_ori7traj2');     % model adopted in the manuscript
Dinf = nan(10, 10, 3);
for su = 1:10
    f = fullfile(ML, sprintf('subj%d_driver_test_est.csv', su));
    if ~isfile(f), continue; end
    T = readtable(f); m = min(height(T), 10);
    Dinf(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
end

SEG  = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
        'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
COND = {'D_ref','D_Vision','D_Infer'};

nS   = numel(S);
subj = nan(nS,1);
err  = nan(nS, 4, 3);        % [trial x segment x condition]
eIMP = nan(nS, 3);           % impact error
dErr = nan(nS, 3, 3);        % [trial x axis x condition] : D estimation error

%% computation
for k = 1:nS
    st = S(k); subj(k) = st.subj;

    row = M(M.subj == st.subj & M.trial == st.trial, :);
    if isempty(row), continue; end
    Dref = [row.Dref_x, row.Dref_y, row.Dref_z];
    Dvid = [row.Dvid_x, row.Dvid_y, row.Dvid_z];
    Dml  = squeeze(Dinf(st.subj, st.trial - 20, :))';
    if any(~isfinite([Dref Dvid Dml])), continue; end

    Ds = {Dref, Dvid, Dml};
    for c = 1:3
        dErr(k,:,c) = (Ds{c} - Dref) / 10;                 % cm
        traj = local_correct(st, Ds{c});
        for r = 1:4
            i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
            err(k,r,c) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2)) / 10;
        end
        eIMP(k,c) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:)) / 10;
    end
end

%% Table 1. trajectory error by interval
rows = {};
fprintf('\n===== [R2-1] propagation of training target uncertainty (driver test, participant level, cm), cm) =====\n');
fprintf('%-16s %14s %14s %14s\n', 'Segment', COND{:});
for r = 1:4
    v = zeros(1,3);
    for c = 1:3
        a = local_agg(err(:,r,c), subj);  v(c) = a(1);
        sd(c) = a(2); %#ok<AGROW>
    end
    fprintf('%-16s %7.1f ± %-5.1f %7.1f ± %-5.1f %7.1f ± %-5.1f\n', SEG{r,1}, ...
        v(1), sd(1), v(2), sd(2), v(3), sd(3));
    rows(end+1,:) = {SEG{r,1}, v(1), sd(1), v(2), sd(2), v(3), sd(3), ...
                     v(2)-v(1), v(3)-v(2)}; %#ok<SAGROW>
end
v = zeros(1,3);
for c = 1:3
    a = local_agg(eIMP(:,c), subj); v(c) = a(1); sd(c) = a(2);
end
fprintf('%-16s %7.1f ± %-5.1f %7.1f ± %-5.1f %7.1f ± %-5.1f\n', 'Impact (event)', ...
    v(1), sd(1), v(2), sd(2), v(3), sd(3));
rows(end+1,:) = {'Impact', v(1), sd(1), v(2), sd(2), v(3), sd(3), v(2)-v(1), v(3)-v(2)};

writetable(cell2table(rows, 'VariableNames', {'segment', ...
    'Dref_mean','Dref_sd','DVision_mean','DVision_sd','DInfer_mean','DInfer_sd', ...
    'target_uncertainty','inference_error'}), ...
    fullfile(RES, 'R2_01_target_uncertainty.csv'));

fprintf('\nincrease: D_Vision - D_ref = training target uncertainty contribution\n');
fprintf('          D_Infer  - D_Vision = BiLSTM inference error contribution\n');

%% Table 2. per-axis error of D itself
AX = 'XYZ';
rows2 = {};
fprintf('\n===== D error relative to motion capture (cm) =====\n');
fprintf('%-10s %18s %18s\n', 'Axis', 'D_Vision', 'D_Infer');
for a = 1:3
    m2 = local_agg(abs(dErr(:,a,2)), subj);
    m3 = local_agg(abs(dErr(:,a,3)), subj);
    b2 = local_agg(dErr(:,a,2), subj);
    b3 = local_agg(dErr(:,a,3), subj);
    fprintf('%-10s MAE %5.1f bias %+5.1f  MAE %5.1f bias %+5.1f\n', ...
        AX(a), m2(1), b2(1), m3(1), b3(1));
    rows2(end+1,:) = {AX(a), m2(1), m2(2), b2(1), m3(1), m3(2), b3(1)}; %#ok<SAGROW>
end
n2 = local_agg(vecnorm(squeeze(dErr(:,:,2)),2,2), subj);
n3 = local_agg(vecnorm(squeeze(dErr(:,:,3)),2,2), subj);
fprintf('%-10s norm %5.1f ± %4.1f      norm %5.1f ± %4.1f\n', 'total', n2(1), n2(2), n3(1), n3(2));
rows2(end+1,:) = {'norm', n2(1), n2(2), NaN, n3(1), n3(2), NaN};

writetable(cell2table(rows2, 'VariableNames', ...
    {'axis','DVision_MAE','DVision_MAE_sd','DVision_bias', ...
     'DInfer_MAE','DInfer_MAE_sd','DInfer_bias'}), ...
    fullfile(RES, 'R2_01_target_uncertainty_D.csv'));

fprintf('\nsaved: %s\n', fullfile(RES, 'R2_01_target_uncertainty.csv'));
fprintf('saved: %s\n', fullfile(RES, 'R2_01_target_uncertainty_D.csv'));

%% local
function traj = local_correct(st, D)
    traj = st.imu_trajCal;
    dm   = st.imu_trajCal(st.imp,:) - D;
    for kk = st.add:st.fin
        w = (kk - st.add) / (st.imp - st.add);
        traj(kk,:) = st.imu_trajCal(kk,:) - w * dm;
    end
end

function m = local_agg(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    m  = [mean(sm) std(sm)];
end
