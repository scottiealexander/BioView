function rgb = Color(str,varargin)
% Color
%
% Description: convert a color name to rgb using the ColorDB
%
% Syntax: rgb = Color(str,[options])
%
% In:
%       str - color name as a string
%   options:
%       show - (false) true to show a sample of the color
%
% Out:
%       rgb - the input color as an rgb triplett
%
% Updated: 2015-10-07
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

opt = ParseOpts(varargin,...
    'show' ,  false ...
    );

db = mge.ColorDB();

if ischar(str)
    if ~db.IsColor(str)
        rgb = [];
        warning('Color:CantFindColor','Requsted color %s is not in database',str);
    else
        rgb = db.Get(str);
        if opt.show
            db.Show(rgb);
        end
    end
elseif isnumeric(str)
    rgb = db.GetRandom(str);
end
