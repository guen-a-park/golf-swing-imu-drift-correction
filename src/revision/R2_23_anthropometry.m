%% [R2-23] R2_23_anthropometry.m
%  Relation between participant stature and the relative wrist displacement D.
%  Output : revision/results/R2_23_height_vs_D.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
OUT_DIR = fullfile(thisDir, 'results');

axesName = {'X','Y','Z'};

%% height (cm)
HEIGHT_AMA = [175 170 160 165 160 181 168 176 166 166];   % S01 S02 S03 S04 S05 S06 S07 S08 S09 S10
HEIGHT_PRO = [173 176 163 176 177 168 172 190 171];       % subj 12~20
subjN_AMA  = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];

%% amateur D (motion capture, driver)
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M');
Ma = M(M.club == 1, :);
Dama = nan(10, 3); Dama_sd = nan(10, 3);
for s = 1:10
    k = Ma.subj == s;
    Dama(s,:)    = [mean(Ma.Dref_x(k)), mean(Ma.Dref_y(k)), mean(Ma.Dref_z(k))] / 10;   % cm
    Dama_sd(s,:) = [std(Ma.Dref_x(k)),  std(Ma.Dref_y(k)),  std(Ma.Dref_z(k)) ] / 10;
end

%% pro D
proFile = fullfile(fileparts(baseDir), 'GolfSwing_0424', 'data', 'swingData_IMP-3.5+1_20Hz_spline.mat');
if ~isfile(proFile)
    proFile = fullfile(baseDir, 'data', 'swingData_IMP-3.5+1_20Hz_spline.mat');
end
Dpro = nan(9, 3); Dpro_sd = nan(9, 3);
if isfile(proFile)
    P = load(proFile);
    fn = fieldnames(P); swingData = P.(fn{1});
    IMP_IDX = 700 - 1;                                    % same as draw_figure1_0223.m
    for si = 1:9
        subj = 11 + si;                                   % 12..20
        d = [];
        for trial = 1:10
            if subj == 19 && trial == 8, continue; end     % same exclusion as the original code
            s = swingData(subj).clubN(1).trialN(trial);
            if isempty(s) || ~isfield(s, 'Mwrist'), continue; end
            Mtraj = s.Mwrist - s.Mwrist(s.address, :);
            d(end+1,:) = Mtraj(IMP_IDX, :) * 100;          %#ok<SAGROW>  m -> cm
        end
        if ~isempty(d)
            Dpro(si,:)    = mean(d, 1);
            Dpro_sd(si,:) = std(d, 0, 1);
        end
    end
else
    warning('no pro data: %s  (amateurs only)', proFile);
end

%% save table
grp = [repmat("Amateur",10,1); repmat("Professional",9,1)];
H   = [HEIGHT_AMA(:); HEIGHT_PRO(:)];
Dall = [Dama; Dpro];
nameAll = [subjN_AMA(:); compose("PRO%d", (1:9)')];

Tsub = table(nameAll, grp, H, Dall(:,1), Dall(:,2), Dall(:,3), vecnorm(Dall,2,2), ...
    'VariableNames', {'subject','group','height_cm','Dx_cm','Dy_cm','Dz_cm','Dnorm_cm'});
writetable(Tsub, fullfile(OUT_DIR, 'R2_23_height_vs_D.csv'));

%% correlation analysis
groups = {'Amateur', 'Professional', 'Pooled'};
masks  = {grp == "Amateur", grp == "Professional", true(19,1)};
vars   = {'Dx','Dy','Dz','|D|'};
V      = [Dall, vecnorm(Dall, 2, 2)];

crows = {};
fprintf('\n===== [R2-23] height vs relative wrist displacement D =====\n');
for gi = 1:3
    m = masks{gi} & all(isfinite([H V]), 2);
    n = sum(m);
    fprintf('\n--- %s (n = %d) ---\n', groups{gi}, n);
    fprintf('%-6s %10s %10s %14s\n', 'var', 'R', 'p', 'slope (cm/cm)');
    for v = 1:4
        if n < 3, continue; end
        [r, p] = corr(H(m), V(m,v), 'Type', 'Pearson');
        pf = polyfit(H(m), V(m,v), 1);
        fprintf('%-6s %10.3f %10.4f %14.3f\n', vars{v}, r, p, pf(1));
        crows(end+1,:) = {groups{gi}, vars{v}, r, p, pf(1), n}; %#ok<SAGROW>
    end
end

C = cell2table(crows, 'VariableNames', {'group','variable','R','p','slope','n'});
writetable(C, fullfile(OUT_DIR, 'R2_23_correlation.csv'));

m = all(isfinite([H V]), 2);
fprintf('\n--- partial correlation after controlling for group (amateur/pro), n = %d ---\n', sum(m));
gd = double(grp(m) == "Professional");
for v = 1:4
    [r, p] = partialcorr(H(m), V(m,v), gd);
    fprintf('%-6s R = %6.3f, p = %.4f\n', vars{v}, r, p);
end

%% figures
figure('Color','w','Position',[100 100 1000 300]);
for v = 1:3
    subplot(1,3,v); hold on; grid on;
    ka = masks{1}; kp = masks{2};
    scatter(H(ka), V(ka,v), 45, [0.2 0.4 0.8], 'filled');
    scatter(H(kp), V(kp,v), 45, [0.8 0.3 0.2], 'filled');
    mm = all(isfinite([H V(:,v)]), 2);
    pf = polyfit(H(mm), V(mm,v), 1);
    xx = linspace(min(H)-2, max(H)+2, 10);
    plot(xx, polyval(pf, xx), 'k--', 'LineWidth', 1.2);
    [r, p] = corr(H(mm), V(mm,v));
    xlabel('Height (cm)'); ylabel(sprintf('D_%s (cm)', lower(axesName{v})));
    title(sprintf('%s: R = %.2f, p = %.3f', axesName{v}, r, p));
    if v == 1, legend({'Amateur','Professional'}, 'Location', 'best', 'FontSize', 8); end
end
exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_23_height.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_23_height.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_23_height_vs_D.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_23_correlation.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_23_height.png'));
