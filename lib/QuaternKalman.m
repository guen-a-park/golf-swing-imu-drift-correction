%% Kalman filter example

function [q1, q2, q3, q4] = QuaternKalman(dt, gyro, acc, qini)

persistent H Q R
persistent x P
persistent firstRun

if isempty(firstRun)
    % system model
    H=eye(4);
    
    % Q, R, noise covariance matrices
    Q=0.0001*eye(4);
    R=10*eye(4);
    
    % initial condition
    x=qini';
    P=1*eye(4);
    
    firstRun=1;
end

ax=acc(1); ay=acc(2);
gyro=gyro.*pi./180;
[phi, theta] = EulerAccel(ax, ay);
z=EulerToQuaternion(phi,theta,0);
A=eye(4)+dt*1/2*[0 -gyro(1) -gyro(2) -gyro(3);
                     gyro(1) 0 gyro(3) -gyro(2);
                     gyro(2) -gyro(3) 0 gyro(1);
                     gyro(3) gyro(2) -gyro(1) 0];
                 
xp=A*x;                     % predict the estimate
Pp=A*P*A'+Q;                % predict the error covariance

K=Pp*H'*inv(H*Pp*H'+R);     % compute the Kalman gain

x=xp+K*(z'-H*xp);            % compute the estimate
P=Pp-K*H*Pp;                % compute the error covariance

x=x./norm(x);

q1=x(1); q2=x(2); q3=x(3); q4=x(4);     % quaternion elements
