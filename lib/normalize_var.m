 function normalized = normalize_var(array)

%      % Normalize to [0, 1]:
%      m = min(array);
%      range = max(array) - m;
%      array = (array - m) / range;
%      % Then scale to [x,y]:
%      range2 = y - x;
%      normalized = (array*range2) + x;

     % Normalize to [-max(minMax), max(minMax)] -> [-1 1]:
     m = min(array); M = max(array);
     Max = max(abs(m), abs(M));
     normalized = array / Max;
     