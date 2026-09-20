%% [R2-30] R2_30_address_axis_error.m
%  Reviewer 2, Comment 30 (numerical precision) response.
%  Copy of draw_orientation_plot.m. Runs only up to the main loop and
%  prints the address orientation error at full precision, before rounding.
%  2026-08-30
%% draw_figure400_401.m
% Figure 400: 3-axis angle error (3x1 subplot) - proposed method (dark_red) only
% Figure 401: quaternion angle error (single plot) - proposed method (dark_red) only
% add, bst, imp, fin mean vertical lines + shade option
% data loading based on draw_figure4_withmlest.m

clc; clear all; close all;
set(groot,'defaultAxesFontSize',14);

%% ===== option settings =====
show_event_shade = false;   % true: show event-time shade, false: show xline only

%% ===== color definitions =====
dark_red = [128 0 32]/255;          % proposed method line color
event_color = [0.85 0.85 0.85];     % event shade color
event_alpha = 0.4;                   % event shade alpha
event_line_color = [0 0 0];          % event vertical line color

%% ===== data load =====
load swingData_2508_aftercal_imp+1_est.mat

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

OrientationMethod = 7;

%% ===== ML folder path settings =====
mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2');

nSubj_ml = 10;
clubs_ml = {'driver','iron','fast'};
nRows_ml = 10; nCols_ml = 3;
nTrials = 10;

% plot x-axis range
plot_x_start = 266;
plot_x_end = 880;

%% ===== ML data load =====
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

%% ===== initialize the result storage variables =====
max_frames = 900;
max_trials_total = 100;

% for storing angle_error_plot (for Figure 401)
angle_error_plot = [];

% for storing angle_error_axis_list (for Figure 400) - 3-axis error
angle_error_axis_list = zeros(max_frames, 3, max_trials_total);

% store events
add_point_list = [];
bst_point_list = [];
imp_point_list = [];
fin_point_list = [];

%% ===== Butterworth filter =====
[b, a] = butter(4, cut_freq/(apdm_rate/2));

%% ===== main loop =====
fprintf('\nProcessing trials...\n');
z = 1;

