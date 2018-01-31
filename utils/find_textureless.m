function [img_out] = find_textureless( img, edges_path)
%Find the largest texture-less area and output a binary map

% Set threshold for contours
contour_thres = 0.005;
thres_func = @(x) (x<contour_thres);

% Perform a linear contrast stretch before calculating gradients
img = adjust_contrast(img, 1, 1); 

% Increase local contrast using CLAHE on RGB image
img_clahe = zeros(size(img));
for color_idx = 1:3
    img_clahe(:,:,color_idx) = adapthisteq(img(:,:,color_idx));
end

% Find image gradients
grad_mag = grad_func(img_clahe, edges_path);

% Down-weigh gradients in the bottom portion of the image
tmp = thres_func(grad_mag);
tmp(ceil(round(size(img,1)*0.25)):end,:) = 0;

% Find the largest connected component
img_out = find_largest_area(tmp);

end  % function find_textureless


function largest_area = find_largest_area(grad_bw)
stats = regionprops(grad_bw,'Area','PixelIdx');
getArea = @(x) x.Area;
region_areas = arrayfun(getArea, stats);
[~, max_idx] = max(region_areas);
largest_area = zeros(size(grad_bw));
largest_area(stats(max_idx).PixelIdxList) = 1;
end  % function find_largest_area


function img_grad = grad_func(img, edges_path)
model_filename = fullfile(edges_path, 'models' ,'trained.mat');
if exist(model_filename,'file'), 
    load(model_filename, 'model');
else
    curr_dir = pwd;
    % set opts for training (see edgesTrain.m)
    opts = edgesTrain();                % default options (good settings)
    opts.modelDir='models/';          % model will be in models/forest
    opts.modelFnm='modelBsds';        % model name
    opts.nPos=5e5; opts.nNeg=5e5;     % decrease to speedup training
    opts.useParfor=0;                 % parallelize if sufficient memory
    % train edge detector (~20m/8Gb per tree, proportional to nPos/nNeg)
    model = edgesTrain(opts); % will load model if already trained
    % set detection parameters (can set after training)
    model.opts.multiscale=0;          % for top accuracy set multiscale=1
    model.opts.sharpen=0;             % for top speed set sharpen=0
    model.opts.nTreesEval=4;          % for top speed set nTreesEval=1
    model.opts.nThreads=4;            % max number threads for evaluation
    model.opts.nms=0;                 % set to true to enable nms
    cd(curr_dir);
end
if size(img,3) == 1, img = repmat(img, [1, 1, 3]); end
img_grad = edgesDetect(img, model);
end  % function grad_func
