%% R2_01_09_supplementary.m
%  Computes two items found missing on a full re-reading of the review.
%  ------------------------------------------------------------------------
%  (A) [R2-1] numerical example of the video-based reconstruction
%      Reviewer's original text: "A numerical example or an intermediate figure showing the ray,
%      the geometric constraint, the estimated wrist positions at address and impact,
%      and the resulting vector would substantially improve clarity."
%      -> for one trial, pixel -> camera ray -> world ray -> quadratic coefficients ->
%         two roots -> selected root -> ADD/IMP 3D positions -> D; prints the numbers at every step.
%
%  (B) [R2-9] trajectory error when saturated trials are excluded
%      Reviewer's original text: "They should also repeat the main trajectory reconstruction results
%      after excluding saturated trials."
%      -> even though we chose not to exclude them, the requested numbers must be given.
%         computed directly from the stored trajectory data (R2_03_traj_store_ori7.mat) and the saturation mask.
%
%  Output : revision/results/R2_01_worked_example.txt
%         revision/results/R2_09_traj_error_saturation_excluded.csv
%
%  2026-08-30
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
RES = fullfile(thisDir, 'results');

%% ========================================================================
%% (A) [R2-1] numerical example of the video-based reconstruction
%% ========================================================================
% representative trial: subj 3 (S03, no saturation), driver, trial 21
SUBJ = 3; CLUB = 1; TRIAL = 21;

fx = 1195.360; fy = 1190.848; cx = 732.411; cy = 531.828;
R2w_0819 = [-0.00993943 -0.04524376 -0.99892653;
             0.99994787  0.00188487 -0.01003496;
             0.00233687 -0.9989742   0.04522267];
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
club_length = [1135 1125 1100 1120 1107 1125 1087 1130 1125 1102];

fprintf('loading data...\n');
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');
g = swingData_2508(SUBJ).clubN(CLUB).trialN(TRIAL);

R2w = R2w_0819;                      % subj 1-3
Tw  = T_CAM(SUBJ,:)';
L   = club_length(SUBJ);

lines = {};
lines{end+1} = sprintf('[R2-1] Worked numerical example');
lines{end+1} = sprintf('Participant %d, driver, trial %d', SUBJ, TRIAL);
lines{end+1} = '';
lines{end+1} = sprintf('Camera intrinsics : fx = %.3f, fy = %.3f, cx = %.3f, cy = %.3f px', fx, fy, cx, cy);
lines{end+1} = sprintf('Camera position   : T_W = [%.1f, %.1f, %.1f] mm', Tw);
lines{end+1} = sprintf('Assumed club length : l = %.0f mm', L);
lines{end+1} = '';

ev = {'address', g.add; 'impact', g.imp};
P  = zeros(3,2);
for e = 1:2
    idx = double(ev{e,2});
    u = g.dl(idx,4); v = g.dl(idx,5);
    rc = [(u-cx)/fx; (v-cy)/fy; 1];
    rw = R2w * rc;
    a = dot(rw,rw); b = 2*dot(rw,Tw); c = dot(Tw,Tw) - L^2;
    D  = b^2 - 4*a*c;
    s1 = (-b + sqrt(D))/(2*a);  s2 = (-b - sqrt(D))/(2*a);
    s  = max([s1 s2]);
    Xw = Tw + s*rw;
    P(:,e) = Xw;

    lines{end+1} = sprintf('--- %s (frame %d) ---', ev{e,1}, idx);
    lines{end+1} = sprintf('  2D wrist pixel        (u, v) = (%.2f, %.2f) px', u, v);
    lines{end+1} = sprintf('  camera-frame ray      r_C = [%.5f, %.5f, %.5f]', rc);
    lines{end+1} = sprintf('  world-frame ray       r_W = [%.5f, %.5f, %.5f]', rw);
    lines{end+1} = sprintf('  quadratic coefficients a = %.5f, b = %.2f, c = %.1f', a, b, c);
    lines{end+1} = sprintf('  discriminant          b^2 - 4ac = %.3e  (two real roots)', D);
    lines{end+1} = sprintf('  roots                 s = %.2f mm and %.2f mm', s1, s2);
    lines{end+1} = sprintf('  selected root (larger, farther from camera) s = %.2f mm', s);
    lines{end+1} = sprintf('  wrist position        p_W = [%.1f, %.1f, %.1f] mm', Xw);
    lines{end+1} = sprintf('  check |p_W| = %.2f mm  (equals l = %.0f mm by construction)', norm(Xw), L);
    lines{end+1} = '';
