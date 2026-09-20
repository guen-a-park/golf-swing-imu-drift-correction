
clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

%% data load
load swingData_2508_aftercal_imp+1_est.mat
% load swingData_2508_est.mat
% load swingData_2508_est_length_fixed.mat
% load swingData_2508_est_length_changed.mat

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;
dark_blue = [40 40 120]/255;


% 0:Reference(marker)
% 1:Reference(Marker + IMU RM)
% 2:Reference(Marker + Marker_gyro)
% 7:derive roll pitch from imu values only, yaw from the mean -> extended to also allow magnetometer
% 9:mahony filter with magnetometer % independent of the initial orientation
% OrientationMethod=7;  
OrientationMethod=7; 

% method 0: imu only (no correction)
% method 1: imu_trajCal   velocity correction
% method 2: imu_trajCalL  velocity + circular trajectory
% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
% method 6: ml_traj_check direct ML trajectory output
mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
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

ml_est_list_stat = [];

%for circlefit validation
raddif=[];

% must be changed to the number of trials, stores per-axis error
% could this just be removed?
% angle_error_axis_list = zeros(900, 3, 20);

% derive quaternion results
angle_error_q_list = [];
angle_error_add_list = [];
angle_error_add2imp = [];
angle_error_plot =[];
angle_error_plot_ref = [];

angle_error_bst_list = [];
angle_error_imp_list = [];
angle_error_fin_list = [];
angle_error_add2bst = [];
error_bet_ml_cam_list = [];


% maybe the way add is detected is the problem
% subj4 day2 add looks wrong
add_acc_list = [];


% change the event point
% point = [g.add,g.add_imu, g.imp, g.vid_min,g.imp_imu1,g.imp_imu2]

add_point_list = [];
bst_point_list = [];
imp_point_list = [];
fin_point_list = [];

roll_marker_list = [];
pitch_marker_list = [];
yaw_marker_list = [];
check_mag_list = [];

imu_roll_error_list = [];
imu_pitch_error_list = [];
marker_yaw_list = [];
imu_yaw_error_list = [];
imu_yaw_error_newmaglist = [];

apdm_biasV_list = [];
imp_est_list = [];


path_length_full_list = [];   % full swing (g.add ~ g.fin)  [unit: Mtraj unit, usually mm or cm]
path_length_down_list = [];   % downswing   (g.bst ~ g.imp)


% mean_idx = 1;
z = 1;


L_list         = [];   % actual length (motion capture reference)
dL_mocap_list  = [];   % mocap-based radial velocity*dt = L_delta
dL_vidimu_list = [];   % video+IMU-based radial velocity*dt = L_delta_vid
trial_list     = [];

Mtraj_cell = {};
g_cell = {};

% ===== settings =====
% mldataDir ='<RUNS_ROOT>\runs_1127_pos450710_ori7_epoch60_2';  % 250

% 251216_ori7 good-performance version
% mldataDir ='<RUNS_ROOT>\runs_1206_acc450710_ori7_epoch100_2';




% when was the earlier discussion version? 1107
% go with gyro included %seems similar to acc-only, maybe a bit worse? converges more// need to decide the criterion
% the numbers all look similar?
% mldataDir ='<RUNS_ROOT>\runs_1127_accgyro450710_ori7_epoch100_3';  % 250


% recheck with the orientation0 version % 1217 ml cleanup
% no need to handle the empty club3 entry for this one
% mldataDir ='<RUNS_ROOT>\runs_1216_accgyro420710_ori0traj_5';  % 250
% mldataDir ='<RUNS_ROOT>\runs_1216_accgyro420710_ori0trajanc_3';  % 250
% mldataDir ='<RUNS_ROOT>\runs_1216_rawaccgyro_420710_ori0traj_4';  % 250
% mldataDir ='<RUNS_ROOT>\runs_1217_rawaccgyro_420710_ori0trajanc_5';  % 250

% mldataDir ='<RUNS_ROOT>\runs_1216_accgyro_420710_ori7trajanc_3';  % 250
% mldataDir ='<RUNS_ROOT>\runs_1217_accgyro_420710_ori7trajanc_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1217_rawaccgyro_420710_ori7traj_3';  % 250


% try a longer range %fast shot has to change too %tried 3->5.. error decreases
% 1219 final model using the camera
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori7traj_5';  % version including fast prediction

%0112
mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
% mldataDir = '<RUNS_ROOT>\runs_0224_accgyro_400800_loso3'; 

% ===== mldataDir2: second model for the viz_mean_z_at_frame comparison =====
mldataDir2 = fullfile(runsRoot(), 'runs_0224_accgyro_400800_loso3');  % <- fill in the path


% mine + imu phase
% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %use run 2 for now ->20.25


% agformer + imu phase
% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %use run 2 for now ->19.55



% % model that fits only the anchor; odd since the data was trained with ori0 / ah, ori was 0
% mldataDir ='<RUNS_ROOT>\runs_1219_accgyro_350800_ori7anc_3';  % version including fast prediction

% participant-specific model %1 participant 7 is predicted oddly.. % increased epochs to 200 for participant 7 only
% mldataDir ='<RUNS_ROOT>\runs_1219_accgyro_350800_ori7trajpsnl_5';  % version including fast prediction


% check with that participant included
% compare against mocap
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_3';  % 250


% check with one participant left out
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt1_5';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt2_5';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt3_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt4_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt5_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt6_5';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt7_5';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt8_5';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt9_3';  % version including fast prediction
% mldataDir ='<RUNS_ROOT>\runs_1218_accgyro_350800_ori0traj_expt10_3';  % version including fast prediction

purple = [128 0 128]/255;  



nSubj_ml   = 10;                     % number of participants
clubs_ml   = {'driver','iron','fast'};      % middle token of the file name
nRows_ml   = 10; nCols_ml = 3;          % number of rows/columns to use from each file
% nRows_ml   = 5; nCols_ml = 3;          % number of rows/columns to use from each file

% number of traj trials
nTrials    = 10;  % number of trials

% ===== initialize result arrays: 10x3x10 =====
ml_est = struct();
for c = 1:numel(clubs_ml)
    ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);  % {trial, subj}
end

% ===== initialize ml_est2 / ml_traj_est2 (for mldataDir2) =====
ml_est2 = struct();
for c = 1:numel(clubs_ml)
    ml_est2.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est2 = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est2.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
end


% 3d comes out well
% runs_1119_acc450710_1 % this is ori7, right? 3e also looks good


%% ========== initialization ==========
% define event-point names and range names
point_names = {'add', 'bst', 'imp', 'fin'};
range_names = {'add_to_bst', 'add_to_imp', 'add_to_fin'};

% initialize the per-event-point error lists
for p = 1:length(point_names)
    pn = point_names{p};
    results.points.(pn).error_xyz_list = [];
    results.points.(pn).error_norm_list = [];
end

% initialize the per-range error lists
for r = 1:length(range_names)
    rn = range_names{r};
    results.ranges.(rn).mae_xyz_list = [];
    results.ranges.(rn).mae_norm_list = [];
    results.ranges.(rn).rmse_xyz_list = [];
    results.ranges.(rn).rmse_norm_list = [];
end


