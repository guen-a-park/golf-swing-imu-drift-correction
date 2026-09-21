%% mae_method 0, 5, 6 comparison analysis
% ML trajectory vs IMU only vs IMU+Cal comparison

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
dark_blue  = [70 100 180]/255;
dark_gray  = [0.5 0.5 0.5];  % darker gray for method 0

OrientationMethod = 7;

%% plot options
show_event_shade = true;   % true: show event-time shade, false: show xline only
event_color = [0.85 0.85 0.85];  % shade color
event_alpha = 0.4;               % shade alpha

event_line_color = [0,0,0];

%% folder path settings

mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); 

nSubj_ml = 10;
clubs_ml = {'driver','iron','fast'};
nRows_ml = 10; nCols_ml = 3;
nTrials = 10;

ml_start_ref = 401;
ml_end_ref = 800;

plot_x_start = 320;
plot_x_end = 850;

fig1000_xlim = [266 880];           % x-axis range (adjustable)
fig1000_ylim = [-100 50; -100 51; -50 100];  % y-axis ranges [subplot1; subplot2; subplot3] (adjustable)
ml_plot_start = 401;              % ML trajectory start point
ml_plot_end = 800;                % ML trajectory end point

%% ML data load
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

%% time-point / segment name definitions
point_names_imu = {'ml_start', 'add', 'bst', 'imp', 'fin', 'ml_end'};
point_names_ml = {'ml_start', 'bst', 'imp', 'ml_end'};

range_names = {'start_to_bst', 'start_to_imp', 'start_to_end'};

methods = [0, 5, 6];
method_names = {'IMU only', 'IMU+Cal', 'ML'};

%% initialize result storage struct
for m_idx = 1:2  % method 0, 5
    m_name = sprintf('m%d', methods(m_idx));
    
    for p = 1:length(point_names_imu)
        pn = point_names_imu{p};
        results.(m_name).points.(pn).error_xyz_list = [];
        results.(m_name).points.(pn).error_norm_list = [];
    end
    
    for r = 1:length(range_names)
        rn = range_names{r};
        results.(m_name).ranges.(rn).mae_xyz_list = [];
        results.(m_name).ranges.(rn).mae_norm_list = [];
        results.(m_name).ranges.(rn).rmse_xyz_list = [];
        results.(m_name).ranges.(rn).rmse_norm_list = [];
    end
end

m_name = 'm6';
for p = 1:length(point_names_ml)
    pn = point_names_ml{p};
    results.(m_name).points.(pn).error_xyz_list = [];
    results.(m_name).points.(pn).error_norm_list = [];
end

for r = 1:length(range_names)
    rn = range_names{r};
    results.(m_name).ranges.(rn).mae_xyz_list = [];
    results.(m_name).ranges.(rn).mae_norm_list = [];
    results.(m_name).ranges.(rn).rmse_xyz_list = [];
    results.(m_name).ranges.(rn).rmse_norm_list = [];
end

max_frames = 900;
max_trials_per_subj = 10;
plot_ds_ref_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);
plot_ds_imu_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);
plot_ds_imucal_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);
plot_ds_ml_all = nan(max_frames, 3, max_trials_per_subj, nSubj_ml);

event_add_all = nan(max_trials_per_subj, nSubj_ml);
event_bst_all = nan(max_trials_per_subj, nSubj_ml);
event_imp_all = nan(max_trials_per_subj, nSubj_ml);
event_fin_all = nan(max_trials_per_subj, nSubj_ml);

subj_id_list = [];
trial_id_list = [];

%% main loop
fprintf('\nProcessing trials...\n');
z_total = 1;

for subj = 1:10
    z_subj = 1;
    club = 1;
   

    for trial = 21:30
        if subj==8 && club==1 && trial==30
            continue
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
        
        if g.fin > 900
            g.fin = 900;
        end
        
%% marker data (same as original)
        WristU = g.marker(:,13:15);
        WristM = g.marker(:,10:12);
        WristL = g.marker(:,7:9);
        abs_wrist = (WristU + WristL) ./ 2;
        
        acc_data = g.apdm(:,1:3);
        gyro_data = g.apdm(:,4:6);
        magnet = g.apdm(:,7:9);
        m_cal = magnet;  % same as original
        
        add_est = g.add_est;
        imp_est = g.imp_est;

        rel_est = imp_est - add_est;
        

        
%% R2Lw computation (same as original)
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
        
%% OrientationMethod = 7 (same as original)
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
        
        

