%% path_length_summary_v2.m
% Robust trajectory path length summary (L = sum ||p(t+1)-p(t)||)

fprintf('\n============================================================\n');
fprintf('Trajectory path length summary (L = sum ||p(t+1)-p(t)|| )\n');
fprintf('  Entire swing: add ~ fin\n');
fprintf('  Downswing   : bst ~ imp\n');
fprintf('============================================================\n');

use_cell = exist('Mtraj_cell','var') && exist('g_cell','var');
use_arr  = exist('Mtraj_all','var')  && exist('g_all','var');

if ~use_cell && ~use_arr
    fprintf('\n[ERROR] Required inputs not found in workspace.\n');
    fprintf('Provide either:\n');
    fprintf('  (A) Mtraj_cell (cell) and g_cell (cell)\n');
    fprintf('      - Mtraj_cell{t}: [N x 3]\n');
    fprintf('      - g_cell{t}: struct with fields add, fin, bst, imp\n');
    fprintf('  or\n');
    fprintf('  (B) Mtraj_all (array) and g_all (struct array)\n');
    fprintf('      - Mtraj_all: [N x 3 x nTrial]\n');
    fprintf('      - g_all(t): struct with fields add, fin, bst, imp\n\n');
    fprintf('After variables exist, re-run this script.\n');
    return;
end

L_entire_list = [];
L_down_list   = [];
skip_reason = strings(0);

if use_cell
    nTrial = numel(Mtraj_cell);
    if numel(g_cell) ~= nTrial
        error('g_cell length (%d) does not match Mtraj_cell length (%d).', numel(g_cell), nTrial);
    end

    L_entire_list = nan(nTrial, 1);
    L_down_list   = nan(nTrial, 1);

    for t = 1:nTrial
        Mtraj = Mtraj_cell{t};
        g     = g_cell{t};

        if isempty(Mtraj) || size(Mtraj,2) ~= 3 || size(Mtraj,1) < 2
            skip_reason(end+1) = "trial "+t+": empty/invalid Mtraj";
            continue;
        end
        if ~isstruct(g) || ~isfield(g,'add') || ~isfield(g,'fin') || ~isfield(g,'bst') || ~isfield(g,'imp')
            skip_reason(end+1) = "trial "+t+": missing g fields";
            continue;
        end

        N = size(Mtraj,1);

        add_check = g.add; fin_check = g.fin; bst_check = g.bst; imp_check = g.imp;

        if ~(isnumeric(add_check) && isscalar(add_check) && isfinite(add_check)) || ...
           ~(isnumeric(fin_check) && isscalar(fin_check) && isfinite(fin_check)) || ...
           ~(isnumeric(bst_check) && isscalar(bst_check) && isfinite(bst_check)) || ...
           ~(isnumeric(imp_check) && isscalar(imp_check) && isfinite(imp_check))
            skip_reason(end+1) = "trial "+t+": g indices are not finite scalars";
            continue;
        end

        add_check = round(add_check); fin_check = round(fin_check); bst_check = round(bst_check); imp_check = round(imp_check);

        if add_check < 1, add_check = 1; end
        if fin_check < 1, fin_check = 1; end
        if bst_check < 1, bst_check = 1; end
        if imp_check < 1, imp_check = 1; end

        if add_check > N, add_check = N; end
        if fin_check > N, fin_check = N; end
        if bst_check > N, bst_check = N; end
        if imp_check > N, imp_check = N; end

        if fin_check <= add_check
            skip_reason(end+1) = "trial "+t+": fin <= add (add="+add_check+", fin="+fin_check+")";
            continue;
        end
        if imp_check <= bst_check
            skip_reason(end+1) = "trial "+t+": imp <= bst (bst="+bst_check+", imp="+imp_check+")";
            continue;
        end

        d = diff(Mtraj(add_check:fin_check, :), 1, 1);
        L_entire_list(t) = sum(sqrt(sum(d.^2, 2)), 'omitnan');

        d = diff(Mtraj(bst_check:imp_check, :), 1, 1);
        L_down_list(t) = sum(sqrt(sum(d.^2, 2)), 'omitnan');
    end
end

