%% [R2-3] R2_03_trajectory_by_calib.m
%  Final trajectory error as a function of the number of calibration swings
%  ------------------------------------------------------------------------
%  The proposed trajectory is
%      traj_lin_subj(t) = imu_trajCal(t) - w(t) * (imu_trajCal(IMP) - D_ml)
%      w(t) = (t - ADD) / (IMP - ADD)
%  so with only imu_trajCal and Mtraj, which do not depend on the condition, the trajectory error for any D_ml
%  can be computed immediately. The pipeline need not be rerun for each condition.
%
%  Prerequisite : R2_08_trajectory_error.m generates results/R2_03_traj_store_ori7.mat
%  Input : multimodal/runs_<TAG>/subj*_driver_test_est.csv pred_x/y/z (= D_Infer)
%  Output : revision/results/R2_03_trajectory_by_calib.csv
%         revision/results/fig_R2_03_trajectory_by_calib.png/.svg
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
ML_DIR  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

storeFile = fullfile(OUT_DIR, 'R2_03_traj_store_ori7.mat');
if ~isfile(storeFile)
    error('%s not found. Run R2_08_trajectory_error.m first.', storeFile);
end
load(storeFile, 'R2_03_store');
S = R2_03_store;
fprintf('trajectory store: %d trials\n', numel(S));

%% ===== conditions to evaluate =====
%  {label, run folder prefix (without runs_, seed as %d), seed list}
NCALIB = [3 5 10 15 20];
SEEDS  = 1:5;
PREFIX = 'R2_03m_calib%d_seed%d';    %% gradient-update-matched version
% PREFIX = 'R2_03_calib%d_seed%d';   %% fixed-epoch version

segs = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
        'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

rows = {};
for ni = 1:numel(NCALIB)
    n = NCALIB(ni);
    for s = SEEDS
        runDir = fullfile(ML_DIR, ['runs_' sprintf(PREFIX, n, s)]);
        Dml = local_load_Dml(runDir);
        if isempty(Dml), warning('not found: %s', runDir); continue; end

        % per-participant phase error
        segErr = nan(10, size(segs,1));
        for su = 1:10
            k = find([S.subj] == su);
            if isempty(k), continue; end
            e = nan(numel(k), size(segs,1));
            for kk = 1:numel(k)
                st = S(k(kk));
                d = Dml(su, st.trial - 20, :);      % [1 x 1 x 3]
                if any(~isfinite(d)), continue; end
                traj = local_correct(st.imu_trajCal, squeeze(d)', st.add, st.imp, st.fin);
                for rr = 1:size(segs,1)
                    i0 = st.(segs{rr,2}); i1 = st.(segs{rr,3});
                    df = st.Mtraj(i0:i1,:) - traj(i0:i1,:);
                    e(kk,rr) = mean(vecnorm(df, 2, 2)) / 10;    % mm -> cm
                end
            end
            segErr(su,:) = mean(e, 1, 'omitnan');
        end
        for rr = 1:size(segs,1)
            v = segErr(:,rr); v = v(isfinite(v));
            rows(end+1,:) = {n, s, segs{rr,1}, mean(v), std(v), numel(v)}; %#ok<SAGROW>
        end
    end
end

T = cell2table(rows, 'VariableNames', {'nCalib','seed','segment','err_cm','err_sd_cm','nSubj'});
writetable(T, fullfile(OUT_DIR, 'R2_03_trajectory_by_calib_matched.csv'));

%% ===== output =====
fprintf('\n===== [R2-3] trajectory error vs number of calibration swings (cm) =====\n');
fprintf('participant-level means aggregated over 5 seeds as mean ± SD\n\n');
fprintf('%9s', 'N swings');
for rr = 1:size(segs,1), fprintf(' %18s', segs{rr,1}); end
fprintf('\n');
for ni = 1:numel(NCALIB)
    fprintf('%9d', NCALIB(ni));
    for rr = 1:size(segs,1)
        v = T.err_cm(T.nCalib == NCALIB(ni) & strcmp(T.segment, segs{rr,1}));
        if isempty(v), fprintf(' %18s', '-'); else
            fprintf(' %9.2f ± %-6.2f', mean(v), std(v));
        end
    end
    fprintf('\n');
end
fprintf('\nNote: manuscript values Backswing 14.13 / Downswing 15.13 / Follow-through 32.56 / Entire 19.56 cm\n');

%% ===== figure =====
figure('Color','w','Position',[100 100 900 340]);
for rr = [2 4]      % Downswing, EntireSwing
    subplot(1,2,find([2 4] == rr)); hold on; grid on;
    v = []; g = [];
    for ni = 1:numel(NCALIB)
        x = T.err_cm(T.nCalib == NCALIB(ni) & strcmp(T.segment, segs{rr,1}));
        v = [v; x]; g = [g; repmat(NCALIB(ni), numel(x), 1)]; %#ok<AGROW>
    end
    if ~isempty(v)
        boxplot(v, g, 'Colors', [0.5 0 0.13], 'Symbol', 'o');
    end
    xlabel('Number of calibration swings'); ylabel('Trajectory error (cm)');
    title(segs{rr,1});
end
exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_03_trajectory_by_calib_matched.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_03_trajectory_by_calib_matched.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_03_trajectory_by_calib_matched.csv'));


%% ===== local functions =====
function D = local_load_Dml(runDir)
% reads pred_x/y/z of subj{N}_driver_test_est.csv as [10 subj x 10 trial x 3]
    D = [];
    if ~isfolder(runDir), return; end
    D = nan(10, 10, 3);
    for su = 1:10
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f);
        m = min(height(T), 10);
        D(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end

function traj = local_correct(imu_trajCal, Dml, add, imp, fin)
% same linear distribution correction as the original pipeline
    traj = imu_trajCal;
    diff_ml = imu_trajCal(imp,:) - Dml;
    for k = add:fin
        w = (k - add) / (imp - add);
        traj(k,:) = imu_trajCal(k,:) - w * diff_ml;
    end
    if fin < size(traj,1)
        traj(fin+1:end,:) = repmat(traj(fin,:), size(traj,1)-fin, 1);
    end
end
