%% R2_pv_fps.m
%  tests whether the per-phase trajectory error changes significantly when the frame rate is lowered.
%  Output : revision/results/R2_pv_fps.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

F = readtable(fullfile(RES, 'R2_01_fps_downsampling.csv'));
L = load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');
S = L.R2_03_store;

FPS = unique(F.fps, 'stable');
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
SEGKR = {'backswing','downswing','follow-through','whole swing'};

n = numel(S);
E  = nan(n, 4, numel(FPS));      % [trial x segment x fps]
IE = nan(n, numel(FPS));         % impact
DV = nan(n, numel(FPS));         % error of D itself
sj = nan(n, 1);

for fi = 1:numel(FPS)
    G = F(F.fps == FPS(fi), :);
    for k = 1:n
        st = S(k); sj(k) = st.subj;
        r = G(G.subj == st.subj & G.trial == st.trial, :);
        if isempty(r), continue; end
        D = [r.D_x(1) r.D_y(1) r.D_z(1)];
        DV(k, fi) = r.errD_vs_mocap(1);

        traj = st.imu_trajCal;
        dm   = st.imu_trajCal(st.imp,:) - D;
        for kk = st.add:st.fin
            w = (kk - st.add) / (st.imp - st.add);
            traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
        end
        for r2 = 1:4
            i0 = st.(SEG{r2,2}); i1 = st.(SEG{r2,3});
            E(k, r2, fi) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2)) / 10;
        end
        IE(k, fi) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:)) / 10;
    end
end

%% paired t test against the 150 fps baseline
base = find(FPS == 150, 1);
rows = {};
fprintf('\n===== effect of lowering the frame rate (150 fps baseline, participant-level paired t test) =====\n');
for fi = 1:numel(FPS)
    if fi == base, continue; end
    fprintf('\n-- %d fps --\n', FPS(fi));
    for r2 = 1:4
        a = agg(E(:, r2, base), sj);
        b = agg(E(:, r2, fi),   sj);
        [~, p, ~, stt] = ttest(a, b);
        fprintf('  %-10s %5.1f -> %5.1f cm   t(%d) = %5.2f, p = %.3f\n', ...
                SEGKR{r2}, mean(a), mean(b), stt.df, stt.tstat, p);
        rows(end+1,:) = {FPS(fi), SEGKR{r2}, mean(a), mean(b), stt.tstat, p}; %#ok<AGROW>
    end
    a = agg(IE(:, base), sj); b = agg(IE(:, fi), sj);
    [~, p, ~, stt] = ttest(a, b);
    fprintf('  %-10s %5.1f -> %5.1f cm   t(%d) = %5.2f, p = %.3f\n', ...
            'impact', mean(a), mean(b), stt.df, stt.tstat, p);
    rows(end+1,:) = {FPS(fi), 'impact', mean(a), mean(b), stt.tstat, p}; %#ok<AGROW>

    a = agg(DV(:, base), sj); b = agg(DV(:, fi), sj);
    [~, p, ~, stt] = ttest(a, b);
    fprintf('  %-10s %5.1f -> %5.1f cm   t(%d) = %5.2f, p = %.3f\n', ...
            'D error', mean(a), mean(b), stt.df, stt.tstat, p);
    rows(end+1,:) = {FPS(fi), 'D error', mean(a), mean(b), stt.tstat, p}; %#ok<AGROW>
end

writetable(cell2table(rows, 'VariableNames', {'fps','phase','ref_150fps','this_fps','t','p'}), ...
    fullfile(RES, 'R2_pv_fps.csv'));
fprintf('\nsaved: results/R2_pv_fps.csv\n');

function m = agg(v, subj)
    su = unique(subj(isfinite(subj)));
    m = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    m = m(isfinite(m));
end
