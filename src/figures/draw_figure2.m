%% General model vs personal model comparison analysis
% ml_traj_check (mae_method=6) based MAE comparison and statistical test

clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

%% data load
load swingData_2508_aftercal_imp+1_est.mat

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [59 115 54]/255;
dark_red   = [170 44 40]/255;
dark_purple = [102 51 153]/255;
soft_purple = [0.749, 0.502, 0.749];
pink = [255,164,179]/255;

color_general = [40 40 120]/255;      % General model - dark navy 

color_personal = [0, 127, 255]/255;   % Personal model - bright blue
color_ref = [0 0 0];                   % Reference - black

OrientationMethod = 7;
mae_method = 6;  % use ml_traj_check
mae_method_vel = 0;

%% folder path settings
mldataDir_general = fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_3');

mldataDir_personal = {
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt1_5');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt2_5');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt3_3');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt4_3');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt5_3');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt6_5');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt7_5');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt8_5');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt9_3');
    fullfile(runsRoot(), 'runs_1218_accgyro_350800_ori0traj_expt10_3');
};

nSubj_ml = 10;
clubs_ml = {'driver','iron','fast'};
nRows_ml = 10; nCols_ml = 3;
nTrials = 10;

ml_start_ref = 351;  % frame 1 of ML corresponds to frame 350 of the reference
ml_end_ref = 800;    % frame 450 of ML corresponds to frame 800 of the reference (799 in practice)

plot_x_start = 320;
plot_x_end = 850;

%% load general model data
fprintf('Loading general model data...\n');
[ml_est_general, ml_traj_est_general] = load_ml_data(mldataDir_general, clubs_ml, nRows_ml, nCols_ml, nTrials, nSubj_ml, []);

%% load personal model data
fprintf('Loading personal model data...\n');
ml_est_personal = struct();
ml_traj_est_personal = struct();
for c = 1:numel(clubs_ml)
    ml_est_personal.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
    ml_traj_est_personal.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
end

for subj = 1:nSubj_ml
    [ml_est_temp, ml_traj_est_temp] = load_ml_data(mldataDir_personal{subj}, clubs_ml, nRows_ml, nCols_ml, nTrials, nSubj_ml, subj);
    
    for c = 1:numel(clubs_ml)
        ml_est_personal.(clubs_ml{c})(:,:,subj) = ml_est_temp.(clubs_ml{c})(:,:,subj);
        ml_traj_est_personal.(clubs_ml{c})(:,subj) = ml_traj_est_temp.(clubs_ml{c})(:,subj);
    end
end

%% MAE computation
mae_list_general = [];
mae_list_personal = [];
mae_norm_list_general = [];
mae_norm_list_personal = [];
subj_id_list = [];
trial_id_list = [];

max_trials_per_subj = 10;
max_frames = 900;
plot_ds_ref_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);        % full reference
plot_ds_ml_general_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml); % general model (on ref frames)
plot_ds_ml_personal_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);% personal model (on ref frames)

event_add_all = nan(max_trials_per_subj, nSubj_ml);
event_bst_all = nan(max_trials_per_subj, nSubj_ml);
event_imp_all = nan(max_trials_per_subj, nSubj_ml);
event_fin_all = nan(max_trials_per_subj, nSubj_ml);

fprintf('\nCalculating MAE for each subject...\n');

