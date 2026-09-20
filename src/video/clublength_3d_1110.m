clc; clear; close all;

% ========= common parameters =========
load swingData_2508.mat

fx = 1195.360;  fy = 1190.848;
cx = 732.411;   cy = 531.828;

R2w_0819 = [-0.00993943 -0.04524376 -0.99892653;  0.99994787  0.00188487 -0.01003496;  0.00233687 -0.99897420  0.04522267];
R2w_0821 = [-0.00688193 -0.04392766 -0.99901101;  0.99992209  0.01010223 -0.00733241;  0.01041433 -0.99898364  0.04385471];
R2w_0822 = [ 0.00180867 -0.04664263 -0.99891000;  0.99989627  0.01435758  0.00114005;  0.01428876 -0.99880845  0.04666376];

% camera center Tw seen in the world frame (6 values per row: club 1 used here)
T = [1944.24195587, -147.53836065, 1065.52214668, 1988.64350687,  74.47982735, 1112.23512068;
     1946.26368487, -145.41073665, 1064.27866168, 1994.22126587,  81.45108035, 1111.14594468;
     1941.23811087, -147.26589965, 1064.27767068, 2038.02827187,  89.00796435, 1111.81709868;
     1966.73649900, -163.74432434, 1081.82660875, 2065.96068100,  72.87786766, 1128.88531375;
     1967.16551500, -166.96142634, 1080.93007875, 2066.12956600,  78.63897666, 1128.51837375;
     2102.06200000, -175.03607234, 1081.19622275, 2146.70482200,  81.41601466, 1128.71147375;
     2102.23739517, -178.74541095, 1095.93619444, 2101.42642117,  54.29340805, 1122.86608444;
     2103.45266617, -187.32518295, 1074.79984244, 2200.30862417,  62.93507005, 1123.65457044;
     2100.91714417, -175.84581295, 1072.13565044, 2200.96078417,  52.08002905, 1121.78629644;
     2106.32278417, -184.96391595, 1074.71015144, 2171.27706817,  62.53522905, 1123.21138744];

% radius (estimated wrist-ball distance) [mm]
club_length      = [1135,1125,1100,1120,1107,1125,1087,1130,1125,1102];
club_length_iron = [ 954, 922, 910, 935, 907, 932, 922, 927, 918, 912];

% ========= height (ground) prior options =========
USE_HEIGHT_PRIOR = true;     % on/off
HEIGHT.mode      = 'band';   % 'band' | 'project'  (soft recommended first)
% HEIGHT.band_mm   = 60;       % allowed band (±) [mm]
HEIGHT.band_mm   = 30;       % allowed band (±) [mm]
HEIGHT.n         = [0;0;1];  % plane normal (assumes world z-up)



% ========= diagnostic parameters =========
eps_px   = 1.0;
sigma_px = 0.5;
N_mc     = 200;

diag_tbl = [];
pca_tbl  = [];

