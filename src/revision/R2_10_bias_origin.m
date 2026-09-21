%% [R2-10] R2_10_bias_origin.m
%  distinguishes whether the systematic bias on the fore-aft axis comes from the club length assumption or from the 2D wrist detection.
%  Output : revision/results/R2_10_bias_origin.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
NL  = char(10);

T_CAM = [2103.45266617, -187.32518295, 1074.79984244];   % representative value, overwritten below
run_cam = fullfile(thisDir, 'R2_02_true_distance_trajectory.m');
txt = fileread(run_cam);
blk = regexp(txt, 'T_CAM\s*=\s*\[(.*?)\];', 'tokens', 'once');
T_CAM = str2num(['[' blk{1} ']']); %#ok<ST2NM>

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

n = height(M);
Dvid = nan(n,3); Dtru = nan(n,3); Dref = nan(n,3); subj = nan(n,1);
for k = 1:n
    row = M(k,:);
    Tw = T_CAM(row.subj, :)';
    pa = [row.addEst_x; row.addEst_y; row.addEst_z];
    pi_= [row.impEst_x; row.impEst_y; row.impEst_z];
    qa = local_resolve(Tw, pa, row.L_add);
    qi = local_resolve(Tw, pi_, row.L_imp);
    if any(~isfinite([qa; qi])), continue; end
    subj(k) = row.subj;
    Dvid(k,:) = [row.Dvid_x, row.Dvid_y, row.Dvid_z] / 10;
    Dtru(k,:) = (qi - qa)' / 10;
    Dref(k,:) = [row.Dref_x, row.Dref_y, row.Dref_z] / 10;
end
ok = isfinite(subj) & all(isfinite([Dvid Dtru Dref]), 2);
Dvid = Dvid(ok,:); Dtru = Dtru(ok,:); Dref = Dref(ok,:); s = subj(ok);
u = unique(s);
axName = {'X (fore-aft)','Y (left-right)','Z (up-down)'};

fprintf([NL '%d trials, %d participants' NL], numel(s), numel(u));
fprintf([NL '%-10s %22s %22s' NL], 'axis', 'assumed club length', 'measured distance');
fprintf('%-10s %10s %11s %10s %11s%s', '', 'bias', 'sign match', 'bias', 'sign match', NL);
rows = {};
for d = 1:3
    e1 = Dvid(:,d) - Dref(:,d);
    e2 = Dtru(:,d) - Dref(:,d);
    b1 = arrayfun(@(x) mean(e1(s==x)), u);
    b2 = arrayfun(@(x) mean(e2(s==x)), u);
    n1 = max(sum(b1>0), sum(b1<0));  n2 = max(sum(b2>0), sum(b2<0));
    fprintf('%-10s %+9.1f %10s %+10.1f %10s%s', axName{d}, mean(b1), ...
            sprintf('%d/%d', n1, numel(u)), mean(b2), sprintf('%d/%d', n2, numel(u)), NL);
    rows = [rows; {axName{d}, mean(b1), n1, mean(b2), n2}]; %#ok<AGROW>
end
r1 = mean(vecnorm(Dvid - Dref, 2, 2));
r2 = mean(vecnorm(Dtru - Dref, 2, 2));
fprintf([NL '3D error : assumed %.1f cm -> measured %.1f cm' NL], r1, r2);

T = cell2table(rows, 'VariableNames', {'axis','bias_assumed','sign_assumed', ...
                                       'bias_measured','sign_measured'});
writetable(T, fullfile(RES, 'R2_10_bias_origin.csv'));
fprintf([NL 'saved: results/R2_10_bias_origin.csv' NL]);

function q = local_resolve(Tw, p_ref, L)
    r = (p_ref - Tw); s_ref = norm(r); r = r / s_ref;
    a = 1; b = 2*dot(r, Tw); c = dot(Tw, Tw) - L^2;
    disc = b^2 - 4*a*c;
    if disc < 0, q = [NaN; NaN; NaN]; return; end
    s = (-b + [1 -1]*sqrt(disc)) / (2*a);
    [~, j] = min(abs(s - s_ref));
    q = Tw + s(j)*r;
end