for subj = 1:nSubj_ml
    z = 1;  % trial counter for this subject
    club = 1;  % driver only
    
    for trial = 21:30  % normal shot only
        if subj==5 && club==3 && trial==5
            continue
        elseif subj==8 && club==1 && trial==30
            continue
        end
        
        g = swingData_2508(subj).clubN(club).trialN(trial);
        
        g.add = double(g.add);
        g.bst = double(g.bst);
        g.imp = double(g.imp);
        g.fin = double(g.fin);
        
        if g.fin > 900
            g.fin = 900;
        end
        
        WristU = g.marker(:,13:15);
        WristL = g.marker(:,7:9);
        abs_wrist = (WristU + WristL) ./ 2;
        
        Mtraj = abs_wrist - abs_wrist(g.add,:);
        
        ml_traj_general = ml_traj_est_general.(clubs_ml{club}){trial-20, subj};
        ml_traj_personal = ml_traj_est_personal.(clubs_ml{club}){trial-20, subj};
        
        if isempty(ml_traj_general) || isempty(ml_traj_personal)
            fprintf('  [WARN] Subject %d, Trial %d: ML data missing. Skip.\n', subj, trial);
            continue
        end
        
        traj_len = size(ml_traj_general, 1);  % usually 450
        
        eval_len = min(traj_len, ml_end_ref - ml_start_ref + 1);
        
        ref_start_idx = ml_start_ref;  % 350
        ref_end_idx = ml_start_ref + eval_len - 1;  % 799 (450 samples)
        
        ref_segment = Mtraj(ref_start_idx:ref_end_idx, :);
        ml_general_segment = ml_traj_general(1:eval_len, :);
        ml_personal_segment = ml_traj_personal(1:eval_len, :);
        
        error_general = ref_segment - ml_general_segment;
        error_personal = ref_segment - ml_personal_segment;
        
        mae_xyz_general = mean(abs(error_general));
        mae_xyz_personal = mean(abs(error_personal));
        mae_norm_general = mean(vecnorm(error_general, 2, 2));
        mae_norm_personal = mean(vecnorm(error_personal, 2, 2));
        
        mae_list_general = [mae_list_general; mae_xyz_general];
        mae_list_personal = [mae_list_personal; mae_xyz_personal];
        mae_norm_list_general = [mae_norm_list_general; mae_norm_general];
        mae_norm_list_personal = [mae_norm_list_personal; mae_norm_personal];
        subj_id_list = [subj_id_list; subj];
        trial_id_list = [trial_id_list; trial];
        
        plot_ds_ref_all(:, :, z, subj) = Mtraj;
        
        ml_ref_indices = ml_start_ref : (ml_start_ref + traj_len - 1);
        plot_ds_ml_general_all(ml_ref_indices, :, z, subj) = ml_traj_general;
        plot_ds_ml_personal_all(ml_ref_indices, :, z, subj) = ml_traj_personal;
        
        event_add_all(z, subj) = g.add;
        event_bst_all(z, subj) = g.bst;
        event_imp_all(z, subj) = g.imp;
        event_fin_all(z, subj) = g.fin;
        
        z = z + 1;
    end
    
    fprintf('Subject %d: %d trials processed\n', subj, z-1);
end

mae_list_general = mae_list_general.*0.1;
mae_list_personal = mae_list_personal.*0.1;
mae_norm_list_general = mae_norm_list_general.*0.1;
mae_norm_list_personal = mae_norm_list_personal.*0.1;

plot_ds_ref_all = plot_ds_ref_all.*0.1;
plot_ds_ml_general_all = plot_ds_ml_general_all.*0.1;
plot_ds_ml_personal_all = plot_ds_ml_personal_all.*0.1;

%% per-participant MAE summary
fprintf('\n========== Per-participant MAE summary ==========\n');
fprintf('%-6s | %-20s | %-20s | %-10s\n', 'Subj', 'General (mean±std)', 'Personal (mean±std)', 'Diff');
fprintf('%s\n', repmat('-', 1, 70));

mae_subj_general = nan(nSubj_ml, 1);
mae_subj_personal = nan(nSubj_ml, 1);
mae_subj_general_std = nan(nSubj_ml, 1);
mae_subj_personal_std = nan(nSubj_ml, 1);

for subj = 1:nSubj_ml
    idx = subj_id_list == subj;
    if sum(idx) == 0
        continue
    end
    
    mae_g = mae_norm_list_general(idx);
    mae_p = mae_norm_list_personal(idx);
    
    mae_subj_general(subj) = mean(mae_g);
    mae_subj_personal(subj) = mean(mae_p);
    mae_subj_general_std(subj) = std(mae_g);
    mae_subj_personal_std(subj) = std(mae_p);
    
    diff_pct = (mean(mae_g) - mean(mae_p)) / mean(mae_g) * 100;
    
    fprintf('%-6d | %8.2f ± %5.2f cm   | %8.2f ± %5.2f cm   | %+6.1f%%\n', ...
        subj, mean(mae_g), std(mae_g), mean(mae_p), std(mae_p), diff_pct);
