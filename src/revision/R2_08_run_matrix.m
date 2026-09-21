%% [R2-8] R2_08_run_matrix.m
%  Places the per-seed results of the three training families side by side, one to one.
%  Output : results/R2_08_run_matrix.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(baseDir)), 'multimodal');

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

FAM = { 'ori7traj',            'runs_0112_accgyro_400800_ori7traj%d',  7;
        'R2_03_calib20_seed',  'runs_R2_03_calib20_seed%d',            7;
        'R2_08_ori8_seed',     'runs_R2_08_ori8_seed%d',               8;
        'R2_07_ori1_seed',     'runs_R2_07_ori1_seed%d',               1;
        'R2_07_ori0_seed',     'runs_R2_07_ori0_seed%d',               0 };

store = struct();
for o = [0 1 7 8]
    f = fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', o));
    if isfile(f), t = load(f, 'R2_03_store'); store.(sprintf('o%d', o)) = t.R2_03_store; end
end

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

rows = {};
fprintf('\n%-22s %6s %10s %10s %10s %10s\n', 'family', 'seed', 'D err(cm)', 'Downswing', 'EntireSwing', 'Impact');
for fi = 1:size(FAM,1)
    for s = 1:5
        d = fullfile(ML, sprintf(FAM{fi,2}, s));
        if ~isfolder(d), continue; end
        Dml = nan(10,10,3);
        for su = 1:10
            f = fullfile(d, sprintf('subj%d_driver_test_est.csv', su));
            if ~isfile(f), continue; end
            T = readtable(f); m = min(height(T),10);
            Dml(su,1:m,:) = [T.pred_x(1:m) T.pred_y(1:m) T.pred_z(1:m)];
        end

        de = [];
        for k = 1:height(M)
            v = squeeze(Dml(M.subj(k), M.trial(k)-20, :))';
            if any(~isfinite(v)), continue; end
            de(end+1,:) = [M.subj(k) norm(v - [M.Dvid_x(k) M.Dvid_y(k) M.Dvid_z(k)])/10]; %#ok<AGROW>
        end
        Dcm = local_subj(de(:,2), de(:,1));

        key = sprintf('o%d', FAM{fi,3});
        seg = nan(1,4); impE = NaN;
        if isfield(store, key)
            S = store.(key); n = numel(S);
            e = nan(n,4); ie = nan(n,1); sj = nan(n,1);
            for k = 1:n
                st = S(k); sj(k) = st.subj;
                v = squeeze(Dml(st.subj, st.trial-20, :))';
                if any(~isfinite(v)), continue; end
                traj = st.imu_trajCal; dm = st.imu_trajCal(st.imp,:) - v;
                for kk = st.add:st.fin
                    w = (kk-st.add)/(st.imp-st.add);
                    traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
                end
                for r = 1:4
                    i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
                    e(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:)-traj(i0:i1,:),2,2))/10;
                end
                ie(k) = norm(st.Mtraj(st.imp,:)-traj(st.imp,:))/10;
            end
            for r = 1:4, seg(r) = local_subj(e(:,r), sj); end
            impE = local_subj(ie, sj);
        end
        fprintf('%-22s %6d %10.1f %10.1f %10.1f %10.1f\n', FAM{fi,1}, s, Dcm, seg(2), seg(4), impE);
        rows(end+1,:) = {FAM{fi,1}, s, Dcm, seg(1), seg(2), seg(3), seg(4), impE}; %#ok<SAGROW>
    end
    fprintf('\n');
end

writetable(cell2table(rows, 'VariableNames', ...
    {'family','seed','D_err_cm','Backswing','Downswing','FollowThrough','EntireSwing','Impact'}), ...
    fullfile(RES, 'R2_08_run_matrix.csv'));
fprintf('saved: %s\n', fullfile(RES, 'R2_08_run_matrix.csv'));

function m = local_subj(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
