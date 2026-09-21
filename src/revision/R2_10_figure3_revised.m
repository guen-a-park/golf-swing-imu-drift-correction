%% [R2-10] R2_10_figure3_revised.m
%  Redraws Figure 3 so that the repeated-measures structure is visible.
%  Output : revision/results/fig_R2_10_figure3_revised.png / .svg

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 11);
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

RUN_POOL = fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2');
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
CMAP = R2_participant_colors();   % index by participant number
axName = {'X (anteroposterior)', 'Y (mediolateral)', 'Z (vertical)'};  % for the log and the csv
axShort = {'X', 'Y', 'Z'};
ROW = { 'Measured %s (cm)', 'Proposed Estimated %s (cm)', 'Proposed Estimated %s (cm)'; ...
        'Proposed Estimated %s (cm)', 'ML Estimated %s (cm)', 'ML Estimated %s (cm)' };
X = {Dref, Dvid, Dvid};
Y = {Dvid, Dpool, Dloso};
PANEL = 'ABCDEFGHI';

fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 6.3 6.5]);
set(fig, 'DefaultAxesFontName', 'Gill Sans MT', 'DefaultTextFontName', 'Gill Sans MT');
rows = {};
for r = 1:3
    for d = 1:3
        ax = subplot(3, 3, (r-1)*3 + d); hold(ax, 'on'); box(ax, 'off');
        set(ax, 'FontSize', 7, 'TickDir', 'out', 'LineWidth', 0.6, 'Layer', 'top');
        x = X{r}(:,d); y = Y{r}(:,d);
        ok = isfinite(x) & isfinite(y);

        for k = 1:numel(u)
            m = ok & subj == u(k);
            scatter(ax, x(m), y(m), 6, CMAP(u(k),:), 'filled', 'MarkerFaceAlpha', 1);
        end
        mx = arrayfun(@(s) mean(x(ok & subj==s)), u);
        my = arrayfun(@(s) mean(y(ok & subj==s)), u);

        xl = [-30 30];   % the fixed range used in the submitted figure
        plot(ax, xl, xl, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.6);
        xlim(ax, xl); ylim(ax, xl); axis(ax, 'square');
        xticks(ax, -30:10:30); yticks(ax, -30:10:30);

        [Rp, Pp] = corr(x(ok), y(ok));
        [Rb, Pb] = corr(mx, my);
        [Rw, Pw] = local_within(x(ok), y(ok), subj(ok));
        [ic, il, ih, ip] = local_icc(mx, my);
        fprintf(['ICC %s %-22s %5.2f [%5.2f, %5.2f] p = %.4f | between %5.2f | within %5.2f' NL], ...
                PANEL((r-1)*3+d), axName{d}, ic, il, ih, ip, Rb, Rw);
        text(ax, 0.05, 0.97, sprintf('ICC = %.2f', ic), 'Units', 'normalized', ...
             'VerticalAlignment', 'top', 'FontWeight', 'bold', 'FontSize', 7.5);
        text(ax, 0.05, 0.875, local_ptxt(ip), 'Units', 'normalized', ...
             'VerticalAlignment', 'top', 'FontSize', 7);
        text(ax, 0.05, 0.785, sprintf('[%.2f, %.2f]', il, ih), 'Units', 'normalized', ...
             'VerticalAlignment', 'top', 'FontSize', 6.5, 'Color', [0.35 0.35 0.35]);
        text(ax, -0.30, 1.14, PANEL((r-1)*3 + d), 'Units', 'normalized', ...
             'FontWeight', 'bold', 'FontSize', 11, 'VerticalAlignment', 'top');
        xlabel(ax, sprintf(ROW{1,r}, axShort{d}), 'FontSize', 7.5);
        ylabel(ax, sprintf(ROW{2,r}, axShort{d}), 'FontSize', 7.5);
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

%% local functions
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

function s = local_ptxt(p)
if p < 0.001, s = 'p < 0.001'; else, s = sprintf('p = %.3f', p); end
end