%% 0112 psi fix
        psi0_deg = 191.53;
        alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 7.16 deg
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

        a_dcm = dcmRot(Rinf, acc_data);
        
%% trajectory integration (same as original)
        ag_wo_g = zeros(size(a_dcm));
        ag_wo_g(:,1) = a_dcm(:,1);
        ag_wo_g(:,2) = a_dcm(:,2);
        ag_wo_g(:,3) = a_dcm(:,3) - 9.80665;
        ag_wo_g = ag_wo_g .* 1000;  % m/s² → mm/s²
        
        imu_vel = cumtrapz(time, ag_wo_g);
        imu_vel = imu_vel - imu_vel(g.add,:);  % address zeroing
        imu_vel(1:g.add,:) = 0;  % zero initial velocity
        
        imu_traj = cumtrapz(time, imu_vel);
        imu_traj = imu_traj - imu_traj(g.add,:);
        
%% velocity correction (imu_trajCal = method 5 intermediate step)
        velCalRate = 1;
        imu_velCal = imu_vel;
        
        for i = g.add:g.bst
            imu_velCal(i,:) = imu_velCal(i,:) - imu_velCal(g.bst,:) ./ (g.bst - g.add) .* (i - g.add) * velCalRate;
        end
        imu_velCal(g.bst+1:end,:) = imu_velCal(g.bst+1:end,:) - imu_velCal(g.bst+1,:) * velCalRate;
        for i = g.bst:length(imu_velCal)
            imu_velCal(i,:) = imu_velCal(i,:) - imu_velCal(g.fin,:) ./ (g.fin - g.bst) .* (i - g.bst) * velCalRate;
        end
        imu_velCal(g.fin+1:end,:) = 0;
        
        imu_trajCal = cumtrapz(ts, imu_velCal);
        imu_trajCal = imu_trajCal - imu_trajCal(g.add,:);

        diff = [(imu_trajCal(g.imp,1)-rel_est(1)) (imu_trajCal(g.imp,2)-rel_est(2)) (imu_trajCal(g.imp,3)-rel_est(3))];

        traj_lin = imu_trajCal;                   % copy of the original

        for k = g.add : g.fin
            w = (k - g.add) / (g.imp - g.add); % 0 → 1 linear weight
            traj_lin(k,:) = imu_trajCal(k,:) - w * diff;  % 1×3 vector
        end

        n_rows_fin = size(traj_lin(g.fin+1:end,:), 1);  % 52
        traj_lin(g.fin+1:end,:) = repmat(traj_lin(g.fin,:), n_rows_fin, 1);

        apdm_trajCalV = traj_lin;

        
%% linear correction (traj_lin_subj = method 5)

        if trial>20
            diff_ml = imu_trajCal(g.imp,:)-ml_est.(clubs_ml{club})(trial-20,:,subj); 
        end

        
        traj_lin_subj = imu_trajCal;
        for k = g.add:g.fin
            w = (k - g.add) / (g.imp - g.add);
            traj_lin_subj(k,:) = imu_trajCal(k,:) - w * diff_ml;
        end
        n_rows_fin = size(traj_lin_subj(g.fin+1:end,:), 1);
        traj_lin_subj(g.fin+1:end,:) = repmat(traj_lin_subj(g.fin,:), n_rows_fin, 1);
        
%% ML trajectory (method 6)
        ml_traj_check = ml_traj_est.(clubs_ml{club}){trial-20, subj};
        
        if isempty(ml_traj_check)
            fprintf('  [WARN] Subject %d, Trial %d: ML data missing. Skip.\n', subj, trial);
            continue
        end
        
%% Reference trajectory
        Mtraj = abs_wrist - abs_wrist(g.add,:);
        
%% time-point index definitions
        points_imu = struct();
        points_imu.ml_start = ml_start_ref;
        points_imu.add = g.add;
        points_imu.bst = g.bst;
        points_imu.imp = g.imp;
        points_imu.fin = g.fin;
        points_imu.ml_end = ml_end_ref;
        
        points_ref_ml = struct();
        points_ref_ml.ml_start = ml_start_ref;
        points_ref_ml.bst = g.bst;
        points_ref_ml.imp = g.imp;
        points_ref_ml.ml_end = ml_end_ref;
        
        points_ml = struct();
        points_ml.ml_start = 1;
        points_ml.bst = g.bst - 350;
        points_ml.imp = g.imp - 350;
        points_ml.ml_end = 450;
        
