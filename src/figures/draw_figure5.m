

%% Fig4&5 to be organised here

clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

%% data load
load swingData_2508_aftercal_imp+1_est.mat
% load swingData_2508_est.mat
% load swingData_2508_est_length_fixed.mat
% load swingData_2508_est_length_changed.mat

apdm_rate = 200;
cut_freq = 15;

idx_fast_draw = 5;

% ===== User settings (for figure editing) =====
highlight_subj = 3;      % participant to highlight in figures 50001~50004 (dark_red)
subj_select = 8;         % participant to select in figure 2025
trial_select = 5;        % fast trial to select in figure 2025

plot_x_start = 266;      % figure x-axis start
plot_x_end = 880;        % figure x-axis end

ml_start_ref = 401;      % ML segment start (reference frame)
ml_end_ref = 800;        % ML segment end (reference frame)
gray_bar = [0.5 0.5 0.5]; % default bar graph colour
% ========================================

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;

dark_purple = [102 51 153]/255;   % slightly deep purple (#663399 feel)
purple = [128 0 128]/255;        % classic purple (#800080)
% soft_purple = [0.875, 0.749, 0.875];
soft_purple = [0.749, 0.502, 0.749];

%changed to blue
dark_blue = [0,127,255] / 255;
pink = [255,164,179]/255;

%changed to sky blue
purple = [100, 149, 237] / 255;

% 0:Reference(marker)
% 1:Reference(Marker + IMU RM)
% 2:Reference(Marker + Marker_gyro)
% 7: derive roll pitch from IMU values only, take yaw as the mean -> extended to also work with magnetometer
% 9:mahony filter with magnetometer % independent of the initial orientation
OrientationMethod=7;  
% OrientationMethod=0;  

% method 0: imu only
% method 1: apdm_trajCal velocity correction
% method 2: apdm_trajCalL velocity + circular trajectory
% method 3: apdm_trajCalI velocity + marker imp coordinates
% method 4: apdm_trajCalV velocity + video estimate
% method 5: fastshot/ normal shot estimates together
mae_method =5;
mae_method_vel =0;


%integration error
mae_list = [];
mae_norm_list = [];
rmse_overall = [];
rmse_norm_list = [];
rmse_xyz_list = [];
rmse_norm_list = [];
error_vellist = [];

%pos error
add_pos_error_ag_list = [];
imp_pos_error_ag_list = [];
imp_rel_pos_error_ag_list =[];

add_pos_error_prop_list = [];
imp_pos_error_prop_list = [];
imp_rel_pos_error_prop_list =[];


%for circlefit validation
raddif=[];

% must be changed to the number of trials, store per-axis error
% could this not just be removed?
% angle_error_axis_list = zeros(900, 3, 20);

% derive quaternion results
angle_error_q_list = [];
angle_error_add_list = [];
angle_error_add2imp = [];
angle_error_plot =[];
angle_error_plot_ref = [];

% not sure whether the way add is detected is a problem
% subj4 day2 add is odd
add_acc_list = [];


% change the event timings
% point = [g.add,g.add_imu, g.imp, g.vid_min,g.imp_imu1,g.imp_imu2]


roll_marker_list = [];
pitch_marker_list = [];
yaw_marker_list = [];
check_mag_list = [];

imu_roll_error_list = [];
imu_pitch_error_list = [];
marker_yaw_list = [];
imu_yaw_error_list = [];

apdm_biasV_list = [];
imp_est_list = [];

% mean_idx = 1;



L_list         = [];   % actual length (motion capture reference)
dL_mocap_list  = [];   % mocap-based radial velocity*dt = L_delta
dL_vidimu_list = [];   % video+IMU based radial velocity*dt = L_delta_vid
trial_list     = [];

ratio_imu_list = [];
ratio_mocap_list = [];
ratio_ml_list = [];

ratio_imu_x_list = [];
ratio_imu_y_list = [];
ratio_imu_z_list = [];
ratio_mocap_x_list = [];
ratio_mocap_y_list = [];
ratio_mocap_z_list = [];
ratio_ml_x_list  = [];
ratio_ml_y_list  = [];
ratio_ml_z_list  = [];

swing_tempo_ref_list = [ ];
swing_tempo_fast_list= [ ];

swing_time_normal_list = [];
swing_time_fast_list = [];

% ===== settings =====
% ori0
% mldataDir ='<RUNS_ROOT>\runs_1201_acc450710_ori0_epoch100_3';
% ori7
% mldataDir ='<RUNS_ROOT>\runs_1206_acc450710_ori7_epoch100_1';

% lengthened
% the one that comes out well for now
% mldataDir ='<RUNS_ROOT>\runs_1217_accgyro_420710_ori7trajanc_3';  % 250

% mldataDir ='<RUNS_ROOT>\runs_1217_rawaccgyro_420710_ori7traj_3';  % 250

% the one with the extended segment
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori7traj_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori7traj_5';  % uses ori7traj_5  % version including fast prediction


%0112
mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); 
% mldataDir = '<RUNS_ROOT>\runs_0224_accgyro_400800_loso3'; 


% imu phase
% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %2 for now ->20.25

% agformer+ imu phase
% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %2 for now ->19.55


% ===== automatic fold number extraction (for saving) =====
fold_num = str2double(mldataDir(end));  % extract the digit from the last character of mldataDir
if isnan(fold_num)
    fold_num = 5;  % default value
end
fprintf('current fold number: %d\n', fold_num);

% participant-specific model
% mldataDir ='<RUNS_ROOT>\runs_1219_accgyro_350800_ori7trajpsnl_1';  % version including fast prediction

% check ori0
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_3';  % 250

nSubj_ml   = 10;                     % number of participants
clubs_ml   = {'driver','iron','fast'};      % middle token of the filename
nRows_ml   = 10; nCols_ml = 3;          % number of rows/columns to use from each file
% nRows_ml   = 5; nCols_ml = 3;          % number of rows/columns to use from each file

nTrials    = 10;  % number of trials

% ===== initialise result arrays: 10x3x10 =====
ml_est = struct();
for c = 1:numel(clubs_ml)
    ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);  % {trial, subj}
end

% scatter plot representation
nsigma = 2;
% start_idx = 560;
% start_idx = 490;

% start_idx = 350;
% end_idx = 800;
% end_idx   = 710;

start_idx = 421;
end_idx   = 700;

% ====== enter the number of data points per participant here ======
% example: 3 participants with 10, 15 and 8 data points respectively
n_per_subject_fast = [10, 10, 10,10,9,10,10,10,9,10];  % number of data points per participant (in order)

n_per_subject_ref  = [10, 10, 10,10,10,10,10,9,10,10];   % number of ref data points
% % =============================================

event_shade_color = [0.25 0.25 0.25];
event_shade_alpha = 0.4;

% n_per_subject_fast = [9];  % number of data points per participant (in order)
% n_per_subject_fast = [10];  % number of data points per participant (in order)
% n_per_subject_ref  = [10];   % number of ref data points

num_subjects = length(n_per_subject_fast);



