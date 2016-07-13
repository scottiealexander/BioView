function varargout = BioView(varargin)
% BioView
%
% Description: BioView cell counting application
%
% Syntax: data = BioView([inp]=<prompt>)
%
% In:
%       [inp] - a .vsi or .mat file path, count data structure, or BFReader
%               call with no inputs to prompt for file path
%
% Out:
%       data - a BioView data structure
%
% Updated: 2016-07-13
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

if isempty(varargin) || isempty(varargin{1})
    varargin{1} = GetImagePath({'*.vsi;*.mat'});
    if isempty(varargin{1})
        return;
    end
end

try
    [data, bf] = InitData(varargin);
catch me
    DumpInfo(varargin{1}, me);
    rethrow(me);
end

if isempty(bf)
    return;
end

varargout{1} = RunSafe(@ErrorHandler, @BioViewRunner, data, bf);

%------------------------------------------------------------------------------%
function ErrorHandler(err)
    log_file = DumpInfo(bf.img_path, err);

    msg = ['Oops..! A bug got through all the traps I set...\n' ...
           'Please email scottiealexander11@gmail.com with the\n' ...
           'circumstances of this error and please attach the log file\n' ...
           'from this session, which is located at:\n\n"%s"\n\nThanks!' ...
    ];

    msg = sprintf(msg, log_file);
    c = {{'edit','string',msg,'Max',2,'Enable','inactive'};...
         {'pushbutton','string','ok','tag','ok'}
    };

    w = Win(c,'title','Error detected','focus','ok');
    w.Wait();

    fprintf(2, '%s\n', msg);
end
%------------------------------------------------------------------------------%
function [s,bf] = InitData(inp)

    s = struct();

    switch lower(class(inp{1}))
    case 'char'
        if strcmpi(regexp(inp{1},'\.([\w]+)$','match','once'),'.mat')
            tmp = load(inp{1});
            [s,bf] = InitData(tmp);
        else
            bf = BFReader(inp{1});
        end
    case 'struct'
        bf = BFReader(inp{1}.path_im);
        fn = [bf.Chan2Field(); {'overlap'}];
        for k = 1:numel(fn)
            s.(fn{k}).c = inp{1}.(fn{k});
            s.(fn{k}).h = [];
        end
    case 'bfreader'
        bf = inp{1};
    otherwise
        error('Invalid input');
    end

    s.path_im = bf.img_path;

    fn = [bf.Chan2Field(); {'overlap'}];

    for k = 1:numel(fn)
        if ~isfield(s,fn{k})
            s.(fn{k}).c = [];
            s.(fn{k}).h = [];
        end
    end
    if ~isfield(s,'overlap')
        s.overlap.c = [];
        s.overlap.h = [];
    end
end
%------------------------------------------------------------------------------%
function pth = GetImagePath(typ)
    [fname,fdir] = uigetfile(typ,'Please select an image/data file');
    if isequal(fname,0) || isequal(fdir,0)
        pth = '';
    else
        pth = fullfile(fdir,fname);
    end
end
%------------------------------------------------------------------------------%
end
