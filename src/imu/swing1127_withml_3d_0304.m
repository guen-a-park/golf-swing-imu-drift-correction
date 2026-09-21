clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

%% data load
load swingData_2508_aftercal_imp+1_est.mat

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;
dark_blue = [40 40 120]/255;

OrientationMethod=7; 

mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
mae_method_vel =0;

mae_list = [];
mae_norm_list = [];
rmse_overall = [];
rmse_norm_list = [];
rmse_xyz_list = [];
rmse_norm_list = [];

error_vellist = [];

add_pos_error_ag_list = [];
imp_pos_error_ag_list = [];
imp_rel_pos_error_ag_list =[];

add_pos_error_prop_list = [];
imp_pos_error_prop_list = [];
imp_rel_pos_error_prop_list =[];

ml_est_list_stat = [];

raddif=[];

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

add_acc_list = [];

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

z = 1;

L_list         = [];   % actual length (motion capture reference)
dL_mocap_list  = [];   % mocap-based radial velocity*dt = L_delta
dL_vidimu_list = [];   % video+IMU-based radial velocity*dt = L_delta_vid
trial_list     = [];

Mtraj_cell = {};
g_cell = {};

mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now

mldataDir2 = fullfile(runsRoot(), 'runs_0224_accgyro_400800_loso3');  % <- fill in the path

purple = [128 0 128]/255;  

nSubj_ml   = 10;                     % number of participants
clubs_ml   = {'driver','iron','fast'};      % middle token of the file name
nRows_ml   = 10; nCols_ml = 3;          % number of rows/columns to use from each file

nTrials    = 10;  % number of trials

ml_est = struct();
for c = 1:numel(clubs_ml)
    ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);  % {trial, subj}
end

ml_est2 = struct();
for c = 1:numel(clubs_ml)
    ml_est2.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est2 = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est2.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
end

%% initialization
point_names = {'add', 'bst', 'imp', 'fin'};
range_names = {'add_to_bst', 'add_to_imp', 'add_to_fin'};

for p = 1:length(point_names)
    pn = point_names{p};
    results.points.(pn).error_xyz_list = [];
    results.points.(pn).error_norm_list = [];
end

for r = 1:length(range_names)
    rn = range_names{r};
    results.ranges.(rn).mae_xyz_list = [];
    results.ranges.(rn).mae_norm_list = [];
    results.ranges.(rn).rmse_xyz_list = [];
    results.ranges.(rn).rmse_norm_list = [];
end

for subj = 1:10
    for club = 1

        fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
        fpath = fullfile(mldataDir, fname);

        fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
        fpath_traj = fullfile(mldataDir, fname_traj);
        if ~isfile(fpath)
            warning('Missing file: %s', fpath);
            continue
        end

        T = readtable(fpath);  % column names are detected automatically if present

        if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
            M = T{:, {'pred_x','pred_y','pred_z'}};
        else
            M = T{:, 1:3};
        end

        m = min(size(M,1), nRows_ml);
        ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);

        T_traj = readtable(fpath_traj);
        unique_trials = unique(T_traj.trial_idx);

        for i = 1:numel(unique_trials)
            trial_traj = unique_trials(i);
            idx = T_traj.trial_idx == trial_traj;
            
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

        
        for trial = 21:30
            if subj==5 && club==3 && trial==5 % IMU recording error
                continue
            elseif subj==9 && club==3 && trial==8 % IMU value comes out NaN
                continue
            elseif subj==8 && club==1 && trial ==30 % magnetometer measurement error
                continue
            elseif subj==2 && club==1 && trial ==10 % IMU recording error
                continue
            elseif subj==6 && club==1 && trial ==3 % IMU recording error
                continue
    
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
            

            
            if g.fin>900
                g.fin = 900;
            end

            
            add_est = g.add_est;
            imp_est = g.imp_est;

            rel_est = imp_est-add_est;

            add_point_list = [add_point_list g.add];
            bst_point_list = [bst_point_list g.bst];
            imp_point_list = [imp_point_list; g.imp];
            fin_point_list = [fin_point_list g.fin];

%% Orientation from marker
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

            

            

            m_cal = magnet; 
            

            
            motionag = g.dl(:,1:3);
            motionag = motionag+ com;

            rel_ag = motionag(g.imp,:)-motionag(g.add,:);

%% derive figure1 3d position
            
            ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);

            add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
            imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
            imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));
            
            add_pos_error_prop =abs_wrist(g.add,:)-add_est;
            imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
            imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);

            ok = true;  % included by default
            
            ok = ok && ~(club==3);
            ok = ok && ~(subj==2 && club==1 && trial==10);
            ok = ok && ~(subj==2 && club==2 && ismember(trial,[23 29]));
            ok = ok && ~(subj==3 && club==2 && ismember(trial,[1 11 14 15]));
            ok = ok && ~(subj==6 && club==1 && trial==3);
            
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
            

            

            Cw = (WristU+WristL)./2;     % center wrist
            Lo = WristL-Cw;             % make center origin
            Mo = WristM-Cw;
            Uo = WristU-Cw;

            wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
            wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
            wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);

            temp_x = Uo./wU; % as I recall the back jitters less than the front % if not, change it later
            vprime_xw = Lo./wL;
            vprime_top = Mo./wM;
            vprime_zw = zeros(length(vprime_xw),3);
            vprime_yw = zeros(length(vprime_xw),3);

            for i = 1:length(vprime_xw)
                vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:)); %1017 revision
            end
            for i = 1:length(vprime_xw)
                vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:)); %1017 revision
            end
            for i = 1:length(vprime_xw)
                vprime_xw(i,:) = cross(vprime_yw(i,:),vprime_zw(i,:));
            end

            for i = 1:length(vprime_xw)
                vprime_xw(i,:)=vprime_xw(i,:) / sqrt(sum(vprime_xw(i,:).^2));
                vprime_yw(i,:)=vprime_yw(i,:) / sqrt(sum(vprime_yw(i,:).^2));
                vprime_zw(i,:)=vprime_zw(i,:) / sqrt(sum(vprime_zw(i,:).^2));
            end

            [dot1, ddot1] = deriv5(Cw(1:length(vprime_xw),1),ts);
            [dot2, ddot2] = deriv5(Cw(1:length(vprime_xw),2),ts);
            [dot3, ddot3] = deriv5(Cw(1:length(vprime_xw),3),ts);
            Cwdot=[dot1(:) dot2(:) dot3(:)];
            Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; %this is the wrist velocity

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
            
            cut_freq = 10;
            [b, a] = butter(3, cut_freq/(200/2));
            WristMdot = filtfilt(b, a, WristMdot);
            WristMddot = filtfilt(b, a, WristMddot);
            WristUdot = filtfilt(b, a, WristUdot);
            Cwdot = filtfilt(b, a, Cwdot);
            Cwddot = filtfilt(b, a, Cwddot);

            

