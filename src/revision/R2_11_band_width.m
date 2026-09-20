%% [R2-11] R2_11_band_width.m
%  Reviewer 2, Comment R2-11 response
%  ------------------------------------------------------------------------
%  Comment: is the consistency metric (proportion inside the ±2 SD band) governed not by actual swing repeatability but
%        by reconstruction uncertainty? If the IMU trajectory varies more than motion capture,
%        the tolerance band widens and the agreement rate is artificially inflated.
%
%  Computed (per participant, per axis, per interval)
%    (1) band width  : ±2 SD width of the 10 preferred swings  = 4 x SD
%                     motion capture band vs proposed (corrected) trajectory band
%    (2) band ratio  : band_est / band_mocap  (greater than 1 means the band widened)
%    (3) recon error : per-sample |ref - prop| RMS
%    (4) key metric  : reconstruction error / motion capture band width
%                     -> this must be small for "reconstruction uncertainty is small relative to the variability measured"
%
%  Prerequisite : R2_11_draw_figure5_copy.m  (creates results/R2_11_trajectory_store.mat)
%  Output       : revision/results/R2_11_band_width.csv
%              revision/results/R2_11_band_width_summary.csv
%              revision/results/fig_R2_11_band_width.png/.svg
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
storeFile = fullfile(OUT_DIR, 'R2_11_trajectory_store.mat');
if ~isfile(storeFile)
    error('%s not found. Run R2_11_draw_figure5_copy.m first.', storeFile);
end
load(storeFile, 'R2_11_store');

subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
axesName = {'X','Y','Z'};
NSIGMA = 2;                      % same as the manuscript: ±2 SD

% consistency evaluation window of manuscript Figure 6 : -1.4 s to impact, relative to impact (280 frames)
WIN = [-280 0];

rows = {};
for s = 1:numel(R2_11_store)
    st = R2_11_store(s);
    if isempty(st) || isempty(st.ref), continue; end

    % preferred swings (data forming the band). stored in mm, so convert to cm
    ref  = st.ref  * 0.1;          % [T x 3 x nTr], motion capture
    prop = st.prop * 0.1;          % proposed (corrected) trajectory
    nTr  = size(ref, 3);
    if nTr < 3, continue; end

    imp = round(mean(double(st.imp)));
    i0 = max(1, imp + WIN(1));
    i1 = min(size(ref,1), imp + WIN(2));
    idx = i0:i1;

    for d = 1:3
        Rr = squeeze(ref (idx, d, :));            % [T x nTr]
        Pp = squeeze(prop(idx, d, :));

        band_ref  = 2*NSIGMA * std(Rr, 0, 2);     % ±2SD full width
        band_prop = 2*NSIGMA * std(Pp, 0, 2);
        recon_err = sqrt(mean((Rr - Pp).^2, 2));  % per-sample reconstruction RMS error

        rows(end+1,:) = { s, string(subjN(s)), axesName{d}, nTr, ...
            mean(band_ref), mean(band_prop), mean(band_prop)/mean(band_ref), ...
            mean(recon_err), mean(recon_err)/mean(band_ref), ...
            max(band_ref), max(band_prop), max(recon_err) }; %#ok<SAGROW>
    end
end

B = cell2table(rows, 'VariableNames', {'subj','subjName','axis','nTrial', ...
    'band_mocap_cm','band_est_cm','band_ratio', ...
    'recon_rms_cm','err_over_band','band_mocap_max','band_est_max','recon_rms_max'});
writetable(B, fullfile(OUT_DIR, 'R2_11_band_width.csv'));

%% ===== per-axis summary (participant level) =====
srows = {};
for d = 1:3
    k = strcmp(B.axis, axesName{d});
    srows(end+1,:) = {axesName{d}, ...
        mean(B.band_mocap_cm(k)), std(B.band_mocap_cm(k)), ...
        mean(B.band_est_cm(k)),   std(B.band_est_cm(k)), ...
        mean(B.band_ratio(k)),    std(B.band_ratio(k)), ...
        mean(B.recon_rms_cm(k)),  std(B.recon_rms_cm(k)), ...
        mean(B.err_over_band(k)), std(B.err_over_band(k)), sum(k)}; %#ok<SAGROW>
end
S = cell2table(srows, 'VariableNames', {'axis', ...
    'band_mocap_mean','band_mocap_sd','band_est_mean','band_est_sd', ...
    'ratio_mean','ratio_sd','recon_mean','recon_sd', ...
    'errOverBand_mean','errOverBand_sd','nSubj'});
writetable(S, fullfile(OUT_DIR, 'R2_11_band_width_summary.csv'));

