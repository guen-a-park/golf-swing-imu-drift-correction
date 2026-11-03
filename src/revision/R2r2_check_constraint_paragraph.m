%% [R2r2-check] R2r2_check_constraint_paragraph.m
%  Rechecks the values in the Discussion paragraph on the accuracy of the displacement constraint.
%  Output : console

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
L = load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = L.R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
SEG = {'add','bst'; 'bst','imp'; 'imp','fin'; 'add','fin'};
n = numel(S); E = nan(n,4,2); sj = nan(n,1);
for k = 1:n
    st = S(k); r = find(M.subj == st.subj & M.trial == st.trial, 1); if isempty(r), continue; end
    sj(k) = st.subj;
    Ds = {[M.Dvid_x(r) M.Dvid_y(r) M.Dvid_z(r)], [M.Dref_x(r) M.Dref_y(r) M.Dref_z(r)]};
    for c = 1:2
        T = st.imu_trajCal; dm = T(st.imp,:) - Ds{c};
        for kk = st.add:st.fin, T(kk,:) = st.imu_trajCal(kk,:) - ((kk-st.add)/(st.imp-st.add))*dm; end
        for q = 1:4
            ii = st.(SEG{q,1}):st.(SEG{q,2});
            E(k,q,c) = mean(vecnorm(st.Mtraj(ii,:) - T(ii,:), 2, 2))/10;
        end
    end
end
su = unique(sj(isfinite(sj)));
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);
nm = {'Backswing','Downswing','FollowThrough','Entire'};
for q = [2 4]
    a = bys(E(:,q,1)); b = bys(E(:,q,2)); [~, p] = ttest(a, b);
    fprintf('%-10s d_video %.2f  d_mocap %.2f  p = %.3f\n', nm{q}, mean(a), mean(b), p);
end
ref = [M.Dref_x M.Dref_y M.Dref_z]/10; vid = [M.Dvid_x M.Dvid_y M.Dvid_z]/10; s = M.subj; us = unique(s);
sdR = cell2mat(arrayfun(@(x) std(ref(s==x,:),0,1), us, 'UniformOutput', false));
sdE = cell2mat(arrayfun(@(x) std(vid(s==x,:)-ref(s==x,:),0,1), us, 'UniformOutput', false));
dev3 = arrayfun(@(x) mean(vecnorm(ref(s==x,:) - mean(ref(s==x,:),1), 2, 2)), us);
fprintf('within-participant SD of d_mocap (X Y Z) : %.2f %.2f %.2f cm, norm of the 3-axis SD %.2f cm, mean 3D deviation %.2f cm\n', ...
    mean(sdR,1), mean(vecnorm(sdR,2,2)), mean(dev3));
fprintf('within-participant SD of the d_video error (X Y Z) : %.2f %.2f %.2f cm\n', mean(sdE,1));
