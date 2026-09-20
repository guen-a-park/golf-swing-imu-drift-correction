function qinf = get_orientation_quaternion_c0(time, add, fin, a, w, qini, qfin)
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


%Convert angular velocity to rad/s
w = w * pi/180; % without removing bias

%Change initial orientation to DCM format
Rini=quatern2dcm(qini); Rfin=quatern2dcm(qfin);
Rini=Rini'; Rfin=Rfin';
%Initialize dcm
Rinf = zeros(3,3,length(time));
for t=1:add
    Rinf(:,:,t) = Rini;
end
for t=add+1:length(time)
    dt = time(t) - time(t-1);
%     tt = 0.5 * dt * (w(t-1,:) + w(t,:));
    tt = dt * w(t,:);
    Rinf(:,:,t) = Rinf(:,:,t-1) * expm(skew(tt));   % matrix exponential
    Rinf(:,:,t)=orthogonalization(Rinf(:,:,t));
end

%Calculate local bias to correct
A=Rinf(:,:,fin);
B=Rfin;
biasSkew=logm(B/A)/(time(fin)-time(fin-1));   % in skew matrix
biasSum=[biasSkew(3,2),biasSkew(1,3),biasSkew(2,1)];

distribute=4;   % 0: no bias, 1: equal, 2: w norm, 3: dw norm, 4: local w mag, 5: local dw mag, 6: local acc. mag, 7: t^2
wb=w;
switch distribute
    case 0  % none
    case 1  % equal
        wb(add+1:fin,:)=w(add+1:fin,:)+biasSum/(fin-add);
    case 2  % w norm
    case 3  % dw norm
        N = [];
        for t=add+1:length(time)
            N(t)=norm(w(t,:)-w(t-1,:));      % dw norm SUM
        end
        for t=add+1:length(time)
            wb(t,:)=w(t,:) + biasSum*norm(w(t,:)-w(t-1,:))/sum(N(add+1:fin));
        end
    case 4  % local w mag
        N = [];
        for t=add+1:length(time)
            N(t,:)=abs(w(t,:));      % local acc. mag SUM
        end
        for t=add+1:length(time)
            wb(t,1)=w(t,1) + biasSum(1) * abs(w(t,1))/sum(N(add+1:fin,1));
            wb(t,2)=w(t,2) + biasSum(2) * abs(w(t,2))/sum(N(add+1:fin,2));
            wb(t,3)=w(t,3) + biasSum(3) * abs(w(t,3))/sum(N(add+1:fin,3));
        end
    case 5  % local dw mag
        N = [];
        for t=add+1:length(time)
            N(t,:)=abs(w(t,:)-w(t-1,:));      % local acc. mag SUM
        end
        for t=add+1:length(time)
            wb(t,1)=w(t,1) + biasSum(1) * abs(w(t,1)-w(t-1,1))/sum(N(add+1:fin,1));
            wb(t,2)=w(t,2) + biasSum(2) * abs(w(t,2)-w(t-1,2))/sum(N(add+1:fin,2));
            wb(t,3)=w(t,3) + biasSum(3) * abs(w(t,3)-w(t-1,3))/sum(N(add+1:fin,3));
        end
    case 6
        N = [];
        for t=add+1:length(time)
            N(t,:)=abs(a(t,:));      % local acc. mag SUM
        end
        for t=add+1:length(time)
            wb(t,1)=w(t,1) + biasSum(1) * abs(a(t,1))/sum(N(add+1:fin,1));
            wb(t,2)=w(t,2) + biasSum(2) * abs(a(t,2))/sum(N(add+1:fin,2));
            wb(t,3)=w(t,3) + biasSum(3) * abs(a(t,3))/sum(N(add+1:fin,3));
        end
    case 7  % t^2
        N=sum((1:fin-add).^2);
        wb(add+1:fin,1)=w(add+1:fin,1)+biasSum(1)/N*((1:fin-add).^2)';
        wb(add+1:fin,2)=w(add+1:fin,2)+biasSum(2)/N*((1:fin-add).^2)';
        wb(add+1:fin,3)=w(add+1:fin,3)+biasSum(3)/N*((1:fin-add).^2)';
end

% %quaternion correction
% qinf = zeros(length(time),4);
% for t=1:add
%     qinf(t,:) = qini;
% end
% for t=add+1:length(time)
%     dt = time(t) - time(t-1);
%     qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, wb(t,:)]);
%     qinf(t,:) = qt ./ norm(qt);
% end

%DCM correction
for t=add+1:length(time)
    dt = time(t) - time(t-1);
    ttb = dt * wb(t,:);
%     Rinf(:,:,t) = Rinf(:,:,t-1) * expm(skew(ttb));   % matrix exponential
    Rinf(:,:,t) = Rinf(:,:,t-1)*(eye(3)+skew(ttb)+0.5*skew(ttb)^2);  % matrix exponential expanded
    Rinf(:,:,t)=orthogonalization(Rinf(:,:,t));
end

%Change orientation to quaternion
for t=1:length(time)
    qinf(t,:)=dcm2quatern(Rinf(:,:,t)');
    if qinf(t,1)<0
        qinf(t,:)=-qinf(t,:);
    end
end

%Calculate correction factors
B = qfin;
A = qinf(fin,:);
C = quaternProd(quaternConj(A),B);
ang = 2*acos(C(1));
axs = [C(2)/sqrt(1-C(1)^2), C(3)/sqrt(1-C(1)^2), C(4)/sqrt(1-C(1)^2)];

%Quaternion correction
deg=2;
for t=add+1:length(time)
    qang = ang * (t-add)^deg/(fin-add)^deg;  % angle difference distributed by time
    qc = [cos(qang/2), axs(1)*sin(qang/2), axs(2)*sin(qang/2), axs(3)*sin(qang/2)];
    qt = quaternProd(qinf(t,:),qc); 
    qinf(t,:) = qt ./ norm(qt);
end

end