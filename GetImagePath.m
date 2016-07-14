function pth = GetImagePath(typ)
% GetImagePath
%
% Description: prompt user for image path, uses the last image loaded (from the
%              .last_image.tmp file) if it exists
%
% Syntax: pth = GetImagePath(type)
%
% In:
%       typ - a string or cell of such of allowed file extensions
%
% Out:
%       pth - the users selected file path (empty if canceled)
%
% Updated: 2016-07-13
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

cur_dir = fileparts(mfilename('fullpath'));
tmp_file = fullfile(cur_dir, '.last_image.tmp');

def_file = '';
base_dir = pwd();
pth = '';

if exist(tmp_file,'file')
    fid = fopen(tmp_file,'r');
    try
        def_file = strtrim(transpose(fread(fid,'*char')));
    catch e
    end
    fclose(fid);

    if exist(def_file,'file') == 0
        def_file = '';
        def_dir = base_dir;
    else
        [def_dir,fname,ext] = fileparts(def_file);
        def_file = [fname ext];
    end
else
    def_dir = base_dir;
end

try
    cd(def_dir);

    [fname,fdir] = uigetfile(typ,'Please select an image/data file',def_file);

    cd(base_dir);

    if isequal(fname,0) || isequal(fdir,0)
        pth = '';
    else
        pth = fullfile(fdir,fname);

        fid = fopen(tmp_file,'w');
        try
            fprintf(fid,'%s\n',pth);
        catch e
        end

        fclose(fid);
    end
catch e
    cd(base_dir);
    rethrow(e);
end

cd(base_dir);

end
