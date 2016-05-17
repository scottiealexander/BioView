classdef BFReader < handle

% BFReader
%
% Description: Bio-Formats image reader class
%
% Syntax: bf = BFReader(path_img)
%
% In:
%       path_img - the path to a vsi file as a string
%
% Out:
%       bf - an instance of the BFReader class
%
% Methods:
%       Get  - get an image stack from a given channel
%       size - returns the size of the image stack in pixels (X,Y,Z)
%
% Updated: 2016-01-07
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

%PUBLIC PROPERTIES------------------------------------------------------------%
properties
    img_path;
    chan;
    scale_factor = 1;
end
%PUBLIC PROPERTIES------------------------------------------------------------%

%PRIVATE PROPERTIES-----------------------------------------------------------%
properties (SetAccess=private)
    rep;
    siz;
    im_siz;
    nchan;
    io;    
    resize;
end
%PRIVATE PROPERTIES-----------------------------------------------------------%

%CONSTANT PROPERTIES----------------------------------------------------------%
properties (Constant)
    MAX_SIZE = 1000;
end
%CONSTANT PROPERTIES----------------------------------------------------------%

%PUBLIC METHODS---------------------------------------------------------------%
methods
    %-------------------------------------------------------------------------%
    function self = BFReader(inp)
        jpath = fullfile(fileparts(mfilename('fullpath')),'loci_tools.jar');
        javaaddpath(jpath);

        loci.common.DebugTools.enableLogging('OFF');

        if ischar(inp)
            self.img_path = inp;
            self.io = true;
            self.Init();
        elseif isnumeric(inp)
            self.img_path = '';
            self.io = false;
            self.rep = inp;
            self.chan = {'none'};
            self.nchan = 1;
            self.siz = size(self.rep);
        end        
    end
    %-------------------------------------------------------------------------%
    function d = Get(self,name,varargin)
    % d = bf.Get(name,[kslice]=<all>)
    %
    % In:
    %       name     - the channel name as a string
    %       [kslice] - indicies of the z-plane slices to get
    %
    % Out:
    %       d - an image stack with numel(kslice) slices
        if isempty(varargin) || isempty(varargin{1})
            kslice = self.siz(3);
        elseif isnumeric(varargin{1})
            if all(varargin{1} > 0 & varargin{1} <= self.siz(3))
                kslice = varargin{1};
            else
                error('Invalid slice range requested');    
            end
        end
        if self.io
            switch lower(name)
            case {'gfp','fitc'}
                name = 'fitc';
            case {'cfos','fos','tritc'}
                name = 'tritc';
            case {'dapi','dapi w'}
                name = self.chan{strncmpi(name,self.chan,4)};
                if isempty(name)
                    error('Channel name %s could not be found',name);
                end
            otherwise
                % error('Channel name %s could not be found',name);
            end
            kchan = find(strcmpi(name,self.chan),1,'first');        
            d = self.ReadChannel(kchan,kslice);
        else
            d = self.rep(:,:,kslice);
        end
    end
    %-------------------------------------------------------------------------%
    function varargout = size(self,varargin)
    % s = size([dim]=<all>)
    %
    % In:
    %       [dim] - the dimention to return the size of
    %
    % Out:
    %       s - the size of the requested dimention(s)
    %        
        if isempty(varargin) || isempty(varargin{1})
            tmp = self.siz;
        else
            ndim = numel(varargin{1});
            d = zeros(1,ndim);
            for k = 1:ndim
                if varargin{1}(k) > numel(self.siz)
                    tmp(k) = 1;
                else
                    tmp(k) = self.siz(varargin{1}(k));
                end
            end
        end
        if nargout > 1
            varargout = num2cell([tmp ones(1,nargout-numel(tmp))]);
        else
            varargout{1} = tmp;
        end
    end
    %-------------------------------------------------------------------------%
end
%PUBLIC METHODS---------------------------------------------------------------%

%PRIVATE METHODS--------------------------------------------------------------%
methods (Access=private)
    %-------------------------------------------------------------------------%
    function Init(self)
        self.rep = loci.formats.ChannelFiller();
        self.rep = loci.formats.ChannelSeparator(self.rep);
        self.rep.setId(self.img_path);

        self.im_siz = [self.rep.getSizeY(), self.rep.getSizeX(), self.rep.getSizeZ()];
        
        if self.im_siz(3) < 2
           msg = 'Image appears to only contain a single Z-plane, this may cause errors later on';
           warning('BFReader:NoZStack',msg); 
        end
        
        if self.im_siz(1) > self.MAX_SIZE
            self.resize = true;
            self.scale_factor = 1/(self.im_siz(1)./self.MAX_SIZE);
            self.siz(1) = self.MAX_SIZE;
            self.siz(2) = floor(self.im_siz(2)*self.scale_factor);
            self.siz(3) = self.im_siz(3);            
        else
            self.resize = false;
            self.scale_factor = 1;
            self.siz = self.im_siz;
        end 

        self.nchan = self.rep.getSizeC();

        %get the label for each channel
        raw = self.rep.getSeriesMetadata();
        if isempty(raw)
            raw = self.rep.getGlobalMetadata();
            warning('BFReader:ReadMetadataError','Series metadata appears to be empty, image may be missing auxiliary files');
        end
        field = cell(raw.keySet.toArray);
        value = cell(raw.values.toArray);

        b = strncmpi(field,'channel name',12);
        [~,ksort] = sort(field(b));
        value = value(b);
        value = value(ksort);
        
        if numel(value) < self.nchan
            error('Failed to find channel labels, aborting...');
        end
        
        self.chan = unique(value(1:self.nchan));
        
        if numel(self.chan) ~= self.nchan
           error('Failed to recover from missing metadata... aborting');
        end
    end
    %-------------------------------------------------------------------------%
    function d = ReadChannel(self,kchan,kslice)

        pxt = self.rep.getPixelType();
        bpp = loci.formats.FormatTools.getBytesPerPixel(pxt);
        fp  = loci.formats.FormatTools.isFloatingPoint(pxt);
        ltl = self.rep.isLittleEndian();
 

        d = zeros([self.siz(1:2) numel(kslice)]);
        for k = 1:numel(kslice)
            idx = self.rep.getIndex(kslice(k)-1,kchan-1,0);
            pln = self.rep.openBytes(idx);
            tmp = loci.common.DataTools.makeDataArray2D(...
                       pln, bpp, fp, ltl, self.im_siz(1)...
                       );
            if self.resize
                % self.scale_factor = self.scale_factor * (1+(400/self.im_siz(1)));
                % tmp = tmp(1:end-400,1:end-400,:);
                d(:,:,k) = imresize(tmp,self.siz(1:2));
            else
                d(:,:,k) = tmp;
            end
        end
        d = d - min(d(:));
        d = d ./ max(d(:));
    end
    %-------------------------------------------------------------------------%
end
%PRIVATE METHODS--------------------------------------------------------------%

end