% for subj = [1 2 3 4 5 6 8 9 10]
for subj = 1:10
% for subj = 1:10 %4 6 8
% for subj = 3
% for subj = 5
    % for club = [1 3]
    for club = 1
    % for club = 1:3

        % exit the for loop automatically when missing
        fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
        % fname = sprintf('subj%d_%s_est.csv', subj, clubs_ml{club});
        fpath = fullfile(mldataDir, fname);

        fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
        fpath_traj = fullfile(mldataDir, fname_traj);
        if ~isfile(fpath)
            warning('Missing file: %s', fpath);
            continue
        end

        T = readtable(fpath);  % column names are detected automatically if present

        % use those columns if pred_x, pred_y, pred_z exist, otherwise columns 1-3
        if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
            M = T{:, {'pred_x','pred_y','pred_z'}};
        else
            M = T{:, 1:3};
        end


        % match the length (store only 10 rows; keep NaN for the shortfall)
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
            ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;  % +1 because trial_idx starts at 0
        end

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


        % ===== loading mldataDir2 =====
        fname2      = sprintf('subj%d_%s_test_est.csv',      subj, clubs_ml{club});
        fpath2      = fullfile(mldataDir2, fname2);
        fname_traj2 = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
        fpath_traj2 = fullfile(mldataDir2, fname_traj2);

        if isfile(fpath2)
            T2 = readtable(fpath2);
            if all(ismember({'pred_x','pred_y','pred_z'}, T2.Properties.VariableNames))
                M2 = T2{:, {'pred_x','pred_y','pred_z'}};
            else
                M2 = T2{:, 1:3};
            end
            m2 = min(size(M2,1), nRows_ml);
            ml_est2.(clubs_ml{club})(1:m2, :, subj) = M2(1:m2, :);

            T_traj2 = readtable(fpath_traj2);
            unique_trials2 = unique(T_traj2.trial_idx);
            for i = 1:numel(unique_trials2)
                trial_traj2 = unique_trials2(i);
                idx2 = T_traj2.trial_idx == trial_traj2;
                pred_data2 = [T_traj2.pred_x(idx2), T_traj2.pred_y(idx2), T_traj2.pred_z(idx2)];
                ml_traj_est2.(clubs_ml{club}){trial_traj2+1, subj} = pred_data2;
            end

            % same exception handling as the existing ml_est
            if club==3 && subj==5
                ml_est2.(clubs_ml{club})(1:4,:,subj) = M2(1:4,:);
                ml_est2.(clubs_ml{club})(5,:,subj)   = NaN;
                ml_est2.(clubs_ml{club})(6:10,:,subj) = M2(5:9,:);
                temp2_ = ml_traj_est2.(clubs_ml{club})(1:9, subj);
                ml_traj_est2.(clubs_ml{club})(1:4, subj) = temp2_(1:4);
                ml_traj_est2.(clubs_ml{club}){5, subj}   = NaN;
                ml_traj_est2.(clubs_ml{club})(6:10, subj) = temp2_(5:9);
            end
            if club==3 && subj==9
                ml_est2.(clubs_ml{club})(1:7,:,subj) = M2(1:7,:);
                ml_est2.(clubs_ml{club})(8,:,subj)   = NaN;
                ml_est2.(clubs_ml{club})(9:10,:,subj) = M2(8:9,:);
                temp2_ = ml_traj_est2.(clubs_ml{club})(1:9, subj);
                ml_traj_est2.(clubs_ml{club})(1:7, subj) = temp2_(1:7);
                ml_traj_est2.(clubs_ml{club}){8, subj}   = NaN;
                ml_traj_est2.(clubs_ml{club})(9:10, subj) = temp2_(8:9);
            end
        else
            warning('Missing file (mldataDir2): %s', fpath2);
        end
        % ===== end of mldataDir2 loading =====


        
        % for trial = 7
        % for trial = 1:10
        % for trial = 11:20
        % for trial = 21:30
        % for trial = 20:29
        % for trial = 1:30
        for trial = 21:30
            if subj==1 && club==2 && trial ==1 % looks like an apdm recording error
                continue
            elseif subj==5 && club==3 && trial==5 % could not be derived from the video at all
                continue
            elseif subj==9 && club==3 && trial==8 % the apdm value looks wrong, comes out NaN
                continue
            elseif subj==8 && club==1 && trial ==30 % magnetometer measurement error
                continue
            % no pelvis %temporary, for the video % but how were the later statistics computed
            elseif subj==2 && club==1 && trial ==10 
                continue
            elseif subj==6 && club==1 && trial ==3 
                continue
    
            % elseif subj==10
            %     continue
            end

            %% filter out the trials with odd gyro?

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

            
            g.add = double(g.add);
            g.bst = double(g.bst);
            g.imp = double(g.imp);
            g.fin = double(g.fin);
            
            % need the mat with the updated event points
            % g.add = double(g.add_imu);
            % g.bst = double(g.bst_imu);
            % g.imp = double(g.imp_imu1);
            % g.fin = double(g.fin_imu);

            
            % remove the error at the fin event point
            if g.fin>900
                g.fin = 900;
            end

            
            % modify if the event point changes
            add_est = g.add_est;
            imp_est = g.imp_est;

            % add_est = g.add_imu_est;
            % imp_est = g.imp_imu1_est;

            % use relative values
            rel_est = imp_est-add_est;



            add_point_list = [add_point_list g.add];
            bst_point_list = [bst_point_list g.bst];
            imp_point_list = [imp_point_list; g.imp];
            fin_point_list = [fin_point_list g.fin];


            % % identify the impact event point
            % Lhand = g.marker(g.bst:g.imp+1, 13:15); % coordinates of the first marker (columns 13-15)
            % clubhead = g.marker(g.bst:g.imp+1, 19:21); % coordinates of the second marker (columns 19-21) % from the plot, +1 seems right for imp
            % 
            % % 3D plot settings
            % figure(trial*550);
            % hold on;
            % grid on;
            % xlabel('X');
            % ylabel('Y');
            % zlabel('Z');
            % title('3D Swing Trajectory');
            % % view(3); % set the 3D view
            % view([90 0]);
            % 
            % % plot the 3D swing trajectory over time
            % for t = 1:size(Lhand, 1)
            %     % % connect the origin to the first marker
            %     % plot3([0, Lhand(t, 1)], [0, Lhand(t, 2)], [0, Lhand(t, 3)], 'r-', 'LineWidth', 1.5);
            %     % 
            %     % connect the first marker to the second marker
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



            % done during the 1019 mat processing
            % % filtering step after the 0518 rawdata processing
            % [b, a] = butter(4, cut_freq/(200/2));
            % acc_data = filtfilt(b, a, acc_data);
            % gyro_data = filtfilt(b, a, gyro_data);
            % magnet = filtfilt(b, a, magnet);
            
            % gpt yaw derivation
            % % should this be done in the mat instead?
            % m = magnet; 
            % % --- simple hard/soft iron correction (diagonal approximation) ---
            % b = (max(m,[],1) + min(m,[],1))/2;     % bias (per-axis mean center)
            % s = (max(m,[],1) - min(m,[],1))/2;     % radius
            % gmean = mean(s);
            % scale = gmean ./ s;                    % rough soft-iron axis scale (diagonal approximation)
            % m_cal = (m - b) .* scale;              % quick approximate correction (the exact model uses ellipsoid fitting)
            % 
            % %try without calibration? the one above gives 17 deg error

            m_cal = magnet; 
            


            
            motionag = g.dl(:,1:3);
            % motionag + com = algo at world coordinate 
            motionag = motionag+ com;

            rel_ag = motionag(g.imp,:)-motionag(g.add,:);

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
            % scatter3(abs_wrist(g.imp,1), abs_wrist(g.impmotionag,2), abs_wrist(g.imp,3), ...
            %          50, 'r', 'filled');
            % text(imp_est(:,1), imp_est(:,2),imp_est(:,3), sprintf('%d',trial), 'FontSize',9, ...
            %  'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
            %  'VerticalAlignment','bottom','Clipping','on');
            % 
            % xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
            % 
            % grid on;
            % view(3);
            % axis equal;  % so the ellipsoid is not distorted



            %%  derive figure1 3d position
            % compare the estimation with the marker values
            % check the wrist position in the actual marker frame, not the relative est
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

            % ... each error vector computed above ...
            ok = true;  % included by default
            
            % pelvis-related statistics
            % exclusion conditions (add rules freely as needed)
            ok = ok && ~(club==3);
            ok = ok && ~(subj==2 && club==1 && trial==10);
            ok = ok && ~(subj==2 && club==2 && ismember(trial,[23 29]));
            ok = ok && ~(subj==3 && club==2 && ismember(trial,[1 11 14 15]));
            ok = ok && ~(subj==6 && club==1 && trial==3);
            
            % if you also want to exclude data broken by NaN/Inf and the like:
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
            temp_x = Uo./wU; % as I recall the back jitters less than the front % if not, change it later
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
            Cwdot=[dot1(:) dot2(:) dot3(:)];
            Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; %this is the wrist velocity

            % for gyro calibration
            % for some imported data the dot dimensions changed so it became dot1' dot2' dot3'/
            % not sure when
            [dot1, ddot1] = deriv5(WristM(1:length(vprime_xw),1),ts);
            [dot2, ddot2] = deriv5(WristM(1:length(vprime_xw),2),ts);
            [dot3, ddot3] = deriv5(WristM(1:length(vprime_xw),3),ts);
            WristMdot=[dot1(:) dot2(:) dot3(:)];
            WristMddot=[ddot1(:) ddot2(:) ddot3(:)];
            WristMdotnorm=sqrt(sum(WristMdot.^2,2));
            [dot1, ddot1] = deriv5(WristU(1:length(vprime_xw),1),ts);
            [dot2, ddot2] = deriv5(WristU(1:length(vprime_xw),2),ts);
            [dot3, ddot3] = deriv5(WristU(1:length(vprime_xw),3),ts);
            WristUdot=[dot1(:) dot2(:) dot3(:)];
            WristUddot=[ddot1(:) ddot2(:) ddot3(:)];
            
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
            % by the formula omegax should be this, not sure why the sign is flipped %1020 changed to the line below
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

            % the acc bias itself can be checked, acc with gravity computed from the markers
            % aL_wrist=zeros(length(vprime_xw),3);
            % for i=1:length(vprime_xw)
            %     aL_wrist(i,:) = R2Lw(:,:,i)^(-1)*[WristMddot(i,1);WristMddot(i,2);WristMddot(i,3)];
            % end

            % gyro global reference value
            w_global_marker=dcmRot(R2Lw,gL_wrist);

            
            % get the reference angle values
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

                    % just to make the code run. this one uses the reference value only for the initial orientation
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

                % let's check with the quaternion version  qinf = get_orientation_quaternion(s.time, s.T5wristGyro, s.address, s.R2Lwq(s.address,:)); % right, it uses the quaternion at the address event point
                case 7  % extract roll,pitch using the pilot-data formula % comes out well

                    local_frame = R2Lw(:,:,g.add);

                    pitch_marker = asin(-local_frame(3,1));
                    roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                    yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
            
                    roll_marker=rad2deg(roll_marker);
                    pitch_marker=rad2deg(pitch_marker);
                    yaw_marker = rad2deg(yaw_marker);

                 
                    acclocal_data = acc_data(g.add,:);
                    acc_global = [acclocal_data(1); acclocal_data(2); acclocal_data(3)];

                    % Step 2: normalization (correct uncalibrated values)
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

                    % (additional) magnetometer-based yaw (one frame: g.add)
                    mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);

                    % mxh =  mx*cos(theta) + mz*sin(theta); %% apparently multiplied in the order rx*ry
                    % myh =  mx*sin(phi)*sin(theta) + my*cos(phi) - mz*sin(phi)*cos(theta);
                    
                    % the expression actually multiplied is indeed this one
                    mxh =  mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
                    myh =  my.*cos(phi) - mz.*sin(phi);
                    
                    % disp('norm horizontal component')
                    check_mag = sqrt(mxh^2+myh^2);

                    check_mag_list = [check_mag_list check_mag ];

                    % psi = atan2(-myh, mxh);   % rad  <-- replaced by this
                    % % psi = atan2(myh, mxh);   % rad  <-- replaced by this
                    % rad2deg(psi);

                    
                    psi0_deg = 191.53;
                    alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 7.16 deg
                    % alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 76 deg
                    yaw_imu_deg = psi0_deg - alpha_deg;
                    yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;



                    % % this seems to be the best achievable
                    % psi = -(360-rad2deg(psi))+198.9; %% align magnetic north with mocap north
                    % % disp('yaw marker and mag values in order');
                    % 
                    % 
                    % if subj==5 && club==1 && trial==7
                    %     psi = psi+360;
                    % end

                    % disp(yaw_marker);
                    % disp(psi);
                    
                    psi = deg2rad(yaw_imu_deg);



                    if club==3
                        psi = deg2rad(yaw_marker);
                    end


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
                    

                    imu_yaw_error_newmag = abs(yaw_marker-yaw_imu_deg);
                    imu_yaw_error_newmaglist = [imu_yaw_error_newmaglist,imu_yaw_error_newmag];

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
                    

                    
                    %% code for the reference
                    % copy-pasted so that any method works
                    Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                    for t=1:length(time)
                        qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                        % disp(qinf(t,1))
                        if qinf_ref(t,1)<0
                            qinf_ref(t,:)=-qinf_ref(t,:);
                        end
                    end

                    % if arrow visualization is needed
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
            abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
            abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);

            % look only from address onward
            Mtraj = abs_wrist-abs_wrist(g.add,:);
            Mtraj(1:g.add,:)=0;

            % 0304
            %% full swing trajectory length (add+1 → fin)
            idx_start_full = double(int32(g.add) + 1);
            idx_end_full   = double(int32(g.fin));
            
            if idx_start_full >= 1 && idx_end_full <= size(Mtraj,1) && idx_end_full > idx_start_full
                seg_full = Mtraj(idx_start_full:idx_end_full, :);
                if size(seg_full, 1) >= 2
                    diffs_full       = seg_full(2:end, :) - seg_full(1:end-1, :);   % replaces diff
                    dist_full        = sqrt(sum(diffs_full.^2, 2));                  % replaces vecnorm
                    path_length_full = sum(dist_full);
                    path_length_full_list(end+1) = path_length_full;
                end
            end
            
            %% downswing trajectory length (bst → imp)
            idx_start_down = double(int32(g.bst));
            idx_end_down   = double(int32(g.imp));
            
            if idx_start_down >= 1 && idx_end_down <= size(Mtraj,1) && idx_end_down > idx_start_down
                seg_down = Mtraj(idx_start_down:idx_end_down, :);
                if size(seg_down, 1) >= 2
                    diffs_down       = seg_down(2:end, :) - seg_down(1:end-1, :);   % replaces diff
                    dist_down        = sqrt(sum(diffs_down.^2, 2));                  % replaces vecnorm
                    path_length_down = sum(dist_down);
                    path_length_down_list(end+1) = path_length_down;
                end
            end


            % n_rows_fin = size(Mtraj(g.fin+1:end,:), 1);  % 52
            % Mtraj(g.fin+1:end,:) = repmat(Mtraj(g.fin,:), n_rows_fin, 1);

            Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
            Mvel(1:g.add,:)=0;
            % Mvel(g.fin+1:end,:)=0;

            % Circle fit with marker data points
            [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);                           % address ~ s.finish
            [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);      % bst ~ s.finish
            raddif=[raddif radM-radMs];
            

            % gravity is always along global z
            % the orientation itself is filled with the initial value everywhere

            ag_wo_g(:,1) = a_dcm(:,1);
            ag_wo_g(:,2) = a_dcm(:,2);
            ag_wo_g(:,3) = a_dcm(:,3)-9.80665; % should it always be subtracted using the norm?
            %m to mm
            ag_wo_g(:,:) = ag_wo_g(:,:).*1000;
            

            % % rw=imp_est %a direction vector along the wrist direction is needed
            % % rw = abs_wrist(g.imp,:)
            % % u0 = abs_wrist(g.imp,:)/norm(abs_wrist(g.imp,:))
            % % u1 = abs_wrist(g.imp-1,:)/norm(abs_wrist(g.imp-1,:))
            % % c = max(-1,min(1, dot(u0,u1)))
            % % s = norm(cross(u0,u1))
            % % theta = atan2(s, c)
            % % omega_perp = theta / 0.005
            % 
            % dt = 1/200;
            % % 1) unit vector (ball -> opposite of the wrist direction: toward the origin (ball))
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
            % a_rad = dot(ag_wo_g(g.imp,:), r_hat)                 % component toward the origin (+ means toward the origin)
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
           
            
            %% decide whether to zero at the input address
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

            % % plot velocity and traj before/after zeroing to inspect the data % per participant
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


            %% velocity singularity correction
            velCalRate=1; %correction coefficient
            % velocity correction
            imu_velCal =imu_vel;
            

            %check depending on whether velocity correction is applied
            % global based, 3 points(address, backswingtop, finish)
            for i=g.add:g.bst
                imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.bst,:)./(g.bst-g.add).*(i-g.add) * velCalRate;  % address~g.bst
            end
            imu_velCal(g.bst+1:end,:)=imu_velCal(g.bst+1:end,:)-imu_velCal(g.bst+1,:) * velCalRate;
            for i=g.bst:length(imu_velCal)
                imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.fin,:)./(g.fin-g.bst).*(i-g.bst) * velCalRate; % bst~fin
                % imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(800,:)./(800-g.bst).*(i-g.bst) * velCalRate; % bst~fin
            end

            imu_velCal(g.fin+1:end,:)=0;
            % imu_velCal(800+1:end,:)=0;
            
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
            imu_accelCal=[dot1(:) dot2(:) dot3(:)];         % global
        
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
            

            % replace imp_est with the participant mean?
            imp_est_list = [imp_est_list; rel_est];
           

            % 0710 % push it down like the velocity
            diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

            diff_ag = [(imu_trajCal(g.imp,1)-rel_ag(1)) (imu_trajCal(g.imp,2)-rel_ag(2)) (imu_trajCal(g.imp,3)-rel_ag(3))];

            % initialize the new trajectory
            traj_lin = imu_trajCal;                   % copy of the original
            traj_lin_ag = imu_trajCal;

            % 1) ADD ~ IMP : correction spread linearly / weighting extended toward fin


            for k = g.add : g.fin
                w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                traj_lin(k,:) = imu_trajCal(k,:) - w * diff;  % 1×3 vector
            end

            n_rows_fin = size(traj_lin(g.fin+1:end,:), 1);  % 52
            traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin, 1);


            for k = g.add : g.fin
                w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                traj_lin_ag(k,:) = imu_trajCal(k,:) - w * diff_ag;  % 1×3 vector
            end
            traj_lin_ag(g.fin+1:end,:) = repmat(traj_lin_ag(g.fin,:), n_rows_fin, 1);

            apdm_biasV_list = [apdm_biasV_list; diff];
            %trial-by-trial correction
            apdm_trajCalV = traj_lin;

            apdm_agcal = traj_lin_ag;
            
            %% ML-corrected integration result
            traj_lin_subj = imu_trajCal; 
            
            % if trial>25
            % if trial>5

            
            %% to obtain ori0 in iron & fast shots
            
  
            if club==3
                diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
            else
                if trial>20
                % if trial>25
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj); 
                    % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,subj); % test 9 with 9 training
                    % diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-25,:,10); % test 9 with 8 training
                    ml_est_list_stat = [ml_est_list_stat; abs(ref_rel_imp-ml_est.(clubs_ml{club})(trial-20,:,subj))];
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

            %% traj_lin_subj2 based on mldataDir2
            traj_lin_subj2 = imu_trajCal;

            if club==3
                diff_ml2 = imu_trajCal(g.imp,:) - ml_est2.(clubs_ml{club})(trial,:,subj);
            else
                if trial > 20
                    diff_ml2 = imu_trajCal(g.imp,:) - ml_est2.(clubs_ml{club})(trial-20,:,subj);
                else % dummy value
                    diff_ml2 = imu_trajCal(g.imp,:) - ml_est2.(clubs_ml{club})(1,:,subj);
                end
            end

            for k = g.add : g.fin
                w = (k - g.add) / (g.imp - g.add);
                traj_lin_subj2(k,:) = imu_trajCal(k,:) - w * diff_ml2;
            end
            traj_lin_subj2(g.fin+1:end,:) = repmat(traj_lin_subj2(g.fin,:), n_rows_fin, 1);

           


            % % check the integration result, per trial
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
            % % %% check the integration result, all trials at once
            % for k = 1:3
            %     figure(k)
            %     hold on;
            %     % plot(ag_wo_g(:,k)) % viewing them together made no sense..
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
            % % convert to mm for visualization
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
                angle_error=[angle_error, tempAng]; %per-trial error value, meaning the rotation angle between the two quaternions
                axis_error=[axis_error; tempAxs]; % “axis (direction) of rotation” info, not really an error
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
                angle_error_ref=[angle_error_ref, tempAng]; %per-trial error value, meaning the rotation angle between the two quaternions
                axis_error_ref=[axis_error_ref; tempAxs]; % “axis (direction) of rotation” info, not really an error
            end

            
            % rmse_Rot = sqrt(mean(angle_error(s.address:s.finish).^2));
            % mae_Rot = mean(angle_error(s.address:s.finish));
            angle_error_plot = [angle_error_plot angle_error'];
            angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];

            angle_error_q = angle_error(g.add:g.fin);
            angle_error_a2imp = angle_error(g.add:g.imp);
            angle_error_a2bst = angle_error(g.add:g.bst);

            % angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];
            % angle_error_bst_list = [angle_error_bst_list abs(angle_error(g.bst))];
            % angle_error_imp_list = [angle_error_imp_list abs(angle_error(g.imp))];
            % angle_error_fin_list = [angle_error_fin_list abs(angle_error(g.fin))];

            angle_error_add_list = [angle_error_add_list angle_error(g.add)];
            angle_error_bst_list = [angle_error_bst_list angle_error(g.bst)];
            angle_error_imp_list = [angle_error_imp_list angle_error(g.imp)];
            angle_error_fin_list = [angle_error_fin_list angle_error(g.fin)];

            % angle_error_q_list = [angle_error_q_list mean(abs(angle_error_q))];
            % angle_error_add2imp = [angle_error_add2imp mean(abs(angle_error_imp))];

            angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
            angle_error_add2imp = [angle_error_add2imp mean(angle_error_a2imp)];
            angle_error_add2bst = [angle_error_add2bst mean(angle_error_a2bst)];


            % visualize the quaternion angle error
            % figure(subj+100)
            % plot(angle_error_q);
            % hold on;

            % % 3-axis angle error
            angle_error_axis = []; % check whether globally aligned
            angle_error_axis_ref = [];

            roll_deg_ref_list = [];
            roll_deg_prop_list = [];

            pitch_deg_ref_list =[];
            pitch_deg_prop_list =[];

            yaw_deg_ref_list =[]; 
            yaw_deg_prop_list =[];


            % the 3-axis one did not start from address...
            %% check locally aligned, added '
            for i = 1:length(time)
                % R1 = R2Lw(:,:,i)';
                % R2 = Rinf(:,:,i)';  % example of the second rotation matrix
                
                % globally align
                R1 = R2Lw(:,:,i);
                R2 = Rinf(:,:,i);  % example of the second rotation matrix
                % 
                % difference between the two rotation matrices (relative rotation matrix)
                % R_diff = R1 * R2';
                R_diff = R2 * R1'; %how much the reference value must be rotated to get the estimate % the angle error can be interpreted directly in the world frame
        
                % convert R_diff to Euler angles (XYZ order)
                eul_angles = rotm2eul(R_diff, 'ZYX');
        
                % angle error about each axis (radians converted to degrees)imu_trajCalI
                roll_error_deg = rad2deg(eul_angles(3));   % x-axis (roll) error
                pitch_error_deg = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg = rad2deg(eul_angles(1));    % z-axis (yaw) error

                
                eul_angles_ref = rotm2eul(R1, 'ZYX');
                eul_angles_prop = rotm2eul(R2, 'ZYX');

                roll_deg_ref =rad2deg(eul_angles_ref(3));
                roll_deg_prop = rad2deg(eul_angles_prop(3));

                pitch_deg_ref =rad2deg(eul_angles_ref(2));
                pitch_deg_prop = rad2deg(eul_angles_prop(2));

                yaw_deg_ref =rad2deg(eul_angles_ref(1));  
                yaw_deg_prop = rad2deg(eul_angles_prop(1)); 

                roll_deg_ref_list = [roll_deg_ref_list roll_deg_ref];
                roll_deg_prop_list = [roll_deg_prop_list roll_deg_prop ];
    
                pitch_deg_ref_list =[pitch_deg_ref_list pitch_deg_ref ];
                pitch_deg_prop_list =[pitch_deg_prop_list pitch_deg_prop ];
    
                yaw_deg_ref_list =[yaw_deg_ref_list yaw_deg_ref ]; 
                yaw_deg_prop_list =[yaw_deg_prop_list yaw_deg_prop ];



                %% additional code for the reference
                R1 = R2Lw(:,:,i);
                R2 = Rinf_ref(:,:,i);  % example of the second rotation matrix
                % 
                % difference between the two rotation matrices (relative rotation matrix)
                R_diff = R2 * R1'; %how much the reference value must be rotated to get the estimate % the angle error can be interpreted directly in the world frame
                % R_diff = R1 * R2';

                % convert R_diff to Euler angles (XYZ order)
                eul_angles = rotm2eul(R_diff, 'ZYX');

                % angle error about each axis (radians converted to degrees)
                roll_error_deg_ref = rad2deg(eul_angles(3));   % x-axis (roll) error
                pitch_error_deg_ref = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg_ref = rad2deg(eul_angles(1));    % z-axis (yaw) error

        
                % store the error angle about each axis in an array
                % for the numbers
                % angle_error_axis = [angle_error_axis; abs(roll_error_deg), abs(pitch_error_deg), abs(yaw_error_deg)];
                % for plotting
                angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];

                angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];

            end

            % 
            % figure(3025)
            % hold on;
            % plot(roll_deg_ref_list);
            % plot(roll_deg_prop_list);
            % 
            % figure(3026)
            % hold on;
            % plot(pitch_deg_ref_list);
            % plot(pitch_deg_prop_list);
            % 
            % figure(3027)
            % hold on;
            % plot(yaw_deg_ref_list);
            % plot(yaw_deg_prop_list);
            % 


            roll_angle_ref_list_all(:,:,z) = roll_deg_ref_list;
            pitch_angle_ref_list_all(:,:,z) = pitch_deg_ref_list;
            yaw_angle_ref_list_all(:,:,z) = yaw_deg_ref_list;

            roll_angle_prop_list_all(:,:,z) = roll_deg_prop_list;
            pitch_angle_prop_list_all(:,:,z) = pitch_deg_prop_list;
            yaw_angle_prop_list_all(:,:,z) = yaw_deg_prop_list;


       
            angle_error_axis_list(:,:,z) = angle_error_axis;
            angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;

            
            plot_ds_ref(:,:,z) = Mtraj;
            plot_ds_prop(:,:,z) = apdm_trajCalV;
            plot_ds_driver(:,:,z) = traj_lin_subj;
            plot_ds_driver2(:,:,z) = traj_lin_subj2;   % trajectory based on mldataDir2
            plot_ds_ag(:,:,z) = apdm_agcal;
            % plot_ds_imu(:,:,z) = imu_trajCal;

            if club==3
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial, subj};
            elseif subj==8 && club==1 && (trial<21)
                ml_traj_check= ml_traj_est.(clubs_ml{club}){3, subj};
            elseif club==1 && (trial<11)
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial, subj};
            elseif club==1 && (trial<21 && trial>10)
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial-10, subj};
            elseif club ==1 && (trial>20)
                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial-20, subj};
            end



            error_bet_ml_cam =abs(traj_lin_subj(g.imp,:)-(imp_est-add_est));
            error_bet_ml_cam_list = [error_bet_ml_cam_list; error_bet_ml_cam];




             % % % % 3D visualization plot of the predicted data
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
            % % plot3(imu_traj(1:g.fin,1), imu_traj(1:g.fin,2), imu_traj(1:g.fin,3),'b','LineWidth', 1.5); %,'LineStyle', '--'); %[0.3 0.3 0.3]
            % 
            % plot3(ml_traj_check(:,1), ml_traj_check(:,2), ml_traj_check(:,3),'Color',dark_green,'LineWidth', 2);
            % plot3(traj_lin_subj(350:g.fin,1), traj_lin_subj(350:g.fin,2), traj_lin_subj(350:g.fin,3),'Color',dark_red,'LineWidth',2);
            % plot3(Mtraj(g.add:g.fin,1), Mtraj(g.add:g.fin,2), Mtraj(g.add:g.fin,3),'k','LineWidth', 2);
            % 
            % 
            % 
            % % mark a specific point (e.g. the 10th point) with a star
            % % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 15);
            % % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'bp', 'MarkerSize', 15);
            % % plot3(traj_lin_subj(g.imp,1), traj_lin_subj(g.imp,2), traj_lin_subj(g.imp,3), 'gp', 'MarkerSize', 15);
            % 
            % % % distinguish the edge and the face with different colors
            % % % the difference cannot possibly be this large
            % % plot3(Mtraj(g.imp,1), Mtraj(g.imp,2), Mtraj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow'); % specify edge color
            % % plot3(apdm_trajCalV(g.imp,1), apdm_trajCalV(g.imp,2), apdm_trajCalV(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
            % % plot3(imu_traj(g.imp,1), imu_traj(g.imp,2), imu_traj(g.imp,3), 'kp', 'MarkerSize', 20, 'MarkerFaceColor', 'yellow');
            % 
            % % add axis labels
            % xlabel('X-axis(mm)');
            % ylabel('Y-axis(mm)');
            % zlabel('Z-axis(mm)');
            % 
            % axis equal;
            % grid off;
            % % the view angle can be changed
            % % view(3);
            % % view(0, 0);
            % % view(0, 90);  % or view(2)
            % view(90, 0);
            % % % 
            % % % print(gcf, 'plot_traj_prop.svg', '-dsvg', '-vector');




            plot_ds_ml(:,:,z) = ml_traj_check;

            plot_ds_imu(:,:,z) = imu_traj;
            plot_imu_vel(:,:,z) = imu_vel ;
            plot_imu_acc(:,:,z) = ag_wo_g;

            plot_imu_acc_local(:,:,z) = acc_data;


            %trajectory visualization
            % figure(subj)
            % 
            % subplot(3, 1, 1);
            % hold on;
            % ylabel('X-axis');
            % % if ismember(trial, [21,25,28])
            % plot(Mtraj(421:710,1),'k','LineWidth', 1)
            % plot(ml_traj_check(:,1),'Color', dark_green,'LineWidth', 1)
            % plot(traj_lin_subj(421:710,1),'Color', dark_red,'LineWidth', 1)
            % % end
            % 
            % 
            % hold off;
            % 
            % subplot(3, 1, 2);
            % hold on;
            % plot(Mtraj(421:710,2),'k')
            % plot(traj_lin_subj(421:710,2),'Color', dark_red)
            % plot(ml_traj_check(:,2),'Color', dark_green)
            % ylabel('Y-axis');
            % hold off;
            % 
            % subplot(3, 1, 3);
            % hold on;
            % plot(Mtraj(421:710,3),'k')
            % plot(traj_lin_subj(421:710,3),'Color', dark_red)
            % plot(ml_traj_check(:,3),'Color', dark_green)
            % ylabel('Z-axis');
            % hold off;





            % mae error
            switch mae_method
                case 0
                    test_drift = imu_traj;
                case 1
                    test_drift = imu_trajCal; %wait, in 3D is this more accurate than apdm_trajCalV?
                case 2
                    test_drift = imu_trajCalL;
                case 3
                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
                case 4
                    test_drift = apdm_trajCalV; % traj_lin_subj, imu only  % apdm_trajCalV trial-by-trial correction
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
        
            %% Mtraj is the wrist % range definition
            
            % has to be changed every time when mae_method=6
            % start_traj = g.add;
            % % end_traj = g.fin;
            % % start_traj = 351;
            % 
            % % start_traj = 451;
            % end_traj = 800;
            % % end_traj = g.imp;
            % 
            % if mae_method==6
            %     error = Mtraj(start_traj:end_traj,:)-test_drift(:,:);
            % else
            %     error = Mtraj(start_traj:end_traj,:)-test_drift(start_traj:end_traj,:);
            % end
            % 
            % % error summary
            % Mae_XYZ = mean(abs(error));
            % % the mean (scalar) of the per-frame Euclidean error, widely used as the representative value
            % Mae_norm = mean(vecnorm(error,2,2));
            % rmse_xyz = sqrt(mean(error.^2, 1));
            % rmse_overall = sqrt(mean(sum(error.^2, 2)));
            % 
            % % compute mae
            % mae_list = [mae_list; Mae_XYZ];
            % mae_norm_list = [mae_norm_list; Mae_norm];
            % rmse_xyz_list = [rmse_xyz_list; rmse_xyz];
            % rmse_norm_list = [rmse_norm_list; rmse_overall];




            % 251219 newly written code
            %% ========== per-trial execution (inside the loop) ==========

            % actual data indices (Mtraj-based) - defined inside the loop since g may differ per trial
            points_real = struct();
            % points_real.add = g.add;
            points_real.add = 351;
            points_real.bst = g.bst;
            points_real.imp = g.imp;
            points_real.fin = 800;
            
            % indices for mae_method (test_drift-based)
            points_method = struct();
            points_method.add = 1;
            points_method.bst = 350 - (g.imp - g.bst);
            points_method.imp = 350;
            points_method.fin = 450;
            
            % ----- per-event-point error computation -----
            for p = 1:length(point_names)
                pn = point_names{p};
                
                idx_real = points_real.(pn);
                idx_method = points_method.(pn);
                
                if mae_method == 6
                    error_pt = Mtraj(idx_real, :) - test_drift(idx_method, :);
                else
                    error_pt = Mtraj(idx_real, :) - test_drift(idx_real, :);
                end
                
                results.points.(pn).error_xyz_list = [results.points.(pn).error_xyz_list; abs(error_pt)];
                results.points.(pn).error_norm_list = [results.points.(pn).error_norm_list; norm(error_pt)];
            end
            
            % ----- per-range error computation -----
            range_defs = {
                'add_to_bst', 'add', 'bst';
                'add_to_imp', 'add', 'imp';
                'add_to_fin', 'add', 'fin'
            };
            
            for r = 1:size(range_defs, 1)
                rn = range_defs{r, 1};
                start_name = range_defs{r, 2};
                end_name = range_defs{r, 3};
                
                start_real = points_real.(start_name);
                end_real = points_real.(end_name);
                start_method = points_method.(start_name);
                end_method = points_method.(end_name);
                
                if mae_method == 6
                    error_range = Mtraj(start_method+350:end_method+350, :) - test_drift(start_method:end_method, :);
                else
                    error_range = Mtraj(start_real:end_real, :) - test_drift(start_real:end_real, :);
                end
                
                % MAE
                mae_xyz = mean(abs(error_range), 1);
                mae_norm = mean(vecnorm(error_range, 2, 2));
                
                % RMSE
                rmse_xyz = sqrt(mean(error_range.^2, 1));
                rmse_norm = sqrt(mean(sum(error_range.^2, 2)));
                
                results.ranges.(rn).mae_xyz_list = [results.ranges.(rn).mae_xyz_list; mae_xyz];
                results.ranges.(rn).mae_norm_list = [results.ranges.(rn).mae_norm_list; mae_norm];
                results.ranges.(rn).rmse_xyz_list = [results.ranges.(rn).rmse_xyz_list; rmse_xyz];
                results.ranges.(rn).rmse_norm_list = [results.ranges.(rn).rmse_norm_list; rmse_norm];
            end




            %% how should the velocity comparison be done?
            error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
            error_vellist = [error_vellist; mean(abs(error_vel))];
            


            %for computing the mean over all trials
            z= z+1;

            % figure(subj)
            % hold on;
            % plot(ag_wo_g(:,1),'k')
            % xlim([350 800])
            % 
            % figure(subj+1)
            % hold on;
            % plot(ag_wo_g(:,2),'k')
            % xlim([350 800])
            % 
            % figure(subj+2)
            % hold on;
            % plot(ag_wo_g(:,3),'k')
            % xlim([350 800])
            % 
            % 
            % figure(subj+3)
            % hold on;
            % plot(imu_velCal(:,1),'r')
            % xlim([350 800])
            % 
            % figure(subj+4)
            % hold on;
            % plot(imu_velCal(:,2),'r')
            % xlim([350 800])
            % 
            % figure(subj+5)
            % hold on;
            % plot(imu_velCal(:,3),'r')
            % xlim([350 800])
            % 
            % 
            % figure(subj+6)
            % hold on;
            % plot(imu_trajCal(:,1),'b')
            % xlim([350 800])
            % 
            % figure(subj+7)
            % hold on;
            % plot(imu_trajCal(:,2),'b')
            % xlim([350 800])
            % 
            % figure(subj+8)
            % hold on;
            % plot(imu_trajCal(:,3),'b')
            % xlim([350 800])


            
            % % preparing for machine learning % build the set including the raw data and the reference values
            swingData_2508(subj).clubN(club).trialN(trial).apdm = [ag_wo_g w_dcm acc_data gyro_data];
            swingData_2508(subj).clubN(club).trialN(trial).rel = [rel_est ref_rel_imp rel_ag];
            swingData_2508(subj).clubN(club).trialN(trial).vel_integration = [imu_vel imu_velCal Mvel];
            swingData_2508(subj).clubN(club).trialN(trial).traj_integration = [imu_traj imu_trajCal imu_trajCalL apdm_trajCalV Mtraj apdm_agcal];
            % store agformer in the trajectory. store something else in rel. check the event points properly when running

        end
    end
    % disp(subj)
end

% %% length variability validation test
% % valid-sample mask
% v1 = isfinite(L_list) & isfinite(dL_mocap_list);
% v2 = isfinite(L_list) & isfinite(dL_vidimu_list);
% 
% x1 = L_list(v1).';      y1 = dL_mocap_list(v1).';
% x2 = L_list(v2).';      y2 = dL_vidimu_list(v2).';
% 
% % correlation coefficient (Pearson)
% [r1,p1] = corr(x1, y1, 'type','Pearson');
% [r2,p2] = corr(x2, y2, 'type','Pearson');
% 
% % linear regression line
% pfit1 = polyfit(x1, y1, 1);  yhat1 = polyval(pfit1, linspace(min(x1), max(x1), 100));
% pfit2 = polyfit(x2, y2, 1);  yhat2 = polyval(pfit2, linspace(min(x2), max(x2), 100));
% 
% % plot
% figure('Color','w','Position',[100 100 1400 520]); 
% tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
% 
% % (a) L vs L_delta (mocap-based variability)
% nexttile; hold on; grid on; box on;
% scatter(x1, y1, 36, 'b','filled','MarkerFaceAlpha',0.7); 
% xx = linspace(min(x1), max(x1), 100);
% plot(xx, polyval(pfit1, xx), 'b','LineWidth',1.5);
% xlabel('L (mm)'); ylabel('L_{\Delta} = \Delta L from MoCap (mm)');
% title(sprintf('L vs L_{\\Delta} (MoCap) | r=%.2f, p=%.3g, slope=%.3g', r1, p1, pfit1(1)));
% 
% % (b) L vs L_delta\_vid (Video+IMU variability)
% nexttile; hold on; grid on; box on;
% scatter(x2, y2, 36, [0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.7);
% xx = linspace(min(x2), max(x2), 100);
% plot(xx, polyval(pfit2, xx), 'Color',[0.85 0.33 0.10],'LineWidth',1.5);
% xlabel('L (mm)'); ylabel('L_{\Delta}^{vid+imu} (mm)');
% title(sprintf('L vs L_{\\Delta}^{vid+imu} | r=%.2f, p=%.3g, slope=%.3g', r2, p2, pfit2(1)));
% 
% sgtitle('Length vs. Radial Increment per Frame (dt=5 ms)','FontWeight','bold');
% 
% % (optional) also check it in table form
% T = table(L_list(:), dL_mocap_list(:), dL_vidimu_list(:), ...
%     'VariableNames', {'L','dL_mocap','dL_vidimu'});
% disp(head(T,10));





disp('motionag positon error(mm)')
add_ag_all_subj_mean = mean(add_pos_error_ag_list).*0.1
add_ag_all_subj_std = std(add_pos_error_ag_list).*0.1
imp_ag_all_subj_mean = mean(imp_pos_error_ag_list).*0.1
imp_ag_all_subj_std = std(imp_pos_error_ag_list).*0.1
imp_est_ag_all_subj = mean(imp_rel_pos_error_ag_list).*0.1;
imp_est_ag_all_subj_std = std(imp_rel_pos_error_ag_list).*0.1;

disp('motionag imp rel error mean& std')
disp(imp_est_ag_all_subj)
disp(imp_est_ag_all_subj_std)

add_prop_all_subj = mean(add_pos_error_prop_list);
add_prop_all_subj_std = std(add_pos_error_prop_list);
imp_prop_all_subj = mean(imp_pos_error_prop_list);
imp_prop_all_subj_std = std(imp_pos_error_prop_list);

disp('proposed add est error mean& std')
disp(add_prop_all_subj.*0.1)
disp(add_prop_all_subj_std.*0.1)
disp('proposed imp est error mean& std')
disp(imp_prop_all_subj.*0.1)
disp(imp_prop_all_subj_std.*0.1)

imp_est_prop_all_subj = mean(imp_rel_pos_error_prop_list);
imp_est_prop_all_subj_std = std(imp_rel_pos_error_prop_list);

disp('proposed imp rel error mean& std')
disp(imp_est_prop_all_subj.*0.1)
disp(imp_est_prop_all_subj_std.*0.1)


disp('angle error')
% errors for all trials of all participants can be checked
angle_error_allsubj = mean(angle_error_q_list)
angle_error_allsubj_std = std(angle_error_q_list)
angle_error_add_allsubj = mean(angle_error_add_list)
angle_error_add_allsubj_std = std(angle_error_add_list)

angle_error_bst_allsubj = mean(angle_error_bst_list)
angle_error_bst_allsubj_std = std(angle_error_bst_list)

angle_error_imp_allsubj = mean(angle_error_imp_list)
angle_error_imp_allsubj_std = std(angle_error_imp_list)

angle_error_fin_allsubj = mean(angle_error_fin_list)
angle_error_fin_allsubj_std = std(angle_error_fin_list)


angle_error_add2imp_all = mean(angle_error_add2imp)
angle_error_add2imp_all_std = std(angle_error_add2imp)


angle_error_add2bst_all = mean(angle_error_add2bst)
angle_error_add2bst_all_std = std(angle_error_add2bst)



%% 0204 error computation redone
%% ============================================================
% Subject-level mean±SD (across subjects) from 1x99 trial lists
% - First: compute subject mean across trials (within-subject)
% - Then: compute mean±SD across subjects (between-subject)
% - Also prints pooled trial-level mean±SD for comparison
%% ============================================================

trialCounts = [10 10 10 10 10 10 10 9 10 10];
nSub = numel(trialCounts);

% ---- unify the input vectors (1x99 or 99x1) to column vectors ----
imu_roll_error_list          = imu_roll_error_list(:);
imu_pitch_error_list         = imu_pitch_error_list(:);
imu_yaw_error_newmaglist     = imu_yaw_error_newmaglist(:);

angle_error_q_list           = angle_error_q_list(:);
angle_error_add_list         = angle_error_add_list(:);

angle_error_bst_list         = angle_error_bst_list(:);
angle_error_imp_list         = angle_error_imp_list(:);
angle_error_fin_list         = angle_error_fin_list(:);

% ---- length check (all must be equal) ----
N = numel(imu_roll_error_list);
allLens = [ numel(imu_pitch_error_list), numel(imu_yaw_error_newmaglist), ...
            numel(angle_error_q_list), numel(angle_error_add_list), ...
            numel(angle_error_bst_list), numel(angle_error_imp_list), numel(angle_error_fin_list) ];

if any(allLens ~= N)
    error('The input lists have different lengths. Reference N=%d, other lengths=%s', N, mat2str(allLens));
end
if sum(trialCounts) ~= N
    error('The sum of trialCounts (%d) differs from the data length (%d).', sum(trialCounts), N);
end

% ---- stack into an [N x M] matrix (each column is one metric) ----
D = [ imu_roll_error_list, ...
      imu_pitch_error_list, ...
      imu_yaw_error_newmaglist, ...
      angle_error_q_list, ...
      angle_error_add_list, ...
      angle_error_bst_list, ...
      angle_error_imp_list, ...
      angle_error_fin_list ];

metricNames = { ...
    'imu roll error', ...
    'imu pitch error', ...
    'imu yaw error (newmag)', ...
    'angle error (quat geodesic)', ...
    'angle error (add)', ...
    'angle error @ BST', ...
    'angle error @ IMP', ...
    'angle error @ FIN' };

nMetric = size(D,2);

% ---- per-participant mean/standard deviation (based on within-participant trials) ----
subjMean = nan(nSub, nMetric);
subjStd_within = nan(nSub, nMetric);   % for reference: within-subject trial SD

startIdx = 1;
for s = 1:nSub
    cnt = trialCounts(s);
    idx = startIdx:(startIdx + cnt - 1);

    subjMean(s,:) = mean(D(idx,:), 1, 'omitnan');
    subjStd_within(s,:) = std(D(idx,:), 0, 1, 'omitnan');

    startIdx = startIdx + cnt;
end

% ---- recommended for the table: subject-level(mean of subject means ± SD across subjects) ----
groupMean_subject = mean(subjMean, 1, 'omitnan');
groupSD_subject   = std(subjMean, 0, 1, 'omitnan');

% ---- for comparison: all samples (trial-level pooled) mean±SD ----
groupMean_trial = mean(D, 1, 'omitnan');
groupSD_trial   = std(D, 0, 1, 'omitnan');

% ---- output ----
fprintf('\n============================================================\n');
fprintf('Subject-level summary (table recommended)\n');
fprintf('  1) within each subject: mean across trials\n');
fprintf('  2) across subjects: mean ± SD (between-subject)\n');
fprintf('Also printing trial-level pooled mean ± SD for comparison.\n');
fprintf('============================================================\n');

for k = 1:nMetric
    fprintf('\n[%s]\n', metricNames{k});
    fprintf('  Trial-level pooled (N=%d):       %.4f ± %.4f\n', N, groupMean_trial(k), groupSD_trial(k));
    fprintf('  Subject-level (Nsub=%d):         %.4f ± %.4f\n', nSub, groupMean_subject(k), groupSD_subject(k));

    % note: summarize the within-subject SD across participants
    meanWithin = mean(subjStd_within(:,k), 'omitnan');
    sdWithin   = std(subjStd_within(:,k), 0, 'omitnan');
    fprintf('  (Ref) within-subject SD mean±SD: %.4f ± %.4f\n', meanWithin, sdWithin);
end

fprintf('\n============================================================\n');
fprintf('Done.\n');
fprintf('============================================================\n');





%% significance test between the two methods
% === build subj_id by adjusting the per-participant trial counts with bad_pairs ===
S = 10;          % number of participants
% T = 30;          % nominal number of trials
T = 10;          % nominal number of trials
N = size(imp_pos_error_prop_list, 1);   % number of rows currently remaining (e.g. 298)

% list of already removed (subj, trial) pairs
% bad_pairs = [
%     2 10
%     6  3
%     8 30
% ];

bad_pairs = [
    8 30
];

% compute the per-participant counts: start from 30 and subtract 1 for that subject
counts = T * ones(S,1);
for k = 1:size(bad_pairs,1)
    s = bad_pairs(k,1);
    counts(s) = counts(s) - 1;
end

% check that the total matches the actual N (if not, recheck bad_pairs)
assert(sum(counts) == N, 'The sum of counts (%d) differs from the number of data rows (%d).', sum(counts), N);

% participant ID vector (length N) — each subject repeated by its remaining trial count
subj_id = repelem((1:S)', counts);

% === compare_methods: paired test after averaging per participant ===
% A = imp_pos_error_prop_list;   % proposed
% B = imp_pos_error_ag_list;     % motionag

% A = add_pos_error_prop_list;   % proposed
% B = add_pos_error_ag_list;     % motionag
% 
% A = ml_est_list_stat;   % proposed
A = imp_rel_pos_error_prop_list;   % proposed
B = imp_rel_pos_error_ag_list;     % motionag


S1 = compare_methods( ...
        A, B, ...
        'Name','IMP abs error (mm)', ...
        'Tail','left', ...                 % hypothesis: proposed < motionag
        'Paired',true, ...
        'Group',subj_id, 'BySubject',true, ...
        'Metric','both', 'Test','auto');

% disp(S1.mag)   % p based on magnitude (norm), effect size, etc.
disp(S1.axis{1})   % p based on magnitude (norm), effect size, etc.
disp(S1.axis{2})   % p based on magnitude (norm), effect size, etc.
disp(S1.axis{3})   % p based on magnitude (norm), effect size, etc.

% === mixed model (LME): use all trials, participant random effect ===
mag_prop = sqrt(sum(A.^2,2));
mag_ag   = sqrt(sum(B.^2,2));

err_all = [mag_prop; mag_ag];
method  = [repmat("prop", numel(mag_prop),1);
           repmat("ag",   numel(mag_ag),  1)];
subj2   = [subj_id; subj_id];

tbl = table(err_all, categorical(method), subj2, ...
            'VariableNames',{'err','method','subj'});
lme = fitlme(tbl,'err ~ method + (1|subj)');
disp(anova(lme));
disp(lme.Coefficients);


% 
% error over the full swing
% % mean/standard deviation
% summary.mae_xyz_mean = mean(mae_list, 1);
% summary.mae_xyz_std  = std (mae_list, 0, 1);
% summary.rmse_xyz_mean= mean(rmse_xyz_list, 1);
% summary.rmse_xyz_std = std (rmse_xyz_list, 0, 1);
% 
% summary.mae_norm_mean  = mean(mae_norm_list);
% summary.mae_norm_std   = std (mae_norm_list);
% summary.rmse_norm_mean = mean(rmse_norm_list);
% summary.rmse_norm_std  = std (rmse_norm_list);
% 
% T = table( ...
%   summary.mae_xyz_mean', summary.mae_xyz_std', ...
%   summary.rmse_xyz_mean', summary.rmse_xyz_std', ...
%   'VariableNames', {'MAE_mean','MAE_std','RMSE_mean','RMSE_std'}, ...
%   'RowNames', {'X','Y','Z'});
% disp(T)
% 
% fprintf('MAE(norm) = %.2f ± %.2f mm\n', ...
%     summary.mae_norm_mean, summary.mae_norm_std);
% fprintf('RMSE(norm)= %.2f ± %.2f mm\n', ...
%     summary.rmse_norm_mean, summary.rmse_norm_std);


%% ========== statistics computation and output (after the loop) ==========

fprintf('\n========================================\n');
fprintf('Point-wise Error\n');
fprintf('========================================\n');

for p = 1:length(point_names)
    pn = point_names{p};
    
    error_xyz = results.points.(pn).error_xyz_list;
    error_norm = results.points.(pn).error_norm_list;
    
    summary.points.(pn).xyz_mean = mean(error_xyz, 1);
    summary.points.(pn).xyz_std = std(error_xyz, 0, 1);
    summary.points.(pn).norm_mean = mean(error_norm);
    summary.points.(pn).norm_std = std(error_norm);
    
    fprintf('\n--- %s ---\n', upper(pn));
    T_point = table( ...
        summary.points.(pn).xyz_mean', summary.points.(pn).xyz_std', ...
        'VariableNames', {'Error_mean', 'Error_std'}, ...
        'RowNames', {'X', 'Y', 'Z'});
    disp(T_point);
    fprintf('Norm Error = %.2f ± %.2f mm\n', ...
        summary.points.(pn).norm_mean, summary.points.(pn).norm_std);
end

fprintf('\n========================================\n');
fprintf('Range-wise Error\n');
fprintf('========================================\n');

for r = 1:length(range_names)
    rn = range_names{r};
    
    mae_xyz = results.ranges.(rn).mae_xyz_list;
    mae_norm = results.ranges.(rn).mae_norm_list;
    rmse_xyz = results.ranges.(rn).rmse_xyz_list;
    rmse_norm = results.ranges.(rn).rmse_norm_list;
    
    summary.ranges.(rn).mae_xyz_mean = mean(mae_xyz, 1);
    summary.ranges.(rn).mae_xyz_std = std(mae_xyz, 0, 1);
    summary.ranges.(rn).rmse_xyz_mean = mean(rmse_xyz, 1);
    summary.ranges.(rn).rmse_xyz_std = std(rmse_xyz, 0, 1);
    summary.ranges.(rn).mae_norm_mean = mean(mae_norm);
    summary.ranges.(rn).mae_norm_std = std(mae_norm);
    summary.ranges.(rn).rmse_norm_mean = mean(rmse_norm);
    summary.ranges.(rn).rmse_norm_std = std(rmse_norm);
    
    fprintf('\n--- %s ---\n', upper(strrep(rn, '_', ' ')));
    T_range = table( ...
        summary.ranges.(rn).mae_xyz_mean', summary.ranges.(rn).mae_xyz_std', ...
        summary.ranges.(rn).rmse_xyz_mean', summary.ranges.(rn).rmse_xyz_std', ...
        'VariableNames', {'MAE_mean', 'MAE_std', 'RMSE_mean', 'RMSE_std'}, ...
        'RowNames', {'X', 'Y', 'Z'});
    disp(T_range);
    fprintf('MAE(norm)  = %.2f ± %.2f mm\n', ...
        summary.ranges.(rn).mae_norm_mean, summary.ranges.(rn).mae_norm_std);
    fprintf('RMSE(norm) = %.2f ± %.2f mm\n', ...
        summary.ranges.(rn).rmse_norm_mean, summary.ranges.(rn).rmse_norm_std);
end

%% overall summary table
fprintf('\n========================================\n');
fprintf('Overall Summary\n');
fprintf('========================================\n');

% per-event-point summary
fprintf('\n[Point-wise Norm Error]\n');
point_summary_data = zeros(length(point_names), 2);
for p = 1:length(point_names)
    pn = point_names{p};
    point_summary_data(p, :) = [summary.points.(pn).norm_mean, summary.points.(pn).norm_std];
end
T_points_summary = table( ...
    point_summary_data(:,1), point_summary_data(:,2), ...
    'VariableNames', {'Error_mean', 'Error_std'}, ...
    'RowNames', point_names);
disp(T_points_summary);

% per-range summary
fprintf('\n[Range-wise MAE/RMSE (Norm)]\n');
range_summary_data = zeros(length(range_names), 4);
for r = 1:length(range_names)
    rn = range_names{r};
    range_summary_data(r, :) = [...
        summary.ranges.(rn).mae_norm_mean, summary.ranges.(rn).mae_norm_std, ...
        summary.ranges.(rn).rmse_norm_mean, summary.ranges.(rn).rmse_norm_std];
end
T_ranges_summary = table( ...
    range_summary_data(:,1), range_summary_data(:,2), ...
    range_summary_data(:,3), range_summary_data(:,4), ...
    'VariableNames', {'MAE_mean', 'MAE_std', 'RMSE_mean', 'RMSE_std'}, ...
    'RowNames', {'add→bst', 'add→imp', 'add→fin'});
disp(T_ranges_summary);







%% data preparation (squeeze to 900x300)
roll_ref = squeeze(roll_angle_ref_list_all);    % 900x300
pitch_ref = squeeze(pitch_angle_ref_list_all);
yaw_ref = squeeze(yaw_angle_ref_list_all);

roll_prop = squeeze(roll_angle_prop_list_all);  % 900x300
pitch_prop = squeeze(pitch_angle_prop_list_all);
yaw_prop = squeeze(yaw_angle_prop_list_all);

%% compute the mean and standard deviation (over 300 samples)
roll_ref_mean = mean(roll_ref, 2);    roll_ref_std = std(roll_ref, 0, 2);
pitch_ref_mean = mean(pitch_ref, 2);  pitch_ref_std = std(pitch_ref, 0, 2);
yaw_ref_mean = mean(yaw_ref, 2);      yaw_ref_std = std(yaw_ref, 0, 2);

roll_prop_mean = mean(roll_prop, 2);    roll_prop_std = std(roll_prop, 0, 2);
pitch_prop_mean = mean(pitch_prop, 2);  pitch_prop_std = std(pitch_prop, 0, 2);
yaw_prop_mean = mean(yaw_prop, 2);      yaw_prop_std = std(yaw_prop, 0, 2);

%% time axis
t = 1:900;

%% plot
% figure(70000);
% 
% % Roll
% subplot(3, 1, 1);
% hold on;
% % ref (black)
% fill([t, fliplr(t)], [roll_ref_mean + roll_ref_std; flipud(roll_ref_mean - roll_ref_std)]', ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, roll_ref_mean, 'k', 'LineWidth', 1.5);
% % prop (dark_red)
% fill([t, fliplr(t)], [roll_prop_mean + roll_prop_std; flipud(roll_prop_mean - roll_prop_std)]', ...
%     dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, roll_prop_mean, 'Color', dark_red, 'LineWidth', 1.5);
% ylabel('Roll deg');
% xlim([350 800])
% hold off;
% 
% % Pitch
% subplot(3, 1, 2);
% hold on;
% % ref (black)
% fill([t, fliplr(t)], [pitch_ref_mean + pitch_ref_std; flipud(pitch_ref_mean - pitch_ref_std)]', ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, pitch_ref_mean, 'k', 'LineWidth', 1.5);
% % prop (dark_red)
% fill([t, fliplr(t)], [pitch_prop_mean + pitch_prop_std; flipud(pitch_prop_mean - pitch_prop_std)]', ...
%     dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, pitch_prop_mean, 'Color', dark_red, 'LineWidth', 1.5);
% ylabel('Pitch deg');
% xlim([350 800])
% hold off;
% 
% % Yaw
% subplot(3, 1, 3);
% hold on;
% % ref (black)
% fill([t, fliplr(t)], [yaw_ref_mean + yaw_ref_std; flipud(yaw_ref_mean - yaw_ref_std)]', ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, yaw_ref_mean, 'k', 'LineWidth', 1.5);
% % prop (dark_red)
% fill([t, fliplr(t)], [yaw_prop_mean + yaw_prop_std; flipud(yaw_prop_mean - yaw_prop_std)]', ...
%     dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% plot(t, yaw_prop_mean, 'Color', dark_red, 'LineWidth', 1.5);
% ylabel('Yaw deg');
% xlabel('Time Step');
% xlim([350 800])
% hold off;





% check the 3-axis error trend
%% compute the mean and standard deviation at each time point
mean_xyz = mean(angle_error_axis_list, 3);  % mean over the 3rd dimension (number of samples) (900x3)
std_xyz = std(angle_error_axis_list, 0, 3); % standard deviation over the 3rd dimension (number of samples) (900x3)

mean_xyz_ref = mean(angle_error_axis_list_ref, 3);  % mean over the 3rd dimension (number of samples) (900x3)
std_xyz_ref = std(angle_error_axis_list_ref, 0, 3); % standard deviation over the 3rd dimension (number of samples) (900x3)



disp('3-axis mean angle')
%% to use this as a result, abs should be applied above. to view it as a graph, abs should not have been applied above.
%% the current problem is that it was a mean of 10, not 120. let's fix the code together
disp(mean(mean_xyz))  
disp('3-axis std')
disp(std(mean_xyz))

disp('report')
disp(mean(add_acc_list))
% 
%for graph
time = 1:900;

% plot the graph
figure(200);
hold on;
grid on;

% visualize the mean and standard deviation of angle_error_xyz1
% X axis (first column)
fill([time, fliplr(time)], [mean_xyz(:,1)' + std_xyz(:,1)', fliplr(mean_xyz(:,1)' - std_xyz(:,1)')], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,1), 'r', 'LineWidth', 1.5);  % mean line

% Y axis (second column)
fill([time, fliplr(time)], [mean_xyz(:,2)' + std_xyz(:,2)', fliplr(mean_xyz(:,2)' - std_xyz(:,2)')], 'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,2), 'g', 'LineWidth', 1.5);  % mean line

% Z axis (third column)
fill([time, fliplr(time)], [mean_xyz(:,3)' + std_xyz(:,3)', fliplr(mean_xyz(:,3)' - std_xyz(:,3)')], 'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,3), 'b', 'LineWidth', 1.5);  % mean line
legend('X dev', 'X mean', 'Y dev', 'Y mean', 'Z dev', 'Z mean');
ylabel('Angle error (deg)');
title('3-axis error');
grid on;
xline([g.imp],'-',{'IMP'},'HandleVisibility','off');
xlim([350 850])
ylim([-60 20])


% figure(300) looks like a duplicate, remove it
% % 
% t = time(:)';                     % ensure a row vector
% M = mean_xyz;                     % [N×3] (X,Y,Z)
% S = std_xyz;                      % [N×3]
% 
% cols = [179 0 25;   % X: crimson
%         214 69 43;  % Y: vermilion
%         142 42 78]/255; % Z: mulberry
% 
% alphaFill = 0.18;   % confidence band transparency
% lw = 1.6;           % line width
% axisLabel = {'X','Y','Z'};
% 
% 
% figure(300); clf; set(gcf,'Color','w');
% ax = gobjects(3,1);
% 
% for i = 1:3
%     ax(i) = subplot(3,1,i); hold(ax(i),'on'); grid(ax(i),'on');
% 
%     m = M(:,i)';  s = S(:,i)';  c = cols(i,:);
% 
%     fill(ax(i), [t fliplr(t)], [m+s fliplr(m-s)], c, ...
%         'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
% 
%     plot(ax(i), t, m, '-', 'Color', c, 'LineWidth', lw);
% 
%     xline(ax(i), g.imp, '-', 'IMP', 'HandleVisibility','off');
% 
%     xlim(ax(i), [350 850]);
%     ylim(ax(i), [-60 20]);
% 
%     ylabel(ax(i), sprintf('%s (deg)', axisLabel{i}));
%     if i==1, title(ax(i), '3-axis error (±1 SD shaded)'); end
% end
% 
% xlabel(ax(3), 'Time (samples)');
% linkaxes(ax,'x');
% sgtitle('Angle Error per Axis');
% 
% h1 = plot(ax(1), nan, nan, '-', 'Color', cols(1,:), 'LineWidth', lw, 'DisplayName','X mean');
% h2 = plot(ax(1), nan, nan, '-', 'Color', cols(2,:), 'LineWidth', lw, 'DisplayName','Y mean');
% h3 = plot(ax(1), nan, nan, '-', 'Color', cols(3,:), 'LineWidth', lw, 'DisplayName','Z mean');
% % legend(ax(1), [h1 h2 h3], 'Location','best', 'Box','off');
% 
% set(ax, 'FontName','Malgun Gothic');  % Korean font (Windows)


%% works up to here

% ====== setup ======
t = time(:)';          % ensure a row vector
M = mean_xyz;          % [N x 3] proposed method mean
S = std_xyz;           % [N x 3] proposed method std
MR = mean_xyz_ref;     % [N x 3] reference value mean
SR = std_xyz_ref;      % [N x 3] reference value std

% size validation (to prevent problems)
assert(size(M,1)==numel(t) && size(M,2)==3, 'mean_xyz size needs checking');
assert(isequal(size(S), size(M)), 'std_xyz size needs checking');
assert(isequal(size(MR), size(M)) && isequal(size(SR), size(S)), 'ref size mismatch');

% color/style
col_prop = [179 0 25]/255;     % proposed method: red (same for all axes)
col_ref_line = [0 0 0];        % reference value line: black
col_ref_fill = 0.70*[1 1 1];   % reference value shading: gray

alpha_prop = 0.18;             % proposed method shading
alpha_ref  = 0.16;             % reference value shading (a bit lighter)
lw = 1.6;
axisLabel = {'X','Y','Z'};

% ====== figure ======
figure(400); clf; set(gcf,'Color','w'); % no idea why, but it draws properly if fig 200 is opened first
ax = gobjects(3,1);

for i = 1:3
    ax(i) = subplot(3,1,i); hold(ax(i),'on'); grid(ax(i),'on');

    % extract the data (row vector)
    m  = M(:,i)';   s  = S(:,i)';
    mr = MR(:,i)';  sr = SR(:,i)';

    % ---- reference value (black line + gray shading) first ----
    fill(ax(i), [t fliplr(t)], [mr+sr  fliplr(mr-sr)], col_ref_fill, ...
        'FaceAlpha', alpha_ref, 'EdgeColor','none', 'HandleVisibility','off');
    pRef = plot(ax(i), t, mr, '-', 'Color', col_ref_line, 'LineWidth', lw, ...
        'DisplayName','Reference mean');

    % ---- proposed method (red line + red shading) ----
    fill(ax(i), [t fliplr(t)], [m+s  fliplr(m-s)], col_prop, ...
        'FaceAlpha', alpha_prop, 'EdgeColor','none', 'HandleVisibility','off');
    pProp = plot(ax(i), t, m, '-', 'Color', col_prop, 'LineWidth', lw, ...
        'DisplayName','Proposed mean');

    % impact vertical line (excluded from the legend)
    if exist('g','var') && isfield(g,'imp')
        xline(ax(i), g.imp, '-', 'IMP', 'HandleVisibility','off');
    end

    xlim(ax(i), [350 850]);
    % ylim(ax(i), [-60 20]);  % restore if needed
    ylabel(ax(i), sprintf('%s (°)', axisLabel{i}));

end

linkaxes(ax,'x');
sgtitle('Angle Error per Axis');
set(ax, 'FontName','Malgun Gothic');  % Korean font (Windows)




% convert to cm
plot_ds_ref = plot_ds_ref.*0.1;
plot_ds_prop = plot_ds_prop.*0.1;
plot_ds_imu = plot_ds_imu.*0.1;
plot_ds_driver = plot_ds_driver.*0.1;
plot_ds_driver2 = plot_ds_driver2.*0.1;   % trajectory based on mldataDir2
plot_ds_ag = plot_ds_ag.*0.1;

plot_ds_ml = plot_ds_ml.*0.1;

% subj_ds_imu = subj_ds_imu.*0.1;
% subj_local_imu = subj_local_imu.*0.1;


% % assess the variability per dataset
% S_ref = cvabs_between_ts_timeAxesTrials(plot_ds_ref(630:701,:,:)); 
% S_imu = cvabs_between_ts_timeAxesTrials(plot_ds_imu(630:701,:,:)); 
% S_local = cvabs_between_ts_timeAxesTrials(subj_local_imu(630:701,:,:)); 



%% cumulative error graph
%% ===== setup: check the data size/time axis =====
% expected shape: [T x 3 x Ntrial] = [900 x 3 x 120]
T = size(plot_ds_ref,1);
if ~exist('time','var') || numel(time)~=T
    time = 1:T;                      % define as 1:T if there is no time axis
end
time = time(:)';                     % unify to a row vector

%% ===== color definitions =====
% col_prop   = [1.00 0.00 0.00];       % prop: red
col_prop   = [1 0 0];
col_driver = [0 0 1];      % driver: pink (specified value)
col_imu    = [0.7 0.7 0.7];       % imu: dark gray
alphaFill  = 0.18;                   % shading transparency
lw         = 1.6;                    % line width

%% ===== 1) compute the 3D distance error over time (mean ± std) =====
% for each method: err(t,trial) = sqrt( sum_{axis=1..3} (ref - method).^2 )
% result shape: [T x Ntrial] -> compute the trial mean/standard deviation along the time axis

% prop
diff_prop = plot_ds_ref - plot_ds_prop;                 % [T x 3 x N]
err_prop_tt = sqrt(sum(diff_prop.^2, 2));               % [T x 1 x N]
err_prop_tt = squeeze(err_prop_tt);                     % [T x N]
m_prop = mean(err_prop_tt, 2)';                         % [1 x T]
s_prop = std (err_prop_tt, 0, 2)';                      % [1 x T]

% driver
diff_driver = plot_ds_ref - plot_ds_driver;             % [T x 3 x N]
err_driver_tt = sqrt(sum(diff_driver.^2, 2));           % [T x 1 x N]
err_driver_tt = squeeze(err_driver_tt);                 % [T x N]
m_driver = mean(err_driver_tt, 2)';                     % [1 x T]
s_driver = std (err_driver_tt, 0, 2)';                  % [1 x T]

% imu
diff_imu = plot_ds_ref - plot_ds_imu;                   % [T x 3 x N]
err_imu_tt = sqrt(sum(diff_imu.^2, 2));                 % [T x 1 x N]
err_imu_tt = squeeze(err_imu_tt);                       % [T x N]
m_imu = mean(err_imu_tt, 2)';                           % [1 x T]
s_imu = std (err_imu_tt, 0, 2)';                        % [1 x T]

%% ===== Figure 1: 3D distance error over time (mean ± std, shaded) =====
figure(2025); clf; hold on; grid on; set(gcf,'Color','w');

% prop (red)
% fill([time fliplr(time)], [m_prop+s_prop fliplr(m_prop-s_prop)], ...
%      col_prop, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
p1 = plot(time, m_prop, '-', 'Color', dark_red, 'LineWidth', lw, 'DisplayName','prop');

% driver (pink)
% fill([time fliplr(time)], [m_driver+s_driver fliplr(m_driver-s_driver)], ...
%      col_driver, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
p2 = plot(time, m_driver, '-', 'Color', dark_green, 'LineWidth', lw, 'DisplayName','driver');

% imu (dark gray)
% fill([time fliplr(time)], [m_imu+s_imu fliplr(m_imu-s_imu)], ...
%      col_imu, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
p3 = plot(time, m_imu, '-', 'Color', col_imu, 'LineWidth', lw, 'DisplayName','imu');

% legend([p1 p2 p3], 'Location','best', 'Box','off');
% xlabel('Time (samples)');
% ylabel('3D distance error');
% title('Time-wise 3D Distance Error vs. Reference (mean \pm SD)');
set(gca,'FontName','Malgun Gothic');

% (optional) mark the impact event point
if exist('g','var') && isfield(g,'imp')
    xline(g.imp,'-','IMP','HandleVisibility','off');
end
xlim([300 800])

% %% ===== 2) compute and plot the cumulative error =====
% % first build the per-trial cumulative sum, then plot its trial mean/standard deviation
% cum_prop_tt   = cumsum(err_prop_tt,   1);   % [T x N]
% cum_driver_tt = cumsum(err_driver_tt, 1);   % [T x N]
% cum_imu_tt    = cumsum(err_imu_tt,    1);   % [T x N]
% 
% m_cprop = mean(cum_prop_tt,   2)';          % [1 x T]
% s_cprop = std (cum_prop_tt,   0, 2)';       % [1 x T]
% m_cdrv  = mean(cum_driver_tt, 2)';          % [1 x T]
% s_cdrv  = std (cum_driver_tt, 0, 2)';       % [1 x T]
% m_cimu  = mean(cum_imu_tt,    2)';          % [1 x T]
% s_cimu  = std (cum_imu_tt,    0, 2)';       % [1 x T]
% 
% figure(2026); clf; hold on; grid on; set(gcf,'Color','w');
% 
% % prop cumulative
% fill([time fliplr(time)], [m_cprop+s_cprop fliplr(m_cprop-s_cprop)], ...
%      col_prop, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
% q1 = plot(time, m_cprop, '-', 'Color', col_prop, 'LineWidth', lw, 'DisplayName','prop');
% 
% % driver cumulative
% fill([time fliplr(time)], [m_cdrv+s_cdrv fliplr(m_cdrv-s_cdrv)], ...
%      col_driver, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
% q2 = plot(time, m_cdrv, '-', 'Color', col_driver, 'LineWidth', lw, 'DisplayName','driver');
% 
% % imu cumulative
% fill([time fliplr(time)], [m_cimu+s_cimu fliplr(m_cimu-s_cimu)], ...
%      col_imu, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
% q3 = plot(time, m_cimu, '-', 'Color', col_imu, 'LineWidth', lw, 'DisplayName','imu');
% 
% legend([q1 q2 q3], 'Location','best', 'Box','off');
% xlabel('Time (samples)');
% ylabel('Cumulative 3D distance error');
% title('Cumulative 3D Distance Error (trial-wise cumsum, then mean \pm SD)');
% set(gca,'FontName','Malgun Gothic');
% 
% % (optional) mark the impact event point
% if exist('g','var') && isfield(g,'imp')
%     xline(g.imp,'-','IMP','HandleVisibility','off');
% end
% xlim([time(1) time(end)]);




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

% color/style
col_prop     = [1 0 0];          % proposed method: red
col_ref_line = [0 0 0];          % reference value line: black
col_ref_fill = 0.70*[1 1 1];     % reference value shading: gray
alpha_prop   = 0.18;             % shading transparency (proposed method)
alpha_ref    = 0.16;             % shading transparency (reference value)
lw = 1.6;

%% ===== 1) over time (mean±SD) =====
m_prop = mean(angle_error_plot,     2)';   % [1×T]
s_prop = std (angle_error_plot, 0,  2)';   % [1×T]
m_ref  = mean(angle_error_plot_ref, 2)';   % [1×T]
s_ref  = std (angle_error_plot_ref, 0,  2)';

figure(401); clf; hold on; grid on; set(gcf,'Color','w');

% reference shading → proposed shading → reference line → proposed line (best readability)
fill([t fliplr(t)], [m_ref+s_ref  fliplr(m_ref-s_ref)], col_ref_fill, ...
     'FaceAlpha', alpha_ref, 'EdgeColor','none', 'HandleVisibility','off');
pRef  = plot(t, m_ref,  '-', 'Color', col_ref_line, 'LineWidth', lw, 'DisplayName','Reference');

fill([t fliplr(t)], [m_prop+s_prop fliplr(m_prop-s_prop)], col_prop, ...
     'FaceAlpha', alpha_prop, 'EdgeColor','none', 'HandleVisibility','off');
pProp = plot(t, m_prop, '-', 'Color', col_prop,     'LineWidth', lw, 'DisplayName','Proposed');

if exist('g','var') && isfield(g,'imp'), xline(g.imp,'-','IMP','HandleVisibility','off'); end
xlabel('Time (samples)'); ylabel('Angle error (deg)');
% title('Time-wise angle error (mean \pm SD)');
% legend([pRef pProp], 'Location','best', 'Box','off');
% xlim([t(1) t(end)]);
xlim([350 850])
set(gca,'FontName','Malgun Gothic');

% %% ===== 2) cumulative error (cumsum) mean±SD =====
% % per-trial cumulative sum → trial mean/standard deviation
% cum_prop = cumsum(angle_error_plot,     1);   % [T×N]
% cum_ref  = cumsum(angle_error_plot_ref, 1);   % [T×N]
% 
% m_cprop = mean(cum_prop, 2)';   s_cprop = std(cum_prop, 0, 2)';
% m_cref  = mean(cum_ref,  2)';   s_cref  = std(cum_ref,  0, 2)';
% 
% figure(402); clf; hold on; grid on; set(gcf,'Color','w');
% 
% fill([t fliplr(t)], [m_cref+s_cref  fliplr(m_cref-s_cref)], col_ref_fill, ...
%      'FaceAlpha', alpha_ref, 'EdgeColor','none', 'HandleVisibility','off');
% qRef  = plot(t, m_cref,  '-', 'Color', col_ref_line, 'LineWidth', lw, 'DisplayName','Reference (cum)');
% 
% fill([t fliplr(t)], [m_cprop+s_cprop fliplr(m_cprop-s_cprop)], col_prop, ...
%      'FaceAlpha', alpha_prop, 'EdgeColor','none', 'HandleVisibility','off');
% qProp = plot(t, m_cprop, '-', 'Color', col_prop,     'LineWidth', lw, 'DisplayName','Proposed (cum)');
% 
% if exist('g','var') && isfield(g,'imp'), xline(g.imp,'-','IMP','HandleVisibility','off'); end
% % xlabel('Time (samples)'); ylabel('Cumulative angle error (deg·samples)');
% % title('Cumulative angle error (trial-wise cumsum; mean \pm SD)');
% % legend([qRef qProp], 'Location','best', 'Box','off');
% xlim([350 850]);
% set(gca,'FontName','Malgun Gothic');







% compute the mean and standard deviation per axis
ref_mean_x = mean(plot_ds_ref(:, 1, :), 3); % x-axis mean
ref_std_x = std(plot_ds_ref(:, 1, :), 0, 3); % x-axis standard deviation

ref_mean_y = mean(plot_ds_ref(:, 2, :), 3); % y-axis mean
ref_std_y = std(plot_ds_ref(:, 2, :), 0, 3); % y-axis standard deviation

ref_mean_z = mean(plot_ds_ref(:, 3, :), 3); % z-axis mean
ref_std_z = std(plot_ds_ref(:, 3, :), 0, 3); % z-axis standard deviation
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

driver_mean_y = mean(plot_ds_driver(:, 2, :), 3); % y-axis mean
driver_std_y = std(plot_ds_driver(:, 2, :), 0, 3); % y-axis standard deviation

driver_mean_z = mean(plot_ds_driver(:, 3, :), 3); % z-axis mean
driver_std_z = std(plot_ds_driver(:, 3, :), 0, 3); % z-axis standard deviation

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ml_mean_x = mean(plot_ds_ml(:, 1, :), 3); % x-axis mean
ml_std_x = std(plot_ds_ml(:, 1, :), 0, 3); % x-axis standard deviation

ml_mean_y = mean(plot_ds_ml(:, 2, :), 3); % y-axis mean
ml_std_y = std(plot_ds_ml(:, 2, :), 0, 3); % y-axis standard deviation

ml_mean_z = mean(plot_ds_ml(:, 3, :), 3); % z-axis mean
ml_std_z = std(plot_ds_ml(:, 3, :), 0, 3); % z-axis standard deviation





%% graph checking the +/- correlation relative to the mean % a single event point

% mode : 'mean', 'z', 'both'
% plot both the z-score and the deviation from the mean

% out3 = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, g.imp, ...
%                            'Mode','mean', 'PredName','Video','RefName','REF');

% out3 = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, g.imp, ...
%                            'Mode','z', 'PredName','video','RefName','REF');
% out3 = viz_mean_z_at_frame(plot_ds_ref, plot_ds_ag, g.imp, ...
%                            'Mode','z', 'PredName','ag','RefName','REF');
% 
% out3 = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, g.imp, ...
%                            'Mode','mean', 'PredName','video','RefName','REF');
% out3 = viz_mean_z_at_frame(plot_ds_ref, plot_ds_ag, g.imp, ...
%                            'Mode','mean', 'PredName','ag','RefName','REF');

% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_ag, frame_idx, subj_id, ...
%     'Mode','mean', 'PredName','ag','RefName','REF');
% 
% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_ag, frame_idx, subj_id, ...
%     'Mode','z', 'PredName','ag','RefName','REF');


%1220 version with specified colors
% out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, g.imp, ...
%     'Mode', 'z', ...
%     'PredName', 'Proposed', ...
%     'RefName', 'Ground Truth', ...
%     'Color', dark_red);
% 
% out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_ag, g.imp, ...
%     'Mode', 'z', ...
%     'PredName', 'MotionagFormer', ...
%     'RefName', 'Ground Truth', ...
%     'Color', [0.5 0.5 0.5]);
% 
% out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, g.imp, ...
%     'Mode', 'mean', ...
%     'PredName', 'Proposed', ...
%     'RefName', 'Ground Truth', ...
%     'Color', dark_red);
% 
% out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_ag, g.imp, ...
%     'Mode', 'mean', ...
%     'PredName', 'MotionagFormer', ...
%     'RefName', 'Ground Truth', ...
%     'Color', [0.5 0.5 0.5]);


out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'Proposed', ...
    'RefName', 'Ground Truth', ...
    'Color', dark_red);

out.abs

% out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_driver, imp_point_list, ...
%     'Mode', 'abs', ...
%     'PredName', 'ML', ...
%     'RefName', 'Ground Truth', ...
%     'Color', dark_red);
% out.abs

out = viz_mean_z_at_frame(plot_ds_prop, plot_ds_driver, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'ML', ...
    'RefName', 'Proposed', ...
    'Color', dark_red);
out.abs

% % ===== mldataDir vs mldataDir2 comparison (viz_mean_z_at_frame) =====
% fprintf('\n===== mldataDir (plot_ds_driver) =====\n');
out_drv1 = viz_mean_z_at_frame(plot_ds_prop, plot_ds_driver2, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'ML_model1', ...
    'RefName', 'Ground Truth', ...
    'Color', dark_green);
out_drv1.abs

disp('for judging statistical significance')
fprintf('\n===== mldataDir2 (plot_ds_driver2) =====\n');
out_drv2 = viz_mean_z_at_frame(plot_ds_driver, plot_ds_driver2, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'ML_model2', ...
    'RefName', 'ML_model1', ...
    'Color', dark_blue);
out_drv2.abs

disp('for judging statistical significance 2')
out = viz_mean_z_at_frame(plot_ds_prop, plot_ds_ag, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'ML', ...
    'RefName', 'Proposed', ...
    'Color', dark_red);
out.abs



% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_prop, imp_point_list, subj_id, ...
%     'Mode','abs', 'PredName','PROP','RefName','REF');
% out.abs
% 
% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_driver, imp_point_list, subj_id, ...
%     'Mode','abs', 'PredName','ml','RefName','REF');
% out.abs
% 
% out = viz_mean_z_at_frame_group(plot_ds_prop, plot_ds_driver, imp_point_list, subj_id, ...
%     'Mode','abs', 'PredName','ml','RefName','prop');
% out.abs



