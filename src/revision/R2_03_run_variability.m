%% [R2-3, R3-2] R2_03_run_variability.m
%  5 independent training runs: the performance variation between them is checked.
%  Output : results/R2_03_run_variability.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(baseDir)), 'multimodal');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

RUNS = 1:5;
rows = {};
fprintf('\n===== 5 training runs: trajectory error variation (driver test, participant level, cm), cm) =====\n');
fprintf('%-8s %10s %10s %10s %10s\n', 'run', SEG{1,1}, SEG{2,1}, SEG{3,1}, SEG{4,1});

for ri = RUNS
    dir_r = fullfile(ML, sprintf('runs_0112_accgyro_400800_ori7traj%d', ri));
    if ~isfolder(dir_r), continue; end
    Dml = nan(10, 10, 3);
    for su = 1:10
        f = fullfile(dir_r, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T), 10);
        Dml(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end

    n = numel(S); subj = nan(n,1); e = nan(n,4);
    for k = 1:n
        st = S(k); subj(k) = st.subj;
        d = squeeze(Dml(st.subj, st.trial-20, :))';
        if any(~isfinite(d)), continue; end
        traj = st.imu_trajCal; dm = st.imu_trajCal(st.imp,:) - d;
        for kk = st.add:st.fin
            w = (kk - st.add)/(st.imp - st.add);
            traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
        end
        for r = 1:4
            i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
            e(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
        end
    end
    v = arrayfun(@(r) local_agg(e(:,r), subj), 1:4);
    fprintf('run %-4d %10.1f %10.1f %10.1f %10.1f\n', ri, v);
    rows(end+1,:) = [{ri}, num2cell(v)]; %#ok<SAGROW>
end

M = cell2mat(rows(:,2:5));
fprintf('\n%-8s %10.1f %10.1f %10.1f %10.1f   <- median\n', 'median', median(M,1));
fprintf('%-8s %10.1f %10.1f %10.1f %10.1f   <- range (max-min)\n', 'range', max(M,[],1)-min(M,[],1));
used = find(cell2mat(rows(:,1)) == 2);
fprintf('%-8s %10.1f %10.1f %10.1f %10.1f   <- run 2 used in the manuscript run 2\n', 'used', M(used,:));
for r = 1:4
    rk = sum(M(:,r) < M(used,r)) + 1;
    fprintf('   %-14s : run 2 has the %d-th smallest error out of 5\n', SEG{r,1}, rk);
end

writetable(cell2table(rows, 'VariableNames', ...
    {'run','Backswing','Downswing','FollowThrough','EntireSwing'}), ...
    fullfile(RES, 'R2_03_run_variability.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_03_run_variability.csv'));

function m = local_agg(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    m  = mean(sm(isfinite(sm)));
end