%% ===== console =====
fprintf('\n===== [R2-11] consistency band width comparison (±%d SD, impact -1.4 s to impact) =====\n', NSIGMA);
fprintf('%-5s %18s %18s %12s %16s %14s\n', 'Axis', 'mocap band (cm)', 'est band (cm)', ...
    'ratio', 'recon RMS (cm)', 'err/band');
for r = 1:height(S)
    fprintf('%-5s %8.2f ± %-7.2f %8.2f ± %-7.2f %6.2f ± %-4.2f %7.2f ± %-6.2f %6.2f ± %-5.2f\n', ...
        S.axis{r}, S.band_mocap_mean(r), S.band_mocap_sd(r), ...
        S.band_est_mean(r), S.band_est_sd(r), ...
        S.ratio_mean(r), S.ratio_sd(r), ...
        S.recon_mean(r), S.recon_sd(r), ...
        S.errOverBand_mean(r), S.errOverBand_sd(r));
end
fprintf('\nInterpretation\n');
fprintf('  ratio > 1      : the estimated trajectory band is wider -> the agreement rate may be artificially inflated\n');
fprintf('  err/band < 1   : reconstruction error is smaller than the variability being measured (metric is valid)\n');

% participant-level paired test (are the band widths actually different)
for d = 1:3
    k = strcmp(B.axis, axesName{d});
    [~, p] = ttest(B.band_est_cm(k), B.band_mocap_cm(k));
    fprintf('  %s axis band width mocap vs est (paired, n=%d), n=%d) : p = %.4f\n', ...
        axesName{d}, sum(k), p);
end

%% ===== [optional] is the band widening common to all participants =====
%  The core of the reviewer's concern is "the band widens so the agreement rate is artificially inflated",
%  but if the widening is common to all participants the between-participant ranking is preserved, so
%  relative comparison is still valid. This is checked with rank correlation.
fprintf('\n--- [optional] between-participant rank agreement of mocap band vs estimated band ---\n');
for d = 1:3
    k = strcmp(B.axis, axesName{d});
    x = B.band_mocap_cm(k); y = B.band_est_cm(k);
    v = isfinite(x) & isfinite(y);
    if sum(v) >= 4
        [rs, ps] = corr(x(v), y(v), 'Type', 'Spearman');
        [rp, pp] = corr(x(v), y(v), 'Type', 'Pearson');
        fprintf('  %s : Spearman rho = %5.2f (p = %.4f), Pearson R = %5.2f (p = %.4f), n = %d\n', ...
            axesName{d}, rs, ps, rp, pp, sum(v));
    end
end
% is the widening ratio constant across participants (the more constant, the better the ranking is preserved)
fprintf('  between-participant coefficient of variation of the band ratio (CV): ');
for d = 1:3
    k = strcmp(B.axis, axesName{d});
    fprintf('%s %.2f  ', axesName{d}, std(B.band_ratio(k))/mean(B.band_ratio(k)));
end
fprintf('\n  -> rho is high and CV is low, the "band widens but ranking is preserved" argument holds\n');

%% ===== figure =====
figure('Color','w','Position',[100 100 1000 340]);

subplot(1,3,1); hold on; grid on;
for d = 1:3
    k = strcmp(B.axis, axesName{d});
    scatter(B.band_mocap_cm(k), B.band_est_cm(k), 40, 'filled');
end
lim = [0 max([B.band_mocap_cm; B.band_est_cm])*1.1];
plot(lim, lim, 'k--'); xlim(lim); ylim(lim);
xlabel('mocap band width (cm)'); ylabel('estimated band width (cm)');
legend(axesName, 'Location', 'best'); title('Band width: mocap vs estimated');

subplot(1,3,2); hold on; grid on;
bar(reshape(S.ratio_mean, 1, []), 'FaceColor', [0.5 0.5 0.8]);
errorbar(1:3, S.ratio_mean, S.ratio_sd, 'k', 'LineStyle', 'none');
yline(1, 'k--'); set(gca, 'XTick', 1:3, 'XTickLabel', axesName);
ylabel('band_{est} / band_{mocap}'); title('Band inflation');

subplot(1,3,3); hold on; grid on;
bar(reshape(S.errOverBand_mean, 1, []), 'FaceColor', [0.8 0.5 0.5]);
errorbar(1:3, S.errOverBand_mean, S.errOverBand_sd, 'k', 'LineStyle', 'none');
yline(1, 'k--'); set(gca, 'XTick', 1:3, 'XTickLabel', axesName);
ylabel('recon RMS / mocap band'); title('Reconstruction error vs variability');

exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_11_band_width.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_11_band_width.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_11_band_width.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_11_band_width_summary.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_11_band_width.png'));
