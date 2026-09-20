%% [R2-10] R2_10_figure3_revised.m
%  Redraws Figure 3 so that the repeated-measures structure is visible.
%
%  The original figure plotted all participants' trials in one color, so it could not tell whether the linearity
%  comes from between-participant differences or within-participant variation. That is what comment 10 of Reviewer 2
%  points at, so the following are changed.
%
%    (1) color the points by participant
%    (2) overlay the participant means as large markers
%    (3) print the between-participant / within-participant correlation alongside the pooled correlation in each panel
%
%  The panel layout is the same as in the manuscript.
%    A-C : motion capture D  vs  video-based D_Vision
%    D-F : D_Vision    vs  pooled model D_Infer
%    G-I : D_Vision    vs  LOSO model D_Infer
%
%  Output : revision/results/fig_R2_10_figure3_revised.png / .svg
%         revision/results/R2_10_figure3_revised.csv
%
%  2026-09-06
%% ========================================================================

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 11);
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

RUN_POOL = fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2');
% this is the run matching the values printed in panels G-I of manuscript Figure 3 (0.07 / 0.33 / 0.19).
% verified by comparing the five runs with R2_10_find_loso_run.m.
RUN_LOSO = fullfile(ML, 'runs_0224_accgyro_400800_loso3');

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
subj = M.subj;
Dref = [M.Dref_x M.Dref_y M.Dref_z] / 10;      % mm -> cm
Dvid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
Dag  = [M.Dag_x  M.Dag_y  M.Dag_z ] / 10;
Dpool = local_load(RUN_POOL, subj, M.trial, false);
Dloso = local_load(RUN_LOSO, subj, M.trial, true);

u = unique(subj);
CMAP = lines(numel(u));
axName = {'X (anteroposterior)', 'Y (mediolateral)', 'Z (vertical)'};
ROW = { 'Motion capture D (cm)', 'D_{Vision} (cm)', 'D_{Vision} (cm)'; ...
        'D_{Vision} (cm)',       'D_{Infer} (cm)',  'D_{Infer}, LOSO (cm)' };
X = {Dref, Dvid, Dvid};
Y = {Dvid, Dpool, Dloso};
PANEL = 'ABCDEFGHI';

fig = figure('Color', 'w', 'Position', [60 40 1150 1000]);
rows = {};
for r = 1:3
    for d = 1:3
        ax = subplot(3, 3, (r-1)*3 + d); hold(ax, 'on'); box(ax, 'on');
        x = X{r}(:,d); y = Y{r}(:,d);
        ok = isfinite(x) & isfinite(y);

        % (1) trials colored by participant
        for k = 1:numel(u)
            m = ok & subj == u(k);
            scatter(ax, x(m), y(m), 16, CMAP(k,:), 'filled', 'MarkerFaceAlpha', 0.55);
        end
        % (2) participant means as large markers
        mx = arrayfun(@(s) mean(x(ok & subj==s)), u);
        my = arrayfun(@(s) mean(y(ok & subj==s)), u);
        scatter(ax, mx, my, 45, CMAP, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.6);

        % regression line and y = x
        p = polyfit(x(ok), y(ok), 1);
        xl = [min([x(ok); y(ok)]) max([x(ok); y(ok)])];
        xl = xl + [-1 1] * 0.08 * diff(xl);
        plot(ax, xl, polyval(p, xl), 'k-', 'LineWidth', 1.2);
        plot(ax, xl, xl, 'k--', 'LineWidth', 0.8);
        xlim(ax, xl); ylim(ax, xl);

        % (3) the three correlations
        [Rp, Pp] = corr(x(ok), y(ok));
        [Rb, Pb] = corr(mx, my);
        [Rw, Pw] = local_within(x(ok), y(ok), subj(ok));
        [ic, il, ih, ip] = local_icc(mx, my);
        fprintf(['ICC %s %-22s %5.2f [%5.2f, %5.2f] p = %.4f | between %5.2f | within %5.2f' NL], ...
                PANEL((r-1)*3+d), axName{d}, ic, il, ih, ip, Rb, Rw);
        text(ax, 0.04, 0.96, sprintf('ICC = %.2f%s', ic, local_star(ip)), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'FontWeight', 'bold', 'FontSize', 11);
        text(ax, 0.04, 0.885, sprintf('[%.2f, %.2f]', il, ih), 'Units', 'normalized', ...
             'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0.25 0.25 0.25]);
        text(ax, 0.96, 0.06, sprintf('within r %.2f%s', ...
             Rw, local_star(Pw)), 'Units', 'normalized', ...
             'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', [0.25 0.25 0.25]);
        title(ax, sprintf('(%s) %s', PANEL((r-1)*3 + d), axName{d}), 'FontWeight', 'normal');
        xlabel(ax, ROW{1,r}); ylabel(ax, ROW{2,r});
        rows = [rows; {PANEL((r-1)*3+d), axName{d}, Rp, Pp, Rb, Pb, Rw, Pw}]; %#ok<AGROW>
    end
end

T = cell2table(rows, 'VariableNames', {'panel','axis','R_pooled','p_pooled', ...
    'R_between','p_between','R_within','p_within'});
writetable(T, fullfile(OUT, 'R2_10_figure3_revised.csv'));
exportgraphics(fig, fullfile(OUT, 'fig_R2_10_figure3_revised.png'), 'Resolution', 200);
saveas(fig, fullfile(OUT, 'fig_R2_10_figure3_revised.svg'));
disp(T);
fprintf([NL 'saved: results/fig_R2_10_figure3_revised.png' NL]);

%% ===== Helper functions =====
function D = local_load(runDir, subj, trial, isLoso)
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
function [Rw, Pw] = local_within(x, y, s)
    u = unique(s); cx = x; cy = y;
    for k = 1:numel(u)
        m = s == u(k);
        cx(m) = cx(m) - mean(cx(m));
        cy(m) = cy(m) - mean(cy(m));
    end
    df = numel(x) - numel(u) - 1;
    Rw = sum(cx.*cy) / sqrt(sum(cx.^2)*sum(cy.^2));
    tw = Rw * sqrt(df / (1 - Rw^2));
    Pw = 2 * (1 - tcdf(abs(tw), df));
end
function s = local_star(p)
    if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, s = ''; end
end

function [icc, lo, hi, p] = local_icc(x, y)
    Y = [x(:) y(:)]; [n, k] = size(Y); gm = mean(Y(:));
    MSR = k * sum((mean(Y,2) - gm).^2) / (n-1);
    MSC = n * sum((mean(Y,1) - gm).^2) / (k-1);
    MSE = (sum((Y(:) - gm).^2) - (n-1)*MSR - (k-1)*MSC) / ((n-1)*(k-1));
    icc = (MSR - MSE) / (MSR + (k-1)*MSE);
    F = MSR / MSE; df1 = n-1; df2 = (n-1)*(k-1);
    p = 1 - fcdf(F, df1, df2);
    fL = F / finv(0.975, df1, df2); fU = F * finv(0.975, df2, df1);
    lo = (fL - 1) / (fL + k - 1); hi = (fU - 1) / (fU + k - 1);
end
