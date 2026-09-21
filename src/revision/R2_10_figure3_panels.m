%% [R2-10] R2_10_figure3_panels.m
%  Exports the nine panels of Figure 3 one at a time.
%  Output : revision/results/fig3_panels/panel_A.emf ... panel_I.emf (+ png)

clc; clear; close all;
NL = char(10);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
PDIR = fullfile(OUT, 'fig3_panels');
if ~exist(PDIR, 'dir'), mkdir(PDIR); end
ML = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
RUN_POOL = fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2');
RUN_LOSO = fullfile(ML, 'runs_0224_accgyro_400800_loso3');

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);   % driver test trials
subj = M.subj;
Dref = [M.Dref_x M.Dref_y M.Dref_z] / 10;      % mm -> cm
Dvid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
Dpool = local_load(RUN_POOL, subj, false);
Dloso = local_load(RUN_LOSO, subj, true);

u = unique(subj);
CMAP = R2_participant_colors();
X = {Dref, Dvid, Dvid};
Y = {Dvid, Dpool, Dloso};
PANEL = 'ABCDEFGHI';

W = 1.72; H = 1.57;          % panel size of the submitted figure, in inches
for r = 1:3
    for d = 1:3
        k = (r-1)*3 + d;
        fig = figure('Color', 'w', 'Units', 'inches', ...
                     'Position', [1 1 W H], 'PaperUnits', 'inches', ...
                     'PaperSize', [W H], 'PaperPosition', [0 0 W H]);
        set(fig, 'DefaultAxesFontName', 'Gill Sans MT', ...
                 'DefaultTextFontName', 'Gill Sans MT');
        ax = axes(fig, 'Position', [0.155 0.115 0.775 0.815]);
        hold(ax, 'on'); box(ax, 'off');
        set(ax, 'FontSize', 8, 'TickDir', 'in', 'LineWidth', 0.6, 'Layer', 'top');

        x = X{r}(:,d); y = Y{r}(:,d);
        ok = isfinite(x) & isfinite(y);
        for s = 1:numel(u)
            m = ok & subj == u(s);
            scatter(ax, x(m), y(m), 9, CMAP(u(s),:), 'filled', 'MarkerFaceAlpha', 1);
        end
        xlim(ax, [-30 30]); ylim(ax, [-30 30]);
        xticks(ax, -30:10:30); yticks(ax, -30:10:30);
        set(ax, 'XTickLabelRotation', 0, 'YTickLabelRotation', 0);

        base = fullfile(PDIR, ['panel_' PANEL(k)]);
        exportgraphics(fig, [base '.png'], 'Resolution', 300);
        print(fig, [base '.emf'], '-dmeta');
        close(fig);
    end
end
fprintf(['saved: results/fig3_panels/panel_A..I.emf' NL]);

%% local functions
function D = local_load(runDir, subj, isLoso)
D = nan(numel(subj), 3);
for su = unique(subj)'
    if isLoso
        f = fullfile(runDir, sprintf('fold_subj%d', su), ...
                     sprintf('subj%d_driver_test_est.csv', su));
    else
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
    end
    if ~isfile(f), continue; end
    T = readtable(f);
    idx = find(subj == su);
    for k = 1:min(numel(idx), height(T))
        D(idx(k), :) = [T.pred_x(k) T.pred_y(k) T.pred_z(k)];
    end
end
D = D / 10;
end
