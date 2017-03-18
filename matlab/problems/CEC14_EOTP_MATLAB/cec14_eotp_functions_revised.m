function [f,func_name] = cec14_eotp_functions_revised(x,no,probstruct)
%CEC14_EOTP_FUNCTIONS_REVISED Implement CEC14 expensive optimization test problems.
%   [F,FUNC_NAME] = CEC14_EOTP_FUNCTIONS(X, NO) with X as the design
%   points and FUNC_NO as functions' number (in [1,2,3,4,5,6,7,8]). F
%   should be the evaluation of F_no(x). In X, which should be a vector of
%   one design point. FUNC_NAME return the functions' name. Output argument
%   FUNC_NAME could be ommited.
%   
%   Example    
%         [f,name]=cec14_eotp_functions(zeros(2,1), 1);
%         printf('%s : f%d([0;0])=%f.\n',name, 1, f);
%     calculate the 1st function at (0,0), print its name and value.
%   
%   Details are to be found in B. Liu, Q. Chen and Q. Zhang, J. J. Liang, 
%   P. N. Suganthan, B. Y. Qu, "Problem Definitions and Evaluation Criteria
%   for Computationally Expensive Single Objective Numerical Optimization", 
%   Technical Report.

assert(no>=1 && no <= 10,'CEC14 expensive optimization test problems based on 8 functions.');
[row, col] = size(x);
assert(row==1 | col ==1, 'X should be a vector.');
x = reshape(x, max(row,col), 1);
assert(max(row,col)>=2,'Functions should at least be 2-D.');
if nargin < 3; probstruct = []; end

names = {'Sphere function',...
    'Ellipsoid function',...
    'Rotated Ellipsoid function',...
    'Step function',...
    'Ackley function',...
    'Griewank function',...
    'Rosenbrock function',...
    'Rastrigin function',...
    'Styb-Tang function',...
    'Cliff function'};

functions = {@sphere,...
    @ellipsoid,...
    @rotated_ellipsoid,...
    @step,...
    @ackley,...
    @griewank,...
    @rosenbrock,...
    @rastrigin,...
    @stybtang,...
    @cliff};

if nargout >= 2
    func_name = names{no};
end

if ~isempty(probstruct)
    % Apply (fixed) random rotation and shift
    x = cec14_rotate_shift_revised(x,no,probstruct);
    f = feval(functions{no},x);
else
    f = []; 
end