%% error computation per method
        for m_idx = 1:length(methods)
            mae_method = methods(m_idx);
            m_name = sprintf('m%d', mae_method);
            
            switch mae_method
                case 0
                    test_drift = imu_traj;
                case 4
                    test_drift = apdm_trajCalV;
                case 5
                    test_drift = traj_lin_subj;
                case 6
                    test_drift = ml_traj_check;
            end
            
            if mae_method == 6
                for p = 1:length(point_names_ml)
                    pn = point_names_ml{p};
                    
                    idx_ref = points_ref_ml.(pn);
                    idx_ml = points_ml.(pn);
                    
                    if idx_ml < 1 || idx_ml > size(test_drift, 1)
                        error_pt = [NaN NaN NaN];
                    else
                        error_pt = Mtraj(idx_ref, :) - test_drift(idx_ml, :);
                    end
                    
                    results.(m_name).points.(pn).error_xyz_list = ...
                        [results.(m_name).points.(pn).error_xyz_list; abs(error_pt)];
                    results.(m_name).points.(pn).error_norm_list = ...
                        [results.(m_name).points.(pn).error_norm_list; norm(error_pt)];
                end
            else
                for p = 1:length(point_names_imu)
                    pn = point_names_imu{p};
                    
                    idx_ref = points_imu.(pn);
                    error_pt = Mtraj(idx_ref, :) - test_drift(idx_ref, :);
                    
                    results.(m_name).points.(pn).error_xyz_list = ...
                        [results.(m_name).points.(pn).error_xyz_list; abs(error_pt)];
                    results.(m_name).points.(pn).error_norm_list = ...
                        [results.(m_name).points.(pn).error_norm_list; norm(error_pt)];
                end
            end
            
        end
        
%% store data for plotting
        plot_ds_ref_all(:, :, z_subj, subj) = Mtraj;
        plot_ds_imu_all(:, :, z_subj, subj) = imu_traj;
        plot_ds_imucal_all(:, :, z_subj, subj) = traj_lin_subj;
        
        traj_len = size(ml_traj_check, 1);
        ml_ref_indices = ml_start_ref : (ml_start_ref + traj_len - 1);
        plot_ds_ml_all(ml_ref_indices, :, z_subj, subj) = ml_traj_check;
        
        event_add_all(z_subj, subj) = g.add;
        event_bst_all(z_subj, subj) = g.bst;
        event_imp_all(z_subj, subj) = g.imp;
        event_fin_all(z_subj, subj) = g.fin;
        
        subj_id_list = [subj_id_list; subj];
        trial_id_list = [trial_id_list; trial];
        
        z_subj = z_subj + 1;
        z_total = z_total + 1;
    end
    
    fprintf('Subject %d: %d trials processed\n', subj, z_subj-1);
end

%% unit conversion (mm → cm)
for m_idx = 1:2
    m_name = sprintf('m%d', methods(m_idx));
    
    for p = 1:length(point_names_imu)
        pn = point_names_imu{p};
        results.(m_name).points.(pn).error_xyz_list = results.(m_name).points.(pn).error_xyz_list * 0.1;
        results.(m_name).points.(pn).error_norm_list = results.(m_name).points.(pn).error_norm_list * 0.1;
    end
    
    for r = 1:length(range_names)
        rn = range_names{r};
        results.(m_name).ranges.(rn).mae_xyz_list = results.(m_name).ranges.(rn).mae_xyz_list * 0.1;
        results.(m_name).ranges.(rn).mae_norm_list = results.(m_name).ranges.(rn).mae_norm_list * 0.1;
        results.(m_name).ranges.(rn).rmse_xyz_list = results.(m_name).ranges.(rn).rmse_xyz_list * 0.1;
        results.(m_name).ranges.(rn).rmse_norm_list = results.(m_name).ranges.(rn).rmse_norm_list * 0.1;
    end
end

m_name = 'm6';
for p = 1:length(point_names_ml)
    pn = point_names_ml{p};
    results.(m_name).points.(pn).error_xyz_list = results.(m_name).points.(pn).error_xyz_list * 0.1;
    results.(m_name).points.(pn).error_norm_list = results.(m_name).points.(pn).error_norm_list * 0.1;
end

for r = 1:length(range_names)
    rn = range_names{r};
    results.(m_name).ranges.(rn).mae_xyz_list = results.(m_name).ranges.(rn).mae_xyz_list * 0.1;
    results.(m_name).ranges.(rn).mae_norm_list = results.(m_name).ranges.(rn).mae_norm_list * 0.1;
    results.(m_name).ranges.(rn).rmse_xyz_list = results.(m_name).ranges.(rn).rmse_xyz_list * 0.1;
    results.(m_name).ranges.(rn).rmse_norm_list = results.(m_name).ranges.(rn).rmse_norm_list * 0.1;
