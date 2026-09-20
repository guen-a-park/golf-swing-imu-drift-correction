%% run_fig10001_20001.m
% correlation analysis script over 5 files for figures 10001 and 20001
%
% usage:
% 1. swing1127_withml_fig5_main.m: set mldataDir to ori7traj_1 and run
%    -> correlation_fold_1.mat is saved automatically
% 2. change mldataDir to ori7traj_2 and run (repeat for 2,3,4,5)
% 3. after running all 5, run this script
%    -> correlation_fold_1.mat ~ correlation_fold_5.mat loaded automatically

clear all; close all; clc;

%% ===== settings =====
dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;
mid_gray = [0.5, 0.5, 0.5];
light_gray = [0.85, 0.85, 0.85];

%% ===== variables for storing results =====
R_imu_all = zeros(5, 1);
p_imu_all = zeros(5, 1);
R_ml_all = zeros(5, 1);
p_ml_all = zeros(5, 1);

all_ratio_mocap = cell(5, 1);
all_ratio_imu = cell(5, 1);
all_ratio_ml = cell(5, 1);


%% ===== load results from .mat files =====
fprintf('\n===== loading correlation_fold_*.mat files =====\n');

for i = 1:5
    mat_filename = sprintf('correlation_fold_%d.mat', i);
    
    if isfile(mat_filename)
        data = load(mat_filename);
        
        % dynamic access by variable name
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


%% ===== correlation coefficient computation =====
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

% R value statistics (valid data only)
valid_idx = ~cellfun(@isempty, all_ratio_mocap);
R_imu_mean = mean(R_imu_all(valid_idx));
R_imu_std = std(R_imu_all(valid_idx));
R_ml_mean = mean(R_ml_all(valid_idx));
R_ml_std = std(R_ml_all(valid_idx));

fprintf('\n===== R value summary (%d files) =====\n', valid_count);
fprintf('IMU: R = %.3f ± %.3f\n', R_imu_mean, R_imu_std);
fprintf('ML:  R = %.3f ± %.3f\n', R_ml_mean, R_ml_std);


%% ===== figure(10001) - overlay of 5 IMU files =====
figure(10001);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

for file_idx = 1:5
    if ~isempty(all_ratio_mocap{file_idx})
        x = all_ratio_mocap{file_idx};
        y = all_ratio_imu{file_idx};
        
        scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_red, 'MarkerFaceAlpha', 1);
        
        % regression line
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


%% ===== figure(20001) - overlay of 5 ML files =====
figure(20001);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

for file_idx = 1:5
    if ~isempty(all_ratio_mocap{file_idx})
        x = all_ratio_mocap{file_idx};
        y = all_ratio_ml{file_idx};
        
        scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_green, 'MarkerFaceAlpha', 1);
        
        % regression line
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

%% ===== figure(10002) - IMU 5th model only =====

% change this number to change the plot

figure(10002);
clf;
set(gcf, 'Position', [508.2,421.8,308.8,282.4]);
hold on;

if ~isempty(all_ratio_mocap{2})
    x = all_ratio_mocap{2};
    y = all_ratio_imu{2};
    
    scatter(x, y, 30, 'filled', 'MarkerFaceColor', dark_red, 'MarkerFaceAlpha', 1);
    
    % regression line
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
% top border line (no ticks)
plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(2) ax.YLim(2)], 'k-', 'LineWidth', 0.5);
% right border line (no ticks)
plot([ax.XLim(2) ax.XLim(2)], [ax.YLim(1) ax.YLim(2)], 'k-', 'LineWidth', 0.5);

hold off;



%% ===== figure(20002) - ML 5th model only =====
%% ===== figure(10003) - figure(10002) export version (8 cm, Gill Sans 15 pt) =====
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
    
    % regression line
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


%% ===== save SVG =====
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


%% ===== console output summary =====
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