%% local gyro filtering (marker)

            gL_wrist=zeros(length(vprime_xw),3);
            for i=1:length(vprime_xw)
                gL_wrist(i,:) = [-dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                    dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                    -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))]; % *180/pi;
            end

            WristMddot(:,3)=WristMddot(:,3)+9.81;
            R2Lw=zeros(3,3,length(vprime_xw));
            for j = 1:length(vprime_zw)
                R2Lw(:,:,j) = [vprime_xw(j,:)' vprime_yw(j,:)' vprime_zw(j,:)'];
            end
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

            w_global_marker=dcmRot(R2Lw,gL_wrist);

            
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

                    Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
        
                    for t=1:length(time)
                        qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                        if qinf_ref(t,1)<0
                            qinf_ref(t,:)=-qinf_ref(t,:);
                        end
                    end

                case 1
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
                        if qinf_ref(t,1)<0
                            qinf_ref(t,:)=-qinf_ref(t,:);
                        end
                    end

                case 2
                    Rinf = get_orientation_apdm(time, acc_data, gL_wrist, g.add, R2Lw(:,:,g.add));
                    a_dcm = dcmRot(Rinf,acc_data);
                    w_dcm = dcmRot(Rinf,gL_wrist);
        
                    for t=1:length(time)
                        qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
                        if qinf(t,1)<0
                            qinf(t,:)=-qinf(t,:);
                        end
                    end

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

                    acc_norm = norm(acc_global);
                    acc_normalized = acc_global / acc_norm;  % convert to a unit vector
                    ax = acc_normalized(1);
                    ay = acc_normalized(2);
                    az = acc_normalized(3);
                    
                    roll = atan2(ay, az);
                    pitch = atan2(-ax, sqrt(ay^2 + az^2));
                    
                    phi = roll;
                    theta = pitch;

                    mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);

                    
                    mxh =  mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
                    myh =  my.*cos(phi) - mz.*sin(phi);
                    
                    check_mag = sqrt(mxh^2+myh^2);

                    check_mag_list = [check_mag_list check_mag ];

                    
                    psi0_deg = 191.53;
                    alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 7.16 deg
                    yaw_imu_deg = psi0_deg - alpha_deg;
                    yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;

                    
                    psi = deg2rad(yaw_imu_deg);

                    if club==3
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

                    

                    global_frame=[1 0 0;0 1 0;0 0 1];
                    R2tri = Rz*Ry*Rx*global_frame; 

                    Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);
                    a_dcm = dcmRot(Rinf,acc_data);
                    w_dcm = dcmRot(Rinf,gyro_data);

                    for j = 1:length(time)
                        qinf(j,:) = dcm2quatern(Rinf(:,:,j)');
                        if qinf(j,1)<0
                            qinf(j,:)=-qinf(j,:);
                        end
                    end
                    

                    
%% code for the reference
                    Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                    for t=1:length(time)
                        qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                        if qinf_ref(t,1)<0
                            qinf_ref(t,:)=-qinf_ref(t,:);
                        end
                    end

            end   
        
%% trajectory integration

            [dot1, ddot1] = deriv5(abs_wrist(1:length(vprime_xw),1),ts);
            [dot2, ddot2] = deriv5(abs_wrist(1:length(vprime_xw),2),ts);
            [dot3, ddot3] = deriv5(abs_wrist(1:length(vprime_xw),3),ts);
            abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
            abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);

            Mtraj = abs_wrist-abs_wrist(g.add,:);
            Mtraj(1:g.add,:)=0;

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

            Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
            Mvel(1:g.add,:)=0;

            [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);                           % address ~ s.finish
            [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);      % bst ~ s.finish
            raddif=[raddif radM-radMs];
            

            ag_wo_g(:,1) = a_dcm(:,1);
            ag_wo_g(:,2) = a_dcm(:,2);
            ag_wo_g(:,3) = a_dcm(:,3)-9.80665; % should it always be subtracted using the norm?
            ag_wo_g(:,:) = ag_wo_g(:,:).*1000;
            

%% integration in the local frame

            imu_vel= cumtrapz(time,ag_wo_g);
            w_dcm = w_dcm*180/pi;
            angle_cal=cumtrapz(time,w_dcm);
           
            
%% decide whether to zero at the input address

            
            imu_traj=cumtrapz(time,imu_vel);

            imu_vel = imu_vel-imu_vel(g.add,:); %address zeroing

            imu_vel(1:g.add,:)=0; % initial velocity 0
            imu_traj=cumtrapz(time,imu_vel);
            imu_traj=imu_traj-imu_traj(g.add,:);
            

            
            length_idx = g.imp;

            r_hat = abs_wrist(length_idx,:)/norm(abs_wrist(length_idx,:));
            vel_r   = dot(Mvel(length_idx,:), r_hat);          % component along r
            L_delta= vel_r*0.005;

            rw_vid = imp_est;
            r_hat_vid = rw_vid/norm(rw_vid);
            vel_r_vid  = dot(imu_vel(length_idx,:), r_hat_vid);          % component along r

            L_delta_vid = vecnorm(imu_traj(g.imp,:), 2, 2);
            
            L_now = vecnorm(abs_wrist(length_idx,:), 2, 2);

            if all(isfinite([L_now, L_delta, L_delta_vid]))
                L_list(end+1)         = L_now;
                dL_mocap_list(end+1)  = L_delta;
                dL_vidimu_list(end+1) = L_delta_vid;
                if exist('trial','var'), trial_list(end+1) = trial; end
            end

%% velocity singularity correction
            velCalRate=1; %correction coefficient
            imu_velCal =imu_vel;
            

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
            

            imp_est_list = [imp_est_list; rel_est];
           

            diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

            diff_ag = [(imu_trajCal(g.imp,1)-rel_ag(1)) (imu_trajCal(g.imp,2)-rel_ag(2)) (imu_trajCal(g.imp,3)-rel_ag(3))];

            traj_lin = imu_trajCal;                   % copy of the original
            traj_lin_ag = imu_trajCal;

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
            apdm_trajCalV = traj_lin;

            apdm_agcal = traj_lin_ag;
            
%% ML-corrected integration result
            traj_lin_subj = imu_trajCal; 
            

            
