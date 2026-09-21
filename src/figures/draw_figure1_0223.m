clc; clear all; close all;
set(groot,'defaultAxesFontSize',20);

%% data load
load swingData_2508_aftercal_imp+1_est.mat
load(fullfile('data','swingData_IMP-3.5+1_20Hz_spline.mat'));

apdm_rate = 200;
cut_freq = 15;

time = 0.005:0.005:4.5;
time = time';
ts = 0.005;

dark_green = [59 115 54]/255;
dark_red   = [170 44 40]/255;

            

OrientationMethod=0;  

mae_method =4;
mae_method_vel =0;

error_list = []; ds_error_list=[]; rms_list = [];
error_vellist = [];
error_norm_list = [];
ds_error_norm_list  = [];

add_pos_error_ag_list = [];
imp_pos_error_ag_list = [];
imp_rel_pos_error_ag_list =[];

add_pos_error_prop_list = [];
imp_pos_error_prop_list = [];
imp_rel_pos_error_prop_list =[];

raddif=[];

angle_error_axis_list = zeros(900, 3, 20);

angle_error_q_list = [];
angle_error_add_list = [];
angle_error_add2imp = [];
angle_error_plot =[];
angle_error_plot_ref = [];

add_acc_list = [];

imu_roll_error_list = [];
imu_pitch_error_list = [];
imu_yaw_list = [];

apdm_biasV_list = [];
imp_est_list = [];

mean_idx = 1;
z = 1;

for subj = 1:10
    for club = 1
        for trial = 21:30
            if subj==5 && club==3 && trial==5 % IMU recording error
                continue
            elseif subj==8 && club==1 && trial ==30 % magnetometer measurement error
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

%% Orientation from marker
            WristU = g.marker(:,13:15); % inner side of left wrist
            WristM = g.marker(:,10:12); % top
            WristL = g.marker(:,7:9); % outer side of left wrist % i.e. front front
            acc_data = g.apdm(:,1:3);
            gyro_data = g.apdm(:,4:6);

            magnet = g.apdm(:,7:9);

            abs_wrist = (WristU+WristL)./2;

            
            

            m_cal = magnet; % 

            add_est = g.add_est;
            imp_est = g.imp_est;
            motionag = g.dl(:,1:3);

            
            ref_rel_imp = abs_wrist(g.imp,:)-abs_wrist(g.add,:);

            add_pos_error_ag = abs_wrist(g.add,:)-motionag(g.add,:);
            imp_pos_error_ag = abs_wrist(g.imp,:)-motionag(g.imp,:);
            imp_rel_pos_error_ag = ref_rel_imp-(motionag(g.imp,:)-motionag(g.add,:));
            
    	    add_pos_error_ag_list  = [add_pos_error_ag_list ;  abs(add_pos_error_ag) ];
            imp_pos_error_ag_list = [imp_pos_error_ag_list; abs(imp_pos_error_ag) ];
            imp_rel_pos_error_ag_list =[imp_rel_pos_error_ag_list; abs(imp_rel_pos_error_ag) ];

            add_pos_error_prop =abs_wrist(g.add,:)-add_est;
            imp_pos_error_prop =abs_wrist(g.imp,:)-imp_est;
            imp_rel_pos_error_prop =ref_rel_imp - (imp_est-add_est);

            add_pos_error_prop_list = [add_pos_error_prop_list;abs(add_pos_error_prop)];
            imp_pos_error_prop_list = [imp_pos_error_prop_list;abs(imp_pos_error_prop)];
            imp_rel_pos_error_prop_list =[imp_rel_pos_error_prop_list;abs(imp_rel_pos_error_prop)];

            rel_est = imp_est-add_est;

            Cw = (WristU+WristL)./2;     % center wrist
            Lo = WristL-Cw;             % make center origin
            Mo = WristM-Cw;
            Uo = WristU-Cw;

            wL = sqrt(Lo(:,1).^2+Lo(:,2).^2+Lo(:,3).^2);
            wM = sqrt(Mo(:,1).^2+Mo(:,2).^2+Mo(:,3).^2);
            wU = sqrt(Uo(:,1).^2+Uo(:,2).^2+Uo(:,3).^2);

            temp_x = Uo./wU; % as I recall back jitters less than front % or not, change it later heh
            vprime_xw = Lo./wL;
            vprime_top = Mo./wM;
            vprime_zw = zeros(length(vprime_xw),3);
            vprime_yw = zeros(length(vprime_xw),3);

            for i = 1:length(vprime_xw)
                vprime_zw(i,:) = cross(temp_x(i,:),vprime_top(i,:)); %1017 modified
            end
            for i = 1:length(vprime_xw)
                vprime_yw(i,:) = cross(temp_x(i,:),vprime_zw(i,:)); %1017 modified
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
            Cwdot=[dot1 dot2 dot3];
            Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity

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
            
            cut_freq = 10;
            [b, a] = butter(3, cut_freq/(200/2));
            WristMdot = filtfilt(b, a, WristMdot);
            WristMddot = filtfilt(b, a, WristMddot);
            WristUdot = filtfilt(b, a, WristUdot);
            Cwdot = filtfilt(b, a, Cwdot);

            

