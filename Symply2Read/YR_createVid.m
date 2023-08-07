function YR_createVid( h )
%YR_CREATEVID Summary of this function goes here
%   Detailed explanation goes here

%% create preview image
video = axes('parent', h.tabVid, 'position', [0.05 0 .9 .9]);
imagevid = image(video, zeros(352, 288, 3));
preview(h.cam, imagevid)
end

