function Rinf = get_orientation(time, a, w, ind, Rini)
%Function to determine orientation of IMU.
% 1) Define initial orientation of device based on direction of gravity
% 2) Define orientation thereafter by integrating angular velocity data.
% Assumes that the device is initially at rest.

% s.time, s.T5wrist, s.T5wristGyro, s.address, R2Lw(:,:,s.address));
% acceleration seems unused, only angular velocity is used

%Inputs:
%1. time - time (s, nx1) 
%2. a - acceleration (g, nx3) 
%3. w - angular velocity (deg/s, nx3) 
%4. ind - index array specifying the samples where the device is at rest 
%         at the beginning of the trial (binary, nx1)
%Outputs:
%1. Rinf - DCM describing IMU orientation (3x3xn)

% give initial orientation from ML model/ or markerset
R= Rini(:,:);

%Initialize variables
Rinf = zeros(3,3,length(time)); Rinf(:,:,1) = R; % R is the initial value

%Convert angular velocity to rad/s
% apdm is already in rad/s
w = w * pi/180;   % without removing bias

for t=1:ind
    Rinf(:,:,t) = R;
end
for t=ind+1:length(time)
    dt = time(t) - time(t-1);
%     tt = 0.5 * dt * (w(t-1,:) + w(t,:));
    tt = dt * w(t,:); %3-axis delta angle values
%     Rinf(:,:,t) = Rinf(:,:,t-1)*(eye(3)+(2/(1+0.5*(tt*tt.')))*...
%         (0.5*skew(tt) + 0.25*skew(tt)^2));    % old version
    Rinf(:,:,t) = Rinf(:,:,t-1)*(eye(3)+skew(tt)+0.5*skew(tt)^2 + 1/6*skew(tt)^3);  % matrix exponential expanded
%     Rinf(:,:,t) = Rinf(:,:,t-1) * expm(skew(tt));   % matrix exponential
    Rinf(:,:,t) = orthogonalization(Rinf(:,:,t));
end
% for t=1:length(time)
%     Rinf(:,:,t)=Rinf(:,:,t)^(-1);
% end
end