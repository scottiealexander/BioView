function s = ParseOpts(opts,varargin)

% ParseOpts
%
% Description: simple optional argument parser
%
% Syntax: s = ParseOpts(varargin,<defaults>)
%
% In: 
%       varargin - the varargin cell containing the param-value specification
%                  from the caller
%       defaults - a series of param-value pairs specifing a default value for
%                  each parameter
%
% Out: 
%       opt  - a struct of option values
%
% Updated: 2014-08-14
% Scottie Alexander

%inorder for cell2struct to accept '2' as the dim (3rd) argument we need our
%cell to be a row cell
opts = reshape(opts,1,[]);

%convert cells to structs
if ~mod(numel(opts),2)
    %make sure there is an even number of parameter value pairs
    s = cell2struct(opts(2:2:end),opts(1:2:end),2);
else
    %chop the last input as it doesn't have a matching item
    opts(end) = [];
    s = cell2struct(opts(2:2:end),opts(1:2:end),2);
end

%make sure there is a value for every param in defaults
if mod(numel(varargin),2)
    me = MException('InvalidInput:MissingValues',...
        'the number of parameters and values in default cell do no match');
    throw(me);
end

def = cell2struct(varargin(2:2:end),varargin(1:2:end),2);

%merge the structs with precedence given to the callers values
cFields = fieldnames(def);
for k = 1:numel(cFields)
    if ~isfield(s,cFields{k})
        s.(cFields{k}) = def.(cFields{k});
    end
end