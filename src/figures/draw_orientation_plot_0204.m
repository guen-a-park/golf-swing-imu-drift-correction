%% draw_figure400_401.m
% Figure 400: 3-axis angle error (3x1 subplot) - proposed method (dark_red) only

clc; clear all; close all;
set(groot,'defaultAxesFontSize',14);

%% option settings
show_event_shade = true;   % true: show shade at the event instants, false: show xline only

%% colour definitions
dark_red = [128 0 32]/255;          % proposed method line colour
event_color = [0.85 0.85 0.85];     % event shade colour
event_alpha = 0.4;                   % event shade transparency
event_line_color = [0 0 0];          % event vertical line colour

%% data loading
load swingData_2508_aftercal_imp+1_est.mat

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

OrientationMethod = 7;

%% ML folder path setup
mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2');

nSubj_ml = 10;
clubs_ml = {'driver','iron','fast'};
nRows_ml = 10; nCols_ml = 3;
nTrials = 10;

plot_x_start = 266;
plot_x_end = 880;

%% ML data loading
ml_est = struct();
for c = 1:numel(clubs_ml)
    ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
end

fprintf('Loading ML data...\n');
for subj = 1:nSubj_ml
    club = 1;
    
    fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
    fpath = fullfile(mldataDir, fname);
    
    fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
    fpath_traj = fullfile(mldataDir, fname_traj);
    
    if ~isfile(fpath)
        warning('Missing file: %s', fpath);
        continue
    end
    
    T = readtable(fpath);
    if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
        M = T{:, {'pred_x','pred_y','pred_z'}};
    else
        M = T{:, 1:3};
    end
    
    m = min(size(M,1), nRows_ml);
    ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);
    
    if isfile(fpath_traj)
        T_traj = readtable(fpath_traj);
        unique_trials = unique(T_traj.trial_idx);
        
        for i = 1:numel(unique_trials)
            trial_traj = unique_trials(i);
            idx = T_traj.trial_idx == trial_traj;
            pred_data = [T_traj.pred_x(idx), T_traj.pred_y(idx), T_traj.pred_z(idx)];
            ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;
        end
    end
end

%% initialise the result storage variables
max_frames = 900;
nSubj = 10;
max_trials_per_subj = 10;

angle_error_axis_all = nan(max_frames, 3, max_trials_per_subj, nSubj);
angle_error_quat_all = nan(max_frames, max_trials_per_subj, nSubj);

event_add_all = nan(max_trials_per_subj, nSubj);
event_bst_all = nan(max_trials_per_subj, nSubj);
event_imp_all = nan(max_trials_per_subj, nSubj);
event_fin_all = nan(max_trials_per_subj, nSubj);

%% Butterworth filter
[b, a] = butter(4, cut_freq/(apdm_rate/2));

%% main loop
fprintf('\nProcessing trials...\n');
z_total = 1;

angle_error_plot = [];
for subj = 1:10
    z_subj = 1;
    for club = 1
        
        for trial = 21:30
            if subj==8 && club==1 && trial==30
                continue
            end
            
            g = swingData_2508(subj).clubN(club).trialN(trial);
            
            if subj==10 && club==1 && trial==24
                g.imp_imu1_est = g.imp_imu2_est;
                g.imp_imu1 = g.imp_imu2;
            end
            
            g.add = double(g.add);
            g.bst = double(g.bst);
            g.imp = double(g.imp);
            g.fin = double(g.fin);
            
            if g.fin > 900
                g.fin = 900;
            end
            
            add_est = g.add_est;
            imp_est = g.imp_est;
            rel_est = imp_est - add_est;
            
            event_add_all(z_subj, subj) = g.add;
            event_bst_all(z_subj, subj) = g.bst;
            event_imp_all(z_subj, subj) = g.imp;
            event_fin_all(z_subj, subj) = g.fin;
            