%% to obtain ori0 in iron & fast shots
            
  
            if club==3
                diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
            else
                if trial>20
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj); 
                    ml_est_list_stat = [ml_est_list_stat; abs(ref_rel_imp-ml_est.(clubs_ml{club})(trial-20,:,subj))];
                else %dummy value
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(1,:,subj);
                end
            end
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

            
            angle_error_plot = [angle_error_plot angle_error'];
            angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];

            angle_error_q = angle_error(g.add:g.fin);
            angle_error_a2imp = angle_error(g.add:g.imp);
            angle_error_a2bst = angle_error(g.add:g.bst);

            angle_error_add_list = [angle_error_add_list angle_error(g.add)];
            angle_error_bst_list = [angle_error_bst_list angle_error(g.bst)];
            angle_error_imp_list = [angle_error_imp_list angle_error(g.imp)];
            angle_error_fin_list = [angle_error_fin_list angle_error(g.fin)];

            angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
            angle_error_add2imp = [angle_error_add2imp mean(angle_error_a2imp)];
            angle_error_add2bst = [angle_error_add2bst mean(angle_error_a2bst)];

            angle_error_axis = []; % check whether globally aligned
            angle_error_axis_ref = [];

            roll_deg_ref_list = [];
            roll_deg_prop_list = [];

            pitch_deg_ref_list =[];
            pitch_deg_prop_list =[];

            yaw_deg_ref_list =[]; 
            yaw_deg_prop_list =[];

%% check locally aligned, added '
            for i = 1:length(time)
                
                R1 = R2Lw(:,:,i);
                R2 = Rinf(:,:,i);  % example of the second rotation matrix
                R_diff = R2 * R1'; %how much the reference value must be rotated to get the estimate % the angle error can be interpreted directly in the world frame
        
                eul_angles = rotm2eul(R_diff, 'ZYX');
        
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
                R_diff = R2 * R1'; %how much the reference value must be rotated to get the estimate % the angle error can be interpreted directly in the world frame

                eul_angles = rotm2eul(R_diff, 'ZYX');

                roll_error_deg_ref = rad2deg(eul_angles(3));   % x-axis (roll) error
                pitch_error_deg_ref = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg_ref = rad2deg(eul_angles(1));    % z-axis (yaw) error

        
                angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];

                angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];

            end

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

            plot_ds_ml(:,:,z) = ml_traj_check;

            plot_ds_imu(:,:,z) = imu_traj;
            plot_imu_vel(:,:,z) = imu_vel ;
            plot_imu_acc(:,:,z) = ag_wo_g;

            plot_imu_acc_local(:,:,z) = acc_data;

            switch mae_method
                case 0
                    test_drift = imu_traj;
                case 1
                    test_drift = imu_trajCal; %wait, in 3D is this more accurate than apdm_trajCalV?
                case 2
                    test_drift = imu_trajCalL;
                case 3
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
            

%% per-trial execution (inside the loop)

            points_real = struct();
            points_real.add = 351;
            points_real.bst = g.bst;
            points_real.imp = g.imp;
            points_real.fin = 800;
            
            points_method = struct();
            points_method.add = 1;
            points_method.bst = 350 - (g.imp - g.bst);
            points_method.imp = 350;
            points_method.fin = 450;
            
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
                
                mae_xyz = mean(abs(error_range), 1);
                mae_norm = mean(vecnorm(error_range, 2, 2));
                
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
            

            z= z+1;

            
            swingData_2508(subj).clubN(club).trialN(trial).apdm = [ag_wo_g w_dcm acc_data gyro_data];
            swingData_2508(subj).clubN(club).trialN(trial).rel = [rel_est ref_rel_imp rel_ag];
            swingData_2508(subj).clubN(club).trialN(trial).vel_integration = [imu_vel imu_velCal Mvel];
            swingData_2508(subj).clubN(club).trialN(trial).traj_integration = [imu_traj imu_trajCal imu_trajCalL apdm_trajCalV Mtraj apdm_agcal];

        end
    end
end

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

trialCounts = [10 10 10 10 10 10 10 9 10 10];
nSub = numel(trialCounts);

imu_roll_error_list          = imu_roll_error_list(:);
imu_pitch_error_list         = imu_pitch_error_list(:);
imu_yaw_error_newmaglist     = imu_yaw_error_newmaglist(:);

angle_error_q_list           = angle_error_q_list(:);
angle_error_add_list         = angle_error_add_list(:);

angle_error_bst_list         = angle_error_bst_list(:);
angle_error_imp_list         = angle_error_imp_list(:);
angle_error_fin_list         = angle_error_fin_list(:);

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

groupMean_subject = mean(subjMean, 1, 'omitnan');
groupSD_subject   = std(subjMean, 0, 1, 'omitnan');

groupMean_trial = mean(D, 1, 'omitnan');
groupSD_trial   = std(D, 0, 1, 'omitnan');

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

    meanWithin = mean(subjStd_within(:,k), 'omitnan');
    sdWithin   = std(subjStd_within(:,k), 0, 'omitnan');
    fprintf('  (Ref) within-subject SD mean±SD: %.4f ± %.4f\n', meanWithin, sdWithin);
end

fprintf('\n============================================================\n');
fprintf('Done.\n');
fprintf('============================================================\n');

%% significance test between the two methods
S = 10;          % number of participants
T = 10;          % nominal number of trials
N = size(imp_pos_error_prop_list, 1);   % number of rows currently remaining (e.g. 298)

bad_pairs = [
    8 30
];

counts = T * ones(S,1);
for k = 1:size(bad_pairs,1)
    s = bad_pairs(k,1);
    counts(s) = counts(s) - 1;
end

assert(sum(counts) == N, 'The sum of counts (%d) differs from the number of data rows (%d).', sum(counts), N);

subj_id = repelem((1:S)', counts);

A = imp_rel_pos_error_prop_list;   % proposed
B = imp_rel_pos_error_ag_list;     % motionag

S1 = compare_methods( ...
        A, B, ...
        'Name','IMP abs error (mm)', ...
        'Tail','left', ...                 % hypothesis: proposed < motionag
        'Paired',true, ...
        'Group',subj_id, 'BySubject',true, ...
        'Metric','both', 'Test','auto');

disp(S1.axis{1})   % p based on magnitude (norm), effect size, etc.
disp(S1.axis{2})   % p based on magnitude (norm), effect size, etc.
disp(S1.axis{3})   % p based on magnitude (norm), effect size, etc.

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

%% statistics computation and output (after the loop)

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
time = 1:900;

figure(200);
hold on;
grid on;

fill([time, fliplr(time)], [mean_xyz(:,1)' + std_xyz(:,1)', fliplr(mean_xyz(:,1)' - std_xyz(:,1)')], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,1), 'r', 'LineWidth', 1.5);  % mean line

