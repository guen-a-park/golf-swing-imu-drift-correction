%% [R2-11 / note 53] R2_11_consistency_traj_figure.m
%  shows consistency with the trajectories themselves rather than with a bar chart. Nothing is averaged;
%  all 10 trials are drawn for each participant.
%
%  Note : the overall size of the wrist trajectory is about 2000 mm while the between-trial band width is 7-18 mm, so
%         overlaying the raw trajectories makes them look like a single line. Each trial is therefore drawn as
%         a deviation from that participant's mean trajectory. The mean serves only as a baseline and
%         the 10 curves remain intact.
%
%  Output : results/fig_R2_11_consistency_traj.png / .svg
%  2026-08-31
%% ========================================================================
clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
L = load(fullfile(RES, 'R2_11_trajectory_store.mat'), 'R2_11_store');
S = L.R2_11_store;

WIN = [-280 0];                  % the same window as R2_11_band_width.m (1.4 s before impact)
FS  = 200;
AX  = 1;                         % X axis (the axis with the largest band ratio in the manuscript)
CM  = [0.45 0.45 0.45];          % motion capture
CE  = [0.00 0.35 0.75];          % proposed method

figure('Color', 'w', 'Position', [80 80 1500 560]);
tiledlayout(2, 5, 'TileSpacing', 'compact', 'Padding', 'compact');

bw = nan(numel(S), 2);
for si = 1:numel(S)
    s = S(si);
    imp = round(mean(double(s.imp)));
    idx = max(1, imp+WIN(1)) : min(size(s.ref,1), imp+WIN(2));
    t   = (idx - imp)' / FS;

    M = squeeze(s.ref(idx,  AX, 1:min(s.nTr, size(s.ref,3))));
    E = squeeze(s.prop(idx, AX, 1:min(s.nTr, size(s.prop,3))));
    M = (M - mean(M, 2, 'omitnan')) / 10;    % deviation from its own mean, cm
    E = (E - mean(E, 2, 'omitnan')) / 10;
    bw(si,:) = [mean(4*std(M, 0, 2), 'omitnan') mean(4*std(E, 0, 2), 'omitnan')];

    nexttile; hold on;
    plot(t, M, '-', 'Color', [CM 0.6], 'LineWidth', 0.7);
    plot(t, E, '-', 'Color', [CE 0.6], 'LineWidth', 0.7);
    yline(0, 'k:');
    title(sprintf('P%d', s.subj), 'FontWeight', 'normal');
    xlim([t(1) 0]); ylim([-36 36]); box off;
    if si > 5, xlabel('Time from impact (s)'); end
    if mod(si-1, 5) == 0, ylabel('Deviation in X (cm)'); end
end

h(1) = plot(nan, nan, '-', 'Color', CM, 'LineWidth', 1.5);
h(2) = plot(nan, nan, '-', 'Color', CE, 'LineWidth', 1.5);
legend(h, {'Motion capture', 'Proposed'}, 'Box', 'off', ...
    'Location', 'southoutside', 'Orientation', 'horizontal');

exportgraphics(gcf, fullfile(RES, 'fig_R2_11_consistency_traj.png'), 'Resolution', 300);
saveas(gcf, fullfile(RES, 'fig_R2_11_consistency_traj.svg'));

fprintf('\n%-8s %14s %14s %8s\n', 'subject', 'mocap band(cm)', 'proposed band(cm)', 'ratio');
for si = 1:numel(S)
    fprintf('P%-7d %14.1f %14.1f %8.2f\n', S(si).subj, bw(si,1), bw(si,2), bw(si,2)/bw(si,1));
end
fprintf('%-8s %14.1f %14.1f %8.2f\n', 'mean', mean(bw(:,1)), mean(bw(:,2)), mean(bw(:,2)./bw(:,1)));
fprintf('\nsaved: %s\n', fullfile(RES, 'fig_R2_11_consistency_traj.png'));