for subj = 1:10
    for club = 1
        
        for trial = 21:30
            % exception handling
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
            
            % get imp_est
            add_est = g.add_est;
            imp_est = g.imp_est;
            rel_est = imp_est - add_est;
            
            % store the event time points
            add_point_list = [add_point_list; g.add];
            bst_point_list = [bst_point_list; g.bst];
            imp_point_list = [imp_point_list; g.imp];
            fin_point_list = [fin_point_list; g.fin];
            
            %% marker data
            WristU = g.marker(:,13:15);
            WristM = g.marker(:,10:12);
            WristL = g.marker(:,7:9);
            abs_wrist = (WristU + WristL) ./ 2;
            
            acc_data = g.apdm(:,1:3);
            gyro_data = g.apdm(:,4:6);
            magnet = g.apdm(:,7:9);
            m_cal = magnet;
            
            %% R2Lw computation (marker-based orientation)
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
            
            % R2Lwq (quaternion)
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
            
            % roll, pitch from IMU
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
            
            % yaw from magnetometer
            mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);
            mxh = mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
            myh = my.*cos(phi) - mz.*sin(phi);
            
            % psi fix (0112 version)
            psi0_deg = 191.53;
            alpha_deg = rad2deg(atan2(myh, mxh));
            yaw_imu_deg = psi0_deg - alpha_deg;
            yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;
            psi = deg2rad(yaw_imu_deg);
            
            if club == 3
                psi = deg2rad(yaw_marker);
            end
            
            % build rotation matrix
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
            
            % Orientation integration
            Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);
            
            % qinf computation (proposed method)
            qinf = zeros(length(time), 4);
            for t = 1:length(time)
                qinf(t,:) = dcm2quatern(Rinf(:,:,t)');
                if qinf(t,1) < 0
                    qinf(t,:) = -qinf(t,:);
                end
            end
            
            %% angle error computation (quaternion) - for Figure 401
            angle_error = [];
            for i = 1:length(time)
                qprod = quaternProd(quaternConj(qinf(i,:)), R2Lwq(i,:));
                tempAng = abs(2 * atan2(norm(qprod(2:4)), qprod(1)) * 180/pi);
                if tempAng > 180
                    tempAng = 360 - tempAng;
                end
                angle_error = [angle_error, tempAng];
            end
            
            % append to angle_error_plot
            angle_error_plot = [angle_error_plot angle_error'];
            
            %% 3-axis angle error computation (Euler angles) - for Figure 400
            angle_error_axis = [];
            for i = 1:length(time)
                % globally align
                R1 = R2Lw(:,:,i);
                R2 = Rinf(:,:,i);
                
                % difference between the two rotation matrices (relative rotation matrix)
                R_diff = R2 * R1';  % how far the reference value must be rotated to give the estimate
                
                % convert R_diff to Euler angles (ZYX order)
                eul_angles = rotm2eul(R_diff, 'ZYX');
                
                % angle error about each axis (radians converted to degrees)
                roll_error_deg = rad2deg(eul_angles(3));   % x-axis (roll) error
                pitch_error_deg = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg = rad2deg(eul_angles(1));    % z-axis (yaw) error
                
                angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];
            end
            
            % store in angle_error_axis_list
            angle_error_axis_list(:,:,z) = angle_error_axis;

            R30_axis(z,:) = abs(angle_error_axis(g.add,:));
            R30_tot(z,1)  = angle_error(g.add);
            R30_subj(z,1) = subj;
            
            z = z + 1;
        end
    end
    fprintf('Subject %d processed\n', subj);
end

fprintf('\nTotal trials: %d\n', z-1);

%% ===== [R2-30] address orientation error, full precision =====
thisRes = fullfile(fileparts(mfilename('fullpath')), 'results');
su = unique(R30_subj);
sm_tot = arrayfun(@(s) mean(R30_tot(R30_subj==s)), su);
sm_ax  = cell2mat(arrayfun(@(s) mean(R30_axis(R30_subj==s,:),1), su, 'uni', 0));
lbl = {'roll','pitch','yaw'};
fprintf('\n===== [R2-30] Address orientation error (subject-level, n = %d) =====\n', numel(su));
fprintf('  total : %.6f +- %.6f deg\n', mean(sm_tot), std(sm_tot));
writetable(table(R30_subj, R30_tot, R30_axis(:,1), R30_axis(:,2), R30_axis(:,3), ...
    'VariableNames', {'subj','total','roll','pitch','yaw'}), ...
    fullfile(thisRes, 'R2_30_address_axis_trialwise.csv'));
fprintf('\n-- trial-level (n = %d) --\n', numel(R30_tot));
fprintf('  total : %.6f +- %.6f\n', mean(R30_tot), std(R30_tot));
for k = 1:3
    fprintf('  %-6s: %.6f +- %.6f\n', lbl{k}, mean(R30_axis(:,k)), std(R30_axis(:,k)));
end

for k = 1:3
    fprintf('  %-6s: %.6f +- %.6f deg\n', lbl{k}, mean(sm_ax(:,k)), std(sm_ax(:,k)));
end
return


% trim the data to the actual number of trials
angle_error_axis_list = angle_error_axis_list(:,:,1:z-1);

%% ===== event statistics =====
event_add_mean = mean(add_point_list, 'omitnan');
event_add_std = std(add_point_list, 0, 'omitnan');
event_bst_mean = mean(bst_point_list, 'omitnan');
event_bst_std = std(bst_point_list, 0, 'omitnan');
event_imp_mean = mean(imp_point_list, 'omitnan');
event_imp_std = std(imp_point_list, 0, 'omitnan');
event_fin_mean = mean(fin_point_list, 'omitnan');
event_fin_std = std(fin_point_list, 0, 'omitnan');

%% ===== Figure 400: 3-axis angle error (3x1 subplot) =====
% 3-axis mean/SD computation
mean_xyz = mean(angle_error_axis_list, 3);  % [900 x 3]
std_xyz = std(angle_error_axis_list, 0, 3); % [900 x 3]

T_frames = size(mean_xyz, 1);
t = 1:T_frames;

% figure settings
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
    
    % extract data (row vector)
    m = mean_xyz(:,i)';
    s = std_xyz(:,i)';
    
    % compute the y-axis range
    y_data_min = min(m(plot_x_start:plot_x_end) - s(plot_x_start:plot_x_end));
    y_data_max = max(m(plot_x_start:plot_x_end) + s(plot_x_start:plot_x_end));
    y_min_ax = floor(y_data_min / 10) * 10;
    y_max_ax = ceil(y_data_max / 10) * 10;
    
    % event markers
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
    
    % mean event vertical lines
    xline(ax(i), event_add_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_bst_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_imp_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ax(i), event_fin_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    
    % proposed method shade + line (dark_red)
    fill(ax(i), [t fliplr(t)], [m+s fliplr(m-s)], dark_red, ...
        'FaceAlpha', alpha_prop, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax(i), t, m, '-', 'Color', dark_red, 'LineWidth', lw);
    
    % axis settings
    xlim(ax(i), [plot_x_start plot_x_end]);
    ylim(ax(i), [y_min_ax y_max_ax]);
    
    % remove x-axis ticks (add a condition to exclude the last subplot)
    set(ax(i), 'XTick', []);
    set(ax(i), 'XTickLabel', []);
    
    % y-axis ticks in steps of 10
    y_ticks_ax = y_min_ax:10:y_max_ax;
    set(ax(i), 'YTick', y_ticks_ax);
    
    % remove ylabel
    ylabel(ax(i), '');
    
    % font settings
    set(ax(i), 'FontSize', 14, 'FontName', 'Gill Sans MT');
end

linkaxes(ax, 'x');

fprintf('Figure 400 (3x1 subplot) created\n');

%% ===== Figure 401: quaternion angle error (single plot) =====
% proposed method mean/SD computation
T_frames = size(angle_error_plot, 1);
t = 1:T_frames;

m_prop = mean(angle_error_plot, 2)';   % [1 x T]
s_prop = std(angle_error_plot, 0, 2)';  % [1 x T]

%% ===== figure settings =====
% same size as one of the 3x1 subplots
fig_width = 600;
fig_height = 184;  % about 1/3 of the total height 551

figure(401); clf;
set(gcf, 'Color', 'w', 'Position', [100, 300, fig_width, fig_height]);

hold on;

%% ===== set y-axis range =====
y_data_min = min(m_prop(plot_x_start:plot_x_end) - s_prop(plot_x_start:plot_x_end));
y_data_max = max(m_prop(plot_x_start:plot_x_end) + s_prop(plot_x_start:plot_x_end));
y_min = floor(y_data_min / 10) * 10;
y_max = ceil(y_data_max / 10) * 10;

%% ===== event markers =====
if show_event_shade
    % add event shade
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    % bst event shade
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    % imp event shade
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    
    % fin event shade
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
end

% mean event vertical lines
xline(event_add_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_bst_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_imp_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(event_fin_mean, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(880, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');

%% ===== proposed method shade + line (dark_red) =====
alpha_prop = 0.2;  % proposed method shade alpha
lw = 1.6;          % line width

% Shade
fill([t fliplr(t)], [m_prop + s_prop, fliplr(m_prop - s_prop)], ...
     dark_red, 'FaceAlpha', alpha_prop, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Mean line
plot(t, m_prop, '-', 'Color', dark_red, 'LineWidth', lw);

%% ===== axis settings =====
xlim([plot_x_start plot_x_end]);
ylim([y_min y_max]);

% remove x-axis ticks
set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);

% y-axis ticks in steps of 10
y_ticks = y_min:10:y_max;
set(gca, 'YTick', y_ticks);

% remove xlabel, ylabel
xlabel('');
ylabel('');

% font settings
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');

% grid on;
hold off;

%% ===== save (optional) =====
% print(figure(400), 'figure400_3axis_darkred.svg', '-dsvg', '-vector');
% print(figure(401), 'figure401_darkred.svg', '-dsvg', '-vector');

fprintf('\nFigure 400, 401 created\n');
fprintf('show_event_shade = %s\n', mat2str(show_event_shade));
fprintf('Event means: ADD=%.1f, BST=%.1f, IMP=%.1f, FIN=%.1f\n', ...
        event_add_mean, event_bst_mean, event_imp_mean, event_fin_mean);
