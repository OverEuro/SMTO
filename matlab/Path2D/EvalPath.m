function [cost] = EvalPath(path,CostFunc)
%EVALPATH この関数の概要をここに記述

T = size(path, 1);
cost = 0;

for i=1:T
   cost_i = CostFunc(path(i, 1), path(i, 2));
   cost = cost + cost_i;
end

end

