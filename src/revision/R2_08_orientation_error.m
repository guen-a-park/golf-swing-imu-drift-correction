%% [R2-8] R2_08_orientation_error.m  (R2_09 Part 3 extended for heading condition comparison)
%  Orientation error by swing phase, compared between heading conditions.
%  Output : revision/results/

clc; close all;
set(groot, 'defaultAxesFontSize', 14);

RUN_PARTS = 3;   % [R2-8] run Part 3 only
R2_08_HEADING_ALIGNED = true;   %% <<< false = ori7 (magnetometer), true = ori8 (motion capture yaw)
R2_08_tag = sprintf('R2_08_ori%d_', 7 + R2_08_HEADING_ALIGNED);

%% Common settings
IMU_ROOT = fullfile(dataRoot(), 'imu');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);                        % ...\250819_golf
OUT_DIR = fullfile(thisDir, 'results');              % output folder
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end
addpath(baseDir);
addpath(genpath(fullfile(fileparts(baseDir), 'GolfSwing_0424')));  % dcm2quatern, get_orientation_apdm, etc.

subjN  = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN  = ["driver","iron","fast"];
CLUBS  = [1 3];              % 1 = driver, 3 = fast swing (targets of this analysis)
NTRIAL = [30 30 10];         % number of trials per condition
apdm_rate = 200;

maskFile = fullfile(OUT_DIR, 'gyro_saturation_mask.mat');

%% Saturation criteria
FSR        = 35.0;      % [rad/s] gyro measurement range (one-sided)
CLIP_RATIO = 0.99;      % C1 threshold ratio
JUMP_TH    = 15.0;      % [rad/s / sample] C2 threshold (200 Hz -> 3000 rad/s^2)

WIN_PRE  = 1.5;
WIN_POST = 0.5;

%% Dataset exceptions
EXCLUDED = [ 5 3  5;   % IMU recording error
             9 3  8;   % IMU value comes out NaN
             8 1 30;   % magnetometer measurement error
             2 1 10;   % IMU recording error
             6 1  3];  % IMU recording error

TRAIN_TRIALS = containers.Map({1, 3}, {1:20, []});
TEST_TRIALS  = containers.Map({1, 3}, {21:30, 1:10});

%% Part 1.  Saturation detection
if ismember(1, RUN_PARTS)
fprintf('\n########## Part 1. Saturation detection ##########\n');

DO_PLOT_SAT = false;      % if true, plot every trial flagged as saturated for visual verification

rows = {};
for subj = 1:numel(subjN)
    for club = CLUBS
        p = fullfile(IMU_ROOT, char(subjN(subj)), char(clubN(club)));
        f = dir(fullfile(p, '*.h5'));
        if isempty(f)
            warning('h5 file not found: %s', p); continue
        end
        [~, idx] = sort([f.datenum]);   % same sorting rule as matProcess0902.m
        f = f(idx);

        ntr = min(numel(f), NTRIAL(club));
        for trial = 1:ntr
            fp = fullfile(p, f(trial).name);

            si = h5info(fp, '/Sensors');
            id = si.Groups(1).Name;
            id = id(find(id == '/', 1, 'last') + 1 : end);
            try
                fs = double(h5readatt(fp, ['/Sensors/' id '/Configuration'], 'Sample Rate'));
            catch
                fs = apdm_rate;
            end

            g = h5read(fp, ['/Sensors/' id '/Gyroscope'])';   % [n x 3], rad/s, raw
            n = size(g, 1);

            [~, pkIdx] = max(max(abs(g), [], 2));
            i0 = max(1, pkIdx - round(WIN_PRE  * fs));
            i1 = min(n, pkIdx + round(WIN_POST * fs));
            gw = g(i0:i1, :);

            aw = abs(gw);
            dw = abs(diff(gw, 1, 1));

            gmaxAxis = max(aw, [], 1);
            gmax     = max(gmaxAxis);

            nClip = sum(any(aw >= CLIP_RATIO * FSR, 2));
            [maxJump, li] = max(dw(:));
            [jr, ~] = ind2sub(size(dw), li);
            nJump = sum(any(dw >= JUMP_TH, 2));

            flagClip = nClip > 0;
            flagOver = nJump > 0;
            isSat    = flagClip || flagOver;

            isExcl = any(all(EXCLUDED == [subj club trial], 2));
            if ismember(trial, TEST_TRIALS(club))
                setName = "test";
            elseif ~isempty(TRAIN_TRIALS(club)) && ismember(trial, TRAIN_TRIALS(club))
                setName = "train";
            else
                setName = "unused";
            end

            rows(end+1, :) = { subj, string(subjN(subj)), club, string(clubN(club)), trial, ...
                setName, isExcl, string(f(trial).name), fs, n, ...
                gmaxAxis(1), gmaxAxis(2), gmaxAxis(3), gmax, gmax/FSR*100, ...
                nClip, maxJump, maxJump*fs, jr - (pkIdx - i0 + 1), nJump, ...
                flagClip, flagOver, isSat }; %#ok<SAGROW>

            if DO_PLOT_SAT && isSat
                local_plot_trial(g, pkIdx, fs, subjN(subj), clubN(club), trial, FSR);
            end
        end
    end
