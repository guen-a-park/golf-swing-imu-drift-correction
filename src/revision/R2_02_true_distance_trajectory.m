%% [R2-2] R2_02_true_distance_trajectory.m
%  Quantifies, in trajectory-error units, the effect of inaccuracy in the hard geometric constraint on the reconstructed trajectory.
%  ------------------------------------------------------------------------
%  Reviewer's original wording:
%    "The authors should discuss how measurement uncertainty quantitatively affects
%     reconstruction, i.e., how plausible errors in the assumed ball to wrist distance
%     affect D_Vision and the final corrected trajectory. For example, if a subject is
%     repeatable within approximately +-2 cm in the address to impact displacement,
%     what effect does this have on the reconstructed trajectory?"
%
%  Two things are computed. It re-solves and compares rather than using derivative sensitivity, so the interpretation is intuitive.
%
%  (A) Instead of the assumed constant club length, the actual ball-wrist distance measured by motion capture at each
%      time point is used as the radius and D is recovered on the same camera ray. The per-segment error when the
%      trajectory is corrected with that D is presented side by side with the original condition.
%
%  (B) Effect of the "+-2 cm repeatability of the address-impact displacement" the reviewer cited as an example.
%      Since D is the boundary condition at impact, a variation delta in D moves the reconstructed trajectory by
%      exactly delta at impact and by 0.91*delta on the downswing average. Shown together with the measured variability.
%
%  Output : results/R2_02_true_distance_trajectory.csv
%
%  2026-08-31
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

% camera position (same as clublength_3d_1020.m, per participant)
T_CAM = [1944.24195587, -147.53836065, 1065.52214668;
         1946.26368487, -145.41073665, 1064.27866168;
         1941.23811087, -147.26589965, 1064.27767068;
         1966.736499  , -163.74432434, 1081.82660875;
         1967.165515  , -166.96142634, 1080.93007875;
         2102.062     , -175.03607234, 1081.19622275;
         2102.23739517, -178.74541095, 1095.93619444;
         2103.45266617, -187.32518295, 1074.79984244;
         2100.91714417, -175.84581295, 1072.13565044;
         2106.32278417, -184.96391595, 1074.71015144];

%% ----- materials --------------------------------------------------------------
load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1, :);

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

n = numel(S);
subj = nan(n,1); eA = nan(n,4); eB = nan(n,4);
iA = nan(n,1); iB = nan(n,1); dD = nan(n,1);

for k = 1:n
    st = S(k); subj(k) = st.subj;
    row = M(M.subj == st.subj & M.trial == st.trial, :);
    if isempty(row), continue; end
    Tw = T_CAM(st.subj, :)';

    Dvid = [row.Dvid_x, row.Dvid_y, row.Dvid_z];                 % assumed constant length
    pa = [row.addEst_x; row.addEst_y; row.addEst_z];
    pi_= [row.impEst_x; row.impEst_y; row.impEst_z];
    % re-solve on the same camera ray with only the radius replaced by the actual measured distance
    qa = local_resolve(Tw, pa, row.L_add);
    qi = local_resolve(Tw, pi_, row.L_imp);
    if any(~isfinite([qa; qi])), continue; end
    Dtrue = (qi - qa)';
    dD(k) = norm(Dtrue - Dvid)/10;

    tA = local_correct(st, Dvid);
    tB = local_correct(st, Dtrue);
    for r = 1:4
        i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
        eA(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:) - tA(i0:i1,:), 2, 2))/10;
        eB(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:) - tB(i0:i1,:), 2, 2))/10;
    end
    iA(k) = norm(st.Mtraj(st.imp,:) - tA(st.imp,:))/10;
    iB(k) = norm(st.Mtraj(st.imp,:) - tB(st.imp,:))/10;
end

%% ----- (A) results ----------------------------------------------------------
rows = {};
fprintf('\n===== [R2-2] assumed constant length vs measured actual distance (participant level, cm) =====\n');
fprintf('%-16s %20s %20s\n', 'Segment', 'assumed constant l', 'measured distances');
for r = 1:4
    a = local_agg(eA(:,r), subj); b = local_agg(eB(:,r), subj);
    fprintf('%-16s %9.1f +- %-8.1f %9.1f +- %-8.1f\n', SEG{r,1}, a(1), a(2), b(1), b(2));
    rows(end+1,:) = {SEG{r,1}, a(1), a(2), b(1), b(2)}; %#ok<SAGROW>
end
a = local_agg(iA, subj); b = local_agg(iB, subj);
fprintf('%-16s %9.1f +- %-8.1f %9.1f +- %-8.1f\n', 'Impact', a(1), a(2), b(1), b(2));
rows(end+1,:) = {'Impact', a(1), a(2), b(1), b(2)};

d = local_agg(dD, subj);
fprintf('\nchange in D itself |D_measured - D_assumed| = %.1f +- %.1f cm\n', d(1), d(2));

writetable(cell2table(rows, 'VariableNames', ...
    {'segment','assumedL_mean','assumedL_sd','trueDist_mean','trueDist_sd'}), ...
    fullfile(RES, 'R2_02_true_distance_trajectory.csv'));

%% ----- (B) effect of D repeatability on the trajectory ------------------------------
sd = nan(10,3);
for su = 1:10
    kk = M.subj == su & M.trial >= 21 & M.trial <= 30;
    sd(su,:) = std([M.Dref_x(kk) M.Dref_y(kk) M.Dref_z(kk)], 0, 1)/10;
end
mag = mean(vecnorm(sd, 2, 2));
fprintf('\n===== within-participant variability of D (motion capture, driver test) =====\n');
fprintf('SD per axis : %.1f, %.1f, %.1f cm\n', mean(sd,1));
fprintf('magnitude   : %.1f cm   (2 SD = %.1f cm)\n', mag, 2*mag);
fprintf(['\nSince D is the boundary condition at impact, a change of delta in D moves the reconstructed\n' ...
         'trajectory by exactly delta at impact and by 0.91*delta on the downswing average.\n' ...
         '  delta = 2 cm -> impact 2.0 cm, downswing 1.8 cm (12 %% of the reported downswing error 15.1 cm)\n']);

fprintf('\nsaved: %s\n', fullfile(RES, 'R2_02_true_distance_trajectory.csv'));


%% ----- local -------------------------------------------------------------
function q = local_resolve(Tw, p_ref, L)
% Recomputes the intersection with the sphere of radius L centred on the ball, along the ray from the camera toward p_ref.
% Picks the root on the same side as the original solution (the far side).
    r = (p_ref - Tw); s_ref = norm(r); r = r / s_ref;
    a = 1; b = 2*dot(r, Tw); c = dot(Tw, Tw) - L^2;
    disc = b^2 - 4*a*c;
    if disc < 0, q = [NaN; NaN; NaN]; return; end
    s = (-b + [1 -1]*sqrt(disc)) / (2*a);
    [~, j] = min(abs(s - s_ref));       % the side closer to the original root
    q = Tw + s(j)*r;
end

function traj = local_correct(st, D)
    traj = st.imu_trajCal;
    dm   = st.imu_trajCal(st.imp,:) - D;
    for kk = st.add:st.fin
        w = (kk - st.add)/(st.imp - st.add);
        traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
    end
end

function m = local_agg(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    m  = [mean(sm) std(sm)];
end
