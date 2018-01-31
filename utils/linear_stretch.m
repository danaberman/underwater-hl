function im_out = linear_stretch(im_in)
% The top 0.00001 pixels of the image are clipped to 1, and the
% image is linearly stretched.
img1 = max(im_in, [],3);   % maximum between RGB channels
img1 = img1(:);
img1 = sort(img1, 'descend');
idx = round(0.00001*length(img1));
scale = img1(idx);
im_out = im_in./scale;
im_out = min(im_out,1);