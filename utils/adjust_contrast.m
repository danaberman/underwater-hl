function adj = adjust_contrast(work, gamma, flag, percen, max_val_lim)
%Contrast stretch utility function, for local hazy patches use: adjust2(img,1,1)
% flag:
% 1 - cliping 1% of the values
% 2 - No clipping, only a linear stretch of each color channel separately.  may change color balance.
% 3 - limit the change magnitude so the WB would not be drastically changed

if ~exist('flag','var') || isempty(flag), flag=1; end
if ~exist('gamma','var') || isempty(gamma), gamma=1; end
if ~exist('percen','var') || isempty(percen), percen=[0.01 0.99]; end
if ~exist('max_val_lim','var') || isempty(max_val_lim), max_val_lim=0; end

% linear contrast stretch to [0,1], identical on all colors
minn=min(work(:));
work=work-minn;
work=work./max(work(:));

% find maximum and minimum of each color channel
minw=min(min(work));
minw=minw(:);
maxw=max(max(work));
maxw=maxw(:);

% Actual mapping
if (flag == 1)  
    % Cliping 1% of the values
    contrast_lim = stretchlim(work, percen);
    contrast_lim(2,:) = max(contrast_lim(2,:), max_val_lim);
    contrast_lim(1,:) = min(contrast_lim(1,:), 1-max_val_lim);
    adj = imadjust(work, contrast_lim, [], gamma);
elseif (flag == 2) 
    % No clipping, only a linear stretch of each color channel separately
    % Note: may change color balance.
    if (size(work,3)>1)
        adj = imadjust(work, [minw'; maxw'], [0, 0, 0; 1, 1, 1], gamma);
    else
        adj = imadjust(work, [minw'; maxw'], [0; 1], gamma);
    end
elseif (flag == 3) 
    % Limit the change magnitude so the WB would not be drastically changed
    contrast_lim = stretchlim(work, percen);
    val = 0.2;
    contrast_lim(2,:) = max(contrast_lim(2,:), 0.2);
    contrast_lim(2,:) = val*contrast_lim(2,:) + (1-val)*max(contrast_lim(2,:), mean(contrast_lim(2,:)));
    contrast_lim(1,:) = val*contrast_lim(1,:) + (1-val)*min(contrast_lim(1,:), mean(contrast_lim(1,:)));
    contrast_lim(2,:) = max(contrast_lim(2,:), max_val_lim);
    contrast_lim(1,:) = min(contrast_lim(1,:), 1-max_val_lim);
    adj = imadjust(work, contrast_lim, [], gamma);
elseif (flag == 4) 
    % Cliping 1% of the values, no WB change.
    contrast_lim = stretchlim(work, percen);
    contrast_lim(2,:) = max(contrast_lim(2, :));
    contrast_lim(1,:) = min(contrast_lim(1, :));
    adj = imadjust(work, contrast_lim, [], gamma);
elseif (flag == 5) % extra limit to the red channel
    contrast_lim = stretchlim(work, percen);
    contrast_lim(2,:) = max(contrast_lim(2,:), max_val_lim);
    contrast_lim(1,:) = min(contrast_lim(1,:), 1-max_val_lim);
    contrast_lim(2,1) = max(contrast_lim(2,1), 0.9); % extra limit to red channel
    adj = imadjust(work, contrast_lim, [], gamma);
end
