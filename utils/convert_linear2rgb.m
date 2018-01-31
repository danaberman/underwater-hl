function [nl_srgb, info] = convert_linear2rgb(img, info, wb_mode, neutral_color)
% This function takes a linear image in the camera's color space and converts it
% to an sRGB image and applies gamma correction.
% Based on the following RAWguide by Rob Summer: 
% https://users.soe.ucsc.edu/~rcsumner/rawguide/RAWguide.pdf

warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
warning off MATLAB:imagesci:tiffmexutils:libtiffWarning
warning off MATLAB:imagesci:tifftagsread:badTagValueDivisionByZero

if exist('info','var') && ~isempty(info) && isstruct(info)
    
    % Color Space Conversion
    xyz2cam = reshape(info.ColorMatrix2,3,3)';
    % Define transformation matrix from sRGB space to XYZ space
    srgb2xyz = [0.4124564 0.3575761 0.1804375;
        0.2126729 0.7151522 0.0721750;
        0.0193339 0.1191920 0.9503041];
    rgb2cam = xyz2cam * srgb2xyz;
    rgb2cam = rgb2cam ./ repmat(sum(rgb2cam,2),1,3);
    cam2rgb = rgb2cam^-1;
    
    lin_srgb = apply_cmatrix(img,cam2rgb);
    lin_srgb = max(0,min(lin_srgb,1));
    img = lin_srgb;
end

% Gamma Correction
nl_srgb = img.^(1/2.2);