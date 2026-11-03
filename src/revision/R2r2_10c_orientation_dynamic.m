%% [R2r2-10c] R2r2_10c_orientation_dynamic.m
%  Dynamic component of the orientation error that remains after the initial error is removed, including a time-shift test against motion capture.
%  Output : revision/results/R2r2_10c_orientation_dynamic.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI; n = numel(S);

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
KS = -4:4;
sj = nan(n,1);
eRaw = nan(n,4,numel(KS)); eAli = nan(n,4,numel(KS));
pk = nan(n,3);
rW = nan(n,1);
wPk = nan(n,1);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    add = st.add; imp = st.imp; fin = st.fin; bst = st.bst;
    N = size(st.Rinf,3);
    E0 = st.R2Lw(:,:,add) * st.Rinf(:,:,add)';
    Ra = zeros(size(st.Rinf));
    for t = 1:N, Ra(:,:,t) = E0 * st.Rinf(:,:,t); end
    for ki = 1:numel(KS)
        s = KS(ki);
        er = local_err(st.Rinf, st.R2Lw, s);
        ea = local_err(Ra, st.R2Lw, s);
        for q = 1:4
            i0 = st.(SEG{q,2}); i9 = st.(SEG{q,3});
            eRaw(k,q,ki) = mean(er(i0:i9), 'omitnan');
            eAli(k,q,ki) = mean(ea(i0:i9), 'omitnan');
        end
        if s == 0
            pk(k,:) = [ea(add) max(ea(bst:min(imp+10,fin))) ea(fin)];
            w = vecnorm(st.gyro, 2, 2);
            rW(k) = corr(ea(bst:imp), w(bst:imp), 'rows', 'complete');
            wPk(k) = max(w(bst:imp));
        end
    end
end

su = unique(sj(isfinite(sj)));
agg = @(v) mean(arrayfun(@(x) mean(v(sj == x), 'omitnan'), su), 'omitnan');
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);

rows = {};
fprintf('\norientation error (deg), mocap orientation shifted by k samples (positive = compared with later mocap samples)\n');
fprintf('%-6s %4s %9s %9s %9s %9s\n', 'condition', 'k', 'Backswing', 'Downswing', 'FollowThrough', 'EntireSwing');
for c = 1:2
    if c == 1, E = eRaw; nm = 'raw'; else, E = eAli; nm = 'aligned'; end
    for ki = 1:numel(KS)
        v = arrayfun(@(q) agg(E(:,q,ki)), 1:4);
        fprintf('%-6s %+4d %9.1f %9.1f %9.1f %9.1f\n', nm, KS(ki), v);
        rows(end+1,:) = {nm, KS(ki), v(1), v(2), v(3), v(4)};
    end
end
k0 = find(KS == 0);
for c = 1:2
    if c == 1, E = eRaw; nm = 'raw'; else, E = eAli; nm = 'aligned'; end
    dv = arrayfun(@(ki) agg(E(:,2,ki)), 1:numel(KS));
    [~, kb] = min(dv);
    [~, p] = ttest(bys(E(:,2,k0)), bys(E(:,2,kb)));
    fprintf('%s: downswing minimum at k = %+d (%.1f -> %.1f deg), p = %.4f\n', nm, KS(kb), dv(k0), dv(kb), p);
end
fprintf('\naligned heading error: address %.1f, downswing-impact maximum %.1f, finish %.1f deg\n', ...
    agg(pk(:,1)), agg(pk(:,2)), agg(pk(:,3)));
[~, p] = ttest(bys(pk(:,2)), bys(pk(:,3)));
fprintf('  maximum vs finish p = %.4g\n', p);
fprintf('correlation of the aligned heading downswing error with |w| r = %.2f (trial mean), peak |w| %.1f rad/s\n', ...
    agg(rW), agg(wPk));
fprintf('  trials with r > 0 : %.0f %%\n', 100*mean(rW > 0, 'omitnan'));

writetable(cell2table(rows, 'VariableNames', ...
    {'condition','shift','Backswing','Downswing','FollowThrough','EntireSwing'}), ...
    fullfile(RES, 'R2r2_10c_orientation_dynamic.csv'));

function e = local_err(Ra, Rb, s)
    N = size(Ra,3); e = nan(N,1);
    for t = 1:N
        u = t + s;
        if u < 1 || u > N, continue; end
        Rr = Ra(:,:,t)' * Rb(:,:,u);
        e(t) = acosd(min(1, max(-1, (trace(Rr) - 1)/2)));
    end
end
