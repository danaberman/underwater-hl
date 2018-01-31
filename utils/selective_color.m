function [ img_out ] = selective_color(img, map)
%Return an image with only the pixels whose map value is true in color and
%the rest in grayscale

img_gray = rgb2gray(img);
% brighten image a bit
img_gray = im2double(img_gray).^0.8;

img_out = repmat(img_gray, [1, 1, 3]);
map = repmat(map, [1, 1, 3]);
img_out(map) = img(map);

end

