%% [R2-10] R2_10_error_structure.m
%  Determines which component of the constraint error degrades trajectory accuracy.
%  Output : revision/results/R2_10_error_structure.csv

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
ag  = [Md.Dag_x  Md.Dag_y  Md.Dag_z ];
bAg  = mean(ag  - ref, 1, 'omitnan');       % overall mean bias
bVid = mean(vid - ref, 1, 'omitnan');
fprintf([NL 'Overall mean bias (cm)   D_Vision %s   D_AGFormer %s' NL], ...
        mat2str(round(bVid/10,1)), mat2str(round(bAg/10,1)));

COND = {'Motion capture D', 'D_Vision', 'D_AGFormer', ...
        'AG const bias only', 'AG bias removed', 'Vision const bias only', 'Vision bias removed'};
DSET = {ref, vid, ag, ref + bAg, ag - bAg, ref + bVid, vid - bVid};

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'Follow-through','imp','fin'; 'Entire swing','add','fin'};
n = numel(S); nc = numel(COND);
E = nan(n, 4, nc); Eimp = nan(n, nc); subj = nan(n,1);

for k = 1:n
    st = S(k);
    r = find(Md.subj == st.subj & Md.trial == st.trial, 1);
    if isempty(r), continue; end
    subj(k) = st.subj;
    for c = 1:nc
        D = DSET{c}(r,:);
        if any(~isfinite(D)), continue; end
        T = local_correct(st.imu_trajCal, D, st.add, st.imp, st.fin);
        for q = 1:4
            i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
            E(k,q,c) = mean(vecnorm(st.Mtraj(i0:i1,:) - T(i0:i1,:), 2, 2)) / 10;
        end
        Eimp(k,c) = norm(st.Mtraj(st.imp,:) - T(st.imp,:)) / 10;
    end
end

%% Summary : per-participant mean, then between participants
u = unique(subj(isfinite(subj)));
fprintf([NL '%-18s %10s %10s %10s' NL], 'Condition', 'Impact', 'Downswing', 'Entire swing');
rows = {};
Msub = nan(numel(u), nc, 3);
for c = 1:nc
    vi = arrayfun(@(x) mean(Eimp(subj==x,c),'omitnan'), u);
    vd = arrayfun(@(x) mean(E(subj==x,2,c),'omitnan'), u);
    ve = arrayfun(@(x) mean(E(subj==x,4,c),'omitnan'), u);
    Msub(:,c,1) = vi; Msub(:,c,2) = vd; Msub(:,c,3) = ve;
    fprintf('%-18s %10.1f %10.1f %10.1f%s', COND{c}, mean(vi), mean(vd), mean(ve), NL);
    rows = [rows; {COND{c}, mean(vi), mean(vd), mean(ve)}]; %#ok<AGROW>
end

%% Paired t-test against D_Vision (participant means, n = 10)
fprintf([NL 'Versus D_Vision (paired t-test on per-participant means, n = %d)' NL], numel(u));
for c = [3 4 5 6 7]
    [~, p1] = ttest(Msub(:,2,2), Msub(:,c,2));
    [~, p2] = ttest(Msub(:,2,3), Msub(:,c,3));
    fprintf('  %-18s downswing p = %.4f   entire swing p = %.4f%s', COND{c}, p1, p2, NL);
end

T = cell2table(rows, 'VariableNames', {'condition','impact_cm','downswing_cm','entire_cm'});
writetable(T, fullfile(OUT, 'R2_10_error_structure.csv'));
fprintf([NL 'saved: results/R2_10_error_structure.csv' NL]);

function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
    end
end
