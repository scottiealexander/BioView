function varargout = RunSafe(f, varargin)

% RunSafe
%
% Description: run a function within a try-catch block
%
% Syntax: varargout = RunSafe(f, varargin)
%
% In:
%       f   - a handle to the function to run
%       varargin - any inputs to pass to the function
%
% Out:
%       varargout - the outputs of the function (if any)
%
% Updated: 2016-05-17
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

persistent inprogress;
if isempty(inprogress)
    inprogress = false;
end
c = onCleanup(@() ResetProgress);

% Only allow one operation to run at a time
if ~inprogress
    inprogress = true;

    %try running the command and catch any error
    try
        varargout = {f(varargin{:})};
    catch me
        %error was reaised, allow reporting
    end

    inprogress = false;
end

%-------------------------------------------------------------------------%
function ResetProgress
    inprogress = false;
end
%-------------------------------------------------------------------------%
end
