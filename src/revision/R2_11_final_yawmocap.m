%% [R2-11] R2_11_final_yawmocap.m
%  Repeats the consistency analysis with the initial heading aligned to a common reference.
%  Output    : revision/results/R2_11_final_yawmocap.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

load(fullfile(OUT, 'R2_11_trajectory_store_yawmocap.mat'), 'R2_11_store');
S = R2_11_store;
NSIG = 2;  WIN = [-280 0];  axName = {'X (anteroposterior)','Y (mediolateral)','Z (vertical)'};

subj = []; aR = []; aE = [];
bM = nan(numel(S),3); bE = nan(numel(S),3); rE = nan(numel(S),3);

for s = 1:numel(S)
    st = S(s);
    if isempty(st) || isempty(st.ref) || isempty(st.ref_fast), continue; end
    imp = round(mean(double(st.imp)));
    idx = max(1, imp + WIN(1)) : min(size(st.ref,1), imp + WIN(2));
    refP = st.ref * 0.1;  estP = st.prop * 0.1;
    refF = st.ref_fast * 0.1;  estF = st.prop_fast * 0.1;

    mR = mean(refP(idx,:,:), 3);  sR = std(refP(idx,:,:), 0, 3);
    mE = mean(estP(idx,:,:), 3);  sE = std(estP(idx,:,:), 0, 3);
    for d = 1:3
        bM(s,d) = mean(2*NSIG*sR(:,d));
        bE(s,d) = mean(2*NSIG*sE(:,d));
        rE(s,d) = sqrt(mean(mean((refP(idx,d,:) - estP(idx,d,:)).^2)));
    end
    for t = 1:size(refF,3)
        iR = zeros(1,3); iE = zeros(1,3);
        for d = 1:3
            iR(d) = mean(abs(refF(idx,d,t) - mR(:,d)) <= NSIG*sR(:,d));
            iE(d) = mean(abs(estF(idx,d,t) - mE(:,d)) <= NSIG*sE(:,d));
        end
        subj(end+1,1) = st.subj;            %#ok<SAGROW>
        aR(end+1,1) = mean(iR)*100;         %#ok<SAGROW>
        aE(end+1,1) = mean(iE)*100;         %#ok<SAGROW>
    end
end
ok = all(isfinite(bM), 2);
bM = bM(ok,:); bE = bE(ok,:); rE = rE(ok,:);

%% (1) band width
fprintf([NL 'band width and reconstruction error per axis (%d participants, cm)' NL], size(bM,1));
rows = {};
for d = 1:3
    [~, p] = ttest(bM(:,d), bE(:,d));
    fprintf('  %-22s motion capture %5.1f   IMU %5.1f   ratio %.1f   recon err %5.1f   p = %.4f%s', ...
            axName{d}, mean(bM(:,d)), mean(bE(:,d)), mean(bE(:,d))/mean(bM(:,d)), ...
            mean(rE(:,d)), p, NL);
    rows = [rows; {axName{d}, mean(bM(:,d)), mean(bE(:,d)), ...
                   mean(bE(:,d))/mean(bM(:,d)), mean(rE(:,d)), p}]; %#ok<AGROW>
end

%% (2)(3) agreement rate
u = unique(subj);
x = arrayfun(@(v) mean(aR(subj==v)), u);
y = arrayfun(@(v) mean(aE(subj==v)), u);
d0 = y - x;
[~, pb, ~, st_] = ttest(x, y);
[ic, lo, hi, pi_] = local_icc(x, y);
[Rw, Pw] = local_within(aR, aE, subj);

fprintf([NL 'agreement rate (%d fast trials, %d participants)' NL], numel(subj), numel(u));
fprintf('  motion capture %.1f +/- %.1f %%   IMU %.1f +/- %.1f %%%s', ...
        mean(x), std(x), mean(y), std(y), NL);
fprintf('  bias %+.1f %%p (t = %.2f, p = %.4f), 95%% limits of agreement [%.1f, %.1f]%s', ...
        mean(d0), st_.tstat, pb, mean(d0)-1.96*std(d0), mean(d0)+1.96*std(d0), NL);
fprintf('  ICC %.2f [%.2f, %.2f] (p = %.4g)%s', ic, lo, hi, pi_, NL);
fprintf('  within-participant r %.2f (p = %.4g)%s', Rw, Pw, NL);

%% (4) Figure 6D
CMAP = R2_participant_colors();   % index by participant number
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 2.6 2.7]);
set(fig, 'DefaultAxesFontName', 'Gill Sans MT', 'DefaultTextFontName', 'Gill Sans MT');
ax = axes(fig, 'Position', [0.185 0.150 0.775 0.775]);
hold(ax, 'on'); box(ax, 'off');
set(ax, 'FontSize', 12, 'TickDir', 'in', 'LineWidth', 0.6, 'Layer', 'top');
for k = 1:numel(u)
    m = subj == u(k);
    scatter(ax, aR(m), aE(m), 26, CMAP(u(k),:), 'filled', 'MarkerFaceAlpha', 1);
end
xl = [0 100];
xlim(ax, xl); ylim(ax, xl); axis(ax, 'square');
xticks(ax, 0:20:100); yticks(ax, 0:20:100);
plot(ax, xl, [xl(2) xl(2)], 'k-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
plot(ax, [xl(2) xl(2)], xl, 'k-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
text(ax, 0.05, 0.96, sprintf('r = %.2f', Rw), 'Units', 'normalized', ...
     'VerticalAlignment', 'top', 'FontSize', 8);
text(ax, 0.05, 0.87, local_ptxt(Pw), 'Units', 'normalized', ...
     'VerticalAlignment', 'top', 'FontSize', 8);
text(ax, -0.26, 1.10, 'D', 'Units', 'normalized', ...
     'FontWeight', 'bold', 'FontSize', 11, 'VerticalAlignment', 'top');
xlabel(ax, 'Measured Consistency (%)', 'FontSize', 7.5);
ylabel(ax, 'Estimated Consistency (%)', 'FontSize', 7.5);

writetable(cell2table(rows, 'VariableNames', {'axis','band_mocap','band_imu','ratio', ...
    'recon_err','p'}), fullfile(OUT, 'R2_11_final_yawmocap.csv'));
writetable(table(subj, aR, aE, 'VariableNames', {'subj','agree_mocap','agree_est'}), ...
    fullfile(OUT, 'R2_11_agreement_yawmocap.csv'));
exportgraphics(fig, fullfile(OUT, 'fig_R2_11_figure6d_final.png'), 'Resolution', 200);
saveas(fig, fullfile(OUT, 'fig_R2_11_figure6d_final.svg'));
fprintf([NL 'saved: results/fig_R2_11_figure6d_final.png' NL]);

%% local functions
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

function s = local_ptxt(p)
if p < 0.001, s = 'p < 0.001'; else, s = sprintf('p = %.3f', p); end
end
