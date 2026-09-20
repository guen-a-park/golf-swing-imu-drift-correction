function Rmse = RMSE(measured,true)
Rmse = sqrt(sum((measured-true).^2)./length(true));
end