%% local gyro filtering (marker)

            gL_wrist=zeros(length(vprime_xw),3);
            for i=1:length(vprime_xw)
                gL_wrist(i,:) = [dot(WristMdot(i,:)-Cwdot(i,:),vprime_zw(i,:))./norm(Mo(i,:)), ...
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

            
%% Orientation from apdm
            switch OrientationMethod
                case 0
                    Rinf = R2Lw;
                    qinf = R2Lwq;
                    a_dcm = dcmRot(Rinf,acc_data);
                    w_dcm = dcmRot(Rinf,gyro_data); %omega's w
                    

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
                case 7  % roll,pitch extracted using the pilot-data formula % comes out well

                    local_frame = R2Lw(:,:,g.add);

                    pitch_marker = asin(-local_frame(3,1));
                    roll_marker = atan2(local_frame(3,2), local_frame(3,3));
                    yaw_marker = atan2(local_frame(2,1), local_frame(1,1));
            
                    roll_marker=rad2deg(roll_marker)
                    pitch_marker=rad2deg(pitch_marker)
                    yaw_marker = rad2deg(yaw_marker);
                    

                    acclocal_data = acc_data(g.add,:);
                    acc_global = [acclocal_data(1); acclocal_data(2); acclocal_data(3)];

                    acc_norm = norm(acc_global);
                    acc_normalized = acc_global / acc_norm;  % convert to unit vector
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

                    psi = atan2(-myh, mxh);   % rad  <-- replaced by this
                    rad2deg(psi)

                    psi = -(360-rad2deg(psi))+198.9; %% align magnetic north & mocap north
                    disp('yaw marker and mag value, in that order')
                    disp(yaw_marker)
                    disp(psi)

                    psi = deg2rad(psi);

                    Rx = [1         0           0
                          0 cos(phi) -sin(phi)
                          0 sin(phi)  cos(phi)];
                
                    Ry = [ cos(theta) 0 sin(theta)
                           0          1     0
                          -sin(theta) 0 cos(theta)];
                
                    Rz = [cos(psi) -sin(psi) 0
                          sin(psi)  cos(psi) 0
                          0         0        1];

                    

                    roll = rad2deg(roll)
                    pitch = rad2deg(pitch)
                    
                    imu_roll_error = abs(roll_marker-roll);
                    imu_pitch_error = abs(pitch_marker-pitch);
                    imu_roll_error_list = [imu_roll_error, imu_roll_error_list];
                    imu_pitch_error_list = [imu_pitch_error, imu_pitch_error_list];
                    imu_yaw_list = [yaw_marker, imu_yaw_list];
                    
                    

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
                    
                    
%% reference code
                    
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
            abs_wrist_dot=[dot1 dot2 dot3];
            abs_wrist_dot = filtfilt(b, a, abs_wrist_dot);

            Mtraj = abs_wrist-abs_wrist(g.add,:);
            Mvel = abs_wrist_dot-abs_wrist_dot(g.add,:);

            [centerM,vnM,radM]=circfit3d(Mtraj(g.add:g.fin,:)); vnM=vnM./norm(vnM);                           % address ~ s.finish
        
        
            [centerMs,vnMs,radMs]=circfit3d(Mtraj(g.bst:g.fin,:)); vnMs=vnMs./norm(vnMs);      % bst ~ s.finish
            raddif=[raddif radM-radMs];
            

            ag_wo_g(:,1) = a_dcm(:,1);
            ag_wo_g(:,2) = a_dcm(:,2);
            ag_wo_g(:,3) = a_dcm(:,3)-9.80665; % should this always be subtracted using the norm??
            ag_wo_g(:,:) = ag_wo_g(:,:).*1000;

%% local frame integration

            acc_data = acc_data(:,:).*1000;
            imu_localvel = cumtrapz(time,acc_data);

            imu_localvel = imu_localvel-imu_localvel(g.add,:);
            imu_localvel(1:g.add,:)=0;
            imu_localtraj=cumtrapz(time,imu_localvel);
            imu_localtraj=imu_localtraj-imu_localtraj(g.add,:);
        
            imu_vel= cumtrapz(time,ag_wo_g);
            w_dcm = w_dcm*180/pi;
            angle_cal=cumtrapz(time,w_dcm);
        
%% velocity singularity correction
            imu_vel = imu_vel-imu_vel(g.add,:); %address zeroing
            imu_vel(1:g.add,:)=0; % initial velocity 0
            imu_traj=cumtrapz(time,imu_vel);
            imu_traj=imu_traj-imu_traj(g.add,:);
            
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
        
%% z-direction error trend check
        
        
%% circular trajectory correction
            [center,vn,rad]=circfit3d(imu_trajCal(g.add:g.fin,:)); vn=vn./norm(vn);                % backswing, apdm_trajCal
            sumR=zeros(3);
            n=g.fin-g.add+1;
%% orientation proposed
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
            imu_accelCal=[dot1 dot2 dot3];         % global
        
            imu_localCal=zeros(length(imu_accelCal),3);
%% orientation proposed
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
        
%% imp instant correction (marker)
            sumRI=zeros(3);
            n=g.fin-g.add+1;
%% orientation proposed
            for i=g.add:g.fin
                sumRI=sumRI+(n+g.add-i)*Rinf(:,:,i);
            end
        
            imu_biasImp=inv(sumRI)*(imu_trajCal(g.imp,:)-Mtraj(g.imp,:))'./ts^2;   % local frame accelerometer bias xyz
        
            [dot1, ddot1] = deriv5(imu_velCal(:,1),ts);
            [dot2, ddot2] = deriv5(imu_velCal(:,2),ts);
            [dot3, ddot3] = deriv5(imu_velCal(:,3),ts);
            imu_accelCal=[dot1 dot2 dot3];         % global
            imu_localCal=zeros(length(imu_trajCal),3);
%% orientation proposed switch
            for i=1:length(imu_trajCal)
                imu_localCal(i,:) = Rinf(:,:,i)^(-1)*[imu_accelCal(i,1);imu_accelCal(i,2);imu_accelCal(i,3)];
            end
            ag_wristCal=zeros(length(imu_trajCal),3);
        
        
%% bias adjustment needed??
        
%% orientation proposed
            for i=1:length(imu_trajCal)
                ag_wristCal(i,:) = Rinf(:,:,i)*([imu_localCal(i,1);imu_localCal(i,2);imu_localCal(i,3)]-imu_biasImp); %bias sign may differ per axis
            end
        
            imu_velCalI(:,1)=cumtrapz(ts,ag_wristCal(:,1));
            imu_velCalI(:,2)=cumtrapz(ts,ag_wristCal(:,2));
            imu_velCalI(:,3)=cumtrapz(ts,ag_wristCal(:,3));
            imu_velCalI=imu_velCalI-imu_velCalI(g.add,:);  % address zeroing
            imu_velCalI(1:g.add,:)=0;
            imu_velCalI(g.fin:end,:)=0;
            imu_trajCalI=cumtrapz(ts,imu_velCalI);
            imu_trajCalI=imu_trajCalI-imu_trajCalI(g.add,:);
        
        
%% proposed method integration result
%% imp instant correction (using the video coordinates as is, so it should be similar to the above)
            

            imu_trajCal=cumtrapz(ts,imu_velCal);
            imu_trajCal=imu_trajCal-imu_trajCal(g.add,:);
            

            imp_est_list = [rel_est; imp_est_list];
           

            diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

            traj_lin = imu_trajCal;                   % copy of the original

%% 1) ADD ~ IMP : correction spread linearly / weighting extended to fin
            for k = g.add : g.fin
                w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
                traj_lin(k,:) = imu_trajCal(k,:) - w * diff;  % 1×3 vector
            end
            
            apdm_biasV_list = [apdm_biasV_list; diff];

            apdm_trajCalV = traj_lin;

            