end

plot_ds_ref_all = plot_ds_ref_all * 0.1;
plot_ds_imu_all = plot_ds_imu_all * 0.1;
plot_ds_imucal_all = plot_ds_imucal_all * 0.1;
plot_ds_ml_all = plot_ds_ml_all * 0.1;

%% Figure 1000: participant means → grand mean (Subject-level averaging)
subj_ref_means = nan(max_frames, 3, nSubj_ml);
subj_imu_means = nan(max_frames, 3, nSubj_ml);
subj_imucal_means = nan(max_frames, 3, nSubj_ml);
subj_ml_means = nan(max_frames, 3, nSubj_ml);
subj_event_add = nan(nSubj_ml, 1);
subj_event_bst = nan(nSubj_ml, 1);
subj_event_imp = nan(nSubj_ml, 1);
subj_event_fin = nan(nSubj_ml, 1);

for subj = 1:nSubj_ml
    n_trials_subj = sum(~isnan(squeeze(plot_ds_ref_all(1,1,:,subj))));
    if n_trials_subj > 0
        subj_ref_means(:,:,subj) = mean(plot_ds_ref_all(:,:,1:n_trials_subj,subj), 3, 'omitnan');
        subj_imu_means(:,:,subj) = mean(plot_ds_imu_all(:,:,1:n_trials_subj,subj), 3, 'omitnan');
        subj_imucal_means(:,:,subj) = mean(plot_ds_imucal_all(:,:,1:n_trials_subj,subj), 3, 'omitnan');
        subj_ml_means(:,:,subj) = mean(plot_ds_ml_all(:,:,1:n_trials_subj,subj), 3, 'omitnan');
        subj_event_add(subj) = mean(event_add_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_bst(subj) = mean(event_bst_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_imp(subj) = mean(event_imp_all(1:n_trials_subj,subj), 'omitnan');
        subj_event_fin(subj) = mean(event_fin_all(1:n_trials_subj,subj), 'omitnan');
    end
end

ref_mean_all = mean(subj_ref_means, 3, 'omitnan');
ref_std_all = std(subj_ref_means, 0, 3, 'omitnan');
imu_mean_all = mean(subj_imu_means, 3, 'omitnan');
imu_std_all = std(subj_imu_means, 0, 3, 'omitnan');
imucal_mean_all = mean(subj_imucal_means, 3, 'omitnan');
imucal_std_all = std(subj_imucal_means, 0, 3, 'omitnan');
ml_mean_all = mean(subj_ml_means, 3, 'omitnan');
ml_std_all = std(subj_ml_means, 0, 3, 'omitnan');

event_add_mean_all = mean(subj_event_add, 'omitnan');
event_add_std_all = std(subj_event_add, 0, 'omitnan');
event_bst_mean_all = mean(subj_event_bst, 'omitnan');
event_bst_std_all = std(subj_event_bst, 0, 'omitnan');
event_imp_mean_all = mean(subj_event_imp, 'omitnan');
event_imp_std_all = std(subj_event_imp, 0, 'omitnan');
event_fin_mean_all = mean(subj_event_fin, 'omitnan');
event_fin_std_all = std(subj_event_fin, 0, 'omitnan');

fprintf('Figure 1000: participant means → grand mean approach (N=%d subjects)\n', nSubj_ml);

figure(1000);
clf;
fig1000_size_cm = [16 10];
set(gcf, 'Color', 'w', 'Units', 'centimeters', ...
         'Position', [2 2 fig1000_size_cm]);

left_margin = 0.13;
top_margin = 0.05;
bottom_margin = 0.08;
plot_width = 0.82;
gap = 0.05;  % <-- adjust only this value
plot_height = (1 - top_margin - bottom_margin - gap * 2) / 3;

for k = 1:3
    subplot(3,1,k);
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);
    
    hold on;
    
    y_min_shade = fig1000_ylim(k, 1);
    y_max_shade = fig1000_ylim(k, 2);
    
    plot(fig1000_xlim, [0 0], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
    
    if show_event_shade
        fill([event_add_mean_all - event_add_std_all, event_add_mean_all + event_add_std_all, ...
              event_add_mean_all + event_add_std_all, event_add_mean_all - event_add_std_all], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill([event_bst_mean_all - event_bst_std_all, event_bst_mean_all + event_bst_std_all, ...
              event_bst_mean_all + event_bst_std_all, event_bst_mean_all - event_bst_std_all], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill([event_imp_mean_all - event_imp_std_all, event_imp_mean_all + event_imp_std_all, ...
              event_imp_mean_all + event_imp_std_all, event_imp_mean_all - event_imp_std_all], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        
        fill([event_fin_mean_all - event_fin_std_all, event_fin_mean_all + event_fin_std_all, ...
              event_fin_mean_all + event_fin_std_all, event_fin_mean_all - event_fin_std_all], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    end
    
    xline(event_add_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean_all, '-', 'Color', event_line_color, 'LineWidth',1, 'HandleVisibility', 'off');
    xline(event_imp_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');

    x_frames_full = 1:900;
    
    ref_upper = ref_mean_all(1:900, k) + ref_std_all(1:900, k);
    ref_lower = ref_mean_all(1:900, k) - ref_std_all(1:900, k);
    valid = ~isnan(ref_upper) & ~isnan(ref_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [ref_upper(valid)', fliplr(ref_lower(valid)')], ...
             'k', 'EdgeColor', 'none', 'FaceAlpha', 0.15, 'HandleVisibility', 'off');
    end
    valid_ref = ~isnan(ref_mean_all(1:900, k));
    plot(x_frames_full(valid_ref), ref_mean_all(valid_ref, k), 'k-', 'LineWidth', 1.5);
    
    imu_upper = imu_mean_all(1:900, k) + imu_std_all(1:900, k);
    imu_lower = imu_mean_all(1:900, k) - imu_std_all(1:900, k);
    valid = ~isnan(imu_upper) & ~isnan(imu_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [imu_upper(valid)', fliplr(imu_lower(valid)')], ...
             dark_gray, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imu = ~isnan(imu_mean_all(1:900, k));
    plot(x_frames_full(valid_imu), imu_mean_all(valid_imu, k), '-', 'Color', dark_gray, 'LineWidth', 1.5);
    
    imucal_upper = imucal_mean_all(1:900, k) + imucal_std_all(1:900, k);
    imucal_lower = imucal_mean_all(1:900, k) - imucal_std_all(1:900, k);
    valid = ~isnan(imucal_upper) & ~isnan(imucal_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [imucal_upper(valid)', fliplr(imucal_lower(valid)')], ...
             dark_red, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imucal = ~isnan(imucal_mean_all(1:900, k));
    plot(x_frames_full(valid_imucal), imucal_mean_all(valid_imucal, k), '-', 'Color', dark_red, 'LineWidth', 1.5);
    
    
    xlim(fig1000_xlim);
    ylim(fig1000_ylim(k, :));
    set(gca, 'FontSize', 18, 'FontName', 'Gill Sans MT')
    set(gca, 'XTick', [])
    set(gca, 'XTickLabel', []);  % remove x-axis numbers
    hold off;

end
set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig1000_size_cm], ...
         'PaperSize', fig1000_size_cm);
print(gcf, sprintf('fig3.svg'), '-dsvg', '-vector');

%% Figure 1005: Figure 1000 without shades
figure(1005);
clf;
set(gcf, 'Color', 'w', 'Units', 'centimeters', ...
         'Position', [2 2 fig1000_size_cm]);

for k = 1:3
    subplot(3,1,k);
    bottom_pos = 1 - top_margin - plot_height * k - gap * (k-1);
    set(gca, 'Position', [left_margin, bottom_pos, plot_width, plot_height]);

    hold on;
    plot(fig1000_xlim, [0 0], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');

    xline(event_add_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean_all, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');

    x_frames_full = 1:900;

    ref_upper = ref_mean_all(1:900, k) + ref_std_all(1:900, k);
    ref_lower = ref_mean_all(1:900, k) - ref_std_all(1:900, k);
    valid = ~isnan(ref_upper) & ~isnan(ref_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], ...
             [ref_upper(valid)', fliplr(ref_lower(valid)')], ...
             'k', 'EdgeColor', 'none', 'FaceAlpha', 0.15, 'HandleVisibility', 'off');
    end
    valid_ref = ~isnan(ref_mean_all(1:900, k));
    plot(x_frames_full(valid_ref), ref_mean_all(valid_ref, k), 'k-', 'LineWidth', 1.5);

    imu_upper = imu_mean_all(1:900, k) + imu_std_all(1:900, k);
    imu_lower = imu_mean_all(1:900, k) - imu_std_all(1:900, k);
    valid = ~isnan(imu_upper) & ~isnan(imu_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], ...
             [imu_upper(valid)', fliplr(imu_lower(valid)')], ...
             dark_gray, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imu = ~isnan(imu_mean_all(1:900, k));
    plot(x_frames_full(valid_imu), imu_mean_all(valid_imu, k), '-', 'Color', dark_gray, 'LineWidth', 1.5);

    imucal_upper = imucal_mean_all(1:900, k) + imucal_std_all(1:900, k);
    imucal_lower = imucal_mean_all(1:900, k) - imucal_std_all(1:900, k);
    valid = ~isnan(imucal_upper) & ~isnan(imucal_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], ...
             [imucal_upper(valid)', fliplr(imucal_lower(valid)')], ...
             dark_red, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imucal = ~isnan(imucal_mean_all(1:900, k));
    plot(x_frames_full(valid_imucal), imucal_mean_all(valid_imucal, k), '-', 'Color', dark_red, 'LineWidth', 1.5);

    xlim(fig1000_xlim);
    ylim(fig1000_ylim(k, :));
    set(gca, 'FontSize', 15, 'FontName', 'Gill Sans MT');
    set(gca, 'XTick', []);
    set(gca, 'XTickLabel', []);
    hold off;
end

set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig1000_size_cm], ...
         'PaperSize', fig1000_size_cm);
