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

%TODO:
%   0) dapi processing button (calc all stats)
%       - user selected/defined threshold for volume calculation
%       - manual (user selected image width and number of images)
%       - auto (with cell volume entry)
%       - allow saving to previous csv file

% attempt to clean up Matlab memory situation on each startup
try
    java.lang.Runtime.getRuntime.gc();
catch tmp
end

if isempty(varargin) || isempty(varargin{1})
    varargin{1} = GetImagePath({'*.vsi;*.mat'});
    if isempty(varargin{1})
        return;
    end
end

try
    [data, bf] = InitData(varargin);
catch me
    % try and get the path to the loaded file...
    switch lower(class(varargin{1}))
    case 'char'
        im_path = varargin{1};
    case 'struct'
        if isfield(varargin{1},'path_im')
            im_path = varargin{1}.path_im;
        else
            im_path = '<unknown>';
        end
    case 'bfreader'
        im_path = varargin{1}.img_path;
    otherwise
        im_path = '<unknown>';
    end

    % process the error
    ErrorHandler(me, im_path);
    return;
end

if isempty(bf)
    return;
end

varargout{1} = RunSafe(@(x) ErrorHandler(x, bf.img_path), @BioViewRunner, data, bf);

%------------------------------------------------------------------------------%
function ErrorHandler(err, img_path)
    log_file = DumpInfo(img_path, err);

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

    for kf = 1:numel(fn)
        if ~isfield(s,fn{kf})
            s.(fn{kf}).c = [];
            s.(fn{kf}).h = [];
        end
    end
    if ~isfield(s,'overlap')
        s.overlap.c = [];
        s.overlap.h = [];
    end
end
%------------------------------------------------------------------------------%
end
