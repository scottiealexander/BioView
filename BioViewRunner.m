function DATA = BioViewRunner(DATA, BFR)
% BioViewRunner
%
% Description: run BioView counting process
%
% Syntax: BioViewRunner(data, bf)
%
% In:
%       data - an initialized (but can be empty) BioView data struct
%       bf   - a BFReader object for the file to use for counting
%
% Out:
%       data - the user entered counting data
%
% Updated: 2016-07-13
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

%TODO:
%   1) dapi processing button (calc all stats)
%       - user selected/defined threshold for volume calculation
%       - manual (user selected image width and number of images)
%       - auto (with cell volume entry)
%       - allow saving to previous csv file

theta = linspace(0,2*pi,100);
CIRC_RAD = 14;
COLORS = [0 1 0; 1 0 0; 0 0 1; 1 1 0; 1 0 1; 0 1 1];
if numel(BFR.chan) > size(COLORS,1)
    COLORS = [COLORS; mge.Color(numel(BFR.chan)-size(COLORS,1)+1)];
end

%scroll wheel state enumeration
SLICE = 0;
CONTRAST = 1;
ZOOM = 2;

ZCUR = 1;
ZOOM_STATE = 1;
PTCUR = NaN;
HPTCUR = NaN;

% make sure to add the overlap channel
cChan = [BFR.Chan2Field(); {'overlap'}];

CIRC_RAD = ceil(CIRC_RAD*sqrt(BFR.scale_factor));

KZ = GetSliceRange();

if isempty(KZ)
    return
end

d = BFR.Get(cChan{1},KZ);

SCR = get(0,'ScreenSize');
pos = ScaleImage();

h = figure('NumberTitle','off','Name','BioView','Units','pixels',...
    'MenuBar','none','Position',pos,...
    'KeyPressFcn',@Keypress,...
    'KeyReleaseFcn',@Keyrelease,...
    'WindowScrollWheelFcn',@ScrollSlice,...
    'WindowButtonDownFcn',@StartCircleMv...
    );

ax = axes('Units','Normalized','Position',[0 0 1 1]);

hi = imagesc(d(:,:,1));
colormap(ax,gray(64));
set(ax,'Box','off','XTick',[],'YTick',[]);

str = sprintf('[%d %d]',round(get(ax,'CLim')*100));

c = {{'text','string','Current Channel:'},...
     {'listbox','string',upper(cChan),'tag','chan','Callback',@ChangeChan};...
     {'text','string','Show Labels:'},...
     {'listbox','string',upper(cChan),'tag','labl','Max',3,'Callback',@ShowLabel};...
     {'text','string','Label Color:'},...
     {'pushbutton','string','Select','tag','color_select','Callback',@SelectColor};...
     {'text','string','Z-Plane:'},...
     {'edit','string','00','tag','zplane','Enable','inactive'};...
     {'text','string','Contrast Range:'},...
     {'edit','string',str,'tag','contrast','Enable','inactive'};...
     {'pushbutton','string','Load Count Data','tag','load','Callback',@LoadData},...
     {'pushbutton','string','Save Count Data','tag','save','Callback',@SaveData};...
     {'pushbutton','string','User Guide','tag','help','Callback',@DisplayHelp},...
     {'pushbutton','string','Close','tag','close','Callback',@CloseFcn} ...
    };

w = Win(c,'title','BioView Controller','grid',true,'Position',[-Inf,0]);

SetZPlaneLabel();
ShowLabel();

try
    w.Wait();
catch me
    fprintf('Caught error!\n');
    rethrow(me);
end

for k = 1:numel(cChan)
    DATA.(cChan{k}) = DATA.(cChan{k}).c;
end

%------------------------------------------------------------------------------%
function DeleteLabel(obj,evt)
    kc = w.GetElementProp('chan','Value');
    delete(HPTCUR);
    DATA.(cChan{kc}).h(PTCUR) = [];
    DATA.(cChan{kc}).c(PTCUR,:) = [];
    HPTCUR = NaN;
end
%------------------------------------------------------------------------------%
function StartCircleMv(obj,evt)
    typ = get(obj,'SelectionType');
    kc = w.GetElementProp('chan','Value');
    if ~isempty(DATA.(cChan{kc}).h)
        cen = DATA.(cChan{kc}).c;
        pt = GetMouseLocation();
        [dst,kpt] = min(sqrt((cen(:,1)-pt(1)).^2+(cen(:,2)-pt(2)).^2));
        if dst <= CIRC_RAD+2
            PTCUR = kpt;
            HPTCUR = DATA.(cChan{kc}).h(kpt);
            if strcmp(typ,'alt')
                pt = GetMouseLocation(1);
                mnu = uicontextmenu;
                sub_mnu = uimenu(mnu,'label','Delete Label',...
                    'Callback',@DeleteLabel);
                set(mnu,'Position',pt,'Visible','on');
            else
                set(h,'WindowButtonUpFcn',@StopCircleMv,...
                      'WindowButtonMotionFcn',@MoveCircle);
            end
        end
    end
