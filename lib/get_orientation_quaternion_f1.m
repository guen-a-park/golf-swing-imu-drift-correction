function qinf = get_orientation_quaternion_f1(time, ini, fin, w, qini, qfin, coef)
%Function to reconstruct orientation of IMU using forward & backward integration

%Inputs:
%1. time - time (s, nx1) 
%2. w - angular velocity (deg/s, nx3) 
%3. ind - index array specifying the samples where the device is at rest 
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
for t=1:ini
    qinf(t,:) = q0;
end

%Initial integration
for t=ini+1:length(time)
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
    qinf(t,:) = qt ./ norm(qt);
end

%Backward integration
qinfb=qinf;
qinfb(fin,:)=qfin;
for i=1:fin-ini
    t=fin-i;
    dt = time(t+1) - time(t);
    qt = qinfb(t+1,:) + 0.5*dt*quaternProd(qinfb(t+1,:),[0, -w(t,:)]);
    qinfb(t,:) = qt ./ norm(qt);
end 

%Reconstruction
qinf(fin,:)=qfin;
for t=ini+1:fin-1
% for t=ini:fin
%     qt = avg_quaternion_markley([qinf(t,:); qinfb(t,:)]);     % equal average
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),fin-t,t-ini);    % time linear
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),coef,1);    % weighted average
    
    qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),coef*(fin-t),t-ini);    % time linear weighted coef:1
    
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),3*(fin-t),t-ini);    % linear 1.83:1
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),(fin-t)^2,(t-ini)^2);    % square
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),2*(fin-t)^2,(t-ini)^2);    % square 2:1
%     qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),(fin-t)^1.83,(t-ini)); % ^1.83:1
    qinf(t,:) = qt ./ norm(qt);
    if qinf(t,:)<0
    qinf(t,:)=-qinf(t,:);
    end
end

end