% 0304
%%%%%%%%%% path length %%%%%%%%%%%%%

disp('path length')

mean_path_full = mean(path_length_full_list, 'omitnan');
std_path_full  = std(path_length_full_list,  0, 'omitnan');

mean_path_down = mean(path_length_down_list, 'omitnan');
std_path_down  = std(path_length_down_list,  0, 'omitnan');

fprintf('\n===== Wrist 3D trajectory length (Path Length) =====\n');
fprintf('Full swing (add→fin): mean = %.2f,  SD = %.2f  [total trials = %d]\n', ...
        mean_path_full, std_path_full, numel(path_length_full_list));
fprintf('Downswing  (bst→imp): mean = %.2f,  SD = %.2f  [total trials = %d]\n', ...
        mean_path_down, std_path_down, numel(path_length_down_list));



% %% significance test between the two methods
% % === build subj_id by adjusting the per-participant trial counts with bad_pairs ===
% S = 10;          % number of participants
% T = 30;          % nominal number of trials
% N = size(imp_pos_error_prop_list, 1);   % number of rows currently remaining (e.g. 298)
% 
% % list of already removed (subj, trial) pairs
% bad_pairs = [
%     2 10
%     6  3
%     8 30
% ];
% 
% % compute the per-participant counts: start from 30 and subtract 1 for that subject
% counts = T * ones(S,1);
% for k = 1:size(bad_pairs,1)
%     s = bad_pairs(k,1);
%     counts(s) = counts(s) - 1;
% end
% 
% 
% % check that the total matches the actual N (if not, recheck bad_pairs)
% assert(sum(counts) == N, 'The sum of counts (%d) differs from the number of data rows (%d).', sum(counts), N);
% 
% % participant ID vector (length N) — each subject repeated by its remaining trial count
% subj_id = repelem((1:S)', counts);
% % 
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% % % % % per-participant data
% frame_idx = g.imp;  % impact frame
% num_subjects    = 10;
% trials_per_subj = 10 * ones(1, num_subjects);   % [10 10 10 ... 10]
% 
% % total number of trials
% N = size(plot_ds_ref, 3);
% assert(sum(trials_per_subj) == N, 'Does not match the number of trials.');
% % 
% % build Group: assign a subject ID to each trial
% Group = repelem(1:num_subjects, trials_per_subj).';   % (N x 1) vector
% % this is the same as the subj_id computed earlier

% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_prop, frame_idx, subj_id, ...
%     'Mode','mean', 'PredName','PROP','RefName','REF');
% 
% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_prop, frame_idx, subj_id, ...
%     'Mode','z', 'PredName','PROP','RefName','REF');

