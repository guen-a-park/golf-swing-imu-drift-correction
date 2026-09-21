%% run_fig10001_20001.m
% correlation analysis script over 5 files for figures 10001 and 20001

clear all; close all; clc;

%% settings
dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;
mid_gray = [0.5, 0.5, 0.5];
light_gray = [0.85, 0.85, 0.85];

%% variables for storing results
R_imu_all = zeros(5, 1);
p_imu_all = zeros(5, 1);
R_ml_all = zeros(5, 1);
p_ml_all = zeros(5, 1);

all_ratio_mocap = cell(5, 1);
all_ratio_imu = cell(5, 1);
all_ratio_ml = cell(5, 1);

%% load results from .mat files
fprintf('\n===== loading correlation_fold_*.mat files =====\n');

for i = 1:5
    mat_filename = sprintf('correlation_fold_%d.mat', i);
    
    if isfile(mat_filename)
        data = load(mat_filename);
        
        mocap_var = sprintf('ratio_mocap_%d', i);
        imu_var = sprintf('ratio_imu_%d', i);
        ml_var = sprintf('ratio_ml_%d', i);
        
        if isfield(data, mocap_var) && isfield(data, imu_var) && isfield(data, ml_var)
            all_ratio_mocap{i} = data.(mocap_var);
            all_ratio_imu{i} = data.(imu_var);
            all_ratio_ml{i} = data.(ml_var);
            fprintf('  [O] %s loaded\n', mat_filename);
        else
            warning('required variables are missing in %s.', mat_filename);
        end
    else
        warning('file %s not found. Run swing1127_withml_fig5_main.m first.', mat_filename);
    end
end

%% correlation coefficient computation
fprintf('\n===== correlation analysis over 5 files =====\n');

valid_count = 0;
for file_idx = 1:5
    if ~isempty(all_ratio_mocap{file_idx})
        [Rmat, Pmat] = corrcoef(all_ratio_mocap{file_idx}, all_ratio_imu{file_idx});
        R_imu_all(file_idx) = Rmat(1, 2);
        p_imu_all(file_idx) = Pmat(1, 2);
        
        [Rmat, Pmat] = corrcoef(all_ratio_mocap{file_idx}, all_ratio_ml{file_idx});
        R_ml_all(file_idx) = Rmat(1, 2);
        p_ml_all(file_idx) = Pmat(1, 2);
        
        fprintf('ori7traj_%d: IMU R=%.3f (p=%.4g), ML R=%.3f (p=%.4g)\n', ...
            file_idx, R_imu_all(file_idx), p_imu_all(file_idx), ...
            R_ml_all(file_idx), p_ml_all(file_idx));
        
        valid_count = valid_count + 1;
    end
end

if valid_count == 0
    error('no data loaded. Run swing1127_withml_fig5_main.m first.');
end

valid_idx = ~cellfun(@isempty, all_ratio_mocap);
R_imu_mean = mean(R_imu_all(valid_idx));
R_imu_std = std(R_imu_all(valid_idx));
R_ml_mean = mean(R_ml_all(valid_idx));
R_ml_std = std(R_ml_all(valid_idx));

fprintf('\n===== R value summary (%d files) =====\n', valid_count);
fprintf('IMU: R = %.3f ± %.3f\n', R_imu_mean, R_imu_std);
fprintf('ML:  R = %.3f ± %.3f\n', R_ml_mean, R_ml_std);

%% figure(10001) - overlay of 5 IMU files
figure(10001);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

for file_idx = 1:5
    if ~isempty(all_ratio_mocap{file_idx})
        x = all_ratio_mocap{file_idx};
        y = all_ratio_imu{file_idx};
        
        scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_red, 'MarkerFaceAlpha', 1);
        
        p = polyfit(x, y, 1);
        x_fit = linspace(0, 100, 100);
        y_fit = polyval(p, x_fit);
        plot(x_fit, y_fit, 'Color', dark_red, 'LineWidth', 1.5);
    end
end

axis equal;
xlim([0 100]);
ylim([0 100]);
set(gca, 'XTick', 0:20:100, 'YTick', 0:20:100);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
box on;
hold off;

%% figure(20001) - overlay of 5 ML files
figure(20001);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

for file_idx = 1:5
    if ~isempty(all_ratio_mocap{file_idx})
        x = all_ratio_mocap{file_idx};
        y = all_ratio_ml{file_idx};
        
        scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_green, 'MarkerFaceAlpha', 1);
        
        p = polyfit(x, y, 1);
        x_fit = linspace(0, 100, 100);
        y_fit = polyval(p, x_fit);
        plot(x_fit, y_fit, 'Color', dark_green, 'LineWidth', 1.5);
    end
end

axis equal;
xlim([0 100]);
ylim([0 100]);
set(gca, 'XTick', 0:20:100, 'YTick', 0:20:100);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
box on;
hold off;

