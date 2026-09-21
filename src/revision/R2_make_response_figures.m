%% R2_make_response_figures.m
%  Generates the figures to attach to the point-by-point response, in the manuscript format.
%  Output: revision/results/response_figures/RespFig*.png, .svg

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
OUT = fullfile(RES, 'response_figures');
if ~isfolder(OUT), mkdir(OUT); end

%% manuscript format constants
S.font      = 'Gill Sans MT';
S.fs        = 14;
S.prop      = [128 0 32]/255;      % proposed method / main condition
S.alt       = [ 90 90 110]/255;    % comparison condition
S.ref       = [0 0 0];             % reference value
S.refFill   = 0.70*[1 1 1];
S.alphaProp = 0.18;
S.alphaRef  = 0.16;
S.lw        = 1.6;

fprintf('generating response figures in the manuscript format\n');

%% RespFig 1 — [R2-1] constraint error versus video frame rate
f = fullfile(RES, 'R2_01_fps_from_csv_summary.csv');
if isfile(f)
    T = readtable(f);
    T = sortrows(T, 'fps');
    k = T.fps < 150;                                  % 150 = baseline, so excluded

    fig = local_fig(560, 380);
    hold on;
    errorbar(T.fps(k), T.errD_mean(k), T.errD_sd(k), '-o', ...
        'Color', S.prop, 'MarkerFaceColor', S.prop, 'LineWidth', S.lw, 'MarkerSize', 6);
    yline(1.04, '--', 'Color', S.ref, 'LineWidth', 1);
    text(max(T.fps(k)), 1.04, '  \sigma_D (anteroposterior)', ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', ...
        'FontName', S.font, 'FontSize', S.fs-3);
    xlabel('Video frame rate (fps)');
    ylabel('Change in constraint |\DeltaD| (cm)');
    xlim([20 130]); set(gca, 'XTick', [30 60 90 120], 'XDir', 'reverse');
    local_style(gca, S);
    local_save(fig, OUT, 'RespFig1_frame_rate');
    fprintf('  RespFig1 (R2-1) frame rate\n');
end

