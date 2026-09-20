%% Kalman filter example

function [pos vel accel] = IMUKalman(z)

persistent A H Q R
persistent x P
persistent firstRun

if isempty(firstRun)
    dt=0.005;

    % system model
    A=[1 0 0 dt 0 0 1/2*dt^2 0 0;
        0 1 0 0 dt 0 0 1/2*dt^2 0;
        0 0 1 0 0 dt 0 0 1/2*dt^2;
        0 0 0 1 0 0 dt 0 0;
        0 0 0 0 1 0 0 dt 0;
        0 0 0 0 0 1 0 0 dt;
        0 0 0 0 0 0 1 0 0;
        0 0 0 0 0 0 0 1 0;
        0 0 0 0 0 0 0 0 1];
    H=eye(9);
%     H=[0 0 0 0 0 0 1 0 0;
%         0 0 0 0 0 0 0 1 0;
%         0 0 0 0 0 0 0 0 1];
    
    % Q, R, noise covariance matrices
    Q=[0.001 0 0 0 0 0 0 0 0;
        0 0.001 0 0 0 0 0 0 0;
        0 0 0.001 0 0 0 0 0 0;
        0 0 0 0.01 0 0 0 0 0;
        0 0 0 0 0.01 0 0 0 0;
        0 0 0 0 0 0.01 0 0 0;
        0 0 0 0 0 0 0.01 0 0;
        0 0 0 0 0 0 0 0.01 0;
        0 0 0 0 0 0 0 0 0.01];
    R=[1 0 0 0 0 0 0 0 0;
        0 1 0 0 0 0 0 0 0;
        0 0 1 0 0 0 0 0 0;
        0 0 0 10 0 0 0 0 0;
        0 0 0 0 10 0 0 0 0;
        0 0 0 0 0 10 0 0 0;
        0 0 0 0 0 0 10 0 0;
        0 0 0 0 0 0 0 10 0;
        0 0 0 0 0 0 0 0 10];
    
    % initial condition
    x=z';
%     x=[0 0 0 0 0 0 z(1) z(2) z(3)]';
    P=0.01*eye(9);
    
    firstRun=1;
end

xp=A*x;                     % predict estimate
Pp=A*P*A'+Q;                % predict error covariance

K=Pp*H'*inv(H*Pp*H'+R);     % compute Kalman gain

x=xp+K*(z'-H*xp);            % compute estimate
P=Pp-K*H*Pp;                % compute error covariance

pos=x(1:3);
vel=x(4:6);
accel=x(7:9);