if use_arr
    if ndims(Mtraj_all) ~= 3 || size(Mtraj_all,2) ~= 3
        error('Mtraj_all must be [N x 3 x nTrial]. Current size: %s', mat2str(size(Mtraj_all)));
    end
    nTrial = size(Mtraj_all,3);
    if numel(g_all) ~= nTrial
        error('g_all length (%d) does not match Mtraj_all trials (%d).', numel(g_all), nTrial);
    end

    L_entire_list = nan(nTrial, 1);
    L_down_list   = nan(nTrial, 1);

    for t = 1:nTrial
        Mtraj = Mtraj_all(:,:,t);
        g     = g_all(t);

        if isempty(Mtraj) || size(Mtraj,1) < 2
            skip_reason(end+1) = "trial "+t+": empty/invalid Mtraj";
            continue;
        end
        if ~isstruct(g) || ~isfield(g,'add') || ~isfield(g,'fin') || ~isfield(g,'bst') || ~isfield(g,'imp')
            skip_reason(end+1) = "trial "+t+": missing g fields";
            continue;
        end

        N = size(Mtraj,1);
        add_check = g.add; fin_check = g.fin; bst_check = g.bst; imp_check = g.imp;

        if ~(isnumeric(add_check) && isscalar(add_check) && isfinite(add_check)) || ...
           ~(isnumeric(fin_check) && isscalar(fin_check) && isfinite(fin_check)) || ...
           ~(isnumeric(bst_check) && isscalar(bst_check) && isfinite(bst_check)) || ...
           ~(isnumeric(imp_check) && isscalar(imp_check) && isfinite(imp_check))
            skip_reason(end+1) = "trial "+t+": g indices are not finite scalars";
            continue;
        end

        add_check = round(add_check); fin_check = round(fin_check); bst_check = round(bst_check); imp_check = round(imp_check);

        if add_check < 1, add_check = 1; end
        if fin_check < 1, fin_check = 1; end
        if bst_check < 1, bst_check = 1; end
        if imp_check < 1, imp_check = 1; end

        if add_check > N, add_check = N; end
        if fin_check > N, fin_check = N; end
        if bst_check > N, bst_check = N; end
        if imp_check > N, imp_check = N; end

        if fin_check <= add_check
            skip_reason(end+1) = "trial "+t+": fin <= add (add="+add_check+", fin="+fin_check+")";
            continue;
        end
        if imp_check <= bst_check
            skip_reason(end+1) = "trial "+t+": imp <= bst (bst="+bst_check+", imp="+imp_check+")";
            continue;
        end

        d = diff(Mtraj(add_check:fin_check, :), 1, 1);
        L_entire_list(t) = sum(sqrt(sum(d.^2, 2)), 'omitnan');

        d = diff(Mtraj(bst_check:imp_check, :), 1, 1);
        L_down_list(t) = sum(sqrt(sum(d.^2, 2)), 'omitnan');
    end
end

valid_entire = ~isnan(L_entire_list);
valid_down   = ~isnan(L_down_list);

mean_entire = mean(L_entire_list(valid_entire), 'omitnan');
std_entire  = std(L_entire_list(valid_entire), 0, 'omitnan');

mean_down = mean(L_down_list(valid_down), 'omitnan');
std_down  = std(L_down_list(valid_down),  0, 'omitnan');

fprintf('\n[RESULT] L (path length) across trials\n');
fprintf('  Entire swing (add~fin):  mean = %.4f, SD = %.4f  (N=%d trials)\n', mean_entire, std_entire, sum(valid_entire));
fprintf('  Downswing  (bst~imp):    mean = %.4f, SD = %.4f  (N=%d trials)\n', mean_down, std_down, sum(valid_down));

if ~isempty(skip_reason)
    fprintf('\n[WARN] Skipped trials (%d). Showing up to first 10 reasons:\n', numel(skip_reason));
    for i = 1:min(10, numel(skip_reason))
        fprintf('  - %s\n', skip_reason(i));
    end
end

fprintf('\n[INFO] Units follow your Mtraj units (cm in -> cm out, m in -> m out).\n');
fprintf('============================================================\n');
