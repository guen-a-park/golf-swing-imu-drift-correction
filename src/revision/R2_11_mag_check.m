%% [R2-11] R2_11_mag_check.m
%  Checks whether the magnetometer in the fast swing is really unusable.
%  Output : revision/results/R2_11_mag_check.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ROOT = fileparts(thisDir);
NL = char(10);

load(fullfile(ROOT, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');
S = swingData_2508;

CLUB = [1 3];  CN = {'driver (preferred)', 'fast'};
rows = {};
for ci = 1:2
    c = CLUB(ci);
    magN = []; horN = []; dYaw = []; sj = [];
    for su = 1:numel(S)
        T = S(su).clubN(c).trialN;
        for t = 1:numel(T)
            g = T(t);
            if isempty(g.apdm) || ~isfinite(g.add) || g.add < 1, continue; end
            a = g.apdm(g.add, 1:3);  m = g.apdm(g.add, 7:9);
            if any(~isfinite([a m])), continue; end

            an = a / norm(a);
            phi   = atan2(an(2), an(3));
            theta = atan2(-an(1), sqrt(an(2)^2 + an(3)^2));
            mxh = m(1)*cos(theta) + m(2)*sin(phi)*sin(theta) + m(3)*cos(phi)*sin(theta);
            myh = m(2)*cos(phi) - m(3)*sin(phi);

            R = reshape(g.marker(g.add, 1:9), 3, 3);
            yawM = rad2deg(atan2(R(2,1), R(1,1)));
            yawI = 191.53 - rad2deg(atan2(myh, mxh));
            d = mod(yawI - yawM + 180, 360) - 180;

            magN(end+1,1) = norm(m);              %#ok<SAGROW>
            horN(end+1,1) = sqrt(mxh^2 + myh^2);  %#ok<SAGROW>
            dYaw(end+1,1) = d;                    %#ok<SAGROW>
            sj(end+1,1)   = su;                   %#ok<SAGROW>
        end
    end
    u = unique(sj);
    a1 = arrayfun(@(x) mean(magN(sj==x)), u);
    a2 = arrayfun(@(x) mean(horN(sj==x)), u);
    a3 = arrayfun(@(x) mean(dYaw(sj==x)), u);
    a4 = arrayfun(@(x) std(dYaw(sj==x)),  u);
    fprintf([NL '===== %s (%d trials, %d participants) =====' NL], CN{ci}, numel(sj), numel(u));
    fprintf('  Magnetometer magnitude      %6.2f ± %5.2f%s', mean(a1), std(a1), NL);
    fprintf('  Horizontal component        %6.2f ± %5.2f%s', mean(a2), std(a2), NL);
    fprintf('  Diff. from marker yaw  %+6.1f ± %5.1f deg   within-participant SD %5.1f deg%s', ...
            mean(a3), std(a3), mean(a4), NL);
    rows = [rows; {CN{ci}, mean(a1), mean(a2), mean(a3), std(a3), mean(a4)}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'condition','mag_norm','horiz_norm', ...
    'dYaw_mean','dYaw_between_sd','dYaw_within_sd'});
writetable(T, fullfile(OUT, 'R2_11_mag_check.csv'));
fprintf([NL 'saved: results/R2_11_mag_check.csv' NL]);