%% driver coefficient correction
            

            diff_subj_all = [ 780.9156 -370.0094  154.5258;
                0,0,0;
                 229.4278, -349.1679, -119.6775]; 

            
            diff_subj = diff_subj_all(3,:);

            traj_lin_subj = imu_trajCal; 
            

%% local frame consistency check
            acc_data_zeroing = acc_data-acc_data(g.add,:);

           

        
%% gyro integration trend check
        
            angle_error=[];
            axis_error=[];
            for i=1:length(time) %s.address:s.finish
                qprod = quaternProd(quaternConj(qinf(i,:)),R2Lwq(i,:)); %proposed vs reference value
                tempAng = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);
                tempAxs = [qprod(2)/sqrt(1-qprod(1)^2), qprod(3)/sqrt(1-qprod(1)^2), qprod(4)/sqrt(1-qprod(1)^2)];
                if tempAng>180
                    tempAng=360-tempAng;
                end
                angle_error=[angle_error, tempAng]; %trial-wise error value, meaning the rotation angle between the two quaternions
                axis_error=[axis_error; tempAxs]; % “the axis (direction) about which rotation occurs” information, not an error
            end
            
            angle_error_ref=[];
            axis_error_ref=[];
            
            for i=1:length(time) %s.address:s.finish
                qprod_ref = quaternProd(quaternConj(qinf_ref(i,:)),R2Lwq(i,:)); %proposed vs reference value
                tempAng = abs(2 * atan2(norm(qprod_ref(2:4)),qprod_ref(1))*180/pi);
                tempAxs = [qprod_ref(2)/sqrt(1-qprod_ref(1)^2), qprod_ref(3)/sqrt(1-qprod_ref(1)^2), qprod_ref(4)/sqrt(1-qprod_ref(1)^2)];
                if tempAng>180
                    tempAng=360-tempAng;
                end
                angle_error_ref=[angle_error_ref, tempAng]; %trial-wise error value, meaning the rotation angle between the two quaternions
                axis_error_ref=[axis_error_ref; tempAxs]; % “the axis (direction) about which rotation occurs” information, not an error
            end

            
            angle_error_plot = [angle_error_plot angle_error'];
            angle_error_plot_ref = [angle_error_plot_ref angle_error_ref'];

            angle_error_q = angle_error(g.add:g.fin);
            angle_error_imp = angle_error(g.add:g.imp);
            angle_error_add_list = [angle_error_add_list abs(angle_error(g.add))];

            angle_error_q_list = [angle_error_q_list mean(angle_error_q)];
            angle_error_add2imp = [angle_error_add2imp mean(angle_error_imp)];

            angle_error_axis = []; % globally align check
            angle_error_axis_ref = [];
%% locally align check, ' added
            for i = 1:length(time)
                
                R1 = R2Lw(:,:,i);
                R2 = Rinf(:,:,i);  % example of the second rotation matrix
                R_diff = R2 * R1'; %how much to rotate the reference value to obtain the estimate % angle error in the world frame can be interpreted directly
        
                eul_angles = rotm2eul(R_diff, 'ZYX');
        
                roll_error_deg = rad2deg(eul_angles(1));   % x-axis (roll) error
                pitch_error_deg = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg = rad2deg(eul_angles(3));    % z-axis (yaw) error

%% reference code added
                R1 = R2Lw(:,:,i);
                R2 = Rinf_ref(:,:,i);  % example of the second rotation matrix
                R_diff = R2 * R1'; %how much to rotate the reference value to obtain the estimate % angle error in the world frame can be interpreted directly

                eul_angles = rotm2eul(R_diff, 'ZYX');

                roll_error_deg_ref = rad2deg(eul_angles(1));   % x-axis (roll) error
                pitch_error_deg_ref = rad2deg(eul_angles(2));  % y-axis (pitch) error
                yaw_error_deg_ref = rad2deg(eul_angles(3));    % z-axis (yaw) error

        
                angle_error_axis = [angle_error_axis; roll_error_deg, pitch_error_deg, yaw_error_deg];

                angle_error_axis_ref = [angle_error_axis_ref; roll_error_deg_ref, pitch_error_deg_ref, yaw_error_deg_ref];

            end
       
            angle_error_axis_list(:,:,z) = angle_error_axis;

            angle_error_axis_list_ref(:,:,z) = angle_error_axis_ref;

            
            plot_ds_ref(:,:,z) = Mtraj;
            plot_ds_prop(:,:,z) = apdm_trajCalV;
            subj_ds_imu(:,:,z) = imu_traj;
            subj_local_imu(:,:,z) = acc_data_zeroing;

           

            subj_plot_ds_ref(:,:,z) = Mtraj;
            subj_plot_ds_prop(:,:,z) = apdm_trajCalV;

            plot_ds_imu(:,:,z) = imu_traj;
            

            

            switch mae_method
                case 0
                    test_drift = imu_traj;
                case 1
                    test_drift = imu_trajCal; %wait, in 3D this is more accurate than apdm_trajCalV??
                case 2
                    test_drift = imu_trajCalL;
                case 3
                    test_drift = imu_trajCalI;
                case 4
                    test_drift = apdm_trajCalV; % traj_lin_subj, imu only  % apdm_trajCalV trial by trial correction
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
        
%% Mtraj is the wrist
            ds_error = Mtraj(g.bst:g.imp,:)-test_drift(g.bst:g.imp,:);
            ds_error_list = [ds_error_list; mean(abs(ds_error))];
            

            ds_error_norm = sqrt(sum((Mtraj(g.add:g.imp,:)-test_drift(g.add:g.imp,:)).^2, 2));

            ds_error_norm_list = [ds_error_norm_list; mean(ds_error_norm)];
            

            error = Mtraj(g.add:g.fin,:)-test_drift(g.add:g.fin,:);

            rmsErr = sqrt( mean( error(:).^2 ) );
            rms_list = [rmsErr rms_list];

            error_norm = sqrt(sum((Mtraj(g.add:g.fin,:)-test_drift(g.add:g.fin,:)).^2, 2));
            error_norm_list = [error_norm_list mean(error_norm)];

%% Wristmdot, Cwdot filtering check
            error_vel = Mvel(g.add:g.fin,:)-test_drift_vel(g.add:g.fin,:);
            error_list = [error_list; mean(abs(error))];
            error_vellist = [error_vellist; mean(abs(error_vel))];
            

            z= z+1;

        end
    end
end

q=1;
for subj = 12:20
    for club = 1
        for trial = 1:10
            if subj==19 && club==1 && trial==8
                continue
            end
            s = swingData(subj).clubN(club).trialN(trial);
            Mtraj_pro=s.Mwrist-s.Mwrist(s.address,:);
            plot_ds_ref_pro(:,:,q) = Mtraj_pro;
            q=q+1;
        end
    end
end

time = 1:900;

plot_ds_ref = plot_ds_ref.*0.1;
plot_ds_prop = plot_ds_prop.*0.1;
plot_ds_imu = plot_ds_imu.*0.1;
subj_ds_imu = subj_ds_imu.*0.1;
subj_local_imu = subj_local_imu.*0.1;

plot_ds_ref_pro = plot_ds_ref_pro.*100;

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

%% ellipse code for all participants and each participant

num_subjects   = 10;
Ntotal         = size(plot_ds_ref, 3);
trials_per_subj = [10 10 10 10 10 10 10 9 10 10];   % length = num_subjects
assert(sum(trials_per_subj) == Ntotal, ...
       'trials_per_subj sum does not match the 3rd dimension of plot_ds_ref.');

trial_subj_ids = zeros(1, Ntotal);
idx = 1;
for s = 1:num_subjects
    n_tr = trials_per_subj(s);
    trial_subj_ids(idx:idx+n_tr-1) = s;
    idx = idx + n_tr;
end

figure(10000); clf; hold on;

colors_ama = [ ...
    0.05, 0.20, 0.55;   % S1  dark navy
    0.10, 0.40, 0.80;   % S2  royal blue
    0.20, 0.60, 0.95;   % S3  dodger blue
    0.00, 0.45, 0.70;   % S4  teal blue
    0.00, 0.65, 0.85;   % S5  cerulean
    0.30, 0.30, 0.75;   % S6  slate blue
    0.10, 0.55, 0.55;   % S7  dark cyan
    0.40, 0.70, 0.95;   % S8  cornflower
    0.55, 0.55, 0.95;   % S9  medium slate
    0.05, 0.35, 0.60;   % S10 steel blue
];

scale_factor = 1;
ref_means  = nan(num_subjects,3); ref_stds  = nan(num_subjects,3);

h_xy_ama = gobjects(num_subjects, 1);
h_xz_ama = gobjects(num_subjects, 1);
h_yz_ama = gobjects(num_subjects, 1);

for subj = 1:num_subjects
    idx_subj = find(trial_subj_ids == subj);
    if isempty(idx_subj)
        fprintf('  [WARN] Subject %d has no trials. Skip.\n', subj);
        continue;
    end

    ref_data_subj = squeeze(plot_ds_ref(g.imp, :, idx_subj)).';
    ref_mean  = mean(ref_data_subj, 1); ref_std  = std(ref_data_subj,0,1);
    ref_means(subj,:)  = ref_mean;  ref_stds(subj,:)  = ref_std;

    curr_color = colors_ama(subj, :);

    scatter3(ref_data_subj(:,1), ref_data_subj(:,2), ref_data_subj(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 1);

    theta = linspace(0, 2*pi, 100);
    sf = scale_factor;
    h_xy_ama(subj) = plot3(ref_std(1)*sf*cos(theta) + ref_mean(1), ...
          ref_std(2)*sf*sin(theta) + ref_mean(2), ...
          zeros(size(theta)) + ref_mean(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
    h_xz_ama(subj) = plot3(ref_std(1)*sf*cos(theta) + ref_mean(1), ...
          zeros(size(theta)) + ref_mean(2), ...
          ref_std(3)*sf*sin(theta) + ref_mean(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
    h_yz_ama(subj) = plot3(zeros(size(theta)) + ref_mean(1), ...
          ref_std(2)*sf*cos(theta) + ref_mean(2), ...
          ref_std(3)*sf*sin(theta) + ref_mean(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
end

xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
axis equal;
xlim([0 20]); ylim([-5 15]); zlim([0 20])
grid on;
set(gca, 'XTick', 0:5:20, 'YTick', -5:5:15, 'ZTick', 0:5:20);

views = [0, 0; 90, 0; 0, 90];
view_names = {'xz', 'yz', 'xy'};
ring_handles_ama = {h_xz_ama, h_yz_ama, h_xy_ama};  % view-specific rings to show

for i = 1:3
    set(h_xy_ama(isvalid(h_xy_ama)), 'Visible', 'off');
    set(h_xz_ama(isvalid(h_xz_ama)), 'Visible', 'off');
    set(h_yz_ama(isvalid(h_yz_ama)), 'Visible', 'off');
    view(views(i,1), views(i,2));
    drawnow;
    print(gcf, sprintf('ama_plot3d_%s.svg', view_names{i}), '-dsvg', '-vector');

    h_show = ring_handles_ama{i};
    set(h_show(isvalid(h_show)), 'Visible', 'on');
    drawnow;
    print(gcf, sprintf('ama_plot3d_%s_ring.svg', view_names{i}), '-dsvg', '-vector');
end

%% professional participant data

num_subjects_pro   = 9;
Ntotal_pro         = size(plot_ds_ref_pro, 3);
trials_per_subj_pro = [10 10 10 10 10 10 10 9 10];   % length = num_subjects
assert(sum(trials_per_subj_pro) == Ntotal_pro, ...
       'trials_per_subj sum does not match the 3rd dimension of plot_ds_ref.');

trial_subj_ids_pro = zeros(1, Ntotal_pro);
idx = 1;
for s = 1:num_subjects_pro
    n_tr = trials_per_subj_pro(s);
    trial_subj_ids_pro(idx:idx+n_tr-1) = s;
    idx = idx + n_tr;
end

figure(11000); clf; hold on;

colors_pro = [ ...
    0.55, 0.05, 0.05;   % P1  dark maroon
    0.80, 0.10, 0.10;   % P2  crimson
    0.95, 0.25, 0.10;   % P3  scarlet
    0.70, 0.20, 0.00;   % P4  burnt orange
    0.90, 0.45, 0.10;   % P5  tangerine
    0.85, 0.15, 0.30;   % P6  raspberry
    0.95, 0.55, 0.20;   % P7  amber
    0.75, 0.35, 0.15;   % P8  sienna
    0.60, 0.10, 0.20;   % P9  burgundy
];

scale_factor = 1;
ref_means_pro  = nan(num_subjects_pro,3); ref_stds_pro  = nan(num_subjects_pro,3);

h_xy_pro = gobjects(num_subjects_pro, 1);
h_xz_pro = gobjects(num_subjects_pro, 1);
h_yz_pro = gobjects(num_subjects_pro, 1);

for subj = 1:num_subjects_pro
    idx_subj = find(trial_subj_ids_pro == subj);
    if isempty(idx_subj)
        fprintf('  [WARN] Subject %d has no trials. Skip.\n', subj);
        continue;
    end

    ref_data_subj_pro  = squeeze(plot_ds_ref_pro(700-1, :, idx_subj)).';
    ref_mean_pro  = mean(ref_data_subj_pro, 1); ref_std_pro  = std(ref_data_subj_pro,0,1);
    ref_means_pro(subj,:)  = ref_mean_pro;  ref_stds_pro(subj,:)  = ref_std_pro;

    curr_color = colors_pro(subj, :);

    scatter3(ref_data_subj_pro(:,1), ref_data_subj_pro(:,2), ref_data_subj_pro(:,3), ...
             30, curr_color, 'filled', 'MarkerFaceAlpha', 1);

    theta = linspace(0, 2*pi, 100);
    sf = scale_factor;
    h_xy_pro(subj) = plot3(ref_std_pro(1)*sf*cos(theta) + ref_mean_pro(1), ...
          ref_std_pro(2)*sf*sin(theta) + ref_mean_pro(2), ...
          zeros(size(theta)) + ref_mean_pro(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
    h_xz_pro(subj) = plot3(ref_std_pro(1)*sf*cos(theta) + ref_mean_pro(1), ...
          zeros(size(theta)) + ref_mean_pro(2), ...
          ref_std_pro(3)*sf*sin(theta) + ref_mean_pro(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
    h_yz_pro(subj) = plot3(zeros(size(theta)) + ref_mean_pro(1), ...
          ref_std_pro(2)*sf*cos(theta) + ref_mean_pro(2), ...
          ref_std_pro(3)*sf*sin(theta) + ref_mean_pro(3), ...
          'Color', [curr_color, 0.5], 'LineWidth', 1);
end

xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
axis equal;
xlim([0 20]); ylim([0 20]); zlim([5 25])
set(gca, 'XTick', 0:5:20, 'YTick', 0:5:20, 'ZTick', 5:5:25);
grid on;

ring_handles_pro = {h_xz_pro, h_yz_pro, h_xy_pro};

for i = 1:3
    set(h_xy_pro(isvalid(h_xy_pro)), 'Visible', 'off');
    set(h_xz_pro(isvalid(h_xz_pro)), 'Visible', 'off');
    set(h_yz_pro(isvalid(h_yz_pro)), 'Visible', 'off');
    view(views(i,1), views(i,2));
    drawnow;
    print(gcf, sprintf('pro_plot3d_%s.svg', view_names{i}), '-dsvg', '-vector');

    h_show = ring_handles_pro{i};
    set(h_show(isvalid(h_show)), 'Visible', 'on');
    drawnow;
    print(gcf, sprintf('pro_plot3d_%s_ring.svg', view_names{i}), '-dsvg', '-vector');
end

stats = struct();

figure(12000); clf; hold on;
xlabel('X(cm)'); ylabel('Y(cm)'); zlabel('Z(cm)');
view(90,0); axis equal;
xlim([0 30]); ylim([0 30]); zlim([0 30])
set(gca, 'XTick', 0:5:30, 'YTick', 0:5:30, 'ZTick', 0:5:25);
grid on;

print(gcf, sprintf('plot3d_%s.svg'), '-dsvg', '-vector');

stats.ref.mean_of_means = mean(ref_means, 1, 'omitnan');
stats.ref.std_of_means  = std (ref_means, 0, 1, 'omitnan');
stats.ref.mean_of_stds  = mean(ref_stds,  1, 'omitnan');
stats.ref.std_of_stds   = std (ref_stds,  0, 1, 'omitnan');
disp(stats.ref)

stats_pro = struct();

stats_pro.ref.mean_of_means = mean(ref_means_pro, 1, 'omitnan');
stats_pro.ref.std_of_means  = std (ref_means_pro, 0, 1, 'omitnan');
stats_pro.ref.mean_of_stds  = mean(ref_stds_pro,  1, 'omitnan');
stats_pro.ref.std_of_stds   = std (ref_stds_pro,  0, 1, 'omitnan');
disp(stats_pro.ref)

A = ref_stds_pro;      % 10 x 3
B = ref_stds;  % 9 x 3

res_indep = compare_methods(A, B, ...
    'Name',   'STD ref(10) vs ref\_pro(9)', ...
    'Paired', false, ...      % independent groups
    'Tail',   'left', ...     % A<B ? (ref std is smaller, if you want to check)
    'Metric', 'axis', ...
    'Test',   'auto');

for d = 1:3
    ax = res_indep.axis{d};
    fprintf('Axis %d: meanA=%.3f, meanB=%.3f, p=%.4f, test=%s\n', ...
        d, ax.meanA, ax.meanB, ax.p, ax.test);
end

A = ref_means_pro;      % 10 x 3
B = ref_means;  % 9 x 3

res_indep = compare_methods(A, B, ...
    'Name',   'STD ref(10) vs ref\_pro(9)', ...
    'Paired', false, ...      % independent groups
    'Tail',   'right', ...     % A<B ? (ref std is smaller, if you want to check)
    'Metric', 'axis', ...
    'Test',   'auto');

for d = 1:3
    ax = res_indep.axis{d};
    fprintf('Axis %d: meanA=%.3f, meanB=%.3f, p=%.4f, test=%s\n', ...
        d, ax.meanA, ax.meanB, ax.p, ax.test);
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

    if opt.Paired
        if size(A,1) ~= size(B,1)
            error('Paired=true but A and B have different numbers of rows. (A:%d, B:%d)', size(A,1), size(B,1));
        end
        keep = all(isfinite(A),2) & all(isfinite(B),2);
        A = A(keep,:);  
        B = B(keep,:);
        if ~isempty(opt.Group), opt.Group = opt.Group(keep); end
    else
        keepA = all(isfinite(A),2);
        keepB = all(isfinite(B),2);
        A = A(keepA,:);
        B = B(keepB,:);
        if ~isempty(opt.Group)
            warning('Paired=false but the Group option was given. Group is not used in independent-sample mode.');
            opt.Group = [];
        end
    end

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
            n_eff = sum(A~=B);                         % 0 -differences excluded, effective n n
            res.test='Wilcoxon signed-rank'; res.p=p; res.h=h; res.n=n_eff;

            if isfield(stats,'zval')                   % approximate
                z = stats.zval;
                r = z / sqrt(n_eff);
                res.approx = true;
                res.z = z; res.eff = 'r (z/sqrt(n))'; res.es = r;
            else                                       % exact → rank-biserial r
                Wplus = stats.signedrank;              % rank sum of positive differences
                Rsum  = n_eff*(n_eff+1)/2;
                r_rb  = (2*Wplus - Rsum) / Rsum;       % [-1,1]
                res.approx = false;
                res.eff = 'rank-biserial r'; res.es = r_rb;
            end
        end
        res.normality_p = p_norm;
        res.meanA = mean(A); 
        res.meanB = mean(B); 
        res.meanDiff = mean(diff);
    else
        n1=numel(A); n2=numel(B);
        [useT, ~] = normal_decision([A(:);B(:)], opt.Test);
        if useT
            [h,p,ci,stats] = ttest2(A,B,'Vartype','unequal','Tail',opt.Tail);
            sp = sqrt(((n1-1)*var(A)+(n2-1)*var(B))/(n1+n2-2));
            d  = (mean(A)-mean(B))/sp;                 % Cohen's d
            res.test='two-sample t-test'; res.p=p; res.h=h; res.ci=ci;
            res.t=stats.tstat; res.df=stats.df; res.eff='d'; res.es=d; res.n1=n1; res.n2=n2;

            res.meanA = mean(A);
            res.meanB = mean(B);
            res.meanDiff = mean(A) - mean(B);
        else
            [p,h,stats] = ranksum(A,B,'tail',tail_to_ranksum(opt.Tail));
            res.test='Mann-Whitney U'; res.p=p; res.h=h; res.n1=n1; res.n2=n2;

            if isfield(stats,'zval')                   % approximate
                z = stats.zval;
                r = z / sqrt(n1+n2);
                res.approx = true;
                res.z = z; res.eff='r (z/sqrt(N))'; res.es=r;
            else                                       % exact → rank-biserial r
                W = stats.ranksum;                     % A(first argument) rank sum
                U1 = W - n1*(n1+1)/2;
                r_rb = 1 - 2*U1/(n1*n2);               % [-1,1], A<B -> negative
                res.approx = false;
                res.eff='rank-biserial r'; res.es=r_rb;
            end
            res.meanA = mean(A); 
            res.meanB = mean(B);
            res.meanDiff = mean(A) - mean(B);
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

