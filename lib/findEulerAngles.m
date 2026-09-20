function findE = findEulerAngles(targetVec)
    % desired target vector (right-hand side)
    % targetVec = [1.6037; -9.6302; -0.6266];
    
    % fsolve option setup (display 'iter' -> shows the iterations)
    options = optimoptions('fsolve','Display','iter');

    % initial guess ( in rad, all assumed within 0~90 deg (=0~pi/2) )
    % x0 = [0.1; 0.1; 0.1];  % arbitrary initial value for (phi, theta, psi)
    x0 = [0.15; 0.15; 0.15];  % arbitrary initial value for (phi, theta, psi)
    
    % run fsolve
    [xSol, ~] = fsolve(@(x) residualFun(x, targetVec), x0, options);
    
    % print result (radian -> degree conversion)
    phi_sol   = xSol(1);
    theta_sol = xSol(2);
    psi_sol   = xSol(3);
    
    fprintf('Solution in radians: phi = %.4f, theta = %.4f, psi = %.4f\n',...
             phi_sol, theta_sol, psi_sol);
    fprintf('Solution in degrees: phi = %.2f°, theta = %.2f°, psi = %.2f°\n',...
             rad2deg(phi_sol), rad2deg(theta_sol), rad2deg(psi_sol));
end

function r = residualFun(x, targetVec)
    % x(1) = phi, x(2) = theta, x(3) = psi
    phi   = x(1);
    theta = x(2);
    psi   = x(3);

    % rotation matrix (note the 3-2-1 order X->Y->Z; may change with notation or definition)
    % Rx = [1       0        0
    %       0 cos(phi) -sin(phi)
    %       0 sin(phi)  cos(phi)];
    % 
    % Ry = [ cos(theta)  0  sin(theta)
    %        0           1      0
    %       -sin(theta)  0  cos(theta)];
    % 
    % Rz = [cos(psi) -sin(psi) 0
    %       sin(psi)  cos(psi) 0
    %       0         0        1];

    Rx = [1       0        0
          0 cos(phi) sin(phi)
          0 -sin(phi)  cos(phi)];
      
    Ry = [ cos(theta)  0  -sin(theta)
           0           1      0
          sin(theta)  0  cos(theta)];
      
    Rz = [cos(psi) sin(psi) 0
          -sin(psi)  cos(psi) 0
          0         0        1];

    % final rotation matrix (mind the order: Rx * Ry * Rz)
    R = Rx * Ry * Rz;  
    
    % apply the rotation matrix to the input vector [0; -9.81; 0]
    vRot = R * [0; -9.81; 0];
    % vRot = R * [0; 0; -9.81];
    
    
    % difference from the target (residual)
    r = vRot - targetVec;
end