% 
% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_ag, frame_idx, subj_id, ...
%     'Mode','mean', 'PredName','ag','RefName','REF');
% 
% out = viz_mean_z_at_frame_group(plot_ds_ref, plot_ds_ag, frame_idx, subj_id, ...
%     'Mode','z', 'PredName','ag','RefName','REF');



% 
% out = viz_regress_ref_prop_per_subject(plot_ds_ref, plot_ds_prop, frame_idx, Group, ...
%     'RefName','REF', 'PredName','PROP');



% phase_windows = [ ...
%     300 650;   % backswing
%     650 750;  % downswing
%     750 800]; % near impact
% 
% phase_names = {'Backswing','Downswing+imp','followthrough'};

% multiple event points %function that checks whether the shapes are similar % and derives it as a range mean
% out = analyze_variability_and_pattern(plot_ds_ref, plot_ds_imu, phase_windows, ...
%           'PhaseNames', phase_names, ...
%           'FeatureType', 'mean', ...       % use the phase-range mean value as the feature
%           'WinLen', 50, 'Hop', 10, ...     % window-based temporal pattern r
%           'ZscorePerWindow', true, ...
%           'DoPlotWindow', true, ...
%           'DoPlotPhase', true, ...
%           'RefName', 'MoCap', ...
%           'PredName', 'IMU-pos');
% out_pos = viz_window_corr_trials(plot_ds_ref, plot_ds_imu, ...
%                 'WinLen', 50, 'Hop', 10, ...
%                 'ZscorePerWindow', true, ...
%                 'DoPlot', true, ...
%                 'RefName', 'MoCap', ...
%                 'PredName', 'IMU-pos');

% out_pos = viz_window_corr_trials(plot_ds_ref, plot_ds_imu, ...
%                 'WinLen', 50, 'Hop', 10, ...
%                 'ZscorePerWindow', true, ...
%                 'DoPlot', true, ...
%                 'RefName', 'MoCap', ...
%                 'PredName', 'IMU-pos');
% 
% % check the per-trial variability
% phase_windows = [300 650; 650 750; 750 800];
% phase_names   = {'Backswing','Downswing+imp','followthrough'};
% 
% out = trial_variability_corr(plot_ds_ref, plot_ds_imu, ...
%           'PhaseWindows', phase_windows, ...
%           'PhaseNames',   phase_names, ...
%           'SmoothLen',    11, ...
%           'DoPlotTime',   true, ...
%           'DoPlotPhase',  false);
% 
% out2 = trial_variability_corr(plot_ds_prop, plot_ds_imu, ...
%           'PhaseWindows', phase_windows, ...
%           'PhaseNames',   phase_names, ...
%           'SmoothLen',    11, ...
%           'DoPlotTime',   true, ...
%           'DoPlotPhase',  false);




% plot the graph (per axis)
figure(1000);
hold on;

% pink = [244 193 192] / 255;
pink = dark_red;