for subj = 1:10
% for subj = 5
    for club = 1
        Xs = [];

        for trial = 1:30
            if subj==1 && club==2 && trial==1,  continue; end
            if subj==5 && club==3 && trial==5,  continue; end
            if club==3 && trial>10,             continue; end

            g = swingData_2508(subj).clubN(club).trialN(trial);

            WristU = g.marker(:,13:15); % left wrist inner
            WristL = g.marker(:,7:9); % left wrist outer % i.e. front
            abs_wrist = (WristU+WristL)./2;

            % target height h(mm): if motion capture is available, using its z is best.
            % a default value is used here (adjust manually if needed)
            HEIGHT.h_add = abs_wrist(g.add,3);      % approximate wrist height at address
            HEIGHT.h_imp = abs_wrist(g.imp,3);      % approximate wrist height at impact


            phases = {'add','imp'};   % process only these frames
            for zi = 1:numel(phases)
                phase = phases{zi};
                point = g.(phase);
                pixel_coords = g.dl(point,4:5);

                % select R per date
                if any(subj==[1 2 3]),       R2w = R2w_0819;
                elseif any(subj==[4 5 6]),   R2w = R2w_0821;
                else                         R2w = R2w_0822;
                end

                % camera center Tw (assumes a single camera: uses the club==1 columns)
                if club==3,  Tw = T(subj,1:3)';
                else         Tw = T(subj,(3*club-2):3*club)';    % ★ use a single set if possible
                end

                % radius L
                if club==1 || club==3,  L = club_length(subj);
                else                    L = club_length_iron(subj);
                end

                % ----- pixel → camera ray -----
                u = pixel_coords(1); v = pixel_coords(2);
                rc = [(u - cx)/fx; (v - cy)/fy; 1];
                rw = R2w * rc;

                % ----- ray-sphere intersection (s>0) -----
                a = dot(rw,rw); b = 2*dot(rw,Tw); c = dot(Tw,Tw) - L^2;
                s_roots = roots([a b c]);
                s_real  = real(s_roots(abs(imag(s_roots))<1e-9));
                s_pos   = s_real(s_real>0);

                if isempty(s_pos)
                    X_w = [0;0;0]; valid = false; sel_mode = "none";
                else
                    % default: the larger root
                    s_sel = max(s_pos);
                    X_w   = Tw + s_sel*rw;
                    sel_mode = "max";

                    if USE_HEIGHT_PRIOR && numel(s_pos)>=1
                        % compute the candidates
                        C = zeros(3, numel(s_pos));
                        for k=1:numel(s_pos), C(:,k) = Tw + s_pos(k)*rw; end

                        % target height
                        h = HEIGHT.h_add; if strcmpi(phase,'imp'), h = HEIGHT.h_imp; end

                        if strcmpi(HEIGHT.mode,'band')
                            % prefer within the band, then minimum residual
                            dz = abs(C(3,:) - h);
                            inb = dz <= HEIGHT.band_mm;
                            if any(inb)
                                [~,ix] = min(dz(inb)); idx = find(inb); idx = idx(ix);
                            else
                                [~,idx] = min(dz);
                            end
                            s_sel = s_pos(idx); X_w = C(:,idx); sel_mode = "band";
                        elseif strcmpi(HEIGHT.mode,'project')
                            % ray-plane intersection → orthogonal projection onto the plane∩sphere circle
                            n = HEIGHT.n;
                            denom = n.'*rw;
                            if abs(denom) > 1e-9
                                s_plane = (h - n.'*Tw)/denom;
                                P = Tw + s_plane*rw;    % intersection on the plane
                                c0 = n*h;
                                Lc = sqrt(max(L^2 - h^2, 0));
                                vP = P - c0; vn = norm(vP);
                                if vn > 1e-9
                                    X_w = c0 + (Lc/vn)*vP;
                                    % s_sel is recomputed for reporting (ray parameter)
                                    s_sel = ((X_w - Tw).'/rw) * (norm(rw)^2 / (rw.'*rw)); % least-squares matching
                                    sel_mode = "project";
                                end
                            end
                        end
                    end
                    valid = true;
                end

                % store/accumulate (for PCA)
                if valid && all(isfinite(X_w)), Xs = [Xs; X_w.']; end
                swingData_2508(subj).clubN(club).trialN(trial).([phase '_est']) = X_w.';

                % ===== diagnostics =====
                Delta      = b^2 - 4*a*c;
                Delta_norm = Delta / (b^2 + 4*abs(a*c) + eps);
                root_gap_mm = 0;
                if numel(s_pos)==2, root_gap_mm = abs(s_pos(1)-s_pos(2)) * norm(rw); end

                % Jacobian cond(J)
                u1 = u + eps_px; rc1 = [(u1 - cx)/fx; (v - cy)/fy; 1]; rw1 = R2w*rc1;
                a1=dot(rw1,rw1); b1=2*dot(rw1,Tw); c1=dot(Tw,Tw)-L^2;
                s1 = roots([a1 b1 c1]); s1=real(s1(abs(imag(s1))<1e-9)); s1=s1(s1>0);
                Xu1 = Tw + (isempty(s1)*s_sel + (~isempty(s1))*max(s1)) * rw1;

                u2 = u - eps_px; rc2 = [(u2 - cx)/fx; (v - cy)/fy; 1]; rw2 = R2w*rc2;
                a2=dot(rw2,rw2); b2=2*dot(rw2,Tw); c2=dot(Tw,Tw)-L^2;
                s2 = roots([a2 b2 c2]); s2=real(s2(abs(imag(s2))<1e-9)); s2=s2(s2>0);
                Xu2 = Tw + (isempty(s2)*s_sel + (~isempty(s2))*max(s2)) * rw2;

                dXu = (Xu1 - Xu2) / (2*eps_px);

                v1 = v + eps_px; rc1 = [(u - cx)/fx; (v1 - cy)/fy; 1]; rw1 = R2w*rc1;
                a1=dot(rw1,rw1); b1=2*dot(rw1,Tw); c1=dot(Tw,Tw)-L^2;
                s1 = roots([a1 b1 c1]); s1=real(s1(abs(imag(s1))<1e-9)); s1=s1(s1>0);
                Xv1 = Tw + (isempty(s1)*s_sel + (~isempty(s1))*max(s1)) * rw1;

                v2 = v - eps_px; rc2 = [(u - cx)/fx; (v2 - cy)/fy; 1]; rw2 = R2w*rc2;
                a2=dot(rw2,rw2); b2=2*dot(rw2,Tw); c2=dot(Tw,Tw)-L^2;
                s2 = roots([a2 b2 c2]); s2=real(s2(abs(imag(s2))<1e-9)); s2=s2(s2>0);
                Xv2 = Tw + (isempty(s2)*s_sel + (~isempty(s2))*max(s2)) * rw2;

                dXv = (Xv1 - Xv2) / (2*eps_px);

                J = [dXu, dXv]; sv = svd(J); if numel(sv)<2, sv=[sv;eps]; end
                condJ = sv(1)/sv(2);

                % Monte Carlo (σ=0.5 px)
                Xmc = zeros(N_mc,3);
                for i_mc = 1:N_mc
                    du = sigma_px*randn; dv = sigma_px*randn;
                    rc_mc = [((u+du)-cx)/fx; ((v+dv)-cy)/fy; 1];
                    rw_mc = R2w*rc_mc;
                    a_mc=dot(rw_mc,rw_mc); b_mc=2*dot(rw_mc,Tw); c_mc=dot(Tw,Tw)-L^2;
                    s_mc = roots([a_mc b_mc c_mc]); s_mc=real(s_mc(abs(imag(s_mc))<1e-9)); s_mc=s_mc(s_mc>0);
                    sm   = s_sel; if ~isempty(s_mc), sm = max(s_mc); end
                    Xmc(i_mc,:) = (Tw + sm*rw_mc).';
                end
                Cmc = cov(Xmc); lam = sort(eig(Cmc),'descend');
                eig_ratio = lam(3)/lam(1);

                % closed-form sensitivity along u
                rwu = R2w * [1/fx; 0; 0];
                au  = 2*(rw.'*rwu);
                bu  = 2*(Tw.'*rwu);
                den = sqrt(max(Delta,eps));
                dsdu = -(s_sel^2*au + s_sel*bu) / den;
                dXdu = rw*dsdu + s_sel*rwu;
                mm_per_px_u = norm(dXdu);

                fprintf('subj=%d trial=%d pt=%s | sel=%s | Δ_norm=%.4f, condJ=%.2f, eig_ratio=%.2e, root_gap=%.1f, |dX/du|=%.2f, z=%.1f (h=%.1f)\n', ...
                        subj, trial, phase, sel_mode, Delta_norm, condJ, eig_ratio, root_gap_mm, mm_per_px_u, X_w(3), ...
                        (strcmpi(phase,'imp')*HEIGHT.h_imp + strcmpi(phase,'add')*HEIGHT.h_add));

                diag_tbl = [diag_tbl; subj, trial, zi, double(sel_mode=="band")+2*double(sel_mode=="project"), ...
                            Delta_norm, condJ, eig_ratio, root_gap_mm, mm_per_px_u, X_w(3)];
            end

            % (optional) trial-level PCA
            if size(Xs,1) >= 3
                Xc = Xs - mean(Xs,1);
                [~,S,~] = svd(Xc, 'econ');
                s1 = S(1,1); s2 = S(min(2,end),min(2,end)); s3 = S(min(3,end),min(3,end));
                linearity = (s1>0) * (s3/s1);
                planarity = (s2>0) * (s3/s2);
                fprintf('  -> PCA: n=%d, linearity=%.3g, planarity=%.3g\n', size(Xs,1), linearity, planarity);
                pca_tbl = [pca_tbl; subj, trial, size(Xs,1), linearity, planarity];
            end
        end
    end
end

% show table
vars = {'subj','trial','pt','sel_mode','Delta_norm','condJ','eig_ratio','root_gap_mm','dXdu_mm_per_px','z_mm'};
diag_tbl = array2table(diag_tbl,'VariableNames',vars);  disp(diag_tbl(1:min(12,height(diag_tbl)),:));
vars_p = {'subj','trial','npts','linearity','planarity'};
% pca_tbl = array2table(pca_tbl,'VariableNames',vars_p);  disp(pca_tbl);