for subj_fast =1:10
% for subj_fast =3
% for subj_fast = 8
    z = 1;
    for subj = subj_fast %4 6 8
    % for subj = 1:5
    % for subj = 10
        % for club = [1 3]
        % for club = 3
        for club = 1
    
            % exit the for loop automatically if absent
            fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
            % fname = sprintf('subj%d_%s_est.csv', subj, clubs_ml{club});
            fpath = fullfile(mldataDir, fname);
            if ~isfile(fpath)
                warning('Missing file: %s', fpath);
                continue
            end
            
            fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
            fpath_traj = fullfile(mldataDir, fname_traj);

            T = readtable(fpath);  % column names are recognised automatically if present
            % use only those columns if pred_x, pred_y, pred_z exist, otherwise columns 1~3
            if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
                M = T{:, {'pred_x','pred_y','pred_z'}};
            else
                M = T{:, 1:3};
            end
    
            % match the length (store only 10 rows; missing entries stay NaN)
            m = min(size(M,1), nRows_ml);
            ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);
            
            T_traj = readtable(fpath_traj);
            % store separately by trial_idx
            unique_trials = unique(T_traj.trial_idx);
    
            for i = 1:numel(unique_trials)
                trial_traj = unique_trials(i);
                idx = T_traj.trial_idx == trial_traj;
                
                % store pred
                pred_data = [T_traj.pred_x(idx), T_traj.pred_y(idx), T_traj.pred_z(idx)];
                ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;  % +1 because trial_idx starts from 0
            end

            for trial = 21:30
            % for trial = 20:29
            % for trial = 26:30
            % for trial = 7
                if subj==1 && club==2 && trial ==1 % looks like an apdm recording error
                    continue
                elseif subj==5 && club==3 && trial==5 % could not be derived from the video at all
                    continue
                elseif subj==8 && club==1 && trial ==30 % magnetometer measurement error
                % not relevant, but ml_est was not derived
                    continue
                % elseif subj==10
                %     continue
                end
    
                %% filter out the odd gyro ones?
    
                if club==3 && (trial>10)
                    continue;
                end
                g = swingData_2508(subj).clubN(club).trialN(trial);
    
                if subj==10 && club==1 && trial==24
                    swingData_2508(subj).clubN(club).trialN(trial).imp_imu1_est = swingData_2508(subj).clubN(club).trialN(trial).imp_imu2_est;
                    swingData_2508(subj).clubN(club).trialN(trial).imp_imu1 = swingData_2508(subj).clubN(club).trialN(trial).imp_imu2;
                    g.imp_imu1_est = g.imp_imu2_est;
                    g.imp_imu1 = g.imp_imu2;
                end

                % need the mat with the updated event timings
                % g.add = double(g.add_imu);
                % g.bst = double(g.bst_imu);
                % g.imp = double(g.imp_imu1);
                % g.fin = double(g.fin_imu);


                g.add = double(g.add);
                g.bst = double(g.bst);
                g.imp = double(g.imp);
                g.fin = double(g.fin);
    
                % remove the error at the fin event
                if g.fin>900
                    g.fin = 900;
                end

                

                % compute swing tempo
                backswing_ref = g.bst-g.add;
                downswing_ref = g.imp-g.bst;
                swing_tempo_ref = backswing_ref/downswing_ref;
                swing_tempo_ref_list = [swing_tempo_ref_list swing_tempo_ref];

                
                time_start_idx =  g.add;
                % time_end_idx = g.imp;
                time_end_idx = g.fin;
                swing_time_normal = time_end_idx-time_start_idx;
                swing_time_normal_list = [swing_time_normal_list swing_time_normal];


                % % identify the imp event
                % Lhand = g.marker(g.bst:g.imp+1, 13:15); % coordinates of the first marker (columns 13~15)
                % clubhead = g.marker(g.bst:g.imp+1, 19:21); % coordinates of the second marker (columns 19~21) % from the plot, imp+1 seems to be right
                % 
                % % 3D plot settings
                % figure(trial*550);
                % hold on;
                % grid on;
                % xlabel('X');
                % ylabel('Y');
                % zlabel('Z');
                % title('3D Swing Trajectory');
                % % view(3); % 3D viewpoint setting
                % view([90 0]);
                % 
                % % plot the 3D swing trajectory over time
                % for t = 1:size(Lhand, 1)
                %     % % connect from the origin to the first marker
                %     % plot3([0, Lhand(t, 1)], [0, Lhand(t, 2)], [0, Lhand(t, 3)], 'r-', 'LineWidth', 1.5);
                %     % 
                %     % connect from the first marker to the second marker
                %     plot3([Lhand(t, 1), clubhead(t, 1)], ...
                %           [Lhand(t, 2), clubhead(t, 2)], ...
                %           [Lhand(t, 3), clubhead(t, 3)], 'b-', 'LineWidth', 1.5);
                % 
                %     plot3(0, 0, 0, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); % mark the origin (0,0,0) with a red dot
                % 
                %     % update the plot
                %     drawnow;
                % end
                % hold off;
    
                %% Orientation from marker
                % apdm version
                WristU = g.marker(:,13:15); % inner side of the left wrist
                WristM = g.marker(:,10:12); % top
                WristL = g.marker(:,7:9); % outer side of the left wrist % i.e. front
                acc_data = g.apdm(:,1:3);
                gyro_data = g.apdm(:,4:6);
                magnet = g.apdm(:,7:9);
                abs_wrist = (WristU+WristL)./2;
                rias = g.marker(:,1:3);
                lias = g.marker(:,4:6);
                com = (rias+lias)./2;
                
    
                
                % figure(2027)
                % hold on;
                % plot(vecnorm(abs_wrist, 2, 2))
                % xline([g.add g.imp],'-',{'ADD','IMP'},'HandleVisibility','off');
                % 
    
    
    
                % 1019 done during mat processing
                % % 0518 filtering step after rawdata processing
                % [b, a] = butter(4, cut_freq/(200/2));
                % acc_data = filtfilt(b, a, acc_data);
                % gyro_data = filtfilt(b, a, gyro_data);
                % magnet = filtfilt(b, a, magnet);
                
                % gpt yaw derivation
                % % should this be done in the mat instead?
                % m = magnet; 
                % % --- simple hard/soft iron correction (diagonal approximation) ---
                % b = (max(m,[],1) + min(m,[],1))/2;     % bias (per-axis mean centre)
                % s = (max(m,[],1) - min(m,[],1))/2;     % radius
                % gmean = mean(s);
                % scale = gmean ./ s;                    % approximate soft-iron axis scale (diagonal approximation)
                % m_cal = (m - b) .* scale;              % quick approximate correction (the exact model is an ellipsoid fit)
                % 
                % %how about skipping cal? the one above gives a 17 deg error
    
                m_cal = magnet; 
                
                % modify if the event timings are changed
                add_est = g.add_est;
                imp_est = g.imp_est;
    
                % add_est = g.add_imu_est;
                % imp_est = g.imp_imu1_est;
                % 
                rel_est = imp_est - add_est; % not used here
        
                % computed with agformer
                % rel_est = g.dl(g.imp,1:3) - g.dl(g.add,1:3);

                % even odder, and x is still odd..
                % imp_est = g.vid_min_est;
    
                % also check for motionag % x is still odd
                % add_est = g.dl(g.add,1:3);
                % imp_est = g.dl(g.imp,1:3);
    
                
                motionag = g.dl(:,1:3);
                % motionag + com = algo at world coordinate 
                motionag = motionag+ com;
    
    
                % figure(30000)
                % hold on;
                % scatter3(add_est(:,1), add_est(:,2), add_est(:,3), ...
                %          50, 'k', 'filled');
                % text(add_est(:,1), add_est(:,2),add_est(:,3), sprintf('%d',trial), 'FontSize',9, ...
                %  'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
                %  'VerticalAlignment','bottom','Clipping','on');
                % scatter3(abs_wrist(g.add,1), abs_wrist(g.add,2), abs_wrist(g.add,3), ...
                %          50, 'g', 'filled');
                % 
                % % Scatter plot - prop data
                % scatter3(imp_est(:,1), imp_est(:,2), imp_est(:,3), ...
                %          50, dark_red, 'filled');
                % scatter3(abs_wrist(g.imp,1), abs_wrist(g.imp,2), abs_wrist(g.imp,3), ...
                %          50, 'r', 'filled');
                % text(imp_est(:,1), imp_est(:,2),imp_est(:,3), sprintf('%d',trial), 'FontSize',9, ...
                %  'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
                %  'VerticalAlignment','bottom','Clipping','on');
                % 
                % xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
                % 
                % grid on;
                % view(3);
                % axis equal;  % so that the ellipsoid is not distorted
    
    
    
                %%  figure1 3d position derivation
                % compare the estimation with the marker values
                % check the wrist position in the actual marker frame rather than the relative est
                % !only knowable if com is available!
                % for k = 1:3
                %     figure(trial*3+k)
                %     hold on;
                %     plot(WristM(:,k),'Color','k');
                %     plot(motionag(:,k),'Color', [0.7, 0.7, 0.7]);
                %     plot(g.add, g.add_est(k), 'ro', 'MarkerSize', 8); 
                %     plot(g.imp, g.imp_est(k), 'ro', 'MarkerSize', 8); 
                % 
                %     xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                %     xlim([g.add-10 g.fin+10])
                % end
                
                ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);
    
                add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
                imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
                imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));
                
                add_pos_error_prop =abs_wrist(g.add,:)-add_est;
                imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
                imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);
    
                % … each error vector computed above …
                ok = true;  % included by default
                
                % pelvis-related statistics
                % exclusion conditions (add freely with whatever rule you want)
                ok = ok && ~(club==3);
                ok = ok && ~(subj==2 && club==1 && trial==10);
                ok = ok && ~(subj==2 && club==2 && ismember(trial,[23 29]));
                ok = ok && ~(subj==3 && club==2 && ismember(trial,[1 11 14 15]));
                ok = ok && ~(subj==6 && club==1 && trial==3);
                
                % if cases where the data itself is broken with NaN/Inf etc. should also be excluded:
                ok = ok && all(isfinite([add_pos_error_ag, imp_pos_error_ag, imp_rel_pos_error_ag, ...
                                         add_pos_error_prop, imp_pos_error_prop, imp_rel_pos_error_prop]));
                
                if ok
                    add_pos_error_ag_list      = [add_pos_error_ag_list;      abs(add_pos_error_ag)];
                    imp_pos_error_ag_list      = [imp_pos_error_ag_list;      abs(imp_pos_error_ag)];
                    imp_rel_pos_error_ag_list  = [imp_rel_pos_error_ag_list;  abs(imp_rel_pos_error_ag)];
                
                    add_pos_error_prop_list    = [add_pos_error_prop_list;    abs(add_pos_error_prop)];
                    imp_pos_error_prop_list    = [imp_pos_error_prop_list;    abs(imp_pos_error_prop)];
                    imp_rel_pos_error_prop_list= [imp_rel_pos_error_prop_list;abs(imp_rel_pos_error_prop)];
                end
                
    
                % % check the IMU acc 3-axis values
                % figure(trial+5)
                % plot(acc_data(:,1), 'r');    % first column: red
                % hold on
                % grid on
                % plot(acc_data(:,2), 'g');    % second column: green
                % plot(acc_data(:,3), 'b');    % third column: blue
                % xline([g.add],'-',{'ADD'},'HandleVisibility','off');
                % % xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                % legend('acc_x','acc_y','acc_z')
                % xlim([g.add-200 g.add+50])
                % hold off
                
                % %gyro 3 axes in the local frame
                % figure(trial+day*10)
                % plot(gyro_data(:,1), 'r');    % first column: red
                % hold on
                % grid on
                % plot(gyro_data(:,2), 'g');    % second column: green
                % plot(gyro_data(:,3), 'b');    % third column: blue
                % xline([g.add],'-',{'ADD'},'HandleVisibility','off');
                % % xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                % legend('w_x','w_y','w_z')
                % % xlim([g.add-200 g.add+50])
                % % ylim([-0.5 1])
                % hold off
    
   
    
                Cw = (WristU+WristL)./2;     % center wrist
                Lo = WristL-Cw;             % make center origin
                Mo = WristM-Cw;
                Uo = WristU-Cw;
    
                wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
                wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
                wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);
    
                % prime vector
                temp_x = Uo./wU; % as I recall, back jumps less than front % no, change it later haha
                vprime_xw = Lo./wL;
                vprime_top = Mo./wM;
                vprime_zw = zeros(length(vprime_xw),3);
                vprime_yw = zeros(length(vprime_xw),3);
    
                % target the middle part
                for i = 1:length(vprime_xw)
                    % vprime_zw(i,:) = cross(vprime_top(i,:),vprime_xw(i,:));
                    vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:)); %1017 revision
                end
                % give orthogonality
                for i = 1:length(vprime_xw)
                    vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:)); %1017 revision
                    % vprime_yw(i,:) = cross(vprime_zw(i,:),vprime_xw(i,:));
                end
                for i = 1:length(vprime_xw)
                    vprime_xw(i,:) = cross(vprime_yw(i,:),vprime_zw(i,:));
                end
    
                % normalize
                for i = 1:length(vprime_xw)
                    vprime_xw(i,:)=vprime_xw(i,:) / sqrt(sum(vprime_xw(i,:).^2));
                    vprime_yw(i,:)=vprime_yw(i,:) / sqrt(sum(vprime_yw(i,:).^2));
                    vprime_zw(i,:)=vprime_zw(i,:) / sqrt(sum(vprime_zw(i,:).^2));
                end
    
                % get velocity
                [dot1, ddot1] = deriv5(Cw(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(Cw(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(Cw(1:length(vprime_xw),3),ts);
                Cwdot=[dot1 dot2 dot3];
                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
    
                % for gyro cal
                % for certain data imports the dot dimensions changed so they became dot1' dot2' dot3'/
                % not sure when
                [dot1, ddot1] = deriv5(WristM(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(WristM(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(WristM(1:length(vprime_xw),3),ts);
                WristMdot=[dot1 dot2 dot3];
                WristMddot=[ddot1 ddot2 ddot3];
                WristMdotnorm=sqrt(sum(WristMdot.^2,2));
                [dot1, ddot1] = deriv5(WristU(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(WristU(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(WristU(1:length(vprime_xw),3),ts);
                WristUdot=[dot1 dot2 dot3];
                WristUddot=[ddot1 ddot2 ddot3];
                
                % seems the same as filtering gl_wrist
                cut_freq = 10;
                [b, a] = butter(3, cut_freq/(200/2));
                WristMdot = filtfilt(b, a, WristMdot);
                WristMddot = filtfilt(b, a, WristMddot);
                WristUdot = filtfilt(b, a, WristUdot);
                Cwdot = filtfilt(b, a, Cwdot);
                Cwddot = filtfilt(b, a, Cwddot);
    
                
    
                %% local gyro filtering (marker)
                % calculate local gyro from marker data
                % 1019 revised code
                % gL_wrist=zeros(length(vprime_xw),3);
                % for i=1:length(vprime_xw)
                % omegax should be this by the formula, not sure why the sign is opposite %1020 changed to the one below
                %     gL_wrist(i,:) = [dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                %         dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                %         -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))]; % *180/pi;
                % end
    
                gL_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    gL_wrist(i,:) = [-dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                        dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                        -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))]; % *180/pi;
                end
    
                % % compare the marker angular velocity with the gyro data % gl_wrist is in the local frame
                % figure(trial)
                % plot(gL_wrist)
                % figure(trial+20)
                % plot(gyro_data) %
    
                % rotation matrix
                WristMddot(:,3)=WristMddot(:,3)+9.81;
                R2Lw=zeros(3,3,length(vprime_xw));
                for j = 1:length(vprime_zw)
                    R2Lw(:,:,j) = [vprime_xw(j,:)' vprime_yw(j,:)' vprime_zw(j,:)'];
                end
                % quaternion
                for j = 1:length(vprime_zw) 
                    R2Lwq(j,:) = dcm2quatern(R2Lw(:,:,j)');
                end
                for j = 1:length(vprime_zw) 
                    R2Gwq(j,:) = dcm2quatern(R2Lw(:,:,j));
                end
    
                ag_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    ag_wrist(i,:) = R2Lw(:,:,i)*acc_data(i,:)';
                end
    
                % the bias of acc itself can be checked, acc with gravity obtained from the markers
                % aL_wrist=zeros(length(vprime_xw),3);
                % for i=1:length(vprime_xw)
                %     aL_wrist(i,:) = R2Lw(:,:,i)^(-1)*[WristMddot(i,1);WristMddot(i,2);WristMddot(i,3)];
                % end
    
                % gyro global reference value
                w_global_marker=dcmRot(R2Lw,gL_wrist);
    
                
                % obtain the angle reference values
                local_frame = R2Lw(:,:,g.add);
                pitch_marker = asin(-local_frame(3,1));
                roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
        
                roll_marker=rad2deg(roll_marker);
                pitch_marker=rad2deg(pitch_marker);
                yaw_marker = rad2deg(yaw_marker);
                
                roll_marker_list = [ roll_marker_list,roll_marker];
                pitch_marker_list = [pitch_marker_list, pitch_marker];
                yaw_marker_list = [yaw_marker_list, yaw_marker];

                %% Orientation from apdm
                switch OrientationMethod
                    case 0
    
                        Rinf = R2Lw;
                        qinf = R2Lwq;
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data); %the w of omega
    
                        % just to make the code run. the one where only the initial orientation is the reference value
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
            
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                    case 1
                        % DCM
                        Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);
            
                        for t=1:length(time)
                            qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
                            if qinf(t,1)<0
                                qinf(t,:)=-qinf(t,:);
                            end
                        end
    
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                    case 2
                        %calculate with marker gyro
                        Rinf = get_orientation_apdm(time, acc_data, gL_wrist, g.add, R2Lw(:,:,g.add));
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gL_wrist);
            
                        for t=1:length(time)
                            qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf(t,1)<0
                                qinf(t,:)=-qinf(t,:);
                            end
                        end
                    case 7  % roll,pitch derived with the pilot-data formula % comes out well
    
                        local_frame = R2Lw(:,:,g.add);
    
                        pitch_marker = asin(-local_frame(3,1));
                        roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                        yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
                
                        roll_marker=rad2deg(roll_marker);
                        pitch_marker=rad2deg(pitch_marker);
                        yaw_marker = rad2deg(yaw_marker);
                        
                        acclocal_data = acc_data(g.add,:);
                        acc_global = [acclocal_data(1); acclocal_data(2); acclocal_data(3)];
    
                        % Step 2: normalisation (correcting uncalibrated values)
                        acc_norm = norm(acc_global);
                        acc_normalized = acc_global / acc_norm;  % convert to a unit vector
                        % Step 3: compute Roll and Pitch
                        % the gravity vector points along [0, 0, -1] in the global frame
                        ax = acc_normalized(1);
                        ay = acc_normalized(2);
                        az = acc_normalized(3);
                        
                        % compute Roll (rotation about the X axis)
                        roll = atan2(ay, az);
                        % compute Pitch (rotation about the Y axis)
                        pitch = atan2(-ax, sqrt(ay^2 + az^2));
                        
                        phi = roll;
                        theta = pitch;
    
                        % psi = deg2rad(-40);
    
                        % (additional) magnetometer-based yaw (single frame: g.add)
                        mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);
                        % mxh =  mx*cos(theta) + mz*sin(theta); %% apparently multiplied in the order rx*ry
                        % myh =  mx*sin(phi)*sin(theta) + my*cos(phi) - mz*sin(phi)*cos(theta);

                        % this is indeed the expression that was actually multiplied
                        mxh =  mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
                        myh =  my.*cos(phi) - mz.*sin(phi);

                        % disp('norm horizontal component')
                        check_mag = sqrt(mxh^2+myh^2);
                        check_mag_list = [check_mag_list check_mag ];

                        % psi = atan2(-myh, mxh);   % rad  <-- replaced by this
                        % % psi = atan2(myh, mxh);   % rad  <-- replaced by this
                        % rad2deg(psi);
                        % 
                        % % this seems to be about the best possible
                        % psi = -(360-rad2deg(psi))+198.9; %% align magnetic north & mocap north
                        % 
                        % if subj==5 && club==1 && trial==7
                        %     psi = psi+360;
                        % end
                        % % disp('yaw marker and mag values in order');
                        % % disp(yaw_marker);
                        % % disp(psi);
                        % psi = deg2rad(psi);
                        
                        %% 0112 psi revision
                        psi0_deg = 191.53;
                        alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 7.16 deg
                        % alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 76 deg
                        yaw_imu_deg = psi0_deg - alpha_deg;
                        yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;
                
                        
                        % psi = deg2rad(psi);
                        psi = deg2rad(yaw_imu_deg);
                        


    

    
                        % phi, theta, psi are all in radians!
                        Rx = [1         0           0
                              0 cos(phi) -sin(phi)
                              0 sin(phi)  cos(phi)];
                    
                        Ry = [ cos(theta) 0 sin(theta)
                               0          1     0
                              -sin(theta) 0 cos(theta)];
                    
                        Rz = [cos(psi) -sin(psi) 0
                              sin(psi)  cos(psi) 0
                              0         0        1];
    
                       
                        % convert radians to degrees
                        roll = rad2deg(roll);
                        pitch = rad2deg(pitch);
                        
                        imu_roll_error = abs(roll_marker-roll);
                        imu_pitch_error = abs(pitch_marker-pitch);

                        imu_roll_error_list = [imu_roll_error_list ,imu_roll_error];
                        imu_pitch_error_list = [imu_pitch_error_list,imu_pitch_error];
                        marker_yaw_list = [marker_yaw_list, yaw_marker];
                        imu_yaw_error = abs(yaw_marker-rad2deg(psi));
                        imu_yaw_error_list = [imu_yaw_error_list,imu_yaw_error];
                        
                        % roll pitch error graph
                        % figure(2025)
                        % hold on;
                        % if subj==1
                        %     scatter(roll_marker,roll,50,'r','filled')
                        % elseif subj==2
                        %     scatter(roll_marker,roll,50,'g','filled')
                        % elseif subj==3
                        %     scatter(roll_marker,roll,50,'b','filled')
                        % else
                        %     scatter(roll_marker,roll,50,'k','filled')
                        % end
                        % 
                        % figure(2026)
                        % hold on;
                        % if subj==1
                        %     scatter(pitch_marker,pitch,50,'r','filled')
                        % elseif subj==2
                        %     scatter(pitch_marker,pitch,50,'g','filled')
                        % elseif subj==3
                        %     scatter(pitch_marker,pitch,50,'b','filled')
                        % else
                        %     scatter(pitch_marker,pitch,50,'k','filled')
                        % end
                        
    
                        global_frame=[1 0 0;0 1 0;0 0 1];
                        R2tri = Rz*Ry*Rx*global_frame; 
    
                        Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);
                        % Rinf = get_orientation_apdm(time, acc_data, gL_wrist, g.add, R2tri);
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);
    
                        for j = 1:length(time)
                            qinf(j,:) = dcm2quatern(Rinf(:,:,j)');
                            if qinf(j,1)<0
                                qinf(j,:)=-qinf(j,:);
                            end
                        end
                        
                        
                        %% code for reference
                        % copy-pasted so that any method can be used
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                        % if arrow visualisation is needed
                        % figure(trial+(day-1)*20 + subj*1000)
                        % hold on;
                        % 
                        % % set the origin
                        % origin = [0; 0; 0];
                        % 
                        % 
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,1), R2tri(2,1), R2tri(3,1), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,2), R2tri(2,2), R2tri(3,2), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,3), R2tri(2,3), R2tri(3,3), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % 
                        % quiver3(origin(1), origin(2), origin(3), vprime_xw(g.add,1)', vprime_xw(g.add,2)', vprime_xw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), vprime_yw(g.add,1)', vprime_yw(g.add,2)', vprime_yw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), vprime_zw(g.add,1)', vprime_zw(g.add,2)', vprime_zw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % 
                        % grid on;
                        % xlabel('X-axis');
                        % ylabel('Y-axis');
                        % zlabel('Z-axis');
                        % title('3D Vector Plot');
                        % axis equal;
    
                end   
            
                %% trajectory integration 
    
                [dot1, ddot1] = deriv5(abs_wrist(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(abs_wrist(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(abs_wrist(1:length(vprime_xw),3),ts);
                abs_wrist_dot=[dot1 dot2 dot3];
                abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);
    
                % look only from address onwards
                Mtraj = abs_wrist-abs_wrist(g.add,:);

                n_rows_fin = size(Mtraj(g.fin+1:end,:), 1);

                Mtraj(1:g.add,:)=0;
                Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
                Mvel(1:g.add,:)=0;
    
    
                % Circle fit with marker data points
                [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);                           % address ~ s.finish
                [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);      % bst ~ s.finish
                raddif=[raddif radM-radMs];
                
    
                % gravity is always along the global z direction
                ag_wo_g(:,1) = a_dcm(:,1);
                ag_wo_g(:,2) = a_dcm(:,2);
                ag_wo_g(:,3) = a_dcm(:,3)-9.80665; % should it always be subtracted using the norm?
                %m to mm
                ag_wo_g(:,:) = ag_wo_g(:,:).*1000;
    
    
    
   
                imu_vel= cumtrapz(time,ag_wo_g);
                %rad2deg
                w_dcm = w_dcm*180/pi;
                angle_cal=cumtrapz(time,w_dcm);
                % angle_marker=cumtrapz(time,w_global_marker);
               
                
                
                imu_traj=cumtrapz(time,imu_vel);
                imu_vel = imu_vel-imu_vel(g.add,:); %address zeroing
                imu_vel(1:g.add,:)=0; % initial velocity 0
                imu_traj=cumtrapz(time,imu_vel);
                imu_traj=imu_traj-imu_traj(g.add,:);
                

    
                
                length_idx = g.imp;
    
                r_hat = abs_wrist(length_idx,:)/norm(abs_wrist(length_idx,:));
                vel_r   = dot(Mvel(length_idx,:), r_hat);          % component along r
                L_delta= vel_r*0.005;
                % disp(L_delta)
    
                rw_vid = imp_est;
                r_hat_vid = rw_vid/norm(rw_vid);
                vel_r_vid  = dot(imu_vel(length_idx,:), r_hat_vid);          % component along r
                % L_delta_vid= vel_r_vid*0.005;
                % disp(L_delta_vid)
    
                L_delta_vid = vecnorm(imu_traj(g.imp,:), 2, 2);
                
                % check whether this is actually correlated with the length variability
                L_now = vecnorm(abs_wrist(length_idx,:), 2, 2);
                % disp(L_now)
    
                if all(isfinite([L_now, L_delta, L_delta_vid]))
                    L_list(end+1)         = L_now;
                    dL_mocap_list(end+1)  = L_delta;
                    dL_vidimu_list(end+1) = L_delta_vid;
                    if exist('trial','var'), trial_list(end+1) = trial; end
                end
    
    
                %% velocity outlier correction
                velCalRate=1; %correction coefficient
                % velocity correction
                imu_velCal =imu_vel;
    
    
                % global based, 3 points(address, backswingtop, finish)
                for i=g.add:g.bst
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.bst,:)./(g.bst-g.add).*(i-g.add) * velCalRate;  % address~g.bst
                end
                imu_velCal(g.bst+1:end,:)=imu_velCal(g.bst+1:end,:)-imu_velCal(g.bst+1,:) * velCalRate;
                for i=g.bst:length(imu_velCal)
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.fin,:)./(g.fin-g.bst).*(i-g.bst) * velCalRate; % bst~fin
                end
                imu_velCal(g.fin+1:end,:)=0;
                
                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);
            
            
                %% circular trajectory correction
                [center,vn,rad]=circfit3d(imu_trajCal(g.add:g.fin,:)); vn=vn./norm(vn);                % backswing, apdm_trajCal
                sumR=zeros(3);
                n=g.fin-g.add+1;
                for i=g.add:g.fin
                    sumR=sumR+(n+g.add-i)*Rinf(:,:,i); 
                end
                d=center+dot((imu_trajCal(g.fin,:)-center),vn').*vn'; %vn is a unit vector
                Calrad=imu_trajCal(g.fin,:)-d;
            %             rad=rad-norm(apdm_trajCal(g.imp,:));    % calibration based on impact point
                endpoint=center+Calrad.*rad./norm(Calrad);                    % g.fin end point on the fitted circle
                imu_bias=inv(sumR)*(imu_trajCal(g.fin,:)-endpoint)'./ts^2;   % local frame accelerometer bias xyz
            
                [dot1, ddot1] = deriv5(imu_velCal(:,1),ts);
                [dot2, ddot2] = deriv5(imu_velCal(:,2),ts);
                [dot3, ddot3] = deriv5(imu_velCal(:,3),ts);
                imu_accelCal=[dot1 dot2 dot3];         % global
            
                imu_localCal=zeros(length(imu_accelCal),3);
    
                for i=1:length(imu_accelCal)
                    imu_localCal(i,:) = Rinf(:,:,i)^(-1)*[imu_accelCal(i,1);imu_accelCal(i,2);imu_accelCal(i,3)];
                end
                ag_wristCal=zeros(length(imu_accelCal),3);
                for i=1:length(imu_accelCal)
                    ag_wristCal(i,:) = Rinf(:,:,i)*([imu_localCal(i,1);imu_localCal(i,2);imu_localCal(i,3)]-imu_bias);
                end
                imu_velCalL(:,1)=cumtrapz(ts,ag_wristCal(:,1));
                imu_velCalL(:,2)=cumtrapz(ts,ag_wristCal(:,2));
                imu_velCalL(:,3)=cumtrapz(ts,ag_wristCal(:,3));
                imu_velCalL=imu_velCalL-imu_velCalL(g.add,:);  % address zeroing
                imu_velCalL(1:g.add,:)=0;
                imu_velCalL(g.fin:end,:)=0;
                imu_trajCalL=cumtrapz(ts,imu_velCalL);
                imu_trajCalL=imu_trajCalL-imu_trajCalL(g.add,:);
               
            
                %% proposed method integration result
                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);
                
    
                % replace imp_est with the subject mean?
                imp_est_list = [imp_est_list; rel_est];
               
    
                % 0710 % pull it down like the velocity
                diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];
    
                % initialise the new trajectory
                traj_lin = imu_trajCal;                   % copy of the original
    
                % 1) ADD ~ IMP : correct by spreading linearly / weighting towards fin
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                    traj_lin(k,:) = imu_trajCal(k,:) - w * diff;  % 1×3 vector
                end
                traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin, 1);


                apdm_biasV_list = [apdm_biasV_list; diff];
                %trial-by-trial correction
                apdm_trajCalV = traj_lin;
                
                %% ML-corrected integration result
                traj_lin_subj = imu_trajCal; 
                
                % if trial>25
                % if trial>5
    
                
                %% to obtain ori0 in iron & fast shot
    
    
                if club==3
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
                else
                    if trial>20
                    % if trial>25
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj); 
                        % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,subj); % 9 test with 9 training
                        % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,10); % 9 test with 8 training
                    else %dummy value
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(1,:,subj);
                    end
                end
                % diff_ml =  [1 1 1]; % dummy
                % 
                % 
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                    traj_lin_subj(k,:) = imu_trajCal(k,:) - w * diff_ml;  % 1×3 vector
                end
    
                traj_lin_subj(g.fin+1:end,:) = repmat(traj_lin_subj(g.fin,:), n_rows_fin, 1);

                % 
                % % % % % 3D visualisation plot of the predicted data
                % figure(100+trial);
                % hold on;
                % % plot3(apdm_trajCalV(g.imp-20:g.imp+20,1), apdm_trajCalV(g.imp-20:g.imp+20,2), apdm_trajCalV(g.imp-20:g.imp+20,3),'r');
                % % plot3(imu_traj(g.imp-20:g.imp+20,1), imu_trajCalL(g.imp-20:g.imp+20,2), imu_trajCalL(g.imp-20:g.imp+20,3),'Color', [0.5 0.5 0.5]);
                % % plot3(imu_trajCalL(g.imp-20:g.imp+20,1), imu_traj(g.imp-20:g.imp+20,2), imu_traj(g.imp-20:g.imp+20,3),'Color', [1 0.8 0.8]); 
                % % plot3(Mtraj(g.imp-20:g.imp+20,1), Mtraj(g.imp-20:g.imp+20,2), Mtraj(g.imp-20:g.imp+20,3),'k');
                % 
                % g.fin = 800;
                % 
                % % plot3(apdm_trajCalV(1:g.fin,1), apdm_trajCalV(1:g.fin,2), apdm_trajCalV(1:g.fin,3),'r','LineWidth', 3);
                % plot3(imu_traj(1:g.fin,1), imu_traj(1:g.fin,2), imu_traj(1:g.fin,3),'b','LineWidth', 1.5); %,'LineStyle', '--'); %[0.3 0.3 0.3]
                % plot3(traj_lin_subj(1:g.fin,1), traj_lin_subj(1:g.fin,2), traj_lin_subj(1:g.fin,3),'Color',dark_green,'LineWidth', 3);
                % plot3(Mtraj(g.add:g.fin,1), Mtraj(g.add:g.fin,2), Mtraj(g.add:g.fin,3),'k','LineWidth', 3);
                % 
                % 
                % 
                % % mark a specific point (e.g. the 10th point) with a star
                % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 15);
                % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'bp', 'MarkerSize', 15);
                % plot3(traj_lin_subj(g.imp,1), traj_lin_subj(g.imp,2), traj_lin_subj(g.imp,3), 'gp', 'MarkerSize', 15);
                % 
                % % % distinguish the edge and the interior with different colours
                % % % the difference cannot possibly be this large
                % % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow'); % specify the edge color
                % % plot3(apdm_trajCalV(g.imp,1), apdm_trajCalV(g.imp,2), apdm_trajCalV(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
                % % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
                % 
                % % add axis labels
                % % xlabel('X-axis(mm)');
                % % ylabel('Y-axis(mm)');
                % % zlabel('Z-axis(mm)');
                % 
                % axis equal;
                % grid off;
                % % the viewing angle can be changed
                % % view(3);
                % % view(0, 0);
                % % view(0, 90);  % or view(2)
                % view(90, 0);
                % % % 
                % % % print(gcf, 'plot_traj_prop.svg', '-dsvg', '-vector');
    
    
                % % check integration results, per trial
                % for k = 1:3
                %     figure(trial*3+k)
                %     hold on;
                %     plot(Mtraj(:,k),'Color','k');
                %     plot(imu_traj(:,k),'Color','g');
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % plot(imu_trajCalL(:,k),'Color','b');
                %     % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                % 
                %     % plot(Lsho(:,k),'Color','r');
                %     % legend('ref','imu','imu vel','circle','imp','video');
                %     % legend('ref','imu','vel','video');
                %     xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                %     xlim([g.add-200 g.fin+10])
                % end
    
                % consist_colors = turbo(20);
                % % %% check integration results, all trials at once
                % for k = 1:3
                %     figure(k)
                %     hold on;
                %     % plot(ag_wo_g(:,k)) % turns out looking at them together makes no sense..
                %     plot(imu_vel(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial)*2,:),'LineWidth', 1.5);
                %     % plot(imu_traj(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % % plot(imu_trajCalL(:,k),'Color','b');
                %     % % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     % plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                %     % %mean correction
                %     % plot(traj_lin_subj(:,k),'Color','b'); % proposed correction
                %     % % plot(Lsho(:,k),'Color','r');
                %     % % legend('ref','imu','imu vel','circle','imp','video');
                %     % % legend('ref','imu','vel','video');
                %     xline([g.add g.imp],'-',{'BST','IMP'},'HandleVisibility','off');
                %     xlim([690 710])
                %     % ylim([-1500 1500])
                % end
                % 
                % % convert to mm for visualisation
                % acc_data(:,:) = acc_data(:,:).*1000;
                % for k = 4:6
                %     figure(k)
                %     hold on;
                %     plot(ag_wo_g(:,k-3),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(acc_data(:,k-3),'Color',consist_colors((trial-20)*2,:));
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial-20)*2,:));
                %     % plot(imu_traj(:,k),'Color',consist_colors((trial-20)*2,:));
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % % plot(imu_trajCalL(:,k),'Color','b');
                %     % % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     % plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                %     % %mean correction
                %     % plot(traj_lin_subj(:,k),'Color','b'); % proposed correction
                %     % % plot(Lsho(:,k),'Color','r');
                %     % % legend('ref','imu','imu vel','circle','imp','video');
                %     % % legend('ref','imu','vel','video');
                %     xline([g.add g.imp],'-',{'BST','IMP'},'HandleVisibility','off');
                %     % xlim([350 800])
                %     xlim([690 710])
                %     % ylim([-1500 1500])
                % end
    
    
               
            
                % calculate angle error , quaternion
                angle_error=[];
                axis_error=[];
                for i=1:length(time) %s.address:s.finish
                    qprod = quaternProd(quaternConj(qinf(i,:)),R2Lwq(i,:)); %proposed vs reference
                    tempAng = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);
                    tempAxs = [qprod(2)/sqrt(1-qprod(1)^2), qprod(3)/sqrt(1-qprod(1)^2), qprod(4)/sqrt(1-qprod(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error=[angle_error, tempAng]; %per-trial error value, means the rotation angle between the two quaternions
                    axis_error=[axis_error; tempAxs]; % “axis (direction) about which the rotation occurs” information, does not seem to be an error
                end
                
                angle_error_ref=[];
                axis_error_ref=[];
                
                for i=1:length(time) %s.address:s.finish
                    qprod_ref = quaternProd(quaternConj(qinf_ref(i,:)),R2Lwq(i,:)); %proposed vs reference
                    tempAng = abs(2 * atan2(norm(qprod_ref(2:4)),qprod_ref(1))*180/pi);
                    tempAxs = [qprod_ref(2)/sqrt(1-qprod_ref(1)^2), qprod_ref(3)/sqrt(1-qprod_ref(1)^2), qprod_ref(4)/sqrt(1-qprod_ref(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error_ref=[angle_error_ref, tempAng]; %per-trial error value, means the rotation angle between the two quaternions
                    axis_error_ref=[axis_error_ref; tempAxs]; % “axis (direction) about which the rotation occurs” information, does not seem to be an error
                end
    
                
                % rmse_Rot = sqrt(mean(angle_error(s.address:s.finish).^2));
                % mae_Rot = mean(angle_error(s.address:s.finish));
                angle_error_plot = [angle_error_plot angle_error'];
                angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];
    
                angle_error_q = angle_error(g.add:g.fin);
                angle_error_imp = angle_error(g.add:g.imp);
                angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];
                % angle_error_q_list = [angle_error_q_list mean(abs(angle_error_q))];
                % angle_error_add2imp = [angle_error_add2imp mean(abs(angle_error_imp))];
    
                angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
                angle_error_add2imp = [angle_error_add2imp mean(angle_error_imp)];
    
    
                % quaternion angle error visualisation
                % figure(subj+100)
                % plot(angle_error_q);
                % hold on;
    
                % % 3-axis angle error
                angle_error_axis = []; % check whether globally aligned
                angle_error_axis_ref = [];
                % the 3-axis one did not start from address...
                %% locally align check, ' added
                for i = 1:length(time)
                    % R1 = R2Lw(:,:,i)';
                    % R2 = Rinf(:,:,i)';  % example of the second rotation matrix
                    
                    % globally align
                    R1 = R2Lw(:,:,i);
                    R2 = Rinf(:,:,i);  % example of the second rotation matrix
                    % 
                    % difference between the two rotation matrices (relative rotation matrix)
                    % R_diff = R1 * R2';
                    R_diff = R2 * R1'; %how much the reference value must be rotated to become the estimate % the angle error in the world frame can be interpreted directly
            
                    % convert R_diff to Euler angles (XYZ order)
                    eul_angles = rotm2eul(R_diff, 'ZYX');
            
                    % angle error about each axis (converting radians to degrees)
                    roll_error_deg = rad2deg(eul_angles(1));   % x-axis (roll) error
                    pitch_error_deg = rad2deg(eul_angles(2));  % y-axis (pitch) error
                    yaw_error_deg = rad2deg(eul_angles(3));    % z-axis (yaw) error
    
    
    
                    %% additional code for reference
                    R1 = R2Lw(:,:,i);
                    R2 = Rinf_ref(:,:,i);  % example of the second rotation matrix
                    % 
                    % difference between the two rotation matrices (relative rotation matrix)
                    R_diff = R2 * R1'; %how much the reference value must be rotated to become the estimate % the angle error in the world frame can be interpreted directly
    
                    % convert R_diff to Euler angles (XYZ order)
                    eul_angles = rotm2eul(R_diff, 'ZYX');
    
                    % angle error about each axis (converting radians to degrees)
                    roll_error_deg_ref = rad2deg(eul_angles(1));   % x-axis (roll) error
                    pitch_error_deg_ref = rad2deg(eul_angles(2));  % y-axis (pitch) error
                    yaw_error_deg_ref = rad2deg(eul_angles(3));    % z-axis (yaw) error
    
            
                    % store the error angle about each axis in an array
                    % for the numbers
                    % angle_error_axis = [angle_error_axis; abs(roll_error_deg), abs(pitch_error_deg), abs(yaw_error_deg)];
                    % for plotting the graph
                    angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];
    
                    angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];
    
                end
           
                angle_error_axis_list(:,:,z) = angle_error_axis;
                angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;
    
                
                plot_ds_ref(:,:,z) = Mtraj;
                plot_ds_prop(:,:,z) = apdm_trajCalV;
                plot_ds_driver(:,:,z) = traj_lin_subj;
                % plot_ds_imu(:,:,z) = imu_trajCal;
    
                plot_ds_imu(:,:,z) = imu_traj;
                plot_imu_vel(:,:,z) = imu_vel ;
                plot_imu_acc(:,:,z) = ag_wo_g;
    
                plot_imu_acc_local(:,:,z) = acc_data;
                
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial-20, subj};
                plot_ds_ml(:,:,z) = ml_traj_check;
    
    
                % mae error
                switch mae_method
                    case 0
                        test_drift = imu_traj;
                    case 1
                        test_drift = imu_trajCal; %wait, is this one more accurate in 3D than apdm_trajCalV?
                    case 2
                        test_drift = imu_trajCalL;
                    case 3
                        test_drift = imu_trajCalI; %the code probably needs changing to pin it down with the actual marker
                    case 4
                        test_drift = apdm_trajCalV; % traj_lin_subj, imu only  % apdm_trajCalV trial by trial correction
                    case 5
                        test_drift = traj_lin_subj;
                    case 6
                        test_drift = ml_traj_check;
                end

                switch mae_method_vel
                    case 0
                        test_drift_vel = imu_vel;
                    case 1
                        test_drift_vel = imu_velCal;
                    case 2
                        test_drift_vel = imu_velCalL;
                    case 3
                        test_drift_vel = imu_velCalI;
                    case 4
                        test_drift_vel = apdm_velCalV;
                end

                %% Mtraj is the wrist % segment definition

                start_traj = g.add;
                % end_traj = g.fin;
                end_traj = 800;
                % end_traj = g.imp;
                error = Mtraj(start_traj:end_traj,:)-test_drift(start_traj:end_traj,:);

                % summarise the errors
                Mae_XYZ = mean(abs(error));
                % the mean (scalar) of the per-frame Euclidean error, widely used as the representative value
                Mae_norm = mean(vecnorm(error,2,2));
                rmse_xyz = sqrt(mean(error.^2, 1));
                rmse_overall = sqrt(mean(sum(error.^2, 2)));

                % compute mae
                mae_list = [mae_list; Mae_XYZ];
                mae_norm_list = [mae_norm_list; Mae_norm];
                rmse_xyz_list = [rmse_xyz_list; rmse_xyz];
                rmse_norm_list = [rmse_norm_list; rmse_overall];


                %% how should the velocity comparison be done?
                error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
                error_vellist = [error_vellist; mean(abs(error_vel))];
                
    
    
                %for computing the mean over all trials
                z= z+1;
    
      
                
                % % preparation for machine learning % build the set including the raw data and the reference values
                swingData_2508(subj).clubN(club).trialN(trial).apdm = [ag_wo_g w_dcm acc_data gyro_data];
                swingData_2508(subj).clubN(club).trialN(trial).rel = [rel_est ref_rel_imp];
                swingData_2508(subj).clubN(club).trialN(trial).vel_integration = [imu_vel imu_velCal Mvel];
                swingData_2508(subj).clubN(club).trialN(trial).traj_integration = [imu_traj imu_trajCal imu_trajCalL apdm_trajCalV Mtraj];
            end
        end
        % disp(subj)
    end
    
    
    
    % error over the whole swing
    % mean/standard deviation
    summary.mae_xyz_mean = mean(mae_list, 1);
    summary.mae_xyz_std  = std (mae_list, 0, 1);
    summary.rmse_xyz_mean= mean(rmse_xyz_list, 1);
    summary.rmse_xyz_std = std (rmse_xyz_list, 0, 1);
    
    summary.mae_norm_mean  = mean(mae_norm_list);
    summary.mae_norm_std   = std (mae_norm_list);
    summary.rmse_norm_mean = mean(rmse_norm_list);
    summary.rmse_norm_std  = std (rmse_norm_list);
    
    T = table( ...
      summary.mae_xyz_mean', summary.mae_xyz_std', ...
      summary.rmse_xyz_mean', summary.rmse_xyz_std', ...
      'VariableNames', {'MAE_mean','MAE_std','RMSE_mean','RMSE_std'}, ...
      'RowNames', {'X','Y','Z'});
    disp(T)
    
    fprintf('MAE(norm) = %.2f ± %.2f mm\n', ...
        summary.mae_norm_mean, summary.mae_norm_std);
    fprintf('RMSE(norm)= %.2f ± %.2f mm\n', ...
        summary.rmse_norm_mean, summary.rmse_norm_std);


    
    

    
    
    
    % check the trend of the 3-axis error
    %% compute the mean and standard deviation at each time point
    mean_xyz = mean(angle_error_axis_list, 3);  % mean over the 3rd dimension (number of data points) (900x3)
    std_xyz = std(angle_error_axis_list, 0, 3); % standard deviation over the 3rd dimension (number of data points) (900x3)
    
    mean_xyz_ref = mean(angle_error_axis_list_ref, 3);  % mean over the 3rd dimension (number of data points) (900x3)
    std_xyz_ref = std(angle_error_axis_list_ref, 0, 3); % standard deviation over the 3rd dimension (number of data points) (900x3)
    
    
    
    
    
    
    
    %% everything up to here works
    
    % ====== preparation ======
    t = time(:)';          % ensure a row vector
    M = mean_xyz;          % [N x 3] proposed method mean
    S = std_xyz;           % [N x 3] proposed method std
    MR = mean_xyz_ref;     % [N x 3] reference mean
    SR = std_xyz_ref;      % [N x 3] reference std
    
    % size validation (to prevent problems)
    assert(size(M,1)==numel(t) && size(M,2)==3, 'mean_xyz size needs checking');
    assert(isequal(size(S), size(M)), 'std_xyz size needs checking');
    assert(isequal(size(MR), size(M)) && isequal(size(SR), size(S)), 'ref size mismatch');
    
    % colour/style
    col_prop = [179 0 25]/255;     % proposed method: red (same for all axes)
    col_ref_line = [0 0 0];        % reference line: black
    col_ref_fill = 0.70*[1 1 1];   % reference shading: grey
    
    alpha_prop = 0.18;             % proposed method shading
    alpha_ref  = 0.16;             % reference shading (slightly lighter)
    lw = 1.6;
    axisLabel = {'X','Y','Z'};
    
    
    % convert to cm
    plot_ds_ref = plot_ds_ref.*0.1;
    plot_ds_prop = plot_ds_prop.*0.1;
    plot_ds_imu = plot_ds_imu.*0.1;
    plot_ds_driver = plot_ds_driver.*0.1;

    plot_ds_ml = plot_ds_ml.*0.1;
    % subj_ds_imu = subj_ds_imu.*0.1;
    % subj_local_imu = subj_local_imu.*0.1;
    
    
    % % assess the variability per data set
    % S_ref = cvabs_between_ts_timeAxesTrials(plot_ds_ref(630:701,:,:)); 
    % S_imu = cvabs_between_ts_timeAxesTrials(plot_ds_imu(630:701,:,:)); 
    % S_local = cvabs_between_ts_timeAxesTrials(subj_local_imu(630:701,:,:)); 
    
    
    
    
    
    
    %% ===== input: angle_error_plot (T×N), angle_error_plot_ref (T×N) =====
    T = size(angle_error_plot,1);
    N = size(angle_error_plot,2);
    assert(all(size(angle_error_plot_ref)==[T N]), 'angle_error_plot_ref size mismatch');
    
    % time axis
    if exist('time','var') && numel(time)==T
        t = time(:)';     % row vector
    else
        t = 1:T;
    end
    
    % colour/style
    col_prop     = [1 0 0];          % proposed method: red
    col_ref_line = [0 0 0];          % reference line: black
    col_ref_fill = 0.70*[1 1 1];     % reference shading: grey
    alpha_prop   = 0.18;             % shading transparency (proposed method)
    alpha_ref    = 0.16;             % shading transparency (reference)
    lw = 1.6;
    
    
    
    
    
    
    % compute the mean and standard deviation per axis
    ref_mean_x = mean(plot_ds_ref(:, 1, :), 3); % x-axis mean
    ref_std_x = std(plot_ds_ref(:, 1, :), 0, 3); % x-axis standard deviation
    if subj==8 % the last trial must be excluded
        ref_mean_x = mean(plot_ds_ref(:, 1, 1:9), 3); % x-axis mean
        ref_std_x = std(plot_ds_ref(:, 1, 1:9), 0, 3); % x-axis standard deviation
    end
    
    ref_mean_y = mean(plot_ds_ref(:, 2, :), 3); % y-axis mean
    ref_std_y = std(plot_ds_ref(:, 2, :), 0, 3); % y-axis standard deviation
    if subj==8 % the last trial must be excluded
        ref_mean_y = mean(plot_ds_ref(:, 2, 1:9), 3); % x-axis mean
        ref_std_y = std(plot_ds_ref(:, 2, 1:9), 0, 3); % x-axis standard deviation
    end
    
    ref_mean_z = mean(plot_ds_ref(:, 3, :), 3); % z-axis mean
    ref_std_z = std(plot_ds_ref(:, 3, :), 0, 3); % z-axis standard deviation
    if subj==8 % the last trial must be excluded
        ref_mean_z = mean(plot_ds_ref(:, 3, 1:9), 3); % x-axis mean
        ref_std_z = std(plot_ds_ref(:, 3, 1:9), 0, 3); % x-axis standard deviation
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    proposed_mean_x = mean(plot_ds_prop(:, 1, :), 3); % x-axis mean
    proposed_std_x = std(plot_ds_prop(:, 1, :), 0, 3); % x-axis standard deviation
    
    proposed_mean_y = mean(plot_ds_prop(:, 2, :), 3); % y-axis mean
    proposed_std_y = std(plot_ds_prop(:, 2, :), 0, 3); % y-axis standard deviation
    
    proposed_mean_z = mean(plot_ds_prop(:, 3, :), 3); % z-axis mean
    proposed_std_z = std(plot_ds_prop(:, 3, :), 0, 3); % z-axis standard deviation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    imu_mean_x = mean(plot_ds_imu(:, 1, :), 3); % x-axis mean
    imu_std_x = std(plot_ds_imu(:, 1, :), 0, 3); % x-axis standard deviation
    
    imu_mean_y = mean(plot_ds_imu(:, 2, :), 3); % y-axis mean
    imu_std_y = std(plot_ds_imu(:, 2, :), 0, 3); % y-axis standard deviation
    
    imu_mean_z = mean(plot_ds_imu(:, 3, :), 3); % z-axis mean
    imu_std_z = std(plot_ds_imu(:, 3, :), 0, 3); % z-axis standard deviation
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    driver_mean_x = mean(plot_ds_driver(:, 1, :), 3); % x-axis mean
    driver_std_x = std(plot_ds_driver(:, 1, :), 0, 3); % x-axis standard deviation
    
    if subj==8 % the last trial must be excluded
        driver_mean_x = mean(plot_ds_driver(:, 1, 1:9), 3); % x-axis mean
        driver_std_x = std(plot_ds_driver(:, 1, 1:9), 0, 3); % x-axis standard deviation
    end

    driver_mean_y = mean(plot_ds_driver(:, 2, :), 3); % y-axis mean
    driver_std_y = std(plot_ds_driver(:, 2, :), 0, 3); % y-axis standard deviation
    if subj==8 % the last trial must be excluded
        driver_mean_y = mean(plot_ds_driver(:, 2, 1:9), 3); % x-axis mean
        driver_std_y = std(plot_ds_driver(:, 2, 1:9), 0, 3); % x-axis standard deviation
    end
    
    driver_mean_z = mean(plot_ds_driver(:, 3, :), 3); % z-axis mean
    driver_std_z = std(plot_ds_driver(:, 3, :), 0, 3); % z-axis standard deviation
    if subj==8 % the last trial must be excluded
        driver_mean_z = mean(plot_ds_driver(:, 3, 1:9), 3); % x-axis mean
        driver_std_z = std(plot_ds_driver(:, 3, 1:9), 0, 3); % x-axis standard deviation
    end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    ml_mean_x = mean(plot_ds_ml(:, 1, :), 3); % x-axis mean
    ml_std_x = std(plot_ds_ml(:, 1, :), 0, 3); % x-axis standard deviation
    
    if subj==8 % the last trial must be excluded
        ml_mean_x = mean(plot_ds_ml(:, 1, 1:9), 3); % x-axis mean
        ml_std_x = std(plot_ds_ml(:, 1, 1:9), 0, 3); % x-axis standard deviation
    end

    ml_mean_y = mean(plot_ds_ml(:, 2, :), 3); % y-axis mean
    ml_std_y = std(plot_ds_ml(:, 2, :), 0, 3); % y-axis standard deviation
    if subj==8 % the last trial must be excluded
        ml_mean_y = mean(plot_ds_ml(:, 2, 1:9), 3); % x-axis mean
        ml_std_y = std(plot_ds_ml(:, 2, 1:9), 0, 3); % x-axis standard deviation
    end
    
    ml_mean_z = mean(plot_ds_ml(:, 3, :), 3); % z-axis mean
    ml_std_z = std(plot_ds_ml(:, 3, :), 0, 3); % z-axis standard deviation
    if subj==8 % the last trial must be excluded
        ml_mean_z = mean(plot_ds_ml(:, 3, 1:9), 3); % x-axis mean
        ml_std_z = std(plot_ds_ml(:, 3, 1:9), 0, 3); % x-axis standard deviation
    end

    
    
    
    
    %% graph checking the +/- correlation against the mean % a single time point
    %integration error
    mae_list = [];
    mae_norm_list = [];
    rmse_overall = [];
    rmse_xyz_list = [];
    rmse_norm_list = [];
    error_vellist = [];

    
    
    
    
    
    ml_est = struct();
    for c = 1:numel(clubs_ml)
        ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
    end
    
    ml_traj_est = struct();
    for c = 1:numel(clubs_ml)
        ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);  % {trial, subj}
    end
    
    z=1;
    % for subj = [1 2 3 4 6 7 8 10]
    for subj = subj_fast %4 6 8
    % for subj = 1:5
    % for subj = 10
        % for club = [1 3]
        for club = 3
        % for club = 1
    
            % exit the for loop automatically if absent
            fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
            % fname = sprintf('subj%d_%s_est.csv', subj, clubs_ml{club});
            fpath = fullfile(mldataDir, fname);
            if ~isfile(fpath)
                warning('Missing file: %s', fpath);
                continue
            end

            fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
            fpath_traj = fullfile(mldataDir, fname_traj);

    
            T = readtable(fpath);  % column names are recognised automatically if present
            % use only those columns if pred_x, pred_y, pred_z exist, otherwise columns 1~3
            if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
                M = T{:, {'pred_x','pred_y','pred_z'}};
            else
                M = T{:, 1:3};
            end
    
            % match the length (store only 10 rows; missing entries stay NaN)
            m = min(size(M,1), nRows_ml);
            ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);
            
            T_traj = readtable(fpath_traj);
            % store separately by trial_idx
            unique_trials = unique(T_traj.trial_idx);
    
            for i = 1:numel(unique_trials)
                trial_traj = unique_trials(i);
                idx = T_traj.trial_idx == trial_traj;
                
                % store pred
                pred_data = [T_traj.pred_x(idx), T_traj.pred_y(idx), T_traj.pred_z(idx)];
                ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;  % +1 because trial_idx starts from 0
            end

    
            % if subj==5
            %     ml_est.(clubs_ml{club})(1:4, :, subj) = M(1:4, :);
            %     ml_est.(clubs_ml{club})(5, :, subj) = NaN;   % set all axes of trial 5 to NaN
            %     ml_est.(clubs_ml{club})(6:10, :, subj) = M(5:9, :);
            % else
            %     m = min(size(M,1), nRows_ml);
            %     ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);
            % end


            if club==3 && subj==5
                ml_est.(clubs_ml{club})(1:4, :, subj) = M(1:4, :);
                ml_est.(clubs_ml{club})(5, :, subj) = NaN;   % set all axes of trial 5 to NaN
                ml_est.(clubs_ml{club})(6:10, :, subj) = M(5:9, :);
    
                temp = ml_traj_est.(clubs_ml{club})(1:9, subj);
                ml_traj_est.(clubs_ml{club})(1:4, subj) = temp(1:4);
                ml_traj_est.(clubs_ml{club}){5, subj}=NaN;
                ml_traj_est.(clubs_ml{club})(6:10, subj) = temp(5:9);
            end
    
            if club==3 && subj==9 
                ml_est.(clubs_ml{club})(1:7, :, subj) = M(1:7, :);
                ml_est.(clubs_ml{club})(8, :, subj) = NaN; 
                ml_est.(clubs_ml{club})(9:10, :, subj) = M(8:9, :);
    
                temp2 = ml_traj_est.(clubs_ml{club})(1:9, subj);
                ml_traj_est.(clubs_ml{club})(1:7, subj) = temp2(1:7);
                ml_traj_est.(clubs_ml{club}){8, subj}=NaN;
                ml_traj_est.(clubs_ml{club})(9:10, subj) = temp2(8:9);
            end
            
            % for trial = 1:30
            for trial = 1:10
            % for trial = 11:20
            % for trial = 21:30
            % for trial = 20:29
            % for trial = 26:30
            % for trial = 7
                if subj==1 && club==2 && trial ==1 % looks like an apdm recording error
                    continue
                elseif subj==5 && club==3 && trial==5 % could not be derived from the video at all
                    continue
                elseif subj==9 && club==3 && trial==8 % the apdm value seems odd, comes out nan
                    continue
                elseif subj==8 && club==1 && trial ==30 % magnetometer measurement error
                    continue
                % elseif subj==10
                %     continue
                end
    
                %% filter out the odd gyro ones?
    
                if club==3 && (trial>10)
                    continue;
                end
                g = swingData_2508(subj).clubN(club).trialN(trial);
    
                % need the mat with the updated event timings
                % g.add = double(g.add_imu);
                % g.bst = double(g.bst_imu);
                % g.imp = double(g.imp_imu1);
                % g.fin = double(g.fin_imu);

                g.add = double(g.add);
                g.bst = double(g.bst);
                g.imp = double(g.imp);
                g.fin = double(g.fin);
    
                % remove the error at the fin event
                if g.fin>900
                    g.fin = 900;
                end


                backswing_fast = g.bst-g.add;
                downswing_fast = g.imp-g.bst;
                swing_tempo_fast = backswing_fast/downswing_fast;
                swing_tempo_fast_list = [swing_tempo_fast_list swing_tempo_fast];
                
                time_start_idx =  g.add;
                time_end_idx = g.imp;
                swing_time_fast = time_end_idx-time_start_idx;
                swing_time_fast_list = [swing_time_fast_list swing_time_fast];

    
                % % identify the imp event
                % Lhand = g.marker(g.bst:g.imp+1, 13:15); % coordinates of the first marker (columns 13~15)
                % clubhead = g.marker(g.bst:g.imp+1, 19:21); % coordinates of the second marker (columns 19~21) % from the plot, imp+1 seems to be right
                % 
                % % 3D plot settings
                % figure(trial*550);
                % hold on;
                % grid on;
                % xlabel('X');
                % ylabel('Y');
                % zlabel('Z');
                % title('3D Swing Trajectory');
                % % view(3); % 3D viewpoint setting
                % view([90 0]);
                % 
                % % plot the 3D swing trajectory over time
                % for t = 1:size(Lhand, 1)
                %     % % connect from the origin to the first marker
                %     % plot3([0, Lhand(t, 1)], [0, Lhand(t, 2)], [0, Lhand(t, 3)], 'r-', 'LineWidth', 1.5);
                %     % 
                %     % connect from the first marker to the second marker
                %     plot3([Lhand(t, 1), clubhead(t, 1)], ...
                %           [Lhand(t, 2), clubhead(t, 2)], ...
                %           [Lhand(t, 3), clubhead(t, 3)], 'b-', 'LineWidth', 1.5);
                % 
                %     plot3(0, 0, 0, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); % mark the origin (0,0,0) with a red dot
                % 
                %     % update the plot
                %     drawnow;
                % end
                % hold off;
    
                %% Orientation from marker
                % apdm version
                WristU = g.marker(:,13:15); % inner side of the left wrist
                WristM = g.marker(:,10:12); % top
                WristL = g.marker(:,7:9); % outer side of the left wrist % i.e. front
                acc_data = g.apdm(:,1:3);
                gyro_data = g.apdm(:,4:6);
                magnet = g.apdm(:,7:9);
                abs_wrist = (WristU+WristL)./2;
                rias = g.marker(:,1:3);
                lias = g.marker(:,4:6);
                com = (rias+lias)./2;
    
    
                
                % figure(2027)
                % hold on;
                % plot(vecnorm(abs_wrist, 2, 2))
                % xline([g.add g.imp],'-',{'ADD','IMP'},'HandleVisibility','off');
                % 
    
    
    
                % 1019 done during mat processing
                % % 0518 filtering step after rawdata processing
                % [b, a] = butter(4, cut_freq/(200/2));
                % acc_data = filtfilt(b, a, acc_data);
                % gyro_data = filtfilt(b, a, gyro_data);
                % magnet = filtfilt(b, a, magnet);
                
                % gpt yaw derivation
                % % should this be done in the mat instead?
                % m = magnet; 
                % % --- simple hard/soft iron correction (diagonal approximation) ---
                % b = (max(m,[],1) + min(m,[],1))/2;     % bias (per-axis mean centre)
                % s = (max(m,[],1) - min(m,[],1))/2;     % radius
                % gmean = mean(s);
                % scale = gmean ./ s;                    % approximate soft-iron axis scale (diagonal approximation)
                % m_cal = (m - b) .* scale;              % quick approximate correction (the exact model is an ellipsoid fit)
                % 
                % %how about skipping cal? the one above gives a 17 deg error
    
                m_cal = magnet; 
                
                % modify if the event timings are changed
                add_est = g.add_est;
                imp_est = g.imp_est;

                % add_est = g.add_imu_est;
                % imp_est = g.imp_imu1_est;
        
                rel_est = imp_est - add_est; % not used here
                
                % computed with agformer
                % rel_est = g.dl(g.imp,1:3) - g.dl(g.add,1:3);

    
    
                % even odder, and x is still odd..
                % imp_est = g.vid_min_est;
    
                % also check for motionag % x is still odd
                % add_est = g.dl(g.add,1:3);
                % imp_est = g.dl(g.imp,1:3);
    
                
                motionag = g.dl(:,1:3);
                % motionag + com = algo at world coordinate 
                motionag = motionag+ com;
    
    
                % figure(30000)
                % hold on;
                % scatter3(add_est(:,1), add_est(:,2), add_est(:,3), ...
                %          50, 'k', 'filled');
                % text(add_est(:,1), add_est(:,2),add_est(:,3), sprintf('%d',trial), 'FontSize',9, ...
                %  'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
                %  'VerticalAlignment','bottom','Clipping','on');
                % scatter3(abs_wrist(g.add,1), abs_wrist(g.add,2), abs_wrist(g.add,3), ...
                %          50, 'g', 'filled');
                % 
                % % Scatter plot - prop data
                % scatter3(imp_est(:,1), imp_est(:,2), imp_est(:,3), ...
                %          50, dark_red, 'filled');
                % scatter3(abs_wrist(g.imp,1), abs_wrist(g.imp,2), abs_wrist(g.imp,3), ...
                %          50, 'r', 'filled');
                % text(imp_est(:,1), imp_est(:,2),imp_est(:,3), sprintf('%d',trial), 'FontSize',9, ...
                %  'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
                %  'VerticalAlignment','bottom','Clipping','on');
                % 
                % xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
                % 
                % grid on;
                % view(3);
                % axis equal;  % so that the ellipsoid is not distorted
    
    
    
                %%  figure1 3d position derivation
                % compare the estimation with the marker values
                % check the wrist position in the actual marker frame rather than the relative est
                % !only knowable if com is available!
                % for k = 1:3
                %     figure(trial*3+k)
                %     hold on;
                %     plot(WristM(:,k),'Color','k');
                %     plot(motionag(:,k),'Color', [0.7, 0.7, 0.7]);
                %     plot(g.add, g.add_est(k), 'ro', 'MarkerSize', 8); 
                %     plot(g.imp, g.imp_est(k), 'ro', 'MarkerSize', 8); 
                % 
                %     xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                %     xlim([g.add-10 g.fin+10])
                % end
                
                ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);
    
                add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
                imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
                imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));
                
                add_pos_error_prop =abs_wrist(g.add,:)-add_est;
                imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
                imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);
    
                % … each error vector computed above …
                ok = true;  % included by default
                
                % pelvis-related statistics
                % exclusion conditions (add freely with whatever rule you want)
                ok = ok && ~(club==3);
                ok = ok && ~(subj==2 && club==1 && trial==10);
                ok = ok && ~(subj==2 && club==2 && ismember(trial,[23 29]));
                ok = ok && ~(subj==3 && club==2 && ismember(trial,[1 11 14 15]));
                ok = ok && ~(subj==6 && club==1 && trial==3);
                
                % if cases where the data itself is broken with NaN/Inf etc. should also be excluded:
                ok = ok && all(isfinite([add_pos_error_ag, imp_pos_error_ag, imp_rel_pos_error_ag, ...
                                         add_pos_error_prop, imp_pos_error_prop, imp_rel_pos_error_prop]));
                
                if ok
                    add_pos_error_ag_list      = [add_pos_error_ag_list;      abs(add_pos_error_ag)];
                    imp_pos_error_ag_list      = [imp_pos_error_ag_list;      abs(imp_pos_error_ag)];
                    imp_rel_pos_error_ag_list  = [imp_rel_pos_error_ag_list;  abs(imp_rel_pos_error_ag)];
                
                    add_pos_error_prop_list    = [add_pos_error_prop_list;    abs(add_pos_error_prop)];
                    imp_pos_error_prop_list    = [imp_pos_error_prop_list;    abs(imp_pos_error_prop)];
                    imp_rel_pos_error_prop_list= [imp_rel_pos_error_prop_list;abs(imp_rel_pos_error_prop)];
                end
                
    
                % % check the IMU acc 3-axis values
                % figure(trial+5)
                % plot(acc_data(:,1), 'r');    % first column: red
                % hold on
                % grid on
                % plot(acc_data(:,2), 'g');    % second column: green
                % plot(acc_data(:,3), 'b');    % third column: blue
                % xline([g.add],'-',{'ADD'},'HandleVisibility','off');
                % % xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                % legend('acc_x','acc_y','acc_z')
                % xlim([g.add-200 g.add+50])
                % hold off
                
                % %gyro 3 axes in the local frame
                % figure(trial+day*10)
                % plot(gyro_data(:,1), 'r');    % first column: red
                % hold on
                % grid on
                % plot(gyro_data(:,2), 'g');    % second column: green
                % plot(gyro_data(:,3), 'b');    % third column: blue
                % xline([g.add],'-',{'ADD'},'HandleVisibility','off');
                % % xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                % legend('w_x','w_y','w_z')
                % % xlim([g.add-200 g.add+50])
                % % ylim([-0.5 1])
                % hold off
    
    
                Cw = (WristU+WristL)./2;     % center wrist
                Lo = WristL-Cw;             % make center origin
                Mo = WristM-Cw;
                Uo = WristU-Cw;
    
                wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
                wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
                wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);
    
                % prime vector
                temp_x = Uo./wU; % as I recall, back jumps less than front % no, change it later haha
                vprime_xw = Lo./wL;
                vprime_top = Mo./wM;
                vprime_zw = zeros(length(vprime_xw),3);
                vprime_yw = zeros(length(vprime_xw),3);
    
                % target the middle part
                for i = 1:length(vprime_xw)
                    % vprime_zw(i,:) = cross(vprime_top(i,:),vprime_xw(i,:));
                    vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:)); %1017 revision
                end
                % give orthogonality
                for i = 1:length(vprime_xw)
                    vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:)); %1017 revision
                    % vprime_yw(i,:) = cross(vprime_zw(i,:),vprime_xw(i,:));
                end
                for i = 1:length(vprime_xw)
                    vprime_xw(i,:) = cross(vprime_yw(i,:),vprime_zw(i,:));
                end
    
                % normalize
                for i = 1:length(vprime_xw)
                    vprime_xw(i,:)=vprime_xw(i,:) / sqrt(sum(vprime_xw(i,:).^2));
                    vprime_yw(i,:)=vprime_yw(i,:) / sqrt(sum(vprime_yw(i,:).^2));
                    vprime_zw(i,:)=vprime_zw(i,:) / sqrt(sum(vprime_zw(i,:).^2));
                end
    
                % get velocity
                [dot1, ddot1] = deriv5(Cw(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(Cw(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(Cw(1:length(vprime_xw),3),ts);
                Cwdot=[dot1 dot2 dot3];
                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
    
                % for gyro cal
                % for certain data imports the dot dimensions changed so they became dot1' dot2' dot3'/
                % not sure when
                [dot1, ddot1] = deriv5(WristM(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(WristM(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(WristM(1:length(vprime_xw),3),ts);
                WristMdot=[dot1 dot2 dot3];
                WristMddot=[ddot1 ddot2 ddot3];
                WristMdotnorm=sqrt(sum(WristMdot.^2,2));
                [dot1, ddot1] = deriv5(WristU(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(WristU(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(WristU(1:length(vprime_xw),3),ts);
                WristUdot=[dot1 dot2 dot3];
                WristUddot=[ddot1 ddot2 ddot3];
                
                % seems the same as filtering gl_wrist
                cut_freq = 10;
                [b, a] = butter(3, cut_freq/(200/2));
                WristMdot = filtfilt(b, a, WristMdot);
                WristMddot = filtfilt(b, a, WristMddot);
                WristUdot = filtfilt(b, a, WristUdot);
                Cwdot = filtfilt(b, a, Cwdot);
                Cwddot = filtfilt(b, a, Cwddot);
    
                
    
                %% local gyro filtering (marker)
                % calculate local gyro from marker data
                % 1019 revised code
                % gL_wrist=zeros(length(vprime_xw),3);
                % for i=1:length(vprime_xw)
                % omegax should be this by the formula, not sure why the sign is opposite %1020 changed to the one below
                %     gL_wrist(i,:) = [dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                %         dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                %         -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))]; % *180/pi;
                % end
    
                gL_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    gL_wrist(i,:) = [-dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                        dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                        -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))]; % *180/pi;
                end
    
                % % compare the marker angular velocity with the gyro data % gl_wrist is in the local frame
                % figure(trial)
                % plot(gL_wrist)
                % figure(trial+20)
                % plot(gyro_data) %
    
                % rotation matrix
                WristMddot(:,3)=WristMddot(:,3)+9.81;
                R2Lw=zeros(3,3,length(vprime_xw));
                for j = 1:length(vprime_zw)
                    R2Lw(:,:,j) = [vprime_xw(j,:)' vprime_yw(j,:)' vprime_zw(j,:)'];
                end
                % quaternion
                for j = 1:length(vprime_zw) 
                    R2Lwq(j,:) = dcm2quatern(R2Lw(:,:,j)');
                end
                for j = 1:length(vprime_zw) 
                    R2Gwq(j,:) = dcm2quatern(R2Lw(:,:,j));
                end
    
                ag_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    ag_wrist(i,:) = R2Lw(:,:,i)*acc_data(i,:)';
                end
    
                % the bias of acc itself can be checked, acc with gravity obtained from the markers
                % aL_wrist=zeros(length(vprime_xw),3);
                % for i=1:length(vprime_xw)
                %     aL_wrist(i,:) = R2Lw(:,:,i)^(-1)*[WristMddot(i,1);WristMddot(i,2);WristMddot(i,3)];
                % end
    
                % gyro global reference value
                w_global_marker=dcmRot(R2Lw,gL_wrist);
    
                
                % obtain the angle reference values
                local_frame = R2Lw(:,:,g.add);
                pitch_marker = asin(-local_frame(3,1));
                roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
        
                roll_marker=rad2deg(roll_marker);
                pitch_marker=rad2deg(pitch_marker);
                yaw_marker = rad2deg(yaw_marker);

                roll_marker_list = [roll_marker_list,roll_marker];
                pitch_marker_list = [pitch_marker_list, pitch_marker];
                yaw_marker_list = [yaw_marker_list, yaw_marker];
                
                %% Orientation from apdm
                switch OrientationMethod
                    case 0
    
                        Rinf = R2Lw;
                        qinf = R2Lwq;
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data); %the w of omega
    
                        % just to make the code run. the one where only the initial orientation is the reference value
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
            
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                    case 1
                        % DCM
                        Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);
            
                        for t=1:length(time)
                            qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
                            if qinf(t,1)<0
                                qinf(t,:)=-qinf(t,:);
                            end
                        end
    
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                    case 2
                        %calculate with marker gyro
                        Rinf = get_orientation_apdm(time, acc_data, gL_wrist, g.add, R2Lw(:,:,g.add));
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gL_wrist);
            
                        for t=1:length(time)
                            qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf(t,1)<0
                                qinf(t,:)=-qinf(t,:);
                            end
                        end
                    case 7  % roll,pitch derived with the pilot-data formula % comes out well
    
                        local_frame = R2Lw(:,:,g.add);
    
                        pitch_marker = asin(-local_frame(3,1));
                        roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                        yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
                
                        roll_marker=rad2deg(roll_marker);
                        pitch_marker=rad2deg(pitch_marker);
                        yaw_marker = rad2deg(yaw_marker);
                        
                        acclocal_data = acc_data(g.add,:);
                        acc_global = [acclocal_data(1); acclocal_data(2); acclocal_data(3)];
    
                        % Step 2: normalisation (correcting uncalibrated values)
                        acc_norm = norm(acc_global);
                        acc_normalized = acc_global / acc_norm;  % convert to a unit vector
                        % Step 3: compute Roll and Pitch
                        % the gravity vector points along [0, 0, -1] in the global frame
                        ax = acc_normalized(1);
                        ay = acc_normalized(2);
                        az = acc_normalized(3);
                        
                        % compute Roll (rotation about the X axis)
                        roll = atan2(ay, az);
                        % compute Pitch (rotation about the Y axis)
                        pitch = atan2(-ax, sqrt(ay^2 + az^2));
                        
                        phi = roll;
                        theta = pitch;
    
                        % psi = deg2rad(-40);
                        % 
                        % % (additional) magnetometer-based yaw (single frame: g.add)
                        % mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);
                        % % mxh =  mx*cos(theta) + mz*sin(theta); %% apparently multiplied in the order rx*ry
                        % % myh =  mx*sin(phi)*sin(theta) + my*cos(phi) - mz*sin(phi)*cos(theta);
                        % 
                        % % this is indeed the expression that was actually multiplied
                        % mxh =  mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
                        % myh =  my.*cos(phi) - mz.*sin(phi);
                        % 
                        % % disp('norm horizontal component')
                        % check_mag = sqrt(mxh^2+myh^2);
                        % 
                        % check_mag_list = [check_mag check_mag_list];
                        % 
                        % psi = atan2(-myh, mxh);   % rad  <-- replaced by this
                        % % psi = atan2(myh, mxh);   % rad  <-- replaced by this
                        % rad2deg(psi);
                        % 
                        % 
                        % 
                        % % this seems to be about the best possible
                        % psi = -(360-rad2deg(psi))+198.9; %% align magnetic north & mocap north
                        % % disp('yaw marker and mag values in order');
                        % % disp(yaw_marker);
                        % % disp(psi);
                        % 
                        % psi = deg2rad(psi);
                        psi = deg2rad(yaw_marker);
    
                        % phi, theta, psi are all in radians!
                        Rx = [1         0           0
                              0 cos(phi) -sin(phi)
                              0 sin(phi)  cos(phi)];
                    
                        Ry = [ cos(theta) 0 sin(theta)
                               0          1     0
                              -sin(theta) 0 cos(theta)];
                    
                        Rz = [cos(psi) -sin(psi) 0
                              sin(psi)  cos(psi) 0
                              0         0        1];
    
                       
                        % convert radians to degrees
                        roll = rad2deg(roll);
                        pitch = rad2deg(pitch);
                        
                        imu_roll_error = abs(roll_marker-roll);
                        imu_pitch_error = abs(pitch_marker-pitch);
    
                        imu_roll_error_list = [imu_roll_error_list ,imu_roll_error];
                        imu_pitch_error_list = [imu_pitch_error_list,imu_pitch_error];
                        marker_yaw_list = [marker_yaw_list, yaw_marker];
                        imu_yaw_error = abs(yaw_marker-rad2deg(psi));
                        imu_yaw_error_list = [imu_yaw_error_list,imu_yaw_error];
                        
                        % roll pitch error graph
                        % figure(2025)
                        % hold on;
                        % if subj==1
                        %     scatter(roll_marker,roll,50,'r','filled')
                        % elseif subj==2
                        %     scatter(roll_marker,roll,50,'g','filled')
                        % elseif subj==3
                        %     scatter(roll_marker,roll,50,'b','filled')
                        % else
                        %     scatter(roll_marker,roll,50,'k','filled')
                        % end
                        % 
                        % figure(2026)
                        % hold on;
                        % if subj==1
                        %     scatter(pitch_marker,pitch,50,'r','filled')
                        % elseif subj==2
                        %     scatter(pitch_marker,pitch,50,'g','filled')
                        % elseif subj==3
                        %     scatter(pitch_marker,pitch,50,'b','filled')
                        % else
                        %     scatter(pitch_marker,pitch,50,'k','filled')
                        % end
                        
    
                        global_frame=[1 0 0;0 1 0;0 0 1];
                        R2tri = Rz*Ry*Rx*global_frame; 
    
                        Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);
                        % Rinf = get_orientation_apdm(time, acc_data, gL_wrist, g.add, R2tri);
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);
    
                        for j = 1:length(time)
                            qinf(j,:) = dcm2quatern(Rinf(:,:,j)');
                            if qinf(j,1)<0
                                qinf(j,:)=-qinf(j,:);
                            end
                        end
                        
                        
                        %% code for reference
                        % copy-pasted so that any method can be used
                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            % disp(qinf(t,1))
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end
    
                        % if arrow visualisation is needed
                        % figure(trial+(day-1)*20 + subj*1000)
                        % hold on;
                        % 
                        % % set the origin
                        % origin = [0; 0; 0];
                        % 
                        % 
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,1), R2tri(2,1), R2tri(3,1), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,2), R2tri(2,2), R2tri(3,2), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), R2tri(1,3), R2tri(2,3), R2tri(3,3), ...
                        %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % 
                        % quiver3(origin(1), origin(2), origin(3), vprime_xw(g.add,1)', vprime_xw(g.add,2)', vprime_xw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), vprime_yw(g.add,1)', vprime_yw(g.add,2)', vprime_yw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % quiver3(origin(1), origin(2), origin(3), vprime_zw(g.add,1)', vprime_zw(g.add,2)', vprime_zw(g.add,3)', ...
                        %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                        % 
                        % grid on;
                        % xlabel('X-axis');
                        % ylabel('Y-axis');
                        % zlabel('Z-axis');
                        % title('3D Vector Plot');
                        % axis equal;
    
                end   
            
                %% trajectory integration 
    
                [dot1, ddot1] = deriv5(abs_wrist(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(abs_wrist(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(abs_wrist(1:length(vprime_xw),3),ts);
                abs_wrist_dot=[dot1 dot2 dot3];
                abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);
    
                % look only from address onwards
                Mtraj = abs_wrist-abs_wrist(g.add,:);
                Mtraj(1:g.add,:)=0;
                Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
                Mvel(1:g.add,:)=0;
    
                n_rows_fin_fast = size(Mtraj(g.fin+1:end,:), 1);

    
                % Circle fit with marker data points
                [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);                           % address ~ s.finish
                [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);      % bst ~ s.finish
                raddif=[raddif radM-radMs];
                
    
                % gravity is always along the global z direction
                ag_wo_g(:,1) = a_dcm(:,1);
                ag_wo_g(:,2) = a_dcm(:,2);
                ag_wo_g(:,3) = a_dcm(:,3)-9.80665; % should it always be subtracted using the norm?
                %m to mm
                ag_wo_g(:,:) = ag_wo_g(:,:).*1000;
    
    
    
                % % rw=imp_est %apparently a direction vector along the wrist direction is needed
                % % rw = abs_wrist(g.imp,:)
                % % u0 = abs_wrist(g.imp,:)/norm(abs_wrist(g.imp,:))
                % % u1 = abs_wrist(g.imp-1,:)/norm(abs_wrist(g.imp-1,:))
                % % c = max(-1,min(1, dot(u0,u1)))
                % % s = norm(cross(u0,u1))
                % % theta = atan2(s, c)
                % % omega_perp = theta / 0.005
                % 
                % dt = 1/200;
                % % 1) unit vector (opposite of ball -> wrist: towards the origin (ball))
                % rw   = abs_wrist(g.imp,:).';
                % u0   = rw / norm(rw);
                % % rw_m = abs_wrist(g.imp-1,:).';
                % % rw_p = abs_wrist(g.imp+1,:).';
                % % u_m  = -rw_m/norm(rw_m);
                % % u_p  = -rw_p/norm(rw_p);
                % 
                % % 2) angle (radians) and |ω_perp| (central difference)
                % c = max(-1,min(1, dot(u_m, u_p)));
                % s = norm(cross(u_m, u_p));
                % theta = atan2(s, c);
                % omega_perp = theta / (2*dt);          % rad/s
                % 
                % L = vecnorm(abs_wrist(point,:), 2, 2);
                % 
                % r_hat = rw / norm(rw)        % unit vector along the ray direction
                % % w_dcm(g.imp,:)
                % ag_wo_g(g.imp,:)
                % % om2 = dot(w_dcm(g.imp,:), w_dcm(g.imp,:));
                % % om_par   = dot(w_dcm(g.imp,:), r_hat)  ;          % component along r
                % % om_perp2 = om2 - om_par^2 ;        % square of the component perpendicular to r
                % om_new2 = norm(omega_perp)^2;
                % a_rad = dot(ag_wo_g(g.imp,:), r_hat)                 % component towards the origin (+ means towards the origin)
                % % L_imu = a_rad / om_perp2    % dynamic radius estimate
                % L_imu = a_rad / om_new2    % dynamic radius estimation
                % 
                % figure(40000)
                % hold on;
                % origin = [0; 0; 0];
                % 
                % a_glob = ag_wo_g(g.imp,:)/norm(ag_wo_g(g.imp,:));
                % quiver3(origin(1), origin(2), origin(3), r_hat(1), r_hat(2), r_hat(3), ...
                %     0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                % 
                % % quiver3(origin(1), origin(2), origin(3), a_rad(1), a_rad(2), a_rad(3), ...
                % %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                % 
                % quiver3(origin(1), origin(2), origin(3), a_glob(1), a_glob(2), a_glob(3), ...
                %     0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5); % red
                % 
                % grid on;
                % xlabel('X-axis');
                % ylabel('Y-axis');
                % zlabel('Z-axis');
                % title('3D Vector Plot');
                % axis equal;
    
    
                %% integration in the local frame
                % acc_data = acc_data(:,:).*1000;
                % imu_localvel = cumtrapz(time,acc_data);
                % 
                % imu_localvel = imu_localvel-imu_localvel(g.add,:);
                % imu_localvel(1:g.add,:)=0;
                % imu_localtraj=cumtrapz(time,imu_localvel);
                % imu_localtraj=imu_localtraj-imu_localtraj(g.add,:);
    
                imu_vel= cumtrapz(time,ag_wo_g);
                %rad2deg
                w_dcm = w_dcm*180/pi;
                angle_cal=cumtrapz(time,w_dcm);
                % angle_marker=cumtrapz(time,w_global_marker);
               
                
                %% decide whether to zero the input at address
                % % raw trajectory
                % figure(2000)
                % hold on;
                % plot(ag_wo_g(:,1))
                % figure(2001)
                % hold on;
                % plot(ag_wo_g(:,2))
                % figure(2002)
                % hold on;
                % plot(ag_wo_g(:,3))
    
                
                imu_traj=cumtrapz(time,imu_vel);
    
                % % plot velocity and traj before and after zeroing to check the data % per participant
                % figure(3000)
                % hold on;
                % plot(imu_vel(:,1))
                % figure(3001)
                % hold on;
                % plot(imu_vel(:,2))
                % figure(3002)
                % hold on;
                % plot(imu_vel(:,3))
                % 
                % figure(4000)
                % hold on;
                % plot(imu_traj(:,1))
                % figure(4001)
                % hold on;
                % plot(imu_traj(:,2))
                % figure(4002)
                % hold on;
                % plot(imu_traj(:,3))
    
                imu_vel = imu_vel-imu_vel(g.add,:); %address zeroing
    
                imu_vel(1:g.add,:)=0; % initial velocity 0
                imu_traj=cumtrapz(time,imu_vel);
                imu_traj=imu_traj-imu_traj(g.add,:);
                
                % figure(5000)
                % hold on;
                % plot(imu_vel(:,1))
                % figure(5001)
                % hold on;
                % plot(imu_vel(:,2))
                % figure(5002)
                % hold on;
                % plot(imu_vel(:,3))
                % 
                % figure(6000)
                % hold on;
                % plot(imu_traj(:,1))
                % figure(6001)
                % hold on;
                % plot(imu_traj(:,2))
                % figure(6002)
                % hold on;
                % plot(imu_traj(:,3))
    
                
                length_idx = g.imp;
    
                r_hat = abs_wrist(length_idx,:)/norm(abs_wrist(length_idx,:));
                vel_r   = dot(Mvel(length_idx,:), r_hat);          % component along r
                L_delta= vel_r*0.005;
                % disp(L_delta)
    
                rw_vid = imp_est;
                r_hat_vid = rw_vid/norm(rw_vid);
                vel_r_vid  = dot(imu_vel(length_idx,:), r_hat_vid);          % component along r
                % L_delta_vid= vel_r_vid*0.005;
                % disp(L_delta_vid)
    
                L_delta_vid = vecnorm(imu_traj(g.imp,:), 2, 2);
                
                % check whether this is actually correlated with the length variability
                L_now = vecnorm(abs_wrist(length_idx,:), 2, 2);
                % disp(L_now)
    
                if all(isfinite([L_now, L_delta, L_delta_vid]))
                    L_list(end+1)         = L_now;
                    dL_mocap_list(end+1)  = L_delta;
                    dL_vidimu_list(end+1) = L_delta_vid;
                    if exist('trial','var'), trial_list(end+1) = trial; end
                end
    
    
                %% velocity outlier correction
                velCalRate=1; %correction coefficient
                % velocity correction
                imu_velCal =imu_vel;
    
    
                % global based, 3 points(address, backswingtop, finish)
                for i=g.add:g.bst
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.bst,:)./(g.bst-g.add).*(i-g.add) * velCalRate;  % address~g.bst
                end
                imu_velCal(g.bst+1:end,:)=imu_velCal(g.bst+1:end,:)-imu_velCal(g.bst+1,:) * velCalRate;
                for i=g.bst:length(imu_velCal)
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.fin,:)./(g.fin-g.bst).*(i-g.bst) * velCalRate; % bst~fin
                end
                imu_velCal(g.fin+1:end,:)=0;
                
                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);
            
            
                %% circular trajectory correction
                [center,vn,rad]=circfit3d(imu_trajCal(g.add:g.fin,:)); vn=vn./norm(vn);                % backswing, apdm_trajCal
                sumR=zeros(3);
                n=g.fin-g.add+1;
                for i=g.add:g.fin
                    sumR=sumR+(n+g.add-i)*Rinf(:,:,i); 
                end
                d=center+dot((imu_trajCal(g.fin,:)-center),vn').*vn'; %vn is a unit vector
                Calrad=imu_trajCal(g.fin,:)-d;
            %             rad=rad-norm(apdm_trajCal(g.imp,:));    % calibration based on impact point
                endpoint=center+Calrad.*rad./norm(Calrad);                    % g.fin end point on the fitted circle
                imu_bias=inv(sumR)*(imu_trajCal(g.fin,:)-endpoint)'./ts^2;   % local frame accelerometer bias xyz
            
                [dot1, ddot1] = deriv5(imu_velCal(:,1),ts);
                [dot2, ddot2] = deriv5(imu_velCal(:,2),ts);
                [dot3, ddot3] = deriv5(imu_velCal(:,3),ts);
                imu_accelCal=[dot1 dot2 dot3];         % global
            
                imu_localCal=zeros(length(imu_accelCal),3);
    
                for i=1:length(imu_accelCal)
                    imu_localCal(i,:) = Rinf(:,:,i)^(-1)*[imu_accelCal(i,1);imu_accelCal(i,2);imu_accelCal(i,3)];
                end
                ag_wristCal=zeros(length(imu_accelCal),3);
                for i=1:length(imu_accelCal)
                    ag_wristCal(i,:) = Rinf(:,:,i)*([imu_localCal(i,1);imu_localCal(i,2);imu_localCal(i,3)]-imu_bias);
                end
                imu_velCalL(:,1)=cumtrapz(ts,ag_wristCal(:,1));
                imu_velCalL(:,2)=cumtrapz(ts,ag_wristCal(:,2));
                imu_velCalL(:,3)=cumtrapz(ts,ag_wristCal(:,3));
                imu_velCalL=imu_velCalL-imu_velCalL(g.add,:);  % address zeroing
                imu_velCalL(1:g.add,:)=0;
                imu_velCalL(g.fin:end,:)=0;
                imu_trajCalL=cumtrapz(ts,imu_velCalL);
                imu_trajCalL=imu_trajCalL-imu_trajCalL(g.add,:);
               
            
                %% proposed method integration result
                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);
                
    
                % replace imp_est with the subject mean?
                imp_est_list = [imp_est_list; rel_est];
               
    
                % 0710 % pull it down like the velocity
                diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];
    
                % initialise the new trajectory
                traj_lin = imu_trajCal;                   % copy of the original
    
                % 1) ADD ~ IMP : correct by spreading linearly / weighting towards fin
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                    traj_lin(k,:) = imu_trajCal(k,:) - w * diff;  % 1×3 vector
                end
                
                traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin_fast, 1);



                apdm_biasV_list = [apdm_biasV_list; diff];
                %trial-by-trial correction
                apdm_trajCalV = traj_lin;
                
                %% ML-corrected integration result
                traj_lin_subj = imu_trajCal; 
                
                % if trial>25
                % if trial>5
    
                
                %% to obtain ori0 in iron & fast shot
    
    
                if club==3
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
                else
                    if trial>20
                    % if trial>25
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj); 
                        % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,subj); % 9 test with 9 training
                        % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,10); % 9 test with 8 training
                    else %dummy value
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(1,:,subj);
                    end
                end
                % diff_ml =  [1 1 1]; % dummy
                % 
                % 
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                    traj_lin_subj(k,:) = imu_trajCal(k,:) - w * diff_ml;  % 1×3 vector
                end
                
                traj_lin_subj(g.fin+1:end,:) = repmat(traj_lin_subj(g.fin,:), n_rows_fin_fast, 1);
                % 
                % % % % % 3D visualisation plot of the predicted data
                % figure(100+trial);
                % hold on;
                % % plot3(apdm_trajCalV(g.imp-20:g.imp+20,1), apdm_trajCalV(g.imp-20:g.imp+20,2), apdm_trajCalV(g.imp-20:g.imp+20,3),'r');
                % % plot3(imu_traj(g.imp-20:g.imp+20,1), imu_trajCalL(g.imp-20:g.imp+20,2), imu_trajCalL(g.imp-20:g.imp+20,3),'Color', [0.5 0.5 0.5]);
                % % plot3(imu_trajCalL(g.imp-20:g.imp+20,1), imu_traj(g.imp-20:g.imp+20,2), imu_traj(g.imp-20:g.imp+20,3),'Color', [1 0.8 0.8]); 
                % % plot3(Mtraj(g.imp-20:g.imp+20,1), Mtraj(g.imp-20:g.imp+20,2), Mtraj(g.imp-20:g.imp+20,3),'k');
                % 
                % g.fin = 800;
                % 
                % % plot3(apdm_trajCalV(1:g.fin,1), apdm_trajCalV(1:g.fin,2), apdm_trajCalV(1:g.fin,3),'r','LineWidth', 3);
                % plot3(imu_traj(1:g.fin,1), imu_traj(1:g.fin,2), imu_traj(1:g.fin,3),'b','LineWidth', 1.5); %,'LineStyle', '--'); %[0.3 0.3 0.3]
                % plot3(traj_lin_subj(1:g.fin,1), traj_lin_subj(1:g.fin,2), traj_lin_subj(1:g.fin,3),'Color',dark_green,'LineWidth', 3);
                % plot3(Mtraj(g.add:g.fin,1), Mtraj(g.add:g.fin,2), Mtraj(g.add:g.fin,3),'k','LineWidth', 3);
                % 
                % 
                % 
                % % mark a specific point (e.g. the 10th point) with a star
                % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 15);
                % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'bp', 'MarkerSize', 15);
                % plot3(traj_lin_subj(g.imp,1), traj_lin_subj(g.imp,2), traj_lin_subj(g.imp,3), 'gp', 'MarkerSize', 15);
                % 
                % % % distinguish the edge and the interior with different colours
                % % % the difference cannot possibly be this large
                % % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow'); % specify the edge color
                % % plot3(apdm_trajCalV(g.imp,1), apdm_trajCalV(g.imp,2), apdm_trajCalV(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
                % % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
                % 
                % % add axis labels
                % % xlabel('X-axis(mm)');
                % % ylabel('Y-axis(mm)');
                % % zlabel('Z-axis(mm)');
                % 
                % axis equal;
                % grid off;
                % % the viewing angle can be changed
                % % view(3);
                % % view(0, 0);
                % % view(0, 90);  % or view(2)
                % view(90, 0);
                % % % 
                % % % print(gcf, 'plot_traj_prop.svg', '-dsvg', '-vector');
    
    
                % % check integration results, per trial
                % for k = 1:3
                %     figure(trial*3+k)
                %     hold on;
                %     plot(Mtraj(:,k),'Color','k');
                %     plot(imu_traj(:,k),'Color','g');
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % plot(imu_trajCalL(:,k),'Color','b');
                %     % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                % 
                %     % plot(Lsho(:,k),'Color','r');
                %     % legend('ref','imu','imu vel','circle','imp','video');
                %     % legend('ref','imu','vel','video');
                %     xline([g.add g.bst g.imp g.fin],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
                %     xlim([g.add-200 g.fin+10])
                % end
    
                % consist_colors = turbo(20);
                % % %% check integration results, all trials at once
                % for k = 1:3
                %     figure(k)
                %     hold on;
                %     % plot(ag_wo_g(:,k)) % turns out looking at them together makes no sense..
                %     plot(imu_vel(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial)*2,:),'LineWidth', 1.5);
                %     % plot(imu_traj(:,k),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % % plot(imu_trajCalL(:,k),'Color','b');
                %     % % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     % plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                %     % %mean correction
                %     % plot(traj_lin_subj(:,k),'Color','b'); % proposed correction
                %     % % plot(Lsho(:,k),'Color','r');
                %     % % legend('ref','imu','imu vel','circle','imp','video');
                %     % % legend('ref','imu','vel','video');
                %     xline([g.add g.imp],'-',{'BST','IMP'},'HandleVisibility','off');
                %     xlim([690 710])
                %     % ylim([-1500 1500])
                % end
                % 
                % % convert to mm for visualisation
                % acc_data(:,:) = acc_data(:,:).*1000;
                % for k = 4:6
                %     figure(k)
                %     hold on;
                %     plot(ag_wo_g(:,k-3),'Color',consist_colors((trial-20)*2,:),'LineWidth', 1.5);
                %     % plot(acc_data(:,k-3),'Color',consist_colors((trial-20)*2,:));
                %     % plot(Mtraj(:,k),'Color',consist_colors((trial-20)*2,:));
                %     % plot(imu_traj(:,k),'Color',consist_colors((trial-20)*2,:));
                %     % plot(imu_trajCal(:,k),'Color','r');
                %     % % plot(imu_trajCalL(:,k),'Color','b');
                %     % % plot(imu_trajCalI(:,k),'Color','c'); %marker correction
                %     % plot(apdm_trajCalV(:,k),'Color','m'); % proposed correction
                %     % %mean correction
                %     % plot(traj_lin_subj(:,k),'Color','b'); % proposed correction
                %     % % plot(Lsho(:,k),'Color','r');
                %     % % legend('ref','imu','imu vel','circle','imp','video');
                %     % % legend('ref','imu','vel','video');
                %     xline([g.add g.imp],'-',{'BST','IMP'},'HandleVisibility','off');
                %     % xlim([350 800])
                %     xlim([690 710])
                %     % ylim([-1500 1500])
                % end
    
    
               
            
                % calculate angle error , quaternion
                angle_error=[];
                axis_error=[];
                for i=1:length(time) %s.address:s.finish
                    qprod = quaternProd(quaternConj(qinf(i,:)),R2Lwq(i,:)); %proposed vs reference
                    tempAng = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);
                    tempAxs = [qprod(2)/sqrt(1-qprod(1)^2), qprod(3)/sqrt(1-qprod(1)^2), qprod(4)/sqrt(1-qprod(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error=[angle_error, tempAng]; %per-trial error value, means the rotation angle between the two quaternions
                    axis_error=[axis_error; tempAxs]; % “axis (direction) about which the rotation occurs” information, does not seem to be an error
                end
                
                angle_error_ref=[];
                axis_error_ref=[];
                
                for i=1:length(time) %s.address:s.finish
                    qprod_ref = quaternProd(quaternConj(qinf_ref(i,:)),R2Lwq(i,:)); %proposed vs reference
                    tempAng = abs(2 * atan2(norm(qprod_ref(2:4)),qprod_ref(1))*180/pi);
                    tempAxs = [qprod_ref(2)/sqrt(1-qprod_ref(1)^2), qprod_ref(3)/sqrt(1-qprod_ref(1)^2), qprod_ref(4)/sqrt(1-qprod_ref(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error_ref=[angle_error_ref, tempAng]; %per-trial error value, means the rotation angle between the two quaternions
                    axis_error_ref=[axis_error_ref; tempAxs]; % “axis (direction) about which the rotation occurs” information, does not seem to be an error
                end
    
                
                % rmse_Rot = sqrt(mean(angle_error(s.address:s.finish).^2));
                % mae_Rot = mean(angle_error(s.address:s.finish));
                angle_error_plot = [angle_error_plot angle_error'];
                angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];
    
                angle_error_q = angle_error(g.add:g.fin);
                angle_error_imp = angle_error(g.add:g.imp);
                angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];
                % angle_error_q_list = [angle_error_q_list mean(abs(angle_error_q))];
                % angle_error_add2imp = [angle_error_add2imp mean(abs(angle_error_imp))];
    
                angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
                angle_error_add2imp = [angle_error_add2imp mean(angle_error_imp)];
    
    
                % quaternion angle error visualisation
                % figure(subj+100)
                % plot(angle_error_q);
                % hold on;
    
                % % 3-axis angle error
                angle_error_axis = []; % check whether globally aligned
                angle_error_axis_ref = [];
                % the 3-axis one did not start from address...
                %% locally align check, ' added
                for i = 1:length(time)
                    % R1 = R2Lw(:,:,i)';
                    % R2 = Rinf(:,:,i)';  % example of the second rotation matrix
                    
                    % globally align
                    R1 = R2Lw(:,:,i);
                    R2 = Rinf(:,:,i);  % example of the second rotation matrix
                    % 
                    % difference between the two rotation matrices (relative rotation matrix)
                    % R_diff = R1 * R2';
                    R_diff = R2 * R1'; %how much the reference value must be rotated to become the estimate % the angle error in the world frame can be interpreted directly
            
                    % convert R_diff to Euler angles (XYZ order)
                    eul_angles = rotm2eul(R_diff, 'ZYX');
            
                    % angle error about each axis (converting radians to degrees)
                    roll_error_deg = rad2deg(eul_angles(1));   % x-axis (roll) error
                    pitch_error_deg = rad2deg(eul_angles(2));  % y-axis (pitch) error
                    yaw_error_deg = rad2deg(eul_angles(3));    % z-axis (yaw) error
    
    
    
                    %% additional code for reference
                    R1 = R2Lw(:,:,i);
                    R2 = Rinf_ref(:,:,i);  % example of the second rotation matrix
                    % 
                    % difference between the two rotation matrices (relative rotation matrix)
                    R_diff = R2 * R1'; %how much the reference value must be rotated to become the estimate % the angle error in the world frame can be interpreted directly
    
                    % convert R_diff to Euler angles (XYZ order)
                    eul_angles = rotm2eul(R_diff, 'ZYX');
    
                    % angle error about each axis (converting radians to degrees)
                    roll_error_deg_ref = rad2deg(eul_angles(1));   % x-axis (roll) error
                    pitch_error_deg_ref = rad2deg(eul_angles(2));  % y-axis (pitch) error
                    yaw_error_deg_ref = rad2deg(eul_angles(3));    % z-axis (yaw) error
    
            
                    % store the error angle about each axis in an array
                    % for the numbers
                    % angle_error_axis = [angle_error_axis; abs(roll_error_deg), abs(pitch_error_deg), abs(yaw_error_deg)];
                    % for plotting the graph
                    angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];
    
                    angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];
    
                end
           
                angle_error_axis_list(:,:,z) = angle_error_axis;
                angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;
    
                
                plot_ds_ref_fast(:,:,z) = Mtraj;
                plot_ds_prop(:,:,z) = apdm_trajCalV;
                plot_ds_fast(:,:,z) = traj_lin_subj;
                % plot_ds_imu(:,:,z) = imu_trajCal;
    
                plot_ds_imu(:,:,z) = imu_traj;
                plot_imu_vel(:,:,z) = imu_vel ;
                plot_imu_acc(:,:,z) = ag_wo_g;
    
                plot_imu_acc_local(:,:,z) = acc_data;
                
               
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial, subj};
                plot_ds_ml_fast(:,:,z) = ml_traj_check;

    
                % mae error
                switch mae_method
                    case 0
                        test_drift = imu_traj;
                    case 1
                        test_drift = imu_trajCal; %wait, is this one more accurate in 3D than apdm_trajCalV?
                    case 2
                        test_drift = imu_trajCalL;
                    case 3
                        test_drift = imu_trajCalI; %the code probably needs changing to pin it down with the actual marker
                    case 4
                        test_drift = apdm_trajCalV; % traj_lin_subj, imu only  % apdm_trajCalV trial by trial correction
                    case 5
                        test_drift = traj_lin_subj;
                    case 6
                        test_drift = ml_traj_check;
                end
            
                switch mae_method_vel
                    case 0
                        test_drift_vel = imu_vel;
                    case 1
                        test_drift_vel = imu_velCal;
                    case 2
                        test_drift_vel = imu_velCalL;
                    case 3
                        test_drift_vel = imu_velCalI;
                    case 4
                        test_drift_vel = apdm_velCalV;
                end



                start_traj = g.add;
                % end_traj = g.fin;
                end_traj = 800;
                % end_traj = g.imp;
                error = Mtraj(start_traj:end_traj,:)-test_drift(start_traj:end_traj,:);

                % summarise the errors
                Mae_XYZ = mean(abs(error));
                % the mean (scalar) of the per-frame Euclidean error, widely used as the representative value
                Mae_norm = mean(vecnorm(error,2,2));
                rmse_xyz = sqrt(mean(error.^2, 1));
                rmse_overall = sqrt(mean(sum(error.^2, 2)));

                % compute mae
                mae_list = [mae_list; Mae_XYZ];
                mae_norm_list = [mae_norm_list; Mae_norm];
                rmse_xyz_list = [rmse_xyz_list; rmse_xyz];
                rmse_norm_list = [rmse_norm_list; rmse_overall];


                %% how should the velocity comparison be done?
                error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
                error_vellist = [error_vellist; mean(abs(error_vel))];
                
                % store the event times (for the figure)
                event_add_fast(z) = g.add;
                event_bst_fast(z) = g.bst;
                event_imp_fast(z) = g.imp;
                event_fin_fast(z) = g.fin;
                    
                z=z+1;
            end
        end
        % disp(subj)
    end
    


    % error over the whole swing
    % mean/standard deviation
    summary_fast.mae_xyz_mean = mean(mae_list, 1);
    summary_fast.mae_xyz_std  = std (mae_list, 0, 1);
    summary_fast.rmse_xyz_mean= mean(rmse_xyz_list, 1);
    summary_fast.rmse_xyz_std = std (rmse_xyz_list, 0, 1);
    
    summary_fast.mae_norm_mean  = mean(mae_norm_list);
    summary_fast.mae_norm_std   = std (mae_norm_list);
    summary_fast.rmse_norm_mean = mean(rmse_norm_list);
    summary_fast.rmse_norm_std  = std (rmse_norm_list);
    
    T = table( ...
      summary_fast.mae_xyz_mean', summary_fast.mae_xyz_std', ...
      summary_fast.rmse_xyz_mean', summary_fast.rmse_xyz_std', ...
      'VariableNames', {'MAE_mean','MAE_std','RMSE_mean','RMSE_std'}, ...
      'RowNames', {'X','Y','Z'});
    disp(T)
    
    fprintf('MAE(norm) = %.2f ± %.2f mm\n', ...
        summary_fast.mae_norm_mean, summary_fast.mae_norm_std);
    fprintf('RMSE(norm)= %.2f ± %.2f mm\n', ...
        summary_fast.rmse_norm_mean, summary_fast.rmse_norm_std);



    plot_ds_fast = plot_ds_fast.*0.1;
    plot_ds_ref_fast = plot_ds_ref_fast.*0.1;
    plot_ds_ml_fast = plot_ds_ml_fast.*0.1;
    
    ref_mean_x_fast = mean(plot_ds_ref_fast(:, 1, :), 3); % x-axis mean
    % ref_std_x = std(plot_ds_ref(:, 1, :), 0, 3); % x-axis standard deviation
    
    ref_mean_y_fast = mean(plot_ds_ref_fast(:, 2, :), 3); % y-axis mean
    % ref_std_y = std(plot_ds_ref(:, 2, :), 0, 3); % y-axis standard deviation
    
    ref_mean_z_fast = mean(plot_ds_ref_fast(:, 3, :), 3); % z-axis mean
    % ref_std_z = std(plot_ds_ref(:, 3, :), 0, 3); % z-axis standard deviation
    
    
    
    % ===== Subplot spacing settings =====
    left_margin = 0.13;
    top_margin = 0.05;
    bottom_margin = 0.08;
    plot_width = 0.82;
    gap = 0.05;  % <-- adjust only this value
    plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;
    % =============================
    
    figure(subj_fast);
    clf;
    set(gcf, 'Position', [100, 349, 600, 551]);
    
    % determine the number of trials
    if subj_fast == 5 || subj_fast == 9
        n_trials_plot = 9;
    else
        n_trials_plot = 10;
    end
    
    % compute the event means
    event_add_mean = mean(event_add_fast(1:n_trials_plot))
    event_bst_mean = mean(event_bst_fast(1:n_trials_plot))
    event_imp_mean = mean(event_imp_fast(1:n_trials_plot))
    event_fin_mean = mean(event_fin_fast(1:n_trials_plot))
    event_add_std = std(event_add_fast(1:n_trials_plot));
    event_bst_std = std(event_bst_fast(1:n_trials_plot));
    event_imp_std = std(event_imp_fast(1:n_trials_plot));
    event_fin_std = std(event_fin_fast(1:n_trials_plot));
    
    % Subplot 1: X-axis
    subplot(3, 1, 1);
    k = 1;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;
    
    % compute the y range
    y_data = plot_ds_fast(plot_x_start:plot_x_end, 1, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event lines (shade removed, lines only)
    xline(event_add_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    % 2-sigma shade
    fill([1:length(driver_mean_x), fliplr(1:length(driver_mean_x))], ...
        [driver_mean_x + driver_std_x*2; flipud(driver_mean_x - driver_std_x*2)], ...
        dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(driver_mean_x, '--','Color', dark_red, 'LineWidth', 1.5);
    
    % plot all trials
    for i = 1:n_trials_plot
        plot(plot_ds_fast(:,1,i),'Color', dark_red,'LineWidth', 0.7);
    end
    
    xlim([plot_x_start plot_x_end])
    set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
    set(gca, 'XTick', [])
    set(gca, 'XTickLabel', []);
    hold off;
    ylim([-60 50]);
    
    % Subplot 2: Y-axis
    subplot(3, 1, 2);
    k = 2;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;
    
    % compute the y range
    y_data = plot_ds_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event lines (shade removed, lines only)
    xline(event_add_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill([1:length(driver_mean_y), fliplr(1:length(driver_mean_y))], ...
        [driver_mean_y + driver_std_y*2; flipud(driver_mean_y - driver_std_y*2)], ...
        dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(driver_mean_y,'--','Color', dark_red, 'LineWidth', 1.5);
    
    for i = 1:n_trials_plot
        plot(plot_ds_fast(:,2,i),'Color', dark_red,'LineWidth', 0.7);
    end
    ylim([-60,50]);
    xlim([plot_x_start plot_x_end])
    set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
    set(gca, 'XTick', [])
    set(gca, 'XTickLabel', []);
    hold off;
    
    % Subplot 3: Z-axis
    subplot(3, 1, 3);
    k = 3;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;
    
    % compute the y range
    y_data = plot_ds_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event lines (shade removed, lines only)
    xline(event_add_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    fill([1:length(driver_mean_z), fliplr(1:length(driver_mean_z))], ...
        [driver_mean_z + driver_std_z*2; flipud(driver_mean_z - driver_std_z*2)], ...
        dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(driver_mean_z, '--','Color', dark_red, 'LineWidth', 1.5);
    
    for i = 1:n_trials_plot
        plot(plot_ds_fast(:,3,i),'Color', dark_red,'LineWidth', 0.7);
    end
    ylim([-10,100]);
    xlim([plot_x_start plot_x_end])
    set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
    set(gca, 'XTick', [])
    set(gca, 'XTickLabel', []);
    hold off;
    if subj_fast ==3
        print(gcf, sprintf('fig5.svg'), '-dsvg', '-vector');
    end

   % 
   % 
    % figure(subj_fast+1000) - ML-based trajectory (revised: x-axis 320~850, ML data 351~800)
    figure(subj_fast+1000); set(gcf, 'Position', [100, 349, 600, 551]);
    clf;
    
    % x-axis range of the ML data (mapped to 351~800)
    ml_x_range = ml_start_ref:(ml_start_ref + size(plot_ds_ml_fast, 1) - 1);

    subplot(3, 1, 1);
    hold on;
    
    % compute the y range (for the event shade - based on the ML data)
    y_data = plot_ds_ml_fast(:, 1, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    % event lines
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    % ML 2-sigma shade (mapped to x-axis 351~800)
    fill([ml_x_range, fliplr(ml_x_range)], ...
        [ml_mean_x + ml_std_x*2; flipud(ml_mean_x - ml_std_x*2)], ...
        dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ml_x_range, ml_mean_x, '--','Color', dark_green, 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(ml_x_range, plot_ds_ml_fast(:,1,i),'Color', dark_green,'LineWidth', 0.7);
    end

    ylabel('X-axis (cm)');
    xlim([plot_x_start plot_x_end])
    grid on;
    hold off;

    subplot(3, 1, 2);
    hold on;
    
    % compute the y range
    y_data = plot_ds_ml_fast(:, 2, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    
    fill([ml_x_range, fliplr(ml_x_range)], ...
        [ml_mean_y + ml_std_y*2; flipud(ml_mean_y - ml_std_y*2)], ...
        dark_green ,'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ml_x_range, ml_mean_y, '--','Color', dark_green, 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(ml_x_range, plot_ds_ml_fast(:,2,i),'Color', dark_green,'LineWidth', 0.7);
    end

    xlim([plot_x_start plot_x_end])
    ylabel('Y-axis (cm)');
    grid on;
    hold off;

    subplot(3, 1, 3);
    hold on;
    
    % compute the y range
    y_data = plot_ds_ml_fast(:, 3, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    fill([ml_x_range, fliplr(ml_x_range)], ...
        [ml_mean_z + ml_std_z*2; flipud(ml_mean_z - ml_std_z*2)], ...
        dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ml_x_range, ml_mean_z,'--', 'Color', dark_green, 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(ml_x_range, plot_ds_ml_fast(:,3,i),'Color', dark_green,'LineWidth', 0.7);
    end
    
    xlim([plot_x_start plot_x_end])
    ylabel('Z-axis (cm)');
    grid on;
    hold off;



    % figure(subj_fast+100) - Reference-based trajectory (revised)
    figure(subj_fast+100); set(gcf, 'Position', [100, 349, 600, 551]);
    clf;

    subplot(3, 1, 1);
    hold on;
    
    % compute the y range (for the event shade)
    y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 1, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    fill([1:length(ref_mean_x), fliplr(1:length(ref_mean_x))], ...
        [ref_mean_x + ref_std_x*2; flipud(ref_mean_x - ref_std_x*2)], ...
        'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ref_mean_x,'--k',  'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(plot_ds_ref_fast(:,1,i),'k','LineWidth', 0.7);
    end

    ylabel('X-axis (cm)');
    xlim([plot_x_start plot_x_end])
    grid on;
    hold off;

    subplot(3, 1, 2);
    hold on;
    
    % compute the y range
    y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    
    fill([1:length(ref_mean_y), fliplr(1:length(ref_mean_y))], ...
        [ref_mean_y + ref_std_y*2; flipud(ref_mean_y - ref_std_y*2)], ...
        'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ref_mean_y, '--k', 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(plot_ds_ref_fast(:,2,i),'k','LineWidth', 0.7);
    end

    xlim([plot_x_start plot_x_end])
    ylabel('Y-axis (cm)');
    grid on;
    hold off;

    subplot(3, 1, 3);
    hold on;
    
    % compute the y range
    y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;
    
    % event shade (add, bst, imp, fin)
    fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
          event_add_mean + event_add_std, event_add_mean - event_add_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
          event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
          event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
          event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
         [y_min, y_min, y_max, y_max], ...
         event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    fill([1:length(ref_mean_z), fliplr(1:length(ref_mean_z))], ...
        [ref_mean_z + ref_std_z*2; flipud(ref_mean_z - ref_std_z*2)], ...
        'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ref_mean_z,'--k', 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(plot_ds_ref_fast(:,3,i),'k','LineWidth', 0.7);
    end

    xlim([plot_x_start plot_x_end])
    ylabel('Z-axis (cm)');
    grid on;
    hold off;


    %% ===== Figure 2025: Y axis =====
    if subj_fast == subj_select
        figure(2025); set(gcf, 'Position', [100, 349, 600, 551]);
        clf;
        
        % ===== Subplot spacing settings =====
        left_margin = 0.13;
        top_margin = 0.05;
        bottom_margin = 0.08;
        plot_width = 0.82;
        gap = 0.05;  % <-- adjust only this value
        plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;
        % =============================

        % Subplot 1: Reference (black)
        subplot(3, 1, 1);

        bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
        set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    

        hold on;
        
        y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        % event shade
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([1:length(ref_mean_y), fliplr(1:length(ref_mean_y))], ...
            [ref_mean_y + ref_std_y*2; flipud(ref_mean_y - ref_std_y*2)], ...
            'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ref_mean_y, '--', 'Color', [0 0 0], 'LineWidth', 1.5);
        plot(plot_ds_ref_fast(:, 2, trial_select), 'Color', [0 0 0], 'LineWidth', 2);
        
        ylabel('Y-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
        
        % Subplot 2: ML (dark green)
        subplot(3, 1, 2);
        hold on;
        
        y_data = plot_ds_ml_fast(:, 2, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([ml_x_range, fliplr(ml_x_range)], ...
            [ml_mean_y + ml_std_y*2; flipud(ml_mean_y - ml_std_y*2)], ...
            dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ml_x_range, ml_mean_y, '--', 'Color', dark_green, 'LineWidth', 1.5);
        plot(ml_x_range, plot_ds_ml_fast(:, 2, trial_select), 'Color', dark_green, 'LineWidth', 2);
        
        ylabel('Y-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
        
        % Subplot 3: IMU/Proposed (dark red)
        subplot(3, 1, 3);
        hold on;
        
        y_data = plot_ds_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([1:length(driver_mean_y), fliplr(1:length(driver_mean_y))], ...
            [driver_mean_y + driver_std_y*2; flipud(driver_mean_y - driver_std_y*2)], ...
            dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(driver_mean_y, '--', 'Color', dark_red, 'LineWidth', 1.5);
        plot(plot_ds_fast(:, 2, trial_select), 'Color', dark_red, 'LineWidth', 2);
        
        ylabel('Y-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
    end

    %% ===== Figure 2026: X axis =====
    if subj_fast == subj_select
        figure(2026); set(gcf, 'Position', [150, 349, 600, 551]);
        clf;
        
        % Subplot 1: Reference (black)
        subplot(3, 1, 1);
        hold on;
        
        y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 1, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([1:length(ref_mean_x), fliplr(1:length(ref_mean_x))], ...
            [ref_mean_x + ref_std_x*2; flipud(ref_mean_x - ref_std_x*2)], ...
            'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ref_mean_x, '--', 'Color', [0 0 0], 'LineWidth', 1.5);
        plot(plot_ds_ref_fast(:, 1, trial_select), 'Color', [0 0 0], 'LineWidth', 2);
        
        ylabel('X-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
        
        % Subplot 2: ML (dark green)
        subplot(3, 1, 2);
        hold on;
        
        y_data = plot_ds_ml_fast(:, 1, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([ml_x_range, fliplr(ml_x_range)], ...
            [ml_mean_x + ml_std_x*2; flipud(ml_mean_x - ml_std_x*2)], ...
            dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ml_x_range, ml_mean_x, '--', 'Color', dark_green, 'LineWidth', 1.5);
        plot(ml_x_range, plot_ds_ml_fast(:, 1, trial_select), 'Color', dark_green, 'LineWidth', 2);
        
        ylabel('X-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
        
        % Subplot 3: IMU/Proposed (dark red)
        subplot(3, 1, 3);
        hold on;
        
        y_data = plot_ds_fast(plot_x_start:plot_x_end, 1, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([event_add_mean - event_add_std, event_add_mean + event_add_std, ...
              event_add_mean + event_add_std, event_add_mean - event_add_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_bst_mean - event_bst_std, event_bst_mean + event_bst_std, ...
              event_bst_mean + event_bst_std, event_bst_mean - event_bst_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_imp_mean - event_imp_std, event_imp_mean + event_imp_std, ...
              event_imp_mean + event_imp_std, event_imp_mean - event_imp_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        fill([event_fin_mean - event_fin_std, event_fin_mean + event_fin_std, ...
              event_fin_mean + event_fin_std, event_fin_mean - event_fin_std], ...
             [y_min, y_min, y_max, y_max], ...
             event_shade_color, 'FaceAlpha', event_shade_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        xline(event_add_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_mean, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        fill([1:length(driver_mean_x), fliplr(1:length(driver_mean_x))], ...
            [driver_mean_x + driver_std_x*2; flipud(driver_mean_x - driver_std_x*2)], ...
            dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(driver_mean_x, '--', 'Color', dark_red, 'LineWidth', 1.5);
        plot(plot_ds_fast(:, 1, trial_select), 'Color', dark_red, 'LineWidth', 2);
        
        ylabel('X-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;
    end


    % ===== Subplot spacing settings =====
    left_margin = 0.13;
    top_margin = 0.05;
    bottom_margin = 0.08;
    plot_width = 0.82;
    gap = 0.05;  % <-- adjust only this value
    plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;
    % =============================
    
    %% ===== Figure 2027: Z axis =====
    if subj_fast == subj_select
        figure(2027); 
        clf;
        set(gcf, 'Position', [200, 349, 600, 551]);
        
        % Subplot 1: Reference (black)
        subplot(3, 1, 1);
        k = 1;  % subplot number
        bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
        set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
        hold on;
        
        y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([1:length(ref_mean_z), fliplr(1:length(ref_mean_z))], ...
            [ref_mean_z + ref_std_z*2; flipud(ref_mean_z - ref_std_z*2)], ...
            'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ref_mean_z, '--', 'Color', [0 0 0], 'LineWidth', 1.5);
        plot(plot_ds_ref_fast(:, 3, trial_select), 'Color', [0 0 0], 'LineWidth', 2);
        
        xlim([plot_x_start plot_x_end]);
        ylim([-10 100]);
        set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
        set(gca, 'XTick', [])
        set(gca, 'XTickLabel', []);
        hold off;

        xline(event_add_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        
        % Subplot 2: ML (dark green)
        subplot(3, 1, 2);
        k = 2;  % subplot number
        bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
        set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
        hold on;
        
        y_data = plot_ds_ml_fast(:, 3, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([ml_x_range, fliplr(ml_x_range)], ...
            [ml_mean_z + ml_std_z*2; flipud(ml_mean_z - ml_std_z*2)], ...
            dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ml_x_range, ml_mean_z, '--', 'Color', dark_green, 'LineWidth', 1.5);
        plot(ml_x_range, plot_ds_ml_fast(:, 3, trial_select), 'Color', dark_green, 'LineWidth', 2);
        
        xline(event_add_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        

        xlim([plot_x_start plot_x_end]);
        ylim([-10 100]);
        set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
        set(gca, 'XTick', [])
        set(gca, 'XTickLabel', []);
        hold off;
        
        % Subplot 3: IMU/Proposed (dark red)
        subplot(3, 1, 3);
        k = 3;  % subplot number
        bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
        set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
        hold on;
        
        y_data = plot_ds_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
        y_min = min(y_data(:)) - 5;
        y_max = max(y_data(:)) + 5;
        
        fill([1:length(driver_mean_z), fliplr(1:length(driver_mean_z))], ...
            [driver_mean_z + driver_std_z*2; flipud(driver_mean_z - driver_std_z*2)], ...
            dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(driver_mean_z, '--', 'Color', dark_red, 'LineWidth', 1.5);
        plot(plot_ds_fast(:, 3, trial_select), 'Color', dark_red, 'LineWidth', 2);
        
        xline(event_add_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_bst_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_imp_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        xline(event_fin_fast(trial_select), '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
        
        xlim([plot_x_start plot_x_end]);
        set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
        set(gca, 'XTick', [])
        set(gca, 'XTickLabel', []);
        hold off;
        ylim([-10 100]);
        print(gcf, sprintf('fig4.svg'), '-dsvg', '-vector');
    end
    
    

    
    % turn into a function and compute %just show it all at once after the computation
    % imp-> 700, bst->630
    mean_traj = [driver_mean_x driver_mean_y driver_mean_z];
    std_traj = [driver_std_x driver_std_y driver_std_z];
    % start_idx = 560;
    % start_idx = 630;
    % end_idx   = 700;
    % nsigma    = 2;
    
    out = compute_shade_coverage(plot_ds_fast, mean_traj, std_traj, ...
                                 start_idx, end_idx, nsigma);
    
    % print the per-axis ratio
    % fprintf('Axis X: %.2f%% in range\n', out.axis_ratio(1)*100);
    % fprintf('Axis Y: %.2f%% in range\n', out.axis_ratio(2)*100);
    % fprintf('Axis Z: %.2f%% in range\n', out.axis_ratio(3)*100);
    
    fprintf('Axis X: %.2f%% out of range\n', 100-out.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out.axis_ratio(3)*100);
    fprintf('3-axis mean %.2f%% out of range\n', 100*(1-mean(out.axis_ratio(:))));
    

    % agreement
    ratio_imu = 100*(mean(out.trial_ratio(:,:),2));
    ratio_imu_axis = 100*(out.trial_ratio(:,:));

    % % degree of deviation
    % ratio_imu = 100*(1-mean(out.trial_ratio(:,:),2));
    % ratio_imu_axis = 100*(1-out.trial_ratio(:,:));
    % 
    if subj==5 || subj==9
        ratio_imu_list = [ratio_imu_list ratio_imu(1:9)' ];
        ratio_imu_x_list = [ratio_imu_x_list ratio_imu_axis(1:9,1)'];
        ratio_imu_y_list = [ratio_imu_y_list ratio_imu_axis(1:9,2)'];
        ratio_imu_z_list = [ratio_imu_z_list ratio_imu_axis(1:9,3)'];
    else
        ratio_imu_list = [ratio_imu_list ratio_imu'];
        ratio_imu_x_list = [ratio_imu_x_list ratio_imu_axis(:,1)'];
        ratio_imu_y_list = [ratio_imu_y_list ratio_imu_axis(:,2)'];
        ratio_imu_z_list = [ratio_imu_z_list ratio_imu_axis(:,3)'];
    end
    
    


    disp(' ');
    
    % check the proportion falling outside in the motion capture data
    mean_traj_fast = [ref_mean_x ref_mean_y ref_mean_z];
    std_traj_fast = [ref_std_x ref_std_y ref_std_z];
    % start_idx = 560;
    % start_idx = 630;
    % end_idx   = 700;
    % nsigma    = 2;
    
    out_fast = compute_shade_coverage(plot_ds_ref_fast, mean_traj_fast, std_traj_fast, ...
                                 start_idx, end_idx, nsigma);
    
    % print the per-axis ratio
    % fprintf('Axis X: %.2f%% in range\n', out.axis_ratio(1)*100);
    % fprintf('Axis Y: %.2f%% in range\n', out.axis_ratio(2)*100);
    % fprintf('Axis Z: %.2f%% in range\n', out.axis_ratio(3)*100);
    
    fprintf('Axis X: %.2f%% out of range\n', 100-out_fast.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out_fast.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out_fast.axis_ratio(3)*100);
    fprintf('3-axis mean %.2f%% out of range\n', 100*(1-mean(out_fast.axis_ratio(:))));
    
    % ratio_mocap = 100*(1-mean(out_fast.axis_ratio(:)));
    % ratio_mocap_list = [ratio_mocap ratio_mocap_list];
    
    % agreement
    ratio_mocap = 100*(mean(out_fast.trial_ratio(:,:),2));
    ratio_mocap_axis = 100*(out_fast.trial_ratio(:,:));

    % % degree of deviation
    % ratio_mocap = 100*(1-mean(out_fast.trial_ratio(:,:),2));
    % ratio_mocap_axis = 100*(1-out_fast.trial_ratio(:,:));

    % if subj==5 || subj==9
    %     ratio_mocap_list = [ratio_mocap(1:9)' ratio_mocap_list];
    % else
    %     ratio_mocap_list = [ratio_mocap' ratio_mocap_list];
    % end
    
    if subj==5 || subj==9
        ratio_mocap_list = [ratio_mocap_list ratio_mocap(1:9)'];
        ratio_mocap_x_list  = [ratio_mocap_x_list ratio_mocap_axis(1:9,1)' ];
        ratio_mocap_y_list  = [ratio_mocap_y_list ratio_mocap_axis(1:9,2)' ];
        ratio_mocap_z_list  = [ratio_mocap_z_list ratio_mocap_axis(1:9,3)' ];
    else
        ratio_mocap_list = [ratio_mocap_list ratio_mocap'];
        ratio_mocap_x_list  = [ratio_mocap_x_list ratio_mocap_axis(:,1)'];
        ratio_mocap_y_list  = [ratio_mocap_y_list ratio_mocap_axis(:,2)'];
        ratio_mocap_z_list  = [ratio_mocap_z_list ratio_mocap_axis(:,3)'];
    end



    disp(' ');
    
    % check the proportion falling outside in the motion capture data
    mean_traj_ml = [ml_mean_x ml_mean_y ml_mean_z];
    std_traj_ml = [ml_std_x ml_std_y ml_std_z];

    
    out_ml = compute_shade_coverage(plot_ds_ml_fast, mean_traj_ml, std_traj_ml, ...
                                 start_idx, end_idx, nsigma);
    
    % print the per-axis ratio
    % fprintf('Axis X: %.2f%% in range\n', out.axis_ratio(1)*100);
    % fprintf('Axis Y: %.2f%% in range\n', out.axis_ratio(2)*100);
    % fprintf('Axis Z: %.2f%% in range\n', out.axis_ratio(3)*100);
    
    fprintf('Axis X: %.2f%% out of range\n', 100-out_ml.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out_ml.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out_ml.axis_ratio(3)*100);
    fprintf('3-axis mean %.2f%% out of range\n', 100*(1-mean(out_ml.axis_ratio(:))));
    
    % ratio_mocap = 100*(1-mean(out_fast.axis_ratio(:)));
    % ratio_mocap_list = [ratio_mocap ratio_mocap_list];
    
    % agreement
    ratio_ml = 100*(mean(out_ml.trial_ratio(:,:),2));
    ratio_ml_axis = 100*(out_ml.trial_ratio(:,:));

    % % degree of deviation
    % ratio_mocap = 100*(1-mean(out_fast.trial_ratio(:,:),2));
    % ratio_mocap_axis = 100*(1-out_fast.trial_ratio(:,:));

    % if subj==5 || subj==9
    %     ratio_mocap_list = [ratio_mocap(1:9)' ratio_mocap_list];
    % else
    %     ratio_mocap_list = [ratio_mocap' ratio_mocap_list];
    % end
    
    if subj==5 || subj==9
        ratio_ml_list = [ratio_ml_list ratio_ml(1:9)'];
        ratio_ml_x_list  = [ratio_ml_x_list ratio_ml_axis(1:9,1)' ];
        ratio_ml_y_list  = [ratio_ml_y_list ratio_ml_axis(1:9,2)' ];
        ratio_ml_z_list  = [ratio_ml_z_list ratio_ml_axis(1:9,3)' ];
    else
        ratio_ml_list = [ratio_ml_list ratio_ml'];
        ratio_ml_x_list  = [ratio_ml_x_list ratio_ml_axis(:,1)'];
        ratio_ml_y_list  = [ratio_ml_y_list ratio_ml_axis(:,2)'];
        ratio_ml_z_list  = [ratio_ml_z_list ratio_ml_axis(:,3)'];
    end


end






x = ratio_mocap_list;
y = ratio_imu_list;
figure(10000); % create a new figure window
scatter(x, y,60, 'filled', 'MarkerFaceColor', dark_red); 
% scatter(x,y,'filled'); % scatter plot with filled circular markers

hold on; % overlay subsequently drawn elements on the current plot

% 3. compute and draw the linear regression (least-squares line)
% method A: use the lsline function (the simplest way)
% the code below is itself the line-drawing function
% lsline; % add a least-squares linear regression line to the current axes

% method B: use the polyfit and polyval functions (regression coefficients can be obtained)
% compute the first-order polynomial (linear) coefficients with polyfit (p(1) is the slope, p(2) the y-intercept)
p = polyfit(x, y, 1);
yfit = polyval(p, x); % generate the regression line y values from the computed coefficients

% --- add the y = x line here ---
% determine the x-axis range (using the min/max of the data)
x_range = linspace(min(x), max(x), 100);
y_identity = x_range; % y = x, so the y values are the same

mid_gray = [0.5, 0.5, 0.5]; 
plot(x_range, y_identity, ...
    'Color', mid_gray, ...       % pass the grey RGB value to the 'Color' property
    'LineStyle', '--', ...       % set a dashed line for the 'LineStyle' property
    'LineWidth', 1.5);

plot(x, yfit, 'k', 'LineWidth', 3); % plot the regression line as a solid red line

% 4. graph settings (title, axis labels, legend, etc.)
xlabel('GT Consistency (%)');
ylabel('Proposed Consistency (%)');
% grid on; % show the grid
axis equal;
xlim([0 100]);
ylim([0 100]);
hold off; % make the next plot be drawn in a new figure window


% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('IMU Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);




x = ratio_mocap_list;
y = ratio_ml_list;
figure(20000); % create a new figure window
scatter(x, y,60, 'filled', 'MarkerFaceColor', dark_green); 
% scatter(x,y,'filled'); % scatter plot with filled circular markers

hold on; % overlay subsequently drawn elements on the current plot

% 3. compute and draw the linear regression (least-squares line)
% method A: use the lsline function (the simplest way)
% the code below is itself the line-drawing function
% lsline; % add a least-squares linear regression line to the current axes

% method B: use the polyfit and polyval functions (regression coefficients can be obtained)
% compute the first-order polynomial (linear) coefficients with polyfit (p(1) is the slope, p(2) the y-intercept)
p = polyfit(x, y, 1);
yfit = polyval(p, x); % generate the regression line y values from the computed coefficients

% --- add the y = x line here ---
% determine the x-axis range (using the min/max of the data)
x_range = linspace(min(x), max(x), 100);
y_identity = x_range; % y = x, so the y values are the same

mid_gray = [0.5, 0.5, 0.5]; 
plot(x_range, y_identity, ...
    'Color', mid_gray, ...       % pass the grey RGB value to the 'Color' property
    'LineStyle', '--', ...       % set a dashed line for the 'LineStyle' property
    'LineWidth', 1.5);

plot(x, yfit, 'k', 'LineWidth', 3); % plot the regression line as a solid red line

% 4. graph settings (title, axis labels, legend, etc.)
xlabel('GT Consistency (%)');
ylabel('End to End Consistency (%)');
% grid on; % show the grid
axis equal;
xlim([0 100]);
ylim([0 100]);
hold off; % make the next plot be drawn in a new figure window


% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('ML Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);


%% ===== Figure 11000, 12000, 13000: per-axis linearity scatter plots (IMU) =====
axis_names = {'X', 'Y', 'Z'};
fig_numbers = [11000, 12000, 13000];

% per-axis data
ratio_mocap_xyz = {ratio_mocap_x_list, ratio_mocap_y_list, ratio_mocap_z_list};
ratio_imu_xyz = {ratio_imu_x_list, ratio_imu_y_list, ratio_imu_z_list};

mid_gray = [0.5, 0.5, 0.5];

for ax = 1:3
    x = ratio_mocap_xyz{ax};
    y = ratio_imu_xyz{ax};
    
    figure(fig_numbers(ax));
    clf;
    scatter(x, y, 60, 'filled', 'MarkerFaceColor', dark_red);
    
    hold on;
    
    % linear regression
    p = polyfit(x, y, 1);
    yfit = polyval(p, x);
    
    % y = x line
    x_range = linspace(0, 100, 100);
    y_identity = x_range;
    
    plot(x_range, y_identity, ...
        'Color', mid_gray, ...
        'LineStyle', '--', ...
        'LineWidth', 1.5);
    
    plot(x, yfit, 'k', 'LineWidth', 3);
    
    % graph settings
    xlabel(sprintf('GT Consistency - %s (%%)', axis_names{ax}));
    ylabel(sprintf('Proposed Consistency - %s (%%)', axis_names{ax}));
    axis equal;
    xlim([0 100]);
    ylim([0 100]);
    hold off;
    
    % compute the correlation coefficient
    [Rmat, Pmat] = corrcoef(x, y);
    R_value = Rmat(1, 2);
    p_value = Pmat(1, 2);
    
    fprintf('IMU %s-axis: R = %.3f, p-value = %.4g\n', axis_names{ax}, R_value, p_value);
end









% % figure drawn with a different colour per participant
% x = ratio_mocap_list;
% y = ratio_imu_list;
% 
% 
% 
% % define the colour palette (generated automatically for the number of participants)
% % colors = lines(num_subjects);  % MATLAB default colour palette
colors = turbo(20);
% % or specify the desired colours directly:
% % colors = [
% %     0.8, 0.2, 0.2;   % red
% %     0.2, 0.6, 0.8;   % blue
% %     0.3, 0.7, 0.3;   % green
% %     0.9, 0.6, 0.1;   % orange
% %     0.6, 0.3, 0.7;   % purple
% % ];
% 
% figure(20000);
% hold on;
% 
% % data start index
% start_idx = 1;
% legend_entries = {};
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx = start_idx + n_per_subject_fast(subj) - 1;
% 
%     % extract the current participant's data
%     x_subj = x(start_idx:end_idx);
%     y_subj = y(start_idx:end_idx);
% 
%     % Scatter plot
%     scatter(x_subj, y_subj, 60, 'filled', 'MarkerFaceColor', colors(subj*2,:));
% 
%     % compute the linear regression
%     p = polyfit(x_subj, y_subj, 1);
%     x_fit = linspace(min(x_subj), max(x_subj), 100);
%     y_fit = polyval(p, x_fit);
% 
%     % draw the Regression line
%     plot(x_fit, y_fit, 'Color', colors(subj*2,:), 'LineWidth', 2);
% 
%     % % store the string for the legend
%     % legend_entries{end+1} = sprintf('Subject %d', subj);
%     % legend_entries{end+1} = sprintf('Fit %d (y=%.2fx+%.2f)', subj, p(1), p(2));
%     % 
%     % update the index for the next participant
%     start_idx = end_idx + 1;
% end
% 
% % y = x reference line (optional)
% % plot([0 100], [0 100], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
% 
% xlabel('Ref dev (%)');
% ylabel('IMU dev (%)');
% axis equal;
% xlim([0 100]);
% ylim([0 100]);
% % legend(legend_entries, 'Location', 'best');
% hold off;


%% swing-tempo related
swing_tempo_ref_list;   % all ref data
swing_tempo_fast_list;  % all fast data


% num_subjects = length(n_per_subject_ref);  % the number of participants must be the same
% colors = lines(num_subjects);

figure(30000);
hold on;

% start index for each
start_idx_ref = 1;
start_idx_fast = 1;

legend_entries = {};

% for storing the results
ref_means = zeros(num_subjects, 1);
all_percent_changes = {};


for subj = 1:num_subjects
    % data range of the current participant (ref and fast separately)
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    
    % extract the current participant's data
    ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
    fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);
    
    % compute the ref mean per participant

    % disp(ref_subj)

    ref_mean = mean(ref_subj);
    ref_means(subj) = ref_mean;
    
    % compute the percentage change (%) of the fast data relative to the ref mean
    percent_change = ((fast_subj - ref_mean) / ref_mean) * 100;
    all_percent_changes{subj} = percent_change;
    
    % x-axis: data index, y-axis: percentage change
    x_plot = 1:n_per_subject_fast(subj);
    
    % Scatter plot
    scatter(x_plot, percent_change, 60, 'filled', 'MarkerFaceColor', colors(subj*2,:));
    
    % horizontal line for the mean percentage change per participant
    mean_change = mean(percent_change);
    % plot([0.5, n_per_subject_fast(subj)+0.5], [mean_change, mean_change], ...
    %     'Color', colors(subj*2,:), 'LineWidth', 2, 'LineStyle', '--');
    
    legend_entries{end+1} = sprintf('S%d (n_{ref}=%d, n_{fast}=%d)', ...
        subj, n_per_subject_ref(subj), n_per_subject_fast(subj));
    legend_entries{end+1} = sprintf('Mean: %.1f%%', mean_change);
    
    % update the indices for the next participant (separately for each)
    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

yline(0, 'k-', 'LineWidth', 1.5);
xlabel('Trial Index');
ylabel('Change from Ref Mean (%)');
title('Swing Tempo: Fast vs Ref Mean');
% legend(legend_entries, 'Location', 'best');
grid on;
hold off;



%% compute the mean and standard deviation of Swing Time per participant

swing_time_normal_list;  % all normal data
swing_time_fast_list;    % all fast data



num_subjects = length(n_per_subject_ref);

% for storing the results
normal_means = zeros(num_subjects, 1);
normal_stds  = zeros(num_subjects, 1);
fast_means   = zeros(num_subjects, 1);
fast_stds    = zeros(num_subjects, 1);

% initialise the start index
start_idx_ref  = 1;
start_idx_fast = 1;

for subj = 1:num_subjects
    % data range of the current participant
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    
    % extract the current participant's data
    normal_subj = swing_time_normal_list(start_idx_ref:end_idx_ref);
    fast_subj   = swing_time_fast_list(start_idx_fast:end_idx_fast);
    
    % compute the mean and standard deviation
    normal_means(subj) = mean(normal_subj);
    normal_stds(subj)  = std(normal_subj);
    fast_means(subj)   = mean(fast_subj);
    fast_stds(subj)    = std(fast_subj);
    
    % update the index for the next participant
    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

%% console output
fprintf('\n===== Swing Time results per participant =====\n');
fprintf('%-10s | %-20s | %-20s\n', 'Subject', 'Normal (Mean±SD)', 'Fast (Mean±SD)');
fprintf('-----------------------------------------------------------\n');

for subj = 1:num_subjects
    fprintf('S%-9d | %8.3f ± %-8.3f | %8.3f ± %-8.3f\n', ...
        subj, normal_means(subj)*0.005, normal_stds(subj)*0.005, ...
        fast_means(subj)*0.005, fast_stds(subj)*0.005);
end

fprintf('-----------------------------------------------------------\n');
fprintf('%-10s | %8.3f ± %-8.3f | %8.3f ± %-8.3f\n', ...
    'Total', mean(normal_means)*0.005, mean(normal_stds)*0.005, ...
    mean(fast_means)*0.005, mean(fast_stds)*0.005);




%% ====== summary bar chart per participant ======
% figure(40000);

mean_changes = zeros(num_subjects, 1);
std_changes = zeros(num_subjects, 1);

for subj = 1:num_subjects
    mean_changes(subj) = mean(all_percent_changes{subj});
    std_changes(subj) = std(all_percent_changes{subj});
end

% bar_handle = bar(1:num_subjects, mean_changes, 'FaceColor', 'flat');
% for subj = 1:num_subjects
%     bar_handle.CData(subj,:) = colors(subj*2,:);
% end
% hold on;
% errorbar(1:num_subjects, mean_changes, std_changes, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);
% yline(0, 'k--', 'LineWidth', 1);
% 
% xlabel('Subject');
% ylabel('Mean Change from Ref (%)');
% title('Average Swing Tempo Change per Subject');
% xticks(1:num_subjects);
% xticklabels(arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false));
% grid on;
% hold off;

%% ====== console output ======
fprintf('\n===== summary of results per participant =====\n');
for subj = 1:num_subjects
    fprintf('Subject %d: Ref Mean = %.2f (n=%d), Fast Mean Change = %.1f%% ± %.1f%% (n=%d)\n', ...
        subj, ref_means(subj), n_per_subject_ref(subj), ...
        mean_changes(subj), std_changes(subj), n_per_subject_fast(subj));
end



% %% all_percent_changes vs ratio_imu_list scatter plot
% figure(50000);
% hold on;
% 
% num_subjects = length(n_per_subject_fast);
% % colors = lines(num_subjects);
% 
% start_idx = 1;
% legend_entries = {};
% 
% % for storing all the data (for the overall regression line)
% all_x = [];
% all_y = [];
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx = start_idx + n_per_subject_fast(subj) - 1;
% 
%     % x: all_percent_changes (swing tempo percentage change)
%     % x_subj = all_percent_changes{subj};
%     x_subj = abs(all_percent_changes{subj});
% 
%     % y: extract this participant's data from ratio_imu_list
%     y_subj = ratio_imu_list(start_idx:end_idx);
% 
%     % Scatter plot
%     scatter(x_subj, y_subj, 60, 'filled', 'MarkerFaceColor', colors(subj*2,:));
% 
%     % regression line per participant (optional)
%     if length(x_subj) > 1
%         p = polyfit(x_subj, y_subj, 1);
%         x_fit = linspace(min(x_subj), max(x_subj), 100);
%         y_fit = polyval(p, x_fit);
%         plot(x_fit, y_fit, 'Color', colors(subj*2,:), 'LineWidth', 1.5, 'LineStyle', '--');
%     end
% 
%     % legend_entries{end+1} = sprintf('S%d', subj);
% 
%     % append to the overall data
%     all_x = [all_x; x_subj(:)];
%     all_y = [all_y; y_subj(:)];
% 
%     % update the index for the next participant
%     start_idx = end_idx + 1;
% end
% 
% % overall regression line
% p_all = polyfit(all_x, all_y, 1);
% x_fit_all = linspace(min(all_x), max(all_x), 100);
% y_fit_all = polyval(p_all, x_fit_all);
% plot(x_fit_all, y_fit_all, 'k', 'LineWidth', 2.5);
% legend_entries{end+1} = sprintf('All (y=%.2fx+%.2f)', p_all(1), p_all(2));
% 
% % compute the correlation coefficient
% [Rmat, Pmat] = corrcoef(all_x, all_y);
% R_value = Rmat(1, 2);
% p_value = Pmat(1, 2);
% 
% xlabel('Swing Tempo Change (%)');
% ylabel('IMU Ratio (%)');
% title(sprintf('Swing Tempo Change vs IMU Ratio (R=%.3f, p=%.4f)', R_value, p_value));
% legend(legend_entries, 'Location', 'best');
% grid on;
% hold off;
% axis equal;

% % console output
% fprintf('\n===== correlation analysis results =====\n');
% fprintf('Pearson R = %.4f\n', R_value);
% fprintf('p-value   = %.4f\n', p_value);
% fprintf('regression equation: y = %.4f * x + %.4f\n', p_all(1), p_all(2));





% %% all_percent_changes vs ratio_imu_list scatter plot
% figure(60000);
% hold on;
% 
% num_subjects = length(n_per_subject_fast);
% % colors = lines(num_subjects);
% 
% start_idx = 1;
% legend_entries = {};
% 
% % for storing all the data (for the overall regression line)
% all_x = [];
% all_y = [];
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx = start_idx + n_per_subject_fast(subj) - 1;
% 
%     % x: all_percent_changes (swing tempo percentage change)
%     % x_subj = all_percent_changes{subj};
%     x_subj = abs(all_percent_changes{subj});
% 
%     % y: extract this participant's data from ratio_imu_list
%     y_subj = ratio_mocap_list(start_idx:end_idx);
% 
%     % Scatter plot
%     scatter(x_subj, y_subj, 60, 'filled', 'MarkerFaceColor', colors(subj*2,:));
% 
%     % regression line per participant (optional)
%     if length(x_subj) > 1
%         p = polyfit(x_subj, y_subj, 1);
%         x_fit = linspace(min(x_subj), max(x_subj), 100);
%         y_fit = polyval(p, x_fit);
%         plot(x_fit, y_fit, 'Color', colors(subj*2,:), 'LineWidth', 1.5, 'LineStyle', '--');
%     end
% 
%     % legend_entries{end+1} = sprintf('S%d', subj);
% 
%     % append to the overall data
%     all_x = [all_x; x_subj(:)];
%     all_y = [all_y; y_subj(:)];
% 
%     % update the index for the next participant
%     start_idx = end_idx + 1;
% end
% 
% % overall regression line
% p_all = polyfit(all_x, all_y, 1);
% x_fit_all = linspace(min(all_x), max(all_x), 100);
% y_fit_all = polyval(p_all, x_fit_all);
% plot(x_fit_all, y_fit_all, 'k', 'LineWidth', 2.5);
% legend_entries{end+1} = sprintf('All (y=%.2fx+%.2f)', p_all(1), p_all(2));
% 
% % compute the correlation coefficient
% [Rmat, Pmat] = corrcoef(all_x, all_y);
% R_value = Rmat(1, 2);
% p_value = Pmat(1, 2);
% 
% xlabel('Swing Tempo Change (%)');
% ylabel('mocap Ratio (%)');
% title(sprintf('Swing Tempo Change vs mocap Ratio (R=%.3f, p=%.4f)', R_value, p_value));
% legend(legend_entries, 'Location', 'best');
% grid on;
% hold off;
% axis equal;

% 
% % console output
% fprintf('\n===== correlation analysis results =====\n');
% fprintf('Pearson R = %.4f\n', R_value);
% fprintf('p-value   = %.4f\n', p_value);
% fprintf('regression equation: y = %.4f * x + %.4f\n', p_all(1), p_all(2));

%% ====== Figure 50010: three graphs combined (3x1 subplot) ======
fig_height = 300;  % variable controlling the height (modify if needed)

figure(50010);
clf;
set(gcf, 'Position', [100, 349, 600, fig_height]);

% ===== Subplot spacing settings =====
left_margin = 0.13;
top_margin = 0.05;
bottom_margin = 0.08;
plot_width = 0.82;
gap = 0.05;  % <-- adjust only this value
plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;
% =============================

% x-axis labels (used only on the last subplot)
x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];

%% ----- Subplot 1: Swing Time Ratio -----
subplot(3, 1, 1);
set(gca, 'Position', [left_margin, 1 - top_margin - plot_height, plot_width, plot_height]);
hold on;

start_idx_ref  = 1;
start_idx_fast = 1;
swing_time_ratios = zeros(num_subjects, 1);
swing_time_ratio_stds = zeros(num_subjects, 1);

for subj = 1:num_subjects
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    
    normal_subj = swing_time_normal_list(start_idx_ref:end_idx_ref);
    fast_subj   = swing_time_fast_list(start_idx_fast:end_idx_fast);
    
    normal_mean = mean(normal_subj);
    ratio_each = (fast_subj / normal_mean) * 100;
    
    swing_time_ratios(subj) = mean(ratio_each);
    swing_time_ratio_stds(subj) = std(ratio_each);
    
    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

all_ratios = [swing_time_ratios; NaN; mean(swing_time_ratios)];
all_stds = [swing_time_ratio_stds; NaN; mean(swing_time_ratio_stds)];

bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
for i = 1:num_subjects
    if i == highlight_subj
        bar_handle.CData(i,:) = dark_red;
    else
        bar_handle.CData(i,:) = gray_bar;
    end
end
bar_handle.CData(num_subjects+1,:) = [1 1 1];
bar_handle.CData(end,:) = gray_bar;

errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);

xticks(1:length(all_ratios));
set(gca, 'XTick', [])
set(gca, 'XTickLabel', []);  % remove the x-axis labels (shown only at the bottom)
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+ 1]);
ylim([0 100]);
box off;
hold off;


%% ----- Subplot 2: Swing Tempo Ratio -----
subplot(3, 1, 2);
set(gca, 'Position', [left_margin, 1 - top_margin - plot_height*2 - gap, plot_width, plot_height]);
hold on;

start_idx_ref  = 1;
start_idx_fast = 1;
swing_tempo_ratios = zeros(num_subjects, 1);
swing_tempo_ratio_stds = zeros(num_subjects, 1);

for subj = 1:num_subjects
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    
    ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
    fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);
    
    ref_mean = mean(ref_subj);
    ratio_each = (fast_subj / ref_mean) * 100;
    
    swing_tempo_ratios(subj) = mean(ratio_each);
    swing_tempo_ratio_stds(subj) = std(ratio_each);
    
    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

all_ratios = [swing_tempo_ratios; NaN; mean(swing_tempo_ratios)];
all_stds = [swing_tempo_ratio_stds; NaN; mean(swing_tempo_ratio_stds)];

bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
for i = 1:num_subjects
    if i == highlight_subj
        bar_handle.CData(i,:) = dark_red;
    else
        bar_handle.CData(i,:) = gray_bar;
    end
end
bar_handle.CData(num_subjects+1,:) = [1 1 1];
bar_handle.CData(end,:) = gray_bar;

errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);

% xticks(1:length(all_ratios));
set(gca, 'XTick', [])
set(gca, 'XTickLabel', []);  % remove the x-axis labels
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+1]);
ylim([0 120]);
box off;
hold off;


%% ----- Subplot 3: IMU Consistency (Axis Ratio) -----
subplot(3, 1, 3);
set(gca, 'Position', [left_margin, bottom_margin, plot_width, plot_height]);
hold on;

axis_ratio_means = zeros(num_subjects, 1);
axis_ratio_stds = zeros(num_subjects, 1);
start_idx_fast = 1;

for subj = 1:num_subjects
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    
    ratio_subj = ratio_imu_list(start_idx_fast:end_idx_fast);
    
    axis_ratio_means(subj) = mean(ratio_subj);
    axis_ratio_stds(subj) = std(ratio_subj);
    
    start_idx_fast = end_idx_fast + 1;
end

all_ratios = [axis_ratio_means; NaN; mean(axis_ratio_means)];
all_stds = [axis_ratio_stds; NaN; mean(axis_ratio_stds)];

bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
for i = 1:num_subjects
    if i == highlight_subj
        bar_handle.CData(i,:) = dark_red;
    else
        bar_handle.CData(i,:) = gray_bar;
    end
end
bar_handle.CData(num_subjects+1,:) = [1 1 1];
bar_handle.CData(end,:) = gray_bar;

errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);

% xticks(1:length(all_ratios));
set(gca, 'XTick', [])
xticklabels(x_labels);  % show the x-axis labels only on the bottom subplot
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+1]);
ylim([0 110]);
box off;
hold off;
print(gcf, sprintf('fig6.svg'), '-dsvg', '-vector');


% %% ====== Figure 50020: two graphs (2x1 subplot), Total removed ======
% fig_height = 250;  % variable controlling the height (modify if needed)
% 
% figure(50020);
% clf;
% set(gcf, 'Position', [100, 349, 250, fig_height]);
% 
% % ===== Subplot spacing settings =====
% left_margin = 0.18;
% top_margin = 0.05;
% bottom_margin = 0.12;
% plot_width = 0.78;
% gap = 0.08;
% plot_height = (1 - top_margin - bottom_margin - gap) / 2;
% 
% %% ----- Subplot 1 (top): IMU Consistency -----
% subplot(2, 1, 1);
% set(gca, 'Position', [left_margin, 1 - top_margin - plot_height, plot_width, plot_height]);
% hold on;
% 
% axis_ratio_means = zeros(num_subjects, 1);
% axis_ratio_stds = zeros(num_subjects, 1);
% start_idx_fast = 1;
% 
% for subj = 1:num_subjects
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
%     ratio_subj = ratio_imu_list(start_idx_fast:end_idx_fast);
%     axis_ratio_means(subj) = mean(ratio_subj);
%     axis_ratio_stds(subj) = std(ratio_subj);
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% all_ratios = axis_ratio_means;
% all_stds = axis_ratio_stds;
% 
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% for i = 1:num_subjects
%     % bar_handle.CData(i,:) = gray_bar;
%     bar_handle.CData(i,:) = dark_red;
% end
% 
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 6);
% 
% set(gca, 'XTick', []);
% set(gca, 'XTickLabel', []);
% set(gca, 'YTick', [0 50 100]);
% set(gca, 'FontSize', 12, 'FontName', 'Gill Sans MT');
% xlim([0, num_subjects + 1]);
% ylim([0 110]);
% 
% box off;
% ax = gca;
% plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(2) ax.YLim(2)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% plot([ax.XLim(2) ax.XLim(2)], [ax.YLim(1) ax.YLim(2)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(1) ax.YLim(1)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% 
% hold off;
% 
% %% ----- Subplot 2 (bottom): Swing Tempo Ratio -----
% subplot(2, 1, 2);
% set(gca, 'Position', [left_margin, bottom_margin, plot_width, plot_height]);
% hold on;
% 
% start_idx_ref  = 1;
% start_idx_fast = 1;
% swing_tempo_ratios = zeros(num_subjects, 1);
% swing_tempo_ratio_stds = zeros(num_subjects, 1);
% 
% for subj = 1:num_subjects
%     end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
%     ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
%     fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);
%     ref_mean = mean(ref_subj);
%     ratio_each = (fast_subj / ref_mean) * 100;
%     swing_tempo_ratios(subj) = mean(ratio_each);
%     swing_tempo_ratio_stds(subj) = std(ratio_each);
%     start_idx_ref  = end_idx_ref  + 1;
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% all_ratios = swing_tempo_ratios;
% all_stds = swing_tempo_ratio_stds;
% 
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% for i = 1:num_subjects
%     bar_handle.CData(i,:) = gray_bar;
% end
% 
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 6);
% 
% set(gca, 'XTick', []);
% set(gca, 'XTickLabel', []);
% set(gca, 'YTick', [0 50 100]);
% set(gca, 'FontSize', 12, 'FontName', 'Gill Sans MT');
% xlim([0, num_subjects + 1]);
% ylim([0 120]);
% 
% box off;
% ax = gca;
% plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(2) ax.YLim(2)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% plot([ax.XLim(2) ax.XLim(2)], [ax.YLim(1) ax.YLim(2)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% plot([ax.XLim(1) ax.XLim(2)], [ax.YLim(1) ax.YLim(1)], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
% 
% hold off;
% 
% print(gcf, sprintf('fig7.svg'), '-dsvg', '-vector');

%% ====== Figure 50020: two graphs (2x1 subplot), Total removed ======
fig_height = 250;
figure(50020);
clf;
set(gcf, 'Position', [100, 349, 250, fig_height]);
set(gcf, 'Color', 'white');  % explicitly set the background to white

% ===== Subplot spacing settings =====
left_margin = 0.18;
top_margin = 0.05;
bottom_margin = 0.12;
plot_width = 0.78;
gap = 0.08;
plot_height = (1 - top_margin - bottom_margin - gap) / 2;

%% ----- Subplot 1 (top): IMU Consistency -----
subplot(2, 1, 1);
set(gca, 'Position', [left_margin, 1 - top_margin - plot_height, plot_width, plot_height]);
hold on;

axis_ratio_means = zeros(num_subjects, 1);
axis_ratio_stds = zeros(num_subjects, 1);
start_idx_fast = 1;
for subj = 1:num_subjects
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    ratio_subj = ratio_imu_list(start_idx_fast:end_idx_fast);
    axis_ratio_means(subj) = mean(ratio_subj);
    axis_ratio_stds(subj) = std(ratio_subj);
    start_idx_fast = end_idx_fast + 1;
end

all_ratios = axis_ratio_means;
all_stds = axis_ratio_stds;

bar_handle = bar(1:length(all_ratios), all_ratios, ...
    'FaceColor', dark_red, ...
    'EdgeColor', 'none');

errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', ...
    'LineStyle', 'none', 'LineWidth', 0.5, 'CapSize', 6);

set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 12, 'FontName', 'Gill Sans MT');
set(gca, 'Color', 'white');
xlim([0, num_subjects + 1]);
ylim([0 110]);
box off;
hold off;

%% ----- Subplot 2 (bottom): Swing Tempo Ratio -----
subplot(2, 1, 2);
set(gca, 'Position', [left_margin, bottom_margin, plot_width, plot_height]);
hold on;

start_idx_ref  = 1;
start_idx_fast = 1;
swing_tempo_ratios = zeros(num_subjects, 1);
swing_tempo_ratio_stds = zeros(num_subjects, 1);
for subj = 1:num_subjects
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
    ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
    fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);
    ref_mean = mean(ref_subj);
    ratio_each = (fast_subj / ref_mean) * 100;
    swing_tempo_ratios(subj) = mean(ratio_each);
    swing_tempo_ratio_stds(subj) = std(ratio_each);
    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

all_ratios = swing_tempo_ratios;
all_stds = swing_tempo_ratio_stds;

bar_handle = bar(1:length(all_ratios), all_ratios, ...
    'FaceColor', gray_bar, ...
    'EdgeColor', 'none');

errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', ...
    'LineStyle', 'none', 'LineWidth', 0.5, 'CapSize', 6);

set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 12, 'FontName', 'Gill Sans MT');
set(gca, 'Color', 'white');
xlim([0, num_subjects + 1]);
ylim([0 120]);
box off;
hold off;

print(gcf, 'fig7.svg', '-dsvg', '-vector');

%% ====== Figure 50021: Figure 50020 export version (8 cm, Gill Sans 15 pt) ======
fig50021_size_cm = [8 8];
figure(50021);
clf;
set(gcf, 'Color', 'white', 'Units', 'centimeters', ...
         'Position', [2 2 fig50021_size_cm]);

subplot(2, 1, 1);
set(gca, 'Position', [left_margin, 1 - top_margin - plot_height, plot_width, plot_height]);
hold on;
all_ratios = axis_ratio_means;
all_stds = axis_ratio_stds;
bar(1:length(all_ratios), all_ratios, ...
    'FaceColor', dark_red, ...
    'EdgeColor', 'none');
errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', ...
    'LineStyle', 'none', 'LineWidth', 1.0, 'CapSize', 6);
set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 15, 'FontName', 'Gill Sans MT');
set(gca, 'Color', 'white');
xlim([0, num_subjects + 1]);
ylim([0 110]);
box off;
hold off;

subplot(2, 1, 2);
set(gca, 'Position', [left_margin, bottom_margin, plot_width, plot_height]);
hold on;
all_ratios = swing_tempo_ratios;
all_stds = swing_tempo_ratio_stds;
bar(1:length(all_ratios), all_ratios, ...
    'FaceColor', gray_bar, ...
    'EdgeColor', 'none');
errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', ...
    'LineStyle', 'none', 'LineWidth', 1.0, 'CapSize', 6);
set(gca, 'XTick', []);
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 15, 'FontName', 'Gill Sans MT');
set(gca, 'Color', 'white');
xlim([0, num_subjects + 1]);
ylim([0 120]);
box off;
hold off;

set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig50021_size_cm], ...
         'PaperSize', fig50021_size_cm);
print(gcf, 'fig7_8cm.svg', '-dsvg', '-vector');


% %% ====== previous Figure 50001~50003 (commented out) ======
% 
% figure(50001);
% clf;
% hold on;
% ... (previous code)
% 
% figure(50002);
% clf;
% hold on;
% ... (previous code)
% 
% figure(50003);
% clf;
% hold on;
% ... (previous code)

% 
% %% ====== Figure 1: Swing Time ratio (Fast relative to Normal) ======
% figure(50001);
% clf;
% hold on;
% 
% % initialise the start index
% start_idx_ref  = 1;
% start_idx_fast = 1;
% 
% % for storing the results
% swing_time_ratios = zeros(num_subjects, 1);
% swing_time_ratio_stds = zeros(num_subjects, 1);
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
% 
%     % extract the current participant's data
%     normal_subj = swing_time_normal_list(start_idx_ref:end_idx_ref);
%     fast_subj   = swing_time_fast_list(start_idx_fast:end_idx_fast);
% 
%     % ratio of fast when the normal mean is taken as 100%
%     normal_mean = mean(normal_subj);
%     ratio_each = (fast_subj / normal_mean) * 100;
% 
%     swing_time_ratios(subj) = mean(ratio_each);
%     swing_time_ratio_stds(subj) = std(ratio_each);
% 
%     % update the index
%     start_idx_ref  = end_idx_ref  + 1;
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% % add the Total mean (with a one-slot gap)
% all_ratios = [swing_time_ratios; NaN; mean(swing_time_ratios)];
% all_stds = [swing_time_ratio_stds; NaN; mean(swing_time_ratio_stds)];
% 
% % Bar graph
% x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% 
% % colour settings (dark_red for highlight_subj only, gray for the rest)
% for i = 1:num_subjects
%     if i == highlight_subj
%         bar_handle.CData(i,:) = dark_red;
%     else
%         bar_handle.CData(i,:) = gray_bar;
%     end
% end
% bar_handle.CData(num_subjects+1,:) = [1 1 1];  % blank slot (white)
% bar_handle.CData(end,:) = gray_bar;  % Total grey
% 
% % Error bar
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
% 
% % reference line (100%)
% yline(100, 'k--', 'LineWidth', 1.5);
% 
% % xlabel('Subject');
% ylabel('Ratio (%)');
% % title('Swing Time: Fast / Normal Mean × 100%');
% xticks(1:length(all_ratios));
% xticklabels(x_labels);
% grid on;
% hold off;
% 
% 
% %% ====== Figure 2: Swing Tempo ratio (Fast relative to Ref) ======
% figure(50002);
% clf;
% hold on;
% 
% % initialise the start index
% start_idx_ref  = 1;
% start_idx_fast = 1;
% 
% % for storing the results
% swing_tempo_ratios = zeros(num_subjects, 1);
% swing_tempo_ratio_stds = zeros(num_subjects, 1);
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
% 
%     % extract the current participant's data
%     ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
%     fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);
% 
%     % ratio of fast when the ref mean is taken as 100%
%     ref_mean = mean(ref_subj);
%     ratio_each = (fast_subj / ref_mean) * 100;
% 
%     swing_tempo_ratios(subj) = mean(ratio_each);
%     swing_tempo_ratio_stds(subj) = std(ratio_each);
% 
%     % update the index
%     start_idx_ref  = end_idx_ref  + 1;
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% % add the Total mean (with a one-slot gap)
% all_ratios = [swing_tempo_ratios; NaN; mean(swing_tempo_ratios)];
% all_stds = [swing_tempo_ratio_stds; NaN; mean(swing_tempo_ratio_stds)];
% 
% % Bar graph
% x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% 
% % colour settings
% for i = 1:num_subjects
%     if i == highlight_subj
%         bar_handle.CData(i,:) = dark_red;
%     else
%         bar_handle.CData(i,:) = gray_bar;
%     end
% end
% bar_handle.CData(num_subjects+1,:) = [1 1 1];
% bar_handle.CData(end,:) = gray_bar;
% 
% % Error bar
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
% 
% % reference line (100%)
% yline(100, 'k--', 'LineWidth', 1.5);
% 
% % xlabel('Subject');
% ylabel('Ratio (%)');
% % title('Swing Tempo: Fast / Ref Mean × 100%');
% xticks(1:length(all_ratios));
% xticklabels(x_labels);
% grid on;
% hold off;
% 
% 
% %% ====== Figure 3: Axis Ratio (out_fast.axis_ratio) ======
% figure(50003);
% clf;
% hold on;
% 
% % for storing the results
% axis_ratio_means = zeros(num_subjects, 1);
% axis_ratio_stds = zeros(num_subjects, 1);
% 
% % initialise the start index
% start_idx_fast = 1;
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
% 
%     % extract this participant's data from the already stored ratio_imu_list
%     ratio_subj = ratio_imu_list(start_idx_fast:end_idx_fast);
% 
%     % mean and standard deviation of axis_ratio
%     axis_ratio_means(subj) = mean(ratio_subj);
%     axis_ratio_stds(subj) = std(ratio_subj);
% 
%     % update the index
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% % add the Total mean (with a one-slot gap)
% all_ratios = [axis_ratio_means; NaN; mean(axis_ratio_means)];
% all_stds = [axis_ratio_stds; NaN; mean(axis_ratio_stds)];
% 
% % Bar graph
% x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% 
% % colour settings
% for i = 1:num_subjects
%     if i == highlight_subj
%         bar_handle.CData(i,:) = dark_red;
%     else
%         bar_handle.CData(i,:) = gray_bar;
%     end
% end
% bar_handle.CData(num_subjects+1,:) = [1 1 1];
% bar_handle.CData(end,:) = gray_bar;
% 
% % Error bar
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
% 
% % reference line (100%)
% yline(100, 'k--', 'LineWidth', 1.5);
% 
% ylabel('Axis Ratio (%)');
% title('IMU Consistency');
% xticks(1:length(all_ratios));
% xticklabels(x_labels);
% grid on;
% hold off;

% 
% figure(50004);
% clf;
% hold on;
% 
% % for storing the results
% axis_ratio_means = zeros(num_subjects, 1);
% axis_ratio_stds = zeros(num_subjects, 1);
% 
% % initialise the start index
% start_idx_fast = 1;
% 
% for subj = 1:num_subjects
%     % data range of the current participant
%     end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;
% 
%     % extract this participant's data from the already stored ratio_ml_list
%     ratio_subj = ratio_ml_list(start_idx_fast:end_idx_fast);
% 
%     % mean and standard deviation of axis_ratio
%     axis_ratio_means(subj) = mean(ratio_subj);
%     axis_ratio_stds(subj) = std(ratio_subj);
% 
%     % update the index
%     start_idx_fast = end_idx_fast + 1;
% end
% 
% % add the Total mean (with a one-slot gap)
% all_ratios = [axis_ratio_means; NaN; mean(axis_ratio_means)];
% all_stds = [axis_ratio_stds; NaN; mean(axis_ratio_stds)];
% 
% % Bar graph
% x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];
% bar_handle = bar(1:length(all_ratios), all_ratios, 'FaceColor', 'flat');
% 
% % colour settings
% for i = 1:num_subjects
%     if i == highlight_subj
%         bar_handle.CData(i,:) = dark_red;
%     else
%         bar_handle.CData(i,:) = gray_bar;
%     end
% end
% bar_handle.CData(num_subjects+1,:) = [1 1 1];
% bar_handle.CData(end,:) = gray_bar;
% 
% % Error bar
% errorbar(1:length(all_ratios), all_ratios, all_stds, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
% 
% % reference line (100%)
% yline(100, 'k--', 'LineWidth', 1.5);
% 
% ylabel('Axis Ratio (%)');
% title('ML Consistency');
% xticks(1:length(all_ratios));
% xticklabels(x_labels);
% grid on;
% hold off;


%% ===== automatic saving of the ratio results (per fold) =====
% save to a .mat file according to the fold number
save_filename = sprintf('correlation_fold_%d.mat', fold_num);
eval(sprintf('ratio_mocap_%d = ratio_mocap_list;', fold_num));
eval(sprintf('ratio_imu_%d = ratio_imu_list;', fold_num));
eval(sprintf('ratio_ml_%d = ratio_ml_list;', fold_num));

save(save_filename, sprintf('ratio_mocap_%d', fold_num), ...
                    sprintf('ratio_imu_%d', fold_num), ...
                    sprintf('ratio_ml_%d', fold_num));
fprintf('\n===== results saved: %s =====\n', save_filename);
fprintf('saved variables: ratio_mocap_%d, ratio_imu_%d, ratio_ml_%d\n', fold_num, fold_num, fold_num);


%% ====== console output summary ======
fprintf('\n===== summary of ratios per participant =====\n');
fprintf('%-8s | %-20s | %-20s | %-15s\n', 'Subject', 'Swing Time (%)', 'Swing Tempo (%)', 'Axis Ratio');
fprintf('------------------------------------------------------------------------\n');

for subj = 1:num_subjects
    fprintf('S%-7d | %7.2f ± %-7.2f | %7.2f ± %-7.2f | %7.3f ± %-7.3f\n', ...
        subj, swing_time_ratios(subj), swing_time_ratio_stds(subj), ...
        swing_tempo_ratios(subj), swing_tempo_ratio_stds(subj), ...
        axis_ratio_means(subj), axis_ratio_stds(subj));
end

fprintf('------------------------------------------------------------------------\n');
fprintf('%-8s | %7.2f ± %-7.2f | %7.2f ± %-7.2f | %7.3f ± %-7.3f\n', ...
    'Total', mean(swing_time_ratios), mean(swing_time_ratio_stds), ...
    mean(swing_tempo_ratios), mean(swing_tempo_ratio_stds), ...
    mean(axis_ratio_means), mean(axis_ratio_stds));



x = ratio_mocap_x_list;
y = ratio_imu_x_list;

% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_y_list; %all 100 at 9 so std is 0 -> comes out NAN..
y = ratio_imu_y_list; 

% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_z_list;
y = ratio_imu_z_list;
% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('ML results summary')

x = ratio_mocap_x_list;
y = ratio_ml_x_list;

% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_y_list; %all 100 at 9 so std is 0 -> comes out NAN..
y = ratio_ml_y_list; 

% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_z_list;
y = ratio_ml_z_list;
% 5) compute the correlation coefficient (R) and p-value
[Rmat, Pmat] = corrcoef(x, y);  % Pearson correlation coefficient matrix and p-value matrix

R_value   = Rmat(1, 2);         % x-y correlation coefficient
p_value   = Pmat(1, 2);         % p-value for the x-y correlation coefficient

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);








function out = compute_shade_coverage(data, mean_traj, std_traj, start_idx, end_idx, nsigma)
% compute_shade_coverage
%
% data      : [T x 3 x N]  (time x axis x trial)
% mean_traj : [T x 3]      (mean trajectory per time point)
% std_traj  : [T x 3]      (standard deviation per time point)
% start_idx : start frame index (1~T)
% end_idx   : end   frame index (1~T)
% nsigma    : sigma range (e.g. 1 → mean±1*std, 2 → mean±2*std)
%
% output out:
%   out.axis_in_count    : 1x3, number of points within range per axis
%   out.axis_total_count : 1x3, total number of valid points per axis
%   out.axis_ratio       : 1x3, in_count / total_count
%   out.trial_ratio      : [N x 3], proportion within range per trial and per axis

    % ===== check input sizes/default values =====
    if nargin < 6
        nsigma = 1;
    end

    if ndims(data) ~= 3
        error('data must be a 3-D array of the form [T x 3 x N].');
    end

    [T, D, N] = size(data);
    if D ~= 3
        error('the second dimension (D) is assumed to be 3 axes. currently D=%d', D);
    end

    if ~isequal(size(mean_traj), [T, 3]) || ~isequal(size(std_traj), [T, 3])
        error('mean_traj and std_traj must be of size [T x 3].');
    end

    % if start_idx < 1 || start_idx > T || end_idx < 1 || end_idx > T || start_idx > end_idx
    %     error('start_idx, end_idx are outside the time length T=%d range or in the wrong order.', T);
    % end


    if T==400
        data_seg      = data(21:300, :, :);         % [L x 3 x N]
        mean_seg      = mean_traj(21:300, :);       % [L x 3]
        std_seg       = std_traj(21:300, :);        % [L x 3]
    else
        idx = start_idx:end_idx;     % indices of the segment of interest
        L   = numel(idx);            % segment length
        % ===== extract the segment of interest =====
        data_seg      = data(idx, :, :);         % [L x 3 x N]
        mean_seg      = mean_traj(idx, :);       % [L x 3]
        std_seg       = std_traj(idx, :);        % [L x 3]
    end



    % where std is too small it must not be left at 0, so raise the min std slightly for convenience
    std_seg(std_seg < 1e-12) = 0;

    % ===== initialise the overall per-axis aggregation =====
    axis_in_count    = zeros(1,3);
    axis_total_count = zeros(1,3);

    % ===== prepare to also compute the per-trial and per-axis ratios =====
    trial_in_count    = zeros(N, 3);
    trial_total_count = zeros(N, 3);

    % ===== loop over axes / trials =====
    for d = 1:3

        % broadcast the per-axis mean and std from [L x 1] → [L x N]
        mu  = repmat(mean_seg(:,d), 1, N);     % [L x N]
        sig = repmat(std_seg(:,d),  1, N);     % [L x N]

        % actual data: [L x N]
        X = squeeze(data_seg(:, d, :));        % data_seg(:,d,:) → [L x N]
        if isvector(X)
            X = X(:);  % in case N=1
        end

        % valid values only (guard against NaN)
        valid_mask = isfinite(X) & isfinite(mu) & isfinite(sig);

        % allowed range (mean ± nsigma*std)
        lower_bound = mu - nsigma .* sig;
        upper_bound = mu + nsigma .* sig;

        in_mask = valid_mask & (X >= lower_bound) & (X <= upper_bound);

        % overall count per axis
        axis_in_count(d)    = sum(in_mask(:));
        axis_total_count(d) = sum(valid_mask(:));

        % count per trial
        for n = 1:N
            v_n = valid_mask(:,n);
            i_n = in_mask(:,n);
            trial_in_count(n,d)    = sum(i_n);
            trial_total_count(n,d) = sum(v_n);
        end
    end

    % ===== per-axis ratio =====
    axis_ratio = axis_in_count ./ max(axis_total_count, 1);  % avoid division by 0

    % ===== per-trial ratio =====
    trial_ratio = trial_in_count ./ max(trial_total_count, 1);  % [N x 3]

    % ===== output struct =====
    out = struct();
    out.axis_in_count    = axis_in_count;
    out.axis_total_count = axis_total_count;
    out.axis_ratio       = axis_ratio;
    out.trial_ratio      = trial_ratio;
    out.nsigma           = nsigma;
    out.start_idx        = start_idx;
    out.end_idx          = end_idx;
end












%% statistical significance code
function out = compare_methods(A, B, varargin)
% A, B: N×D (numbers such as errors) — A is assumed to be 'proposed', B the 'baseline'
% options:
%   'Name'      : label (default 'comparison')
%   'Paired'    : logical (default true)
%   'Tail'      : 'both'|'left'|'right' (default 'both')  % 'left' = mean(A-B)<0
%   'Group'     : N×1 participant ID (default [])
%   'BySubject' : whether to aggregate by Group (default false)
%   'Metric'    : 'both'|'mag'|'axis' (default 'both')
%   'Test'      : 'auto'|'t'|'nonparam'  (paired: ttest vs signrank / indep: ttest2 vs ranksum)

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

    % common mask for removing NaN
    keep = all(isfinite(A),2) & all(isfinite(B),2);
    A = A(keep,:);  B = B(keep,:);
    if ~isempty(opt.Group), opt.Group = opt.Group(keep); end

    % aggregate per participant (recommended: avoids pseudoreplication)
    if opt.BySubject && ~isempty(opt.Group)
        [A,B] = aggregate_by_group(A,B,opt.Group,@mean);
    end

    D = size(A,2);
    out = struct('name',opt.Name,'N',size(A,1),'options',opt);

    % ===== magnitude (norm) comparison =====
    if any(strcmpi(opt.Metric, {'both','mag'}))
        Am = sqrt(sum(A.^2,2));  Bm = sqrt(sum(B.^2,2));
        out.mag = run_test(Am, Bm, opt);
        out.mag.label = sprintf('%s | MAG', opt.Name);
    end

    % ===== per-axis comparison =====
    if any(strcmpi(opt.Metric, {'both','axis'}))
        out.axis = cell(1,D);
        for d = 1:D
            out.axis{d} = run_test(A(:,d), B(:,d), opt);
            out.axis{d}.label = sprintf('%s | Axis %d', opt.Name, d);
        end
    end
end

function [Xg,Yg] = aggregate_by_group(X,Y,g,fun)
    ug = unique(g(:));
    Xg = zeros(numel(ug), size(X,2));
    Yg = zeros(numel(ug), size(Y,2));
    for k = 1:numel(ug)
        m = (g==ug(k));
        Xg(k,:) = fun(X(m,:), 1);
        Yg(k,:) = fun(Y(m,:), 1);
    end
end

function res = run_test(A, B, opt)
% A: proposed (prop), B: baseline (ag). Tail='left' → A<B is the alternative hypothesis.
    res = struct('label',opt.Name,'paired',opt.Paired,'tail',opt.Tail);
    if opt.Paired
        diff = A - B; n = numel(diff);
        [useT, p_norm] = normal_decision(diff, opt.Test);
        if useT
            [h,p,ci,stats] = ttest(A,B,'Tail',opt.Tail);
            dz = mean(diff)/std(diff);                  % Cohen's dz (paired)
            res.test='paired t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='dz'; res.es=dz; res.n=n;
        else
            % Wilcoxon signed-rank (for small n it is exact → no z)
            [p,h,stats] = signrank(A,B,'tail',tail_to_signrank(opt.Tail));
            n_eff = sum(A~=B);                         % effective n with zero differences excluded
            res.test='Wilcoxon signed-rank'; res.p=p; res.h=h; res.n=n_eff;

            if isfield(stats,'zval')                   % approximate
                z = stats.zval;
                r = z / sqrt(n_eff);
                res.approx = true;
                res.z = z; res.eff = 'r (z/sqrt(n))'; res.es = r;
            else                                       % exact → rank-biserial r
                Wplus = stats.signedrank;              % rank sum of the positive differences
                Rsum  = n_eff*(n_eff+1)/2;
                r_rb  = (2*Wplus - Rsum) / Rsum;       % [-1,1]
                res.approx = false;
                res.eff = 'rank-biserial r'; res.es = r_rb;
            end
        end
        res.normality_p = p_norm;
        res.meanA = mean(A); res.meanB = mean(B); res.meanDiff = mean(diff);
    else
        % independent-samples comparison
        n1=numel(A); n2=numel(B);
        [useT, ~] = normal_decision([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;                 % Cohen's d
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;
        else
            % Mann-Whitney U (for small n it is exact → no z)
            [p,h,stats] = ranksum(A,B,'tail',tail_to_ranksum(opt.Tail));
            res.test='Mann-Whitney U'; res.p=p; res.h=h; res.n1=n1; res.n2=n2;

            if isfield(stats,'zval')                   % approximate
                z = stats.zval;
                r = z / sqrt(n1+n2);
                res.approx = true;
                res.z = z; res.eff='r (z/sqrt(N))'; res.es=r;
            else                                       % exact → rank-biserial r
                W = stats.ranksum;                     % rank sum of A (the first argument)
                U1 = W - n1*(n1+1)/2;
                r_rb = 1 - 2*U1/(n1*n2);               % [-1,1], negative if A<B
                res.approx = false;
                res.eff='rank-biserial r'; res.es=r_rb;
            end
            res.meanA = mean(A); res.meanB = mean(B);
        end
    end
end

function [useT, p_norm] = normal_decision(x, how)
    useT = true; p_norm = NaN;
    switch lower(how)
        case 't',         useT = true;
        case 'nonparam',  useT = false;
        otherwise % 'auto'
            try
                [h,p_norm] = lillietest(x);
                useT = ~h;                 % normality retained → t-test
            catch
                useT = numel(x) >= 8;      % simple heuristic
            end
    end
end

function tail = tail_to_signrank(t)
    switch lower(t)
        case 'left',  tail='left';
        case 'right', tail='right';
        otherwise,    tail='both';
    end
end
function tail = tail_to_ranksum(t)
    switch lower(t)
        case 'left',  tail='smaller';   % A<B
        case 'right', tail='larger';    % A>B
        otherwise,    tail='both';
    end
end

