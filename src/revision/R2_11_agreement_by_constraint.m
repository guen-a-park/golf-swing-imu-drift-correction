%% [R2-10 / R2-11] R2_11_agreement_by_constraint.m
%  Checks whether the consistency metric of Figure 6 changes depending on which constraint is used.
%  Output      : revision/results/R2_11_agreement_by_constraint.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

load(fullfile(OUT, 'R2_11_trajectory_store.mat'), 'R2_11_store');
M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
Mp = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);   % preferred evaluation
Mf = M(M.club == 3, :);                                   % fast

NSIGMA = 2;  WIN = [-280 0];
COND = {'D_Vision', 'D_AGFormer'};

subj = []; agrRef = []; agrEst = [];   % agrEst : [n x 2]
chk = [];

for s = 1:numel(R2_11_store)
    st = R2_11_store(s);
    if isempty(st) || isempty(st.ref) || isempty(st.ref_fast), continue; end
    su = st.subj;
    pRows = Mp(Mp.subj == su, :);  fRows = Mf(Mf.subj == su, :);
    if isempty(pRows) || isempty(fRows), continue; end

    imp = round(mean(double(st.imp)));
    idx = max(1, imp + WIN(1)) : min(size(st.ref,1), imp + WIN(2));
    refP = st.ref * 0.1;  refF = st.ref_fast * 0.1;

    fAdd = double(st.imp(1)) - (fRows.idxIMP - fRows.idxADD);
    fImp = repmat(double(st.imp(1)), height(fRows), 1);

    P = cell(1,2); F = cell(1,2);
    for c = 1:2
        P{c} = local_reapply(st.prop      * 0.1, st.add, st.imp, pRows, COND{c}, chk);
        F{c} = local_reapply(st.prop_fast * 0.1, fAdd,   fImp,   fRows, COND{c}, chk);
    end

    for c = 1:2
        mRef = mean(refP(idx,:,:), 3);   sRef = std(refP(idx,:,:), 0, 3);
        mEst = mean(P{c}(idx,:,:), 3);   sEst = std(P{c}(idx,:,:), 0, 3);
        for t = 1:size(refF,3)
            inR = zeros(1,3); inE = zeros(1,3);
            for d = 1:3
                inR(d) = mean(abs(refF(idx,d,t) - mRef(:,d)) <= NSIGMA*sRef(:,d));
                inE(d) = mean(abs(F{c}(idx,d,t) - mEst(:,d)) <= NSIGMA*sEst(:,d));
            end
            if c == 1
                subj(end+1,1)   = su;             %#ok<SAGROW>
                agrRef(end+1,1) = mean(inR)*100;  %#ok<SAGROW>
            end
            agrEst(numel(subj), c) = mean(inE)*100;
        end
    end
end

%% correlation decomposition
fprintf([NL '%d fast trials, %d participants' NL], numel(subj), numel(unique(subj)));
fprintf([NL 'condition       pooled R  between R     within R         p(within)' NL]);
rows = {};
for c = 1:2
    y = agrEst(:,c);
    Rp = corr(agrRef, y);
    u = unique(subj);
    a = arrayfun(@(x) mean(agrRef(subj==x)), u);
    b = arrayfun(@(x) mean(y(subj==x)), u);
    Rb = corr(a, b);
    [Rw, Pw] = local_within(agrRef, y, subj);
    fprintf('%-14s  %6.2f      %6.2f       %6.2f        %.4g%s', COND{c}, Rp, Rb, Rw, Pw, NL);
    rows = [rows; {COND{c}, Rp, Rb, Rw, Pw}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'constraint','R_pooled','R_between','R_within','p_within'});
writetable(T, fullfile(OUT, 'R2_11_agreement_by_constraint.csv'));
fprintf([NL 'saved: results/R2_11_agreement_by_constraint.csv' NL]);

%% helper functions
function X = local_reapply(X0, add, imp, rows, cond, ~)
    X = X0;
    n = size(X0,3);
    for t = 1:min(n, height(rows))
        a = double(add(min(t,numel(add))));
        i = double(imp(min(t,numel(imp))));
        Dold = squeeze(X0(i,:,t)) - squeeze(X0(a,:,t));
        if strcmp(cond, 'D_Vision')
            Dnew = [rows.Dvid_x(t) rows.Dvid_y(t) rows.Dvid_z(t)] / 10;
        else
            Dnew = [rows.Dag_x(t)  rows.Dag_y(t)  rows.Dag_z(t) ] / 10;
        end
        if any(~isfinite(Dnew)), continue; end
        w = zeros(size(X0,1),1);
        w(a:end) = min(1, (double(a:size(X0,1))' - a) / max(1, i - a));
        X(:,:,t) = X0(:,:,t) + w * (Dnew - Dold);
    end
end
function [Rw, Pw] = local_within(x, y, subj)
    u = unique(subj); cx = x; cy = y;
    for k = 1:numel(u)
        m = subj == u(k);
        cx(m) = cx(m) - mean(cx(m));
        cy(m) = cy(m) - mean(cy(m));
    end
    df = numel(x) - numel(u) - 1;
    Rw = sum(cx.*cy) / sqrt(sum(cx.^2)*sum(cy.^2));
    tw = Rw * sqrt(df / (1 - Rw^2));
    Pw = 2 * (1 - tcdf(abs(tw), df));
end