print(gcf, sprintf('fig3_noshade.svg'), '-dsvg', '-vector');

%% Figure 1002: Figure 1000 mean trajectories in 3D
figure(1002);
clf;
fig1002_size_cm = [16 14.69];  % keep the previous 600:551 aspect ratio
set(gcf, 'Color', 'w', 'Units', 'centimeters', ...
         'Position', [2 2 fig1002_size_cm]);

x_frames_full = 1:900;
plot_idx = fig1000_xlim(1):fig1000_xlim(2);
traj3d_data = {ref_mean_all, imu_mean_all, imucal_mean_all};
traj3d_color = {'k', dark_gray, dark_red};

hold on;
event_names_3d = {'ADD', 'IMP', 'BST', 'FIN'};
event_frames_3d = [event_add_mean_all, event_imp_mean_all, event_bst_mean_all, event_fin_mean_all];

for m = 1:numel(traj3d_data)
    traj3d_mean = traj3d_data{m};
    traj3d = traj3d_mean(plot_idx, 1:3);
    valid_traj3d = all(isfinite(traj3d), 2);

    plot3(traj3d(valid_traj3d, 1), ...
          traj3d(valid_traj3d, 2), ...
          traj3d(valid_traj3d, 3), ...
          '-', 'Color', traj3d_color{m}, 'LineWidth', 2);

    for e = 1:numel(event_names_3d)
        if e == 1
            if m ~= 3
                continue;
            end
            first_valid_idx = find(valid_traj3d, 1, 'first');
            if isempty(first_valid_idx)
                continue;
            end
            event_pos = traj3d(first_valid_idx, :);
            marker_color = 'k';
        else
            event_frame = event_frames_3d(e);
            if ~isfinite(event_frame) || event_frame < plot_idx(1) || event_frame > plot_idx(end)
                continue;
            end
            event_pos = interp1(x_frames_full, traj3d_mean(:, 1:3), event_frame, 'linear');
            marker_color = traj3d_color{m};
        end

        if all(isfinite(event_pos))
            plot3(event_pos(1), event_pos(2), event_pos(3), 'o', ...
                  'MarkerSize', 7, 'MarkerFaceColor', marker_color, ...
                  'MarkerEdgeColor', 'none');
        end
    end
