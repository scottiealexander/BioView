function Update
% Update
%
% Description: Update BioView
%
% Syntax: Update
%
% In:
%
% Out:
%
% Updated: 2016-07-13
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com
if ispc()
    nulldev = 'NUL';
else
    nulldev = '/dev/null';
end

if system(['git status > ' nulldev]) == 0
    msg = ['It appears "git" is not installed or not accessible. '...
        'See the <a href='...
        '"https://github.com/scottiealexander/BioView/wiki/Install">'...
        'BioView wiki</a> for more information.'...
    ];
    error(msg);
end

repo = fileparts(mfilename('fullpath'));

cur_dir = pwd();

try
    cd(repo);
    if isdir(fullfile(repo, '.git'))
        [out,res] = system('git pull origin master');
        if out ~= 0
            msg = ['Code update failed.\n',...
                   'Repository: %s\n'     ,...
                   'Error message: %s\n'   ...
            ];
            idir = strrep(repos{k},'\','\\');
            msg = sprintf(msg, idir, res);
            warning('Update:UpdateFailed', msg);
        else
            fprintf('SUCCESS: %s\n', res);
        end
    else
        fprintf('[INFO]: no repository located at %s\n', repos{k});
    end

catch me
    cd(cur_dir);
end

cd(cur_dir);