end
%------------------------------------------------------------------------------%
function StopCircleMv(obj,evt)
    pt = GetMouseLocation();
    set(h,'WindowButtonUpFcn',[],...
          'WindowButtonMotionFcn',[]);
    kc = w.GetElementProp('chan','Value');
    DATA.(cChan{kc}).c(PTCUR,:) = [pt ZCUR+KZ(1)];
    PTCUR = NaN;
end
%------------------------------------------------------------------------------%
function MoveCircle(obj,evt)
    pt = GetMouseLocation();
    set(HPTCUR,'XData',(CIRC_RAD*cos(theta))+pt(1),...
               'YData',(CIRC_RAD*sin(theta))+pt(2));
end
%------------------------------------------------------------------------------%
function b = PanOn(varargin)
    pan(h,'on');

    ToggleListeners(h, 'off');

    if isempty(varargin) || ~strcmpi(class(varargin{1}),'function_handle')
        fscroll = @ScrollSlice;
    else
        fscroll = varargin{1};
    end
    set(h,'KeyPressFcn',@Keypress,...
          'KeyReleaseFcn',@Keyrelease,...
          'WindowScrollWheelFcn',fscroll);
end
%------------------------------------------------------------------------------%
function PanOff(varargin)
    set(h,'KeyPressFcn',@Keypress,...
          'KeyReleaseFcn',@Keyrelease,...
          'WindowScrollWheelFcn',@ScrollSlice,...
          'WindowButtonDownFcn',@StartCircleMv);

    ToggleListeners(h, 'on');
    pan(h,'off');
end
%------------------------------------------------------------------------------%
function ToggleListeners(hfig, state)
%NOTE: update for HG2 changes to event.proplistener class
% this fix courtesy of Yair Altman:
% http://undocumentedmatlab.com/blog/enabling-user-callbacks-during-zoom-pan

    fix_url = 'http://undocumentedmatlab.com/blog/enabling-user-callbacks-during-zoom-pan';

    hm = uigetmodemanager(hfig);

    re = regexp(version('-release'), '(?<d>\d{4})(?<l>\w+)','names');
    if isempty(re)
        error('Failed to parse Matlab version string');
    end

    ver_date = str2double(re.d);

    if ver_date < 2014 || (ver_date == 2014 && re.l < 'b')
        if islogical(state) || isnumeric(state)
            if state
                state = 'on';
            else
                state = 'off';
            end
        elseif ischar(state)
            if ~any(strcmpi(state, {'on','off'}))
                error('%s is not a valid state', state);
            end
        else
            error('Invalid state given, must be logical or string');
        end
        try
            set(hm.WindowListenerHandles, 'Enable', state);
        catch me
            fprintf(2,'****************************************************\n');
            fprintf(2,'Failed to disable property listeners for mode manager\n');
            fprintf(2,'****************************************************\n');
            fprintf(2,'Matlab raised the following error:\n')
            rethrow(me);
        end
    else
        if ischar(state)
            switch lower(state)
                case 'on'
                    state = true;
                case 'off'
                    state = false;
                otherwise
                    error('%s is not a valid state', state);
            end
        elseif isnumeric(state)
            state = logical(state);
        elseif ~islogical(state)
            error('Invalid state given, must be logical or string');
        end
        try
            [hm.WindowListenerHandles.Enabled] = deal(state);
        catch me
            if ver_date > 2015 || (ver_date == 2015 && re.l > 'a')
                msg = ['This Matlab version is unsupported and undocumented features may have changed.\n\t'...
                       'Please see this webpage\n\t<a href="%s">[LINK]</a>\n\tfor possible fixes.'
                      ];
                msg = sprintf(msg, fix_url);
            else
                msg = 'Please restart Matlab and try again.';
            end
            fprintf(2,'****************************************************\n');
            fprintf(2,'Failed to disable property listeners for mode manager:\n\t%s\n', msg);
            fprintf(2,'****************************************************\n');
            fprintf(2,'Matlab raised the following error:\n')
            rethrow(me);
        end
    end
