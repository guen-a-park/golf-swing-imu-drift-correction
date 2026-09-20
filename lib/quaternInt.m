function diff=quaternInt(time, add, fin, w, b, qini, qfin)

qinf = zeros(length(time),4); qinf(1,:) = qini;
%Convert angular velocity to rad/s
% w = w * pi/180; % without removing bias

%Define orientation ~ADD
for t=1:add
    qinf(t,:) = qini;
end
%Initial integration
for t=add+1:length(time)
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)+[b(1),b(2),b(3)]]);
    qinf(t,:) = qt ./ norm(qt);
end

% diff=qinf(fin,:)-qfin;
qprod = quaternProd(quaternConj(qinf(fin,:)),qfin);
diff = abs(2 * atan2(norm(qprod(2:4)),qprod(1))*180/pi);