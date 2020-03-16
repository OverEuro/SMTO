function [cost] = EvalPath(path,CostFunc)
%EVALPATH ���̊֐��̊T�v�������ɋL�q

T = size(path, 1);
cost = 0;

for i=1:T
   cost_i = CostFunc(path(i, 1), path(i, 2));
   cost = cost + cost_i;
end

end

