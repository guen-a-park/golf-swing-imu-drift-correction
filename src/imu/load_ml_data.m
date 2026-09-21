function [ml_est, ml_traj_est] = load_ml_data(mldataDir, clubs_ml, nRows_ml, nCols_ml, nTrials, nSubj_ml, subj_list)

    if isempty(subj_list)
        subj_list = 1:nSubj_ml;
    end
    
    ml_est = struct();
    for c = 1:numel(clubs_ml)
        ml_est.(clubs_ml{c}) = nan(nRows_ml, nCols_ml, nSubj_ml);
    end
    
    ml_traj_est = struct();
    for c = 1:numel(clubs_ml)
        ml_traj_est.(clubs_ml{c}) = cell(nTrials, nSubj_ml);
    end
    
    for subj = subj_list
        for club = 1  % driver only
            fname = sprintf('subj%d_%s_test_est.csv', subj, clubs_ml{club});
            fpath = fullfile(mldataDir, fname);
            if ~isfile(fpath)
                warning('Missing file: %s', fpath);
                continue
            end
            
            fname_traj = sprintf('subj%d_%s_test_traj_est.csv', subj, clubs_ml{club});
            fpath_traj = fullfile(mldataDir, fname_traj);
            
            T = readtable(fpath);
            if all(ismember({'pred_x','pred_y','pred_z'}, T.Properties.VariableNames))
                M = T{:, {'pred_x','pred_y','pred_z'}};
            else
                M = T{:, 1:3};
            end
            
            m = min(size(M,1), nRows_ml);
            ml_est.(clubs_ml{club})(1:m, :, subj) = M(1:m, :);
            
            if isfile(fpath_traj)
                T_traj = readtable(fpath_traj);
                unique_trials = unique(T_traj.trial_idx);
                
                for i = 1:numel(unique_trials)
                    trial_traj = unique_trials(i);
                    idx = T_traj.trial_idx == trial_traj;
                    pred_data = [T_traj.pred_x(idx), T_traj.pred_y(idx), T_traj.pred_z(idx)];
                    ml_traj_est.(clubs_ml{club}){trial_traj+1, subj} = pred_data;
                end
            end
        end
    end
end
