function qinf = get_orientation_quaternion_c5(time, add, fin, a, w, qini, qfin)
%Function to determine orientation of IMU.

%Inputs:
%1. time - time (s, nx1) 
%2. a - acceleration (g, nx3) 
%3. w - angular velocity (deg/s, nx3) 
%4. ind - index array specifying the samples where the device is at rest 
%         at the beginning of the trial (binary, nx1)
%
%Outputs:
%1. qinf - quaternion describing IMU orientation (nx4)

%Convert to a quaternion   
q0 = qini;

%Initialize variables
qinf = zeros(length(time),4); qinf(1,:) = q0;

%Convert angular velocity to rad/s
w = w * pi/180; % without removing bias

%Define orientation throughout trial
for t=1:add
    qinf(t,:) = q0;
end

%Initial integration
for t=add+1:length(time)
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
    qinf(t,:) = qt ./ norm(qt);
end

%Calculate correction factors
B = qfin;
A = qinf(fin,:);
C = quaternProd(quaternConj(A),B);
ang = 2*acos(C(1));
axs = [C(2)/sqrt(1-C(1)^2), C(3)/sqrt(1-C(1)^2), C(4)/sqrt(1-C(1)^2)];
N = [];
for t=add+1:length(time)
    N(t)=norm(a(t,:))-9.81;      % acc norm SUM
end

%Quaternion correction
for t=add+1:length(time)
    qang = ang * sum(N(1:t))/sum(N(add+1:fin));  % angle difference distributed by acc norm
    qc = [cos(qang/2), axs(1)*sin(qang/2), axs(2)*sin(qang/2), axs(3)*sin(qang/2)];
    qt = quaternProd(qinf(t,:),qc); 
    qinf(t,:) = qt ./ norm(qt);
end

end