fill([time, fliplr(time)], [mean_xyz(:,2)' + std_xyz(:,2)', fliplr(mean_xyz(:,2)' - std_xyz(:,2)')], 'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,2), 'g', 'LineWidth', 1.5);  % mean line

fill([time, fliplr(time)], [mean_xyz(:,3)' + std_xyz(:,3)', fliplr(mean_xyz(:,3)' - std_xyz(:,3)')], 'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % shaded band
plot(time, mean_xyz(:,3), 'b', 'LineWidth', 1.5);  % mean line
legend('X dev', 'X mean', 'Y dev', 'Y mean', 'Z dev', 'Z mean');
ylabel('Angle error (deg)');
title('3-axis error');
grid on;
xline([g.imp],'-',{'IMP'},'HandleVisibility','off');
xlim([350 850])
ylim([-60 20])

%% works up to here

t = time(:)';          % ensure a row vector
M = mean_xyz;          % [N x 3] proposed method mean
S = std_xyz;           % [N x 3] proposed method std
MR = mean_xyz_ref;     % [N x 3] reference value mean
SR = std_xyz_ref;      % [N x 3] reference value std

assert(size(M,1)==numel(t) && size(M,2)==3, 'mean_xyz size needs checking');
assert(isequal(size(S), size(M)), 'std_xyz size needs checking');
assert(isequal(size(MR), size(M)) && isequal(size(SR), size(S)), 'ref size mismatch');

col_prop = [179 0 25]/255;     % proposed method: red (same for all axes)
col_ref_line = [0 0 0];        % reference value line: black
col_ref_fill = 0.70*[1 1 1];   % reference value shading: gray

alpha_prop = 0.18;             % proposed method shading
alpha_ref  = 0.16;             % reference value shading (a bit lighter)
lw = 1.6;
axisLabel = {'X','Y','Z'};

figure(400); clf; set(gcf,'Color','w'); % no idea why, but it draws properly if fig 200 is opened first
ax = gobjects(3,1);

for i = 1:3
    ax(i) = subplot(3,1,i); hold(ax(i),'on'); grid(ax(i),'on');

    m  = M(:,i)';   s  = S(:,i)';
    mr = MR(:,i)';  sr = SR(:,i)';

    fill(ax(i), [t fliplr(t)], [mr+sr  fliplr(mr-sr)], col_ref_fill, ...
        'FaceAlpha', alpha_ref, 'EdgeColor','none', 'HandleVisibility','off');
    pRef = plot(ax(i), t, mr, '-', 'Color', col_ref_line, 'LineWidth', lw, ...
        'DisplayName','Reference mean');

    fill(ax(i), [t fliplr(t)], [m+s  fliplr(m-s)], col_prop, ...
        'FaceAlpha', alpha_prop, 'EdgeColor','none', 'HandleVisibility','off');
    pProp = plot(ax(i), t, m, '-', 'Color', col_prop, 'LineWidth', lw, ...
        'DisplayName','Proposed mean');

    if exist('g','var') && isfield(g,'imp')
        xline(ax(i), g.imp, '-', 'IMP', 'HandleVisibility','off');
    end

    xlim(ax(i), [350 850]);
    ylabel(ax(i), sprintf('%s (°)', axisLabel{i}));

end

linkaxes(ax,'x');
sgtitle('Angle Error per Axis');
set(ax, 'FontName','Malgun Gothic');  % Korean font (Windows)

plot_ds_ref = plot_ds_ref.*0.1;
plot_ds_prop = plot_ds_prop.*0.1;
plot_ds_imu = plot_ds_imu.*0.1;
plot_ds_driver = plot_ds_driver.*0.1;
plot_ds_driver2 = plot_ds_driver2.*0.1;   % trajectory based on mldataDir2
plot_ds_ag = plot_ds_ag.*0.1;

plot_ds_ml = plot_ds_ml.*0.1;

%% cumulative error graph
%% setup: check the data size/time axis
T = size(plot_ds_ref,1);
if ~exist('time','var') || numel(time)~=T
    time = 1:T;                      % define as 1:T if there is no time axis
end
time = time(:)';                     % unify to a row vector

%% color definitions
col_prop   = [1 0 0];
col_driver = [0 0 1];      % driver: pink (specified value)
col_imu    = [0.7 0.7 0.7];       % imu: dark gray
alphaFill  = 0.18;                   % shading transparency
lw         = 1.6;                    % line width

%% 1) compute the 3D distance error over time (mean ± std)

diff_prop = plot_ds_ref - plot_ds_prop;                 % [T x 3 x N]
err_prop_tt = sqrt(sum(diff_prop.^2, 2));               % [T x 1 x N]
err_prop_tt = squeeze(err_prop_tt);                     % [T x N]
m_prop = mean(err_prop_tt, 2)';                         % [1 x T]
s_prop = std (err_prop_tt, 0, 2)';                      % [1 x T]

diff_driver = plot_ds_ref - plot_ds_driver;             % [T x 3 x N]
err_driver_tt = sqrt(sum(diff_driver.^2, 2));           % [T x 1 x N]
err_driver_tt = squeeze(err_driver_tt);                 % [T x N]
m_driver = mean(err_driver_tt, 2)';                     % [1 x T]
s_driver = std (err_driver_tt, 0, 2)';                  % [1 x T]

diff_imu = plot_ds_ref - plot_ds_imu;                   % [T x 3 x N]
err_imu_tt = sqrt(sum(diff_imu.^2, 2));                 % [T x 1 x N]
err_imu_tt = squeeze(err_imu_tt);                       % [T x N]
m_imu = mean(err_imu_tt, 2)';                           % [1 x T]
s_imu = std (err_imu_tt, 0, 2)';                        % [1 x T]

%% Figure 1: 3D distance error over time (mean ± std, shaded)
figure(2025); clf; hold on; grid on; set(gcf,'Color','w');

p1 = plot(time, m_prop, '-', 'Color', dark_red, 'LineWidth', lw, 'DisplayName','prop');

p2 = plot(time, m_driver, '-', 'Color', dark_green, 'LineWidth', lw, 'DisplayName','driver');

p3 = plot(time, m_imu, '-', 'Color', col_imu, 'LineWidth', lw, 'DisplayName','imu');

set(gca,'FontName','Malgun Gothic');

if exist('g','var') && isfield(g,'imp')
    xline(g.imp,'-','IMP','HandleVisibility','off');
end
xlim([300 800])

%% input: angle_error_plot (T×N), angle_error_plot_ref (T×N)
T = size(angle_error_plot,1);
N = size(angle_error_plot,2);
assert(all(size(angle_error_plot_ref)==[T N]), 'angle_error_plot_ref size mismatch');

if exist('time','var') && numel(time)==T
    t = time(:)';     % row vector
else
    t = 1:T;
end

col_prop     = [1 0 0];          % proposed method: red
col_ref_line = [0 0 0];          % reference value line: black
col_ref_fill = 0.70*[1 1 1];     % reference value shading: gray
alpha_prop   = 0.18;             % shading transparency (proposed method)
alpha_ref    = 0.16;             % shading transparency (reference value)
lw = 1.6;

%% 1) over time (mean±SD)
m_prop = mean(angle_error_plot,     2)';   % [1×T]
s_prop = std (angle_error_plot, 0,  2)';   % [1×T]
m_ref  = mean(angle_error_plot_ref, 2)';   % [1×T]
s_ref  = std (angle_error_plot_ref, 0,  2)';

