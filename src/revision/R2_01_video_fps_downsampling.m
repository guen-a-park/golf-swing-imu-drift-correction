%% [R2-1] R2_01_video_fps_downsampling.m
%  Effect of the video frame rate on the video-based reconstruction.
%  Output : revision/results/R2_01_fps_downsampling.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
OUT_DIR = fullfile(thisDir, 'results');
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

%% settings
subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
CLUB  = 1;                       % driver
TRIALS = 1:30;
FPS_LIST = [150 120 90 60];      % 150 = baseline
fs = 200;                        % sampling rate of the stored signal

EXCLUDED = [2 1 10; 6 1 3; 8 1 30];

%% camera parameters (same as clublength_3d_1020.m)
fx = 1195.360; fy = 1190.848; cx = 732.411; cy = 531.828;

R2w_0819 = [-0.00993943 -0.04524376 -0.99892653;
             0.99994787  0.00188487 -0.01003496;
             0.00233687 -0.9989742   0.04522267];
R2w_0821 = [-0.00688193, -0.04392766, -0.99901101;
             0.99992209,  0.01010223, -0.00733241;
             0.01041433, -0.99898364,  0.04385471];
R2w_0822 = [ 0.00180867, -0.04664263, -0.99891;
             0.99989627,  0.01435758,  0.00114005;
             0.01428876, -0.99880845,  0.04666376];

T_CAM = [1944.24195587, -147.53836065, 1065.52214668;
         1946.26368487, -145.41073665, 1064.27866168;
         1941.23811087, -147.26589965, 1064.27767068;
         1966.736499  , -163.74432434, 1081.82660875;
         1967.165515  , -166.96142634, 1080.93007875;
         2102.062     , -175.03607234, 1081.19622275;
         2102.23739517, -178.74541095, 1095.93619444;
         2103.45266617, -187.32518295, 1074.79984244;
         2100.91714417, -175.84581295, 1072.13565044;
         2106.32278417, -184.96391595, 1074.71015144];

club_length = [1135 1125 1100 1120 1107 1125 1087 1130 1125 1102];

%% data loading
fprintf('Loading swing data...\n');
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');

%% trial loop
rows = {};
chk = [];                                     % for verifying the baseline reproduction
for subj = 1:10
    if     ismember(subj, [1 2 3]), R2w = R2w_0819;
    elseif ismember(subj, [4 5 6]), R2w = R2w_0821;
    else,                           R2w = R2w_0822;
    end
    Tw = T_CAM(subj,:)';
    L  = club_length(subj);

    for trial = TRIALS
        if any(all(EXCLUDED == [subj CLUB trial], 2)), continue; end
        g = swingData_2508(subj).clubN(CLUB).trialN(trial);
        if isempty(g) || isempty(g.dl), continue; end

        add = double(g.add); imp = double(g.imp);
        px  = g.dl(:, 4:5);                    % [900 x 2] left wrist pixels (200 Hz)
        if any(~isfinite(px(:))), continue; end

        n  = size(px, 1);
        t0 = (0:n-1)' / fs;

        WristU = g.marker(:,13:15); WristL = g.marker(:,7:9);
        abs_wrist = (WristU + WristL) ./ 2;
        Pref_add = abs_wrist(add,:)'; Pref_imp = abs_wrist(imp,:)';
        Dref = Pref_imp - Pref_add;

        P = cell(numel(FPS_LIST), 2);          % {fps, [add imp]}
        for fi = 1:numel(FPS_LIST)
            f = FPS_LIST(fi);
            if f >= fs
                pxf = px;                      % baseline (no additional downsampling)
            else
                tg  = (0 : 1/f : t0(end))';    % low frame rate grid
                lo  = interp1(t0, px, tg, 'linear');
                pxf = interp1(tg, lo, t0, 'linear', 'extrap');   % restored to 200 Hz as in the pipeline
            end
            P{fi,1} = local_reconstruct(pxf(add,:), R2w, Tw, L, fx, fy, cx, cy);
            P{fi,2} = local_reconstruct(pxf(imp,:), R2w, Tw, L, fx, fy, cx, cy);
        end

        if all(isfinite(g.add_est))
            chk(end+1,:) = [norm(P{1,1}' - g.add_est), norm(P{1,2}' - g.imp_est)]; %#ok<SAGROW>
        end

        Dbase = P{1,2} - P{1,1};
        for fi = 1:numel(FPS_LIST)
            Df = P{fi,2} - P{fi,1};
            rows(end+1,:) = { subj, string(subjN(subj)), trial, FPS_LIST(fi), ...
                norm(P{fi,1} - P{1,1}), norm(P{fi,2} - P{1,2}), ...      % vs 150 fps
                norm(P{fi,1} - Pref_add), norm(P{fi,2} - Pref_imp), ...  % vs mocap
                norm(Df - Dbase), norm(Df - Dref), ...                   % D error
                Df(1), Df(2), Df(3) }; %#ok<SAGROW>
        end
    end
    fprintf('  subject %d done\n', subj);
end

R = cell2table(rows, 'VariableNames', {'subj','subjName','trial','fps', ...
    'errADD_vs150','errIMP_vs150','errADD_vs_mocap','errIMP_vs_mocap', ...
    'errD_vs150','errD_vs_mocap','D_x','D_y','D_z'});