end

%% overall statistics summary
fprintf('\n========== Overall MAE statistics ==========\n');
fprintf('General model (General):\n');
fprintf('  MAE norm: %.2f ± %.2f cm\n', mean(mae_norm_list_general), std(mae_norm_list_general));
fprintf('  MAE X: %.2f ± %.2f cm\n', mean(mae_list_general(:,1)), std(mae_list_general(:,1)));
fprintf('  MAE Y: %.2f ± %.2f cm\n', mean(mae_list_general(:,2)), std(mae_list_general(:,2)));
fprintf('  MAE Z: %.2f ± %.2f cm\n', mean(mae_list_general(:,3)), std(mae_list_general(:,3)));

fprintf('\nPersonal model (Personal):\n');
fprintf('  MAE norm: %.2f ± %.2f cm\n', mean(mae_norm_list_personal), std(mae_norm_list_personal));
fprintf('  MAE X: %.2f ± %.2f cm\n', mean(mae_list_personal(:,1)), std(mae_list_personal(:,1)));
fprintf('  MAE Y: %.2f ± %.2f cm\n', mean(mae_list_personal(:,2)), std(mae_list_personal(:,2)));
fprintf('  MAE Z: %.2f ± %.2f cm\n', mean(mae_list_personal(:,3)), std(mae_list_personal(:,3)));

%% statistical significance test
fprintf('\n========== Statistical significance test ==========\n');

fprintf('\n[1] Trial-level Paired Comparison (N=%d trials)\n', length(mae_norm_list_general));
result_trial = compare_methods_local(mae_list_general, mae_list_personal, ...
    'Name', 'General vs Personal (Trial-level)', ...
    'Paired', true, ...
    'Tail', 'left', ...
    'Metric', 'both');

print_stat_result(result_trial);

fprintf('\n[2] Paired Comparison after per-participant mean aggregation (N=%d subjects)\n', nSubj_ml);
result_subj = compare_methods_local(mae_list_general, mae_list_personal, ...
    'Name', 'General vs Personal (Subject-level)', ...
    'Paired', true, ...
    'Tail', 'left', ...
    'Group', subj_id_list, ...
    'BySubject', true, ...
    'Metric', 'both');

print_stat_result(result_subj);

%% Figure 4: mean Trajectory comparison over all Trials of one participant (3x1 subplot)
subj_plot = 1;  % participant number to plot (change to the desired participant)

n_trials_subj = sum(~isnan(squeeze(plot_ds_ref_all(1,1,:,subj_plot))));

ref_data = squeeze(plot_ds_ref_all(:,:,1:n_trials_subj, subj_plot));      % [900 x 3 x n_trials]
ml_general_data = squeeze(plot_ds_ml_general_all(:,:,1:n_trials_subj, subj_plot));
ml_personal_data = squeeze(plot_ds_ml_personal_all(:,:,1:n_trials_subj, subj_plot));

events_add = event_add_all(1:n_trials_subj, subj_plot);
events_bst = event_bst_all(1:n_trials_subj, subj_plot);
events_imp = event_imp_all(1:n_trials_subj, subj_plot);
events_fin = event_fin_all(1:n_trials_subj, subj_plot);

event_add_mean = mean(events_add, 'omitnan');
event_add_std = std(events_add, 0, 'omitnan');
event_bst_mean = mean(events_bst, 'omitnan');
event_bst_std = std(events_bst, 0, 'omitnan');
event_imp_mean = mean(events_imp, 'omitnan');
event_imp_std = std(events_imp, 0, 'omitnan');
event_fin_mean = mean(events_fin, 'omitnan');
event_fin_std = std(events_fin, 0, 'omitnan');

ref_mean = mean(ref_data, 3, 'omitnan');           % [900 x 3]
ref_std = std(ref_data, 0, 3, 'omitnan');
ml_general_mean = mean(ml_general_data, 3, 'omitnan');
ml_general_std = std(ml_general_data, 0, 3, 'omitnan');
ml_personal_mean = mean(ml_personal_data, 3, 'omitnan');
ml_personal_std = std(ml_personal_data, 0, 3, 'omitnan');

