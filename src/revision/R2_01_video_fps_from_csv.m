%% [R2-1] R2_01_video_fps_from_csv.m
%  Reviewer 2, Comment R2-1 response — based on the original CSV (improved version)
%  ------------------------------------------------------------------------
%  Why redo this
%    The previous version (R2_01_video_fps_downsampling.m) used the stored g.dl. But g.dl
%    has already gone, inside matProcess0902.m, through
%       150 fps CSV -> 200 Hz linear interpolation -> 4th-order Butterworth 10 Hz low-pass
%    the above. If a 10 Hz low-pass is already applied, decimating to 60 fps (Nyquist 30 Hz)
%    loses almost nothing, so the downsampling effect comes out far smaller than it really is.
%
%    If the actual capture frame rate is lower, the order must be "decimate -> interpolate -> filter", so
%    this script first decimates the original CSV (150 fps, HRNet 2D output) and then runs it
%    through the same pipeline.
%
%  Terminology
%    "150 fps baseline" = the condition with no downsampling at all. The original video is 150 fps, so
%    this is the undegraded reference, and the 120/90/60/30 fps results are compared against it.
%
%  Procedure (per trial)
%    1) Load the left wrist pixels (x_pixel, y_pixel) from the CSV (150 fps)
%    2) Baseline : 200 Hz linear interpolation -> 10 Hz low-pass   (same as matProcess0902.m)
%    3) Align    : find the integer offset by least squares against the stored g.dl and match the 900-frame window
%                (matches the result instead of reproducing the sync logic. verified by the residual)
%    4) Each fps : decimate the CSV onto the target fps grid -> 200 Hz interpolation -> 10 Hz filter -> same offset
%    5) Solve the ray-sphere intersection with the ADD/IMP pixels to recompute the 3D position and the constraint D
%
%  Output : revision/results/R2_01_fps_from_csv.csv
%         revision/results/R2_01_fps_from_csv_summary.csv
%         revision/results/fig_R2_01_fps_from_csv.png/.svg
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
OUT_DIR = fullfile(thisDir, 'results');
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

%% ===== settings =====
VIDEO_ROOT = fullfile(dataRoot(), 'video');
subjN  = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN  = ["driver","iron","fast"];
CLUB   = 1;
TRIALS = 1:30;

FPS_SRC  = 150;                     % original capture frame rate
FS       = 200;                     % pipeline resampling frequency
CUT_FREQ = 10;                      % pose filter of matProcess0902.m (4th order, 10 Hz)
FPS_LIST = [150 120 90 60 30];      % 150 = baseline

EXCLUDED = [2 1 10; 6 1 3; 8 1 30];

[bf, af] = butter(4, CUT_FREQ/(FS/2));

%% ===== camera parameters (same as clublength_3d_1020.m) =====
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

%% ===== data load =====
fprintf('Loading swing data...\n');
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');

