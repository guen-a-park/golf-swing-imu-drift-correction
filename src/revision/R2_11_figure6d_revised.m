%% [R2-11] R2_11_figure6d_revised.m
%  Redraws Figure 6D so that the repeated-measures structure is visible.
%  Output      : revision/results/fig_R2_11_figure6d_revised.png / .svg

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

A = readtable(fullfile(OUT, 'R2_11_agreement_within.csv'));
s = A.subj; x = A.agree_mocap; y = A.agree_est;
u = unique(s); CMAP = R2_participant_colors();   % index by participant number

fig = figure('Color', 'w', 'Position', [200 200 560 520]);
ax = axes(fig); hold(ax, 'on'); box(ax, 'on');

for k = 1:numel(u)
    m = s == u(k);
    scatter(ax, x(m), y(m), 26, CMAP(u(k),:), 'filled', 'MarkerFaceAlpha', 1);
end
mx = arrayfun(@(v) mean(x(s==v)), u);
my = arrayfun(@(v) mean(y(s==v)), u);

p  = polyfit(x, y, 1);
xl = [0 100];
plot(ax, xl, polyval(p, xl), 'k-',  'LineWidth', 1.3);
plot(ax, xl, xl,             'k--', 'LineWidth', 0.9);
xlim(ax, xl); ylim(ax, xl); axis(ax, 'square');

[ic, lo, hi, pi_] = local_icc(mx, my);
[Rw, Pw] = local_within(x, y, s);
text(ax, 0.04, 0.96, sprintf('ICC = %.2f%s', ic, local_star(pi_)), ...
     'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'FontWeight', 'bold', 'FontSize', 13);
text(ax, 0.04, 0.89, sprintf('[%.2f, %.2f]', lo, hi), 'Units', 'normalized', ...
     'VerticalAlignment', 'top', 'FontSize', 10, 'Color', [0.25 0.25 0.25]);
text(ax, 0.96, 0.06, sprintf('within r %.2f%s', Rw, local_star(Pw)), ...
     'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
     'HorizontalAlignment', 'right', 'FontSize', 10, 'Color', [0.25 0.25 0.25]);
xlabel(ax, 'Motion capture based agreement rate (%)');
ylabel(ax, 'IMU based agreement rate (%)');

fprintf([NL '%d fast trials, %d participants' NL], numel(s), numel(u));
fprintf('ICC = %.2f [%.2f, %.2f], p = %.4g%s', ic, lo, hi, pi_, NL);
fprintf('within r = %.2f, p = %.4g%s', Rw, Pw, NL);

exportgraphics(fig, fullfile(OUT, 'fig_R2_11_figure6d_revised.png'), 'Resolution', 200);
saveas(fig, fullfile(OUT, 'fig_R2_11_figure6d_revised.svg'));
fprintf([NL 'saved: results/fig_R2_11_figure6d_revised.png' NL]);

%% helper functions
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
