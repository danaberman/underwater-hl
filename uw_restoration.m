function [img_out, trans_out, A, estimated_water_type] = uw_restoration(...
    img_name, img_dir, edges_path, max_width, result_dir, verbose)
% A revised implementation of 
% "Diving Into Haze-Lines: Color restoration of Underwater Images",
% Dana Berman, Tali Treibitz, Shai Avidan, BMVC 2017.
%
% Input arguments:
%   img_name   - File name of the image (without directory).
%   img_dir    - Folder containing image.
%   edges_path - Path to Structured Edge Detection Toolbox V3.0.
%   max_width  - Maximal width of output image.
%   result_dir - Folder to save results in.
%   verbose    - Boolean, whether to print verbose output and save
%                intermediate results.
%
% Author: Dana Berman, 2017. 
%
% This code is provided under the attached LICENSE.md.

%% Method params
fid = fopen('TR500.txt', 'r');
uwhl_params.points = cell2mat(textscan(fid,'%f %f %f')) ;
fclose(fid);
uwhl_params.trans_min = 0.01;

% Attenuation coefficient (beta) ratios to test.
[beta_BG_pair, beta_BR_pair, n_iters, water_types] = get_water_types('peak');

%% Image specific handling
% Get current image name.
[~, image_name, ext] = fileparts(img_name);
if verbose, disp(['Image name: ', image_name]); end

% Determine whether the file is raw. If it is, we have to handle it
% differently.
if any(strcmpi(ext, {'.CR2','.NEF','.ORF', '.ARW'})), is_raw = true;
else, is_raw = false;
end

% Read input image, according to its type.
% If it's raw, we have to use appropriate conversion from raw to sRGB.
if is_raw,
    dng_filename = fullfile(img_dir, [image_name, '_linear_demosaiced.dng']);
    if ~exist(dng_filename, 'file'),  % File doesn't exists, create it
        adc_path = '"C:\Program Files (x86)\Adobe\Adobe DNG Converter.exe"';
        if ~exist(adc_path, 'file'),
            error('Could not find Adobe DNG converter');
        end
        adc_cmd = [adc_path, ' -u -l ', img_dir, img_name];
        system(adc_cmd);
        % The output filename is by default the filename with .dng extension.
        % Rename it to emphasize the file type
        movefile(fullfile(img_dir, [image_name, '.dng']), dng_filename);

    end
    
    [img_linear, convert_info] = convert_dng2linear(dng_filename, false);
    % Contrast stretch, with very small clipping, to obtain a better dynamic 
    % range. All of the color channel undergo the same transformation.
    img_linear = linear_stretch(img_linear) ;
    
    % Contrast stretch, without clipping, to obtain a better dynamic range.
    img_in = adjust_contrast( img_linear, 1, 3, 0 );
    img_in = min(max(img_in,0),1);
    
    % Raw files often have a high resolution, we will reduce the resolution
    % to have a width of max_width pixels.
    if size(img_linear, 2) > max_width,
        img_in = imresize(img_linear, [NaN, max_width]);
    end
    
    % Contrast stretch, with clipping. Despite the loss of linearity, in
    % dark scenes this step is quite helpful.
    contrast_limit = stretchlim(img_in,[0, 0.999]);
    img_in = img_in./max(contrast_limit(2,:));
    img_in = max(min(img_in, 1), 0);
    
else
    % sRGB images do not require special conversion.
    img_in = im2double(imread(fullfile(img_dir, img_name)));
    % Contrast stretch, to obtain a better dynamic range.
    img_in = adjust_contrast(img_in, 1, 3);
end

[h, w, ~] = size(img_in);

% If color charts are visible in the image (to test the reconstruction
% accuracy), we wish to mask them during the transmission estimation and
% later set the chart's transmission based on transmission values at its bottom. 
% Get binary mask of chart/ no-chart, in the correct scale.
resolution_str = [num2str(h), '_', num2str(w)];
mask_filenme = fullfile(img_dir, [image_name, '_mask_', resolution_str, '.mat']);
if exist(mask_filenme, 'file'), load(mask_filenme, 'mask');
else, mask = true(h,w);
end

% Prepare dir prefixes and output cell array.
save_dir = fullfile(result_dir, [image_name, '_']);
if verbose,
    % Verbose results will be saved in this directory, e.g. restoration results 
    % using all water types, and veiling-light.
    result_dir_verbose = fullfile(result_dir, 'all');
    if ~exist(result_dir_verbose,'dir'), mkdir(result_dir_verbose); end
    save_dir_verbose = fullfile(result_dir_verbose, [image_name, '_']);