figure(401); clf; hold on; grid on; set(gcf,'Color','w');

fill([t fliplr(t)], [m_ref+s_ref  fliplr(m_ref-s_ref)], col_ref_fill, ...
     'FaceAlpha', alpha_ref, 'EdgeColor','none', 'HandleVisibility','off');
pRef  = plot(t, m_ref,  '-', 'Color', col_ref_line, 'LineWidth', lw, 'DisplayName','Reference');

fill([t fliplr(t)], [m_prop+s_prop fliplr(m_prop-s_prop)], col_prop, ...
     'FaceAlpha', alpha_prop, 'EdgeColor','none', 'HandleVisibility','off');
pProp = plot(t, m_prop, '-', 'Color', col_prop,     'LineWidth', lw, 'DisplayName','Proposed');

if exist('g','var') && isfield(g,'imp'), xline(g.imp,'-','IMP','HandleVisibility','off'); end
xlabel('Time (samples)'); ylabel('Angle error (deg)');
xlim([350 850])
set(gca,'FontName','Malgun Gothic');

ref_mean_x = mean(plot_ds_ref(:, 1, :), 3); % x-axis mean
ref_std_x = std(plot_ds_ref(:, 1, :), 0, 3); % x-axis standard deviation

ref_mean_y = mean(plot_ds_ref(:, 2, :), 3); % y-axis mean
ref_std_y = std(plot_ds_ref(:, 2, :), 0, 3); % y-axis standard deviation

ref_mean_z = mean(plot_ds_ref(:, 3, :), 3); % z-axis mean
ref_std_z = std(plot_ds_ref(:, 3, :), 0, 3); % z-axis standard deviation
proposed_mean_x = mean(plot_ds_prop(:, 1, :), 3); % x-axis mean
proposed_std_x = std(plot_ds_prop(:, 1, :), 0, 3); % x-axis standard deviation

proposed_mean_y = mean(plot_ds_prop(:, 2, :), 3); % y-axis mean
proposed_std_y = std(plot_ds_prop(:, 2, :), 0, 3); % y-axis standard deviation

proposed_mean_z = mean(plot_ds_prop(:, 3, :), 3); % z-axis mean
proposed_std_z = std(plot_ds_prop(:, 3, :), 0, 3); % z-axis standard deviation
imu_mean_x = mean(plot_ds_imu(:, 1, :), 3); % x-axis mean
imu_std_x = std(plot_ds_imu(:, 1, :), 0, 3); % x-axis standard deviation

imu_mean_y = mean(plot_ds_imu(:, 2, :), 3); % y-axis mean
imu_std_y = std(plot_ds_imu(:, 2, :), 0, 3); % y-axis standard deviation

imu_mean_z = mean(plot_ds_imu(:, 3, :), 3); % z-axis mean
imu_std_z = std(plot_ds_imu(:, 3, :), 0, 3); % z-axis standard deviation

driver_mean_x = mean(plot_ds_driver(:, 1, :), 3); % x-axis mean
driver_std_x = std(plot_ds_driver(:, 1, :), 0, 3); % x-axis standard deviation

driver_mean_y = mean(plot_ds_driver(:, 2, :), 3); % y-axis mean
driver_std_y = std(plot_ds_driver(:, 2, :), 0, 3); % y-axis standard deviation

driver_mean_z = mean(plot_ds_driver(:, 3, :), 3); % z-axis mean
driver_std_z = std(plot_ds_driver(:, 3, :), 0, 3); % z-axis standard deviation

ml_mean_x = mean(plot_ds_ml(:, 1, :), 3); % x-axis mean
ml_std_x = std(plot_ds_ml(:, 1, :), 0, 3); % x-axis standard deviation

ml_mean_y = mean(plot_ds_ml(:, 2, :), 3); % y-axis mean
ml_std_y = std(plot_ds_ml(:, 2, :), 0, 3); % y-axis standard deviation

ml_mean_z = mean(plot_ds_ml(:, 3, :), 3); % z-axis mean
ml_std_z = std(plot_ds_ml(:, 3, :), 0, 3); % z-axis standard deviation

%% graph checking the +/- correlation relative to the mean % a single event point

out = viz_mean_z_at_frame(plot_ds_ref, plot_ds_prop, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'Proposed', ...
    'RefName', 'Ground Truth', ...
    'Color', dark_red);

out.abs

out = viz_mean_z_at_frame(plot_ds_prop, plot_ds_driver, imp_point_list, ...
    'Mode', 'abs', ...
    'PredName', 'ML', ...
    'RefName', 'Proposed', ...
    'Color', dark_red);
out.abs

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

%% path length %%%%%%%%%%%%%

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

figure(1000);
hold on;

pink = dark_red;

subplot(3, 1, 1);
hold on;
plot(ref_mean_x, 'k', 'LineWidth', 1.5); % reference value mean
plot(proposed_mean_x,'LineWidth',1.5,'Color', pink); % proposed method mean

plot(imu_mean_x, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)

plot(driver_mean_x, 'Color', dark_green, 'LineWidth', 1.5); % reference value mean

ylabel('X-axis');
xlim([300 800])
hold off;

subplot(3, 1, 2);
hold on;
plot(ref_mean_y, 'k', 'LineWidth', 1.5); % reference value mean
plot(proposed_mean_y, 'LineWidth', 1.5,'Color', pink); % proposed method mean

plot(imu_mean_y, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%'LineStyle', '--'); % dark gray (plot)

plot(driver_mean_y,'Color', dark_green, 'LineWidth', 1.5); % reference value mean

xlim([300 800])
ylabel('Y-axis');

hold off;

subplot(3, 1, 3);
hold on;
plot(ref_mean_z, 'k', 'LineWidth', 1.5); % reference value mean
plot(proposed_mean_z,'LineWidth', 1.5,'Color',pink); % proposed method mean

plot(imu_mean_z, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);%,'LineStyle', '--'); % dark gray (plot)
plot(driver_mean_z, 'Color', dark_green, 'LineWidth', 1.5); % reference value mean

xlim([300 800])
ylabel('Z-axis');

hold off;

start_idx = 351;
end_idx = 800;

figure(2028);
pink = dark_red;

t_plot = 1:(end_idx - start_idx + 1);  % x axis starting from 1
range_ref = start_idx:end_idx;          % for data indexing
t_ml = 1:length(ml_mean_x);

