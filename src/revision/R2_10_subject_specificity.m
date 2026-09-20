%% [R2-10] R2_10_subject_specificity.m
%  Directly checks whether the constraint has to be participant-specific.
%
%  "Is a different D per participant really needed? Does correction not work with the same value for everyone?"
%  To answer that, everything else is kept identical and only the applied constraint is changed.
%
%     none            : no displacement correction
%     group mean D    : one constant for all participants and trials
%     subject mean D  : each participant's own reference mean (no trial variation)
%     motion capture D: per-trial reference value (upper bound)
%     D_Vision        : video-based
%     D_Infer         : IMU inference
%
%  The difference between group mean and participant mean is the magnitude of "why it must be participant-specific".
%  The difference between participant mean and motion capture is the magnitude of "why it must be trial-specific".
%
%  Data   : driver evaluation set, 99 trials
%  Output : revision/results/R2_10_subject_specificity.csv
%
%  2026-09-06
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

load(fullfile(OUT, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;
M  = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
Md = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
Dml = local_load_Dml(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'));

ref = [Md.Dref_x Md.Dref_y Md.Dref_z];
vid = [Md.Dvid_x Md.Dvid_y Md.Dvid_z];
gmean = mean(ref, 1, 'omitnan');                       % group mean D D
smean = nan(size(ref));                                % participant mean D D
for su = unique(Md.subj)'
    m = Md.subj == su;
    smean(m,:) = repmat(mean(ref(m,:), 1, 'omitnan'), sum(m), 1);
end
fprintf([NL 'group mean D D = (%.1f, %.1f, %.1f) cm' NL], gmean/10);
dev = vecnorm(smean - gmean, 2, 2) / 10;
fprintf('deviation of participant means from the group mean : %.1f ± %.1f cm%s', ...
        mean(dev,'omitnan'), std(dev,'omitnan'), NL);

COND = {'no constraint','group mean D','participant mean D','motion capture D D','D_Vision','D_Infer'};
SEG  = {'backswing','add','bst'; 'downswing','bst','imp'; ...
        'follow-through','imp','fin'; 'entire swing','add','fin'};
n = numel(S); nc = numel(COND);
E = nan(n,4,nc); Eimp = nan(n,nc); subj = nan(n,1);

for k = 1:n
    st = S(k);
    r = find(Md.subj == st.subj & Md.trial == st.trial, 1);
    if isempty(r) || any(~isfinite(ref(r,:))), continue; end
    Dinf = squeeze(Dml(st.subj, st.trial-20, :))';
    subj(k) = st.subj;
    DS = {[], gmean, smean(r,:), ref(r,:), vid(r,:), Dinf};
    for c = 1:nc
        if c == 1
            T = st.imu_trajCal;
        else
            if any(~isfinite(DS{c})), continue; end
            T = local_correct(st.imu_trajCal, DS{c}, st.add, st.imp, st.fin);
        end
        for q = 1:4
            i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
            E(k,q,c) = mean(vecnorm(st.Mtraj(i0:i1,:) - T(i0:i1,:), 2, 2))/10;
        end
        Eimp(k,c) = norm(st.Mtraj(st.imp,:) - T(st.imp,:))/10;
    end
end

u = unique(subj(isfinite(subj)));
fprintf([NL '%-16s %10s %10s %10s' NL], 'condition', 'impact', 'downswing', 'entire swing');
rows = {}; Msub = nan(numel(u), nc, 3);
for c = 1:nc
    vi = arrayfun(@(x) mean(Eimp(subj==x,c),'omitnan'), u);
    vd = arrayfun(@(x) mean(E(subj==x,2,c),'omitnan'), u);
    ve = arrayfun(@(x) mean(E(subj==x,4,c),'omitnan'), u);
    Msub(:,c,1)=vi; Msub(:,c,2)=vd; Msub(:,c,3)=ve;
    fprintf('%-16s %10.1f %10.1f %10.1f%s', COND{c}, mean(vi), mean(vd), mean(ve), NL);
    rows = [rows; {COND{c}, mean(vi), mean(vd), mean(ve)}]; %#ok<AGROW>
end

fprintf([NL 'paired t-test (per-participant means, n = %d), n = %d)' NL], numel(u));
PAIR = {2,3,'group mean vs participant mean'; 3,4,'participant mean vs motion capture'; ...
        2,6,'group mean vs D_Infer'; 6,4,'D_Infer vs motion capture'};
for i = 1:size(PAIR,1)
    a = Msub(:,PAIR{i,1},2); b = Msub(:,PAIR{i,2},2);
    [~,p1] = ttest(a,b);
    a2 = Msub(:,PAIR{i,1},3); b2 = Msub(:,PAIR{i,2},3);
    [~,p2] = ttest(a2,b2);
    fprintf('  %-26s downswing %5.1f vs %5.1f (p = %.4f)   entire %5.1f vs %5.1f (p = %.4f)%s', ...
            PAIR{i,3}, mean(a), mean(b), p1, mean(a2), mean(b2), p2, NL);
end

T = cell2table(rows, 'VariableNames', {'condition','impact_cm','downswing_cm','entire_cm'});
writetable(T, fullfile(OUT, 'R2_10_subject_specificity.csv'));
fprintf([NL 'saved: results/R2_10_subject_specificity.csv' NL]);

function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
function D = local_load_Dml(runDir)
    D = nan(10,10,3);
    for su = 1:10
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); m = min(height(T),10);
        D(su,1:m,:) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end
