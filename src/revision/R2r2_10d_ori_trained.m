%% [R2r2-10d] R2r2_10d_ori_trained.m
%  Trajectory error when each orientation condition is corrected with the d_IMU of the BiLSTM trained under that condition, over all seeds.
%  Output : revision/results/R2r2_10d_ori_trained.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; 'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

CND = { 7, 'ori7 manuscript (0112 traj)',  arrayfun(@(s) sprintf('runs_0112_accgyro_400800_ori7traj%d', s), 1:5, 'UniformOutput', false);
        7, 'ori7 manuscript (R2_03 calib20)', arrayfun(@(s) sprintf('runs_R2_03_calib20_seed%d', s), 1:5, 'UniformOutput', false);
        8, 'ori8 initial heading from mocap', arrayfun(@(s) sprintf('runs_R2_08_ori8_seed%d', s), 1:5, 'UniformOutput', false);
        1, 'ori1 initial 3-axis orientation from mocap',     arrayfun(@(s) sprintf('runs_R2_07_ori1_seed%d', s), 1:5, 'UniformOutput', false);
        0, 'ori0 mocap orientation over the entire swing',      arrayfun(@(s) sprintf('runs_R2_07_ori0_seed%d', s), 1:5, 'UniformOutput', false) };

R = struct();
for c = 1:size(CND,1)
    L = load(fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', CND{c,1})), 'R2_03_store'); S = L.R2_03_store;
    sj = arrayfun(@(s) s.subj, S(:)); su = unique(sj);
    runs = CND{c,3}; V = nan(numel(su), 4, numel(runs));
    fprintf('\n%s\n', CND{c,2});
    for r = 1:numel(runs)
        Dml = local_load_Dml(fullfile(ML, runs{r}));
        e = nan(numel(S), 4);
        for k = 1:numel(S)
            st = S(k); D = squeeze(Dml(st.subj, st.trial-20, :))';
            if any(~isfinite(D)), continue; end
            T = local_correct(st.imu_trajCal, D, st.add, st.imp, st.fin);
            for q = 1:4
                ii = st.(SEG{q,2}):st.(SEG{q,3});
                e(k,q) = mean(vecnorm(st.Mtraj(ii,:) - T(ii,:), 2, 2))/10;
            end
        end
        for q = 1:4, V(:,q,r) = arrayfun(@(x) mean(e(sj == x, q), 'omitnan'), su); end
        fprintf('  %-34s %s\n', runs{r}, sprintf('%6.1f', mean(V(:,:,r), 1, 'omitnan')));
    end
    Vm = mean(V, 3, 'omitnan');
    fprintf('  %-34s %s\n', 'seed mean', sprintf('%6.1f', mean(Vm, 1, 'omitnan')));
    R(c).V = V; R(c).Vm = Vm; R(c).su = su;
end

fprintf('\npaired t-test against the manuscript condition (0112 traj seed mean), participant means\n');
rows = {};
base = R(1).Vm;
for c = 1:size(CND,1)
    p = nan(1,4);
    if c > 1, for q = 1:4, [~, p(q)] = ttest(base(:,q), R(c).Vm(:,q)); end, end
    m = mean(R(c).Vm, 1, 'omitnan');
    fprintf('  %-28s %s | p %s\n', CND{c,2}, sprintf('%6.1f', m), sprintf('%7.3f', p));
    rows(end+1,:) = {CND{c,2}, m(1), m(2), m(3), m(4), p(1), p(2), p(3), p(4)};
end
writetable(cell2table(rows, 'VariableNames', {'condition','BS','DS','FT','ES','pBS','pDS','pFT','pES'}), ...
    fullfile(RES, 'R2r2_10d_ori_trained.csv'));

function D = local_load_Dml(runDir)
    D = nan(10,10,3);
    for su = 1:10
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T),10);
        D(su,1:m,:) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end

function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
