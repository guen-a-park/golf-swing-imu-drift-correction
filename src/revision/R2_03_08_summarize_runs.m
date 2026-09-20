%% [R2-3 / R2-8] R2_03_08_summarize_runs.m
%  Aggregates the results of the training runs.
%  ------------------------------------------------------------------------
%  R2-3 : performance curve by number of calibration swings N = 3/5/10/20 (distribution over 5 seeds)
%  R2-8 : ori7 (magnetometer heading) vs ori8 (motion capture heading alignment) comparison
%         Both conditions use N = 20 and 5 seeds so that the protocol matches.
%
%  Metric: constraint D estimation error = |D_Infer - D_Vision| (mm)
%        the L2_err column of each run's subj*_driver_test_est.csv
%        aggregated as per-participant mean -> mean across participants (reflecting the repeated-measures structure, R2-10)
%
%  Prerequisite: multimodal/runs_R2_03_calib{N}_seed{S}, runs_R2_08_ori8_seed{S}
%  Output: revision/results/R2_03_calibration_curve.csv
%        revision/results/R2_08_orientation_condition.csv
%        revision/results/fig_R2_03_calibration_curve.png/.svg
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end
ML_DIR = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

NCALIB = [3 5 10 20];
SEEDS  = 1:5;

%% ===== R2-3 : calibration swing count curve =====
rows = {}; box_v = []; box_g = [];
for ni = 1:numel(NCALIB)
    n = NCALIB(ni);
    for s = SEEDS
        d = fullfile(ML_DIR, sprintf('runs_R2_03_calib%d_seed%d', n, s));
        [mD, mL] = local_run_metrics(d);
        if isnan(mD), warning('not found: %s', d); continue; end
        rows(end+1,:) = {n, s, mD, mL}; %#ok<SAGROW>
        box_v(end+1,1) = mD; box_g(end+1,1) = n; %#ok<SAGROW>
    end
end
T3 = cell2table(rows, 'VariableNames', {'nCalib','seed','D_err_mm','train_loss'});
writetable(T3, fullfile(OUT_DIR, 'R2_03_calibration_curve.csv'));

fprintf('\n===== [R2-3] constraint estimation error by number of calibration swings (driver test) =====\n');
fprintf('%8s %10s %10s %10s %10s %12s\n', 'N swings', 'mean', 'SD', 'min', 'max', 'median');
for ni = 1:numel(NCALIB)
    v = T3.D_err_mm(T3.nCalib == NCALIB(ni));
    if isempty(v), continue; end
    fprintf('%8d %10.2f %10.2f %10.2f %10.2f %12.2f\n', NCALIB(ni), ...
        mean(v), std(v), min(v), max(v), median(v));
end

%% ===== R2-8 : orientation condition comparison =====
rows8 = {};
for s = SEEDS
    d7 = fullfile(ML_DIR, sprintf('runs_R2_03_calib20_seed%d', s));   % ori7, N=20
    d8 = fullfile(ML_DIR, sprintf('runs_R2_08_ori8_seed%d', s));      % ori8, N=20
    [m7, l7] = local_run_metrics(d7);
    [m8, l8] = local_run_metrics(d8);
    rows8(end+1,:) = {s, m7, l7, m8, l8, m8-m7}; %#ok<SAGROW>
end
T8 = cell2table(rows8, 'VariableNames', ...
    {'seed','ori7_D_err','ori7_loss','ori8_D_err','ori8_loss','diff'});
writetable(T8, fullfile(OUT_DIR, 'R2_08_orientation_condition.csv'));

fprintf('\n===== [R2-8] heading alignment condition comparison (N=20, 5 seeds) =====\n');
fprintf('%6s %14s %14s %12s\n', 'seed', 'ori7 (mag)', 'ori8 (mocap yaw)', 'diff');
for r = 1:height(T8)
    fprintf('%6d %14.2f %14.2f %12.2f\n', T8.seed(r), T8.ori7_D_err(r), ...
        T8.ori8_D_err(r), T8.diff(r));
end
v7 = T8.ori7_D_err(isfinite(T8.ori7_D_err));
v8 = T8.ori8_D_err(isfinite(T8.ori8_D_err));
if numel(v7) >= 2 && numel(v8) >= 2
    [~, p] = ttest(v7, v8);
    fprintf('%6s %8.2f ± %-5.2f %8.2f ± %-5.2f %12.2f   (paired p = %.4f)\n', ...
        'mean', mean(v7), std(v7), mean(v8), std(v8), mean(v8-v7), p);
end

%% ===== figure : R2-3 curve =====
if ~isempty(box_v)
    figure('Color','w','Position',[100 100 560 360]); hold on; grid on;
    boxplot(box_v, box_g, 'Colors', [0.5 0 0.13], 'Symbol', 'o');
    xlabel('Number of calibration swings'); ylabel('Constraint error |D_{Infer} - D_{Vision}| (mm)');
    title('Effect of calibration swing count');
    set(gca, 'FontSize', 12);
    exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_03_calibration_curve.png'), 'Resolution', 300);
    saveas(gcf, fullfile(OUT_DIR, 'fig_R2_03_calibration_curve.svg'));
end

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_03_calibration_curve.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_08_orientation_condition.csv'));


%% ===== local functions =====
function [mD, mLoss] = local_run_metrics(runDir)
% aggregate the D error of the driver test as per-participant mean -> mean across participants
    mD = NaN; mLoss = NaN;
    if ~isfolder(runDir), return; end
    f = dir(fullfile(runDir, 'subj*_driver_test_est.csv'));
    if isempty(f), return; end
    sm = nan(numel(f),1);
    for k = 1:numel(f)
        T = readtable(fullfile(runDir, f(k).name));
        if ismember('L2_err', T.Properties.VariableNames)
            sm(k) = mean(T.L2_err, 'omitnan');
        end
    end
    mD = mean(sm, 'omitnan');

    h = fullfile(runDir, 'training_history_history.csv');
    if isfile(h)
        H = readtable(h);
        n = height(H);
        mLoss = mean(H.train_loss(max(1,n-9):n), 'omitnan');
    end
end