end

Tsat = cell2table(rows, 'VariableNames', { ...
    'subj', 'subjName', 'club', 'clubName', 'trial', 'set', 'preExcluded', 'file', 'fs', 'nSample', ...
    'gmaxX', 'gmaxY', 'gmaxZ', 'gmaxAll', 'pctFSR', ...
    'nClipSample', 'maxJump', 'maxAngAccel', 'jumpRelImpact', 'nJumpSample', ...
    'flagClip', 'flagOverflow', 'isSaturated'});
writetable(Tsat, fullfile(OUT_DIR, 'gyro_saturation_trialwise.csv'));

%% participant x condition summary
srows = {};
for subj = 1:numel(subjN)
    for club = CLUBS
        m  = Tsat.subj == subj & Tsat.club == club & ~Tsat.preExcluded;
        mT = m & Tsat.set == "test";
        srows(end+1, :) = { subj, string(subjN(subj)), string(clubN(club)), ...
            sum(m),  sum(Tsat.isSaturated(m)),  100*sum(Tsat.isSaturated(m))/max(sum(m), 1), ...
            sum(mT), sum(Tsat.isSaturated(mT)), 100*sum(Tsat.isSaturated(mT))/max(sum(mT), 1), ...
            max(Tsat.gmaxAll(m)), sum(Tsat.flagClip(m)), sum(Tsat.flagOverflow(m)) }; %#ok<SAGROW>
    end
end
Ssat = cell2table(srows, 'VariableNames', { ...
    'subj', 'subjName', 'clubName', 'nTrial', 'nSaturated', 'pctSaturated', ...
    'nTest', 'nTestSaturated', 'pctTestSaturated', 'peakOmega', 'nClipTrial', 'nOverflowTrial'});
writetable(Ssat, fullfile(OUT_DIR, 'gyro_saturation_summary.csv'));

%% save exclusion mask (directly usable by the existing analysis code)
satFlag = struct('name', num2cell(subjN(:)));
for subj = 1:numel(subjN)
    for club = 1:3
        satFlag(subj).clubN(club).trialN = false(1, NTRIAL(club));
    end
end
for k = 1:height(Tsat)
    satFlag(Tsat.subj(k)).clubN(Tsat.club(k)).trialN(Tsat.trial(k)) = Tsat.isSaturated(k);
end
satCriteria = struct('FSR_rad_s', FSR, 'FSR_deg_s', FSR*180/pi, ...
    'clipRatio', CLIP_RATIO, 'jumpThreshold_rad_s_per_sample', JUMP_TH, ...
    'jumpThreshold_rad_s2', JUMP_TH*apdm_rate, 'window_s', [-WIN_PRE WIN_POST]);
save(maskFile, 'satFlag', 'satCriteria', 'Tsat', 'Ssat');

%% console summary (for writing the paper text/tables)
fprintf('\nFull-scale range  : +-%.1f rad/s (= +-%.0f deg/s, nominal +-2000 deg/s)\n', FSR, FSR*180/pi);
fprintf('C1 range clipping : |w_axis| >= %.2f rad/s (%.0f%% of FSR), >=1 sample\n', CLIP_RATIO*FSR, CLIP_RATIO*100);
fprintf('C2 range overflow : |dw| >= %.1f rad/s per sample (= %.0f rad/s^2 at %d Hz), >=1 sample\n', ...
    JUMP_TH, JUMP_TH*apdm_rate, apdm_rate);
fprintf('Analysis window   : impact %.1f s ~ +%.1f s\n', -WIN_PRE, WIN_POST);

valid = ~Tsat.preExcluded;
fprintf('\n--- Overall (driver + fast, pre-excluded trials removed) ---\n');
fprintf('saturated %d / %d trials (%.1f%%)\n', sum(Tsat.isSaturated(valid)), sum(valid), ...
    100*sum(Tsat.isSaturated(valid))/sum(valid));
