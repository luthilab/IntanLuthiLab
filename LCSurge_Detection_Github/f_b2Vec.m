function v_b = f_b2Vec(b,s_Fs)
% Fucntion that converts the b vector containing the 4 second behavioral 
% information of the animal into numerical codes.
% Inputs:
%   b           : Behavioral b vector from veryscore 2 
%   s_Fs        : sampling frequency
%   s_NSignal   : length of signal
% See also f_ElimMA.

% Alejandro Osorio-Forero 2018
    b=b';
    m_b = nan(length(b),s_Fs*4);
%     v_b = zeros(1,s_NSignal);
    m_b(b=='n',:) = 2;
    m_b(b=='m',:) = 3;
    m_b(b=='r',:) = 1;
    m_b(b=='w',:) = 3;
    m_b(b=='f',:) = 3;
    m_b(b=='1',:) = 3;
    m_b(b=='2',:) = 2;
    m_b(b=='3',:) = 1;
    v_b = reshape(m_b',1,[]);
%     v_b(1:length(v_bT)) = v_bT;   
%      bs(b=='1'|b=='w') = 3;
%      bs(b=='2'|b=='n') = 2;
%      bs(b=='3'|b=='r') = 1;
    
end