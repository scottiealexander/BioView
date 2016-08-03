function varargout = RunSafe(ferr, fproc, varargin)
% RunSafe
%
% Description: run a function within a try-catch block
%
% Syntax: varargout = RunSafe(ferr, fproc, varargin)
%
% In:
%       ferr - a handle to an error handling function (i.e. takes an
%             MException as it's only input, returns no ouputs)
%       fproc - a handle to the "process" function to run
%       varargin - any inputs to pass to the process function
%
% Out:
%       varargout - the outputs of the function (if any)
%
% Updated: 2016-07-13
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com


%try running the command and catch any error
try
    varargout = {fproc(varargin{:})};
catch me
    %error was reaised, attempt reporting
    try
        ferr(me);
    catch me
    end

    % make sure output is assigned
    varargout = {[]};
end

end
