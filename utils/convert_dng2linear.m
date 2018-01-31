function [out, info] = convert_dng2linear(filename, apply_color)
% This function reads a UNCOMPRESSED DNG file and returns a linear RGB image.
% Based on the following RAWguide by Rob Summer: 
% https://users.soe.ucsc.edu/~rcsumner/rawguide/RAWguide.pdf

warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
warning off MATLAB:imagesci:tiffmexutils:libtiffWarning
warning off MATLAB:imagesci:tifftagsread:badTagValueDivisionByZero

if ~exist('apply_color','var') || isempty(apply_color)
    apply_color = 0;
end

% Read file info
info = imfinfo(filename);
infoRaw = info.SubIFDs{1};

% Read file
t = Tiff(filename,'r');
offsets = getTag(t,'SubIFD');
setSubDirectory(t,offsets(1));
cfa = read(t);
close(t);

% White Balance
wb_multipliers = (info.AsShotNeutral).^-1;
wb_multipliers = wb_multipliers/wb_multipliers(2);

if strcmp(infoRaw.PhotometricInterpretation,'CFA')
    % Crop to only valid pixels, if necessary
    x_origin = infoRaw.ActiveArea(2)+1; % +1 due to MATLAB indexing
    width = infoRaw.DefaultCropSize(1);
    y_origin = infoRaw.ActiveArea(1)+1;
    height = infoRaw.DefaultCropSize(2);
    raw = double(cfa(y_origin:y_origin+height-1,x_origin:x_origin+width-1));
    
    if isfield(infoRaw,'LinearizationTable')
        ltab=infoRaw.LinearizationTable;
        raw = ltab(raw+1);
    end
    
	% Adjust Black and White levels
    black = infoRaw.BlackLevel(1); 
    saturation = infoRaw.WhiteLevel;
    lin_bayer = (raw-black)/(saturation-black);
    lin_bayer = max(0,min(lin_bayer,1));
    
    % Demosaic - reduce resolution by half and avoid artifacts ('rggb')
    lin_rgb = zeros(floor(size(lin_bayer,1)/2), floor(size(lin_bayer,2)/2), 3);
    lin_rgb(:,:,1) = lin_bayer(1:2:end, 1:2:end);
    lin_rgb(:,:,3) = lin_bayer(2:2:end, 2:2:end);
    lin_rgb(:,:,2) = 0.5.*lin_bayer(2:2:end, 1:2:end) + 0.5.*lin_bayer(1:2:end, 2:2:end);
    
    % White Balance: green is unchanges, balance only red and blue
    lin_rgb(:,:,1) = lin_rgb(:,:,1).*wb_multipliers(1);
    lin_rgb(:,:,3) = lin_rgb(:,:,3).*wb_multipliers(3);
        
elseif strcmp(infoRaw.PhotometricInterpretation,'LinearRaw')
    raw = im2double(cfa);
    
    % White Balance
    for ii = 1:3, raw(:,:,ii) = raw(:,:,ii).*wb_multipliers(ii); end
    lin_rgb = raw;
end

% Color Space Conversion
if apply_color
    xyz2cam = reshape(info.ColorMatrix2,3,3)';
    % Define transformation matrix from sRGB space to XYZ space
    srgb2xyz = [0.4124564 0.3575761 0.1804375;
        0.2126729 0.7151522 0.0721750;
        0.0193339 0.1191920 0.9503041];
    rgb2cam = xyz2cam * srgb2xyz;
    rgb2cam = rgb2cam ./ repmat(sum(rgb2cam, 2), 1, 3);
    cam2rgb = rgb2cam^-1;
    
    lin_srgb = apply_cmatrix(lin_rgb,cam2rgb);
    lin_srgb = max(0,min(lin_srgb,1));
    out = lin_srgb;
else
    out = lin_rgb;
end

out = out./max(out(:));
