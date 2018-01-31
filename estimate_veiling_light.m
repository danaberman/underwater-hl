function [A, textureless_map] = estimate_veiling_light(img_in_lin, ...
    img_in_rgb, edges_path, verbose, result_dir_verbose)
%Estimate veiling-light and a textureless map of the image (the background)
% Often the water area is textureless.
%
% A revised implementation of 
% "Diving Into Haze-Lines: Color restoration of Underwater Images",
% Dana Berman, Tali Treibitz, Shai Avidan, BMVC 2017.
%
% Input arguments:
%   img_in_lin - Image to sample values from (linear image if working with raw).
%	img_in_rgb - Image to find texture-less region in, (sRGB if input is raw).
%   edges_path - Path to Structured Edge Detection toolbox.
%   verbose    - Boolean, whether to save an illustration of the veiling-light.
%   result_dir_verbose - Path to save the illustration of the veiling-light.
%
% Output arguments:
%	A - Estimated veiling-light for the scene, class: double.
%	textureless_map - region without texture, from which the veiling light
%	                  is measured.
%
% Author: Dana Berman, 2017. 
%
% This code is provided under the attached LICENSE.md.

if ~exist('verbose', 'var'), verbose = false; end  % save veiling visualization

textureless_map = logical(find_textureless(img_in_rgb, edges_path));

% For robustenss, the veiling-light is the median value of the texture-less 
% region in terms of luminosity.
img_in_gray = rgb2gray(img_in_rgb);
candidates = img_in_gray(textureless_map);

% sort candidates to find median idx.
[~, candidates_idx] = sort(candidates);
idx_median = candidates_idx(round(numel(candidates)/2));
A = zeros(1,1,3);
for color_idx=1:3
    img_tmp = img_in_lin(:,:,color_idx);
    img_tmp = img_tmp(textureless_map);
    % Estimate the veiling-light to be the median value in the region.
    A(color_idx) = img_tmp(idx_median);
end

% If verbose, plot the veiling-light region by using a graylevel image with
% only the veiling-light colored.
if verbose,
    img_veiling = im2uint8(selective_color(img_in_rgb, textureless_map));
    imwrite(img_veiling, [result_dir_verbose, 'veiling_light.jpg']);
end

end
