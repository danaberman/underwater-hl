function [beta_BG_pair, beta_BR_pair, n_iters, water_types] = get_water_types(beta_type)
%Return array of attenuation coefficients ratios
%
% The argument beta_type is one of the following:
%   'dense' - A dense sampling of the physical space
%   'peak'  - The value at the peak sensitivity of the camera response function, 
%             as described in the BMVC paper
%   'blurriness' - The values used by Peng and Cosman, TIP 2017
%
% Author: Dana Berman, 2017. 
%
% This code is provided under the attached LICENSE.md.


if strcmp(beta_type,'peak')
    % Only peak sensitivities, according to JERLOV water types
    beta_BG_pair = [0.4566, 0.5499, 0.6341,  0.7937,  0.9539, 1.0930, 1.1244, 1.2725];
    beta_BR_pair = [0.1118, 0.1452, 0.1745,  0.2773,  0.4051, 0.4642, 0.6515, 1.0000];
    
elseif strcmp(beta_type,'blurriness')
    % The parameters used in: "
    beta_BG_pair = [0.3210, 0.3983, 0.4624, 0.6199, 0.8424, 1.2022, 1.3652, 1.5550];
    beta_BR_pair = [0.0637, 0.0856, 0.1066, 0.1806, 0.3168, 0.4521, 0.6678, 1.0686];
    
elseif strcmp(beta_type,'dense')
    % dense sampling
    beta_BG_vec = 0.41 : 0.16 :1.46;
    beta_BR_vec = 0.1 : 0.16 : 1.15;
    p = [1.9877,   -2.4070,    0.8576];  % polyfit to ratios according to water types
    
    % create a matrix of probable combinations
    data_size = [length(beta_BR_vec), length(beta_BG_vec)];
    estimated_BR = p(1).*beta_BG_vec.^2 + p(2).*beta_BG_vec + p(3);
    diff_mat = abs (repmat(  reshape(estimated_BR,1,[]), data_size(1),1) - ...
        repmat(  reshape(beta_BR_vec,[],1), 1, data_size(2)) );
    diff_mat_in_range = diff_mat<0.35;
    
    [beta_BG_mat,beta_BR_mat] = meshgrid(beta_BG_vec, beta_BR_vec);
    beta_BG_pair = beta_BG_mat(diff_mat_in_range);
    beta_BR_pair = beta_BR_mat(diff_mat_in_range);
end

n_iters = length(beta_BR_pair);
water_types = {'I','IA','IB','II','III','C1','C3','C5','C7','C9'};

end