%% marker data
            WristU = g.marker(:,13:15);
            WristM = g.marker(:,10:12);
            WristL = g.marker(:,7:9);
            abs_wrist = (WristU + WristL) ./ 2;
            
            acc_data = g.apdm(:,1:3);
            gyro_data = g.apdm(:,4:6);
            magnet = g.apdm(:,7:9);
            m_cal = magnet;
            
%% compute R2Lw (marker-based orientation)
            Cw = (WristU + WristL) ./ 2;
            Lo = WristL - Cw;
            Mo = WristM - Cw;
            Uo = WristU - Cw;
            
            wL = sqrt(Lo(:,1).^2 + Lo(:,2).^2 + Lo(:,3).^2);
            wM = sqrt(Mo(:,1).^2 + Mo(:,2).^2 + Mo(:,3).^2);
            wU = sqrt(Uo(:,1).^2 + Uo(:,2).^2 + Uo(:,3).^2);
            
            temp_x = Uo ./ wU;
            vprime_xw = Lo ./ wL;
            vprime_top = Mo ./ wM;
            vprime_zw = zeros(length(vprime_xw), 3);
            vprime_yw = zeros(length(vprime_xw), 3);
            
            for i = 1:length(vprime_xw)
                vprime_zw(i,:) = cross(temp_x(i,:), vprime_top(i,:));
            end
            for i = 1:length(vprime_xw)
                vprime_yw(i,:) = cross(temp_x(i,:), vprime_zw(i,:));
            end
            for i = 1:length(vprime_xw)
                vprime_xw(i,:) = cross(vprime_yw(i,:), vprime_zw(i,:));
            end
            
            for i = 1:length(vprime_xw)
                vprime_xw(i,:) = vprime_xw(i,:) / sqrt(sum(vprime_xw(i,:).^2));
                vprime_yw(i,:) = vprime_yw(i,:) / sqrt(sum(vprime_yw(i,:).^2));
                vprime_zw(i,:) = vprime_zw(i,:) / sqrt(sum(vprime_zw(i,:).^2));
            end
            
            R2Lw = zeros(3, 3, length(vprime_xw));
            for j = 1:length(vprime_zw)
                R2Lw(:,:,j) = [vprime_xw(j,:)' vprime_yw(j,:)' vprime_zw(j,:)'];
            end
            
            R2Lwq = zeros(length(time), 4);
            for t = 1:length(time)
                R2Lwq(t,:) = dcm2quatern(R2Lw(:,:,t)');
                if R2Lwq(t,1) < 0
                    R2Lwq(t,:) = -R2Lwq(t,:);
                end
            end
            
%% OrientationMethod = 7
            local_frame = R2Lw(:,:,g.add);
            
            pitch_marker = asin(-local_frame(3,1));
            roll_marker = atan2(local_frame(3,2), local_frame(3,3));
            yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
            
            roll_marker = rad2deg(roll_marker);
            pitch_marker = rad2deg(pitch_marker);
            yaw_marker = rad2deg(yaw_marker);
            
            acclocal_data = acc_data(g.add,:);
            acc_global = [acclocal_data(1); acclocal_data(2); acclocal_data(3)];
            acc_norm = norm(acc_global);
            acc_normalized = acc_global / acc_norm;
            
            ax = acc_normalized(1);
            ay = acc_normalized(2);
            az = acc_normalized(3);
            
            roll = atan2(ay, az);
            pitch = atan2(-ax, sqrt(ay^2 + az^2));
            
            phi = roll;
            theta = pitch;
            
            mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);
            mxh = mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
            myh = my.*cos(phi) - mz.*sin(phi);
            
            psi0_deg = 191.53;
            alpha_deg = rad2deg(atan2(myh, mxh));
            yaw_imu_deg = psi0_deg - alpha_deg;
            yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;
            psi = deg2rad(yaw_imu_deg);
            
            if club == 3
                psi = deg2rad(yaw_marker);
            end
            
            Rx = [1         0           0
                  0 cos(phi) -sin(phi)
                  0 sin(phi)  cos(phi)];
            
            Ry = [ cos(theta) 0 sin(theta)
                   0          1     0
                  -sin(theta) 0 cos(theta)];
            
            Rz = [cos(psi) -sin(psi) 0
                  sin(psi)  cos(psi) 0
                  0         0        1];
            
            global_frame = [1 0 0; 0 1 0; 0 0 1];
            R2tri = Rz * Ry * Rx * global_frame;
            
            Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);
            
            qinf = zeros(length(time), 4);
            for t = 1:length(time)
                qinf(t,:) = dcm2quatern(Rinf(:,:,t)');
                if qinf(t,1) < 0
                    qinf(t,:) = -qinf(t,:);
                end
            end
            
%% compute the angle error (quaternion) - for Figure 401
            angle_error = [];
            for i = 1:length(time)
                qprod = quaternProd(quaternConj(qinf(i,:)), R2Lwq(i,:));
                tempAng = abs(2 * atan2(norm(qprod(2:4)), qprod(1)) * 180/pi);
                if tempAng > 180
                    tempAng = 360 - tempAng;
                end
                angle_error = [angle_error, tempAng];
            end
            
            angle_error_plot = [angle_error_plot angle_error'];
            
%% compute the 3-axis angle error (Euler angles) - for Figure 400
            angle_error_axis = [];
            for i = 1:length(time)
                R1 = R2Lw(:,:,i);
                R2 = Rinf(:,:,i);
                
                R_diff = R2 * R1';  % how much the reference value must be rotated to give the estimate
                
                eul_angles = rotm2eul(R_diff, 'ZYX');
                
                roll_error_deg = rad2deg(eul_angles(3));   % x axis (roll) error
                pitch_error_deg = rad2deg(eul_angles(2));  % y axis (pitch) error
                yaw_error_deg = rad2deg(eul_angles(1));    % z axis (yaw) error
                
                angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];
            end
            
            angle_error_axis_all(:,:,z_subj,subj) = angle_error_axis;
            
            angle_error_quat_all(:,z_subj,subj) = angle_error';
            
            z_subj = z_subj + 1;
            z_total = z_total + 1;
        end
    end
    fprintf('Subject %d: %d trials processed\n', subj, z_subj-1);
end

fprintf('\nTotal trials: %d\n', z_total-1);

%% per-participant mean → overall mean (Subject-level averaging)
subj_axis_means = nan(max_frames, 3, nSubj);   % for Figure 400
subj_quat_means = nan(max_frames, nSubj);       % for Figure 401
subj_event_add = nan(nSubj, 1);
subj_event_bst = nan(nSubj, 1);
subj_event_imp = nan(nSubj, 1);
subj_event_fin = nan(nSubj, 1);

for subj = 1:nSubj
    n_trials_subj = sum(~isnan(squeeze(angle_error_quat_all(1,:,subj))));
    if n_trials_subj > 0
        subj_axis_means(:,:,subj) = mean(angle_error_axis_all(:,:,1:n_trials_subj,subj), 3, 'omitnan');
        subj_quat_means(:,subj) = mean(angle_error_quat_all(:,1:n_trials_subj,subj), 2, 'omitnan');
        subj_event_add(subj) = mean(event_add_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_bst(subj) = mean(event_bst_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_imp(subj) = mean(event_imp_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_fin(subj) = mean(event_fin_all(1:n_trials_subj,subj), 'omitnan');
    end
end

mean_xyz = mean(subj_axis_means, 3, 'omitnan');   % [900 x 3]
std_xyz = std(subj_axis_means, 0, 3, 'omitnan');  % [900 x 3]

m_prop_subj = mean(subj_quat_means, 2, 'omitnan')';   % [1 x 900]
s_prop_subj = std(subj_quat_means, 0, 2, 'omitnan')';  % [1 x 900]

event_add_mean = mean(subj_event_add, 'omitnan');
event_add_std = std(subj_event_add, 0, 'omitnan');
event_bst_mean = mean(subj_event_bst, 'omitnan');
event_bst_std = std(subj_event_bst, 0, 'omitnan');
event_imp_mean = mean(subj_event_imp, 'omitnan');
event_imp_std = std(subj_event_imp, 0, 'omitnan');
event_fin_mean = mean(subj_event_fin, 'omitnan');
event_fin_std = std(subj_event_fin, 0, 'omitnan');

fprintf('per-participant mean → overall mean approach (N=%d subjects)\n', nSubj);

%% for the previous version: mean over all trials (for comparison)
all_axis_old = [];
all_quat_old = [];
all_add_old = [];
all_bst_old = [];
all_imp_old = [];
all_fin_old = [];

for subj = 1:nSubj
    n_trials_subj = sum(~isnan(squeeze(angle_error_quat_all(1,:,subj))));
    if n_trials_subj > 0
        all_axis_old = cat(3, all_axis_old, angle_error_axis_all(:,:,1:n_trials_subj,subj));
        all_quat_old = cat(2, all_quat_old, angle_error_quat_all(:,1:n_trials_subj,subj));
        all_add_old = [all_add_old; event_add_all(1:n_trials_subj,subj)];
        all_bst_old = [all_bst_old; event_bst_all(1:n_trials_subj,subj)];
        all_imp_old = [all_imp_old; event_imp_all(1:n_trials_subj,subj)];
        all_fin_old = [all_fin_old; event_fin_all(1:n_trials_subj,subj)];
    end
end

mean_xyz_old = mean(all_axis_old, 3, 'omitnan');
std_xyz_old = std(all_axis_old, 0, 3, 'omitnan');
m_prop_old = mean(all_quat_old, 2, 'omitnan')';
s_prop_old = std(all_quat_old, 0, 2, 'omitnan')';

event_add_mean_old = mean(all_add_old, 'omitnan');
event_add_std_old = std(all_add_old, 0, 'omitnan');
event_bst_mean_old = mean(all_bst_old, 'omitnan');
event_bst_std_old = std(all_bst_old, 0, 'omitnan');
event_imp_mean_old = mean(all_imp_old, 'omitnan');
event_imp_std_old = std(all_imp_old, 0, 'omitnan');
event_fin_mean_old = mean(all_fin_old, 'omitnan');
event_fin_std_old = std(all_fin_old, 0, 'omitnan');

%% Figure 400: 3-axis angle error (per-participant mean)

T_frames = size(mean_xyz, 1);
t = 1:T_frames;

fig_width = 600;
fig_height = 551;  % total height of the 3x1 subplot

figure(400); clf;
set(gcf, 'Color', 'w', 'Position', [100, 100, fig_width, fig_height]);

axisLabel = {'X (Roll)', 'Y (Pitch)', 'Z (Yaw)'};
alpha_prop = 0.18;
lw = 1.6;

ax = gobjects(3,1);

for i = 1:3
    ax(i) = subplot(3,1,i); 
    hold(ax(i), 'on'); 
    grid(ax(i), 'on');
    
    m = mean_xyz(:,i)';
    s = std_xyz(:,i)';
    
    y_data_min = min(m(plot_x_start:plot_x_end) - s(plot_x_start:plot_x_end));
    y_data_max = max(m(plot_x_start:plot_x_end) + s(plot_x_start:plot_x_end));
    y_min_ax = floor(y_data_min / 10) * 10;
    y_max_ax = ceil(y_data_max / 10) * 10;
    
    if show_event_shade
        fill(ax(i), [event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill(ax(i), [event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill(ax(i), [event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill(ax(i), [event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    end
    
    xline(ax(i), event_add_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_bst_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_imp_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_fin_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill(ax(i), [t fliplr(t)], [m+s fliplr(m-s)], dark_red, ...
        'FaceAlpha', alpha_prop, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax(i), t, m, '-', 'Color', dark_red, 'LineWidth', lw);
    
    xlim(ax(i), [plot_x_start plot_x_end]);
    ylim(ax(i), [y_min_ax y_max_ax]);
    
    set(ax(i), 'XTick', []);
    set(ax(i), 'XTickLabel', []);
    
    y_ticks_ax = y_min_ax:10:y_max_ax;
    set(ax(i), 'YTick', y_ticks_ax);
    
    ylabel(ax(i), '');
    
    set(ax(i), 'FontSize', 14, 'FontName', 'Gill Sans MT');
end

linkaxes(ax, 'x');

fprintf('Figure 400 (3x1 subplot) created\n');

%% Figure 401: quaternion angle error (per-participant mean)
T_frames = size(m_prop_subj, 2);
t = 1:T_frames;

m_prop = m_prop_subj;
s_prop = s_prop_subj;

%% Figure setup
fig_width = 600;
fig_height = 184;  % about 1/3 of the total height of 551

figure(401); clf;
set(gcf, 'Color', 'w', 'Position', [100, 300, fig_width, fig_height]);

hold on;

%% y axis range setup
y_data_min = min(m_prop(plot_x_start:plot_x_end) - s_prop(plot_x_start:plot_x_end));
y_data_max = max(m_prop(plot_x_start:plot_x_end) + s_prop(plot_x_start:plot_x_end));
y_min = floor(y_data_min / 10) * 10;
y_max = ceil(y_data_max / 10) * 10;

%% event display
if show_event_shade
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
end

xline(event_add_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_bst_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_imp_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_fin_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(880, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');

%% proposed method shade + line (dark_red)
alpha_prop = 0.2;  % proposed method shade transparency
lw = 1.6;          % line width

fill([t fliplr(t)], [m_prop + s_prop, fliplr(m_prop - s_prop)], ...
     dark_red, 'FaceAlpha', alpha_prop, 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(t, m_prop, '-', 'Color', dark_red, 'LineWidth', lw);

%% axis setup
xlim([plot_x_start plot_x_end]);
ylim([y_min y_max]);

set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);

y_ticks = y_min:10:y_max;
set(gca, 'YTick', y_ticks);

xlabel('');
ylabel('');

set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');

hold off;

%% save (optional)

fprintf('\nFigure 400, 401 created (per-participant mean approach)\n');
fprintf('show_event_shade = %s\n', mat2str(show_event_shade));
fprintf('Event means: ADD=%.1f, BST=%.1f, IMP=%.1f, FIN=%.1f\n', ...
        event_add_mean, event_bst_mean, event_imp_mean, event_fin_mean);

%% Figure 4001: previous version 3-axis angle error (mean over all trials)
T_frames_old = size(mean_xyz_old, 1);
t_old = 1:T_frames_old;

figure(4001); clf;
set(gcf, 'Color', 'w', 'Position', [750, 100, fig_width, 551]);

ax_old = gobjects(3,1);

for i = 1:3
    ax_old(i) = subplot(3,1,i); 
    hold(ax_old(i), 'on'); 
    grid(ax_old(i), 'on');
    
    m_old = mean_xyz_old(:,i)';
    s_old = std_xyz_old(:,i)';
    
    y_data_min = min(m_old(plot_x_start:plot_x_end) - s_old(plot_x_start:plot_x_end));
    y_data_max = max(m_old(plot_x_start:plot_x_end) + s_old(plot_x_start:plot_x_end));
    y_min_ax = floor(y_data_min / 10) * 10;
    y_max_ax = ceil(y_data_max / 10) * 10;
    
    if show_event_shade
        fill(ax_old(i), [event_add_mean_old - event_add_std_old, event_add_mean_old + event_add_std_old, ...
              event_add_mean_old + event_add_std_old, event_add_mean_old - event_add_std_old], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill(ax_old(i), [event_bst_mean_old - event_bst_std_old, event_bst_mean_old + event_bst_std_old, ...
              event_bst_mean_old + event_bst_std_old, event_bst_mean_old - event_bst_std_old], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill(ax_old(i), [event_imp_mean_old - event_imp_std_old, event_imp_mean_old + event_imp_std_old, ...
              event_imp_mean_old + event_imp_std_old, event_imp_mean_old - event_imp_std_old], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill(ax_old(i), [event_fin_mean_old - event_fin_std_old, event_fin_mean_old + event_fin_std_old, ...
              event_fin_mean_old + event_fin_std_old, event_fin_mean_old - event_fin_std_old], ...
             [y_min_ax, y_min_ax, y_max_ax, y_max_ax], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    end
    
    xline(ax_old(i), event_add_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax_old(i), event_bst_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax_old(i), event_imp_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax_old(i), event_fin_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill(ax_old(i), [t_old fliplr(t_old)], [m_old+s_old fliplr(m_old-s_old)], dark_red, ...
        'FaceAlpha', alpha_prop, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax_old(i), t_old, m_old, '-', 'Color', dark_red, 'LineWidth', lw);
    
    xlim(ax_old(i), [plot_x_start plot_x_end]);
    ylim(ax_old(i), [y_min_ax y_max_ax]);
    set(ax_old(i), 'XTick', []);
    set(ax_old(i), 'XTickLabel', []);
    y_ticks_ax = y_min_ax:10:y_max_ax;
    set(ax_old(i), 'YTick', y_ticks_ax);
    ylabel(ax_old(i), '');
    set(ax_old(i), 'FontSize', 14, 'FontName', 'Gill Sans MT');
end

linkaxes(ax_old, 'x');
sgtitle('Figure 4001: previous version (mean over all trials)', 'FontSize', 14);

%% Figure 4011: previous version quaternion angle error
figure(4011); clf;
set(gcf, 'Color', 'w', 'Position', [750, 300, fig_width, fig_height]);
hold on;

y_data_min = min(m_prop_old(plot_x_start:plot_x_end) - s_prop_old(plot_x_start:plot_x_end));
y_data_max = max(m_prop_old(plot_x_start:plot_x_end) + s_prop_old(plot_x_start:plot_x_end));
y_min_old = floor(y_data_min / 10) * 10;
y_max_old = ceil(y_data_max / 10) * 10;

if show_event_shade
    fill([event_add_mean_old - event_add_std_old, event_add_mean_old + event_add_std_old, ...
          event_add_mean_old + event_add_std_old, event_add_mean_old - event_add_std_old], ...
         [y_min_old, y_min_old, y_max_old, y_max_old], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    fill([event_bst_mean_old - event_bst_std_old, event_bst_mean_old + event_bst_std_old, ...
          event_bst_mean_old + event_bst_std_old, event_bst_mean_old - event_bst_std_old], ...
         [y_min_old, y_min_old, y_max_old, y_max_old], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    fill([event_imp_mean_old - event_imp_std_old, event_imp_mean_old + event_imp_std_old, ...
          event_imp_mean_old + event_imp_std_old, event_imp_mean_old - event_imp_std_old], ...
         [y_min_old, y_min_old, y_max_old, y_max_old], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    fill([event_fin_mean_old - event_fin_std_old, event_fin_mean_old + event_fin_std_old, ...
          event_fin_mean_old + event_fin_std_old, event_fin_mean_old - event_fin_std_old], ...
         [y_min_old, y_min_old, y_max_old, y_max_old], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
end

xline(event_add_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_bst_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_imp_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_fin_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(880, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');

t_old_q = 1:size(m_prop_old, 2);
fill([t_old_q fliplr(t_old_q)], [m_prop_old + s_prop_old, fliplr(m_prop_old - s_prop_old)], ...
     dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(t_old_q, m_prop_old, '-', 'Color', dark_red, 'LineWidth', 1.6);

xlim([plot_x_start plot_x_end]);
ylim([y_min_old y_max_old]);
set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);
y_ticks_old = y_min_old:10:y_max_old;
set(gca, 'YTick', y_ticks_old);
xlabel(''); ylabel('');
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
title('Figure 4011: previous version (mean over all trials)', 'FontSize', 14);
hold off;

fprintf('previous version Figure 4001, 4011 created\n');