else
    save_dir_verbose = '';
end
corrected = cell(1, n_iters);

% If the input is raw, convert image to sRGB color space for comparison and 
% for veiling light estimation.
if is_raw
    img_in_rgb = convert_linear2rgb(img_in, convert_info);
    imwrite(img_in_rgb, [save_dir, 'input_rgb.jpg']);
    % Apply contrast stretch on input image as a baseline.
    img_in_rgb_adj = im2uint8(adjust_contrast(img_in_rgb, 1, 1, [], 0.5));
    imwrite(img_in_rgb_adj, [save_dir,'input_rgb_contrast.jpg']);
else
    img_in_rgb = img_in;
end

% Estimate veiling-light (value + textureless map).
[A, uwhl_params.textureless] = estimate_veiling_light(img_in, img_in_rgb, ...
    edges_path, verbose, save_dir_verbose);

% Quality measure - define helper func and binary mask to measure how
% much the image adheres to the Gray-World assumption.
gray_world_dev = @(x) std(mean(x, 1));
not_sky_map = ~uwhl_params.textureless;

% Iterate over different water types (i.e. different attenuation coeffs).
for i_water_type = 1:n_iters
    if verbose, disp(['Iter #',num2str(i_water_type)]); end
    uwhl_params.betaBR = beta_BR_pair(i_water_type);
    uwhl_params.betaBG = beta_BG_pair(i_water_type);
    
    % Restore the colors, assuming a particular water type.
    [out_img, out_trans] = uw_restoration_type(img_in, A, uwhl_params, mask);
    
    % Convert restored image to sRGB color space.
    if is_raw
        out_img = convert_linear2rgb(out_img, convert_info);
    end
    img_adj = adjust_contrast(out_img, 1, 5, [0.001, 0.999], 0.8);
    
    % Save the restored image and the transmission (per water type).
    if verbose
        file_suffix = ['_beta_', ...
            strrep(['BR',num2str(uwhl_params.betaBR,'%1.2f'), ...
            '_BG',num2str(uwhl_params.betaBG,'%1.2f')],'.','-')];
        img_file_suffix = [save_dir_verbose, 'UWHL_img', file_suffix];
        imwrite(im2uint8(img_adj), [img_file_suffix, '.jpg']);
        transfile_suffix = strrep(img_file_suffix, 'img', 'trans');
        imwrite(im2uint8(out_trans), jet(256), [transfile_suffix, '.jpg']);
    end
        
    % Update output cell array.
    corrected{i_water_type}.trans = out_trans;
    corrected{i_water_type}.out_img = out_img;
    corrected{i_water_type}.out_img_adj = img_adj;
    
    % Measure restoration quality (will be used for comparison between
    % water types later)
    not_sky_pixels = reshape(img_adj(repmat(not_sky_map, [1,1,3])), [], 3);
    corrected{i_water_type}.gw_notsky = gray_world_dev(not_sky_pixels);
    
end  % Loop: iterations on beta ratios

% Quality measure to estimate the best water type
vals = cellfun( @(x) x.gw_notsky, corrected);
[~, idx_sorted] = sort(vals, 'ascend');
% Do not take into consideration beta ratios that their water
% transmission is too high. Specifically, require the RED transmission
% average to be larger by 0.1 on objects than in water.
get_trans_r = @(x) mean(x.trans(not_sky_map)) - mean(x.trans(~not_sky_map));
trans_r_all_beta = cellfun(get_trans_r, corrected);
trans_diff_thres = 0.1;
idx_to_erase = find(trans_r_all_beta < trans_diff_thres);
while( length(idx_to_erase) == length(trans_r_all_beta))
    trans_diff_thres = trans_diff_thres*0.5;
    idx_to_erase = find(trans_r_all_beta < trans_diff_thres);
end
idx_sorted = setdiff(idx_sorted, idx_to_erase, 'stable');

% The output is the first index after sorting.
selected_idx = idx_sorted(1);
if verbose
    disp(['Estimated water type is: ', water_types{selected_idx}])
end

% Set the output variables
estimated_water_type = water_types{selected_idx};
img_out = corrected{selected_idx}.out_img_adj;
trans_out = corrected{selected_idx}.trans;
