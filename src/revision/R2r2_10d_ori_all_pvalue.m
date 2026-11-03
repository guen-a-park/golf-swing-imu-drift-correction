%% [R2r2-10d] R2r2_10d_ori_all_pvalue.m
%  R2r2_10d_ori0_pvalue.m extended to all four orientation conditions.
%  Output : revision/results/R2r2_10d_ori_all_pvalue.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
NAMES = [SEG(:,1)' {'Impact'}];

rows = {};
for mode = 2
    OR = [7 8 1 0]; P = cell(1,4);
    for oi = 1:4
        ori = OR(oi);
        L = load(fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', ori)), 'R2_03_store');
        P{oi} = local_subjerr(L.R2_03_store, M, mode, SEG);
    end
    for oj = 2:4
        su = intersect(P{1}.subj, P{oj}.subj);
        for c = 1:5
            a = P{1}.v(ismember(P{1}.subj, su), c);
            b = P{oj}.v(ismember(P{oj}.subj, su), c);
            [~, p] = ttest(a, b);
            rows(end+1,:) = {OR(oj), NAMES{c}, mean(a), mean(b), mean(b-a), p, numel(su)};
            fprintf('ori7 vs ori%d %-14s %5.1f -> %5.1f  diff %+5.1f  p = %.3f (n=%d)\n', ...
                OR(oj), NAMES{c}, mean(a), mean(b), mean(b-a), p, numel(su));
        end
    end
end
writetable(cell2table(rows, 'VariableNames', ...
    {'ori','segment','ori7','oriX','diff','p','nSubj'}), ...
    fullfile(RES, 'R2r2_10d_ori_all_pvalue.csv'));

function out = local_subjerr(S, M, mode, SEG)
    n = numel(S); e = nan(n,5); sj = nan(n,1);
    for k = 1:n
        st = S(k); sj(k) = st.subj; traj = st.imu_trajCal;
        if mode == 2
            r = M(M.subj == st.subj & M.trial == st.trial, :);
            if isempty(r), continue; end
            D  = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
            dm = st.imu_trajCal(st.imp,:) - D;
            for kk = st.add:st.fin
                w = (kk - st.add)/(st.imp - st.add);
                traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
            end
        end
        for r2 = 1:4
            i0 = st.(SEG{r2,2}); i1 = st.(SEG{r2,3});
            e(k,r2) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
        end
        e(k,5) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:))/10;
    end
    su = unique(sj(isfinite(sj)));
    v = nan(numel(su),5);
    for i = 1:numel(su), v(i,:) = mean(e(sj == su(i),:), 1, 'omitnan'); end
    out.subj = su; out.v = v;
end
