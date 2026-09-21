%% [R2-1 / memo 13] R2_13_fps_phase_error.m
%  Examines the effect of lowering the frame rate as phase-wise trajectory error, as in the manuscript, rather than as D error.
%  Output : results/R2_13_fps_phase_error.csv

clc; clear;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

F = readtable(fullfile(RES, 'R2_01_fps_downsampling.csv'));
L = load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');
S = L.R2_03_store;

FPS = unique(F.fps, 'stable');
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

rows = {};
fprintf('\n%-6s %11s %11s %11s %11s %11s %9s\n', ...
    'fps', 'Backswing', 'Downswing', 'Follow-through', 'EntireSwing', 'Impact', 'D err');
for fi = 1:numel(FPS)
    G = F(F.fps == FPS(fi), :);
    n = numel(S); e = nan(n,4); ie = nan(n,1); sj = nan(n,1); dv = nan(n,1);
    for k = 1:n
        st = S(k); sj(k) = st.subj;
        r = G(G.subj == st.subj & G.trial == st.trial, :);
        if isempty(r), continue; end
        D = [r.D_x(1) r.D_y(1) r.D_z(1)];
        dv(k) = r.errD_vs_mocap(1);

        traj = st.imu_trajCal;
        dm   = st.imu_trajCal(st.imp,:) - D;
        for kk = st.add:st.fin
            w = (kk - st.add)/(st.imp - st.add);
            traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
        end
        for r2 = 1:4
            i0 = st.(SEG{r2,2}); i1 = st.(SEG{r2,3});
            e(k,r2) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
        end
        ie(k) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:))/10;
    end
    [v, vs] = deal(nan(1,4));
    for c = 1:4, [v(c), vs(c)] = local_subj(e(:,c), sj); end
    [im, ims] = local_subj(ie, sj); dm2 = local_subj(dv, sj);
    fprintf('%-6d %11.1f %11.1f %11.1f %11.1f %11.1f %9.1f\n', FPS(fi), v, im, dm2);
    rows(end+1,:) = {FPS(fi), v(1), vs(1), v(2), vs(2), v(3), vs(3), v(4), vs(4), im, ims}; %#ok<SAGROW>
end

writetable(cell2table(rows, 'VariableNames', {'fps','Backswing','Backswing_sd','Downswing','Downswing_sd', ...
    'FollowThrough','FollowThrough_sd','EntireSwing','EntireSwing_sd','Impact','Impact_sd'}), ...
    fullfile(RES, 'R2_13_fps_phase_error.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_13_fps_phase_error.csv'));

function [m, sd] = local_subj(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; sd = NaN; else, m = mean(sm); sd = std(sm); end
end