end

grid off;
axis equal;
view(90, 0);
camproj('orthographic');
axis off;
hold off;
set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig1002_size_cm], ...
         'PaperSize', fig1002_size_cm);
print(gcf, sprintf('fig3_mean_3d.svg'), '-dsvg', '-vector');

%% Figure 1003: PPT-friendly Y-Z projection
figure(1003);
clf;
set(gcf, 'Color', 'w', 'Units', 'centimeters', ...
         'Position', [2 2 fig1002_size_cm]);

hold on;
for m = 1:numel(traj3d_data)
    traj3d_mean = traj3d_data{m};
    traj3d = traj3d_mean(plot_idx, 1:3);
    valid_traj3d = all(isfinite(traj3d), 2);

    plot(traj3d(valid_traj3d, 2), ...
         traj3d(valid_traj3d, 3), ...
         '-', 'Color', traj3d_color{m}, 'LineWidth', 2);

    for e = 1:numel(event_frames_3d)
        if e == 1
            if m ~= 3
                continue;
            end
            first_valid_idx = find(valid_traj3d, 1, 'first');
            if isempty(first_valid_idx)
                continue;
            end
            event_pos = traj3d(first_valid_idx, :);
            marker_color = 'k';
        else
            event_frame = event_frames_3d(e);
            if ~isfinite(event_frame) || event_frame < plot_idx(1) || event_frame > plot_idx(end)
                continue;
            end
            event_pos = interp1(x_frames_full, traj3d_mean(:, 1:3), event_frame, 'linear');
            marker_color = traj3d_color{m};
        end

        if all(isfinite(event_pos))
            plot(event_pos(2), event_pos(3), 'o', ...
                 'MarkerSize', 7, 'MarkerFaceColor', marker_color, ...
                 'MarkerEdgeColor', 'none');
        end
    end
