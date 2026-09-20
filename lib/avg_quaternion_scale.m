function Qavg=avg_quaternion_scale(Q1,Q2,a,b)
% Form the symmetric accumulator matrix
C = quaternProd(quaternConj(Q1),Q2);
if C(1)<0
    C=-C;
end
ang = 2*acos(C(1));
axs = [C(2)/sqrt(1-C(1)^2), C(3)/sqrt(1-C(1)^2), C(4)/sqrt(1-C(1)^2)];
qang = ang .* b./(a+b);  % angle difference distributed by norm(w(t)-w(t-1))
qc = [cos(qang/2), axs(1)*sin(qang/2), axs(2)*sin(qang/2), axs(3)*sin(qang/2)];
Qavg = quaternProd(Q1,qc);
end