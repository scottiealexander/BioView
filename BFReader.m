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

%PUBLIC PROPERTIES-------------------------------------------------------------%
properties
    img_path;
    chan;
    scale_factor = 1;
end
%PUBLIC PROPERTIES-------------------------------------------------------------%

%PRIVATE PROPERTIES------------------------------------------------------------%
properties (SetAccess=private)
    rep;
    siz;
    im_siz;
    nchan;
    io;
    resize;
end
%PRIVATE PROPERTIES------------------------------------------------------------%

%CONSTANT PROPERTIES-----------------------------------------------------------%
properties (Constant)
    MAX_SIZE = 1000;
end
%CONSTANT PROPERTIES-----------------------------------------------------------%


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
    %--------------------------------------------------------------------------%
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
            case {'dapi','dapi w', 'dapi_w'}
                name = self.chan{strncmpi(name,self.chan,4)};
                if isempty(name)
                    error('Channel name %s could not be found',name);
                end
            otherwise
                % error('Channel name %s could not be found',name);
            end

            kchan = find(strcmpi(name,self.chan),1,'first');
            if isempty(kchan)
                error('Channel name %s could not be found',name);
            end

            d = self.ReadChannel(kchan,kslice);
        else
            d = self.rep(:,:,kslice);
        end
    end

    %--------------------------------------------------------------------------%
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
    %--------------------------------------------------------------------------%
    function fields = Chan2Field(self,varargin)
        if ~isempty(varargin)
            if isnumeric(varargin{1})
                name = {self.chan{varargin{1}}};
            elseif ~ischar(varargin{1})
                error('Invalid input type %s', class(varargin{1}));
            end
        else
            name = self.chan;
        end

        fields = cell(numel(name),1);
        for k = 1:numel(name)
            fields{k} = regexprep(name{k}, '^[\W\d_]', '');
            fields{k} = regexprep(fields{k}, '[\W_]+','_');
        end

        if numel(fields) == 1
            fields = fields{1};
        end
    end
    %--------------------------------------------------------------------------%
end
%PUBLIC METHODS----------------------------------------------------------------%

%PRIVATE METHODS---------------------------------------------------------------%
methods (Access=private)
    %--------------------------------------------------------------------------%
    function Init(self)

        % add loci_tools.jar to javaclasspath if needed
        loci_path = fullfile(fileparts(mfilename('fullpath')),'loci_tools.jar');

        if exist(loci_path,'file') == 0
            msg = [...
                'Ahh crap, we failed to locate the loci_tools.jar file.\n '...
                'Please make sure you copied it into the folder that\n'...
                'contains this code.\nThanks!'...
            ];
            c = {{'text','string',sprintf(msg)};...
                 {'pushbutton','string','Ok','tag','Ok'}...
            };
            w = Win(c,'title','Missing loci_tools','focus','Ok');
            w.Wait();

            error('Failed to locate loci_tools at "%s"', loci_path);
        end

        if ~any(strcmpi(loci_path, javaclasspath('-dynamic')))
            javaaddpath(loci_path);
        end

        loci.common.DebugTools.enableLogging('OFF');

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
        labels = cell(raw.values.toArray);

        % GIST: in the metadata, channel labels are listed as "Channel name #N"
        % => <channel_label_string>, the issue is that there seem to always be
        % 4 "Channel name" fields even if there are only 3 channels, thus we
        % parse the channel indicies (the <N> in "Channel name #N") and use
        %  those to order our channel label list (self.chan)
        b = strncmpi(field,'channel name',12);

        cfield = field(b);
        labels = labels(b);

        % kfield: a list mapping each label in <labels> to its channel index
        % in the image (hopefully), by default mapping is just 1:N
        kfield = 1:sum(b);

        for k = 1:numel(cfield)
            re = regexp(cfield{k}, '[Cc]hannel\s*[Nn]ame\s*\#?(\d+)',...
                'tokens');

            if isempty(re)
                warning('BFReader:ChannelOrder',['Failed to find channel '...
                    'order information in file metadata, channel labels '...
                    '*MAY* be incorrect'...
                    ]);
            else
                kf = str2double(re{1});
                if isnan(kf)
                    warning('BFReader:ChannelOrderConvert',['Failed to '...
                        ' parse channel order from metadata'...
                        ]);
                else
                    kfield(k) = str2double(re{1});
                end
            end
        end

        % ensure kfield are valid indicies, if it blows up fall back to 1:N
        % and issue a warning
        if any(kfield < 1)
            kfield = kfield + (1 - min(kfield));
        end

        if any(kfield > sum(b))
            kfield = 1:sum(b);
            warning('BFReader:ChannelOrderRange',['Channel order '...
                'information in file metadata was invalid, channel labels '...
                '*MAY* be incorrect'...
                ]);
        end

        % order the labels to that labels(K) => label of channel #K
        [~,ksort] = sort(kfield);
        labels = labels(ksort);

        if numel(labels) < self.nchan
            error('Failed to find channel labels, aborting...');
        end

        % NOTE: we are assuming the if we have more labels than channels that
        % the first N labels correctly map to the first N channels, which given
        % all the schenanigans we go through above to ensure that the labels
        % are in the correct order *SHOULD* always work... we'll have to see
        % if that plays out in practice
        self.chan = labels(1:self.nchan);
    end
    %--------------------------------------------------------------------------%
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
    %--------------------------------------------------------------------------%
end
%PRIVATE METHODS---------------------------------------------------------------%

%STATIC METHODS----------------------------------------------------------------%
methods (Static=true)
    %--------------------------------------------------------------------------%
    function field = str2field(strfield)
       field = regexprep(strfield,'\W+','_');
       if field(1) == '_'
           field = field(2:end);
       end
    end
    %--------------------------------------------------------------------------%
end
%STATIC METHODS----------------------------------------------------------------%

end
