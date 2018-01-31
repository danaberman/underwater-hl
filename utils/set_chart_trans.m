function [ trans_out ] = set_chart_trans( mask_positive, trans_in )
%Set a uniform transmission value for the entire chart:
%use the average value of the mask's bottom as the value for the entire mask
%   Inputs:
%   mask_positive - mask where the color chart pixels are zero and the rest
%   (scene pixels) are one
%   trans_in - a 1D transmission map

% structure element for same pixel and the one below
SE = strel('arbitrary',[0,0,0;0,1,0;0,1,0]);

% calculate value for each chart separately:
region_labels = bwlabel(~mask_positive);
trans_out = trans_in;
for region_idx = 1:max(region_labels(:))
    mask_region = region_labels == region_idx; % mask for a single chart
    mask_bottom_border = imdilate(mask_region, SE,'same') & ~mask_region;
    trans_region = mean(trans_in(mask_bottom_border));
    trans_out(mask_region) = trans_region;
end

end