%% RespFig 2 — [R2-2] actual ball-wrist distance vs assumed club length
f = fullfile(RES, 'R2_02_ball_wrist_distance.csv');
if isfile(f)
    T = readtable(f);
    n = height(T);

    fig = local_fig(760, 380);

    subplot(1,2,1); hold on;
    for i = 1:n
        plot([i i], [T.Ladd_mean_cm(i) T.Limp_mean_cm(i)], '-', ...
            'Color', 0.75*[1 1 1], 'LineWidth', 1);
    end
    h1 = plot(1:n, T.Ladd_mean_cm, 'o', 'MarkerEdgeColor', S.ref, ...
        'MarkerFaceColor', 'w', 'MarkerSize', 7, 'LineWidth', 1.2);
    h2 = plot(1:n, T.Limp_mean_cm, 'o', 'MarkerEdgeColor', S.prop, ...
        'MarkerFaceColor', S.prop, 'MarkerSize', 7);
    h3 = plot(1:n, T.clubLength_cm, '_', 'Color', S.ref, ...
        'MarkerSize', 14, 'LineWidth', 1.6);
    set(gca, 'XTick', 1:n, 'XTickLabel', T.subjName, 'XTickLabelRotation', 45);
    xlim([0.4 n+0.6]);
    ylabel('Ball-to-wrist distance (cm)');
    legend([h1 h2 h3], {'Address', 'Impact', 'Assumed club length'}, ...
        'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
    local_style(gca, S);

    subplot(1,2,2); hold on;
    d = T.IMPminusADD_mean_cm;
    bar(1:n, d, 0.6, 'FaceColor', S.prop, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
    errorbar(1:n, d, T.IMPminusADD_sd_cm, 'k', 'LineStyle', 'none', 'CapSize', 4);
    yline(mean(d), '--', 'Color', S.ref, 'LineWidth', 1);
    set(gca, 'XTick', 1:n, 'XTickLabel', T.subjName, 'XTickLabelRotation', 45);
    xlim([0.4 n+0.6]);
    ylabel('L_{impact} - L_{address} (cm)');
    local_style(gca, S);

    local_save(fig, OUT, 'RespFig2_ball_wrist_distance');
    fprintf('  RespFig2 (R2-2) ball-wrist distance\n');
end

%% RespFig 3 — [R2-6] trajectory error propagation from violating the zero-velocity assumption
f = fullfile(RES, 'R2_06b_zero_velocity_propagation.csv');
if isfile(f)
    T = readtable(f);
    segs  = {'Backswing','Downswing','EntireSwing'};
    labs  = {'Backswing','Downswing','Entire swing'};
    before = nan(1,numel(segs)); after = nan(1,numel(segs));
    beforeSD = before; afterSD = after;
    for i = 1:numel(segs)
        b = strcmp(T.quantity, ['BeforeD_' segs{i}]);
        a = strcmp(T.quantity, ['AfterD_'  segs{i}]);
        if any(b), before(i) = T.norm_mean(b); beforeSD(i) = T.norm_sd(b); end
        if any(a), after(i)  = T.norm_mean(a); afterSD(i)  = T.norm_sd(a); end
    end

    fig = local_fig(560, 380);
    hold on;
    x = 1:numel(segs);
    b1 = bar(x-0.18, before, 0.32, 'FaceColor', S.refFill, 'EdgeColor', S.ref, 'LineWidth', 1);
    b2 = bar(x+0.18, after,  0.32, 'FaceColor', S.prop,   'EdgeColor', 'none', 'FaceAlpha', 0.9);
    errorbar(x-0.18, before, beforeSD, 'k', 'LineStyle', 'none', 'CapSize', 5);
    errorbar(x+0.18, after,  afterSD,  'k', 'LineStyle', 'none', 'CapSize', 5);
    set(gca, 'XTick', x, 'XTickLabel', labs);
    ylabel('Propagated trajectory error (cm)');
    legend([b1 b2], {'Before displacement constraint', 'After displacement constraint'}, ...
        'Location', 'northeast', 'Box', 'off');
    local_style(gca, S);
    local_save(fig, OUT, 'RespFig3_zero_velocity_propagation');
    fprintf('  RespFig3 (R2-6) zero-velocity assumption propagation\n');
end

%% RespFig 4 — [R2-9] actual form of gyro saturation (sign inversion)
IMU_ROOT = fullfile(dataRoot(), 'imu');
FSR = 35.0;
CASES = {'S05','driver',10,'Non-saturated'; 'S05','driver',8,'Saturated'};
if isfolder(fullfile(IMU_ROOT, 'S05', 'driver'))
    fig = local_fig(820, 360);
    for k = 1:size(CASES,1)
        p = fullfile(IMU_ROOT, CASES{k,1}, CASES{k,2});
        ff = dir(fullfile(p,'*.h5')); [~,ix] = sort([ff.datenum]); ff = ff(ix);
        fp = fullfile(p, ff(CASES{k,3}).name);
        si = h5info(fp,'/Sensors'); id = si.Groups(1).Name;
        id = id(find(id=='/',1,'last')+1:end);
        fs = double(h5readatt(fp, ['/Sensors/' id '/Configuration'], 'Sample Rate'));
        g  = h5read(fp, ['/Sensors/' id '/Gyroscope'])';
        [~,pk] = max(max(abs(g),[],2));
        i0 = max(1,pk-round(0.08*fs)); i1 = min(size(g,1), pk+round(0.08*fs));
        t = ((i0:i1)-pk)/fs*1000;

        subplot(1,2,k); hold on;
        plot(t, g(i0:i1,1), '-', 'Color', S.prop, 'LineWidth', S.lw);
        plot(t, g(i0:i1,2), '-', 'Color', S.alt,  'LineWidth', 1.1);
        plot(t, g(i0:i1,3), '-', 'Color', S.refFill*0.8, 'LineWidth', 1.1);
        yline( FSR, '--', 'Color', S.ref, 'LineWidth', 1);
        yline(-FSR, '--', 'Color', S.ref, 'LineWidth', 1);
        text(t(end), FSR, ' +FSR ', 'VerticalAlignment','bottom', ...
            'HorizontalAlignment','right', 'FontName', S.font, 'FontSize', S.fs-3);
        ylim([-46 46]); xlim([t(1) t(end)]);
        xlabel('Time from impact (ms)');
        if k == 1
            ylabel('Angular velocity (rad s^{-1})');
            legend({'\omega_x','\omega_y','\omega_z'}, 'Location','southwest','Box','off');
        end
        title(CASES{k,4}, 'FontName', S.font, 'FontSize', S.fs, 'FontWeight','normal');
        local_style(gca, S);
    end
    local_save(fig, OUT, 'RespFig4_gyroscope_saturation');
    fprintf('  RespFig4 (R2-9) gyro saturation\n');
end

%% RespFig 5 — [R2-8] orientation error by segment before and after heading alignment
f7 = fullfile(RES, 'R2_08_ori7_phase_table_subjectlevel.csv');
f8 = fullfile(RES, 'R2_08_ori8_phase_table_subjectlevel.csv');
if isfile(f7) && isfile(f8)
    T7 = readtable(f7); T8 = readtable(f8);
    ord = {'@ADD','Backswing','Downswing','@IMP','FollowThrough','EntireSwing'};
    labs = {'Address', 'Back-\newlineswing', 'Down-\newlineswing', 'Impact', ...
            'Follow-\newlinethrough', 'Entire\newlineswing'};
    m7 = nan(1,numel(ord)); s7 = m7; m8 = m7; s8 = m7;
    for i = 1:numel(ord)
        a = strcmp(T7.segment, ord{i}); b = strcmp(T8.segment, ord{i});
        if any(a), m7(i) = T7.all_mean(a); s7(i) = T7.all_sd(a); end
        if any(b), m8(i) = T8.all_mean(b); s8(i) = T8.all_sd(b); end
    end

    fig = local_fig(760, 400);
    hold on;
    x = 1:numel(ord);
    b1 = bar(x-0.19, m7, 0.34, 'FaceColor', S.refFill, 'EdgeColor', S.ref, 'LineWidth', 1);
    b2 = bar(x+0.19, m8, 0.34, 'FaceColor', S.prop,   'EdgeColor', 'none', 'FaceAlpha', 0.9);
    errorbar(x-0.19, m7, s7, 'k', 'LineStyle','none', 'CapSize', 5);
    errorbar(x+0.19, m8, s8, 'k', 'LineStyle','none', 'CapSize', 5);
    set(gca, 'XTick', x, 'XTickLabel', labs, 'XTickLabelRotation', 0);
    ylim([0 42]); xlim([0.4 numel(ord)+0.6]);
    ylabel('Orientation error (deg)');
    legend([b1 b2], {'Magnetometer-based heading', 'Heading aligned to motion capture'}, ...
        'Location','northwest', 'Box','off');
    local_style(gca, S);
    local_save(fig, OUT, 'RespFig5_heading_alignment');
    fprintf('  RespFig5 (R2-8) heading alignment\n');
end

%% RespFig 6 — [R2-10] Bland-Altman (video-based constraint vs motion capture)
f = fullfile(RES, 'R2_common_mocap_metrics.mat');
if isfile(f)
    load(f, 'M');
    Ms = M(M.club == 1, :);
    meas = [Ms.Dref_x, Ms.Dref_y, Ms.Dref_z]/10;
    pred = [Ms.Dvid_x, Ms.Dvid_y, Ms.Dvid_z]/10;
    ok = all(isfinite([meas pred]),2);
    meas = meas(ok,:); pred = pred(ok,:); subj = Ms.subj(ok);
    axn = {'Anteroposterior','Mediolateral','Vertical'};

    fig = local_fig(980, 340);
    for d = 1:3
        subplot(1,3,d); hold on;
        mu = (meas(:,d)+pred(:,d))/2; e = pred(:,d)-meas(:,d);
        scatter(mu, e, 18, S.prop, 'filled', 'MarkerFaceAlpha', 0.45);
        yline(mean(e), '-', 'Color', S.ref, 'LineWidth', 1.4);
        yline(mean(e)+1.96*std(e), '--', 'Color', S.ref, 'LineWidth', 1);
        yline(mean(e)-1.96*std(e), '--', 'Color', S.ref, 'LineWidth', 1);
        xlabel('Mean of two methods (cm)');
        if d == 1, ylabel('Video - motion capture (cm)'); end
        title(sprintf('%s\nbias %.1f, LoA [%.1f, %.1f]', axn{d}, mean(e), ...
            mean(e)-1.96*std(e), mean(e)+1.96*std(e)), ...
            'FontName', S.font, 'FontSize', S.fs-2, 'FontWeight','normal');
        local_style(gca, S);
    end
    local_save(fig, OUT, 'RespFig6_bland_altman');
    fprintf('  RespFig6 (R2-10) Bland-Altman\n');
end

%% RespFig 7 — [R2-11] variability band width comparison
f = fullfile(RES, 'R2_11_band_width_summary.csv');
if isfile(f)
    T = readtable(f);
    labs = {'Anteroposterior','Mediolateral','Vertical'};

    fig = local_fig(700, 380);
    hold on;
    x = 1:height(T);
    b1 = bar(x-0.19, T.band_mocap_mean, 0.34, 'FaceColor', S.refFill, ...
        'EdgeColor', S.ref, 'LineWidth', 1);
    b2 = bar(x+0.19, T.band_est_mean, 0.34, 'FaceColor', S.prop, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.9);
    errorbar(x-0.19, T.band_mocap_mean, T.band_mocap_sd, 'k', 'LineStyle','none','CapSize',5);
    errorbar(x+0.19, T.band_est_mean,   T.band_est_sd,   'k', 'LineStyle','none','CapSize',5);
    for i = x
        text(i, max(T.band_est_mean(i)+T.band_est_sd(i), T.band_mocap_mean(i))+1.5, ...
            sprintf('x%.1f', T.ratio_mean(i)), 'HorizontalAlignment','center', ...
            'FontName', S.font, 'FontSize', S.fs-3);
    end
    set(gca, 'XTick', x, 'XTickLabel', labs);
    ylabel('Width of \pm2 SD band (cm)');
    legend([b1 b2], {'Motion capture', 'IMU-based reconstruction'}, ...
        'Location','northwest','Box','off');
    local_style(gca, S);
    local_save(fig, OUT, 'RespFig7_band_width');
    fprintf('  RespFig7 (R2-11) band width\n');
end

%% RespFig 8 — [R2-23] height and relative wrist displacement
f = fullfile(RES, 'R2_23_height_vs_D.csv');
if isfile(f)
    T = readtable(f);
    isPro = strcmp(string(T.group), "Professional");
    cols = {'Dx_cm','Dy_cm','Dz_cm'};
    labs = {'D_{anteroposterior}','D_{mediolateral}','D_{vertical}'};

    fig = local_fig(980, 340);
    for d = 1:3
        subplot(1,3,d); hold on;
        y = T.(cols{d});
        h1 = scatter(T.height_cm(~isPro), y(~isPro), 42, S.prop, 'filled');
        h2 = scatter(T.height_cm(isPro),  y(isPro),  42, S.ref, 'o', 'LineWidth', 1.2);
        v = isfinite(T.height_cm) & isfinite(y);
        pf = polyfit(T.height_cm(v), y(v), 1);
        xx = linspace(min(T.height_cm)-2, max(T.height_cm)+2, 10);
        plot(xx, polyval(pf, xx), '--', 'Color', 0.4*[1 1 1], 'LineWidth', 1.2);
        [r, p] = corr(T.height_cm(v), y(v));
        xlabel('Stature (cm)');
        if d == 1
            ylabel('Relative wrist displacement (cm)');
            legend([h1 h2], {'Amateur','Professional'}, 'Location','best','Box','off');
        end
        title(sprintf('%s\nR = %.2f, p = %.2f', labs{d}, r, p), ...
            'FontName', S.font, 'FontSize', S.fs-2, 'FontWeight','normal');
        local_style(gca, S);
    end
    local_save(fig, OUT, 'RespFig8_stature');
    fprintf('  RespFig8 (R2-23) height\n');
end

fprintf('\nsaved to: %s\n', OUT);

%% local functions
function fig = local_fig(w, h)
    fig = figure('Color', 'w', 'Position', [100 100 w h], ...
                 'PaperPositionMode', 'auto');
end

function local_style(ax, S)
    set(ax, 'FontName', S.font, 'FontSize', S.fs, ...
        'Box', 'off', 'TickDir', 'out', 'LineWidth', 1, ...
        'XColor', [0 0 0], 'YColor', [0 0 0], 'Color', 'w');
    grid(ax, 'off');
    set(get(ax,'XLabel'), 'FontName', S.font, 'FontSize', S.fs);
    set(get(ax,'YLabel'), 'FontName', S.font, 'FontSize', S.fs);
end

function local_save(fig, outDir, name)
    exportgraphics(fig, fullfile(outDir, [name '.png']), 'Resolution', 300);
    print(fig, fullfile(outDir, [name '.svg']), '-dsvg', '-vector');
end