%% ===== trial loop =====
rows = {}; alignRes = [];
for subj = 1:10
    if     ismember(subj, [1 2 3]), R2w = R2w_0819;
    elseif ismember(subj, [4 5 6]), R2w = R2w_0821;
    else,                           R2w = R2w_0822;
    end
    Tw = T_CAM(subj,:)';
    L  = club_length(subj);

    p = fullfile(VIDEO_ROOT, char(subjN(subj)), char(clubN(CLUB)));
    f = dir(fullfile(p, '*.csv'));
    if isempty(f), warning('CSV not found: %s', p); continue; end
    [~, idx] = sort({f.name});                 % same ordering as matProcess0902.m
    f = f(idx);

    for trial = TRIALS
        if any(all(EXCLUDED == [subj CLUB trial], 2)), continue; end
        if trial > numel(f), continue; end

        g = swingData_2508(subj).clubN(CLUB).trialN(trial);
        if isempty(g) || isempty(g.dl), continue; end
        add = double(g.add); imp = double(g.imp);
        stored = g.dl(:, 4:5);                 % stored (aligned) 200 Hz pixels

        raw = readmatrix(fullfile(p, f(trial).name));
        if size(raw,2) < 5, continue; end
        px150 = raw(:, 4:5);                   % x_pixel, y_pixel @150 fps
        if any(~isfinite(px150(:))), continue; end

        % --- baseline: 150 -> 200 Hz -> 10 Hz filter ---
        base200 = local_pipeline(px150, FPS_SRC, FPS_SRC, FS, bf, af);

        % --- alignment: the integer offset that minimizes least squares against the stored signal ---
        [off, res] = local_align(base200, stored);
        if isnan(off), continue; end
        alignRes(end+1,:) = [subj trial res]; %#ok<SAGROW>

        % motion capture reference value
        WristU = g.marker(:,13:15); WristL = g.marker(:,7:9);
        abs_wrist = (WristU + WristL) ./ 2;
        Dref = (abs_wrist(imp,:) - abs_wrist(add,:))';

        P = cell(numel(FPS_LIST), 2);
        okAll = true;
        for fi = 1:numel(FPS_LIST)
            fps = FPS_LIST(fi);
            s200 = local_pipeline(px150, FPS_SRC, fps, FS, bf, af);
            ia = off + add; ii = off + imp;
            if ia < 1 || ii > size(s200,1), okAll = false; break; end
            P{fi,1} = local_reconstruct(s200(ia,:), R2w, Tw, L, fx, fy, cx, cy);
            P{fi,2} = local_reconstruct(s200(ii,:), R2w, Tw, L, fx, fy, cx, cy);
        end
        if ~okAll, continue; end

        Dbase = P{1,2} - P{1,1};
        for fi = 1:numel(FPS_LIST)
            Df = P{fi,2} - P{fi,1};
            rows(end+1,:) = { subj, string(subjN(subj)), trial, FPS_LIST(fi), ...
                norm(P{fi,1} - P{1,1}), norm(P{fi,2} - P{1,2}), ...
                norm(Df - Dbase), norm(Df - Dref) }; %#ok<SAGROW>
        end
    end
    fprintf('  subject %d done\n', subj);
end

R = cell2table(rows, 'VariableNames', {'subj','subjName','trial','fps', ...
    'errADD_vs150','errIMP_vs150','errD_vs150','errD_vs_mocap'});
writetable(R, fullfile(OUT_DIR, 'R2_01_fps_from_csv.csv'));

fprintf('\n[alignment check] residual vs stored (pixels) : mean %.3f, median %.3f, max %.3f  (n=%d)\n', ...
    mean(alignRes(:,3)), median(alignRes(:,3)), max(alignRes(:,3)), size(alignRes,1));

%% ===== summary (participant level) =====
subjList = unique(R.subj);
srows = {};
cols = {'errADD_vs150','errIMP_vs150','errD_vs150','errD_vs_mocap'};
for fi = 1:numel(FPS_LIST)
    k = R.fps == FPS_LIST(fi);
    v = nan(1, 2*numel(cols));
    for c = 1:numel(cols)
        sm = nan(numel(subjList),1);
        for si = 1:numel(subjList)
            sm(si) = mean(R.(cols{c})(k & R.subj == subjList(si)), 'omitnan');
        end
        v(2*c-1) = mean(sm,'omitnan')/10;      % mm -> cm
        v(2*c)   = std(sm,'omitnan')/10;
    end
    srows(end+1,:) = [{FPS_LIST(fi)}, num2cell(v)]; %#ok<SAGROW>
end
S = cell2table(srows, 'VariableNames', {'fps', ...
    'errADD_mean','errADD_sd','errIMP_mean','errIMP_sd', ...
    'errD_mean','errD_sd','errD_mocap_mean','errD_mocap_sd'});
writetable(S, fullfile(OUT_DIR, 'R2_01_fps_from_csv_summary.csv'));