end
%------------------------------------------------------------------------------%
function ScrollWheelFcn(state)
    switch state
    case SLICE
        fscroll = @ScrollSlice;
    case CONTRAST
        fscroll = @ScrollContrast;
    case ZOOM
        fscroll = @ScrollZoom;
    otherwise
        error('Invaid state supplied (%d)\n',state);
    end
    set(h,'WindowScrollWheelFcn',fscroll);
end
%------------------------------------------------------------------------------%
function ChangeChan(varargin)
    kc = w.GetElementProp('chan','Value');
    if ~strcmpi(cChan{kc},'overlap')
        tmp = {{'text','string','Changing channel...'}};
        wtmp = Win(tmp,'Title','Please wait');
        d = BFR.Get(cChan{kc},KZ);
        wtmp.Close();
        w.SetElementProp('labl','Value',kc);
        Redraw;
    else
        kl = GetValidChannels();
        if numel(kl) < 3
            w.SetElementProp('labl','Value',kc);
        else
            w.SetElementProp('labl','Value',kl);
        end
    end
    ShowLabel;
    set(h,'Visible','on');
end
%------------------------------------------------------------------------------%
function kl = GetValidChannels
    kl = find(strncmpi('o',cChan,1),1,'first');
    for k = 1:numel(cChan)
        if ~isempty(DATA.(cChan{k}).c)
            kl(end+1,1) = k;
        end
    end
    kl = unique(kl);
end
%------------------------------------------------------------------------------%
function ShowLabel(varargin)
    kl = w.GetElementProp('labl','Value');
    DeleteCircles;
    for k = 1:numel(kl)
        tmp = DATA.(cChan{kl(k)}).c;
        for k2 = 1:size(tmp,1)
            DATA.(cChan{kl(k)}).h(end+1,1) = AddCircle(tmp(k2,:),kl(k));
        end
    end
end
%------------------------------------------------------------------------------%
function CloseFcn(obj,evt)
    if ishandle(h)
        close(h);
    end
    w.BtnPush(obj,true);
end
%------------------------------------------------------------------------------%
function pt = GetMouseLocation(varargin)
    %returns the (x,y) locations of the mouse pointer in axes units
    pos = get(h,'Position');

    %mouse position relative to top-left of figure in pixels
    pt = get(0,'PointerLocation')-pos(1:2); %ref = BL
    if ~isempty(varargin)
        return;
    end
    pt(2) = pos(4)-pt(2); %ref = TL

    xl = get(ax,'XLim');
    yl = get(ax,'YLim');

    %datapoints-per-pixel
    dpp = [xl(2)-xl(1) yl(2)-yl(1)] ./ pos(3:4);

    %click location in datapoints plus offset for origin (not 0,0 anymore)
    pt = (pt.*dpp)+[xl(1) yl(1)];
end
%------------------------------------------------------------------------------%
function Keypress(obj,evt)
    switch lower(evt.Key)
    case 'shift'
        ScrollWheelFcn(CONTRAST);
    case 'control'
        ScrollWheelFcn(ZOOM);
    case 'w'
        po = pan(h);
        if strcmpi(po.Enable,'on')
            PanOff();
        else
            PanOn();
        end
    case 'a'
        pt = GetMouseLocation;
        kc = w.GetElementProp('chan','Value');

        %only allow overlap labeling if two channel actually have been labeled
        if strcmpi(cChan{kc},'overlap') && numel(GetValidChannels) < 3
            return;
        end
        DATA.(cChan{kc}).h(end+1,1) = AddCircle(pt,kc);
        DATA.(cChan{kc}).c(end+1,:) = [pt ZCUR+KZ(1)];
    case {'s','l'}
        if ~isempty(evt.Modifier) && ismember('control',evt.Modifier)
            if lower(evt.Key)=='s'
                SaveData();
            else
                LoadData();
            end
        end
    case 'h'
        if ~isempty(evt.Modifier) && ismember('control',evt.Modifier)
            DisplayHelp();
        end
    otherwise

        kl = NaN;
        chan_labels = num2cell(sprintf('%d', 1:numel(cChan)));

        switch lower(evt.Key)
        case chan_labels
            % key press on number that is valid channel
            kl = str2double(evt.Key);
        case 'o'
            % overlap channel
            kl = find(strcmpi('overlap', cChan), 1, 'first');
        otherwise
        end

        if ~isnan(kl)
            if ~isempty(evt.Modifier) && ismember('control',evt.Modifier)
                w.SetElementProp('labl','Value',kl);
                ShowLabel();
            else
                w.SetElementProp('chan','Value',kl);
                ChangeChan();
            end
        end
    end
