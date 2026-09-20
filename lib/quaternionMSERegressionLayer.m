classdef quaternionMSERegressionLayer < nnet.layer.RegressionLayer
        
    properties
        % (Optional) Layer properties.

        % Layer properties go here.
    end
 
    methods
        function layer = quaternionRegressionLayer()           
            % (Optional) Create a myRegressionLayer.
%             layer.Name = name;
            layer.Description = 'Quaternion product angle error';
            % Layer constructor function goes here.
        end

        function loss = forwardLoss(layer, Y, T)
            % Return the loss between the predictions Y and the training
            % targets T.
            %
            % Inputs:
            %         layer - Output layer
            %         Y     ? Predictions made by network
            %         T     ? Training targets
            %
            
%             qprod = quaternProd(quaternConj(Y),T);
%             prodError = 2 * atan2(norm(qprod(2:4)),qprod(1));
            N = size(Y,4); diff=0;
            Y=squeeze(Y);
            T=squeeze(T);
            for i=1:N
                diff = diff + 1-abs(Y(:,i)'*(Y(:,i)'*Y(:,i))^(-1/2) * T(:,i)); % + 0.5 * (1-Y(:,i)'*Y(:,i))^2 ;     % phi4
                diff = diff + 10 * sum(Y(:,i).^2-T(:,i).^2)./length(Y(:,i)); 
%                  diff = diff + 1-(Y(:,i)'./norm(Y(:,i)) * T(:,i))^2;     % phi4^2
%                 diff = diff + acos(abs(Y(:,i)'*(Y(:,i)'*Y(:,i))^(-1/2) * T(:,i))); %+ 0.2 * (1-Y(:,i)'*Y(:,i))^2 ;        % phi3
            end
            
            
            % Output:
            %         loss  - Loss between Y and T
            
            loss = diff/N;

            % Layer forward loss function goes here.
        end
        
        function dLdY = backwardLoss(layer, Y, T)
            % (Optional) Backward propagate the derivative of the loss 
            % function.
            %
            % Inputs:
            %         layer - Output layer
            %         Y     ? Predictions made by network
            %         T     ? Training targets
            %
%             q = quaternProd(Y+0.001,T);
%             prodError = 2 * atan2(norm(q(2:4)),q(1));
            N = size(Y,4); diff=zeros(4,N);
            Y=gather(squeeze(Y));
            T=gather(squeeze(T));
            for i=1:N
                if Y(:,i)'*(Y(:,i)'*Y(:,i))^(-1/2) * T(:,i) >= 0        % phi4
                    diff(:,i)=-(T(:,i)*(Y(:,i)'*Y(:,i))^(-1/2) - Y(:,i)*(Y(:,i)'*Y(:,i))^(-3/2)*(Y(:,i)'*T(:,i))); % - 0.5* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
                    diff(:,i)=diff(:,i) + sum(2*Y(:,i))./length(Y(:,i));
                else
                    diff(:,i)=(T(:,i)*(Y(:,i)'*Y(:,i))^(-1/2) - Y(:,i)*(Y(:,i)'*Y(:,i))^(-3/2)*(Y(:,i)'*T(:,i))); % - 0.5* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
                    diff(:,i)=diff(:,i) + sum(2*Y(:,i))./length(Y(:,i));
                end
                
%                 diff(:,i) = -2 * Y(:,i)'*T(:,i) / norm(Y(:,i)) * (T(:,i)/norm(Y(:,i)) - 1/2 * Y(:,i)'*T(:,i) * (Y(:,i)'*Y(:,i))^(-3/2) * 2*Y(:,i)); % phi4^2 re
%                 diff(:,i) = -2 * Y(:,i)'*T(:,i) / norm(Y(:,i)) * (T(:,i)/norm(Y(:,i)) - Y(:,i)' * T(:,i) * norm(Y(:,i))^(-2) * Y(:,i)); % phi4^2

%                 if Y(:,i)'./norm(Y(:,i)) * T(:,i) >= 0              % phi3
%                     diff(:,i) = -1/sqrt(1-(Y(:,i)'./norm(Y(:,i)) * T(:,i))^2) * (T(:,i)/norm(Y(:,i)) - 1/2 * Y(:,i)'*T(:,i) * (Y(:,i)'*Y(:,i))^(-3/2) * 2*Y(:,i)); % - 0.2* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
%                 elseif Y(:,i)'./norm(Y(:,i)) * T(:,i) < 0
%                     diff(:,i) = -1/sqrt(1-(-Y(:,i)'./norm(Y(:,i)) * T(:,i))^2) * (-T(:,i)/norm(Y(:,i)) + 1/2 * Y(:,i)'*T(:,i) * (Y(:,i)'*Y(:,i))^(-3/2) * 2*Y(:,i)); %  -0.2* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
%                 end
%                 if  Y(:,i)'*(Y(:,i)'*Y(:,i))^(-1/2) * T(:,i) >= 0              % phi3 modified
%                     diff(:,i) = -1/sqrt(1-(Y(:,i)'./norm(Y(:,i)) * T(:,i))^2) * (T(:,i)*(Y(:,i)'*Y(:,i))^(-1/2) - Y(:,i)*(Y(:,i)'*Y(:,i))^(-3/2)*(Y(:,i)'*T(:,i))); % - 0.2* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
%                 elseif  Y(:,i)'*(Y(:,i)'*Y(:,i))^(-1/2) * T(:,i) < 0
%                     diff(:,i) = -1/sqrt(1-(Y(:,i)'./norm(Y(:,i)) * T(:,i))^2) * -(T(:,i)*(Y(:,i)'*Y(:,i))^(-1/2) - Y(:,i)*(Y(:,i)'*Y(:,i))^(-3/2)*(Y(:,i)'*T(:,i))); %  -0.2* 4 * (1-Y(:,i)'*Y(:,i))*Y(:,i);
%                 end
            end
            % Output:
            %         dLdY  - Derivative of the loss with respect to the 
            %                 predictions Y        
%             N = size(Y,4);
%             dLdY = [sum(prodError)/N;
            dLdY = gpuArray(single(zeros(1,1,4,N))); 
%             dLdY(1,1,:,:) = single(diff);
            dLdY(1,1,:,:) = gpuArray(single(diff));
            
%             dLdY(1,1,:,:) = cast(diff,'single');
            % Layer backward loss function goes here.
        end
    end
end