subplot(3, 1, 1);
hold on;
% fill([1:length(ref_mean_x), fliplr(1:length(ref_mean_x))], ...
%     [ref_mean_x + ref_std_x; flipud(ref_mean_x - ref_std_x)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% fill([1:length(proposed_mean_x), fliplr(1:length(proposed_mean_x))], ...
%     [proposed_mean_x + proposed_std_x; flipud(proposed_mean_x - proposed_std_x)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(ref_mean_x, 'k', 'LineWidth', 1.5); % reference value mean
plot(proposed_mean_x,'LineWidth',1.5,'Color', pink); % proposed method mean

% plot(proposed_mean_x,'b','LineWidth', 1.5); % proposed method mean

% set the Fill color to light gray
% fill([1:length(imu_mean_x), fliplr(1:length(imu_mean_x))], ...
%     [imu_mean_x + imu_std_x; flipud(imu_mean_x - imu_std_x)], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)

% set the Plot line color to dark gray
plot(imu_mean_x, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)


% fill([1:length(driver_mean_x), fliplr(1:length(driver_mean_x))], ...
%     [driver_mean_x + driver_std_x; flipud(driver_mean_x - driver_std_x)], ...
%     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(driver_mean_x, 'Color', dark_green, 'LineWidth', 1.5); % reference value mean


% title('Wrist Trajectory(cm)')
ylabel('X-axis');
% xlim([630 702]);
xlim([300 800])
% xlim([350 g.imp])
% ylim([-100 50])
% ylim([-222 100]);% maybe switch to subj3
hold off;

% y-axis graph
% figure(302);
% hold on;
subplot(3, 1, 2);
hold on;
% fill([1:length(ref_mean_y), fliplr(1:length(ref_mean_y))], ...
%     [ref_mean_y + ref_std_y; flipud(ref_mean_y - ref_std_y)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% fill([1:length(proposed_mean_y), fliplr(1:length(proposed_mean_y))], ...
%     [proposed_mean_y + proposed_std_y; flipud(proposed_mean_y - proposed_std_y)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(ref_mean_y, 'k', 'LineWidth', 1.5); % reference value mean
plot(proposed_mean_y, 'LineWidth', 1.5,'Color', pink); % proposed method mean
% plot(proposed_mean_y,'b', 'LineWidth', 1.5); % proposed method mean
% title('Y-axis');


% set the Fill color to light gray
% fill([1:length(imu_mean_y), fliplr(1:length(imu_mean_y))], ...
%     [imu_mean_y + imu_std_y; flipud(imu_mean_y - imu_std_y)], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)

% set the Plot line color to dark gray
plot(imu_mean_y, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)

% fill([1:length(driver_mean_y), fliplr(1:length(driver_mean_y))], ...
%     [driver_mean_y + driver_std_y; flipud(driver_mean_y - driver_std_y)], ...
%     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(driver_mean_y,'Color', dark_green, 'LineWidth', 1.5); % reference value mean


% xlim([630 702]);
xlim([300 800])
% xlim([350 g.imp])
% ylim([-300 100]);
ylabel('Y-axis');
% ylim([-100 100]); %subj3

hold off;

% z-axis graph
% figure(303);
% hold on;
subplot(3, 1, 3);
hold on;
% fill([1:length(ref_mean_z), fliplr(1:length(ref_mean_z))], ...
%     [ref_mean_z + ref_std_z; flipud(ref_mean_z - ref_std_z)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% fill([1:length(proposed_mean_z), fliplr(1:length(proposed_mean_z))], ...
%     [proposed_mean_z + proposed_std_z; flipud(proposed_mean_z - proposed_std_z)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(ref_mean_z, 'k', 'LineWidth', 1.5); % reference value mean
% plot(proposed_mean_z, 'r', 'LineWidth', 1.5); % proposed method mean
plot(proposed_mean_z,'LineWidth', 1.5,'Color',pink); % proposed method mean
% title('Z-axis');

% set the Fill color to light gray
% fill([1:length(imu_mean_z), fliplr(1:length(imu_mean_z))], ...
%     [imu_mean_z + imu_std_z; flipud(imu_mean_z - imu_std_z)], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)

% set the Plot line color to dark gray
plot(imu_mean_z, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%,'LineStyle', '--'); % dark gray (plot)
% 
% fill([1:length(driver_mean_z), fliplr(1:length(driver_mean_z))], ...
%     [driver_mean_z + driver_std_z; flipud(driver_mean_z - driver_std_z)], ...
%     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
plot(driver_mean_z, 'Color', dark_green, 'LineWidth', 1.5); % reference value mean

% xlim([630 702]);
xlim([300 800])
% xlim([350 g.imp])
% ylim([-150 150]);
ylabel('Z-axis');
% ylim([-100 100]); %subj3

% ylim([0 90]);
hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% comparison with the ML-derived trajectory
% plot the graph (per axis)
% figure(2027);
% hold on;
% 
% % pink = [244 193 192] / 255;
% pink = dark_red;
% 
% subplot(3, 1, 1);
% hold on;
% fill([1:length(ml_mean_x), fliplr(1:length(ml_mean_x))], ...
%     [ml_mean_x + ml_std_x; flipud(ml_mean_x - ml_std_x)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
% plot(ml_mean_x,'LineWidth',1.5,'Color', pink); % proposed method mean
% 
% ylabel('X-axis');
% % xlim([630 702]);
% % xlim([450 710])
% 
% hold off;
% 
% % y-axis graph
% subplot(3, 1, 2);
% hold on;
% fill([1:length(ml_mean_y), fliplr(1:length(ml_mean_y))], ...
%     [ml_mean_y + ml_std_y; flipud(ml_mean_y - ml_std_y)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
% 
% plot(ml_mean_y, 'LineWidth', 1.5,'Color', pink); % proposed method mean
% ylabel('Y-axis');
% 
% 
% hold off;
% 
% % z-axis graph
% subplot(3, 1, 3);
% hold on;
% fill([1:length(ml_mean_z), fliplr(1:length(ml_mean_z))], ...
%     [ml_mean_z + ml_std_z; flipud(ml_mean_z - ml_std_z)], ...
%     pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % purple shading (proposed method)
% plot(ml_mean_z,'LineWidth', 1.5,'Color',pink); % proposed method mean
% 
% 
% % xlim([450 710])
% ylabel('Z-axis');
% 
% hold off;

% start_idx = 421;
% % start_idx = 451;
% end_idx = 710;

start_idx = 351;
end_idx = 800;

figure(2028);
pink = dark_red;

% index setup
t_plot = 1:(end_idx - start_idx + 1);  % x axis starting from 1
range_ref = start_idx:end_idx;          % for data indexing
t_ml = 1:length(ml_mean_x);

% x-axis graph
subplot(3, 1, 1);
hold on;
% ref (black)
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_x(range_ref) + ref_std_x(range_ref); flipud(ref_mean_x(range_ref) - ref_std_x(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_x(range_ref), 'k', 'LineWidth', 1.5);
% driver (dark_green)
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_x(range_ref) + driver_std_x(range_ref); flipud(driver_mean_x(range_ref) - driver_std_x(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_x(range_ref), 'Color', pink, 'LineWidth', 1.5);
% ml (pink)
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_x + ml_std_x; flipud(ml_mean_x - ml_std_x)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_x, 'Color', dark_green, 'LineWidth', 1.5);

% 
% % set the Fill color to light gray
% fill([t_plot, fliplr(t_plot)], ...
%     [imu_mean_x(range_ref) + imu_std_x(range_ref); flipud(imu_mean_x(range_ref) - imu_std_x(range_ref))], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)
% 
% % set the Plot line color to dark gray
% plot(imu_mean_x(range_ref), 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)

xlim([1 450])

ylabel('X-axis');
hold off;

% y-axis graph
subplot(3, 1, 2);
hold on;
% ref (black)
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_y(range_ref) + ref_std_y(range_ref); flipud(ref_mean_y(range_ref) - ref_std_y(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_y(range_ref), 'k', 'LineWidth', 1.5);
% driver (dark_green)
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_y(range_ref) + driver_std_y(range_ref); flipud(driver_mean_y(range_ref) - driver_std_y(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_y(range_ref), 'Color', pink, 'LineWidth', 1.5);
% ml (pink)
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_y + ml_std_y; flipud(ml_mean_y - ml_std_y)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_y, 'Color', dark_green, 'LineWidth', 1.5);
% 
% % set the Fill color to light gray
% fill([t_plot, fliplr(t_plot)], ...
%     [imu_mean_y(range_ref) + imu_std_y(range_ref); flipud(imu_mean_y(range_ref) - imu_std_y(range_ref))], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)
% 
% % set the Plot line color to dark gray
% plot(imu_mean_y(range_ref), 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)
xlim([1 450])

ylabel('Y-axis');
hold off;

% z-axis graph
subplot(3, 1, 3);
hold on;
% ref (black)
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_z(range_ref) + ref_std_z(range_ref); flipud(ref_mean_z(range_ref) - ref_std_z(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_z(range_ref), 'k', 'LineWidth', 1.5);
% driver (dark_green)
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_z(range_ref) + driver_std_z(range_ref); flipud(driver_mean_z(range_ref) - driver_std_z(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_z(range_ref), 'Color', pink, 'LineWidth', 1.5);
% ml (pink)
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_z + ml_std_z; flipud(ml_mean_z - ml_std_z)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_z, 'Color', dark_green, 'LineWidth', 1.5);

% % set the Fill color to light gray
% fill([t_plot, fliplr(t_plot)], ...
%     [imu_mean_z(range_ref) + imu_std_z(range_ref); flipud(imu_mean_z(range_ref) - imu_std_z(range_ref))], ...
%     [0.8, 0.8, 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % light gray (fill)
% 
% % set the Plot line color to dark gray
% plot(t_plot,imu_mean_z(range_ref), 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%,'LineStyle', '--'); % dark gray (plot)

xlim([1 450])

ylabel('Z-axis');
hold off;

% figure(2028);
% hold on;
% 
% % pink = [244 193 192] / 255;
% pink = dark_red;
% 
% subplot(3, 1, 1);
% hold on;
% fill([1:length(ref_mean_x), fliplr(1:length(ref_mean_x))], ...
%     [ref_mean_x + ref_std_x; flipud(ref_mean_x - ref_std_x)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% plot(ref_mean_x, 'k', 'LineWidth', 1.5); % reference value mean
% 
% ylabel('X-axis');
% % xlim([630 702]);
% xlim([450 710])
% 
% hold off;
% 
% % y-axis graph
% subplot(3, 1, 2);
% hold on;
% fill([1:length(ref_mean_y), fliplr(1:length(ref_mean_y))], ...
%     [ref_mean_y + ref_std_y; flipud(ref_mean_y - ref_std_y)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% 
% plot(ref_mean_y, 'k', 'LineWidth', 1.5); % reference value mean
% xlim([450 710])
% ylabel('Y-axis');
% 
% 
% hold off;
% 
% % z-axis graph
% subplot(3, 1, 3);
% hold on;
% fill([1:length(ref_mean_z), fliplr(1:length(ref_mean_z))], ...
%     [ref_mean_z + ref_std_z; flipud(ref_mean_z - ref_std_z)], ...
%     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none'); % black shading (reference value)
% 
% plot(ref_mean_z, 'k', 'LineWidth', 1.5); % reference value mean
% 
% xlim([450 710])
% ylabel('Z-axis');
% 
% hold off;
% 
% 








































% % ellipse code for all participants and for each participant

% % color definitions (for 4 participants)
% colors = {[1 0 0],    % red
%           [0 0 1],    % blue
%           [0 1 0],    % green
%           [1 0.5 0]}; % orange
% 
% % color definitions (for 4 participants)
% colors = {[0.31 0.58 0.31],   % dark green (top)
%           [0.96 0.76 0.24],   % yellow/gold
%           [0.96 0.55 0.33],   % orange
%           [0.55 0.35 0.25]};  % brown (bottom)
% 


% ------------------------------------------------------------------------
% 0) prepare trial_subj_ids
%    trial_subj_ids(k) = which participant the k-th trial belongs to (1~num_subjects)
%    - if such a vector already exists, use it as is,
%    - otherwise, e.g. 10 for S1, 9 for S2, 10 for S3, ...
%      just build it to match the actual number of trials.
% ------------------------------------------------------------------------

% example) actual trial count of each participant (fill in to match)
% trials_per_subj = [5];   % length = num_subjects
trials_per_subj = [10 10 10 10 10 10 10 9 10 10];   % length = num_subjects
% trials_per_subj = [20 20 20 20 20 20 20 20 20 20];   % length = num_subjects
% num_subjects   = 1;
% trials_per_subj = [9 10];   % length = num_subjects
% trials_per_subj = [4 5];   % length = num_subjects
% trials_per_subj = [5 5 5 5 5 5 5 4 5 5];   % length = num_subjects
num_subjects   = 10;
Ntotal         = size(plot_ds_ref, 3);
% trials_per_subj = [20 20 20 20];   % length = num_subjects
% trials_per_subj = [10 10 10 10 10];   % length = num_subjects
% trials_per_subj = [30 30 30 30 30 30 30 30 30 29];   % length = num_subjects
assert(sum(trials_per_subj) == Ntotal, ...
       'The sum of trials_per_subj differs from the 3rd-dimension size of plot_ds_ref.');

trial_subj_ids = zeros(1, Ntotal);
idx = 1;
for s = 1:num_subjects
    n_tr = trials_per_subj(s);
    trial_subj_ids(idx:idx+n_tr-1) = s;
    idx = idx + n_tr;
end

% ------------------------------------------------------------------------
% 1) common guard: check that the 3rd-dimension size of each array is the same
% ------------------------------------------------------------------------
assert(all([size(plot_ds_prop,3), size(plot_ds_imu,3)] == Ntotal), ...
       'The 3rd-dimension sizes of ref/prop/imu differ.');

% ------------------------------------------------------------------------
% 2) prepare the figure
% ------------------------------------------------------------------------
figure(10000); clf; hold on;
colors = turbo(20);
[x_sphere, y_sphere, z_sphere] = sphere(20);
scale_factor = 1;

ref_means  = nan(num_subjects,3); ref_stds  = nan(num_subjects,3);
imu_means  = nan(num_subjects,3); imu_stds  = nan(num_subjects,3);
prop_means = nan(num_subjects,3); prop_stds = nan(num_subjects,3);

for subj = 1:num_subjects
    % trial indices of this participant (only those that actually exist)
    idx_subj = find(trial_subj_ids == subj);   % 1 x N_subj
    if isempty(idx_subj)
        fprintf('  [WARN] Subject %d has no trials. Skip.\n', subj);
        continue;
    end

    % --- ref / imu / prop data: [N_subj x 3] ---
    ref_data_subj = squeeze(plot_ds_ref(g.imp, :, idx_subj)).';      % g.imp frame
    prop_data_subj = squeeze(plot_ds_prop(g.imp, :, idx_subj)).';
    % imu_data_subj  = squeeze(plot_ds_imu (g.imp, :, idx_subj)).';
    imu_data_subj  = squeeze(plot_ds_driver (g.imp, :, idx_subj)).';

    % --- statistics ---
    ref_mean  = mean(ref_data_subj, 1); ref_std  = std(ref_data_subj,0,1);
    imu_mean  = mean(imu_data_subj,  1); imu_std  = std(imu_data_subj,0,1);
    prop_mean = mean(prop_data_subj, 1); prop_std = std(prop_data_subj,0,1);

    ref_means(subj,:)  = ref_mean;  ref_stds(subj,:)  = ref_std;
    imu_means(subj,:)  = imu_mean;  imu_stds(subj,:)  = imu_std;
    prop_means(subj,:) = prop_mean; prop_stds(subj,:) = prop_std;

    curr_color = colors(subj, :);

    % --- scatter plot (light) ---
    scatter3(ref_data_subj(:,1), ref_data_subj(:,2), ref_data_subj(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 0.3);

    % --- Ref ellipse (light) ---
    surf(x_sphere*ref_std(1)*scale_factor + ref_mean(1), ...
         y_sphere*ref_std(2)*scale_factor + ref_mean(2), ...
         z_sphere*ref_std(3)*scale_factor + ref_mean(3), ...
         'FaceColor', curr_color, 'FaceAlpha', 0.1, 'EdgeColor','none');

    % uncomment if you also want to plot the mean point
    scatter3(ref_mean(1), ref_mean(2), ref_mean(3), 100, curr_color, ...
             'filled','MarkerEdgeColor','k','LineWidth',1,'MarkerFaceAlpha',0.3);
    text(ref_mean(1), ref_mean(2),ref_mean(3), sprintf('%d',subj), 'FontSize',9, ...
     'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
     'VerticalAlignment','bottom','Clipping','on');

        % % camera estimate point
    scatter3(prop_data_subj(:,1), prop_data_subj(:,2), prop_data_subj(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 0.4);

    surf(x_sphere*prop_std(1)*scale_factor + prop_mean(1), ...
          y_sphere*prop_std(2)*scale_factor + prop_mean(2), ...
          z_sphere*prop_std(3)*scale_factor + prop_mean(3), ...
          'FaceColor', curr_color, 'FaceAlpha', 0.3, ...
          'EdgeColor', 'none');
    scatter3(prop_mean(1), prop_mean(2), prop_mean(3), ...
             100, curr_color, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1, ...
             'MarkerFaceAlpha', 0.3); % prop darker, edge also thin
    
    text(prop_mean(1), prop_mean(2),prop_mean(3), sprintf('%d',subj), 'FontSize',9, ...
     'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
     'VerticalAlignment','bottom','Clipping','on');
    
    % IMU estimate point
    scatter3(imu_data_subj(:,1), imu_data_subj(:,2), imu_data_subj(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 0.3);

    surf(x_sphere*imu_std(1)*scale_factor + imu_mean(1), ...
          y_sphere*imu_std(2)*scale_factor + imu_mean(2), ...
          z_sphere*imu_std(3)*scale_factor + imu_mean(3), ...
          'FaceColor', 'g', 'FaceAlpha', 0.4, ...
          'EdgeColor', 'none');
    scatter3(imu_mean(1), imu_mean(2), imu_mean(3), ...
             100, curr_color, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1, ...
             'MarkerFaceAlpha', 0.3); % prop darker, edge also thin
    text(imu_mean(1), imu_mean(2),imu_mean(3), sprintf('%d',subj), 'FontSize',9, ...
     'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
     'VerticalAlignment','bottom','Clipping','on');

end

xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
view(90,0); axis equal;
print(gcf, 'plot3d_xz.svg', '-dsvg', '-vector');
grid on;
% xlim([0 20]); zlim([0 20]); ylim([-10 10]);

% ------------------------------------------------------------------------
% 3) compute statistics over all participants (re-summarize the per-subject mean/std)
%    NaN (empty participant) is ignored automatically
% ------------------------------------------------------------------------
stats = struct();

% ref
stats.ref.mean_of_means = mean(ref_means, 1, 'omitnan');
stats.ref.std_of_means  = std (ref_means, 0, 1, 'omitnan');
stats.ref.mean_of_stds  = mean(ref_stds,  1, 'omitnan');
stats.ref.std_of_stds   = std (ref_stds,  0, 1, 'omitnan');

% imu
stats.imu.mean_of_means = mean(imu_means, 1, 'omitnan');
stats.imu.std_of_means  = std (imu_means, 0, 1, 'omitnan');
stats.imu.mean_of_stds  = mean(imu_stds,  1, 'omitnan');
stats.imu.std_of_stds   = std (imu_stds,  0, 1, 'omitnan');

% prop
stats.prop.mean_of_means = mean(prop_means, 1, 'omitnan');
stats.prop.std_of_means  = std (prop_means, 0, 1, 'omitnan');
stats.prop.mean_of_stds  = mean(prop_stds,  1, 'omitnan');
stats.prop.std_of_stds   = std (prop_stds,  0, 1, 'omitnan');

disp(stats.ref)
disp(stats.imu)
disp(stats.prop)




%% check the consistency correlation
% per participant or across all participants?
% ref_stds, prop_stds, imu_stds : [S x 3] (S=num_subjects, columns: X Y Z)
epsv = 1e-9;

ratio_prop = prop_stds ./ max(ref_stds, epsv);   % [S x 3]
ratio_imu  = imu_stds  ./ max(ref_stds, epsv);   % [S x 3]

% per-axis mean±standard deviation
summ.prop.mean = mean(ratio_prop, 1);
summ.prop.std  = std (ratio_prop, 0, 1);
summ.imu.mean  = mean(ratio_imu,  1);
summ.imu.std   = std (ratio_imu,  0, 1);

fprintf('PROP/REF ratio (X,Y,Z) mean±SD = [%.2f±%.2f, %.2f±%.2f, %.2f±%.2f]\n', ...
    summ.prop.mean(1), summ.prop.std(1), ...
    summ.prop.mean(2), summ.prop.std(2), ...
    summ.prop.mean(3), summ.prop.std(3));
fprintf('IMU /REF ratio (X,Y,Z) mean±SD = [%.2f±%.2f, %.2f±%.2f, %.2f±%.2f]\n', ...
    summ.imu.mean(1), summ.imu.std(1), ...
    summ.imu.mean(2), summ.imu.std(2), ...
    summ.imu.mean(3), summ.imu.std(3));



% % % % check on a single participant
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % 
figure(20000);
hold on;

% per participant
% first extract the data for the scatter plot
ref_data = squeeze(plot_ds_ref(g.imp, :, :))';   % convert to a 120x3 matrix
prop_data = squeeze(plot_ds_prop(g.imp, :, :))'; % convert to a 120x3 matrix
driver_data = squeeze(plot_ds_driver(g.imp, :, :))'; % convert to a 120x3 matrix

% compute the mean and standard deviation of the 120 points
mtraj_mean = mean(ref_data, 1);    % 1x3 vector (mean of the 120 points)
mtraj_std = std(ref_data, 0, 1);   % 1x3 vector (standard deviation of the 120 points)

apdm_mean = mean(prop_data, 1);    % 1x3 vector
apdm_std = std(prop_data, 0, 1);   % 1x3 vector

driver_data_mean = mean(driver_data, 1);    % 1x3 vector
driver_data_std = std(driver_data, 0, 1);   % 1x3 vector


% Scatter plot - ref data
scatter3(ref_data(:,1), ref_data(:,2), ref_data(:,3), ...
         50, 'k', 'filled');
% Scatter plot - prop data
scatter3(prop_data(:,1), prop_data(:,2), prop_data(:,3), ...
         50, dark_red, 'filled');
% % mean-corrected data
scatter3(driver_data(:,1), driver_data(:,2), driver_data(:,3), ...
         50, dark_green, 'filled');


% draw the sphere
[x_sphere, y_sphere, z_sphere] = sphere(20);

% Ref ellipsoid (using the per-axis standard deviation)
surf(x_sphere*mtraj_std(1) + mtraj_mean(1), ...
     y_sphere*mtraj_std(2) + mtraj_mean(2), ...
     z_sphere*mtraj_std(3) + mtraj_mean(3), ...
     'FaceColor', 'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

% Prop ellipsoid
surf(x_sphere*apdm_std(1) + apdm_mean(1), ...
     y_sphere*apdm_std(2) + apdm_mean(2), ...
     z_sphere*apdm_std(3) + apdm_mean(3), ...
     'FaceColor', dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

% % Prop ellipsoid
surf(x_sphere*driver_data_std(1) + driver_data_mean(1), ...
     y_sphere*driver_data_std(2) + driver_data_mean(2), ...
     z_sphere*driver_data_std(3) + driver_data_mean(3), ...
     'FaceColor', dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

% 
% %% draw the gray circle or not  % try plotting the velocity-corrected version
% imu_data_wocal = squeeze(plot_ds_imu(g.imp, :, :))'; % convert to a 120x3 matrix
% imu_data_wocal_mean = mean(imu_data_wocal, 1);    % 1x3 vector
% imu_data_wocal_std = std(imu_data_wocal, 0, 1);   % 1x3 vector
% % % imu data
% scatter3(imu_data_wocal(:,1), imu_data_wocal(:,2), imu_data_wocal(:,3), ...
%          50, [0.7 0.7 0.7], 'filled');
% % % Prop ellipsoid
% surf(x_sphere*imu_data_wocal_std(1) + imu_data_wocal_mean(1), ...
%      y_sphere*imu_data_wocal_std(2) + imu_data_wocal_mean(2), ...
%      z_sphere*imu_data_wocal_std(3) + imu_data_wocal_mean(3), ...
%      'FaceColor', [0.7 0.7 0.7], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% scatter3(imu_data_wocal_mean(1), imu_data_wocal_mean(2), imu_data_wocal_mean(3), ...
%          200, [0.7 0.7 0.7], 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
% 
% 
% 
% mark the mean point (for checking)
scatter3(mtraj_mean(1), mtraj_mean(2), mtraj_mean(3), ...
         200, 'k', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
scatter3(apdm_mean(1), apdm_mean(2), apdm_mean(3), ...
         200, dark_red, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
% 
scatter3(driver_data_mean(1), driver_data_mean(2), driver_data_mean(3), ...
         200, dark_green, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);


xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
% xlim([0 10])
% ylim([-8 8])
% zlim([-2 15])

grid on;
view(90,0);
axis equal;  % so the ellipsoid is not distorted


%% statistical significance code
function out = compare_methods(A, B, varargin)
% A, B: N×D (values such as errors) — assumes A is 'proposed' and B is 'baseline'
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

    % common mask for NaN removal
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
            % Wilcoxon signed-rank (exact for small n → no z)
            [p,h,stats] = signrank(A,B,'tail',tail_to_signrank(opt.Tail));
            n_eff = sum(A~=B);                         % effective n excluding zero differences
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
        % independent-sample comparison
        n1=numel(A); n2=numel(B);
        [useT, ~] = normal_decision([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;                 % Cohen's d
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;
        else
            % Mann-Whitney U (exact for small n → no z)
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
                useT = ~h;                 % normality holds → t-test
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


% % check the imu angle error
% disp('roll error mean and SD')
% mean(imu_roll_error_list)
% std(imu_roll_error_list)
% 
% disp('pitch error mean and SD')
% mean(imu_roll_error_list)
% std(imu_pitch_error_list)
% 
% disp('yaw angle mean and SD')
% mean(imu_yaw_list)
% std(imu_yaw_list)

% drift correction
disp('correction coefficient mean&SD')
mean(apdm_biasV_list)
% std(apdm_biasV_list,0,2) %the second 0 selects whether the denominator is n or n-1




function nrmse = NRMSE_range(measured, truev)
% per-axis NRMSE (denominator: the range of true). Guards against a zero denominator.
E = measured - truev;                 % [N x 3]
rmse_xyz = sqrt(mean(E.^2, 1));       % [1 x 3]
den = range(truev, 1);                % [1 x 3]  (max-min, per column)
den(den==0) = eps;                    % guard against a zero denominator
nrmse = rmse_xyz ./ den;              % [1 x 3]
end

function S = cvabs_between_ts_timeAxesTrials(X, idx)
% X:   [nTime x nAxes x nTrials]  (e.g. 450 x 3 x 10)
% idx: (optional) time indices to use. Whole range if omitted.
%
% returns S:
%   .CVabs_between_ts_pct          [nTimeSel x nAxes]   % between-trial CVabs(%) per time and axis
%   .CVabs_between_ts_mean_pct     [1 x nAxes]          % time average of the above (per-axis summary)
%   .CVabs_between_ts_mag_pct      [nTimeSel x 1]       % CVabs(%) based on the vector magnitude (‖x‖)
%   .CVabs_between_ts_mag_mean_pct [1 x 1]              % time average of the above (scalar summary)
%   .mean_trials                   [nTimeSel x nAxes]   % trial mean at each time and axis (sign preserved)
%   .mean_abs_trials               [nTimeSel x nAxes]   % mean(|x|) at each time and axis  ← CVabs denominator
%   .std_trials                    [nTimeSel x nAxes]   % standard deviation at each time and axis (across trials)

    if nargin < 2 || isempty(idx)
        idx = 1:size(X,1);
    end

    Xsel = X(idx, :, :);                       % [nTimeSel x nAxes x nTrials]

    % --- per axis: std and mean(|x|) across trials at each time step
    std_trials      = std( Xsel, 0, 3, 'omitnan');    % [nTimeSel x nAxes]
    mean_trials     = mean(Xsel,    3, 'omitnan');    % [nTimeSel x nAxes] (for reference: sign preserved)
    mean_abs_trials = mean(abs(Xsel),3, 'omitnan');   % [nTimeSel x nAxes] (CVabs denominator)

    CVabs_between_ts_pct      = 100 * (std_trials ./ max(mean_abs_trials, eps));  % [nTimeSel x nAxes]
    CVabs_between_ts_mean_pct = mean(CVabs_between_ts_pct, 1, 'omitnan');         % [1 x nAxes]

    % --- based on the vector magnitude (‖x‖): between-trial CVabs(%) at each time step
    R = squeeze( sqrt(sum(Xsel.^2, 2)) );      % [nTimeSel x nTrials]
    sd_R  = std(R, 0, 2, 'omitnan');           % [nTimeSel x 1]
    muA_R = mean(abs(R), 2, 'omitnan');        % [nTimeSel x 1]
    CVabs_between_ts_mag_pct      = 100 * (sd_R ./ max(muA_R, eps));              % [nTimeSel x 1]
    CVabs_between_ts_mag_mean_pct = mean(CVabs_between_ts_mag_pct, 'omitnan');    % 1x1

    % --- output
    S = struct();
    S.CVabs_between_ts_pct          = CVabs_between_ts_pct;
    S.CVabs_between_ts_mean_pct     = CVabs_between_ts_mean_pct;
    S.CVabs_between_ts_mag_pct      = CVabs_between_ts_mag_pct;
    S.CVabs_between_ts_mag_mean_pct = CVabs_between_ts_mag_mean_pct;
    S.mean_trials                   = mean_trials;
    S.mean_abs_trials               = mean_abs_trials;
    S.std_trials                    = std_trials;
end

function out = viz_mean_z_at_frame(ref_data, pred_data, frame_idx, varargin)
% ref_data, pred_data : [T x 3 x N]  (time x axis x trial)
% frame_idx           : scalar (same frame for all trials) or
%                       vector [N x 1] (a different frame per trial, e.g. imp_point_list)
%
% options (Name-Value):
%   'Mode'     : 'both' | 'z' | 'mean' | 'abs'   % default 'both'
%                'abs' = absolute coordinate frame (a separate figure per axis)
%   'PredName' : string label (default 'PRED')
%   'RefName'  : string label (default 'REF')
%   'Color'    : scatter color [R G B] (default [] → a different color per axis)
%
% output:
%   out.z    : z-score scatter results (per-axis r, p, slope, intercept, std_ratio)
%   out.mean : deviation-from-mean scatter results (per-axis r, p, slope, intercept)
%   out.abs  : absolute-coordinate scatter results (per-axis r, p, slope, intercept)

    % ===== option parsing =====
    p = inputParser;
    addParameter(p,'Mode','both');
    addParameter(p,'PredName','PRED');
    addParameter(p,'RefName','REF');
    addParameter(p,'Color',[]);
    parse(p,varargin{:});
    mode      = lower(p.Results.Mode);
    predName  = p.Results.PredName;
    refName   = p.Results.RefName;
    userColor = p.Results.Color;

    % ===== extract the values at the per-trial frame : [N x 3] =====
    N = size(ref_data, 3);  % number of trials
    
    if isscalar(frame_idx)
        % existing approach: the same frame for all trials
        ref_vals  = squeeze(ref_data (frame_idx,:,:)).';   % N x 3
        pred_vals = squeeze(pred_data(frame_idx,:,:)).';   % N x 3
        frame_label = sprintf('Frame %d', frame_idx);
    else
        % new approach: a different frame per trial (frame_idx is an Nx1 vector)
        ref_vals  = nan(N, 3);
        pred_vals = nan(N, 3);
        for i = 1:N
            if ~isnan(frame_idx(i)) && frame_idx(i) >= 1 && frame_idx(i) <= size(ref_data, 1)
                ref_vals(i, :)  = ref_data(frame_idx(i), :, i);
                pred_vals(i, :) = pred_data(frame_idx(i), :, i);
            end
        end
        frame_label = sprintf('Variable Frame (mean=%.0f)', mean(frame_idx, 'omitnan'));
    end

    % ===== trial mean/standard deviation =====
    ref_mu  = mean(ref_vals,  1, 'omitnan');
    ref_std = std (ref_vals,  0, 1, 'omitnan');
    p_mu    = mean(pred_vals, 1, 'omitnan');
    p_std   = std (pred_vals, 0, 1, 'omitnan');

    % ===== z-score preparation =====
    den_ref = ref_std;
    den_ref(den_ref < 1e-12) = NaN;
    den_p   = p_std;
    den_p  (den_p   < 1e-12) = NaN;
    z_ref   = (ref_vals  - ref_mu) ./ den_ref;
    z_pred  = (pred_vals - p_mu)   ./ den_p;
    std_ratio = p_std ./ ref_std;

    % ===== deviation from the mean (unnormalized) =====
    d_ref  = ref_vals  - ref_mu;
    d_pred = pred_vals - p_mu;

    axesNames = {'X','Y','Z'};
    
    % color setup
    if isempty(userColor)
        clr = lines(3);
    else
        clr = repmat(userColor(:)', 3, 1);
    end

    out = struct();

    % ===== z-score scatter plot =====
    if any(strcmp(mode, {'both','z'}))
        figure('Name',[predName ' vs ' refName ' (z-score)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
        tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

        out.z = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3), ...
                       'intercept',nan(1,3),'std_ratio',std_ratio, ...
                       'ref_std',ref_std,'pred_std',p_std);

        for d = 1:3
            nexttile; hold on; grid on; axis equal;
            v = isfinite(z_ref(:,d)) & isfinite(z_pred(:,d));
            x = z_ref (v,d); 
            y = z_pred(v,d);

            scatter(x, y, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none');

            mx  = max(abs([x; y])); 
            lim = max(3, ceil(mx));
            
            plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);
            plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);
            plot([-lim lim], [-lim lim], 'k--', 'LineWidth', 1);

            if numel(x) >= 2 && std(x)>0
                pfit = polyfit(x, y, 1);
                yfit = polyval(pfit, [-lim lim]);
                plot([-lim lim], yfit, 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
                out.z.slope(d)     = pfit(1);
                out.z.intercept(d) = pfit(2);
            end
            if numel(x) >= 2
                [rval, pval] = corr(x, y, 'Type','Pearson');
                out.z.r(d) = rval; out.z.p(d) = pval;
            end

            xlim([-lim lim]); ylim([-lim lim]);

            xlabel(sprintf('%s z (%s)', refName,  axesNames{d}));
            ylabel(sprintf('%s z (%s)', predName, axesNames{d}));
            title(sprintf('%s | r=%.2f, p=%.3g | sigma-ratio=%.2f', ...
                  axesNames{d}, out.z.r(d), out.z.p(d), std_ratio(d)));
        end
        sgtitle(sprintf('%s : z-score comparison', frame_label), 'FontWeight','bold');
        filename = [predName, '.png'];
        saveas(gcf, filename);
    end

    % ===== deviation-from-mean scatter plot (no normalization) =====
    if any(strcmp(mode, {'both','mean'}))
        figure('Name',[predName ' vs ' refName ' (mean-centered)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
        tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

        out.mean = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3),'intercept',nan(1,3));

        for d = 1:3
            nexttile; hold on; grid on; axis equal;
            v = isfinite(d_ref(:,d)) & isfinite(d_pred(:,d));
            x = d_ref (v,d); 
            y = d_pred(v,d);

            scatter(x, y, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','k');

            mx  = max(abs([x; y])); 
            lim = max( max(1, round(mx)), 1 );

            plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);
            plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);

            if numel(x) >= 2 && std(x)>0
                pfit = polyfit(x, y, 1);
                yfit = polyval(pfit, [-lim lim]);
                plot([-lim lim], yfit, 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
                out.mean.slope(d)     = pfit(1);
                out.mean.intercept(d) = pfit(2);
            end
            if numel(x) >= 2
                [rval, pval] = corr(x, y, 'Type','Pearson');
                out.mean.r(d) = rval; out.mean.p(d) = pval;
            end

            xlim([-lim lim]); ylim([-lim lim]);
            xlabel(sprintf('%s dev from mean (%s)', refName,  axesNames{d}));
            ylabel(sprintf('%s dev from mean (%s)', predName, axesNames{d}));
            title(sprintf('%s | r=%.2f, p=%.3g, slope=%.2f', ...
                  axesNames{d}, out.mean.r(d), out.mean.p(d), out.mean.slope(d)));
        end
        sgtitle(sprintf('%s : deviation-from-mean comparison', frame_label), 'FontWeight','bold');
    end

    % ===== absolute coordinate scatter plot (a separate figure per axis) =====
    if any(strcmp(mode, {'abs'}))
        out.abs = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3),'intercept',nan(1,3), ...
                         'ref_mean',ref_mu,'pred_mean',p_mu,'ref_std',ref_std,'pred_std',p_std);

        for d = 1:3
            figure('Name',sprintf('%s vs %s (abs %s)', predName, refName, axesNames{d}), ...
                   'Color','w', 'Position', [100 + (d-1)*50, 200, 600, 550]);
            hold on; axis equal;
            
            v = isfinite(ref_vals(:,d)) & isfinite(pred_vals(:,d));
            x = ref_vals(v,d); 
            y = pred_vals(v,d);

            scatter(x, y, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none', 'LineWidth', 0.5);

            all_vals = [x; y];
            min_val = min(all_vals);
            max_val = max(all_vals);
            margin = (max_val - min_val) * 0.1;
            lim_min = min_val - margin;
            lim_max = max_val + margin;

            % plot([-5 25], [-5 25], 'k--', 'LineWidth', 1.5);
            plot([-30 30], [-30 30], 'k--', 'LineWidth', 1.5);

            if numel(x) >= 2 && std(x) > 0
                pfit = polyfit(x, y, 1);
                yfit = polyval(pfit, [lim_min lim_max]);
                plot([lim_min lim_max], yfit, 'Color', userColor, 'LineWidth', 1.5);

                out.abs.slope(d)     = pfit(1);
                out.abs.intercept(d) = pfit(2);
            end
            
            if numel(x) >= 2
                [rval, pval] = corr(x, y, 'Type','Pearson');
                out.abs.r(d) = rval; 
                out.abs.p(d) = pval;
            end

            % xlim([-5 25]); 
            % ylim([-5 25]);
            xlim([-30 30]); ylim([-30 30]);

            
            
            xlabel(sprintf('%s %s (cm)', refName, axesNames{d}));
            ylabel(sprintf('%s %s (cm)', predName, axesNames{d}));
            
            hold off;
            
            filename = sprintf('%s_vs_%s_abs_%s.svg', predName, refName, axesNames{d});
            saveas(gcf, filename);
        end
    end
end
% function out = viz_mean_z_at_frame(ref_data, pred_data, frame_idx, varargin)
% % ref_data, pred_data : [T x 3 x N]  (time x axis x trial)
% % frame_idx           : frame index of interest (e.g. g.imp)
% %
% % options (Name-Value):
% %   'Mode'     : 'both' | 'z' | 'mean' | 'abs'   % default 'both'
% %                'abs' = absolute coordinate frame (a separate figure per axis)
% %   'PredName' : string label (default 'PRED')
% %   'RefName'  : string label (default 'REF')
% %   'Color'    : scatter color [R G B] (default [] → a different color per axis)
% %
% % output:
% %   out.z    : z-score scatter results (per-axis r, p, slope, intercept, std_ratio)
% %   out.mean : deviation-from-mean scatter results (per-axis r, p, slope, intercept)
% %   out.abs  : absolute-coordinate scatter results (per-axis r, p, slope, intercept)
% 
%     % ===== option parsing =====
%     p = inputParser;
%     addParameter(p,'Mode','both');
%     addParameter(p,'PredName','PRED');
%     addParameter(p,'RefName','REF');
%     addParameter(p,'Color',[]);  % newly added
%     parse(p,varargin{:});
%     mode      = lower(p.Results.Mode);
%     predName  = p.Results.PredName;
%     refName   = p.Results.RefName;
%     userColor = p.Results.Color;  % user-specified color
% 
%     % ===== extract the trial values at the impact frame : [N x 3] =====
%     ref_vals  = squeeze(ref_data (frame_idx,:,:)).';   % N x 3
%     pred_vals = squeeze(pred_data(frame_idx,:,:)).';   % N x 3
% 
%     % ===== trial mean/standard deviation =====
%     ref_mu  = mean(ref_vals,  1, 'omitnan');
%     ref_std = std (ref_vals,  0, 1, 'omitnan');
%     p_mu    = mean(pred_vals, 1, 'omitnan');
%     p_std   = std (pred_vals, 0, 1, 'omitnan');
% 
%     % ===== z-score preparation =====
%     den_ref = ref_std;
%     den_ref(den_ref < 1e-12) = NaN;
%     den_p   = p_std;
%     den_p  (den_p   < 1e-12) = NaN;
%     z_ref   = (ref_vals  - ref_mu) ./ den_ref;
%     z_pred  = (pred_vals - p_mu)   ./ den_p;
%     std_ratio = p_std ./ ref_std;
% 
%     % ===== deviation from the mean (unnormalized) =====
%     d_ref  = ref_vals  - ref_mu;
%     d_pred = pred_vals - p_mu;
% 
%     axesNames = {'X','Y','Z'};
% 
%     % color setup: if a user-specified color is given, apply it to all axes
%     if isempty(userColor)
%         clr = lines(3);  % default: a different color per axis
%     else
%         clr = repmat(userColor(:)', 3, 1);  % apply the user color to all 3 axes
%     end
% 
%     out = struct();
% 
%     % ===== z-score scatter plot =====
%     if any(strcmp(mode, {'both','z'}))
%         figure('Name',[predName ' vs ' refName ' (z-score)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
%         tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
% 
%         out.z = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3), ...
%                        'intercept',nan(1,3),'std_ratio',std_ratio, ...
%                        'ref_std',ref_std,'pred_std',p_std);
% 
%         for d = 1:3
%             nexttile; hold on; grid on; axis equal;
%             v = isfinite(z_ref(:,d)) & isfinite(z_pred(:,d));
%             x = z_ref (v,d); 
%             y = z_pred(v,d);
% 
%             scatter(x, y, 60, 'filled', ...
%                     'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none');
% 
%             mx  = max(abs([x; y])); 
%             lim = max(3, ceil(mx));
% 
%             % draw the axis lines through the origin (x=0, y=0) in bold
%             plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);  % x axis
%             plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);  % y axis
% 
%             plot([-lim lim], [-lim lim], 'k--', 'LineWidth', 1);  % 1:1
% 
%             if numel(x) >= 2 && std(x)>0
%                 pfit = polyfit(x, y, 1);
%                 yfit = polyval(pfit, [-lim lim]);
%                 plot([-lim lim], yfit, 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
%                 out.z.slope(d)     = pfit(1);
%                 out.z.intercept(d) = pfit(2);
%             end
%             if numel(x) >= 2
%                 [rval, pval] = corr(x, y, 'Type','Pearson');
%                 out.z.r(d) = rval; out.z.p(d) = pval;
%             end
% 
%             xlim([-lim lim]); ylim([-lim lim]);
% 
%             xlabel(sprintf('%s z (%s)', refName,  axesNames{d}));
%             ylabel(sprintf('%s z (%s)', predName, axesNames{d}));
%             title(sprintf('%s | r=%.2f, p=%.3g | sigma-ratio=%.2f', ...
%                   axesNames{d}, out.z.r(d), out.z.p(d), std_ratio(d)));
%         end
%         sgtitle(sprintf('Frame %d : z-score comparison', frame_idx), 'FontWeight','bold');
%         filename = [predName, '.png'];
%         saveas(gcf, filename);
%     end
% 
%     % ===== deviation-from-mean scatter plot (no normalization) =====
%     if any(strcmp(mode, {'both','mean'}))
%         figure('Name',[predName ' vs ' refName ' (mean-centered)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
%         tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
% 
%         out.mean = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3),'intercept',nan(1,3));
% 
%         for d = 1:3
%             nexttile; hold on; grid on; axis equal;
%             v = isfinite(d_ref(:,d)) & isfinite(d_pred(:,d));
%             x = d_ref (v,d); 
%             y = d_pred(v,d);
% 
%             scatter(x, y, 60, 'filled', ...
%                     'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','k');
% 
%             mx  = max(abs([x; y])); 
%             lim = max( max(1, round(mx)), 1 );
% 
%             % draw the axis lines through the origin (x=0, y=0) in bold
%             plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);  % x axis
%             plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);  % y axis
% 
%             if numel(x) >= 2 && std(x)>0
%                 pfit = polyfit(x, y, 1);
%                 yfit = polyval(pfit, [-lim lim]);
%                 plot([-lim lim], yfit, 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
%                 out.mean.slope(d)     = pfit(1);
%                 out.mean.intercept(d) = pfit(2);
%             end
%             if numel(x) >= 2
%                 [rval, pval] = corr(x, y, 'Type','Pearson');
%                 out.mean.r(d) = rval; out.mean.p(d) = pval;
%             end
% 
%             xlim([-lim lim]); ylim([-lim lim]);
%             xlabel(sprintf('%s dev from mean (%s)', refName,  axesNames{d}));
%             ylabel(sprintf('%s dev from mean (%s)', predName, axesNames{d}));
%             title(sprintf('%s | r=%.2f, p=%.3g, slope=%.2f', ...
%                   axesNames{d}, out.mean.r(d), out.mean.p(d), out.mean.slope(d)));
%         end
%         sgtitle(sprintf('Frame %d : deviation-from-mean comparison', frame_idx), 'FontWeight','bold');
%     end
% 
%     % ===== absolute coordinate scatter plot (a separate figure per axis) =====
%     if any(strcmp(mode, {'abs'}))
%         out.abs = struct('r',nan(1,3),'p',nan(1,3),'slope',nan(1,3),'intercept',nan(1,3), ...
%                          'ref_mean',ref_mu,'pred_mean',p_mu,'ref_std',ref_std,'pred_std',p_std);
% 
%         for d = 1:3
%             figure('Name',sprintf('%s vs %s (abs %s)', predName, refName, axesNames{d}), ...
%                    'Color','w', 'Position', [100 + (d-1)*50, 200, 600, 550]);
%             hold on; axis equal; %grid on;
% 
%             v = isfinite(ref_vals(:,d)) & isfinite(pred_vals(:,d));
%             x = ref_vals(v,d); 
%             y = pred_vals(v,d);
% 
%             scatter(x, y, 60, 'filled', ...
%                     'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none', 'LineWidth', 0.5);
% 
%             % compute the axis range
%             all_vals = [x; y];
%             min_val = min(all_vals);
%             max_val = max(all_vals);
%             margin = (max_val - min_val) * 0.1;
%             lim_min = min_val - margin;
%             lim_max = max_val + margin;
% 
%             % y = x reference line
%             % plot([lim_min lim_max], [lim_min lim_max], 'k--', 'LineWidth', 1.5);
%             plot([-5 25], [-5 25], 'k--', 'LineWidth', 1.5);
% 
%             % regression line
%             if numel(x) >= 2 && std(x) > 0
%                 pfit = polyfit(x, y, 1);
%                 yfit = polyval(pfit, [lim_min lim_max]);
%                 plot([lim_min lim_max], yfit, 'Color', userColor, 'LineWidth', 1.5);
% 
%                 out.abs.slope(d)     = pfit(1);
%                 out.abs.intercept(d) = pfit(2);
%             end
% 
%             % correlation coefficient
%             if numel(x) >= 2
%                 [rval, pval] = corr(x, y, 'Type','Pearson');
%                 out.abs.r(d) = rval; 
%                 out.abs.p(d) = pval;
%             end
% 
%             % xlim([lim_min lim_max]); 
%             % ylim([lim_min lim_max]);
% 
%             xlim([-5 25]); 
%             ylim([-5 25]);
% 
%             xlabel(sprintf('%s %s (cm)', refName, axesNames{d}));
%             ylabel(sprintf('%s %s (cm)', predName, axesNames{d}));
% 
%             % % statistics text
%             % text_str = sprintf('r=%.3f, p=%.3g\nslope=%.2f\n%s: %.1f±%.1f\n%s: %.1f±%.1f', ...
%             %     out.abs.r(d), out.abs.p(d), out.abs.slope(d), ...
%             %     refName, ref_mu(d), ref_std(d), ...
%             %     predName, p_mu(d), p_std(d));
%             % text(lim_min + margin*0.5, lim_max - margin*0.5, text_str, ...
%             %     'FontSize', 10, 'VerticalAlignment', 'top');
% 
%             hold off;
% 
%             % save
%             filename = sprintf('%s_vs_%s_abs_%s.svg', predName, refName, axesNames{d});
%             saveas(gcf, filename);
%         end
%     end
% end


function out = viz_mean_z_at_frame_group(ref_data, pred_data, frame_idx, group, varargin)
% ref_data, pred_data : [T x 3 x N]  (time x axis x trial)
% frame_idx           : scalar (same frame for all trials) or
%                       vector [N x 1] (a different frame per trial, e.g. imp_point_list)
% group               : [N x 1] participant ID per trial (1,1,...,1,2,2,...)
%
% options (Name-Value):
%   'Mode'     : 'both' | 'z' | 'mean' | 'abs'   % default 'both'
%                'abs' = absolute coordinate frame (a separate figure per axis)
%   'PredName' : string label (default 'PRED')
%   'RefName'  : string label (default 'REF')
%   'Color'    : scatter color [R G B] (default [] → a different color per axis)
%
% output:
%   out.z    : z-score scatter results (per-axis r, p, slope_subj, slope_mean, std_ratio)
%   out.mean : deviation-from-mean scatter results (per-axis r, p, slope_subj, slope_mean)
%   out.abs  : absolute-coordinate scatter results (per-axis r, p, slope_subj, slope_mean)

    % ===== option parsing =====
    p = inputParser;
    addParameter(p,'Mode','both');
    addParameter(p,'PredName','PRED');
    addParameter(p,'RefName','REF');
    addParameter(p,'Color',[]);
    parse(p,varargin{:});
    mode      = lower(p.Results.Mode);
    predName  = p.Results.PredName;
    refName   = p.Results.RefName;
    userColor = p.Results.Color;

    % ===== input size check =====
    if ndims(ref_data) ~= 3 || ndims(pred_data) ~= 3
        error('ref_data and pred_data must be 3-D arrays of shape [T x 3 x N].');
    end
    [T1,D1,N1] = size(ref_data);
    [T2,D2,N2] = size(pred_data);
    if T1~=T2 || D1~=3 || D2~=3 || N1~=N2
        error('ref/pred size mismatch: ref [%d x %d x %d], pred [%d x %d x %d]', ...
              T1,D1,N1,T2,D2,N2);
    end
    N = N1;

    % ===== group vector check =====
    group = group(:);
    if numel(group) ~= N
        error('The group length (%d) differs from the number of trials N (%d).', numel(group), N);
    end
    subj_ids = unique(group);
    Ng = numel(subj_ids);

    % ===== extract the values at the per-trial frame : [N x 3] =====
    if isscalar(frame_idx)
        ref_vals  = squeeze(ref_data (frame_idx,:,:)).';   % N x 3
        pred_vals = squeeze(pred_data(frame_idx,:,:)).';   % N x 3
        frame_label = sprintf('Frame %d', frame_idx);
    else
        ref_vals  = nan(N, 3);
        pred_vals = nan(N, 3);
        for i = 1:N
            if ~isnan(frame_idx(i)) && frame_idx(i) >= 1 && frame_idx(i) <= size(ref_data, 1)
                ref_vals(i, :)  = ref_data(frame_idx(i), :, i);
                pred_vals(i, :) = pred_data(frame_idx(i), :, i);
            end
        end
        frame_label = sprintf('Variable Frame (mean=%.0f)', mean(frame_idx, 'omitnan'));
    end

    % ===== trial mean/standard deviation =====
    ref_mu  = mean(ref_vals,  1, 'omitnan');
    ref_std = std (ref_vals,  0, 1, 'omitnan');
    p_mu    = mean(pred_vals, 1, 'omitnan');
    p_std   = std (pred_vals, 0, 1, 'omitnan');

    % ===== z-score preparation =====
    den_ref = ref_std;
    den_ref(den_ref < 1e-12) = NaN;
    den_p   = p_std;
    den_p  (den_p   < 1e-12) = NaN;
    z_ref   = (ref_vals  - ref_mu) ./ den_ref;
    z_pred  = (pred_vals - p_mu)   ./ den_p;
    std_ratio = p_std ./ ref_std;

    % ===== deviation from the mean (unnormalized) =====
    d_ref  = ref_vals  - ref_mu;
    d_pred = pred_vals - p_mu;

    axesNames = {'X','Y','Z'};
    margin_reg = 0.1;  % margin ratio for the regression line length

    % scatter color setup
    if isempty(userColor)
        clr = lines(3);
    else
        clr = repmat(userColor(:)', 3, 1);
    end

    % per-participant regression line color
    cmap_subj = lines(max(Ng, 3));

    out = struct();

    % ===== z-score scatter plot =====
    if any(strcmp(mode, {'both','z'}))
        figure('Name',[predName ' vs ' refName ' (z-score, grouped)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
        tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

        out.z = struct('r',nan(1,3),'p',nan(1,3), ...
                       'slope_subj',nan(Ng,3),'intercept_subj',nan(Ng,3), ...
                       'slope_mean',nan(1,3), ...
                       'std_ratio',std_ratio, ...
                       'ref_std',ref_std,'pred_std',p_std);

        for d = 1:3
            nexttile; hold on; grid on; axis equal;
            v = isfinite(z_ref(:,d)) & isfinite(z_pred(:,d));
            x_all = z_ref (v,d);
            y_all = z_pred(v,d);
            g_all = group(v);

            scatter(x_all, y_all, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none');

            mx  = max(abs([x_all; y_all]));
            lim = max(3, ceil(mx));

            plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);
            plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);
            plot([-lim lim], [-lim lim], 'k--', 'LineWidth', 1);

            % overall correlation coefficient
            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.z.r(d) = rval; out.z.p(d) = pval;
            end

            % per-participant regression line
            for si = 1:Ng
                sid = subj_ids(si);
                m = (g_all == sid);
                xg = x_all(m); yg = y_all(m);

                if numel(xg) >= 2 && std(xg) > 0
                    pfit = polyfit(xg, yg, 1);
                    x_min = min(xg); x_max = max(xg);
                    span  = x_max - x_min;
                    if span <= 0, continue; end
                    xL = max(-lim, x_min - margin_reg * span);
                    xR = min( lim, x_max + margin_reg * span);
                    plot([xL xR], polyval(pfit, [xL xR]), ...
                         'Color', cmap_subj(si,:), 'LineWidth', 1.5);
                    out.z.slope_subj(si,d)     = pfit(1);
                    out.z.intercept_subj(si,d) = pfit(2);
                end
            end

            out.z.slope_mean(d) = mean(out.z.slope_subj(:,d), 'omitnan');

            xlim([-lim lim]); ylim([-lim lim]);
            xlabel(sprintf('%s z (%s)', refName,  axesNames{d}));
            ylabel(sprintf('%s z (%s)', predName, axesNames{d}));
            title(sprintf('%s | r=%.2f, p=%.3g | sigma-ratio=%.2f', ...
                  axesNames{d}, out.z.r(d), out.z.p(d), std_ratio(d)));
        end
        sgtitle(sprintf('%s : z-score comparison (per-subject)', frame_label), 'FontWeight','bold');
        filename = [predName, '_group.png'];
        saveas(gcf, filename);
    end

    % ===== deviation-from-mean scatter plot (no normalization) =====
    if any(strcmp(mode, {'both','mean'}))
        figure('Name',[predName ' vs ' refName ' (mean-centered, grouped)'], 'Color','w', 'Position', [2077.8,200,1952,668.8]);
        tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

        out.mean = struct('r',nan(1,3),'p',nan(1,3), ...
                          'slope_subj',nan(Ng,3),'intercept_subj',nan(Ng,3), ...
                          'slope_mean',nan(1,3));

        for d = 1:3
            nexttile; hold on; grid on; axis equal;
            v = isfinite(d_ref(:,d)) & isfinite(d_pred(:,d));
            x_all = d_ref (v,d);
            y_all = d_pred(v,d);
            g_all = group(v);

            scatter(x_all, y_all, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','k');

            mx  = max(abs([x_all; y_all]));
            lim = max( max(1, round(mx)), 1 );

            plot([-lim lim], [0 0], 'k-', 'LineWidth', 1.5);
            plot([0 0], [-lim lim], 'k-', 'LineWidth', 1.5);

            % overall correlation coefficient
            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.mean.r(d) = rval; out.mean.p(d) = pval;
            end

            % per-participant regression line
            for si = 1:Ng
                sid = subj_ids(si);
                m = (g_all == sid);
                xg = x_all(m); yg = y_all(m);

                if numel(xg) >= 2 && std(xg) > 0
                    pfit = polyfit(xg, yg, 1);
                    x_min = min(xg); x_max = max(xg);
                    span  = x_max - x_min;
                    if span <= 0, continue; end
                    xL = max(-lim, x_min - margin_reg * span);
                    xR = min( lim, x_max + margin_reg * span);
                    plot([xL xR], polyval(pfit, [xL xR]), ...
                         'Color', cmap_subj(si,:), 'LineWidth', 1.5);
                    out.mean.slope_subj(si,d)     = pfit(1);
                    out.mean.intercept_subj(si,d) = pfit(2);
                end
            end

            out.mean.slope_mean(d) = mean(out.mean.slope_subj(:,d), 'omitnan');

            xlim([-lim lim]); ylim([-lim lim]);
            xlabel(sprintf('%s dev from mean (%s)', refName,  axesNames{d}));
            ylabel(sprintf('%s dev from mean (%s)', predName, axesNames{d}));
            title(sprintf('%s | r=%.2f, p=%.3g, slope=%.2f', ...
                  axesNames{d}, out.mean.r(d), out.mean.p(d), out.mean.slope_mean(d)));
        end
        sgtitle(sprintf('%s : deviation-from-mean comparison (per-subject)', frame_label), 'FontWeight','bold');
    end

    % ===== absolute coordinate scatter plot (a separate figure per axis) =====
    if any(strcmp(mode, {'abs'}))
        out.abs = struct('r',nan(1,3),'p',nan(1,3), ...
                         'slope_subj',nan(Ng,3),'intercept_subj',nan(Ng,3), ...
                         'slope_mean',nan(1,3), ...
                         'ref_mean',ref_mu,'pred_mean',p_mu,'ref_std',ref_std,'pred_std',p_std);

        for d = 1:3
            figure('Name',sprintf('%s vs %s (abs %s, grouped)', predName, refName, axesNames{d}), ...
                   'Color','w', 'Position', [100 + (d-1)*50, 200, 600, 550]);
            hold on; axis equal;

            v = isfinite(ref_vals(:,d)) & isfinite(pred_vals(:,d));
            x_all = ref_vals(v,d);
            y_all = pred_vals(v,d);
            g_all = group(v);

            scatter(x_all, y_all, 60, 'filled', ...
                    'MarkerFaceColor', clr(d,:), 'MarkerEdgeColor','none', 'LineWidth', 0.5);

            plot([-30 30], [-30 30], 'k--', 'LineWidth', 1.5);


            % overall correlation coefficient
            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.abs.r(d) = rval; out.abs.p(d) = pval;
            end

            % per-participant regression line
            for si = 1:Ng
                sid = subj_ids(si);
                m = (g_all == sid);
                xg = x_all(m); yg = y_all(m);

                if numel(xg) >= 2 && std(xg) > 0
                    pfit = polyfit(xg, yg, 1);
                    x_min = min(xg); x_max = max(xg);
                    span  = x_max - x_min;
                    if span <= 0, continue; end
                    xL = x_min - margin_reg * span;
                    xR = x_max + margin_reg * span;
                    plot([xL xR], polyval(pfit, [xL xR]), ...
                         'Color', cmap_subj(si,:), 'LineWidth', 1.5);
                    out.abs.slope_subj(si,d)     = pfit(1);
                    out.abs.intercept_subj(si,d) = pfit(2);
                end
            end

            out.abs.slope_mean(d) = mean(out.abs.slope_subj(:,d), 'omitnan');

            xlim([-5 25]); ylim([-5 25]);
            % xlim([-30 30]); ylim([-30 30]);
            xlabel(sprintf('%s %s (cm)', refName, axesNames{d}));
            ylabel(sprintf('%s %s (cm)', predName, axesNames{d}));
            hold off;

            filename = sprintf('%s_vs_%s_abs_%s_group.svg', predName, refName, axesNames{d});
            saveas(gcf, filename);
        end
    end

    % ===== console output =====
    if isfield(out, 'z')
        fprintf('\n[z-mode] mean slope per axis (X/Y/Z): %.3f  %.3f  %.3f\n', ...
                out.z.slope_mean(1), out.z.slope_mean(2), out.z.slope_mean(3));
    end
    if isfield(out, 'mean')
        fprintf('[mean-mode] mean slope per axis (X/Y/Z): %.3f  %.3f  %.3f\n\n', ...
                out.mean.slope_mean(1), out.mean.slope_mean(2), out.mean.slope_mean(3));
    end
    if isfield(out, 'abs')
        fprintf('[abs-mode] mean slope per axis (X/Y/Z): %.3f  %.3f  %.3f\n\n', ...
                out.abs.slope_mean(1), out.abs.slope_mean(2), out.abs.slope_mean(3));
    end
end


function out = viz_regress_ref_prop_per_subject(ref_data, pred_data, frame_idx, group, varargin)
% ref_data, pred_data : [T x 3 x N]  (time x axis x trial)
% frame_idx           : frame index of interest (e.g. g.imp)
% group               : [N x 1] participant ID per trial (1,1,...,1,2,2,...)
%
% options (Name-Value):
%   'PredName' : string for the y-axis label (default 'PROP')
%   'RefName'  : string for the x-axis label (default 'REF')
%
% behavior:
%   - uses the raw ref vs prop values at frame_idx
%   - for each axis (X,Y,Z), a scatter plot (all trials) + one regression line per participant
%   - computes the mean of the per-participant slopes for each axis, stores it in out.slope_mean and prints it to the console

    % ===== option parsing =====
    p = inputParser;
    addParameter(p,'PredName','PROP');
    addParameter(p,'RefName','REF');
    parse(p,varargin{:});
    predName = p.Results.PredName;
    refName  = p.Results.RefName;

    % ===== input size check =====
    if ndims(ref_data) ~= 3 || ndims(pred_data) ~= 3
        error('ref_data and pred_data must be 3-D arrays of shape [T x 3 x N].');
    end
    [T1,D1,N1] = size(ref_data);
    [T2,D2,N2] = size(pred_data);
    if T1~=T2 || D1~=3 || D2~=3 || N1~=N2
        error('ref/pred size mismatch: ref [%d x %d x %d], pred [%d x %d x %d]', ...
              T1,D1,N1,T2,D2,N2);
    end
    T = T1; N = N1;

    if frame_idx < 1 || frame_idx > T
        error('frame_idx (%d) is out of range for the time length T=%d.', frame_idx, T);
    end

    % ===== group vector check =====
    group = group(:);
    if numel(group) ~= N
        error('The group length (%d) differs from the number of trials N (%d).', numel(group), N);
    end
    subj_ids = unique(group);   % unique participant IDs
    Ng = numel(subj_ids);       % number of participants

    % ===== extract the trial values at that frame : [N x 3] =====
    ref_vals  = squeeze(ref_data (frame_idx,:,:)).';   % N x 3
    pred_vals = squeeze(pred_data(frame_idx,:,:)).';   % N x 3

    axesNames = {'X','Y','Z'};
    cmap = lines(max(Ng,3));    % per-participant color
    margin = 0.1;               % margin ratio for the regression line length

    % initialize the output struct
    out = struct();
    out.slope_subj     = nan(Ng, 3);   % [subject x axis]
    out.intercept_subj = nan(Ng, 3);
    out.slope_mean     = nan(1, 3);
    out.r_all          = nan(1, 3);
    out.p_all          = nan(1, 3);

    % ===== figure: ref vs prop regression per axis =====
    figure('Name', sprintf('%s vs %s (per-subject regression)', predName, refName), ...
           'Color','w', 'Position',[200 200 1900 650]);
    tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

    for d = 1:3
        nexttile; hold on; grid on; axis equal;

        % use only valid trials
        x_all = ref_vals(:,d);
        y_all = pred_vals(:,d);
        v = isfinite(x_all) & isfinite(y_all);
        x_all = x_all(v);
        y_all = y_all(v);
        g_all = group(v);

        % scatter: all trials in gray
        scatter(x_all, y_all, 50, ...
                'filled', ...
                'MarkerFaceColor',[0.7 0.7 0.7], ...
                'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',0.4);

        % correlation coefficient over all trials
        if numel(x_all) >= 2
            [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
            out.r_all(d) = rval;
            out.p_all(d) = pval;
        end

        % axis range over all data (for the 1:1 line)
        mx  = max(abs([x_all; y_all]));
        lim = max( max(1, round(mx)), 1 );
        plot([-lim lim], [-lim lim], 'k--', 'LineWidth', 1);  % 1:1 line

        % per-participant regression line
        for si = 1:Ng
            sid = subj_ids(si);
            m = (g_all == sid);
            xg = x_all(m); yg = y_all(m);

            if numel(xg) >= 2 && std(xg)>0
                pfit = polyfit(xg, yg, 1);

                % per-participant x range ±margin
                x_min = min(xg);
                x_max = max(xg);
                span  = x_max - x_min;
                if span <= 0, continue; end

                xL = x_min - margin * span;
                xR = x_max + margin * span;
                xL = max(-lim, xL);
                xR = min( lim, xR);

                x_line = [xL xR];
                y_line = polyval(pfit, x_line);

                plot(x_line, y_line, ...
                     'Color', cmap(si,:), 'LineWidth', 1.5);

                out.slope_subj(si,d)     = pfit(1);
                out.intercept_subj(si,d) = pfit(2);
            end
        end

        % mean of the per-participant slopes
        out.slope_mean(d) = mean(out.slope_subj(:,d), 'omitnan');

        xlim([-lim lim]); ylim([-lim lim]);
        xlabel(sprintf('%s (%s)', refName,  axesNames{d}));
        ylabel(sprintf('%s (%s)', predName, axesNames{d}));
        title(sprintf('%s | r(all)=%.2f, p=%.3g | mean slope=%.2f', ...
              axesNames{d}, out.r_all(d), out.p_all(d), out.slope_mean(d)));
    end

    sgtitle(sprintf('Frame %d : %s vs %s (per-subject regression)', ...
            frame_idx, predName, refName), 'FontWeight','bold');

    % print the per-axis mean slope to the console
    fprintf('\n[Raw ref vs prop] mean slope per axis (X/Y/Z): %.3f  %.3f  %.3f\n\n', ...
            out.slope_mean(1), out.slope_mean(2), out.slope_mean(3));
end



function out = viz_window_corr_trials(ref_data, pred_data, varargin)
% viz_window_corr_trials
%   ref_data, pred_data : [T x D x N] (time x axis x trial)
%
%   e.g.)
%     ref_data  = mocap_pos;            % motion capture coordinates
%     pred_data = imu_pos;              % IMU integrated coordinates
%     out = viz_window_corr_trials(ref_data, pred_data, ...
%              'WinLen', 50, 'Hop', 10, ...
%              'ZscorePerWindow', true, ...
%              'DoPlot', true, ...
%              'RefName', 'MoCap', ...
%              'PredName', 'IMU-pos');
%
% options (Name-Value):
%   'WinLen'          : window length (number of frames, default = T/10)
%   'Hop'             : window hop interval (number of frames, default = WinLen/2)
%   'ZscorePerWindow' : if true, z-score normalize per trial, window and axis before
%                       computing the correlation (focused on shape comparison, default true)
%   'DoPlot'          : if true, plot r(t) per axis (default true)
%   'RefName'         : name of the ref data (label for plots)
%   'PredName'        : name of the pred data (label for plots)
%
% output struct out:
%   out.T            : total length T
%   out.D            : number of axes D
%   out.N            : number of trials N
%   out.win_len      : window length
%   out.hop          : hop size
%   out.t_center     : [n_win x 1] center frame index of each window
%   out.r_trial      : [n_win x D x N] correlation coefficient per window/axis/trial
%   out.r_mean       : [n_win x D] trial mean r
%   out.r_std        : [n_win x D] standard deviation across trials
%   out.r_global     : [D x N] whole-range correlation coefficient (per trial)
%   out.r_global_mean: [1 x D] trial mean of the whole-range r
%   out.r_global_std : [1 x D] trial standard deviation of the whole-range r

    % ===== normalize the basic input shape =====
    if ndims(ref_data) == 2
        ref_data = reshape(ref_data, size(ref_data,1), size(ref_data,2), 1);
    end
    if ndims(pred_data) == 2
        pred_data = reshape(pred_data, size(pred_data,1), size(pred_data,2), 1);
    end

    if ndims(ref_data) ~= 3 || ndims(pred_data) ~= 3
        error('ref_data and pred_data must have shape [T x D x N] (3-D).');
    end

    [T1, D1, N1] = size(ref_data);
    [T2, D2, N2] = size(pred_data);

    if T1 ~= T2 || D1 ~= D2 || N1 ~= N2
        error('ref_data and pred_data must have the same size. (ref: %d x %d x %d, pred: %d x %d x %d)', ...
              T1, D1, N1, T2, D2, N2);
    end

    T = T1; D = D1; N = N1;

    % ===== option parsing =====
    p = inputParser;
    addParameter(p, 'WinLen',          max(10, floor(T/10)));
    addParameter(p, 'Hop',             []);
    addParameter(p, 'ZscorePerWindow', true);
    addParameter(p, 'DoPlot',          true);
    addParameter(p, 'RefName',         'REF');
    addParameter(p, 'PredName',        'PRED');
    parse(p, varargin{:});

    win_len          = p.Results.WinLen;
    hop              = p.Results.Hop;
    do_zscore        = p.Results.ZscorePerWindow;
    do_plot          = p.Results.DoPlot;
    refName          = p.Results.RefName;
    predName         = p.Results.PredName;

    if isempty(hop)
        hop = max(1, floor(win_len/2));
    end

    if T < win_len
        error('The data length T=%d is shorter than the window length win_len=%d.', T, win_len);
    end

    % ===== whole-range correlation coefficient (per trial, for reference) =====
    r_global = nan(D, N);   % [D x N]

    for n = 1:N
        for d = 1:D
            x = ref_data(:,d,n);
            y = pred_data(:,d,n);
            v = isfinite(x) & isfinite(y);
            if nnz(v) >= 2
                C = corrcoef(x(v), y(v));
                if size(C,1) >= 2 && size(C,2) >= 2
                    r_global(d,n) = C(1,2);
                end
            end
        end
    end

    r_global_mean = mean(r_global, 2, 'omitnan').';  % 1 x D
    r_global_std  = std (r_global, 0, 2, 'omitnan').'; % 1 x D

    % ===== sliding window setup =====
    n_win = floor((T - win_len)/hop) + 1;

    r_trial  = nan(n_win, D, N);   % [window x axis x trial]
    t_center = nan(n_win, 1);

    % ===== compute the correlation coefficient per window =====
    for w = 1:n_win
        idx_start = (w-1)*hop + 1;
        idx_end   = idx_start + win_len - 1;
        t_center(w) = (idx_start + idx_end) / 2;

        for n = 1:N
            % slice the range of this window: [win_len x D]
            seg_ref  = squeeze(ref_data(idx_start:idx_end, :, n));
            seg_pred = squeeze(pred_data(idx_start:idx_end, :, n));

            % reshape it back in case it was squeezed to 1-D
            if size(seg_ref,2) == 1 && D > 1
                seg_ref  = reshape(seg_ref,  win_len, D);
                seg_pred = reshape(seg_pred, win_len, D);
            end

            % normalize according to the z-score option
            if do_zscore
                for d = 1:D
                    xr = seg_ref(:,d);
                    xp = seg_pred(:,d);

                    % ref z-score
                    mu_r = mean(xr, 'omitnan');
                    sd_r = std (xr, 0, 'omitnan');
                    if sd_r < 1e-12
                        zr = nan(size(xr));
                    else
                        zr = (xr - mu_r) ./ sd_r;
                    end

                    % pred z-score
                    mu_p = mean(xp, 'omitnan');
                    sd_p = std (xp, 0, 'omitnan');
                    if sd_p < 1e-12
                        zp = nan(size(xp));
                    else
                        zp = (xp - mu_p) ./ sd_p;
                    end

                    v = isfinite(zr) & isfinite(zp);
                    if nnz(v) >= 2
                        C = corrcoef(zr(v), zp(v));
                        if size(C,1) >= 2 && size(C,2) >= 2
                            r_trial(w,d,n) = C(1,2);
                        end
                    end
                end
            else
                % correlation on the raw signal without normalization
                for d = 1:D
                    xr = seg_ref(:,d);
                    xp = seg_pred(:,d);
                    v = isfinite(xr) & isfinite(xp);
                    if nnz(v) >= 2
                        C = corrcoef(xr(v), xp(v));
                        if size(C,1) >= 2 && size(C,2) >= 2
                            r_trial(w,d,n) = C(1,2);
                        end
                    end
                end
            end
        end
    end

    % ===== per-window trial mean/standard deviation =====
    r_mean = mean(r_trial, 3, 'omitnan');  % [n_win x D]
    r_std  = std (r_trial, 0, 3, 'omitnan'); % [n_win x D]

    % ===== assemble the result struct =====
    out = struct();
    out.T             = T;
    out.D             = D;
    out.N             = N;
    out.win_len       = win_len;
    out.hop           = hop;
    out.t_center      = t_center;
    out.r_trial       = r_trial;
    out.r_mean        = r_mean;
    out.r_std         = r_std;
    out.r_global      = r_global;
    out.r_global_mean = r_global_mean;
    out.r_global_std  = r_global_std;

    % ===== plot (mean ± std per axis) =====
    if do_plot
        axesNames = cell(1,D);
        for d = 1:D
            if D == 3
                tmp = {'X','Y','Z'};
                axesNames{d} = tmp{d};
            else
                axesNames{d} = sprintf('Dim%d', d);
            end
        end

        figure('Name', sprintf('%s vs %s : Windowed Corr', predName, refName), ...
               'Color','w', 'Position',[200 200 1000 700]);
        tiledlayout(D,1, 'TileSpacing','compact', 'Padding','compact');

        for d = 1:D
            nexttile; hold on; grid on;
            m = r_mean(:,d);
            s = r_std(:,d);

            % mean r
            plot(t_center, m, 'LineWidth', 1.5);

            % mean ± std (shown as two solid lines)
            plot(t_center, m + s, '--', 'LineWidth', 1);
            plot(t_center, m - s, '--', 'LineWidth', 1);

            ylim([-1 1]);
            xlim([t_center(1) t_center(end)]);
            ylabel(sprintf('r (%s)', axesNames{d}));

            if d == 1
                legend({'mean r', 'mean + std', 'mean - std'}, 'Location','best');
                title(sprintf('%s vs %s : windowed correlation', predName, refName));
            else
                title(sprintf('Axis %s', axesNames{d}));
            end
        end

        xlabel('Frame index (window center)');
    end
end


function out = analyze_variability_and_pattern(ref_data, pred_data, phase_windows, varargin)
% analyze_variability_and_pattern
%
%   ref_data, pred_data : [T x D x N] (time x axis x trial)
%   phase_windows       : [P x 2] each row is [start_frame end_frame] (phase range)
%
% example usage:
%   out = analyze_variability_and_pattern(mocap_pos, imu_pos, phase_windows, ...
%               'PhaseNames', {'Backswing','Downswing','Impact'}, ...
%               'FeatureType', 'mean', ...
%               'WinLen', 50, 'Hop', 10, ...
%               'ZscorePerWindow', true, ...
%               'DoPlotWindow', true, ...
%               'DoPlotPhase', true, ...
%               'RefName', 'MoCap', ...
%               'PredName', 'IMU-pos');
%
% output struct out
%   out.info:
%       .T, .D, .N               : length, number of axes, number of trials
%       .P                       : number of phases
%       .axesNames               : axis names
%       .phase_names             : phase names
%   out.window:
%       .win_len, .hop
%       .t_center                : [n_win x 1] center frame of each window
%       .r_trial                 : [n_win x D x N] per-window temporal pattern r
%       .r_mean                  : [n_win x D] trial mean r
%       .r_std                   : [n_win x D] trial standard deviation
%       .r_global                : [D x N] whole-range r (temporal pattern)
%       .r_global_mean, .r_global_std : [1 x D]
%   out.phase:
%       .feature_type            : feature type used
%       .feat_ref                : [P x D x N] ref feature per phase
%       .feat_pred               : [P x D x N] pred feature per phase
%       .r_phase                 : [P x D] across-trial correlation r per phase
%       .p_phase                 : [P x D] corresponding p value

    % ===== normalize the input shape =====
    if ndims(ref_data) == 2
        ref_data = reshape(ref_data, size(ref_data,1), size(ref_data,2), 1);
    end
    if ndims(pred_data) == 2
        pred_data = reshape(pred_data, size(pred_data,1), size(pred_data,2), 1);
    end

    if ndims(ref_data) ~= 3 || ndims(pred_data) ~= 3
        error('ref_data and pred_data must have shape [T x D x N] (3-D).');
    end

    [T1, D1, N1] = size(ref_data);
    [T2, D2, N2] = size(pred_data);

    if T1 ~= T2 || D1 ~= D2 || N1 ~= N2
        error('ref_data and pred_data must have the same size. (ref: %d x %d x %d, pred: %d x %d x %d)', ...
              T1, D1, N1, T2, D2, N2);
    end

    T = T1; D = D1; N = N1;

    if nargin < 3 || isempty(phase_windows)
        phase_windows = [];
    end
    if ~isempty(phase_windows)
        if size(phase_windows,2) ~= 2
            error('phase_windows must have shape [P x 2]. Each row is [start_frame end_frame].');
        end
        P = size(phase_windows,1);
    else
        P = 0;
    end

    % ===== option parsing =====
    p = inputParser;
    addParameter(p, 'PhaseNames',       {});
    addParameter(p, 'FeatureType',      'mean');   % 'mean','max','min','range','std'
    addParameter(p, 'WinLen',           max(10, floor(T/10)));
    addParameter(p, 'Hop',              []);
    addParameter(p, 'ZscorePerWindow',  true);
    addParameter(p, 'DoPlotWindow',     true);
    addParameter(p, 'DoPlotPhase',      true);
    addParameter(p, 'RefName',          'REF');
    addParameter(p, 'PredName',         'PRED');
    parse(p, varargin{:});

    phase_names      = p.Results.PhaseNames;
    feature_type     = lower(p.Results.FeatureType);
    win_len          = p.Results.WinLen;
    hop              = p.Results.Hop;
    zscore_per_win   = p.Results.ZscorePerWindow;
    do_plot_window   = p.Results.DoPlotWindow;
    do_plot_phase    = p.Results.DoPlotPhase;
    refName          = p.Results.RefName;
    predName         = p.Results.PredName;

    if isempty(hop)
        hop = max(1, floor(win_len/2));
    end

    if T < win_len
        error('The data length T=%d is shorter than the window length win_len=%d.', T, win_len);
    end

    if isempty(phase_names) && P > 0
        phase_names = cell(P,1);
        for i = 1:P
            phase_names{i} = sprintf('Phase%d', i);
        end
    elseif ~isempty(phase_names) && numel(phase_names) ~= P
        error('The length of PhaseNames must match the number of rows (P) of phase_windows.');
    end

    % axis names
    axesNames = cell(1,D);
    if D == 3
        tmpAxes = {'X','Y','Z'};
        axesNames = tmpAxes(1:D);
    else
        for d = 1:D
            axesNames{d} = sprintf('Dim%d', d);
        end
    end

    % ===== 1) window-based temporal pattern correlation (role of the previous function) =====
    n_win = floor((T - win_len)/hop) + 1;
    t_center  = nan(n_win, 1);
    r_trial   = nan(n_win, D, N);   % [window x axis x trial]
    r_global  = nan(D, N);          % whole-range r

    % compute the whole-range r (based on the temporal pattern)
    for n = 1:N
        for d = 1:D
            xr = ref_data(:,d,n);
            xp = pred_data(:,d,n);
            v = isfinite(xr) & isfinite(xp);
            if nnz(v) >= 2
                C = corrcoef(xr(v), xp(v));
                if size(C,1) >= 2 && size(C,2) >= 2
                    r_global(d,n) = C(1,2);
                end
            end
        end
    end
    r_global_mean = mean(r_global, 2, 'omitnan').';   % [1 x D]
    r_global_std  = std (r_global, 0, 2, 'omitnan').';% [1 x D]

    % compute the per-window temporal pattern r
    for w = 1:n_win
        idx_start = (w-1)*hop + 1;
        idx_end   = idx_start + win_len - 1;
        t_center(w) = (idx_start + idx_end) / 2;

        for n = 1:N
            seg_ref  = squeeze(ref_data(idx_start:idx_end, :, n));  % [win_len x D]
            seg_pred = squeeze(pred_data(idx_start:idx_end, :, n)); % [win_len x D]

            if size(seg_ref,2) == 1 && D > 1
                seg_ref  = reshape(seg_ref,  win_len, D);
                seg_pred = reshape(seg_pred, win_len, D);
            end

            if zscore_per_win
                for d = 1:D
                    xr = seg_ref(:,d);
                    xp = seg_pred(:,d);

                    mu_r = mean(xr, 'omitnan');
                    sd_r = std (xr, 0, 'omitnan');
                    if sd_r < 1e-12
                        zr = nan(size(xr));
                    else
                        zr = (xr - mu_r) ./ sd_r;
                    end

                    mu_p = mean(xp, 'omitnan');
                    sd_p = std (xp, 0, 'omitnan');
                    if sd_p < 1e-12
                        zp = nan(size(xp));
                    else
                        zp = (xp - mu_p) ./ sd_p;
                    end

                    v = isfinite(zr) & isfinite(zp);
                    if nnz(v) >= 2
                        C = corrcoef(zr(v), zp(v));
                        if size(C,1) >= 2 && size(C,2) >= 2
                            r_trial(w,d,n) = C(1,2);
                        end
                    end
                end
            else
                for d = 1:D
                    xr = seg_ref(:,d);
                    xp = seg_pred(:,d);
                    v = isfinite(xr) & isfinite(xp);
                    if nnz(v) >= 2
                        C = corrcoef(xr(v), xp(v));
                        if size(C,1) >= 2 && size(C,2) >= 2
                            r_trial(w,d,n) = C(1,2);
                        end
                    end
                end
            end
        end
    end

    r_mean = mean(r_trial, 3, 'omitnan');  % [n_win x D]
    r_std  = std (r_trial, 0, 3, 'omitnan'); % [n_win x D]

    % ===== 2) across-trial correlation of the per-phase features =====
    feat_ref  = [];
    feat_pred = [];
    r_phase   = [];
    p_phase   = [];

    if P > 0
        feat_ref  = nan(P, D, N);   % [phase x axis x trial]
        feat_pred = nan(P, D, N);

        for p_idx = 1:P
            s = phase_windows(p_idx,1);
            e = phase_windows(p_idx,2);
            s = max(1, min(T, s));
            e = max(1, min(T, e));
            if e < s
                tmp = s;
                s = e;
                e = tmp;
            end
            frames = s:e;

            for n = 1:N
                seg_ref  = squeeze(ref_data(frames, :, n));  % [len x D]
                seg_pred = squeeze(pred_data(frames, :, n));

                if size(seg_ref,2) == 1 && D > 1
                    seg_ref  = reshape(seg_ref,  [], D);
                    seg_pred = reshape(seg_pred, [], D);
                end

                for d = 1:D
                    xr = seg_ref(:,d);
                    xp = seg_pred(:,d);

                    switch feature_type
                        case 'mean'
                            val_ref  = mean(xr, 'omitnan');
                            val_pred = mean(xp, 'omitnan');
                        case 'max'
                            val_ref  = max(xr);
                            val_pred = max(xp);
                        case 'min'
                            val_ref  = min(xr);
                            val_pred = min(xp);
                        case 'range'
                            val_ref  = max(xr) - min(xr);
                            val_pred = max(xp) - min(xp);
                        case 'std'
                            val_ref  = std(xr, 0, 'omitnan');
                            val_pred = std(xp, 0, 'omitnan');
                        otherwise
                            error('Unsupported FeatureType: %s', feature_type);
                    end

                    feat_ref(p_idx,d,n)  = val_ref;
                    feat_pred(p_idx,d,n) = val_pred;
                end
            end
        end

        r_phase = nan(P,D);
        p_phase = nan(P,D);

        for p_idx = 1:P
            for d = 1:D
                xr = squeeze(feat_ref(p_idx,d,:));   % [N x 1]
                xp = squeeze(feat_pred(p_idx,d,:));  % [N x 1]
                v = isfinite(xr) & isfinite(xp);
                if nnz(v) >= 2
                    C = corrcoef(xr(v), xp(v));
                    if size(C,1) >= 2 && size(C,2) >= 2
                        r_phase(p_idx,d) = C(1,2);
                        p_phase(p_idx,d) = C(1,2); % corrcoef does not give the p value directly, so just use r
                    end
                end
            end
        end
    end

    % ===== assemble the result struct =====
    out = struct();
    out.info = struct();
    out.info.T          = T;
    out.info.D          = D;
    out.info.N          = N;
    out.info.P          = P;
    out.info.axesNames  = axesNames;
    out.info.phaseNames = phase_names;

    out.window = struct();
    out.window.win_len       = win_len;
    out.window.hop           = hop;
    out.window.t_center      = t_center;
    out.window.r_trial       = r_trial;
    out.window.r_mean        = r_mean;
    out.window.r_std         = r_std;
    out.window.r_global      = r_global;
    out.window.r_global_mean = r_global_mean;
    out.window.r_global_std  = r_global_std;

    out.phase = struct();
    out.phase.feature_type = feature_type;
    out.phase.feat_ref     = feat_ref;
    out.phase.feat_pred    = feat_pred;
    out.phase.r_phase      = r_phase;
    out.phase.p_phase      = p_phase;
    out.phase.phase_windows= phase_windows;

    % ===== 3) plot: window-based temporal pattern correlation =====
    if do_plot_window
        figure('Name', sprintf('%s vs %s : Windowed Corr', predName, refName), ...
               'Color','w', 'Position',[200 200 1000 700]);
        tiledlayout(D,1, 'TileSpacing','compact', 'Padding','compact');

        for d = 1:D
            nexttile; hold on; grid on;
            m = r_mean(:,d);
            s = r_std(:,d);

            plot(t_center, m, 'LineWidth', 1.5);
            plot(t_center, m + s, '--', 'LineWidth', 1);
            plot(t_center, m - s, '--', 'LineWidth', 1);

            ylim([-1 1]);
            xlim([t_center(1) t_center(end)]);
            ylabel(sprintf('r (%s)', axesNames{d}));

            if d == 1
                legend({'mean r', 'mean + std', 'mean - std'}, 'Location','best');
                title(sprintf('%s vs %s : windowed correlation', predName, refName));
            else
                title(sprintf('Axis %s', axesNames{d}));
            end
        end

        xlabel('Frame index (window center)');
    end

    % ===== 4) plot: heatmap of the across-trial correlation per phase =====
    if do_plot_phase && P > 0
        figure('Name', sprintf('%s vs %s : Phase-wise Trial Corr', predName, refName), ...
               'Color','w', 'Position',[300 200 700 500]);
        imagesc(r_phase);
        colorbar;
        caxis([-1 1]);
        colormap(jet);
        set(gca, 'XTick', 1:D, 'XTickLabel', axesNames, ...
                 'YTick', 1:P, 'YTickLabel', phase_names, ...
                 'YDir','normal');
        xlabel('Axis');
        ylabel('Phase');
        title(sprintf('Phase-wise trial correlation (feature: %s)', feature_type));

        % print the r value as a number in each cell
        for p_idx = 1:P
            for d = 1:D
                val = r_phase(p_idx,d);
                if isfinite(val)
                    text(d, p_idx, sprintf('%.2f', val), ...
                         'HorizontalAlignment','center', ...
                         'VerticalAlignment','middle', ...
                         'Color','w', 'FontWeight','bold');
                end
            end
        end
    end
end

function out = trial_variability_corr(ref_data, pred_data, varargin)
% trial_variability_corr
%
%   ref_data, pred_data : [T x D x N]
%       T : time frames
%       D : axes (e.g. 3 if there are 3 axes)
%       N : trials
%
%   ref_data  e.g.) mocap_pos (ground truth)
%   pred_data e.g.) imu_pos   (prediction)
%
%   Name-Value options:
%       'PhaseWindows' : [P x 2] each row is [start_frame end_frame] (default [])
%       'PhaseNames'   : cell array of length P (default {'Phase1',...})
%       'SmoothLen'    : moving-average length along time for r(t,d) (odd recommended, default 11)
%       'DoPlotTime'   : whether to plot the per-frame r(t,d) (default true)
%       'DoPlotPhase'  : whether to plot the heatmap of the mean r per phase (default true)
%
%   output struct out:
%       out.T, out.D, out.N
%       out.axesNames           : axis names
%       out.phase_windows       : [P x 2]
%       out.phase_names         : 1 x P cell
%
%       out.r_frame_trial       : [T x D] per-frame across-trial correlation r(t,d)
%       out.r_frame_smooth      : [T x D] moving-average smoothed r(t,d)
%       out.smooth_len          : smoothing length
%
%       out.r_phase_mean        : [P x D] mean r per phase
%       out.r_phase_std         : [P x D] standard deviation of r per phase
%
%   usage example:
%
%     out = trial_variability_corr(mocap_pos, imu_pos, ...
%                'PhaseWindows', [50 150; 151 250; 251 300], ...
%                'PhaseNames',   {'Backswing','Downswing','Impact'}, ...
%                'SmoothLen',    11, ...
%                'DoPlotTime',   true, ...
%                'DoPlotPhase',  true);
%
%   this function
%       1) computes the across-trial correlation r(t,d) at each frame t and axis d,
%       2) smooths it with a moving average along the time axis, then
%       3) computes the mean and standard deviation of r over the given phase ranges.

    % ========== 0) input shape and size check ==========
    if ndims(ref_data) == 2
        ref_data = reshape(ref_data, size(ref_data,1), size(ref_data,2), 1);
    end
    if ndims(pred_data) == 2
        pred_data = reshape(pred_data, size(pred_data,1), size(pred_data,2), 1);
    end

    if ndims(ref_data) ~= 3 || ndims(pred_data) ~= 3
        error('ref_data and pred_data must have shape [T x D x N] (3-D).');
    end

    [T1, D1, N1] = size(ref_data);
    [T2, D2, N2] = size(pred_data);

    if T1 ~= T2 || D1 ~= D2 || N1 ~= N2
        error('ref_data and pred_data must have the same size. (ref: %d x %d x %d, pred: %d x %d x %d)', ...
              T1, D1, N1, T2, D2, N2);
    end

    T = T1; D = D1; N = N1;

    % ========== 1) option parsing ==========
    p = inputParser;
    addParameter(p, 'PhaseWindows', [], @(x) isempty(x) || (isnumeric(x) && size(x,2)==2));
    addParameter(p, 'PhaseNames',   {});
    addParameter(p, 'SmoothLen',    11, @(x) isnumeric(x) && isscalar(x) && x>=1);
    addParameter(p, 'DoPlotTime',   true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'DoPlotPhase',  true, @(x) islogical(x) || isnumeric(x));

    parse(p, varargin{:});

    phase_windows = p.Results.PhaseWindows;
    phase_names   = p.Results.PhaseNames;
    smooth_len    = round(p.Results.SmoothLen);
    do_plot_time  = logical(p.Results.DoPlotTime);
    do_plot_phase = logical(p.Results.DoPlotPhase);

    if mod(smooth_len,2) == 0
        warning('SmoothLen is even. An odd value is recommended for easier interpretation.');
    end

    % ========== 2) set the axis names and phase defaults ==========
    axesNames = cell(1,D);
    if D == 3
        tmpAxes = {'X','Y','Z'};
        axesNames = tmpAxes(1:D);
    else
        for d = 1:D
            axesNames{d} = sprintf('Dim%d', d);
        end
    end

    if isempty(phase_windows)
        P = 0;
    else
        if size(phase_windows,2) ~= 2
            error('PhaseWindows must have shape [P x 2]. Each row is [start_frame end_frame].');
        end
        P = size(phase_windows,1);
    end

    if P > 0
        if isempty(phase_names)
            phase_names = cell(1,P);
            for p_idx = 1:P
                phase_names{p_idx} = sprintf('Phase%d', p_idx);
            end
        elseif numel(phase_names) ~= P
            error('The length of PhaseNames must match the number of rows (P) of PhaseWindows.');
        else
            phase_names = reshape(phase_names,1,[]);
        end
    else
        phase_names = {};
    end

    % ========== 3) compute the per-frame across-trial correlation r_frame_trial(t,d) ==========
    r_frame_trial = nan(T, D);   % [T x D]

    for t = 1:T
        for d = 1:D
            x = squeeze(ref_data(t,d,:));   % [N x 1]
            y = squeeze(pred_data(t,d,:));  % [N x 1]

            v = isfinite(x) & isfinite(y);
            if nnz(v) < 2
                r_frame_trial(t,d) = NaN;
                continue;
            end

            xv = x(v);
            yv = y(v);

            if std(xv) < 1e-12 || std(yv) < 1e-12
                r_frame_trial(t,d) = NaN;
                continue;
            end

            C = corrcoef(xv, yv);
            if size(C,1) >= 2 && size(C,2) >= 2
                r_frame_trial(t,d) = C(1,2);
            else
                r_frame_trial(t,d) = NaN;
            end
        end
    end

    % ========== 4) smooth r(t,d) with a moving average along the time axis ==========
    if smooth_len > 1
        r_frame_smooth = nan(T,D);
        for d = 1:D
            r_frame_smooth(:,d) = movmean(r_frame_trial(:,d), smooth_len, 'omitnan');
        end
    else
        r_frame_smooth = r_frame_trial;
    end

    % ========== 5) compute the mean r per phase (based on the smoothed r) ==========
    if P > 0
        r_phase_mean = nan(P, D);
        r_phase_std  = nan(P, D);

        for p_idx = 1:P
            s = phase_windows(p_idx,1);
            e = phase_windows(p_idx,2);

            % clamp the index range
            s = max(1, min(T, s));
            e = max(1, min(T, e));
            if e < s
                tmp = s; s = e; e = tmp;
            end

            idx = s:e;

            r_phase_mean(p_idx,:) = mean(r_frame_smooth(idx,:), 1, 'omitnan');
            r_phase_std (p_idx,:) = std (r_frame_smooth(idx,:), 0, 1, 'omitnan');
        end
    else
        r_phase_mean = [];
        r_phase_std  = [];
    end

    % ========== 6) assemble the out struct ==========
    out = struct();
    out.T            = T;
    out.D            = D;
    out.N            = N;
    out.axesNames    = axesNames;
    out.phase_windows= phase_windows;
    out.phase_names  = phase_names;

    out.r_frame_trial  = r_frame_trial;
    out.r_frame_smooth = r_frame_smooth;
    out.smooth_len     = smooth_len;

    out.r_phase_mean   = r_phase_mean;
    out.r_phase_std    = r_phase_std;

    % ========== 7) plot 1: per-frame r(t,d) time series ==========
    if do_plot_time
        figure('Color','w', 'Position',[200 200 1000 700]);
        tiledlayout(D,1, 'TileSpacing','compact', 'Padding','compact');

        time_vec = (1:T).';

        for d = 1:D
            nexttile; hold on; grid on;

            h_raw  = plot(time_vec, r_frame_trial(:,d), 'LineWidth',1.5);
            h_smooth = plot(time_vec, r_frame_smooth(:,d), 'LineWidth', 1.5);

            ylim([-1.2 1.2]);
            xlim([1 T]);
            xline(700);
            ylabel(sprintf('r (%s)', axesNames{d}));

            if P > 0
                yL = ylim;
                for p_idx = 1:P
                    s = phase_windows(p_idx,1);
                    e = phase_windows(p_idx,2);
                    s = max(1, min(T, s));
                    e = max(1, min(T, e));
                    if e < s
                        tmp = s; s = e; e = tmp;
                    end
                    patch([s e e s], [yL(1) yL(1) yL(2) yL(2)], ...
                          [0.9 0.9 1.0], 'EdgeColor','none', 'FaceAlpha',0.2);
                end
                uistack(findobj(gca,'Type','line'), 'top');
            end

            if d == 1
                legend([h_raw, h_smooth], {'raw r(t)','smoothed r(t)'}, 'Location','best')
                % legend({'raw r(t)','smoothed r(t)'}, 'Location','best');
                title('Frame-wise trial correlation r(t,d)');
            else
                title(sprintf('Axis %s', axesNames{d}));
            end
        end

        xlabel('Frame index');
    end

    % ========== 8) plot 2: heatmap of the mean r per phase ==========
    if do_plot_phase && P > 0
        figure('Color','w', 'Position',[300 200 700 500]);
        imagesc(r_phase_mean);
        colorbar;
        caxis([-1 1]);
        colormap(jet);

        set(gca, 'XTick', 1:D, 'XTickLabel', axesNames, ...
                 'YTick', 1:P, 'YTickLabel', phase_names, ...
                 'YDir','normal');

        xlabel('Axis');
        ylabel('Phase');
        title(sprintf('Phase-wise mean r (smoothed, window=%d)', smooth_len));

        for p_idx = 1:P
            for d = 1:D
                val = r_phase_mean(p_idx,d);
                if isfinite(val)
                    text(d, p_idx, sprintf('%.2f', val), ...
                         'HorizontalAlignment','center', ...
                         'VerticalAlignment','middle', ...
                         'Color','w', 'FontWeight','bold');
                end
            end
        end
    end
end
