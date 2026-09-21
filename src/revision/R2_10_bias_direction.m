%% [R2-10] R2_10_bias_direction.m
%  Checks whether the constraint bias cancelling the integration drift is coincidental or structural.
%  Output : revision/results/R2_10_bias_direction.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

load(fullfile(OUT, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M  = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
ref = [Md.Dref_x Md.Dref_y Md.Dref_z];
vid = [Md.Dvid_x Md.Dvid_y Md.Dvid_z];
bVid = mean(vid - ref, 1, 'omitnan');
axName = {'X (ant-post)','Y (med-lat)','Z (vertical)'};

n = numel(S); subj = nan(n,1); drift = nan(n,3);
eRef = nan(n,1); eBias = nan(n,1);
for k = 1:n
    st = S(k);
    r = find(Md.subj == st.subj & Md.trial == st.trial, 1);
    if isempty(r) || any(~isfinite(ref(r,:))), continue; end
    subj(k) = st.subj;

    dImu = st.imu_trajCal(st.imp,:) - st.imu_trajCal(st.add,:);
    drift(k,:) = (dImu - ref(r,:)) / 10;          % cm

    T1 = local_correct(st.imu_trajCal, ref(r,:),        st.add, st.imp, st.fin);
    T2 = local_correct(st.imu_trajCal, ref(r,:) + bVid, st.add, st.imp, st.fin);
    i0 = st.bst; i1 = st.imp;
    eRef(k)  = mean(vecnorm(st.Mtraj(i0:i1,:) - T1(i0:i1,:), 2, 2)) / 10;
    eBias(k) = mean(vecnorm(st.Mtraj(i0:i1,:) - T2(i0:i1,:), 2, 2)) / 10;
end

u = unique(subj(isfinite(subj)));

%% (1) drift direction
fprintf([NL 'Uncorrected integration drift (impact, mean of participant means ± SD, cm)' NL]);
for d = 1:3
    v = arrayfun(@(x) mean(drift(subj==x,d),'omitnan'), u);
    fprintf('  %-10s %+7.1f ± %5.1f     participants with the same sign %d / %d%s', ...
            axName{d}, mean(v), std(v), max(sum(v>0), sum(v<0)), numel(u), NL);
end

%% (2) bias direction
fprintf([NL 'D~Vision~ bias (mean of participant means ± SD, cm)' NL]);
for d = 1:3
    e = (vid(:,d) - ref(:,d)) / 10;
    v = arrayfun(@(x) mean(e(Md.subj==x),'omitnan'), u);
    fprintf('  %-10s %+7.1f ± %5.1f     participants with the same sign %d / %d%s', ...
            axName{d}, mean(v), std(v), max(sum(v>0), sum(v<0)), numel(u), NL);
end

%% (3) is the bias beneficial
a = arrayfun(@(x) mean(eRef(subj==x),'omitnan'),  u);
b = arrayfun(@(x) mean(eBias(subj==x),'omitnan'), u);
[~, p, ~, st_] = ttest(a, b);
fprintf([NL 'Downswing error : motion capture D %.1f cm  vs  reference+bias %.1f cm' NL], mean(a), mean(b));
fprintf('  participants whose error the bias reduced : %d / %d%s', sum(b < a), numel(u), NL);
fprintf('  paired t-test : t = %.2f, p = %.4f%s', st_.tstat, p, NL);

T = table(u, a, b, b-a, 'VariableNames', {'subj','mocapD_cm','withBias_cm','diff_cm'});
writetable(T, fullfile(OUT, 'R2_10_bias_direction.csv'));
fprintf([NL 'saved: results/R2_10_bias_direction.csv' NL]);

function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