%% model needs to be changed

%% figure(10002) - IMU 5th model only

figure(10002);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

if ~isempty(all_ratio_mocap{2})
    x = all_ratio_mocap{2};
    y = all_ratio_imu{2};
    
    scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_red, 'MarkerFaceAlpha', 1);
    
    p = polyfit(x, y, 1);
    x_fit = linspace(0, 100, 100);
    y_fit = polyval(p, x_fit);
    plot(x_fit, y_fit, 'Color', dark_red, 'LineWidth', 1.5);
end

axis equal;
xlim([0 100]);
ylim([0 100]);
set(gca, 'XTick', 0:20:100, 'YTick', 0:20:100);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
box off;

ax = gca;
plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(2) ax.YLim(2)], 'k-', 'LineWidth', 0.5);
plot([ax.XLim(2) ax.XLim(2)], [ax.YLim(1) ax.YLim(2)], 'k-', 'LineWidth', 0.5);

hold off;

%% figure(20002) - ML 5th model only
%% figure(10003) - figure(10002) export version (8 cm, Gill Sans 15 pt)
fig10003_size_cm = [9 8.23];  % keep the current 308.8:282.4 aspect ratio
figure(10003);
clf;
set(gcf, 'Color', 'w', 'Units', 'centimeters', ...
         'Position', [2 2 fig10003_size_cm]);
hold on;

if ~isempty(all_ratio_mocap{2})
    x = all_ratio_mocap{2};
    y = all_ratio_imu{2};

    scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_red, 'MarkerFaceAlpha', 1);

    p = polyfit(x, y, 1);
    x_fit = linspace(0, 100, 100);
    y_fit = polyval(p, x_fit);
    plot(x_fit, y_fit, 'Color', dark_red, 'LineWidth', 1.5);
end

axis equal;
xlim([0 100]);
ylim([0 100]);
set(gca, 'XTick', 0:20:100, 'YTick', 0:20:100);
set(gca, 'FontSize', 15, 'FontName', 'Gill Sans MT');
box off;

ax = gca;
plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(2) ax.YLim(2)], 'k-', 'LineWidth', 0.5);
plot([ax.XLim(2) ax.XLim(2)], [ax.YLim(1) ax.YLim(2)], 'k-', 'LineWidth', 0.5);

hold off;
set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig10003_size_cm], ...
         'PaperSize', fig10003_size_cm);
print(gcf, 'fig10002_imu_fold5_9cm.svg', '-dsvg', '-vector');

figure(20002);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

if ~isempty(all_ratio_mocap{2})
    x = all_ratio_mocap{2};
    y = all_ratio_ml{2};
    
    scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_green, 'MarkerFaceAlpha', 1);
    
    p = polyfit(x, y, 1);
    x_fit = linspace(0, 100, 100);
    y_fit = polyval(p, x_fit);
    plot(x_fit, y_fit, 'Color', dark_green, 'LineWidth', 1.5);
end

axis equal;
xlim([0 100]);
ylim([0 100]);
set(gca, 'XTick', 0:20:100, 'YTick', 0:20:100);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
box on;
hold off;

%% save SVG
figure(10001);
print(gcf, 'fig10001_imu_5folds.svg', '-dsvg', '-vector');

figure(20001);
print(gcf, 'fig20001_ml_5folds.svg', '-dsvg', '-vector');

figure(10002);
print(gcf, 'fig10002_imu_fold5.svg', '-dsvg', '-vector');

figure(20002);
print(gcf, 'fig20002_ml_fold5.svg', '-dsvg', '-vector');

fprintf('\n===== SVG files saved =====\n');
fprintf('  fig10001_imu_5folds.svg\n');
fprintf('  fig20001_ml_5folds.svg\n');
fprintf('  fig10002_imu_fold5.svg\n');
fprintf('  fig10002_imu_fold5_9cm.svg\n');
fprintf('  fig20002_ml_fold5.svg\n');

%% console output summary
fprintf('\n===== correlation coefficient per file =====\n');
fprintf('%-12s | %-20s | %-20s\n', 'File', 'IMU (R, p)', 'ML (R, p)');
fprintf('%s\n', repmat('-', 1, 60));
for i = 1:5
    if ~isempty(all_ratio_mocap{i})
        fprintf('ori7traj_%d   | R=%.3f, p=%.4g   | R=%.3f, p=%.4g\n', ...
            i, R_imu_all(i), p_imu_all(i), R_ml_all(i), p_ml_all(i));
    else
        fprintf('ori7traj_%d   | (no data)        | (no data)\n', i);
    end
end
fprintf('%s\n', repmat('-', 1, 60));
fprintf('Mean ± Std   | %.3f ± %.3f         | %.3f ± %.3f\n', ...
    R_imu_mean, R_imu_std, R_ml_mean, R_ml_std);