%% ===== console =====
W_DOWN = 0.91;                                  % downswing mean weight obtained in R2-2
fprintf('\n===== [R2-1] frame rate effect based on the original CSV (cm, participant level) =====\n');
fprintf('order: decimate -> 200 Hz interpolation -> 10 Hz filter. 150 fps = baseline (no downsampling)\n\n');
fprintf('%6s %12s %12s %14s %16s %14s\n', 'fps', 'ADD error', 'IMP error', '|ΔD|', 'impact traj err', 'downswing mean');
for r = 1:height(S)
    fprintf('%6d %12.3f %12.3f %14.3f %16.3f %14.3f\n', S.fps(r), ...
        S.errADD_mean(r), S.errIMP_mean(r), S.errD_mean(r), ...
        S.errD_mean(r), S.errD_mean(r)*W_DOWN);
end
fprintf('\nD error vs motion capture: ');
fprintf('%d fps %.2f  ', [S.fps'; S.errD_mocap_mean']);
fprintf('\n\ncomparison reference: downswing trajectory error 15.13 cm, within-participant σ_D = 1.04 / 1.33 / 0.75 cm\n');

%% ===== figures =====
figure('Color','w','Position',[100 100 900 340]);
subplot(1,2,1); hold on; grid on;
errorbar(S.fps, S.errD_mean, S.errD_sd, '-o', 'LineWidth', 1.5, 'Color', [0.5 0 0.13]);
yline(1.04, 'k--'); text(max(S.fps), 1.04, ' \sigma_D (X)', 'VerticalAlignment','bottom');
xlabel('Video frame rate (fps)'); ylabel('|\DeltaD| vs 150 fps (cm)');
title('Constraint error vs frame rate'); set(gca,'XDir','reverse');

subplot(1,2,2); hold on; grid on;
errorbar(S.fps, S.errADD_mean, S.errADD_sd, '-o', 'LineWidth', 1.5);
errorbar(S.fps, S.errIMP_mean, S.errIMP_sd, '-s', 'LineWidth', 1.5);
xlabel('Video frame rate (fps)'); ylabel('3D position error vs 150 fps (cm)');
legend({'ADD','IMP'}, 'Location','best'); title('Per-event error'); set(gca,'XDir','reverse');

exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_01_fps_from_csv.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_01_fps_from_csv.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_01_fps_from_csv_summary.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_01_fps_from_csv.png'));


%% ===== local functions =====
function out = local_pipeline(px_src, fps_src, fps_target, fs, bf, af)
% Decimate from the original (fps_src) to fps_target, then interpolate to fs and low-pass.
% If fps_target == fps_src, only interpolation+filter without decimation (baseline).
    n  = size(px_src, 1);
    t0 = (0:n-1)' / fps_src;
    if fps_target < fps_src
        tg  = (0 : 1/fps_target : t0(end))';
        px  = interp1(t0, px_src, tg, 'linear');
        tin = tg;
    else
        px  = px_src;
        tin = t0;
    end
    tnew = (0 : 1/fs : tin(end))';
    out  = interp1(tin, px, tnew, 'linear', 'extrap');
    out  = filtfilt(bf, af, out);
end

function [off, res] = local_align(base200, stored)
% Find the integer offset telling where in base200 stored(900x2) was cut out
    n = size(stored, 1); N = size(base200, 1);
    if N < n, off = NaN; res = NaN; return; end
    best = inf; off = NaN;
    for k = 0:(N - n)
        d = base200(k+1:k+n, :) - stored;
        e = mean(sqrt(sum(d.^2, 2)));
        if e < best, best = e; off = k; end
    end
    res = best;
end

function Xw = local_reconstruct(pix, R2w, Tw, L, fx, fy, cx, cy)
    rc = [(pix(1) - cx)/fx; (pix(2) - cy)/fy; 1];
    rw = R2w * rc;
    a = dot(rw,rw); b = 2*dot(rw,Tw); c = dot(Tw,Tw) - L^2;
    D = b^2 - 4*a*c;
    if D < 0, Xw = [NaN;NaN;NaN]; return; end
    s = [(-b + sqrt(D))/(2*a), (-b - sqrt(D))/(2*a)];
    s = s(s > 0);
    if isempty(s), Xw = [NaN;NaN;NaN]; return; end
    Xw = Tw + max(s)*rw;
end
