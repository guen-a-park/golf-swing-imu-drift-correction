%% R2_pv_report.m
%  For items where the manuscript only compares two conditions without attaching a test,
%  Output       : revision/results/R2_pvalues.csv

clc; clear; close all;
D0 = fileparts(mfilename('fullpath')); if isempty(D0), D0 = pwd; end
RES = fullfile(D0, 'results');
NL = char(10);
SEG = {'backswing','downswing','follow-through','entire swing'};
rows = {};

%% (1) trajectory error by constraint condition : D_Vision / D_Infer vs motion capture D D
L = load(fullfile(RES, '_pv1.mat'), 'err', 'eIMP', 'subj');
CN = {'D_ref','D_Vision','D_Infer'};
fprintf([NL '===== (1) trajectory error by constraint condition (cm) =====' NL]);
for r = 1:4
    a = agg(L.err(:,r,1), L.subj);
    for c = 2:3
        b = agg(L.err(:,r,c), L.subj);
        [~, p, ~, stt] = ttest(a, b);
        pr('constraint', sprintf('%s : %s vs %s %s', SEG{r}, CN{c}, CN{1}), ...
           mean(b), mean(a), stt.tstat, p);
        rows(end+1,:) = {'constraint', sprintf('%s %s vs %s', SEG{r}, CN{c}, CN{1}), ...
                         mean(b), mean(a), stt.tstat, p}; %#ok<AGROW>
    end
end

%% (2) assumed club length vs measured distance
L = load(fullfile(RES, '_pv2.mat'), 'eA', 'eB', 'iA', 'iB', 'subj');
fprintf([NL '===== (2) assumed club length vs measured distance (cm) =====' NL]);
for r = 1:4
    a = agg(L.eA(:,r), L.subj); b = agg(L.eB(:,r), L.subj);
    [~, p, ~, stt] = ttest(a, b);
    pr('measured distance', SEG{r}, mean(b), mean(a), stt.tstat, p);
    rows(end+1,:) = {'measured distance', SEG{r}, mean(b), mean(a), stt.tstat, p}; %#ok<AGROW>
end
a = agg(L.iA, L.subj); b = agg(L.iB, L.subj);
[~, p, ~, stt] = ttest(a, b);
pr('measured distance', 'impact', mean(b), mean(a), stt.tstat, p);
rows(end+1,:) = {'measured distance', 'impact', mean(b), mean(a), stt.tstat, p};

%% (3) velocity anchor : zero-velocity assumption vs measured velocity
L = load(fullfile(RES, '_pv3.mat'), 'eZ', 'eMv', 'iZ', 'iMv', 'sj');
DN = {'motion capture D','video D','inferred D D'};
fprintf([NL '===== (3) velocity anchor conditions (cm) =====' NL]);
for q = 1:size(L.eZ, 3)
    for r = 1:4
        a = agg(L.eZ(:,r,q), L.sj); b = agg(L.eMv(:,r,q), L.sj);
        [~, p, ~, stt] = ttest(a, b);
        pr('velocity anchor', sprintf('%s, %s', DN{q}, SEG{r}), mean(b), mean(a), stt.tstat, p);
        rows(end+1,:) = {'velocity anchor', sprintf('%s %s', DN{q}, SEG{r}), ...
                         mean(b), mean(a), stt.tstat, p}; %#ok<AGROW>
    end
    a = agg(L.iZ(:,q), L.sj); b = agg(L.iMv(:,q), L.sj);
    [~, p, ~, stt] = ttest(a, b);
    pr('velocity anchor', sprintf('%s, impact', DN{q}), mean(b), mean(a), stt.tstat, p);
    rows(end+1,:) = {'velocity anchor', sprintf('%s impact', DN{q}), ...
                     mean(b), mean(a), stt.tstat, p}; %#ok<AGROW>
end

%% (4) complementary filter vs angular velocity integration alone
L = load(fullfile(RES, '_pv4.mat'), 'eG', 'eF', 'iG', 'iF', 'sj');
KP = [0.1 0.5 2.0];
fprintf([NL '===== (4) complementary filter (orientation error, deg), deg) =====' NL]);
for g = 1:numel(KP)
    for r = 1:4
        a = agg(L.eG(:,r), L.sj); b = agg(L.eF(:,r,g), L.sj);
        [~, p, ~, stt] = ttest(a, b);
        pr('complementary filter', sprintf('Kp=%.1f, %s', KP(g), SEG{r}), mean(b), mean(a), stt.tstat, p);
        rows(end+1,:) = {'complementary filter', sprintf('Kp=%.1f %s', KP(g), SEG{r}), ...
                         mean(b), mean(a), stt.tstat, p}; %#ok<AGROW>
    end
end

%% (5) exclusion of gyroscope saturation trials
T = readtable(fullfile(RES, 'R2_08_ori7_trialwise.csv'));
u = unique(T.subj);
FLD = {'errIMP','impact'; 'errFollowThrough','follow-through'; ...
       'errDownswing','downswing'; 'errEntireSwing','entire swing'};
fprintf([NL '===== (5) saturation trials excluded (orientation error, deg), deg) =====' NL]);
for f = 1:size(FLD,1)
    v = T.(FLD{f,1});
    all_ = nan(numel(u),1); ex = nan(numel(u),1);
    for i = 1:numel(u)
        m = T.subj == u(i);
        all_(i) = mean(v(m), 'omitnan');
        ex(i)   = mean(v(m & T.isSaturated == 0), 'omitnan');
    end
    ok = isfinite(all_) & isfinite(ex);
    [~, p, ~, stt] = ttest(all_(ok), ex(ok));
    fprintf('  %-10s all %5.1f -> excluded %5.1f   t(%d) = %5.2f, p = %.4f  (%d participants)%s', ...
            FLD{f,2}, mean(all_(ok)), mean(ex(ok)), stt.df, stt.tstat, p, sum(ok), NL);
    rows(end+1,:) = {'saturation excluded', FLD{f,2}, mean(ex(ok)), mean(all_(ok)), stt.tstat, p}; %#ok<AGROW>
end

%% save
writetable(cell2table(rows, 'VariableNames', ...
    {'item','comparison','conditionB','conditionAA','t','p'}), ...
    fullfile(RES, 'R2_pvalues.csv'));
fprintf([NL 'saved: results/R2_pvalues.csv' NL]);

%% helpers
function m = agg(v, subj)
    su = unique(subj(isfinite(subj)));
    m = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    m = m(isfinite(m));
end
function pr(tag, name, b, a, t, p) %#ok<INUSL>
    fprintf('  %-26s %5.1f -> %5.1f   t = %5.2f, p = %.4f\n', name, a, b, t, p);
end