end

axis equal;
axis off;
hold off;
set(gcf, 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 fig1002_size_cm], ...
         'PaperSize', fig1002_size_cm);
print(gcf, sprintf('fig3_mean_yz_2d.svg'), '-dsvg', '-vector');
if ispc
    print(gcf, sprintf('fig3_mean_yz_2d.emf'), '-dmeta', '-vector');
end

%% Figure 1001: previous version (mean over all trials) - for comparison
all_ref = [];
all_imu = [];
all_imucal = [];
all_ml = [];
all_events_add_old = [];
all_events_bst_old = [];
all_events_imp_old = [];
all_events_fin_old = [];

for subj = 1:nSubj_ml
    n_trials_subj = sum(~isnan(squeeze(plot_ds_ref_all(1,1,:,subj))));
    if n_trials_subj > 0
        all_ref = cat(3, all_ref, plot_ds_ref_all(:,:,1:n_trials_subj,subj));
        all_imu = cat(3, all_imu, plot_ds_imu_all(:,:,1:n_trials_subj,subj));
        all_imucal = cat(3, all_imucal, plot_ds_imucal_all(:,:,1:n_trials_subj,subj));
        all_ml = cat(3, all_ml, plot_ds_ml_all(:,:,1:n_trials_subj,subj));
        all_events_add_old = [all_events_add_old; event_add_all(1:n_trials_subj,subj)];
        all_events_bst_old = [all_events_bst_old; event_bst_all(1:n_trials_subj,subj)];
        all_events_imp_old = [all_events_imp_old; event_imp_all(1:n_trials_subj,subj)];
        all_events_fin_old = [all_events_fin_old; event_fin_all(1:n_trials_subj,subj)];
    end
end

ref_mean_old = mean(all_ref, 3, 'omitnan');
ref_std_old = std(all_ref, 0, 3, 'omitnan');
imu_mean_old = mean(all_imu, 3, 'omitnan');
imu_std_old = std(all_imu, 0, 3, 'omitnan');
imucal_mean_old = mean(all_imucal, 3, 'omitnan');
imucal_std_old = std(all_imucal, 0, 3, 'omitnan');

event_add_mean_old = mean(all_events_add_old, 'omitnan');
event_add_std_old = std(all_events_add_old, 0, 'omitnan');
event_bst_mean_old = mean(all_events_bst_old, 'omitnan');
event_bst_std_old = std(all_events_bst_old, 0, 'omitnan');
event_imp_mean_old = mean(all_events_imp_old, 'omitnan');
event_imp_std_old = std(all_events_imp_old, 0, 'omitnan');
event_fin_mean_old = mean(all_events_fin_old, 'omitnan');
event_fin_std_old = std(all_events_fin_old, 0, 'omitnan');

figure(1001);
clf;
set(gcf, 'Position', [750, 349, 600, 551]);

left_margin_old = 0.13;
top_margin_old = 0.05;
bottom_margin_old = 0.08;
plot_width_old = 0.82;
gap_old = 0.05;
plot_height_old = (1 - top_margin_old - bottom_margin_old - gap_old * 2) / 3;

