function Rinf = get_orientation(time, a, w, ind,Rini)
%Function to determine orientation of IMU.
% 1) Define initial orientation of device based on direction of gravity
% 2) Define orientation thereafter by integrating angular velocity data.
% Assumes that the device is initially at rest.

%Inputs:
%1. time - time (s, nx1) 
%2. a - acceleration (g, nx3) 
%3. w - angular velocity (deg/s, nx3) 
%4. ind - index array specifying the samples where the device is at rest 
%         at the beginning of the trial (binary, nx1)
%Outputs:
%1. Rinf - DCM describing IMU orientation (3x3xn)

%Define initial Z direction (gravity)
% Z = a(ind,:) ./ norm(mean(a(ind,:)));
Z = a(ind,:) ./ norm(a(ind,:));

%Define remaining axes 
%X in terms of (i,j,k) according to X = j x Z
X = cross([0,0,1],Z); X = X./norm(X);
% X = [1,0,0];

% Y = -cross([0,0,1],Z); Y = Y./norm(Y);

%Re-define Y in terms of (i,j,k) to ensure orthogonality (Y = Z x X)
Y = cross(Z,X); Y = Y./norm(Y);
% Y = [0,-1,0];

% X = -cross(Z,Y); X = X./norm(X);

%Define initial DCM    
R = [X' Y' Z']';

% %Find and correct yaw rotation from Marker Rini -> just use Rini from marker orientation
% yaw=atan2(Rini(2,1),Rini(1,1));
% % yaw=asin(Rini(2,1));
% R=[cos(yaw) -sin(yaw) 0; sin(yaw) cos(yaw) 0; 0 0 1] * R;
% % initMyunghyun=norm(cross(cross(R^-1*[1;0;0],R^-1*[0;1;0]),R^-1*[0;0;1]))
% R= Rini(:,:);   % give initial orientation with marker

% %Define remaining axes from initial acceleration -> wrong
% %X in terms of (i,j,k) according to X = j x Z
% Y = cross([1,0,0],Z); Y = Y./norm(Y);
% backward=  Rini*[0,1,0]';
% axisY = cross(Y,backward);
% angleY = acos(dot(Y,backward)/norm(Y)*norm(backward));
% c=cos(angleY); s=sin(angleY);
% t=s/c; x=axisY(1); y=axisY(2); z=axisY(3);
% RY=[t*x*x+c, t*x*y-z*s, t*x*z+y*s;
%     t*x*y+z*s, t*y*y+c, t*y*z-x*s;
%     t*x*z-y*s, t*y*z+x*s, t*z*z+c];
% Y = -RY * Y';
% Y=Y'./norm(Y);
% %Re-define Y in terms of (i,j,k) to ensure orthogonality (Y = Z x X)
% X = -cross(Z,Y); X = X./norm(X);
% %Define initial DCM    
% R = [X; Y; Z];
% %Find and correct yaw rotation from Marker Rini
% yaw=atan(Rini(2,1)/Rini(1,1));
% R=[cos(yaw) -sin(yaw) 0; sin(yaw) cos(yaw) 0; 0 0 1] * R;


%Initialize variables
Rinf = zeros(3,3,length(time)); Rinf(:,:,1) = R;

%Convert angular velocity to rad/s and remove bias
% w = (w - (w(:,1).^0)*mean(w(ind,:))) * pi/180;
w = w * pi/180;   % without removing bias

% w = (w - (w.^0).*w(ind,:)) * pi/180;

for t=1:ind-1
    Rinf(:,:,t) = R;
end

for t=ind:length(time)
    dt = time(t) - time(t-1);
    tt = 0.5 * dt * (w(t-1,:) + w(t,:));
%     tt = dt * w(t,:);
    Rinf(:,:,t) = Rinf(:,:,t-1)*(eye(3)+(2/(1+0.5*(tt*tt.')))*...
        (0.5*skew(tt) + 0.25*skew(tt)^2));
end
end