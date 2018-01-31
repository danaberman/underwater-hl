function [img_out, transmission_refined] = uw_restoration_type(...
    img_in, veiling_light, params, mask_pixels)
% A revised implementation of 
% "Diving Into Haze-Lines: Color restoration of Underwater Images",
% Dana Berman, Tali Treibitz, Shai Avidan, BMVC 2017.
% for a SPECIFIC water type.
%
% Input arguments:
%	img_in        - An underwater image, class: double.
%	veiling_light - Estimated veiling-light for the scene, class: double.
%   params        - Color correction parameters, including scattering 
%                   coefficients ratios.
%	mask_pixels   - A binary mask to ignoree certain pixels during the
%                   transmission estimation process. Used on the color charts, 
%                   so they can be used only for evaluation of the method 
%                   without affecting the estimated distance map of the scene. 
%                   Optional argument.
%
% Author: Dana Berman, 2017. 
%
% This code is provided under the attached LICENSE.md.


%% Validate input
[h, w, colors] = size(img_in);
if (colors ~= 3) % input verification
    error(['Underwater color restoration requires an RGB image, while input',...
        ' has only ',num2str(colors),' dimensions.']);
end

% Veiling light
if ~exist('veiling_light','var') || isempty(veiling_light)  
    error('Cannot perform color correction without veiling-light.');
elseif numel(veiling_light) == 3
    veiling_light = reshape(veiling_light, 1,1,3);
end

if ~exist('mask_pixels','var') || isempty(mask_pixels)  
    mask_pixels = true(h, w);
elseif ~all(size(mask_pixels) == [h, w])
    error('Mask must be the same size as the image.');
end


%% Parameters
if isfield(params,'trans_min') && ~isempty(params.trans_min) && isnumeric(params.trans_min)
    trans_min = params.trans_min;
else
    trans_min = 0.1;
end


%% Calculate compensated distances from veiling-light in RGB space
dist_from_airlight = double(zeros(h,w,colors));
for ii=1:colors
    dist_from_airlight(:,:,ii) = veiling_light(:,:,ii)- img_in(:,:,ii);
end

x = dist_from_airlight(:,:,1); x = x(mask_pixels); x = x(:);
y = dist_from_airlight(:,:,2); y = y(mask_pixels); y = y(:);
z = dist_from_airlight(:,:,3); z = z(mask_pixels); z = z(:);
x_comp = sign(x).*(abs(x).^params.betaBR);
y_comp = sign(y).*(abs(y).^params.betaBG);

dist_comp = [x_comp, y_comp, z];
radius = sqrt(sum(dist_comp.^2, 2));


%% Estimate Initial Transmission
% Cluster pixels in order to estimate their true radius.
dist_unit_radius = bsxfun(@rdivide, dist_comp, radius);
mdl = KDTreeSearcher(params.points);
ind = knnsearch(mdl, dist_unit_radius);
sz = length(params.points);

% Estimate radius and take mask into consideration.
tmp = zeros(h*w, 1);
K = accumarray(ind, radius(:), [prod(sz), 1], @max);
tmp(mask_pixels) = K(ind);
radius_new = reshape(tmp, h, w);

% Estimate transmission.
tmp = zeros(h,w); tmp(mask_pixels) = radius;
transmission_estimation = tmp./radius_new;
transmission_estimation = min(max(transmission_estimation, trans_min), 1);
transmission_estimation(~mask_pixels) = 0;

transmission_estimation(~mask_pixels) = NaN;
transmission_estimation = inpaint_nans(transmission_estimation);
% Underwater, the transmisison even at a small distance of about 1meter from
% the camera is already 0.9 or less.
transmission_estimation = 0.9*transmission_estimation;  

% Apply lower bound from the image.
trans_lower_boundR = max(1 - img_in(:,:,1)./veiling_light(1), 0);
trans_lower_boundG = max(1 - img_in(:,:,2)./veiling_light(2), 0);
trans_lower_boundB = max(1 - img_in(:,:,3)./veiling_light(3), 0);
trans_lower_bound = max(max(trans_lower_boundR.^params.betaBR, ...
    trans_lower_boundG.^params.betaBG), trans_lower_boundB);
trans_lower_bound = max(trans_lower_bound, 0.1);
transmission_estimation = max(transmission_estimation, trans_lower_bound);

% Handle low-visibility areas - defined by their Mahalanobis distance to
% the textureless body of water assumed to be the veiling-light.
if isfield(params,'textureless')
    idx_veiling = find(params.textureless);
    veiling_light_pixels = zeros(length(idx_veiling), 3);
    veiling_light_pixels(:,1) = img_in(idx_veiling);
    veiling_light_pixels(:,2) = img_in(idx_veiling+h*w);
    veiling_light_pixels(:,3) = img_in(idx_veiling+2*h*w);
    dist_mahal_self = mahal(veiling_light_pixels, veiling_light_pixels);
    mahal_thres_water = mean(dist_mahal_self) + 2*std(dist_mahal_self);
    mahal_thres_notwater = max(dist_mahal_self) + std(dist_mahal_self);
    dist_mahal = mahal(reshape(img_in, h*w,3), veiling_light_pixels);
    dist_mahal = reshape(dist_mahal, h,w);
    water_prob_func = @(x) 1 - min(1, max((x - mahal_thres_water)/(mahal_thres_notwater-mahal_thres_water), 0));
    water_map = water_prob_func(dist_mahal);
    transmission_estimation = trans_lower_bound.*water_map + (1-water_map).*transmission_estimation;
end


%% Post-processing using guided filter
guide_img = adjust_contrast(img_in, 1/2.2, 1);
guide_img(~repmat(mask_pixels,1,1,3)) = 0;
guided_filter_radius = 30;
epsilon = 0.001;
transmission_refined = guidedfilter_color(guide_img, transmission_estimation, ...
    guided_filter_radius, epsilon);

% Handle masked regions: use the average value of the mask's bottom as the
% value for the entire mask.
transmission_refined = set_chart_trans( mask_pixels, transmission_refined);


%% Restore Image
% Even if the transmission estimation is close to zero, we cannot use this
% value for restoration since it might enhance artifacts in the image.
% We limit the value to be 0.1 in the red channel, and accordingly in the
% blue channel (for which we calculated the transmission).
min_val_trans = 0.1.^params.betaBR;
transmission_refined = max(min(transmission_refined, 1), min_val_trans);
transmission_refinedRGB = repmat(transmission_refined, 1, 1, 3);
transmission_refinedRGB(:,:,1) = transmission_refinedRGB(:,:,1).^(1./params.betaBR);
transmission_refinedRGB(:,:,2) = transmission_refinedRGB(:,:,2).^(1./params.betaBG);
transmission_refinedRGB = max(min(transmission_refinedRGB, 1), 0.1);

img_out = zeros(h,w,colors);
for ii = 1:3
    dist_channel = dist_from_airlight(:,:,ii);
    trans_channel = max(transmission_refinedRGB(:,:,ii), 0.1);
    img_out(:,:,ii) = -dist_channel./trans_channel + veiling_light(ii);
end
% handle artifacts and clip the value to the [0-1] range.
img_out = img_out - max(min(img_out(:)), -0.08);
img_out = max(img_out, 0);
max_val = min( max(img_out(:)), 1.6);
img_out = img_out./max_val;
img_out = min(img_out, 1);

% Return the transmission of the red channel.
transmission_refined = transmission_refinedRGB(:,:,1);

return % function dehaze_using_similar_colors