% %% ===== commented out below =====
% 
% %% ===== merge all data (for the new figure) =====
% all_mocap_combined = [];
% all_imu_combined = [];
% all_ml_combined = [];
% 
% for i = 1:5
%     if ~isempty(all_ratio_mocap{i})
%         all_mocap_combined = [all_mocap_combined; all_ratio_mocap{i}(:)];
%         all_imu_combined = [all_imu_combined; all_ratio_imu{i}(:)];
%         all_ml_combined = [all_ml_combined; all_ratio_ml{i}(:)];
%     end
% end
% 
% % residual computation
% residual_imu = all_imu_combined - all_mocap_combined;
% residual_ml = all_ml_combined - all_mocap_combined;
% 
% % RMSE computation
% rmse_imu = sqrt(mean(residual_imu.^2));
% rmse_ml = sqrt(mean(residual_ml.^2));
% 
% % LOA computation (Bland-Altman)
% mean_diff_imu = mean(residual_imu);
% std_diff_imu = std(residual_imu);
% loa_upper_imu = mean_diff_imu + 1.96 * std_diff_imu;
% loa_lower_imu = mean_diff_imu - 1.96 * std_diff_imu;
% 
% mean_diff_ml = mean(residual_ml);
% std_diff_ml = std(residual_ml);
% loa_upper_ml = mean_diff_ml + 1.96 * std_diff_ml;
% loa_lower_ml = mean_diff_ml - 1.96 * std_diff_ml;
% 
% fprintf('IMU std=%.2f%%, ML std=%.2f%%\n', std_diff_imu, std_diff_ml);
% 
% fprintf('\n===== RMSE (relative to y=x) =====\n');
% fprintf('IMU RMSE: %.2f%%\n', rmse_imu);
% fprintf('ML RMSE:  %.2f%%\n', rmse_ml);
% 
% fprintf('\n===== LOA (Limits of Agreement) =====\n');
% fprintf('IMU: Bias=%.1f%%, LOA=[%.1f, %.1f], range=%.1f%%\n', ...
%     mean_diff_imu, loa_lower_imu, loa_upper_imu, loa_upper_imu - loa_lower_imu);
% fprintf('ML:  Bias=%.1f%%, LOA=[%.1f, %.1f], range=%.1f%%\n', ...
%     mean_diff_ml, loa_lower_ml, loa_upper_ml, loa_upper_ml - loa_lower_ml);
% 
% 
% %% ===== figure(10003) - IMU residual histogram =====
% figure(10003);
% clf;
% hold on;
% 
% edges = -60:5:60;
% histogram(residual_imu, edges, 'FaceColor', dark_red, 'FaceAlpha', 0.7, 'EdgeColor', 'w');
% xline(0, 'k--', 'LineWidth', 1.5);
% xline(mean(residual_imu), 'Color', dark_red, 'LineWidth', 2, 'LineStyle', '-');
% 
% xlabel('Residual (Estimated - GT) (%)');
% ylabel('Count');
% xlim([-60 60]);
% grid on;
% hold off;
% 
% 
% %% ===== figure(10004) - ML residual histogram =====
% figure(10004);
% clf;
% hold on;
% 
% histogram(residual_ml, edges, 'FaceColor', dark_green, 'FaceAlpha', 0.7, 'EdgeColor', 'w');
% xline(0, 'k--', 'LineWidth', 1.5);
% xline(mean(residual_ml), 'Color', dark_green, 'LineWidth', 2, 'LineStyle', '-');
% 
% xlabel('Residual (Estimated - GT) (%)');
% ylabel('Count');
% xlim([-60 60]);
% grid on;
% hold off;
% 
% 
% %% ===== figure(10005) - overlay of residual histograms =====
% figure(10005);
% clf;
% hold on;
% 
% histogram(residual_imu, edges, 'FaceColor', dark_red, 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'DisplayName', 'Proposed');
% histogram(residual_ml, edges, 'FaceColor', dark_green, 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'DisplayName', 'End-to-End');
% xline(0, 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
% 
% xlabel('Residual: Estimated - GT (%)');
% ylabel('Count');
% xlim([-60 60]);
% grid on;
% hold off;
% 
% 
% %% ===== figure(10006) - GT Consistency phase-wise error analysis =====
% figure(10006);
% clf;
% 
% bins = [0, 33, 66, 100];
% bin_labels = {'Inconsistent (0-33%)', 'Medium (34-66%)', 'Consistent (67-100%)'};
% 
% residual_imu_by_bin = cell(3, 1);
% residual_ml_by_bin = cell(3, 1);
% 
% for b = 1:3
%     idx = all_mocap_combined >= bins(b) & all_mocap_combined < bins(b+1);
%     if b == 3
%         idx = all_mocap_combined >= bins(b) & all_mocap_combined <= bins(b+1);
%     end
%     residual_imu_by_bin{b} = residual_imu(idx);
%     residual_ml_by_bin{b} = residual_ml(idx);
% end
% 
% subplot(1, 2, 1);
% bar_data_std = [std(residual_imu_by_bin{1}), std(residual_imu_by_bin{2}), std(residual_imu_by_bin{3});
%                 std(residual_ml_by_bin{1}), std(residual_ml_by_bin{2}), std(residual_ml_by_bin{3})]';
% b = bar(bar_data_std);
% b(1).FaceColor = dark_red;
% b(2).FaceColor = dark_green;
% xticklabels(bin_labels);
% xtickangle(15);
% xlabel('GT Consistency Level');
% ylabel('Residual Std (%)');
% legend({'Proposed', 'End-to-End'}, 'Location', 'northwest');
% grid on;
% 
% subplot(1, 2, 2);
% bar_data_abs = [mean(abs(residual_imu_by_bin{1})), mean(abs(residual_imu_by_bin{2})), mean(abs(residual_imu_by_bin{3}));
%                 mean(abs(residual_ml_by_bin{1})), mean(abs(residual_ml_by_bin{2})), mean(abs(residual_ml_by_bin{3}))]';
% b = bar(bar_data_abs);
% b(1).FaceColor = dark_red;
% b(2).FaceColor = dark_green;
% xticklabels(bin_labels);
% xtickangle(15);
% xlabel('GT Consistency Level');
% ylabel('Mean Absolute Error (%)');
% legend({'Proposed', 'End-to-End'}, 'Location', 'northwest');
% grid on;
% 
% 
% %% ===== figure(10007) - underestimation ratio in the Consistent range =====
% figure(10007);
% clf;
% 
% consistent_idx = all_mocap_combined >= 67;
% residual_imu_consistent = residual_imu(consistent_idx);
% residual_ml_consistent = residual_ml(consistent_idx);
% 
% threshold = -10;
% underest_imu = sum(residual_imu_consistent < threshold) / length(residual_imu_consistent) * 100;
% underest_ml = sum(residual_ml_consistent < threshold) / length(residual_ml_consistent) * 100;
% 
% subplot(1, 2, 1);
% hold on;
% histogram(residual_imu_consistent, -60:5:30, 'FaceColor', dark_red, 'FaceAlpha', 0.6, 'EdgeColor', 'w');
% histogram(residual_ml_consistent, -60:5:30, 'FaceColor', dark_green, 'FaceAlpha', 0.6, 'EdgeColor', 'w');
% xline(0, 'k--', 'LineWidth', 1.5);
% xline(threshold, 'r-', 'LineWidth', 1.5);
% xlabel('Residual in Consistent Swings (%)');
% ylabel('Count');
% legend({'Proposed', 'End-to-End'}, 'Location', 'northwest');
% xlim([-60 30]);
% grid on;
% hold off;
% 
% subplot(1, 2, 2);
% bar_data = [underest_imu; underest_ml];
% b = bar(bar_data);
% b.FaceColor = 'flat';
% b.CData(1,:) = dark_red;
% b.CData(2,:) = dark_green;
% xticklabels({'Proposed', 'End-to-End'});
% ylabel(sprintf('Underestimation Rate (residual < %d%%)', threshold));
% ylim([0 max(bar_data)*1.3]);
% grid on;
% 
% text(1, underest_imu + 2, sprintf('%.1f%%', underest_imu), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
% text(2, underest_ml + 2, sprintf('%.1f%%', underest_ml), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
% 
% 
% %% ===== figure(10008) - LOA range comparison =====
% figure(10008);
% clf;
% hold on;
% 
% loa_range_imu = loa_upper_imu - loa_lower_imu;
% loa_range_ml = loa_upper_ml - loa_lower_ml;
% 
% bar_data = [loa_range_imu; loa_range_ml];
% b = bar(bar_data);
% b.FaceColor = 'flat';
% b.CData(1,:) = dark_red;
% b.CData(2,:) = dark_green;
% xticklabels({'Proposed', 'End-to-End'});
% ylabel('LOA Range (%)');
% grid on;
% 
% text(1, loa_range_imu + 1, sprintf('%.1f%%', loa_range_imu), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
% text(2, loa_range_ml + 1, sprintf('%.1f%%', loa_range_ml), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
% 
% hold off;