for club = CLUBS
    m = valid & Tsat.club == club;
    fprintf('  %-7s : %3d / %3d (%.1f%%)   [test set: %d / %d]\n', clubN(club), ...
        sum(Tsat.isSaturated(m)), sum(m), 100*sum(Tsat.isSaturated(m))/sum(m), ...
        sum(Tsat.isSaturated(m & Tsat.set == "test")), sum(m & Tsat.set == "test"));
end

fprintf('\n--- Per subject (n saturated / n trials) ---\n');
fprintf('%-6s %-16s %-16s %-16s\n', 'Subj', 'driver(1-30)', 'fast(1-10)', 'test set only');
for subj = 1:numel(subjN)
    md = valid & Tsat.subj == subj & Tsat.club == 1;
    mf = valid & Tsat.subj == subj & Tsat.club == 3;
    mt = valid & Tsat.subj == subj & Tsat.set == "test";
    fprintf('%-6s %2d/%-13d %2d/%-13d %2d/%-13d\n', subjN(subj), ...
        sum(Tsat.isSaturated(md)), sum(md), sum(Tsat.isSaturated(mf)), sum(mf), ...
        sum(Tsat.isSaturated(mt)), sum(mt));
end

fprintf('\n--- Saturated trial list ---\n');
for subj = 1:numel(subjN)
    for club = CLUBS
        m = valid & Tsat.subj == subj & Tsat.club == club & Tsat.isSaturated;
        if any(m)
            fprintf('%-5s %-7s : %s\n', subjN(subj), clubN(club), ...
                strjoin(string(Tsat.trial(m))', ', '));
        end
    end
end

fprintf('\n--- Separation check (threshold validity) ---\n');
fprintf('max |dw| among NON-saturated trials : %.2f rad/s/sample (%.0f rad/s^2)\n', ...
    max(Tsat.maxJump(valid & ~Tsat.isSaturated)), max(Tsat.maxAngAccel(valid & ~Tsat.isSaturated)));
fprintf('min |dw| among     saturated trials : %.2f rad/s/sample (%.0f rad/s^2)\n', ...
    min(Tsat.maxJump(valid &  Tsat.isSaturated)), min(Tsat.maxAngAccel(valid &  Tsat.isSaturated)));
fprintf('overflow event timing rel. impact   : %d ~ %d samples (%.0f ~ %.0f ms)\n', ...
    min(Tsat.jumpRelImpact(valid & Tsat.flagOverflow)), max(Tsat.jumpRelImpact(valid & Tsat.flagOverflow)), ...
    1000*min(Tsat.jumpRelImpact(valid & Tsat.flagOverflow))/apdm_rate, ...
    1000*max(Tsat.jumpRelImpact(valid & Tsat.flagOverflow))/apdm_rate);

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'gyro_saturation_trialwise.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'gyro_saturation_summary.csv'));
fprintf('saved: %s\n', maskFile);
end % Part 1

%% Part 2.  Example figure (normal vs saturated raw gyro)
if ismember(2, RUN_PARTS)
fprintf('\n########## Part 2. Example figure ##########\n');

CASES = { 'S05', 'driver', 10, 'Non-saturated (trial 10)';
          'S05', 'driver',  8, 'Saturated (trial 8)' };

figure(4000); clf;
set(gcf, 'Color', 'w', 'Position', [100 100 900 340]);
for k = 1:size(CASES, 1)
    p = fullfile(IMU_ROOT, CASES{k,1}, CASES{k,2});
    f = dir(fullfile(p, '*.h5'));
    [~, idx] = sort([f.datenum]); f = f(idx);          % same sorting as matProcess0902.m

    fp = fullfile(p, f(CASES{k,3}).name);
    si = h5info(fp, '/Sensors');
    id = si.Groups(1).Name; id = id(find(id == '/', 1, 'last') + 1 : end);
    fs = double(h5readatt(fp, ['/Sensors/' id '/Configuration'], 'Sample Rate'));
    g  = h5read(fp, ['/Sensors/' id '/Gyroscope'])';

    [~, pk] = max(max(abs(g), [], 2));
    i0 = max(1, pk - round(0.10*fs));
    i1 = min(size(g,1), pk + round(0.10*fs));
    tt = ((i0:i1) - pk) / fs * 1000;

    subplot(1, 2, k);
    plot(tt, g(i0:i1, :), 'LineWidth', 1.4); hold on; grid on;
    yline( FSR, 'k--', 'LineWidth', 1); yline(-FSR, 'k--', 'LineWidth', 1);
    text(tt(end), FSR, '  +FSR', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
    ylim([-45 45]); xlim([tt(1) tt(end)]);
    xlabel('Time from impact (ms)'); ylabel('Angular velocity (rad/s)');
    title(sprintf('%s %s - %s', CASES{k,1}, CASES{k,2}, CASES{k,4}));
    if k == 1
        legend({'\omega_x', '\omega_y', '\omega_z'}, 'Location', 'southwest');
    end
end

exportgraphics(figure(4000), fullfile(OUT_DIR, 'fig_gyro_saturation_example.png'), 'Resolution', 300);
saveas(figure(4000), fullfile(OUT_DIR, 'fig_gyro_saturation_example.svg'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_gyro_saturation_example.png'));
end % Part 2

%% Part 3.  Effect of saturation on orientation error
if ismember(3, RUN_PARTS)
fprintf('\n########## Part 3. Orientation error impact check ##########\n');

CLUB   = 1;            % driver
TRIALS = 21:30;        % test set
plot_x_start = 266;    % same as draw_orientation_plot.m
plot_x_end   = 880;
SAVE_FIG = true;

dark_red = [128   0  32]/255;    % saturation excluded
gray_all = [0.45 0.45 0.45];     % all trials
sat_blue = [ 31 119 180]/255;    % saturated trials only
event_line_color = [0 0 0];

%% load data
if ~exist('satFlag', 'var')      % when Part 1 was not run in the same session
    if ~isfile(maskFile)
        error('%s not found. Include 1 in RUN_PARTS and run Part 1 first.', maskFile);
    end
    load(maskFile, 'satFlag', 'satCriteria');
end
fprintf('Loading swing data...\n');
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');

time = (0.005:0.005:4.5)';
max_frames = 900;

angle_error_all      = [];    % [900 x nTrial]  quaternion angle error
angle_error_axis_all = [];    % [900 x 3 x nTrial]
isSat_list = []; subj_list = []; trial_list = [];
add_list = []; bst_list = []; imp_list = []; fin_list = [];

%% main loop (same as draw_orientation_plot.m)
fprintf('Processing trials...\n');
z = 1;
for subj = 1:10
    club = CLUB;
    for trial = TRIALS
        if subj == 8 && club == 1 && trial == 30
            continue
        end

        g = swingData_2508(subj).clubN(club).trialN(trial);

        if subj == 10 && club == 1 && trial == 24
            g.imp_imu1_est = g.imp_imu2_est;
            g.imp_imu1 = g.imp_imu2;
        end

        g.add = double(g.add);
        g.bst = double(g.bst);
        g.imp = double(g.imp);
        g.fin = double(g.fin);
        if g.fin > 900, g.fin = 900; end

%% marker data
        WristU = g.marker(:,13:15);
        WristM = g.marker(:,10:12);
        WristL = g.marker(:, 7: 9);

        acc_data  = g.apdm(:,1:3);
        gyro_data = g.apdm(:,4:6);
        m_cal     = g.apdm(:,7:9);

%% R2Lw (marker-based orientation)
        Cw = (WristU + WristL) ./ 2;
        Lo = WristL - Cw;
        Mo = WristM - Cw;
        Uo = WristU - Cw;

        wL = vecnorm(Lo, 2, 2);
        wM = vecnorm(Mo, 2, 2);
        wU = vecnorm(Uo, 2, 2);

        temp_x     = Uo ./ wU;
        vprime_xw  = Lo ./ wL;
        vprime_top = Mo ./ wM;
        vprime_zw  = zeros(size(vprime_xw));
        vprime_yw  = zeros(size(vprime_xw));

        for i = 1:size(vprime_xw,1)
            vprime_zw(i,:) = cross(temp_x(i,:), vprime_top(i,:));
        end
        for i = 1:size(vprime_xw,1)
            vprime_yw(i,:) = cross(temp_x(i,:), vprime_zw(i,:));
        end
        for i = 1:size(vprime_xw,1)
            vprime_xw(i,:) = cross(vprime_yw(i,:), vprime_zw(i,:));
        end
        for i = 1:size(vprime_xw,1)
            vprime_xw(i,:) = vprime_xw(i,:) / norm(vprime_xw(i,:));
            vprime_yw(i,:) = vprime_yw(i,:) / norm(vprime_yw(i,:));
            vprime_zw(i,:) = vprime_zw(i,:) / norm(vprime_zw(i,:));
        end

        R2Lw = zeros(3, 3, size(vprime_zw,1));
        for j = 1:size(vprime_zw,1)
            R2Lw(:,:,j) = [vprime_xw(j,:)' vprime_yw(j,:)' vprime_zw(j,:)'];
        end

        R2Lwq = zeros(length(time), 4);
        for t = 1:length(time)
            R2Lwq(t,:) = dcm2quatern(R2Lw(:,:,t)');
            if R2Lwq(t,1) < 0
                R2Lwq(t,:) = -R2Lwq(t,:);
            end
        end

%% initial orientation (OrientationMethod = 7)
        local_frame = R2Lw(:,:,g.add);
        yaw_marker  = rad2deg(atan2(local_frame(2,1), local_frame(1,1)));

        acclocal_data  = acc_data(g.add,:);
        acc_normalized = acclocal_data(:) / norm(acclocal_data);
        ax = acc_normalized(1); ay = acc_normalized(2); az = acc_normalized(3);

        roll  = atan2(ay, az);
        pitch = atan2(-ax, sqrt(ay^2 + az^2));
        phi   = roll;
        theta = pitch;

        mx = m_cal(g.add,1); my = m_cal(g.add,2); mz = m_cal(g.add,3);
        mxh = mx.*cos(theta) + my.*sin(phi).*sin(theta) + mz.*cos(phi).*sin(theta);
        myh = my.*cos(phi) - mz.*sin(phi);

        psi0_deg    = 191.53;
        alpha_deg   = rad2deg(atan2(myh, mxh));
        yaw_imu_deg = mod(psi0_deg - alpha_deg + 180, 360) - 180;
        psi = deg2rad(yaw_imu_deg);
%% [R2-8] heading-aligned condition: replace only yaw with the motion capture reference
        if R2_08_HEADING_ALIGNED
            psi = deg2rad(yaw_marker);
        end
        if club == 3
            psi = deg2rad(yaw_marker);
        end

        Rx = [1 0 0; 0 cos(phi) -sin(phi); 0 sin(phi) cos(phi)];
        Ry = [cos(theta) 0 sin(theta); 0 1 0; -sin(theta) 0 cos(theta)];
        Rz = [cos(psi) -sin(psi) 0; sin(psi) cos(psi) 0; 0 0 1];
        R2tri = Rz * Ry * Rx * eye(3);

%% Orientation integration
        Rinf = get_orientation_apdm(time, acc_data, gyro_data, g.add, R2tri);

        qinf = zeros(length(time), 4);
        for t = 1:length(time)
            qinf(t,:) = dcm2quatern(Rinf(:,:,t)');
            if qinf(t,1) < 0
                qinf(t,:) = -qinf(t,:);
            end
        end

%% Angle error (quaternion, Figure 4)
        angle_error = zeros(length(time), 1);
        for i = 1:length(time)
            qprod   = quaternProd(quaternConj(qinf(i,:)), R2Lwq(i,:));
            tempAng = abs(2 * atan2(norm(qprod(2:4)), qprod(1)) * 180/pi);
            if tempAng > 180, tempAng = 360 - tempAng; end
            angle_error(i) = tempAng;
        end

%% 3-axis angle error (Euler)
        angle_error_axis = zeros(length(time), 3);
        for i = 1:length(time)
            R_diff = Rinf(:,:,i) * R2Lw(:,:,i)';
            eul = rotm2eul(R_diff, 'ZYX');
            angle_error_axis(i,:) = [rad2deg(eul(3)), rad2deg(eul(2)), rad2deg(eul(1))];
        end

%% save
        angle_error_all(:, z)       = angle_error;        %#ok<SAGROW>
        angle_error_axis_all(:,:,z) = angle_error_axis;   %#ok<SAGROW>
        isSat_list(z,1) = satFlag(subj).clubN(club).trialN(trial); %#ok<SAGROW>
        subj_list(z,1)  = subj;   %#ok<SAGROW>
        trial_list(z,1) = trial;  %#ok<SAGROW>
        add_list(z,1) = g.add; bst_list(z,1) = g.bst;  %#ok<SAGROW>
        imp_list(z,1) = g.imp; fin_list(z,1) = g.fin;  %#ok<SAGROW>

        z = z + 1;
    end
    fprintf('  subject %d done\n', subj);
end
nTrial = z - 1;
isSat_list = logical(isSat_list);
fprintf('Total %d trials (saturated %d, non-saturated %d)\n', ...
    nTrial, sum(isSat_list), sum(~isSat_list));

%% per-trial phase errors (Table 3 format)
phaseNames = {'Backswing', 'Downswing', 'FollowThrough', 'EntireSwing'};
eventNames = {'ADD', 'BST', 'IMP', 'FIN'};

phaseErr = nan(nTrial, 4);      % phase mean error
eventErr = nan(nTrial, 4);      % error at event instants
for k = 1:nTrial
    e  = angle_error_all(:, k);
    i1 = add_list(k); i2 = bst_list(k); i3 = imp_list(k); i4 = fin_list(k);
    phaseErr(k,:) = [mean(e(i1:i2)), mean(e(i2:i3)), mean(e(i3:i4)), mean(e(i1:i4))];
    eventErr(k,:) = [e(i1), e(i2), e(i3), e(i4)];
end

Ttrial = table(subj_list, string(subjN(subj_list))', trial_list, isSat_list, ...
    phaseErr(:,1), phaseErr(:,2), phaseErr(:,3), phaseErr(:,4), ...
    eventErr(:,1), eventErr(:,2), eventErr(:,3), eventErr(:,4), ...
    'VariableNames', {'subj', 'subjName', 'trial', 'isSaturated', ...
    'errBackswing', 'errDownswing', 'errFollowThrough', 'errEntireSwing', ...
    'errADD', 'errBST', 'errIMP', 'errFIN'});
writetable(Ttrial, fullfile(OUT_DIR, [R2_08_tag 'trialwise.csv']));

%% group definitions
grpMask  = {true(nTrial,1), ~isSat_list, isSat_list};
grpNames = {'All trials', 'Saturation excluded', 'Saturated only'};
allSeg    = [phaseErr eventErr];
segLabels = [phaseNames, cellfun(@(x) ['@' x], eventNames, 'UniformOutput', false)];

%% trial-level aggregation + between-group t-test
rows = {};
for m = 1:size(allSeg, 2)
    v = allSeg(:, m);
    r = {segLabels{m}};
    for gi = 1:3
        x = v(grpMask{gi});
        r = [r, {mean(x, 'omitnan'), std(x, 'omitnan'), numel(x)}]; %#ok<AGROW>
    end
    [~, p] = ttest2(v(~isSat_list), v(isSat_list));    % non-saturated vs saturated
    rows(end+1,:) = [r, {p}]; %#ok<SAGROW>
end
Tphase = cell2table(rows, 'VariableNames', {'segment', ...
    'all_mean', 'all_sd', 'all_n', ...
    'excl_mean', 'excl_sd', 'excl_n', ...
    'sat_mean', 'sat_sd', 'sat_n', 'p_excl_vs_sat'});
writetable(Tphase, fullfile(OUT_DIR, [R2_08_tag 'phase_table.csv']));

%% participant-level aggregation (same scheme as the manuscript values)
subjRows = {};
for m = 1:size(allSeg, 2)
    r = {segLabels{m}};
    for gi = 1:3
        sm = nan(10, 1);
        for s = 1:10
            msk = grpMask{gi} & subj_list == s;
            if any(msk), sm(s) = mean(allSeg(msk, m), 'omitnan'); end
        end
        sm = sm(~isnan(sm));
        r = [r, {mean(sm), std(sm), numel(sm)}]; %#ok<AGROW>
    end
    subjRows(end+1,:) = r; %#ok<SAGROW>
end
TphaseSubj = cell2table(subjRows, 'VariableNames', {'segment', ...
    'all_mean', 'all_sd', 'all_nSubj', ...
    'excl_mean', 'excl_sd', 'excl_nSubj', ...
    'sat_mean', 'sat_sd', 'sat_nSubj'});
writetable(TphaseSubj, fullfile(OUT_DIR, [R2_08_tag 'phase_table_subjectlevel.csv']));

%% console output
fprintf('\n=========== Orientation error by swing phase (deg) ===========\n');
fprintf('Gyro saturation criterion : FSR +-%.1f rad/s, |dw| >= %.0f rad/s/sample\n', ...
    satCriteria.FSR_rad_s, satCriteria.jumpThreshold_rad_s_per_sample);
fprintf('Dataset : driver, test set (trial %d-%d)\n', TRIALS(1), TRIALS(end));

fprintf('\n[A] Participant-level aggregation (same as the manuscript, main metric)\n');
fprintf('%-16s %-18s %-18s %-18s\n', 'Segment', ...
    sprintf('All (%d subj)', TphaseSubj.all_nSubj(1)), ...
    sprintf('Excluded (%d subj)', TphaseSubj.excl_nSubj(1)), ...
    sprintf('Saturated (%d subj)', TphaseSubj.sat_nSubj(1)));
for r = 1:height(TphaseSubj)
    fprintf('%-16s %7.2f +- %-7.2f %7.2f +- %-7.2f %7.2f +- %-7.2f\n', ...
        TphaseSubj.segment{r}, TphaseSubj.all_mean(r), TphaseSubj.all_sd(r), ...
        TphaseSubj.excl_mean(r), TphaseSubj.excl_sd(r), ...
        TphaseSubj.sat_mean(r), TphaseSubj.sat_sd(r));
end

fprintf('\n[B] Trial-level aggregation (reference; same mean, larger SD)\n');
fprintf('%-16s %-18s %-18s %-18s %10s\n', 'Segment', ...
    sprintf('All (n=%d)', sum(grpMask{1})), ...
    sprintf('Excluded (n=%d)', sum(grpMask{2})), ...
    sprintf('Saturated (n=%d)', sum(grpMask{3})), 'p');
for r = 1:height(Tphase)
    fprintf('%-16s %7.2f +- %-7.2f %7.2f +- %-7.2f %7.2f +- %-7.2f %10.4f\n', ...
        Tphase.segment{r}, Tphase.all_mean(r), Tphase.all_sd(r), ...
        Tphase.excl_mean(r), Tphase.excl_sd(r), ...
        Tphase.sat_mean(r), Tphase.sat_sd(r), Tphase.p_excl_vs_sat(r));
end

fprintf('\n--- Remaining trials per participant (after excluding saturation) ---\n');
for s = 1:10
    n_all = sum(subj_list == s);
    n_ok  = sum(subj_list == s & ~isSat_list);
    flag = '';
    if n_ok == 0, flag = '   <-- all excluded'; end
    fprintf('  %-5s : %2d / %2d%s\n', subjN(s), n_ok, n_all, flag);
end

%% Within-subject comparison (removes participant mixing)
bothSubj = [];
for s = 1:10
    if any(subj_list == s & isSat_list) && any(subj_list == s & ~isSat_list)
        bothSubj(end+1) = s; %#ok<SAGROW>
    end
end

wsRows = {};
fprintf('\n--- Within-subject comparison (%d participants with both saturated and non-saturated trials: %s) ---\n', ...
    numel(bothSubj), strjoin(cellstr(subjN(bothSubj)), ', '));
fprintf('%-16s %-18s %-18s %10s %10s\n', 'Segment', 'Non-saturated', 'Saturated', 'diff', 'p(paired)');
for m = 1:size(allSeg, 2)
    a = nan(numel(bothSubj), 1);   % per-participant non-saturated mean
    b = nan(numel(bothSubj), 1);   % per-participant saturated   mean
    for ii = 1:numel(bothSubj)
        s = bothSubj(ii);
        a(ii) = mean(allSeg(subj_list == s & ~isSat_list, m), 'omitnan');
        b(ii) = mean(allSeg(subj_list == s &  isSat_list, m), 'omitnan');
    end
    [~, p] = ttest(a, b);          % paired samples
    fprintf('%-16s %7.2f +- %-7.2f %7.2f +- %-7.2f %10.2f %10.4f\n', ...
        segLabels{m}, mean(a), std(a), mean(b), std(b), mean(b - a), p);
    wsRows(end+1,:) = {segLabels{m}, mean(a), std(a), mean(b), std(b), mean(b-a), p, numel(bothSubj)}; %#ok<SAGROW>
end
Tws = cell2table(wsRows, 'VariableNames', {'segment', ...
    'nonsat_mean', 'nonsat_sd', 'sat_mean', 'sat_sd', 'diff', 'p_paired', 'nSubj'});
writetable(Tws, fullfile(OUT_DIR, [R2_08_tag 'withinsubject.csv']));

%% event means (for vertical lines)
ev = @(v, msk) mean(v(msk), 'omitnan');
mskE = ~isSat_list;
event_mean = [ev(add_list, mskE), ev(bst_list, mskE), ev(imp_list, mskE), ev(fin_list, mskE)];

%% Figure : quaternion angle error (manuscript Figure 4 redrawn)
tf = 1:max_frames;
figure(4001); clf;
set(gcf, 'Color', 'w', 'Position', [100, 200, 640, 300]); hold on; grid on;

hs = gobjects(3,1);
grpColor = {gray_all, dark_red, sat_blue};
for gi = [1 3 2]                         % put the proposed (excluded) result on top
    if ~any(grpMask{gi}), continue; end
    M = angle_error_all(:, grpMask{gi});
    m = mean(M, 2)'; s = std(M, 0, 2)';
    fill([tf fliplr(tf)], [m+s fliplr(m-s)], grpColor{gi}, ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    hs(gi) = plot(tf, m, '-', 'Color', grpColor{gi}, 'LineWidth', 1.8);
end
for e = event_mean
    xline(e, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
end
xlim([plot_x_start plot_x_end]);
local_set_time_axis(gca, apdm_rate);
xlabel('Time from impact (s)'); ylabel('Angle error (deg)');
legend(hs(isgraphics(hs)), grpNames(isgraphics(hs)), 'Location', 'northwest', 'Box', 'off');
title('Orientation error - effect of gyroscope saturation');
set(gca, 'FontSize', 13);

%% Figure : 3-axis angle error
figure(4002); clf;
set(gcf, 'Color', 'w', 'Position', [760, 100, 640, 560]);
axisLabel = {'X (Roll)', 'Y (Pitch)', 'Z (Yaw)'};
axh = gobjects(3,1);
for i = 1:3
    axh(i) = subplot(3,1,i); hold on; grid on;
    for gi = [1 3 2]
        if ~any(grpMask{gi}), continue; end
        M = squeeze(angle_error_axis_all(:, i, grpMask{gi}));
        m = mean(M, 2)'; s = std(M, 0, 2)';
        fill([tf fliplr(tf)], [m+s fliplr(m-s)], grpColor{gi}, ...
            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(tf, m, '-', 'Color', grpColor{gi}, 'LineWidth', 1.6);
    end
    for e = event_mean
        xline(e, '-', 'Color', event_line_color, 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    xlim([plot_x_start plot_x_end]);
    local_set_time_axis(gca, apdm_rate);
    ylabel(axisLabel{i});
    set(gca, 'FontSize', 12);
end
xlabel(axh(3), 'Time from impact (s)');
legend(axh(1), grpNames, 'Location', 'northwest', 'Box', 'off', 'FontSize', 9);
linkaxes(axh, 'x');

if SAVE_FIG
    exportgraphics(figure(4001), fullfile(OUT_DIR, [R2_08_tag 'fig4.png']), 'Resolution', 300);
    saveas(figure(4001), fullfile(OUT_DIR, [R2_08_tag 'fig4.svg']));
    exportgraphics(figure(4002), fullfile(OUT_DIR, [R2_08_tag 'fig4_3axis.png']), 'Resolution', 300);
    saveas(figure(4002), fullfile(OUT_DIR, [R2_08_tag 'fig4_3axis.svg']));
end

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, [R2_08_tag 'phase_table_subjectlevel.csv']));
fprintf('saved: %s\n', fullfile(OUT_DIR, [R2_08_tag 'phase_table.csv']));
fprintf('saved: %s\n', fullfile(OUT_DIR, [R2_08_tag 'withinsubject.csv']));
fprintf('saved: %s\n', fullfile(OUT_DIR, [R2_08_tag 'trialwise.csv']));
fprintf('saved: %s\n', fullfile(OUT_DIR, [R2_08_tag 'fig4.png']));
end % Part 3

fprintf('\n[R2-9] done.\n');

%% Local functions
function local_plot_trial(g, pkIdx, fs, sname, cname, trial, FSR)
    i0 = max(1, pkIdx - round(0.15*fs));
    i1 = min(size(g, 1), pkIdx + round(0.15*fs));
    t  = ((i0:i1) - pkIdx) / fs * 1000;
    figure('Name', sprintf('%s %s %d', sname, cname, trial));
    plot(t, g(i0:i1, :), 'LineWidth', 1.2); hold on; grid on;
    yline( FSR, 'k--'); yline(-FSR, 'k--');
    xlabel('time from impact (ms)'); ylabel('\omega (rad/s)');
    title(sprintf('%s / %s / trial %d', sname, cname, trial));
    legend({'\omega_x', '\omega_y', '\omega_z'}, 'Location', 'best');
end

function local_set_time_axis(axHandle, fs)
    ticksFrame = 200:100:900;
    set(axHandle, 'XTick', ticksFrame);
    set(axHandle, 'XTickLabel', arrayfun(@(v) sprintf('%.1f', (v-700)/fs), ...
        ticksFrame, 'UniformOutput', false));
end
