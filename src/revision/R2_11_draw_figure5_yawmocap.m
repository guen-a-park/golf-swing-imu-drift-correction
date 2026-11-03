%% [R2r2-11] R2_11_draw_figure5_yawmocap.m
%  src/figures/draw_figure5.m run with the initial heading aligned to motion capture and the model trained under that condition (runs_R2_08_ori8_seed5); gives the agreement rates of Figure 6.
%  Output : correlation_fold_<n>.mat

clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

R2_11_thisDir = fileparts(mfilename('fullpath'));
addpath(fileparts(R2_11_thisDir));
addpath(genpath(fullfile(fileparts(fileparts(R2_11_thisDir)), 'GolfSwing_0424')));

load swingData_2508_aftercal_imp+1_est.mat

apdm_rate = 200;
cut_freq = 15;

idx_fast_draw = 5;

highlight_subj = 3;
subj_select = 8;
trial_select = 5;

plot_x_start = 266;
plot_x_end = 880;

ml_start_ref = 401;
ml_end_ref = 800;
gray_bar = [0.5 0.5 0.5];

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [0 80 0]/255;
dark_red   = [128 0 32]/255;

dark_purple = [102 51 153]/255;
purple = [128 0 128]/255;
soft_purple = [0.749, 0.502, 0.749];

dark_blue = [0,127,255] / 255;
pink = [255,164,179]/255;

purple = [100, 149, 237] / 255;

OrientationMethod=7;

mae_method =5;
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

raddif=[];

angle_error_q_list = [];
angle_error_add_list = [];
angle_error_add2imp = [];
angle_error_plot =[];
angle_error_plot_ref = [];

add_acc_list = [];

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

L_list         = [];
dL_mocap_list  = [];
dL_vidimu_list = [];
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

mldataDir = fullfile(runsRoot(), 'runs_R2_08_ori8_seed5');

fold_num = str2double(mldataDir(end));
if isnan(fold_num)
    fold_num = 5;
end
fprintf('current fold number: %d\n', fold_num);

nSubj_ml   = 10;
clubs_ml   = {'driver','iron','fast'};
nRows_ml   = 10; nCols_ml = 3;

nTrials    = 10;

ml_est = struct();
for c = 1:numel(clubs_ml)
    ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
end

ml_traj_est = struct();
for c = 1:numel(clubs_ml)
    ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
end

nsigma = 2;

start_idx = 421;
end_idx   = 700;

n_per_subject_fast = [10, 10, 10,10,9,10,10,10,9,10];

n_per_subject_ref  = [10, 10, 10,10,10,10,10,9,10,10];

event_shade_color = [0.25 0.25 0.25];
event_shade_alpha = 0.4;

num_subjects = length(n_per_subject_fast);

