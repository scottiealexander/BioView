function data = DapiCount(pth,varargin)

% DapiCount
%
% Description:
%
% Syntax: DapiCount(pth,<options>)
%
% In:
%       pth - the path the the .vsi file
%   options:
%       kslice   - ([])
%       auto     - (false)
%       img_path - ('')
%       cell_vol - ([])
%
% Out:
%
% Updated: 2015-05-22
% Scottie Alexander
%
% Please report bugs to: scottiealexander11@gmail.com

nstep = 3;
w = 100;

opt = ParseOpts(varargin,...
    'kslice', []   ,...
    'auto' , false ,...
    'img_path', '' ,...
    'cell_vol', []  ...
    );
scale_factor = 1;
if ischar(pth)
    if isempty(opt.kslice)
        error('Slice range is unspecified');
    end
    bf_tmp = BFReader(pth);
    scale_factor = bf_tmp.scale_factor;
    d = bf_tmp.Get('dapi',opt.kslice);
elseif isnumeric(pth) && numel(size(pth)) == 3
    d = pth;
    pth = opt.img_path;
elseif strcmpi(class(bf),'bfreader')
    if isempty(opt.kslice)
        error('Slice range is unspecified');
    end
    d = pth.Get('dapi',opt.kslice);
    pth = pth.img_path;
end

tmp = d > .1;
tmp = imfill(imdilate(tmp,ones(6,6,6)),'holes');
cc = bwconncomp(tmp,26);
[~,kmx] = max(cellfun(@numel,cc.PixelIdxList));
kpx = cc.PixelIdxList{kmx};

if ~opt.auto
    cc = bwconncomp(tmp(:,:,5),26);
    s = regionprops(cc,'MinorAxisLength');
    [~,kmx] = max(cellfun(@numel,cc.PixelIdxList));
    mal = s(kmx).MinorAxisLength*.75;

    d2 = false(size(d));
    d2(kpx) = true;
    d(~d2) = 0;

    % keyboard;

    [y,x] = ind2sub([size(d,1) size(d,2)],find(d2(:,:,5)));
    p = polyfit(x,y,1);

    x = round(linspace(min(x)+w+200,max(x)-w-200,nstep));
    y = round(polyval(p,x));

    h = round(mal);

    cell_vol = 0;
    data.rect = zeros(nstep,4);
        data.count = zeros(nstep,1);
    for k = 1:nstep
        tmp = d(y(k)-h:y(k)+h,x(k)-w:x(k)+w,:);
        vol = sum(tmp(:) > 0);    
        
        bf = BFReader(tmp);
        bf.scale_factor = scale_factor;
        bf.img_path = pth;
        
        res = BioView(1:size(bf,3),bf);
        
        cell_vol = cell_vol + (vol/size(res.dapi,1));

        data.rect(k,:) = [y(k)-h y(k)+h x(k)-w x(k)+w];
        data.count(k) = size(res.dapi,1);
    end

    cell_vol = cell_vol./nstep;
else
    if isempty(opt.cell_vol) || ~isnumeric(opt.cell_vol)
        error('Single Cell Volume is requires as input in auto mode');
    end
    cell_vol = opt.cell_vol;
end

data.cell_vol = cell_vol;
data.n_cell = round(numel(kpx)./cell_vol);
data.total_vol = numel(kpx);

% [fdir,fname] = fileparts(pth);
% dapi_dir = fullfile(fdir,'dapi');
% if ~isdir(dapi_dir)
%     mkdir(dapi_dir);
% end
% fout = fullfile(dapi_dir,[fname '.mat']);
% save(fout,'-struct','data');

% n = 0;
% VolView(d,[]);
% line(x,y,'Color',[1 0 0],'LineWidth',4);

% xv = randi([x(1)+100 x(2)-100],1);
% yv = polyval(p,xv) + mal;

% xv = [xv-100 xv+100 xv+100 xv-100 xv-100];
% yv = [yv yv yv-2*mal yv-2*mal yv];

% line(xv,yv,'Color',[0 0 1],'LineWidth',4);
