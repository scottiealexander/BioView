function DumpInfo(ifile, me)
% DumpInfo
%
% Description:
%
% Syntax: DumpInfo(me)
%
% In:
%       ifile - the path to the .vsi file that was loaded/loading at the time
%               of the error
%       me    - an MException object
%
% Out:
%
% Updated: 2016-05-10
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

str = datestr(now(), 'yyyymmdd_HH-MM');

ofile = GenLogFile(str);

if exist(ofile, 'file') > 0
    str = datestr(datetime('now'), 'yyyymmdd_HH-MM-SS');
    ofile = GenLogFile(str);
end

fid = fopen(ofile, 'w');

try
    fprintf(fid, 'date-time: %s\n', str);
    fprintf(fid, 'matlab-version: %s\n', version());
    fprintf(fid, 'computer-arch: %s\n', computer('arch'));

    if ispc()
        [~,os] = system('ver');
    elseif ismac()
        [~,os] = system('sw_vers -productVersion');
    else
        %linux
        [~,os] = system('uname -vr');
    end

    fprintf(fid, 'os: %s\n', os);
    fprintf(fid, 'data-file: %s\n\n', ifile);

    fprintf(fid, 'error-message: %s\n', me.message);
    fprintf(fid, 'stack-trace:\n');

    for k = 1:numel(me.stack)
        fprintf(fid, '\t%s\n', repmat('*', 1, 20));
        fprintf(fid,...
            '\tfile: %s\n\tfunction: %s\n\tline: %d\n',...
            me.stack(k).file, me.stack(k).name, me.stack(k).line ...
            );
    end
    fprintf(fid, '\t%s\n', repmat('*', 1, 20));
catch me
    fclose(fid);
    rethrow(me);
end

fclose(fid);

% ---------------------------------------------------------------------------- %
function ofile = GenLogFile(str)
    odir = fileparts(mfilename('fullpath'));
    ofile = fullfile(odir, [str '_error.log']);
% ---------------------------------------------------------------------------- %