end
%------------------------------------------------------------------------------%
function Keyrelease(obj,evt)
    warning('off','MATLAB:modes:mode:InvalidPropertySet');
    switch lower(evt.Key)
    case {'shift','control'}
        ScrollWheelFcn(SLICE);
    otherwise
        %pass
    end
end
%------------------------------------------------------------------------------%
function ScrollSlice(obj,evt)
    %-1 = up, 1 = down
    ZCUR = ZCUR - evt.VerticalScrollCount;
    if ZCUR > numel(KZ)
        ZCUR = numel(KZ);
    elseif ZCUR < 1
        ZCUR = 1;
    end
    Redraw;
end
%------------------------------------------------------------------------------%
function ScrollContrast(obj,evt)
    %-1 = up, 1 = down
    clim = get(ax,'CLim');
    step = (clim(2)-clim(1))*.1;
    clim = [clim(1) clim(2)-(evt.VerticalScrollCount*-step)];
    set(ax,'CLim',clim);
    SetContrastLabel(clim);
end
%------------------------------------------------------------------------------%
function ScrollZoom(obj,evt)
    if ZOOM_STATE > 10 && evt.VerticalScrollCount < 0
        %don't allow zooming to greater than 10x
    else
        zoom(ax,ZOOM_STATE*(1.1^-evt.VerticalScrollCount));
    end
end
%------------------------------------------------------------------------------%
function Redraw
    set(hi,'CData',d(:,:,ZCUR));
    SetZPlaneLabel;
    drawnow;
end
%------------------------------------------------------------------------------%
function SetZPlaneLabel
    w.SetElementProp('zplane','String',sprintf('%d',KZ(ZCUR)));
end
%------------------------------------------------------------------------------%
function SetContrastLabel(clim)
    str = sprintf('[%d %d]',round(clim*100));
    w.SetElementProp('contrast','string',str);
end
%------------------------------------------------------------------------------%
function pos = ScaleImage
    szi = size(d);

    if szi(1) > szi(2)
        h = max([szi(1) SCR(4)]) - 55;
        w = h * (szi(2)/szi(1));
    else
        w = min([szi(2) SCR(3)]) - 67;
        h = w * (szi(1)/szi(2));
    end

    l = floor((SCR(3)/2)-(w/2));
    b = floor(((SCR(4)-50)/2)-(h/2));

    pos = [l,b,w,h];
end
%------------------------------------------------------------------------------%
function SelectColor(varargin)
    kc = w.GetElementProp('chan','Value');
    col = uisetcolor(COLORS(kc,:),'Channel color');
    COLORS(kc,:) = col;
    ShowLabel();
end
%------------------------------------------------------------------------------%
function hcir = AddCircle(pt,kcol)
    x = (CIRC_RAD*cos(theta))+pt(1);
    y = (CIRC_RAD*sin(theta))+pt(2);
    hcir = line(x,y,'Color',COLORS(kcol,:),'LineWidth',2,'Parent',ax);
end
%------------------------------------------------------------------------------%
function DeleteCircles
    for k = 1:numel(cChan)
        delete(DATA.(cChan{k}).h);
        DATA.(cChan{k}).h = [];
    end
end
%------------------------------------------------------------------------------%
function kz = GetSliceRange()

    kz = [];
    n = BFR.im_siz(3);

    ks = num2str(floor(n/3));
    ke = num2str(n);

    ctmp = {...
        {'text','string','Please select the Z-range to load:'},...
        {};...
        {'text','string','First slice:'},...
        {'edit','string',ks,'tag','kstart','valfun',{'inrange',1,n-1,true}};...
        {'text','string','Last slice:'},...
        {'edit','string',ke,'tag','kend','valfun',{'inrange',2,n,true}};...
        {'pushbutton','string','Load','callback',@CheckSliceRange},...
        {'pushbutton','string','Cancel','validate',false}...
    };

    wtmp = Win(ctmp, 'title', 'Slice selection', 'focus','kstart');
    wtmp.Wait();

    if strcmpi(wtmp.res.btn, 'load')
        kz = wtmp.res.kstart:wtmp.res.kend;
    end

    %--------------------------------------------------------------------------%
    function CheckSliceRange(obj, varargin)
        kstart = str2double(wtmp.GetElementProp('kstart', 'string'));
        kend = str2double(wtmp.GetElementProp('kend', 'string'));
        tag = 'kstart';
        msg = '';
        if isnan(kstart)
            msg = sprintf('"%s" is not a valid slice index!',...
                wtmp.GetElementProp('kstart'));
        elseif isnan(kend)
            tag = 'kend';
            msg = sprintf('"%s" is not a valid slice index!',...
                wtmp.GetElementProp('kend'));
        elseif kstart >= kend
            msg = 'Starting slice index *MUST* be less than the ending slice index';
        end
        if ~isempty(msg)
            tmp = {...
                {'text','string', msg};...
                {'pushbutton','string','OK'}...
            };
            tmp = Win(tmp, 'title', 'Error: Slice selection');
            tmp.Wait();
            wtmp.SetFocus(tag);
        else
            wtmp.BtnPush(obj,true);
        end
    end
    %--------------------------------------------------------------------------%
