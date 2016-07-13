classdef ColorDB < handle
% mge.ColorDB
%
% Description: class interface to Color Database mapping between names
%              and rgb values
%
% Syntax: db = mge.ColorDB()
%
% In:
%
% Out:
%       db - an instance of the ColorDB class
%
% Methods:
%       Get(str) - get rgb values given a color name
%       GetRandom(n) - get n unique randomly chosen colors
%       Set(str,rgb) - add mapping from str to rgb to the data base
%       Remove(str) - remove a color from the database by name
%       Show(str|rgb) - show a color given a name or rgb
%       Revert() - revert database to original state
%       IsColor(str) - check whether str exists in the database
%       RGB2Name(rgb) - attempt reverse mapping from rgb value to color name
%
% Updated: 2016-01-29
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

%PRIVATE PROPERTIES-----------------------------------------------------------%
properties (SetAccess=private)
    fnames;
    fvalues;
    ncolors;
end
%PRIVATE PROPERTIES-----------------------------------------------------------%

%PUBLIC METHODS---------------------------------------------------------------%
methods
    %-------------------------------------------------------------------------%
    function self = ColorDB()
        idir = fileparts(mfilename('fullpath'));
        self.fnames = fullfile(idir,'colors.txt');
        self.fvalues = fullfile(idir,'colors.dat');
        self.CheckFiles();
        self.ncolors = numel(self.GetNames());
    end
    %-------------------------------------------------------------------------%
    function rgb = Get(self,name)
        k = self.Name2Idx(name);
        if isempty(k)
            error('Failed to find color %s',name);
        end
        rgb = reshape(self.GetColor(k),1,[]);
    end
    %-------------------------------------------------------------------------%
    function rgb = GetRandom(self,n)
        kc = randperm(self.ncolors,n);
        rgb = nan(n,3);
        for k = 1:n
            rgb(k,:) = reshape(self.GetColor(kc(k)),1,[]);
        end
    end
    %-------------------------------------------------------------------------%
    function Set(self,name,rgb)
        if numel(rgb) ~= 3 || any(rgb < 0)
            error('RGB *MUST* contain 3 values >= 0');
        end
        if all(rgb <= 1)
            rgb = rgb .* 255;
        end
        [k,names] = self.Name2Idx(name);
        if isempty(k)
            k = numel(names)+1;
            names{end+1} = name;
        end
        x = self.GetValues();
        k = k*3;
        x(k-2:k) = uint8(rgb);

        self.WriteNames(names);
        self.WriteValues(x);
    end
    %-------------------------------------------------------------------------%
    function Remove(self,name)
        k = self.Name2Idx(name);
        if ~isempty(k)
            x = self.GetValues();
            kk = k*3;
            x(kk-2:kk) = [];
            names = self.GetNames();
            names(k) = [];
            self.WriteNames(names);
            self.WriteValues(x);
        else
            warning('ColorDB:InputNotColor','The color %s cannot be found in the databse',name);
        end
    end
    %-------------------------------------------------------------------------%
    function him = Show(self,rgb)
        if isnumeric(rgb)
            rgb = rgb;
        elseif ischar(rgb)
            rgb = self.Get(rgb);
        end
        if any(rgb) > 1
            rgb = rgb./255;
        end
        him = imshow(repmat(reshape(rgb,1,1,3),400,400));
        title(gca,sprintf('[%d, %d, %d]',rgb*255));
    end
    %-------------------------------------------------------------------------%
    function Revert(self)
        pw = sprintf('%d',randi([0 9],[1 6]));
        msg = 'To revert database you must enter the following code:';
        str = sprintf('%s\n\t  %s\n\t> ',msg,pw);
        res = input(str,'s');
        if ~strcmp(res,pw)
            fprintf('Incorrect code entered!\n');
            return;
        else
            fprintf('Reverting database...\n');
            orig_names = Path(self.fnames).append('color.bak');
            orig_value = Path(self.fvalues).append('color.bak');
            if exist(orig_names,'file') == 2 && exist(orig_value,'file') == 2
                delete(self.fnames);
                copyfile(orig_names,self.fnames);
                cmd = 'chmod +w %s';
                system(sprintf(cmd,self.fnames));

                delete(self.fvalues);
                copyfile(orig_value,self.fvalues);
                system(sprintf(cmd,self.fvalues));
            else
                error('Failed to locate database backup files');
            end
        end
    end
    %-------------------------------------------------------------------------%
    function b = IsColor(self,name)
        b = any(strcmpi(name,self.GetNames()));
    end
    %-------------------------------------------------------------------------%
    function name = RGB2Name(self,rgb)
        if numel(rgb) ~= 3 || any(rgb < 0)
            error('RGB *MUST* contain 3 values > 0');
        end
        if all(rgb <= 1)
            rgb = rgb.*255;
        end
        rgb = reshape(rgb,1,[]);
        x = transpose(reshape(self.GetValues(),3,[]));

        [mn,kmn] = min(sum((repmat(rgb,size(x,1),1)-x).^2,2));
        if mn == 0
            names = self.GetNames();
            name = names{kmn};
        else
            error('Failed to locate RGB value in database');
        end
    end
    %-------------------------------------------------------------------------%
end
%PUBLIC METHODS---------------------------------------------------------------%

%PUBLIC METHODS---------------------------------------------------------------%
methods (Access=private)
    %-------------------------------------------------------------------------%
    function rgb = GetColor(self,k)
        fid = fopen(self.fvalues,'r');
        try
            fseek(fid,(k-1)*3,'bof');
            rgb = fread(fid,3,'uint8');
            fclose(fid);
        catch me
            if any(fopen('all')==fid)
                fclose(fid);
            end
            rethrow(me);
        end
        rgb = double(rgb)./255;
    end
    %-------------------------------------------------------------------------%
    function [k,names] = Name2Idx(self,name)
        names = self.GetNames();
        k = find(strcmpi(name,names),1,'first');
    end
    %-------------------------------------------------------------------------%
    function names = GetNames(self)
        names = regexp(strtrim(fget(self.fnames)),'\n','split');
    end
    %-------------------------------------------------------------------------%
    function WriteNames(self,names)
        fid = fopen(self.fnames,'w');
        if fid < 1
            error('Failed to open colors.txt for writing, check permissions');
        end
        fprintf(fid,'%s',strjoin(reshape(names,1,[]),char(10)));
        fclose(fid);
    end
    %-------------------------------------------------------------------------%
    function x = GetValues(self)
        fid = fopen(self.fvalues,'r');
        x = fread(fid,'uint8');
        fclose(fid);
    end
    %-------------------------------------------------------------------------%
    function WriteValues(self,x)
        fid = fopen(self.fvalues,'w');
        if fid < 1
            error('Failed to open colors.dat for writing, check permissions');
        end
        fwrite(fid,x,'uint8');
        fclose(fid);
    end
    %-------------------------------------------------------------------------%
    function CheckFiles(self)
        c = {self.fnames,self.fvalues};
        for k = 1:numel(c)
            if exist(c{k},'file') ~= 2
                error('Failed to locate file %s',c{k});
            end
        end
    end
    %-------------------------------------------------------------------------%
end
%PUBLIC METHODS---------------------------------------------------------------%
end