for k = 1:3
    subplot(3,1,k);
    bottom_pos = 1 - top_margin_old - plot_height_old * k - gap_old * (k-1);
    set(gca, 'Position', [left_margin_old, bottom_pos, plot_width_old, plot_height_old]);
    hold on;
    
    y_min_shade = fig1000_ylim(k, 1);
    y_max_shade = fig1000_ylim(k, 2);
    
    plot(fig1000_xlim, [0 0], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
    
    if show_event_shade
        fill([event_add_mean_old - event_add_std_old, event_add_mean_old + event_add_std_old, ...
              event_add_mean_old + event_add_std_old, event_add_mean_old - event_add_std_old], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill([event_bst_mean_old - event_bst_std_old, event_bst_mean_old + event_bst_std_old, ...
              event_bst_mean_old + event_bst_std_old, event_bst_mean_old - event_bst_std_old], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill([event_imp_mean_old - event_imp_std_old, event_imp_mean_old + event_imp_std_old, ...
              event_imp_mean_old + event_imp_std_old, event_imp_mean_old - event_imp_std_old], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
        fill([event_fin_mean_old - event_fin_std_old, event_fin_mean_old + event_fin_std_old, ...
              event_fin_mean_old + event_fin_std_old, event_fin_mean_old - event_fin_std_old], ...
             [y_min_shade, y_min_shade, y_max_shade, y_max_shade], ...
             event_color, 'EdgeColor', 'none', 'FaceAlpha', event_alpha, 'HandleVisibility', 'off');
    end
    
    xline(event_add_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_bst_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_imp_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(event_fin_mean_old, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(880, '-', 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    x_frames_full = 1:900;
    
    ref_upper = ref_mean_old(1:900, k) + ref_std_old(1:900, k);
    ref_lower = ref_mean_old(1:900, k) - ref_std_old(1:900, k);
    valid = ~isnan(ref_upper) & ~isnan(ref_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [ref_upper(valid)', fliplr(ref_lower(valid)')], ...
             'k', 'EdgeColor', 'none', 'FaceAlpha', 0.15, 'HandleVisibility', 'off');
    end
    valid_ref = ~isnan(ref_mean_old(1:900, k));
    plot(x_frames_full(valid_ref), ref_mean_old(valid_ref, k), 'k-', 'LineWidth', 2);
    
    imu_upper = imu_mean_old(1:900, k) + imu_std_old(1:900, k);
    imu_lower = imu_mean_old(1:900, k) - imu_std_old(1:900, k);
    valid = ~isnan(imu_upper) & ~isnan(imu_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [imu_upper(valid)', fliplr(imu_lower(valid)')], ...
             dark_gray, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imu = ~isnan(imu_mean_old(1:900, k));
    plot(x_frames_full(valid_imu), imu_mean_old(valid_imu, k), '-', 'Color', dark_gray, 'LineWidth', 1.5);
    
    imucal_upper = imucal_mean_old(1:900, k) + imucal_std_old(1:900, k);
    imucal_lower = imucal_mean_old(1:900, k) - imucal_std_old(1:900, k);
    valid = ~isnan(imucal_upper) & ~isnan(imucal_lower);
    if any(valid)
        fill([x_frames_full(valid), fliplr(x_frames_full(valid))], [imucal_upper(valid)', fliplr(imucal_lower(valid)')], ...
             dark_red, 'EdgeColor', 'none', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
    end
    valid_imucal = ~isnan(imucal_mean_old(1:900, k));
    plot(x_frames_full(valid_imucal), imucal_mean_old(valid_imucal, k), '-', 'Color', dark_red, 'LineWidth', 1.5);
    
    xlim(fig1000_xlim);
    ylim(fig1000_ylim(k, :));
    set(gca, 'FontSize', 14, 'FontName', 'Gill Sans MT');
    set(gca, 'XTick', []);
    set(gca, 'XTickLabel', []);
    hold off;
end

sgtitle('Figure 1001: previous version (mean over all trials)', 'FontSize', 14);
fprintf('Figure 1001 (previous version, mean over all trials) created\n');

%% save results
save_results = struct();
save_results.results = results;
save_results.subj_id_list = subj_id_list;
save_results.trial_id_list = trial_id_list;
save_results.plot_ds_ref = plot_ds_ref_all;
save_results.plot_ds_imu = plot_ds_imu_all;
save_results.plot_ds_imucal = plot_ds_imucal_all;
save_results.plot_ds_ml = plot_ds_ml_all;
save_results.event_add = event_add_all;
save_results.event_bst = event_bst_all;
save_results.event_imp = event_imp_all;
save_results.event_fin = event_fin_all;

save('method_comparison_results.mat', 'save_results');
fprintf('\nResults saved to method_comparison_results.mat.\n');

%% Helper Functions
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