end

Dv = P(:,2) - P(:,1);
WristU = g.marker(:,13:15); WristL = g.marker(:,7:9);
aw = (WristU + WristL)/2;
Dref = (aw(double(g.imp),:) - aw(double(g.add),:))';

lines{end+1} = sprintf('--- resulting constraint ---');
lines{end+1} = sprintf('  D_Vision = p_W,IMP - p_W,ADD = [%.1f, %.1f, %.1f] mm', Dv);
lines{end+1} = sprintf('           = [%.2f, %.2f, %.2f] cm', Dv/10);
lines{end+1} = sprintf('  motion capture reference D = [%.2f, %.2f, %.2f] cm', Dref/10);
lines{end+1} = sprintf('  difference                 = [%.2f, %.2f, %.2f] cm  (|.| = %.2f cm)', ...
    (Dv-Dref)/10, norm(Dv-Dref)/10);

fid = fopen(fullfile(RES, 'R2_01_worked_example.txt'), 'w');
fprintf(fid, '%s\n', lines{:}); fclose(fid);
fprintf('%s\n', lines{:});

%% ========================================================================
%% (B) [R2-9] trajectory error when saturated trials are excluded
%% ========================================================================
storeFile = fullfile(RES, 'R2_03_traj_store_ori7.mat');
maskFile  = fullfile(RES, 'gyro_saturation_mask.mat');
if isfile(storeFile) && isfile(maskFile)
    load(storeFile, 'R2_03_store');  S = R2_03_store;
    load(maskFile, 'satFlag');

    ML = fullfile(fileparts(fileparts(baseDir)), 'multimodal', ...
                  'runs_0112_accgyro_400800_ori7traj2');     % model adopted in the manuscript
    Dml = nan(10, 10, 3);
    for su = 1:10
        f = fullfile(ML, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T), 10);
        Dml(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end

    segs = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
            'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
    nS = numel(S);
    err = nan(nS, size(segs,1)); isSat = false(nS,1); subj = nan(nS,1);
    for k = 1:nS
        st = S(k); subj(k) = st.subj;
        isSat(k) = satFlag(st.subj).clubN(1).trialN(st.trial);
        d = squeeze(Dml(st.subj, st.trial-20, :))';
        if any(~isfinite(d)), continue; end
        traj = st.imu_trajCal;
        dm = st.imu_trajCal(st.imp,:) - d;
        for kk = st.add:st.fin
            wgt = (kk - st.add)/(st.imp - st.add);
            traj(kk,:) = st.imu_trajCal(kk,:) - wgt*dm;
        end
        for rr = 1:size(segs,1)
            i0 = st.(segs{rr,2}); i1 = st.(segs{rr,3});
            e = st.Mtraj(i0:i1,:) - traj(i0:i1,:);
            err(k,rr) = mean(vecnorm(e,2,2))/10;
        end
    end

    rows = {};
    fprintf('\n===== [R2-9] trajectory error with saturated trials excluded (driver test, cm) =====\n');
    fprintf('%-16s %20s %20s %10s\n', 'Segment', 'All trials', 'Saturation excluded', 'n excl');
    for rr = 1:size(segs,1)
        a = local_subjagg(err(:,rr), subj, true(nS,1));
        b = local_subjagg(err(:,rr), subj, ~isSat);
        fprintf('%-16s %8.2f ± %-9.2f %8.2f ± %-9.2f %10d\n', segs{rr,1}, ...
            a(1), a(2), b(1), b(2), sum(isSat));
        rows(end+1,:) = {segs{rr,1}, a(1), a(2), b(1), b(2), sum(~isSat), sum(isSat)}; %#ok<SAGROW>
    end
    T = cell2table(rows, 'VariableNames', {'segment','all_mean','all_sd', ...
        'excl_mean','excl_sd','n_kept','n_excluded'});
    writetable(T, fullfile(RES, 'R2_09_traj_error_saturation_excluded.csv'));
    fprintf('\nnumber of participants with saturation excluded: %d -> %d\n', ...
        numel(unique(subj)), numel(unique(subj(~isSat))));
    fprintf('saved: %s\n', fullfile(RES, 'R2_09_traj_error_saturation_excluded.csv'));
end


function m = local_subjagg(v, subj, keep)
    su = unique(subj(keep));
    sm = nan(numel(su),1);
    for i = 1:numel(su)
        sm(i) = mean(v(keep & subj == su(i)), 'omitnan');
    end
    sm = sm(isfinite(sm));
    m = [mean(sm) std(sm)];
end
