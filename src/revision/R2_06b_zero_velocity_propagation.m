%% [R2-6b] R2_06b_zero_velocity_propagation.m
%  Propagation of a zero-velocity assumption violation into the trajectory error.
%  Output    : revision/results/R2_06b_zero_velocity_propagation.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M');

fs = 200; ts = 1/fs;
axesName = {'X','Y','Z'};

Msel = M(M.club == 1, :);            % driver
nT = height(Msel);

rows = {};
dxIMP = nan(nT,3); dxBS = nan(nT,3); dxDS = nan(nT,3); dxALL = nan(nT,3);
cxBS  = nan(nT,3); cxDS = nan(nT,3); cxALL = nan(nT,3); cxFIN = nan(nT,3);

for k = 1:nT
    add = Msel.idxADD(k); bst = Msel.idxBST(k);
    imp = Msel.idxIMP(k); fin = Msel.idxFIN(k);

    vmBST = [Msel.vBST_x(k), Msel.vBST_y(k), Msel.vBST_z(k)];   % mm/s
    vmFIN = [Msel.vFIN_x(k), Msel.vFIN_y(k), Msel.vFIN_z(k)];

    n = 900;
    d = zeros(n, 3);
    i1 = add:bst;
    w1 = (i1 - add)' / (bst - add);
    d(i1,:) = -w1 .* vmBST;
    i2 = bst:fin;
    w2 = (i2 - bst)' / (fin - bst);
    d(i2,:) = -vmBST + w2 .* (vmBST - vmFIN);

    dx = cumtrapz(ts, d);
    dx = dx - dx(add,:);                       % mm

    wD = zeros(n,1);
    wD(add:fin) = ((add:fin) - add)' / (imp - add);
    cx = dx - wD .* dx(imp,:);

    dxIMP(k,:) = dx(imp,:);
    dxBS(k,:)  = mean(abs(dx(add:bst,:)), 1);
    dxDS(k,:)  = mean(abs(dx(bst:imp,:)), 1);
    dxALL(k,:) = mean(abs(dx(add:fin,:)), 1);

    cxBS(k,:)  = mean(abs(cx(add:bst,:)), 1);
    cxDS(k,:)  = mean(abs(cx(bst:imp,:)), 1);
    cxALL(k,:) = mean(abs(cx(add:fin,:)), 1);
    cxFIN(k,:) = abs(cx(fin,:));
end

%% participant-level aggregation
subjList = unique(Msel.subj);
agg = @(V) local_subjagg(V, Msel.subj, subjList);

quantities = { ...
    'BeforeD_IMP',        abs(dxIMP);
    'BeforeD_Backswing',  dxBS;
    'BeforeD_Downswing',  dxDS;
    'BeforeD_EntireSwing',dxALL;
    'AfterD_Backswing',   cxBS;
    'AfterD_Downswing',   cxDS;
    'AfterD_EntireSwing', cxALL;
    'AfterD_FIN',         cxFIN};

fprintf('\n===== [R2-6b] propagation of the zero-velocity assumption violation into trajectory error (cm) =====\n');
fprintf('driver %d trials / %d subjects. participant-level mean ± SD\n', nT, numel(subjList));
fprintf('counterfactual: difference from setting the v(BST), v(FIN) targets to the motion capture measured values instead of 0\n\n');
fprintf('%-22s %14s %14s %14s %14s\n', 'Quantity', 'X', 'Y', 'Z', '|.| (norm)');
for q = 1:size(quantities,1)
    V = quantities{q,2} / 10;                       % mm -> cm
    [m, s] = agg(V);
    nrm = vecnorm(quantities{q,2}, 2, 2) / 10;
    [mn, sn] = agg(nrm);
    fprintf('%-22s %6.2f ± %-6.2f %6.2f ± %-6.2f %6.2f ± %-6.2f %6.2f ± %-6.2f\n', ...
        quantities{q,1}, m(1), s(1), m(2), s(2), m(3), s(3), mn, sn);
    rows(end+1,:) = {quantities{q,1}, m(1), s(1), m(2), s(2), m(3), s(3), mn, sn}; %#ok<SAGROW>
end

T = cell2table(rows, 'VariableNames', {'quantity', ...
    'X_mean','X_sd','Y_mean','Y_sd','Z_mean','Z_sd','norm_mean','norm_sd'});
writetable(T, fullfile(OUT_DIR, 'R2_06b_zero_velocity_propagation.csv'));

%% interpretation output
nrmIMP = vecnorm(dxIMP,2,2)/10;  [mIMP, ~] = agg(nrmIMP);
nrmDS  = vecnorm(dxDS ,2,2)/10;  [mDS , ~] = agg(nrmDS);
cnrmDS = vecnorm(cxDS ,2,2)/10;  [cDS , ~] = agg(cnrmDS);
fprintf('\n--- interpretation ---\n');
fprintf('before the D constraint correction: the zero-velocity assumption violation contributes %.2f cm to the impact displacement (downswing mean %.2f cm)\n', mIMP, mDS);
fprintf('after the D constraint correction: 0 at impact by definition (absorbed by the constraint), downswing mean reduced to %.2f cm\n', cDS);
fprintf('               -> absorption rate %.0f%%\n', 100*(1 - cDS/max(mDS,eps)));
fprintf('residual contribution %.1f%% of the reported downswing trajectory error of 15.13 cm\n', 100*cDS/15.13);

%% figure
figure('Color','w','Position',[100 100 900 330]);
subplot(1,2,1); hold on; grid on;
b = bar([T.norm_mean(1:4)'; nan(1,4)], 'grouped');
set(gca,'XTick',1,'XTickLabel',{'before D correction'});
legend({'@IMP','Backswing','Downswing','Entire'}, 'Location','best','FontSize',8);
ylabel('|\Deltax| (cm)'); title('Propagated error before D constraint');

subplot(1,2,2); hold on; grid on;
bar([T.norm_mean(5:8)'; nan(1,4)], 'grouped');
set(gca,'XTick',1,'XTickLabel',{'after D correction'});
legend({'Backswing','Downswing','Entire','@FIN'}, 'Location','best','FontSize',8);
ylabel('|\Deltax| (cm)'); title('Residual after D constraint');

exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_06b_propagation.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_06b_propagation.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_06b_zero_velocity_propagation.csv'));

%% local functions
function [m, s] = local_subjagg(V, subj, subjList)
    nS = numel(subjList);
    sm = nan(nS, size(V,2));
    for si = 1:nS
        sm(si,:) = mean(V(subj == subjList(si), :), 1, 'omitnan');
    end
    m = mean(sm, 1, 'omitnan');
    s = std(sm, 0, 1, 'omitnan');
end