for subj_fast =1:10
    z = 1;
    for subj = subj_fast
        for club = 1

            fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
            fpath = fullfile(mldataDir, fname);
            if ~isfile(fpath)
                warning('Missing file: %s', fpath);
                continue
            end

            fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
            fpath_traj = fullfile(mldataDir, fname_traj);

            T = readtable(fpath);
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
                ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;
            end

            for trial = 21:30
                if subj==1 && club==2 && trial ==1
                    continue
                elseif subj==5 && club==3 && trial==5
                    continue
                elseif subj==8 && club==1 && trial ==30
                    continue
                end

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

                backswing_ref = g.bst-g.add;
                downswing_ref = g.imp-g.bst;
                swing_tempo_ref = backswing_ref/downswing_ref;
                swing_tempo_ref_list = [swing_tempo_ref_list swing_tempo_ref];

                time_start_idx =  g.add;
                time_end_idx = g.fin;
                swing_time_normal = time_end_idx-time_start_idx;
                swing_time_normal_list = [swing_time_normal_list swing_time_normal];

                WristU = g.marker(:,13:15);
                WristM = g.marker(:,10:12);
                WristL = g.marker(:,7:9);
                acc_data = g.apdm(:,1:3);
                gyro_data = g.apdm(:,4:6);
                magnet = g.apdm(:,7:9);
                abs_wrist = (WristU+WristL)./2;
                rias = g.marker(:,1:3);
                lias = g.marker(:,4:6);
                com = (rias+lias)./2;

                m_cal = magnet;

                add_est = g.add_est;
                imp_est = g.imp_est;

                rel_est = imp_est - add_est;

                motionag = g.dl(:,1:3);
                motionag = motionag+ com;

                ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);

                add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
                imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
                imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));

                add_pos_error_prop =abs_wrist(g.add,:)-add_est;
                imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
                imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);

                ok = true;

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

                Cw = (WristU+WristL)./2;
                Lo = WristL-Cw;
                Mo = WristM-Cw;
                Uo = WristU-Cw;

                wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
                wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
                wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);

                temp_x = Uo./wU;
                vprime_xw = Lo./wL;
                vprime_top = Mo./wM;
                vprime_zw = zeros(length(vprime_xw),3);
                vprime_yw = zeros(length(vprime_xw),3);

                for i = 1:length(vprime_xw)
                    vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:));
                end
                for i = 1:length(vprime_xw)
                    vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:));
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
                Cwddot=[ddot1(:) ddot2(:) ddot3(:)];

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

                gL_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    gL_wrist(i,:) = [-dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                        dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                        -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))];
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

                switch OrientationMethod
                    case 0

                        Rinf = R2Lw;
                        qinf = R2Lwq;
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);

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
                    case 7

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
                        acc_normalized = acc_global / acc_norm;
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
                        alpha_deg = rad2deg(atan2(myh, mxh));
                        yaw_imu_deg = yaw_marker;
                        yaw_imu_deg = mod(yaw_imu_deg + 180, 360) - 180;

                        psi = deg2rad(yaw_imu_deg);

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

                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end

                end

                [dot1, ddot1] = deriv5(abs_wrist(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(abs_wrist(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(abs_wrist(1:length(vprime_xw),3),ts);
                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
                abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);

                Mtraj = abs_wrist-abs_wrist(g.add,:);

                n_rows_fin = size(Mtraj(g.fin+1:end,:), 1);

                Mtraj(1:g.add,:)=0;
                Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
                Mvel(1:g.add,:)=0;

                [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);
                [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);
                raddif=[raddif radM-radMs];

                ag_wo_g(:,1) = a_dcm(:,1);
                ag_wo_g(:,2) = a_dcm(:,2);
                ag_wo_g(:,3) = a_dcm(:,3)-9.80665;
                ag_wo_g(:,:) = ag_wo_g(:,:).*1000;

                imu_vel= cumtrapz(time,ag_wo_g);
                w_dcm = w_dcm*180/pi;
                angle_cal=cumtrapz(time,w_dcm);

                imu_traj=cumtrapz(time,imu_vel);
                imu_vel = imu_vel-imu_vel(g.add,:);
                imu_vel(1:g.add,:)=0;
                imu_traj=cumtrapz(time,imu_vel);
                imu_traj=imu_traj-imu_traj(g.add,:);

                length_idx = g.imp;

                r_hat = abs_wrist(length_idx,:)/norm(abs_wrist(length_idx,:));
                vel_r   = dot(Mvel(length_idx,:), r_hat);
                L_delta= vel_r*0.005;

                rw_vid = imp_est;
                r_hat_vid = rw_vid/norm(rw_vid);
                vel_r_vid  = dot(imu_vel(length_idx,:), r_hat_vid);

                L_delta_vid = vecnorm(imu_traj(g.imp,:), 2, 2);

                L_now = vecnorm(abs_wrist(length_idx,:), 2, 2);

                if all(isfinite([L_now, L_delta, L_delta_vid]))
                    L_list(end+1)         = L_now;
                    dL_mocap_list(end+1)  = L_delta;
                    dL_vidimu_list(end+1) = L_delta_vid;
                    if exist('trial','var'), trial_list(end+1) = trial; end
                end

                velCalRate=1;
                imu_velCal =imu_vel;

                for i=g.add:g.bst
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.bst,:)./(g.bst-g.add).*(i-g.add) * velCalRate;
                end
                imu_velCal(g.bst+1:end,:)=imu_velCal(g.bst+1:end,:)-imu_velCal(g.bst+1,:) * velCalRate;
                for i=g.bst:length(imu_velCal)
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.fin,:)./(g.fin-g.bst).*(i-g.bst) * velCalRate;
                end
                imu_velCal(g.fin+1:end,:)=0;

                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);

                [center,vn,rad]=circfit3d(imu_trajCal(g.add:g.fin,:)); vn=vn./norm(vn);
                sumR=zeros(3);
                n=g.fin-g.add+1;
                for i=g.add:g.fin
                    sumR=sumR+(n+g.add-i)*Rinf(:,:,i);
                end
                d=center+dot((imu_trajCal(g.fin,:)-center),vn').*vn';
                Calrad=imu_trajCal(g.fin,:)-d;
                endpoint=center+Calrad.*rad./norm(Calrad);
                imu_bias=inv(sumR)*(imu_trajCal(g.fin,:)-endpoint)'./ts^2;

                [dot1, ddot1] = deriv5(imu_velCal(:,1),ts);
                [dot2, ddot2] = deriv5(imu_velCal(:,2),ts);
                [dot3, ddot3] = deriv5(imu_velCal(:,3),ts);
                imu_accelCal=[dot1(:) dot2(:) dot3(:)];

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
                imu_velCalL=imu_velCalL-imu_velCalL(g.add,:);
                imu_velCalL(1:g.add,:)=0;
                imu_velCalL(g.fin:end,:)=0;
                imu_trajCalL=cumtrapz(ts,imu_velCalL);
                imu_trajCalL=imu_trajCalL-imu_trajCalL(g.add,:);

                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);

                imp_est_list = [imp_est_list; rel_est];

                diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

                traj_lin = imu_trajCal;

                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add);
                    traj_lin(k,:) = imu_trajCal(k,:) - w * diff;
                end
                traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin, 1);

                apdm_biasV_list = [apdm_biasV_list; diff];
                apdm_trajCalV = traj_lin;

                traj_lin_subj = imu_trajCal;

                if club==3
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
                else
                    if trial>20
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj);
                    else
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(1,:,subj);
                    end
                end
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add);
                    traj_lin_subj(k,:) = imu_trajCal(k,:) - w * diff_ml;
                end

                traj_lin_subj(g.fin+1:end,:) = repmat(traj_lin_subj(g.fin,:), n_rows_fin, 1);

                angle_error=[];
                axis_error=[];
                for i=1:length(time)
                    qprod = quaternProd(quaternConj(qinf(i,:)),R2Lwq(i,:));
                    tempAng = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);
                    tempAxs = [qprod(2)/sqrt(1-qprod(1)^2), qprod(3)/sqrt(1-qprod(1)^2), qprod(4)/sqrt(1-qprod(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error=[angle_error, tempAng];
                    axis_error=[axis_error; tempAxs];
                end

                angle_error_ref=[];
                axis_error_ref=[];

                for i=1:length(time)
                    qprod_ref = quaternProd(quaternConj(qinf_ref(i,:)),R2Lwq(i,:));
                    tempAng = abs(2 * atan2(norm(qprod_ref(2:4)),qprod_ref(1))*180/pi);
                    tempAxs = [qprod_ref(2)/sqrt(1-qprod_ref(1)^2), qprod_ref(3)/sqrt(1-qprod_ref(1)^2), qprod_ref(4)/sqrt(1-qprod_ref(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error_ref=[angle_error_ref, tempAng];
                    axis_error_ref=[axis_error_ref; tempAxs];
                end

                angle_error_plot = [angle_error_plot angle_error'];
                angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];

                angle_error_q = angle_error(g.add:g.fin);
                angle_error_imp = angle_error(g.add:g.imp);
                angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];

                angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
                angle_error_add2imp = [angle_error_add2imp mean(angle_error_imp)];

                angle_error_axis = [];
                angle_error_axis_ref = [];
                for i = 1:length(time)

                    R1 = R2Lw(:,:,i);
                    R2 = Rinf(:,:,i);
                    R_diff = R2 * R1';

                    eul_angles = rotm2eul(R_diff, 'ZYX');

                    roll_error_deg = rad2deg(eul_angles(1));
                    pitch_error_deg = rad2deg(eul_angles(2));
                    yaw_error_deg = rad2deg(eul_angles(3));

                    R1 = R2Lw(:,:,i);
                    R2 = Rinf_ref(:,:,i);
                    R_diff = R2 * R1';

                    eul_angles = rotm2eul(R_diff, 'ZYX');

                    roll_error_deg_ref = rad2deg(eul_angles(1));
                    pitch_error_deg_ref = rad2deg(eul_angles(2));
                    yaw_error_deg_ref = rad2deg(eul_angles(3));

                    angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];

                    angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];

                end

                angle_error_axis_list(:,:,z) = angle_error_axis;
                angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;

                plot_ds_ref(:,:,z) = Mtraj;
                plot_ds_prop(:,:,z) = apdm_trajCalV;
                plot_ds_driver(:,:,z) = traj_lin_subj;

                plot_ds_imu(:,:,z) = imu_traj;
                plot_imu_vel(:,:,z) = imu_vel ;
                plot_imu_acc(:,:,z) = ag_wo_g;

                plot_imu_acc_local(:,:,z) = acc_data;

                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial-20, subj};
                plot_ds_ml(:,:,z) = ml_traj_check;

                switch mae_method
                    case 0
                        test_drift = imu_traj;
                    case 1
                        test_drift = imu_trajCal;
                    case 2
                        test_drift = imu_trajCalL;
                    case 3
                        test_drift = imu_trajCalI;
                    case 4
                        test_drift = apdm_trajCalV;
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
                end_traj = 800;
                error = Mtraj(start_traj:end_traj,:)-test_drift(start_traj:end_traj,:);

                Mae_XYZ = mean(abs(error));
                Mae_norm = mean(vecnorm(error,2,2));
                rmse_xyz = sqrt(mean(error.^2, 1));
                rmse_overall = sqrt(mean(sum(error.^2, 2)));

                mae_list = [mae_list; Mae_XYZ];
                mae_norm_list = [mae_norm_list; Mae_norm];
                rmse_xyz_list = [rmse_xyz_list; rmse_xyz];
                rmse_norm_list = [rmse_norm_list; rmse_overall];

                error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
                error_vellist = [error_vellist; mean(abs(error_vel))];

                z= z+1;

                swingData_2508(subj).clubN(club).trialN(trial).apdm = [ag_wo_g w_dcm acc_data gyro_data];
                swingData_2508(subj).clubN(club).trialN(trial).rel = [rel_est ref_rel_imp];
                swingData_2508(subj).clubN(club).trialN(trial).vel_integration = [imu_vel imu_velCal Mvel];
                swingData_2508(subj).clubN(club).trialN(trial).traj_integration = [imu_traj imu_trajCal imu_trajCalL apdm_trajCalV Mtraj];
            end
        end
    end

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

    mean_xyz = mean(angle_error_axis_list, 3);
    std_xyz = std(angle_error_axis_list, 0, 3);

    mean_xyz_ref = mean(angle_error_axis_list_ref, 3);
    std_xyz_ref = std(angle_error_axis_list_ref, 0, 3);

    t = time(:)';
    M = mean_xyz;
    S = std_xyz;
    MR = mean_xyz_ref;
    SR = std_xyz_ref;

    assert(size(M,1)==numel(t) && size(M,2)==3, 'check the size of mean_xyz');
    assert(isequal(size(S), size(M)), 'check the size of std_xyz');
    assert(isequal(size(MR), size(M)) && isequal(size(SR), size(S)), 'ref size mismatch');

    col_prop = [179 0 25]/255;
    col_ref_line = [0 0 0];
    col_ref_fill = 0.70*[1 1 1];

    alpha_prop = 0.18;
    alpha_ref  = 0.16;
    lw = 1.6;
    axisLabel = {'X','Y','Z'};

    R2_11_store(subj_fast).subj  = subj_fast;
    R2_11_store(subj_fast).nTr   = size(plot_ds_ref, 3);
    R2_11_store(subj_fast).ref    = plot_ds_ref;
    R2_11_store(subj_fast).propV  = plot_ds_prop;
    R2_11_store(subj_fast).prop   = plot_ds_driver;

    plot_ds_ref = plot_ds_ref.*0.1;
    plot_ds_prop = plot_ds_prop.*0.1;
    plot_ds_imu = plot_ds_imu.*0.1;
    plot_ds_driver = plot_ds_driver.*0.1;

    plot_ds_ml = plot_ds_ml.*0.1;

    T = size(angle_error_plot,1);
    N = size(angle_error_plot,2);
    assert(all(size(angle_error_plot_ref)==[T N]), 'angle_error_plot_ref size mismatch');

    if exist('time','var') && numel(time)==T
        t = time(:)';
    else
        t = 1:T;
    end

    col_prop     = [1 0 0];
    col_ref_line = [0 0 0];
    col_ref_fill = 0.70*[1 1 1];
    alpha_prop   = 0.18;
    alpha_ref    = 0.16;
    lw = 1.6;

    ref_mean_x = mean(plot_ds_ref(:, 1, :), 3);
    ref_std_x = std(plot_ds_ref(:, 1, :), 0, 3);
    if subj==8
        ref_mean_x = mean(plot_ds_ref(:, 1, 1:9), 3);
        ref_std_x = std(plot_ds_ref(:, 1, 1:9), 0, 3);
    end

    ref_mean_y = mean(plot_ds_ref(:, 2, :), 3);
    ref_std_y = std(plot_ds_ref(:, 2, :), 0, 3);
    if subj==8
        ref_mean_y = mean(plot_ds_ref(:, 2, 1:9), 3);
        ref_std_y = std(plot_ds_ref(:, 2, 1:9), 0, 3);
    end

    ref_mean_z = mean(plot_ds_ref(:, 3, :), 3);
    ref_std_z = std(plot_ds_ref(:, 3, :), 0, 3);
    if subj==8
        ref_mean_z = mean(plot_ds_ref(:, 3, 1:9), 3);
        ref_std_z = std(plot_ds_ref(:, 3, 1:9), 0, 3);
    end
    proposed_mean_x = mean(plot_ds_prop(:, 1, :), 3);
    proposed_std_x = std(plot_ds_prop(:, 1, :), 0, 3);

    proposed_mean_y = mean(plot_ds_prop(:, 2, :), 3);
    proposed_std_y = std(plot_ds_prop(:, 2, :), 0, 3);

    proposed_mean_z = mean(plot_ds_prop(:, 3, :), 3);
    proposed_std_z = std(plot_ds_prop(:, 3, :), 0, 3);
    imu_mean_x = mean(plot_ds_imu(:, 1, :), 3);
    imu_std_x = std(plot_ds_imu(:, 1, :), 0, 3);

    imu_mean_y = mean(plot_ds_imu(:, 2, :), 3);
    imu_std_y = std(plot_ds_imu(:, 2, :), 0, 3);

    imu_mean_z = mean(plot_ds_imu(:, 3, :), 3);
    imu_std_z = std(plot_ds_imu(:, 3, :), 0, 3);

    driver_mean_x = mean(plot_ds_driver(:, 1, :), 3);
    driver_std_x = std(plot_ds_driver(:, 1, :), 0, 3);

    if subj==8
        driver_mean_x = mean(plot_ds_driver(:, 1, 1:9), 3);
        driver_std_x = std(plot_ds_driver(:, 1, 1:9), 0, 3);
    end

    driver_mean_y = mean(plot_ds_driver(:, 2, :), 3);
    driver_std_y = std(plot_ds_driver(:, 2, :), 0, 3);
    if subj==8
        driver_mean_y = mean(plot_ds_driver(:, 2, 1:9), 3);
        driver_std_y = std(plot_ds_driver(:, 2, 1:9), 0, 3);
    end

    driver_mean_z = mean(plot_ds_driver(:, 3, :), 3);
    driver_std_z = std(plot_ds_driver(:, 3, :), 0, 3);
    if subj==8
        driver_mean_z = mean(plot_ds_driver(:, 3, 1:9), 3);
        driver_std_z = std(plot_ds_driver(:, 3, 1:9), 0, 3);
    end

    ml_mean_x = mean(plot_ds_ml(:, 1, :), 3);
    ml_std_x = std(plot_ds_ml(:, 1, :), 0, 3);

    if subj==8
        ml_mean_x = mean(plot_ds_ml(:, 1, 1:9), 3);
        ml_std_x = std(plot_ds_ml(:, 1, 1:9), 0, 3);
    end

    ml_mean_y = mean(plot_ds_ml(:, 2, :), 3);
    ml_std_y = std(plot_ds_ml(:, 2, :), 0, 3);
    if subj==8
        ml_mean_y = mean(plot_ds_ml(:, 2, 1:9), 3);
        ml_std_y = std(plot_ds_ml(:, 2, 1:9), 0, 3);
    end

    ml_mean_z = mean(plot_ds_ml(:, 3, :), 3);
    ml_std_z = std(plot_ds_ml(:, 3, :), 0, 3);
    if subj==8
        ml_mean_z = mean(plot_ds_ml(:, 3, 1:9), 3);
        ml_std_z = std(plot_ds_ml(:, 3, 1:9), 0, 3);
    end

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
        ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
    end

    z=1;
    for subj = subj_fast
        for club = 3

            fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
            fpath = fullfile(mldataDir, fname);
            if ~isfile(fpath)
                warning('Missing file: %s', fpath);
                continue
            end

            fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
            fpath_traj = fullfile(mldataDir, fname_traj);

            T = readtable(fpath);
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
                ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;
            end

            if club==3 && subj==5
                ml_est.(clubs_ml{club})(1:4, :, subj) = M(1:4, :);
                ml_est.(clubs_ml{club})(5, :, subj) = NaN;
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

            for trial = 1:10
                if subj==1 && club==2 && trial ==1
                    continue
                elseif subj==5 && club==3 && trial==5
                    continue
                elseif subj==9 && club==3 && trial==8
                    continue
                elseif subj==8 && club==1 && trial ==30
                    continue
                end

                if club==3 && (trial>10)
                    continue;
                end
                g = swingData_2508(subj).clubN(club).trialN(trial);

                g.add = double(g.add);
                g.bst = double(g.bst);
                g.imp = double(g.imp);
                g.fin = double(g.fin);

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

                WristU = g.marker(:,13:15);
                WristM = g.marker(:,10:12);
                WristL = g.marker(:,7:9);
                acc_data = g.apdm(:,1:3);
                gyro_data = g.apdm(:,4:6);
                magnet = g.apdm(:,7:9);
                abs_wrist = (WristU+WristL)./2;
                rias = g.marker(:,1:3);
                lias = g.marker(:,4:6);
                com = (rias+lias)./2;

                m_cal = magnet;

                add_est = g.add_est;
                imp_est = g.imp_est;

                rel_est = imp_est - add_est;

                motionag = g.dl(:,1:3);
                motionag = motionag+ com;

                ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);

                add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
                imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
                imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));

                add_pos_error_prop =abs_wrist(g.add,:)-add_est;
                imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
                imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);

                ok = true;

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

                Cw = (WristU+WristL)./2;
                Lo = WristL-Cw;
                Mo = WristM-Cw;
                Uo = WristU-Cw;

                wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
                wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
                wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);

                temp_x = Uo./wU;
                vprime_xw = Lo./wL;
                vprime_top = Mo./wM;
                vprime_zw = zeros(length(vprime_xw),3);
                vprime_yw = zeros(length(vprime_xw),3);

                for i = 1:length(vprime_xw)
                    vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:));
                end
                for i = 1:length(vprime_xw)
                    vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:));
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
                Cwddot=[ddot1(:) ddot2(:) ddot3(:)];

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

                gL_wrist=zeros(length(vprime_xw),3);
                for i=1:length(vprime_xw)
                    gL_wrist(i,:) = [-dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
                        dot(WristUdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./(norm(Uo(i,:))), ...
                        -dot(WristUdot(i,:)-Cwdot(i,:),vprime_yw(i,:))./(norm(Uo(i,:)))];
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

                roll_marker_list = [roll_marker_list,roll_marker];
                pitch_marker_list = [pitch_marker_list, pitch_marker];
                yaw_marker_list = [yaw_marker_list, yaw_marker];

                switch OrientationMethod
                    case 0

                        Rinf = R2Lw;
                        qinf = R2Lwq;
                        a_dcm = dcmRot(Rinf,acc_data);
                        w_dcm = dcmRot(Rinf,gyro_data);

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
                    case 7

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
                        acc_normalized = acc_global / acc_norm;
                        ax = acc_normalized(1);
                        ay = acc_normalized(2);
                        az = acc_normalized(3);

                        roll = atan2(ay, az);
                        pitch = atan2(-ax, sqrt(ay^2 + az^2));

                        phi = roll;
                        theta = pitch;

                        psi = deg2rad(yaw_marker);

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

                        Rinf_ref = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2Lw(:,:,g.add));
                        for t=1:length(time)
                            qinf_ref(t,:)=dcm2quatern(Rinf_ref(:,:,t)');
                            if qinf_ref(t,1)<0
                                qinf_ref(t,:)=-qinf_ref(t,:);
                            end
                        end

                end

                [dot1, ddot1] = deriv5(abs_wrist(1:length(vprime_xw),1),ts);
                [dot2, ddot2] = deriv5(abs_wrist(1:length(vprime_xw),2),ts);
                [dot3, ddot3] = deriv5(abs_wrist(1:length(vprime_xw),3),ts);
                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
                abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);

                Mtraj = abs_wrist-abs_wrist(g.add,:);
                Mtraj(1:g.add,:)=0;
                Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);
                Mvel(1:g.add,:)=0;

                n_rows_fin_fast = size(Mtraj(g.fin+1:end,:), 1);

                [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);
                [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);
                raddif=[raddif radM-radMs];

                ag_wo_g(:,1) = a_dcm(:,1);
                ag_wo_g(:,2) = a_dcm(:,2);
                ag_wo_g(:,3) = a_dcm(:,3)-9.80665;
                ag_wo_g(:,:) = ag_wo_g(:,:).*1000;

                imu_vel= cumtrapz(time,ag_wo_g);
                w_dcm = w_dcm*180/pi;
                angle_cal=cumtrapz(time,w_dcm);

                imu_traj=cumtrapz(time,imu_vel);

                imu_vel = imu_vel-imu_vel(g.add,:);

                imu_vel(1:g.add,:)=0;
                imu_traj=cumtrapz(time,imu_vel);
                imu_traj=imu_traj-imu_traj(g.add,:);

                length_idx = g.imp;

                r_hat = abs_wrist(length_idx,:)/norm(abs_wrist(length_idx,:));
                vel_r   = dot(Mvel(length_idx,:), r_hat);
                L_delta= vel_r*0.005;

                rw_vid = imp_est;
                r_hat_vid = rw_vid/norm(rw_vid);
                vel_r_vid  = dot(imu_vel(length_idx,:), r_hat_vid);

                L_delta_vid = vecnorm(imu_traj(g.imp,:), 2, 2);

                L_now = vecnorm(abs_wrist(length_idx,:), 2, 2);

                if all(isfinite([L_now, L_delta, L_delta_vid]))
                    L_list(end+1)         = L_now;
                    dL_mocap_list(end+1)  = L_delta;
                    dL_vidimu_list(end+1) = L_delta_vid;
                    if exist('trial','var'), trial_list(end+1) = trial; end
                end

                velCalRate=1;
                imu_velCal =imu_vel;

                for i=g.add:g.bst
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.bst,:)./(g.bst-g.add).*(i-g.add) * velCalRate;
                end
                imu_velCal(g.bst+1:end,:)=imu_velCal(g.bst+1:end,:)-imu_velCal(g.bst+1,:) * velCalRate;
                for i=g.bst:length(imu_velCal)
                    imu_velCal(i,:)=imu_velCal(i,:)-imu_velCal(g.fin,:)./(g.fin-g.bst).*(i-g.bst) * velCalRate;
                end
                imu_velCal(g.fin+1:end,:)=0;

                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);

                [center,vn,rad]=circfit3d(imu_trajCal(g.add:g.fin,:)); vn=vn./norm(vn);
                sumR=zeros(3);
                n=g.fin-g.add+1;
                for i=g.add:g.fin
                    sumR=sumR+(n+g.add-i)*Rinf(:,:,i);
                end
                d=center+dot((imu_trajCal(g.fin,:)-center),vn').*vn';
                Calrad=imu_trajCal(g.fin,:)-d;
                endpoint=center+Calrad.*rad./norm(Calrad);
                imu_bias=inv(sumR)*(imu_trajCal(g.fin,:)-endpoint)'./ts^2;

                [dot1, ddot1] = deriv5(imu_velCal(:,1),ts);
                [dot2, ddot2] = deriv5(imu_velCal(:,2),ts);
                [dot3, ddot3] = deriv5(imu_velCal(:,3),ts);
                imu_accelCal=[dot1(:) dot2(:) dot3(:)];

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
                imu_velCalL=imu_velCalL-imu_velCalL(g.add,:);
                imu_velCalL(1:g.add,:)=0;
                imu_velCalL(g.fin:end,:)=0;
                imu_trajCalL=cumtrapz(ts,imu_velCalL);
                imu_trajCalL=imu_trajCalL-imu_trajCalL(g.add,:);

                imu_trajCal=cumtrapz(ts,imu_velCal);
                imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);

                imp_est_list = [imp_est_list; rel_est];

                diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

                traj_lin = imu_trajCal;

                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add);
                    traj_lin(k,:) = imu_trajCal(k,:) - w * diff;
                end

                traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin_fast, 1);

                apdm_biasV_list = [apdm_biasV_list; diff];
                apdm_trajCalV = traj_lin;

                traj_lin_subj = imu_trajCal;

                if club==3
                    diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial,:,subj);
                else
                    if trial>20
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj);
                    else
                        diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(1,:,subj);
                    end
                end
                for k = g.add : g.fin
                    w = (k - g.add) / (g.imp - g.add);
                    traj_lin_subj(k,:) = imu_trajCal(k,:) - w * diff_ml;
                end

                traj_lin_subj(g.fin+1:end,:) = repmat(traj_lin_subj(g.fin,:), n_rows_fin_fast, 1);

                angle_error=[];
                axis_error=[];
                for i=1:length(time)
                    qprod = quaternProd(quaternConj(qinf(i,:)),R2Lwq(i,:));
                    tempAng = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);
                    tempAxs = [qprod(2)/sqrt(1-qprod(1)^2), qprod(3)/sqrt(1-qprod(1)^2), qprod(4)/sqrt(1-qprod(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error=[angle_error, tempAng];
                    axis_error=[axis_error; tempAxs];
                end

                angle_error_ref=[];
                axis_error_ref=[];

                for i=1:length(time)
                    qprod_ref = quaternProd(quaternConj(qinf_ref(i,:)),R2Lwq(i,:));
                    tempAng = abs(2 * atan2(norm(qprod_ref(2:4)),qprod_ref(1))*180/pi);
                    tempAxs = [qprod_ref(2)/sqrt(1-qprod_ref(1)^2), qprod_ref(3)/sqrt(1-qprod_ref(1)^2), qprod_ref(4)/sqrt(1-qprod_ref(1)^2)];
                    if tempAng>180
                        tempAng=360-tempAng;
                    end
                    angle_error_ref=[angle_error_ref, tempAng];
                    axis_error_ref=[axis_error_ref; tempAxs];
                end

                angle_error_plot = [angle_error_plot angle_error'];
                angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];

                angle_error_q = angle_error(g.add:g.fin);
                angle_error_imp = angle_error(g.add:g.imp);
                angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];

                angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
                angle_error_add2imp = [angle_error_add2imp mean(angle_error_imp)];

                angle_error_axis = [];
                angle_error_axis_ref = [];
                for i = 1:length(time)

                    R1 = R2Lw(:,:,i);
                    R2 = Rinf(:,:,i);
                    R_diff = R2 * R1';

                    eul_angles = rotm2eul(R_diff, 'ZYX');

                    roll_error_deg = rad2deg(eul_angles(1));
                    pitch_error_deg = rad2deg(eul_angles(2));
                    yaw_error_deg = rad2deg(eul_angles(3));

                    R1 = R2Lw(:,:,i);
                    R2 = Rinf_ref(:,:,i);
                    R_diff = R2 * R1';

                    eul_angles = rotm2eul(R_diff, 'ZYX');

                    roll_error_deg_ref = rad2deg(eul_angles(1));
                    pitch_error_deg_ref = rad2deg(eul_angles(2));
                    yaw_error_deg_ref = rad2deg(eul_angles(3));

                    angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];

                    angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];

                end

                angle_error_axis_list(:,:,z) = angle_error_axis;
                angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;

                plot_ds_ref_fast(:,:,z) = Mtraj;
                plot_ds_prop(:,:,z) = apdm_trajCalV;
                plot_ds_fast(:,:,z) = traj_lin_subj;

                plot_ds_imu(:,:,z) = imu_traj;
                plot_imu_vel(:,:,z) = imu_vel ;
                plot_imu_acc(:,:,z) = ag_wo_g;

                plot_imu_acc_local(:,:,z) = acc_data;

                ml_traj_check= ml_traj_est.(clubs_ml{club}){trial, subj};
                plot_ds_ml_fast(:,:,z) = ml_traj_check;

                switch mae_method
                    case 0
                        test_drift = imu_traj;
                    case 1
                        test_drift = imu_trajCal;
                    case 2
                        test_drift = imu_trajCalL;
                    case 3
                        test_drift = imu_trajCalI;
                    case 4
                        test_drift = apdm_trajCalV;
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
                end_traj = 800;
                error = Mtraj(start_traj:end_traj,:)-test_drift(start_traj:end_traj,:);

                Mae_XYZ = mean(abs(error));
                Mae_norm = mean(vecnorm(error,2,2));
                rmse_xyz = sqrt(mean(error.^2, 1));
                rmse_overall = sqrt(mean(sum(error.^2, 2)));

                mae_list = [mae_list; Mae_XYZ];
                mae_norm_list = [mae_norm_list; Mae_norm];
                rmse_xyz_list = [rmse_xyz_list; rmse_xyz];
                rmse_norm_list = [rmse_norm_list; rmse_overall];

                error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
                error_vellist = [error_vellist; mean(abs(error_vel))];

                event_add_fast(z) = g.add;
                event_bst_fast(z) = g.bst;
                event_imp_fast(z) = g.imp;
                event_fin_fast(z) = g.fin;

                z=z+1;
            end
        end
    end

    R2_11_store(subj_fast).nTrFast  = z-1;
    R2_11_store(subj_fast).ref_fast = plot_ds_ref_fast(:,:,1:z-1);
    R2_11_store(subj_fast).prop_fast= plot_ds_fast(:,:,1:z-1);
    R2_11_store(subj_fast).add   = event_add_fast(1:z-1);
    R2_11_store(subj_fast).bst   = event_bst_fast(1:z-1);
    R2_11_store(subj_fast).imp   = event_imp_fast(1:z-1);
    R2_11_store(subj_fast).fin   = event_fin_fast(1:z-1);

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

    ref_mean_x_fast = mean(plot_ds_ref_fast(:, 1, :), 3);

    ref_mean_y_fast = mean(plot_ds_ref_fast(:, 2, :), 3);

    ref_mean_z_fast = mean(plot_ds_ref_fast(:, 3, :), 3);

    left_margin = 0.13;
    top_margin = 0.05;
    bottom_margin = 0.08;
    plot_width = 0.82;
    gap = 0.05;
    plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;

    figure(subj_fast);
    clf;
    set(gcf, 'Position', [100, 349, 600, 551]);

    if subj_fast == 5 || subj_fast == 9
        n_trials_plot = 9;
    else
        n_trials_plot = 10;
    end

    event_add_mean = mean(event_add_fast(1:n_trials_plot))
    event_bst_mean = mean(event_bst_fast(1:n_trials_plot))
    event_imp_mean = mean(event_imp_fast(1:n_trials_plot))
    event_fin_mean = mean(event_fin_fast(1:n_trials_plot))
    event_add_std = std(event_add_fast(1:n_trials_plot));
    event_bst_std = std(event_bst_fast(1:n_trials_plot));
    event_imp_std = std(event_imp_fast(1:n_trials_plot));
    event_fin_std = std(event_fin_fast(1:n_trials_plot));

    subplot(3, 1, 1);
    k = 1;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;

    y_data = plot_ds_fast(plot_x_start:plot_x_end, 1, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;

    xline(event_add_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');

    fill([1:length(driver_mean_x), fliplr(1:length(driver_mean_x))], ...
        [driver_mean_x + driver_std_x*2; flipud(driver_mean_x - driver_std_x*2)], ...
        dark_red, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(driver_mean_x, '--','Color', dark_red, 'LineWidth', 1.5);

    for i = 1:n_trials_plot
        plot(plot_ds_fast(:,1,i),'Color', dark_red,'LineWidth', 0.7);
    end

    xlim([plot_x_start plot_x_end])
    set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT')
    set(gca, 'XTick', [])
    set(gca, 'XTickLabel', []);
    hold off;
    ylim([-60 50]);

    subplot(3, 1, 2);
    k = 2;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;

    y_data = plot_ds_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;

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

    subplot(3, 1, 3);
    k = 3;
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    hold on;

    y_data = plot_ds_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
    y_min = min(y_data(:)) - 5;
    y_max = max(y_data(:)) + 5;

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

    figure(subj_fast+1000); set(gcf, 'Position', [100, 349, 600, 551]);
    clf;

    ml_x_range = ml_start_ref:(ml_start_ref + size(plot_ds_ml_fast, 1) - 1);

    subplot(3, 1, 1);
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
    xline(ml_start_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(ml_end_ref, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

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

    y_data = plot_ds_ml_fast(:, 3, 1:n_trials_plot);
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

    figure(subj_fast+100); set(gcf, 'Position', [100, 349, 600, 551]);
    clf;

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

    y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
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

    y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 3, 1:n_trials_plot);
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

    if subj_fast == subj_select
        figure(2025); set(gcf, 'Position', [100, 349, 600, 551]);
        clf;

        left_margin = 0.13;
        top_margin = 0.05;
        bottom_margin = 0.08;
        plot_width = 0.82;
        gap = 0.05;
        plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;

        subplot(3, 1, 1);

        bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
        set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);

        hold on;

        y_data = plot_ds_ref_fast(plot_x_start:plot_x_end, 2, 1:n_trials_plot);
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

        fill([1:length(ref_mean_y), fliplr(1:length(ref_mean_y))], ...
            [ref_mean_y + ref_std_y*2; flipud(ref_mean_y - ref_std_y*2)], ...
            'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ref_mean_y, '--', 'Color', [0 0 0], 'LineWidth', 1.5);
        plot(plot_ds_ref_fast(:, 2, trial_select), 'Color', [0 0 0], 'LineWidth', 2);

        ylabel('Y-axis (cm)');
        xlim([plot_x_start plot_x_end]);
        grid on;
        hold off;

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

    if subj_fast == subj_select
        figure(2026); set(gcf, 'Position', [150, 349, 600, 551]);
        clf;

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

    left_margin = 0.13;
    top_margin = 0.05;
    bottom_margin = 0.08;
    plot_width = 0.82;
    gap = 0.05;
    plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;

    if subj_fast == subj_select
        figure(2027);
        clf;
        set(gcf, 'Position', [200, 349, 600, 551]);

        subplot(3, 1, 1);
        k = 1;
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

        subplot(3, 1, 2);
        k = 2;
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

        subplot(3, 1, 3);
        k = 3;
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

    mean_traj = [driver_mean_x driver_mean_y driver_mean_z];
    std_traj = [driver_std_x driver_std_y driver_std_z];

    out = compute_shade_coverage(plot_ds_fast, mean_traj, std_traj, ...
                                 start_idx, end_idx, nsigma);

    fprintf('Axis X: %.2f%% out of range\n', 100-out.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out.axis_ratio(3)*100);
    fprintf('three-axis mean %.2f%% out of range\n', 100*(1-mean(out.axis_ratio(:))));

    ratio_imu = 100*(mean(out.trial_ratio(:,:),2));
    ratio_imu_axis = 100*(out.trial_ratio(:,:));

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

    mean_traj_fast = [ref_mean_x ref_mean_y ref_mean_z];
    std_traj_fast = [ref_std_x ref_std_y ref_std_z];

    out_fast = compute_shade_coverage(plot_ds_ref_fast, mean_traj_fast, std_traj_fast, ...
                                 start_idx, end_idx, nsigma);

    fprintf('Axis X: %.2f%% out of range\n', 100-out_fast.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out_fast.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out_fast.axis_ratio(3)*100);
    fprintf('three-axis mean %.2f%% out of range\n', 100*(1-mean(out_fast.axis_ratio(:))));

    ratio_mocap = 100*(mean(out_fast.trial_ratio(:,:),2));
    ratio_mocap_axis = 100*(out_fast.trial_ratio(:,:));

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

    mean_traj_ml = [ml_mean_x ml_mean_y ml_mean_z];
    std_traj_ml = [ml_std_x ml_std_y ml_std_z];

    out_ml = compute_shade_coverage(plot_ds_ml_fast, mean_traj_ml, std_traj_ml, ...
                                 start_idx, end_idx, nsigma);

    fprintf('Axis X: %.2f%% out of range\n', 100-out_ml.axis_ratio(1)*100);
    fprintf('Axis Y: %.2f%% out of range\n', 100-out_ml.axis_ratio(2)*100);
    fprintf('Axis Z: %.2f%% out of range\n', 100-out_ml.axis_ratio(3)*100);
    fprintf('three-axis mean %.2f%% out of range\n', 100*(1-mean(out_ml.axis_ratio(:))));

    ratio_ml = 100*(mean(out_ml.trial_ratio(:,:),2));
    ratio_ml_axis = 100*(out_ml.trial_ratio(:,:));

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
figure(10000);
scatter(x, y,60, 'filled', 'MarkerFaceColor', dark_red);

hold on;

p = polyfit(x, y, 1);
yfit = polyval(p, x);

x_range = linspace(min(x), max(x), 100);
y_identity = x_range;

mid_gray = [0.5, 0.5, 0.5];
plot(x_range, y_identity, ...
    'Color', mid_gray, ...
    'LineStyle', '--', ...
    'LineWidth', 1.5);

plot(x, yfit, 'k', 'LineWidth', 3);

xlabel('GT Consistency (%)');
ylabel('Proposed Consistency (%)');
axis equal;
xlim([0 100]);
ylim([0 100]);
hold off;

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('IMU Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_list;
y = ratio_ml_list;
figure(20000);
scatter(x, y,60, 'filled', 'MarkerFaceColor', dark_green);

hold on;

p = polyfit(x, y, 1);
yfit = polyval(p, x);

x_range = linspace(min(x), max(x), 100);
y_identity = x_range;

mid_gray = [0.5, 0.5, 0.5];
plot(x_range, y_identity, ...
    'Color', mid_gray, ...
    'LineStyle', '--', ...
    'LineWidth', 1.5);

plot(x, yfit, 'k', 'LineWidth', 3);

xlabel('GT Consistency (%)');
ylabel('End to End Consistency (%)');
axis equal;
xlim([0 100]);
ylim([0 100]);
hold off;

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('ML Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

axis_names = {'X', 'Y', 'Z'};
fig_numbers = [11000, 12000, 13000];

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

    p = polyfit(x, y, 1);
    yfit = polyval(p, x);

    x_range = linspace(0, 100, 100);
    y_identity = x_range;

    plot(x_range, y_identity, ...
        'Color', mid_gray, ...
        'LineStyle', '--', ...
        'LineWidth', 1.5);

    plot(x, yfit, 'k', 'LineWidth', 3);

    xlabel(sprintf('GT Consistency - %s (%%)', axis_names{ax}));
    ylabel(sprintf('Proposed Consistency - %s (%%)', axis_names{ax}));
    axis equal;
    xlim([0 100]);
    ylim([0 100]);
    hold off;

    [Rmat, Pmat] = corrcoef(x, y);
    R_value = Rmat(1, 2);
    p_value = Pmat(1, 2);

    fprintf('IMU %s-axis: R = %.3f, p-value = %.4g\n', axis_names{ax}, R_value, p_value);
end

colors = turbo(20);

swing_tempo_ref_list;
swing_tempo_fast_list;

figure(30000);
hold on;

start_idx_ref = 1;
start_idx_fast = 1;

legend_entries = {};

ref_means = zeros(num_subjects, 1);
all_percent_changes = {};

for subj = 1:num_subjects
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;

    ref_subj  = swing_tempo_ref_list(start_idx_ref:end_idx_ref);
    fast_subj = swing_tempo_fast_list(start_idx_fast:end_idx_fast);

    ref_mean = mean(ref_subj);
    ref_means(subj) = ref_mean;

    percent_change = ((fast_subj - ref_mean) / ref_mean) * 100;
    all_percent_changes{subj} = percent_change;

    x_plot = 1:n_per_subject_fast(subj);

    scatter(x_plot, percent_change, 60, 'filled', 'MarkerFaceColor', colors(subj*2,:));

    mean_change = mean(percent_change);

    legend_entries{end+1} = sprintf('S%d (n_{ref}=%d, n_{fast}=%d)', ...
        subj, n_per_subject_ref(subj), n_per_subject_fast(subj));
    legend_entries{end+1} = sprintf('Mean: %.1f%%', mean_change);

    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

yline(0, 'k-', 'LineWidth', 1.5);
xlabel('Trial Index');
ylabel('Change from Ref Mean (%)');
title('Swing Tempo: Fast vs Ref Mean');
grid on;
hold off;

swing_time_normal_list;
swing_time_fast_list;

num_subjects = length(n_per_subject_ref);

normal_means = zeros(num_subjects, 1);
normal_stds  = zeros(num_subjects, 1);
fast_means   = zeros(num_subjects, 1);
fast_stds    = zeros(num_subjects, 1);

start_idx_ref  = 1;
start_idx_fast = 1;

for subj = 1:num_subjects
    end_idx_ref  = start_idx_ref  + n_per_subject_ref(subj)  - 1;
    end_idx_fast = start_idx_fast + n_per_subject_fast(subj) - 1;

    normal_subj = swing_time_normal_list(start_idx_ref:end_idx_ref);
    fast_subj   = swing_time_fast_list(start_idx_fast:end_idx_fast);

    normal_means(subj) = mean(normal_subj);
    normal_stds(subj)  = std(normal_subj);
    fast_means(subj)   = mean(fast_subj);
    fast_stds(subj)    = std(fast_subj);

    start_idx_ref  = end_idx_ref  + 1;
    start_idx_fast = end_idx_fast + 1;
end

fprintf('\n===== swing time by participant =====\n');
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

mean_changes = zeros(num_subjects, 1);
std_changes = zeros(num_subjects, 1);

for subj = 1:num_subjects
    mean_changes(subj) = mean(all_percent_changes{subj});
    std_changes(subj) = std(all_percent_changes{subj});
end

fprintf('\n===== summary by participant =====\n');
for subj = 1:num_subjects
    fprintf('Subject %d: Ref Mean = %.2f (n=%d), Fast Mean Change = %.1f%% ± %.1f%% (n=%d)\n', ...
        subj, ref_means(subj), n_per_subject_ref(subj), ...
        mean_changes(subj), std_changes(subj), n_per_subject_fast(subj));
end

fig_height = 300;

figure(50010);
clf;
set(gcf, 'Position', [100, 349, 600, fig_height]);

left_margin = 0.13;
top_margin = 0.05;
bottom_margin = 0.08;
plot_width = 0.82;
gap = 0.05;
plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;

x_labels = [arrayfun(@(x) sprintf('S%d', x), 1:num_subjects, 'UniformOutput', false), {''}, {'Total'}];

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
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+ 1]);
ylim([0 100]);
box off;
hold off;

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

set(gca, 'XTick', [])
set(gca, 'XTickLabel', []);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+1]);
ylim([0 120]);
box off;
hold off;

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

set(gca, 'XTick', [])
xticklabels(x_labels);
set(gca, 'YTick', [0 50 100]);
set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
xlim([0, length(all_ratios)+1]);
ylim([0 110]);
box off;
hold off;
print(gcf, sprintf('fig6.svg'), '-dsvg', '-vector');

fig_height = 250;
figure(50020);
clf;
set(gcf, 'Position', [100, 349, 250, fig_height]);
set(gcf, 'Color', 'white');

left_margin = 0.18;
top_margin = 0.05;
bottom_margin = 0.12;
plot_width = 0.78;
gap = 0.08;
plot_height = (1 - top_margin - bottom_margin - gap) / 2;

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

save_filename = sprintf('correlation_fold_%d.mat', fold_num);
eval(sprintf('ratio_mocap_%d = ratio_mocap_list;', fold_num));
eval(sprintf('ratio_imu_%d = ratio_imu_list;', fold_num));
eval(sprintf('ratio_ml_%d = ratio_ml_list;', fold_num));

save(save_filename, sprintf('ratio_mocap_%d', fold_num), ...
                    sprintf('ratio_imu_%d', fold_num), ...
                    sprintf('ratio_ml_%d', fold_num));
fprintf('\n===== results saved: %s =====\n', save_filename);
fprintf('saved variables: ratio_mocap_%d, ratio_imu_%d, ratio_ml_%d\n', fold_num, fold_num, fold_num);

fprintf('\n===== ratio summary by participant =====\n');
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

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_y_list;
y = ratio_imu_y_list;

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_z_list;
y = ratio_imu_z_list;
[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

disp('ML result summary')

x = ratio_mocap_x_list;
y = ratio_ml_x_list;

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_y_list;
y = ratio_ml_y_list;

[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

x = ratio_mocap_z_list;
y = ratio_ml_z_list;
[Rmat, Pmat] = corrcoef(x, y);

R_value   = Rmat(1, 2);
p_value   = Pmat(1, 2);

fprintf('Correlation R = %.3f,  p-value = %.4g\n', R_value, p_value);

if exist('R2_11_store', 'var')
    outDir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~isfolder(outDir), mkdir(outDir); end
    save(fullfile(outDir, 'R2_11_trajectory_store_yawmocap.mat'), 'R2_11_store', '-v7.3');
    fprintf('\n[R2-11] saved: %s\n', fullfile(outDir, 'R2_11_trajectory_store_yawmocap.mat'));
end

function out = compute_shade_coverage(data, mean_traj, std_traj, start_idx, end_idx, nsigma)

    if nargin < 6
        nsigma = 1;
    end

    if ndims(data) ~= 3
        error('data must be a 3D array of size [T x 3 x N].');
    end

    [T, D, N] = size(data);
    if D ~= 3
        error('the second dimension (D) is assumed to be the three axes. current D=%d', D);
    end

    if ~isequal(size(mean_traj), [T, 3]) || ~isequal(size(std_traj), [T, 3])
        error('mean_traj and std_traj must be of size [T x 3].');
    end

    if T==400
        data_seg      = data(21:300, :, :);
        mean_seg      = mean_traj(21:300, :);
        std_seg       = std_traj(21:300, :);
    else
        idx = start_idx:end_idx;
        L   = numel(idx);
        data_seg      = data(idx, :, :);
        mean_seg      = mean_traj(idx, :);
        std_seg       = std_traj(idx, :);
    end

    std_seg(std_seg < 1e-12) = 0;

    axis_in_count    = zeros(1,3);
    axis_total_count = zeros(1,3);

    trial_in_count    = zeros(N, 3);
    trial_total_count = zeros(N, 3);

    for d = 1:3

        mu  = repmat(mean_seg(:,d), 1, N);
        sig = repmat(std_seg(:,d),  1, N);

        X = squeeze(data_seg(:, d, :));
        if isvector(X)
            X = X(:);
        end

        valid_mask = isfinite(X) & isfinite(mu) & isfinite(sig);

        lower_bound = mu - nsigma .* sig;
        upper_bound = mu + nsigma .* sig;

        in_mask = valid_mask & (X >= lower_bound) & (X <= upper_bound);

        axis_in_count(d)    = sum(in_mask(:));
        axis_total_count(d) = sum(valid_mask(:));

        for n = 1:N
            v_n = valid_mask(:,n);
            i_n = in_mask(:,n);
            trial_in_count(n,d)    = sum(i_n);
            trial_total_count(n,d) = sum(v_n);
        end
    end

    axis_ratio = axis_in_count ./ max(axis_total_count, 1);

    trial_ratio = trial_in_count ./ max(trial_total_count, 1);

    out = struct();
    out.axis_in_count    = axis_in_count;
    out.axis_total_count = axis_total_count;
    out.axis_ratio       = axis_ratio;
    out.trial_ratio      = trial_ratio;
    out.nsigma           = nsigma;
    out.start_idx        = start_idx;
    out.end_idx          = end_idx;
end

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
            dz = mean(diff)/std(diff);
            res.test='paired t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='dz'; res.es=dz; res.n=n;
        else
            [p,h,stats] = signrank(A,B,'tail',tail_to_signrank(opt.Tail));
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
        [useT, ~] = normal_decision([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;
        else
            [p,h,stats] = ranksum(A,B,'tail',tail_to_ranksum(opt.Tail));
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

function [useT, p_norm] = normal_decision(x, how)
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

function tail = tail_to_signrank(t)
    switch lower(t)
        case 'left',  tail='left';
        case 'right', tail='right';
        otherwise,    tail='both';
    end
end
function tail = tail_to_ranksum(t)
    switch lower(t)
        case 'left',  tail='smaller';
        case 'right', tail='larger';
        otherwise,    tail='both';
    end
end
