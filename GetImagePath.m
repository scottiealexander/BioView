function pth = GetImagePath(typ)
% GetImagePath
%
% Description: prompt user for image path
%
% Syntax: pth = GetImagePath(type)
%
% In:
%       typ - a string or cell of such of allowed file extensions
%
% Out:
%       pth - the users selected file path (empty if canceled)
%
% Updated: 2016-07-12
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

[fname,fdir] = uigetfile(typ,'Please select an image/data file');
if isequal(fname,0) || isequal(fdir,0)
    pth = '';
else
    pth = fullfile(fdir,fname);
end

end