x_frames = (plot_x_start:plot_x_end)';

figure('Position', [100,349,600,551]);

axis_labels = {'X', 'Y', 'Z'};
for k = 1:3
    subplot(3,1,k);
    hold on;
    
    ref_plot_data = ref_mean(plot_x_start:plot_x_end, k);
    y_min = min(ref_plot_data) - 10;
    y_max = max(ref_plot_data) + 10;
    
    event_color = [0.8 0.8 0.8];
    event_alpha = 0.3;
    
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    xline(ml_start_ref, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');

    ref_upper = ref_mean(plot_x_start:plot_x_end, k) + ref_std(plot_x_start:plot_x_end, k);
    ref_lower = ref_mean(plot_x_start:plot_x_end, k) - ref_std(plot_x_start:plot_x_end, k);
    fill([x_frames; flipud(x_frames)], [ref_upper; flipud(ref_lower)], ...
         color_ref, 'EdgeColor', 'none', 'FaceAlpha', 0.15, 'HandleVisibility', 'off');
    
    ml_valid_idx = ml_start_ref:ml_end_ref;
    ml_x = ml_valid_idx';
    ml_gen_upper = ml_general_mean(ml_valid_idx, k) + ml_general_std(ml_valid_idx, k);
    ml_gen_lower = ml_general_mean(ml_valid_idx, k) - ml_general_std(ml_valid_idx, k);
    valid_gen = ~isnan(ml_gen_upper) & ~isnan(ml_gen_lower);
    if any(valid_gen)
        fill([ml_x(valid_gen); flipud(ml_x(valid_gen))], ...
             [ml_gen_upper(valid_gen); flipud(ml_gen_lower(valid_gen))], ...
             color_general, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    
    ml_pers_upper = ml_personal_mean(ml_valid_idx, k) + ml_personal_std(ml_valid_idx, k);
    ml_pers_lower = ml_personal_mean(ml_valid_idx, k) - ml_personal_std(ml_valid_idx, k);
    valid_pers = ~isnan(ml_pers_upper) & ~isnan(ml_pers_lower);
    if any(valid_pers)
        fill([ml_x(valid_pers); flipud(ml_x(valid_pers))], ...
             [ml_pers_upper(valid_pers); flipud(ml_pers_lower(valid_pers))], ...
             color_personal, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    
    plot(x_frames, ref_mean(plot_x_start:plot_x_end, k), '-', ...
         'Color', color_ref, 'LineWidth', 2, 'DisplayName', 'Reference');
    
    valid_gen_mean = ~isnan(ml_general_mean(ml_valid_idx, k));
    plot(ml_x(valid_gen_mean), ml_general_mean(ml_valid_idx(valid_gen_mean), k), '-', ...
         'Color', color_general, 'LineWidth', 1.5, 'DisplayName', 'General Model');
    
    valid_pers_mean = ~isnan(ml_personal_mean(ml_valid_idx, k));
    plot(ml_x(valid_pers_mean), ml_personal_mean(ml_valid_idx(valid_pers_mean), k), '-', ...
         'Color', color_personal, 'LineWidth', 1.5, 'DisplayName', 'Personal Model');
    
    xlim([plot_x_start plot_x_end]);
    ylim([y_min y_max]);
    
    
    
    hold off;
end

%% Figure 5: 3D Trajectory comparison (participant mean)
figure('Position', [100, 100, 800, 600]);
hold on;

plot3(ref_mean(plot_x_start:800, 1), ...
      ref_mean(plot_x_start:800, 2), ...
      ref_mean(plot_x_start:800, 3), ...
      '-', 'Color', color_ref, 'LineWidth', 2, 'DisplayName', 'Reference');

valid_gen_3d = ~isnan(ml_general_mean(ml_valid_idx, 1));
plot3(ml_general_mean(ml_valid_idx(valid_gen_3d)-2, 1), ...
      ml_general_mean(ml_valid_idx(valid_gen_3d)-2, 2), ...
      ml_general_mean(ml_valid_idx(valid_gen_3d)-2, 3), ...
      '-', 'Color', color_general, 'LineWidth', 1.5, 'DisplayName', 'General Model');

valid_pers_3d = ~isnan(ml_personal_mean(ml_valid_idx, 1));
plot3(ml_personal_mean(ml_valid_idx(valid_pers_3d)-10, 1), ...
      ml_personal_mean(ml_valid_idx(valid_pers_3d)-10, 2), ...
      ml_personal_mean(ml_valid_idx(valid_pers_3d)-10, 3), ...
      '-', 'Color', color_personal, 'LineWidth', 1.5, 'DisplayName', 'Personal Model');

xlabel('X (cm)'); ylabel('Y (cm)'); zlabel('Z (cm)');
axis equal;
view(3);
hold off;

%% save results
results = struct();
results.mae_list_general = mae_list_general;
results.mae_list_personal = mae_list_personal;
results.mae_norm_list_general = mae_norm_list_general;
results.mae_norm_list_personal = mae_norm_list_personal;
results.mae_subj_general = mae_subj_general;
results.mae_subj_personal = mae_subj_personal;
results.mae_subj_general_std = mae_subj_general_std;
results.mae_subj_personal_std = mae_subj_personal_std;
results.subj_id_list = subj_id_list;
results.trial_id_list = trial_id_list;
results.stat_trial = result_trial;
results.stat_subj = result_subj;
results.plot_ds_ref = plot_ds_ref_all;
results.plot_ds_ml_general = plot_ds_ml_general_all;
results.plot_ds_ml_personal = plot_ds_ml_personal_all;
results.event_add = event_add_all;
results.event_bst = event_bst_all;
results.event_imp = event_imp_all;
results.event_fin = event_fin_all;

save('general_vs_personal_model_comparison.mat', 'results');
fprintf('\nResults saved to general_vs_personal_model_comparison.mat.\n');

function print_stat_result(result)
    if isfield(result, 'mag')
        r = result.mag;
        fprintf('\n  [MAG] %s\n', r.label);
        fprintf('    Test: %s\n', r.test);
        fprintf('    Mean A (General): %.3f, Mean B (Personal): %.3f\n', r.meanA, r.meanB);
        fprintf('    Mean Diff: %.3f\n', r.meanDiff);
        fprintf('    p-value: %f %s\n', r.p, get_sig_stars(r.p));
        if isfield(r, 'es')
            fprintf('    Effect size (%s): %.3f\n', r.eff, r.es);
        end
    end
    
    if isfield(result, 'axis')
        for d = 1:numel(result.axis)
            r = result.axis{d};
            fprintf('\n  [AXIS %d] %s\n', d, r.label);
            fprintf('    Test: %s\n', r.test);
            fprintf('    Mean A (General): %.3f, Mean B (Personal): %.3f\n', r.meanA, r.meanB);
            fprintf('    Mean Diff: %.3f\n', r.meanDiff);
            fprintf('    p-value: %f %s\n', r.p, get_sig_stars(r.p));
            if isfield(r, 'es')
                fprintf('    Effect size (%s): %.3f\n', r.eff, r.es);
            end
        end
    end
end

function stars = get_sig_stars(p)
    if p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = 'n.s.';
    end
end

function out = compare_methods_local(A, B, varargin)
    p = inputParser;
    addParameter(p,'Name','comparison');
    addParameter(p,'Paired',true);
    addParameter(p,'Tail','both');
    addParameter(p,'Group',[]);
    addParameter(p,'BySubject',false);
    addParameter(p,'Metric','both');
    addParameter(p,'Test','auto');
    parse(p,varargin{:});
    opt = p.Results;

    keep = all(isfinite(A),2) & all(isfinite(B),2);
    A = A(keep,:);  B = B(keep,:);
    if ~isempty(opt.Group), opt.Group = opt.Group(keep); end

    if opt.BySubject && ~isempty(opt.Group)
        [A,B] = aggregate_by_group_local(A,B,opt.Group,@mean);
    end

    D = size(A,2);
    out = struct('name',opt.Name,'N',size(A,1),'options',opt);

    if any(strcmpi(opt.Metric, {'both','mag'}))
        Am = sqrt(sum(A.^2,2));  Bm = sqrt(sum(B.^2,2));
        out.mag = run_test_local(Am, Bm, opt);
        out.mag.label = sprintf('%s | MAG', opt.Name);
    end

    if any(strcmpi(opt.Metric, {'both','axis'}))
        out.axis = cell(1,D);
        for d = 1:D
            out.axis{d} = run_test_local(A(:,d), B(:,d), opt);
            out.axis{d}.label = sprintf('%s | Axis %d', opt.Name, d);
        end
    end
end

function [Xg,Yg] = aggregate_by_group_local(X,Y,g,fun)
    ug = unique(g(:));
    Xg = zeros(numel(ug), size(X,2));
    Yg = zeros(numel(ug), size(Y,2));
    for k = 1:numel(ug)
        m = (g==ug(k));
        Xg(k,:) = fun(X(m,:), 1);
        Yg(k,:) = fun(Y(m,:), 1);
    end
end

function res = run_test_local(A, B, opt)
    res = struct('label',opt.Name,'paired',opt.Paired,'tail',opt.Tail);
    if opt.Paired
        diff = A - B; n = numel(diff);
        [useT, p_norm] = normal_decision_local(diff, opt.Test);
        if useT
            [h,p,ci,stats] = ttest(A,B,'Tail',opt.Tail);
            dz = mean(diff)/std(diff);
            res.test='paired t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='dz'; res.es=dz; res.n=n;
        else
            [p,h,stats] = signrank(A,B,'tail',tail_to_signrank_local(opt.Tail));
            n_eff = sum(A~=B);
            res.test='Wilcoxon signed-rank'; res.p=p; res.h=h; res.n=n_eff;

            if isfield(stats,'zval')
                z = stats.zval;
                r = z / sqrt(n_eff);
                res.approx = true;
                res.z = z; res.eff = 'r (z/sqrt(n))'; res.es = r;
            else
                Wplus = stats.signedrank;
                Rsum  = n_eff*(n_eff+1)/2;
                r_rb  = (2*Wplus - Rsum) / Rsum;
                res.approx = false;
                res.eff = 'rank-biserial r'; res.es = r_rb;
            end
        end
        res.normality_p = p_norm;
        res.meanA = mean(A); res.meanB = mean(B); res.meanDiff = mean(diff);
    else
        n1=numel(A); n2=numel(B);
        [useT, ~] = normal_decision_local([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;
        else
            [p,h,stats] = ranksum(A,B,'tail',tail_to_ranksum_local(opt.Tail));
            res.test='Mann-Whitney U'; res.p=p; res.h=h; res.n1=n1; res.n2=n2;

            if isfield(stats,'zval')
                z = stats.zval;
                r = z / sqrt(n1+n2);
                res.approx = true;
                res.z = z; res.eff='r (z/sqrt(N))'; res.es=r;
            else
                W = stats.ranksum;
                U1 = W - n1*(n1+1)/2;
                r_rb = 1 - 2*U1/(n1*n2);
                res.approx = false;
                res.eff='rank-biserial r'; res.es=r_rb;
            end
            res.meanA = mean(A); res.meanB = mean(B);
        end
    end
end

function [useT, p_norm] = normal_decision_local(x, how)
    useT = true; p_norm = NaN;
    switch lower(how)
        case 't',         useT = true;
        case 'nonparam',  useT = false;
        otherwise
            try
                [h,p_norm] = lillietest(x);
                useT = ~h;
            catch
                useT = numel(x) >= 8;
            end
    end
end

function tail = tail_to_signrank_local(t)
    switch lower(t)
        case 'left',  tail='left';
        case 'right', tail='right';
        otherwise,    tail='both';
    end
end

function tail = tail_to_ranksum_local(t)
    switch lower(t)
        case 'left',  tail='smaller';
        case 'right', tail='larger';
        otherwise,    tail='both';
    end
end
