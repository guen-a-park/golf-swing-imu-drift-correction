%% [R2-1] R2_01_fps_trajectory_figure.m
%  Shows as a figure how the 2D wrist trajectory actually changes when the frame rate is lowered.
%  Output : results/fig_R2_01_fps_traj.png / .svg

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 14);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
OUT_DIR = fullfile(thisDir, 'results');

VIDEO_ROOT = fullfile(dataRoot(), 'video');
subjN  = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
SUBJ = 3; CLUB = 1; TRIAL = 21;          % same trial as the worked example

FPS_SRC = 150; FS = 200; CUT_FREQ = 10;
FPS_LIST = [150 120 60 30];
[bf, af] = butter(4, CUT_FREQ/(FS/2));

dark_red = [128 0 32]/255;
COL = [0 0 0; 0.30 0.45 0.75; 0.90 0.55 0.10; dark_red];

%% data
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');
g = swingData_2508(SUBJ).clubN(CLUB).trialN(TRIAL);
add = double(g.add); imp = double(g.imp);

p = fullfile(VIDEO_ROOT, subjN(SUBJ), 'driver');
f = dir(fullfile(p, '*.csv'));
[~, idx] = sort({f.name}); f = f(idx);
raw = readmatrix(fullfile(p, f(TRIAL).name));
px150 = raw(:, 4:5);

base200 = local_pipeline(px150, FPS_SRC, FPS_SRC, FS, bf, af);
off = local_align(base200, g.dl(:, 4:5));
t = ((1:size(g.dl,1))' - imp) / FS;       % time relative to impact (s)

S = cell(numel(FPS_LIST), 1);
SMP = cell(numel(FPS_LIST), 2);          % actual sample points before interpolation (time, pixel)
for fi = 1:numel(FPS_LIST)
    [s, tg, pg] = local_pipeline(px150, FPS_SRC, FPS_LIST(fi), FS, bf, af);
    S{fi} = s(off + (1:size(g.dl,1)), :);
    SMP{fi,1} = tg - (off + imp - 1)/FS;  % convert to time relative to impact
    SMP{fi,2} = pg;
end

%% figure
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 6.6 2.4], ...
             'PaperUnits', 'inches', 'PaperSize', [6.6 2.4], ...
             'PaperPosition', [0 0 6.6 2.4]);
set(fig, 'DefaultAxesFontName', 'Gill Sans MT', 'DefaultTextFontName', 'Gill Sans MT');
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
win = (t >= -2.0) & (t <= 0.6);

PANEL = {'A', 'B'};
YL = {'Wrist x (pixel)', 'Wrist y (pixel)'};
for k = 1:2
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'off');
    set(ax, 'FontSize', 9, 'TickDir', 'in', 'LineWidth', 0.6, 'Layer', 'top');
    for fi = 1:numel(FPS_LIST)
        plot(ax, t(win), S{fi}(win,k), 'Color', COL(fi,:), 'LineWidth', 1.2);
    end
    local_events(t, add, imp);
    ylabel(ax, YL{k}, 'FontSize', 9);
    xlabel(ax, 'Time from impact (s)', 'FontSize', 9);
    text(ax, -0.15, 1.12, PANEL{k}, 'Units', 'normalized', ...
         'FontName', 'Gill Sans MT', 'FontSize', 12, 'VerticalAlignment', 'top');
    if k == 1
        legend(ax, compose('%d fps', FPS_LIST), 'Location', 'northwest', ...
               'Box', 'off', 'FontSize', 8);
    end
end

print(fig, fullfile(OUT_DIR, 'fig_R2_01_fps_traj.png'), '-dpng', '-r300');
print(fig, fullfile(OUT_DIR, 'fig_R2_01_fps_traj.svg'), '-dsvg');

%% values at the two events
fprintf('\n=== participant %d, driver %d: pixel coordinates by frame rate ===\n', SUBJ, TRIAL);
fprintf('%-8s %22s %22s %14s\n', 'fps', 'ADD (x, y)', 'IMP (x, y)', 'IMP deviation(px)');
for fi = 1:numel(FPS_LIST)
    fprintf('%-8d (%8.2f, %8.2f) (%8.2f, %8.2f) %12.2f\n', FPS_LIST(fi), ...
        S{fi}(add,1), S{fi}(add,2), S{fi}(imp,1), S{fi}(imp,2), ...
        norm(S{fi}(imp,:) - S{1}(imp,:)));
end
d_all = vecnorm(S{end} - S{1}, 2, 2);
seg = add:imp;
fprintf('\n30 fps deviation from 150 fps: address %.2f px, impact %.2f px, downswing max %.2f px\n', ...
    d_all(add), d_all(imp), max(d_all(seg)));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_01_fps_traj.png'));

%% local
function local_events(t, add, imp)
    yl = ylim;
    xline(t(add), 'k-', 'ADD', 'LabelVerticalAlignment', 'bottom');
    xline(t(imp), 'k-', 'IMP', 'LabelVerticalAlignment', 'bottom');
    ylim(yl);
end

function [out, tin, px] = local_pipeline(px_src, fps_src, fps_target, fs, bf, af)
    n  = size(px_src, 1);
    t0 = (0:n-1)' / fps_src;
    if fps_target < fps_src
        tg  = (0 : 1/fps_target : t0(end))';
        px  = interp1(t0, px_src, tg, 'linear');
        tin = tg;
    else
        px  = px_src;  tin = t0;
    end
    tnew = (0 : 1/fs : tin(end))';
    out  = interp1(tin, px, tnew, 'linear', 'extrap');
    out  = filtfilt(bf, af, out);
end

function off = local_align(base200, stored)
    n = size(stored, 1); N = size(base200, 1);
    best = inf; off = NaN;
    for k = 0:(N - n)
        r = mean(vecnorm(base200(k + (1:n), :) - stored, 2, 2));
        if r < best, best = r; off = k; end
    end
end