writetable(R, fullfile(OUT_DIR, 'R2_01_fps_downsampling.csv'));

if ~isempty(chk)
    fprintf('\n[verification] 150 fps reproduction error (against the stored add_est/imp_est) : %.4f / %.4f mm\n', ...
        mean(chk(:,1)), mean(chk(:,2)));
end

%% summary (participant-level aggregation)
subjList = unique(R.subj);
srows = {};
for fi = 1:numel(FPS_LIST)
    f = FPS_LIST(fi);
    k = R.fps == f;
    cols = {'errADD_vs150','errIMP_vs150','errD_vs150','errADD_vs_mocap','errIMP_vs_mocap','errD_vs_mocap'};
    vals = nan(1, 2*numel(cols));
    for c = 1:numel(cols)
        sm = nan(numel(subjList),1);
        for si = 1:numel(subjList)
            sm(si) = mean(R.(cols{c})(k & R.subj == subjList(si)), 'omitnan');
        end
        vals(2*c-1) = mean(sm, 'omitnan') / 10;      % mm -> cm
        vals(2*c)   = std(sm, 'omitnan') / 10;
    end
    srows(end+1,:) = [{f}, num2cell(vals)]; %#ok<SAGROW>
end
S = cell2table(srows, 'VariableNames', {'fps', ...
    'errADD_vs150_mean','errADD_vs150_sd','errIMP_vs150_mean','errIMP_vs150_sd', ...
    'errD_vs150_mean','errD_vs150_sd', ...
    'errADD_vs_mocap_mean','errADD_vs_mocap_sd','errIMP_vs_mocap_mean','errIMP_vs_mocap_sd', ...
    'errD_vs_mocap_mean','errD_vs_mocap_sd'});
writetable(S, fullfile(OUT_DIR, 'R2_01_fps_summary.csv'));

%% console output
fprintf('\n========== [R2-1] effect of video frame rate downsampling (cm) ==========\n');
fprintf('driver %d trials / %d subjects, participant-level aggregation\n\n', height(R)/numel(FPS_LIST), numel(subjList));
fprintf('%6s | %-26s | %-26s\n', 'fps', 'vs 150 fps baseline', 'vs motion capture');
fprintf('%6s | %8s %8s %8s | %8s %8s %8s\n', '', 'ADD', 'IMP', '|dD|', 'ADD', 'IMP', '|D err|');
for r = 1:height(S)
    fprintf('%6d | %8.3f %8.3f %8.3f | %8.2f %8.2f %8.2f\n', S.fps(r), ...
        S.errADD_vs150_mean(r), S.errIMP_vs150_mean(r), S.errD_vs150_mean(r), ...
        S.errADD_vs_mocap_mean(r), S.errIMP_vs_mocap_mean(r), S.errD_vs_mocap_mean(r));
end

W_DOWN = 0.91;
fprintf('\n--- propagation into the training target (D_Vision corrected trajectory) ---\n');
fprintf('%6s %14s %18s %14s\n', 'fps', '|dD| (cm)', 'impact traj. error', 'downswing mean');
for r = 2:height(S)
    fprintf('%6d %14.3f %18.3f %14.3f\n', S.fps(r), S.errD_vs150_mean(r), ...
        S.errD_vs150_mean(r), S.errD_vs150_mean(r)*W_DOWN);
end
fprintf('\nreference for comparison: current downswing trajectory error 15.13 cm, within-participant D variation σ_D = 1.04/1.33/0.75 cm\n');

%% figure
figure('Color','w','Position',[100 100 900 340]);
subplot(1,2,1); hold on; grid on;
errorbar(S.fps, S.errD_vs150_mean, S.errD_vs150_sd, '-o', 'LineWidth', 1.5, 'Color', [0.5 0 0.13]);
xlabel('Video frame rate (fps)'); ylabel('|\DeltaD| vs 150 fps (cm)');
title('Constraint error from downsampling'); set(gca, 'XDir', 'reverse');

subplot(1,2,2); hold on; grid on;
errorbar(S.fps, S.errADD_vs_mocap_mean, S.errADD_vs_mocap_sd, '-o', 'LineWidth', 1.5);
errorbar(S.fps, S.errIMP_vs_mocap_mean, S.errIMP_vs_mocap_sd, '-s', 'LineWidth', 1.5);
xlabel('Video frame rate (fps)'); ylabel('3D position error vs mocap (cm)');
legend({'ADD','IMP'}, 'Location', 'best'); title('Absolute accuracy'); set(gca, 'XDir', 'reverse');

exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_01_fps.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_01_fps.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_01_fps_summary.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_01_fps.png'));

%% local functions
function Xw = local_reconstruct(pix, R2w, Tw, L, fx, fy, cx, cy)
    u = pix(1); v = pix(2);
    rc = [(u - cx)/fx; (v - cy)/fy; 1];
    rw = R2w * rc;
    a = dot(rw, rw); b = 2*dot(rw, Tw); c = dot(Tw, Tw) - L^2;
    D = b^2 - 4*a*c;
    if D < 0
        Xw = [NaN; NaN; NaN]; return
    end
    s = [(-b + sqrt(D))/(2*a), (-b - sqrt(D))/(2*a)];
    s = s(s > 0);
    if isempty(s)
        Xw = [NaN; NaN; NaN]; return
    end
    Xw = Tw + max(s)*rw;
end