subplot(3, 1, 1);
hold on;
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_x(range_ref) + ref_std_x(range_ref); flipud(ref_mean_x(range_ref) - ref_std_x(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_x(range_ref), 'k', 'LineWidth', 1.5);
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_x(range_ref) + driver_std_x(range_ref); flipud(driver_mean_x(range_ref) - driver_std_x(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_x(range_ref), 'Color', pink, 'LineWidth', 1.5);
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_x + ml_std_x; flipud(ml_mean_x - ml_std_x)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_x, 'Color', dark_green, 'LineWidth', 1.5);

xlim([1 450])

ylabel('X-axis');
hold off;

subplot(3, 1, 2);
hold on;
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_y(range_ref) + ref_std_y(range_ref); flipud(ref_mean_y(range_ref) - ref_std_y(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_y(range_ref), 'k', 'LineWidth', 1.5);
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_y(range_ref) + driver_std_y(range_ref); flipud(driver_mean_y(range_ref) - driver_std_y(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_y(range_ref), 'Color', pink, 'LineWidth', 1.5);
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_y + ml_std_y; flipud(ml_mean_y - ml_std_y)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_y, 'Color', dark_green, 'LineWidth', 1.5);
xlim([1 450])

ylabel('Y-axis');
hold off;

subplot(3, 1, 3);
hold on;
fill([t_plot, fliplr(t_plot)], ...
    [ref_mean_z(range_ref) + ref_std_z(range_ref); flipud(ref_mean_z(range_ref) - ref_std_z(range_ref))], ...
    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, ref_mean_z(range_ref), 'k', 'LineWidth', 1.5);
fill([t_plot, fliplr(t_plot)], ...
    [driver_mean_z(range_ref) + driver_std_z(range_ref); flipud(driver_mean_z(range_ref) - driver_std_z(range_ref))], ...
    pink, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_plot, driver_mean_z(range_ref), 'Color', pink, 'LineWidth', 1.5);
fill([t_ml, fliplr(t_ml)], ...
    [ml_mean_z + ml_std_z; flipud(ml_mean_z - ml_std_z)], ...
    dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(t_ml, ml_mean_z, 'Color', dark_green, 'LineWidth', 1.5);

xlim([1 450])

ylabel('Z-axis');
hold off;

trials_per_subj = [10 10 10 10 10 10 10 9 10 10];   % length = num_subjects
num_subjects   = 10;
Ntotal         = size(plot_ds_ref, 3);
assert(sum(trials_per_subj) == Ntotal, ...
       'The sum of trials_per_subj differs from the 3rd-dimension size of plot_ds_ref.');

trial_subj_ids = zeros(1, Ntotal);
idx = 1;
for s = 1:num_subjects
    n_tr = trials_per_subj(s);
    trial_subj_ids(idx:idx+n_tr-1) = s;
    idx = idx + n_tr;
end

assert(all([size(plot_ds_prop,3), size(plot_ds_imu,3)] == Ntotal), ...
       'The 3rd-dimension sizes of ref/prop/imu differ.');

figure(10000); clf; hold on;
colors = turbo(20);
[x_sphere, y_sphere, z_sphere] = sphere(20);
scale_factor = 1;

ref_means  = nan(num_subjects,3); ref_stds  = nan(num_subjects,3);
imu_means  = nan(num_subjects,3); imu_stds  = nan(num_subjects,3);
prop_means = nan(num_subjects,3); prop_stds = nan(num_subjects,3);

for subj = 1:num_subjects
    idx_subj = find(trial_subj_ids == subj);   % 1 x N_subj
    if isempty(idx_subj)
        fprintf('  [WARN] Subject %d has no trials. Skip.\n', subj);
        continue;
    end

    ref_data_subj = squeeze(plot_ds_ref(g.imp, :, idx_subj)).';      % g.imp frame
    prop_data_subj = squeeze(plot_ds_prop(g.imp, :, idx_subj)).';
    imu_data_subj  = squeeze(plot_ds_driver (g.imp, :, idx_subj)).';

    ref_mean  = mean(ref_data_subj, 1); ref_std  = std(ref_data_subj,0,1);
    imu_mean  = mean(imu_data_subj,  1); imu_std  = std(imu_data_subj,0,1);
    prop_mean = mean(prop_data_subj, 1); prop_std = std(prop_data_subj,0,1);

    ref_means(subj,:)  = ref_mean;  ref_stds(subj,:)  = ref_std;
    imu_means(subj,:)  = imu_mean;  imu_stds(subj,:)  = imu_std;
    prop_means(subj,:) = prop_mean; prop_stds(subj,:) = prop_std;

    curr_color = colors(subj, :);

    scatter3(ref_data_subj(:,1), ref_data_subj(:,2), ref_data_subj(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 0.3);

    surf(x_sphere*ref_std(1)*scale_factor + ref_mean(1), ...
         y_sphere*ref_std(2)*scale_factor + ref_mean(2), ...
         z_sphere*ref_std(3)*scale_factor + ref_mean(3), ...
         'FaceColor', curr_color, 'FaceAlpha', 0.1, 'EdgeColor','none');

    scatter3(ref_mean(1), ref_mean(2), ref_mean(3), 100, curr_color, ...
             'filled','MarkerEdgeColor','k','LineWidth',1,'MarkerFaceAlpha',0.3);
    text(ref_mean(1), ref_mean(2),ref_mean(3), sprintf('%d',subj), 'FontSize',9, ...
     'FontWeight','bold','Color','k','HorizontalAlignment','center', ...
     'VerticalAlignment','bottom','Clipping','on');

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

stats = struct();

stats.ref.mean_of_means = mean(ref_means, 1, 'omitnan');
stats.ref.std_of_means  = std (ref_means, 0, 1, 'omitnan');
stats.ref.mean_of_stds  = mean(ref_stds,  1, 'omitnan');
stats.ref.std_of_stds   = std (ref_stds,  0, 1, 'omitnan');

stats.imu.mean_of_means = mean(imu_means, 1, 'omitnan');
stats.imu.std_of_means  = std (imu_means, 0, 1, 'omitnan');
stats.imu.mean_of_stds  = mean(imu_stds,  1, 'omitnan');
stats.imu.std_of_stds   = std (imu_stds,  0, 1, 'omitnan');

stats.prop.mean_of_means = mean(prop_means, 1, 'omitnan');
stats.prop.std_of_means  = std (prop_means, 0, 1, 'omitnan');
stats.prop.mean_of_stds  = mean(prop_stds,  1, 'omitnan');
stats.prop.std_of_stds   = std (prop_stds,  0, 1, 'omitnan');

disp(stats.ref)
disp(stats.imu)
disp(stats.prop)

%% check the consistency correlation
epsv = 1e-9;

ratio_prop = prop_stds ./ max(ref_stds, epsv);   % [S x 3]
ratio_imu  = imu_stds  ./ max(ref_stds, epsv);   % [S x 3]

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

figure(20000);
hold on;

ref_data = squeeze(plot_ds_ref(g.imp, :, :))';   % convert to a 120x3 matrix
prop_data = squeeze(plot_ds_prop(g.imp, :, :))'; % convert to a 120x3 matrix
driver_data = squeeze(plot_ds_driver(g.imp, :, :))'; % convert to a 120x3 matrix

mtraj_mean = mean(ref_data, 1);    % 1x3 vector (mean of the 120 points)
mtraj_std = std(ref_data, 0, 1);   % 1x3 vector (standard deviation of the 120 points)

apdm_mean = mean(prop_data, 1);    % 1x3 vector
apdm_std = std(prop_data, 0, 1);   % 1x3 vector

driver_data_mean = mean(driver_data, 1);    % 1x3 vector
driver_data_std = std(driver_data, 0, 1);   % 1x3 vector

scatter3(ref_data(:,1), ref_data(:,2), ref_data(:,3), ...
         50, 'k', 'filled');
scatter3(prop_data(:,1), prop_data(:,2), prop_data(:,3), ...
         50, dark_red, 'filled');
scatter3(driver_data(:,1), driver_data(:,2), driver_data(:,3), ...
         50, dark_green, 'filled');

[x_sphere, y_sphere, z_sphere] = sphere(20);

surf(x_sphere*mtraj_std(1) + mtraj_mean(1), ...
     y_sphere*mtraj_std(2) + mtraj_mean(2), ...
     z_sphere*mtraj_std(3) + mtraj_mean(3), ...
     'FaceColor', 'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

surf(x_sphere*apdm_std(1) + apdm_mean(1), ...
     y_sphere*apdm_std(2) + apdm_mean(2), ...
     z_sphere*apdm_std(3) + apdm_mean(3), ...
     'FaceColor', dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

surf(x_sphere*driver_data_std(1) + driver_data_mean(1), ...
     y_sphere*driver_data_std(2) + driver_data_mean(2), ...
     z_sphere*driver_data_std(3) + driver_data_mean(3), ...
     'FaceColor', dark_green, 'FaceAlpha', 0.2, 'EdgeColor', 'none');

scatter3(mtraj_mean(1), mtraj_mean(2), mtraj_mean(3), ...
         200, 'k', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
scatter3(apdm_mean(1), apdm_mean(2), apdm_mean(3), ...
         200, dark_red, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
scatter3(driver_data_mean(1), driver_data_mean(2), driver_data_mean(3), ...
         200, dark_green, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);

xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');

grid on;
view(90,0);
axis equal;  % so the ellipsoid is not distorted

%% statistical significance code
function out = compare_methods(A, B, varargin)

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
        [A,B] = aggregate_by_group(A,B,opt.Group,@mean);
    end

    D = size(A,2);
    out = struct('name',opt.Name,'N',size(A,1),'options',opt);

    if any(strcmpi(opt.Metric, {'both','mag'}))
        Am = sqrt(sum(A.^2,2));  Bm = sqrt(sum(B.^2,2));
        out.mag = run_test(Am, Bm, opt);
        out.mag.label = sprintf('%s | MAG', opt.Name);
    end

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
        n1=numel(A); n2=numel(B);
        [useT, ~] = normal_decision([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;                 % Cohen's d
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;
        else
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

disp('correction coefficient mean&SD')
mean(apdm_biasV_list)

function nrmse = NRMSE_range(measured, truev)
E = measured - truev;                 % [N x 3]
rmse_xyz = sqrt(mean(E.^2, 1));       % [1 x 3]
den = range(truev, 1);                % [1 x 3]  (max-min, per column)
den(den==0) = eps;                    % guard against a zero denominator
nrmse = rmse_xyz ./ den;              % [1 x 3]
end

function S = cvabs_between_ts_timeAxesTrials(X, idx)

    if nargin < 2 || isempty(idx)
        idx = 1:size(X,1);
    end

    Xsel = X(idx, :, :);                       % [nTimeSel x nAxes x nTrials]

    std_trials      = std( Xsel, 0, 3, 'omitnan');    % [nTimeSel x nAxes]
    mean_trials     = mean(Xsel,    3, 'omitnan');    % [nTimeSel x nAxes] (for reference: sign preserved)
    mean_abs_trials = mean(abs(Xsel),3, 'omitnan');   % [nTimeSel x nAxes] (CVabs denominator)

    CVabs_between_ts_pct      = 100 * (std_trials ./ max(mean_abs_trials, eps));  % [nTimeSel x nAxes]
    CVabs_between_ts_mean_pct = mean(CVabs_between_ts_pct, 1, 'omitnan');         % [1 x nAxes]

    R = squeeze( sqrt(sum(Xsel.^2, 2)) );      % [nTimeSel x nTrials]
    sd_R  = std(R, 0, 2, 'omitnan');           % [nTimeSel x 1]
    muA_R = mean(abs(R), 2, 'omitnan');        % [nTimeSel x 1]
    CVabs_between_ts_mag_pct      = 100 * (sd_R ./ max(muA_R, eps));              % [nTimeSel x 1]
    CVabs_between_ts_mag_mean_pct = mean(CVabs_between_ts_mag_pct, 'omitnan');    % 1x1

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

    N = size(ref_data, 3);  % number of trials
    
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

    ref_mu  = mean(ref_vals,  1, 'omitnan');
    ref_std = std (ref_vals,  0, 1, 'omitnan');
    p_mu    = mean(pred_vals, 1, 'omitnan');
    p_std   = std (pred_vals, 0, 1, 'omitnan');

    den_ref = ref_std;
    den_ref(den_ref < 1e-12) = NaN;
    den_p   = p_std;
    den_p  (den_p   < 1e-12) = NaN;
    z_ref   = (ref_vals  - ref_mu) ./ den_ref;
    z_pred  = (pred_vals - p_mu)   ./ den_p;
    std_ratio = p_std ./ ref_std;

    d_ref  = ref_vals  - ref_mu;
    d_pred = pred_vals - p_mu;

    axesNames = {'X','Y','Z'};
    
    if isempty(userColor)
        clr = lines(3);
    else
        clr = repmat(userColor(:)', 3, 1);
    end

    out = struct();

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

            xlim([-30 30]); ylim([-30 30]);

            
            
            xlabel(sprintf('%s %s (cm)', refName, axesNames{d}));
            ylabel(sprintf('%s %s (cm)', predName, axesNames{d}));
            
            hold off;
            
            filename = sprintf('%s_vs_%s_abs_%s.svg', predName, refName, axesNames{d});
            saveas(gcf, filename);
        end
    end
end

function out = viz_mean_z_at_frame_group(ref_data, pred_data, frame_idx, group, varargin)

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

    group = group(:);
    if numel(group) ~= N
        error('The group length (%d) differs from the number of trials N (%d).', numel(group), N);
    end
    subj_ids = unique(group);
    Ng = numel(subj_ids);

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

    ref_mu  = mean(ref_vals,  1, 'omitnan');
    ref_std = std (ref_vals,  0, 1, 'omitnan');
    p_mu    = mean(pred_vals, 1, 'omitnan');
    p_std   = std (pred_vals, 0, 1, 'omitnan');

    den_ref = ref_std;
    den_ref(den_ref < 1e-12) = NaN;
    den_p   = p_std;
    den_p  (den_p   < 1e-12) = NaN;
    z_ref   = (ref_vals  - ref_mu) ./ den_ref;
    z_pred  = (pred_vals - p_mu)   ./ den_p;
    std_ratio = p_std ./ ref_std;

    d_ref  = ref_vals  - ref_mu;
    d_pred = pred_vals - p_mu;

    axesNames = {'X','Y','Z'};
    margin_reg = 0.1;  % margin ratio for the regression line length

    if isempty(userColor)
        clr = lines(3);
    else
        clr = repmat(userColor(:)', 3, 1);
    end

    cmap_subj = lines(max(Ng, 3));

    out = struct();

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

            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.z.r(d) = rval; out.z.p(d) = pval;
            end

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

            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.mean.r(d) = rval; out.mean.p(d) = pval;
            end

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

            if numel(x_all) >= 2
                [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
                out.abs.r(d) = rval; out.abs.p(d) = pval;
            end

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
            xlabel(sprintf('%s %s (cm)', refName, axesNames{d}));
            ylabel(sprintf('%s %s (cm)', predName, axesNames{d}));
            hold off;

            filename = sprintf('%s_vs_%s_abs_%s_group.svg', predName, refName, axesNames{d});
            saveas(gcf, filename);
        end
    end

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

    p = inputParser;
    addParameter(p,'PredName','PROP');
    addParameter(p,'RefName','REF');
    parse(p,varargin{:});
    predName = p.Results.PredName;
    refName  = p.Results.RefName;

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

    group = group(:);
    if numel(group) ~= N
        error('The group length (%d) differs from the number of trials N (%d).', numel(group), N);
    end
    subj_ids = unique(group);   % unique participant IDs
    Ng = numel(subj_ids);       % number of participants

    ref_vals  = squeeze(ref_data (frame_idx,:,:)).';   % N x 3
    pred_vals = squeeze(pred_data(frame_idx,:,:)).';   % N x 3

    axesNames = {'X','Y','Z'};
    cmap = lines(max(Ng,3));    % per-participant color
    margin = 0.1;               % margin ratio for the regression line length

    out = struct();
    out.slope_subj     = nan(Ng, 3);   % [subject x axis]
    out.intercept_subj = nan(Ng, 3);
    out.slope_mean     = nan(1, 3);
    out.r_all          = nan(1, 3);
    out.p_all          = nan(1, 3);

    figure('Name', sprintf('%s vs %s (per-subject regression)', predName, refName), ...
           'Color','w', 'Position',[200 200 1900 650]);
    tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

    for d = 1:3
        nexttile; hold on; grid on; axis equal;

        x_all = ref_vals(:,d);
        y_all = pred_vals(:,d);
        v = isfinite(x_all) & isfinite(y_all);
        x_all = x_all(v);
        y_all = y_all(v);
        g_all = group(v);

        scatter(x_all, y_all, 50, ...
                'filled', ...
                'MarkerFaceColor',[0.7 0.7 0.7], ...
                'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',0.4);

        if numel(x_all) >= 2
            [rval, pval] = corr(x_all, y_all, 'Type','Pearson');
            out.r_all(d) = rval;
            out.p_all(d) = pval;
        end

        mx  = max(abs([x_all; y_all]));
        lim = max( max(1, round(mx)), 1 );
        plot([-lim lim], [-lim lim], 'k--', 'LineWidth', 1);  % 1:1 line

        for si = 1:Ng
            sid = subj_ids(si);
            m = (g_all == sid);
            xg = x_all(m); yg = y_all(m);

            if numel(xg) >= 2 && std(xg)>0
                pfit = polyfit(xg, yg, 1);

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

        out.slope_mean(d) = mean(out.slope_subj(:,d), 'omitnan');

        xlim([-lim lim]); ylim([-lim lim]);
        xlabel(sprintf('%s (%s)', refName,  axesNames{d}));
        ylabel(sprintf('%s (%s)', predName, axesNames{d}));
        title(sprintf('%s | r(all)=%.2f, p=%.3g | mean slope=%.2f', ...
              axesNames{d}, out.r_all(d), out.p_all(d), out.slope_mean(d)));
    end

    sgtitle(sprintf('Frame %d : %s vs %s (per-subject regression)', ...
            frame_idx, predName, refName), 'FontWeight','bold');

    fprintf('\n[Raw ref vs prop] mean slope per axis (X/Y/Z): %.3f  %.3f  %.3f\n\n', ...
            out.slope_mean(1), out.slope_mean(2), out.slope_mean(3));
end

function out = viz_window_corr_trials(ref_data, pred_data, varargin)

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

    n_win = floor((T - win_len)/hop) + 1;

    r_trial  = nan(n_win, D, N);   % [window x axis x trial]
    t_center = nan(n_win, 1);

    for w = 1:n_win
        idx_start = (w-1)*hop + 1;
        idx_end   = idx_start + win_len - 1;
        t_center(w) = (idx_start + idx_end) / 2;

        for n = 1:N
            seg_ref  = squeeze(ref_data(idx_start:idx_end, :, n));
            seg_pred = squeeze(pred_data(idx_start:idx_end, :, n));

            if size(seg_ref,2) == 1 && D > 1
                seg_ref  = reshape(seg_ref,  win_len, D);
                seg_pred = reshape(seg_pred, win_len, D);
            end

            if do_zscore
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
end

function out = analyze_variability_and_pattern(ref_data, pred_data, phase_windows, varargin)

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

    axesNames = cell(1,D);
    if D == 3
        tmpAxes = {'X','Y','Z'};
        axesNames = tmpAxes(1:D);
    else
        for d = 1:D
            axesNames{d} = sprintf('Dim%d', d);
        end
    end

    n_win = floor((T - win_len)/hop) + 1;
    t_center  = nan(n_win, 1);
    r_trial   = nan(n_win, D, N);   % [window x axis x trial]
    r_global  = nan(D, N);          % whole-range r

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

    if smooth_len > 1
        r_frame_smooth = nan(T,D);
        for d = 1:D
            r_frame_smooth(:,d) = movmean(r_frame_trial(:,d), smooth_len, 'omitnan');
        end
    else
        r_frame_smooth = r_frame_trial;
    end

    if P > 0
        r_phase_mean = nan(P, D);
        r_phase_std  = nan(P, D);

        for p_idx = 1:P
            s = phase_windows(p_idx,1);
            e = phase_windows(p_idx,2);

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
                title('Frame-wise trial correlation r(t,d)');
            else
                title(sprintf('Axis %s', axesNames{d}));
            end
        end

        xlabel('Frame index');
    end

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