end
%------------------------------------------------------------------------------%
function SaveData(varargin)
    [fdir,fname] = fileparts(BFR.img_path);
    cpt = {'*.mat','Matlab data file (*.mat for saving ROIs)';...
           '*.csv','Excel format (*.csv for final cell counts)'};
    [fname,fdir] = uiputfile(cpt,'Save Counting Data',fullfile(fdir,[fname '.mat']));
    if isequal(fname,0) || isequal(fdir,0)
        return;
    else
        pth = fullfile(fdir,fname);
        [~,~,ext] = fileparts(pth);
        tmp = struct();
        if strcmpi(ext,'.mat')
            for k = 1:numel(cChan)
                tmp.(cChan{k}) = DATA.(cChan{k}).c;
            end
            tmp.path_im = DATA.path_im;
            save(pth,'-struct','tmp');
        elseif strcmpi(ext,'.csv')
            for k = 1:numel(cChan)
                tmp.(cChan{k}) = size(DATA.(cChan{k}).c,1);
            end
            tmp.file = DATA.path_im;
            CSVWrite(pth,tmp);
        end
    end
end
%------------------------------------------------------------------------------%
function CSVWrite(pth,s)
    fid = fopen(pth,'a');
    if fid < 1
        msg = ['Failed to open file %s\nEither the filepath is invalid or ',...
               'the file is already open in another application (if so '   ,...
               'please close the file).\nIf this problem persists try'     ,...
               'restarting matlab.'...
              ];
        error(msg, pth);
    end
    try
        if exist(pth,'file') && getfield(dir(pth),'bytes') > 0
            fseek(fid,0,'eof');
        else
            fprintf(fid,[repmat('%s,',1,numel(cChan)+1) '\n'],'file',cChan{:});
        end
        fprintf(fid,'%s',s.file);
        for k = 1:numel(cChan)
            fprintf(fid,',%d',s.(cChan{k}));
        end
        fprintf(fid,'\n');
    catch me
        fclose(fid);
        rethrow(me);
    end

    fclose(fid);
end
%------------------------------------------------------------------------------%
function LoadData(varargin)
    pth = GetImagePath('*.mat');
    if ~isempty(pth)
        s = load(pth);
        if ~strcmp(DATA.path_im,s.path_im)
            tmp = ['The file you selected does not match the current image.\n',...
                   'Would you like to load the new image?'];
            tmp = {{'text','string',str},...
                   {};...
                   {'pushbutton','string','Yes'},...
                   {'pushbutton','string','No'}...
                  };
            tmp = Win(tmp,'title','Image mismatch');
            tmp.Wait();
            if strcmpi(tmp.res.btn,'no')
                return;
            else
                cur_chan = cChan{w.GetElementProp('chan','Value')};
                BFR = BFReader(s.path_im);
                d = BFR.Get(cur_chan,KZ);
                SetZPlaneLabel();
            end
        end
        DeleteCircles;
        for k = 1:numel(cChan)
            DATA.(cChan{k}).c = s.(cChan{k});
        end
        ShowLabel();
    end
end
%------------------------------------------------------------------------------%
function DisplayHelp(varargin)
    pth = fullfile(fileparts(mfilename('fullpath')),'help.txt');
    if exist(pth,'file')
        fid = fopen(pth,'r');
        str = transpose(fread(fid,'*char'));
        fclose(fid);
    else
        str = 'ERROR: Unable to locate BioView help file';
    end
    ctmp = {{'text','string',str,'HorizontalAlignment','left'};...
        {'pushbutton','string','Close'}...
       };
    pause(.01);
    tmp = Win(ctmp,'Title','BioView User Guide');
    drawnow;
end
%------------------------------------------------------------------------------%
end
