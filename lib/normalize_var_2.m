 function normalized = normalize_var_2(array)

     % Normalize to [0, 1]:
     m = min(array);
     range = max(array) - m;
     normalized = (array - m) / range;
%      % Then scale to [x,y]:
%      range2 = y - x;
%      normalized = (array*range2) + x;
