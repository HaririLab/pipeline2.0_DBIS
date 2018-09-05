% Writes slspec file from JSON dwi file using SliceTiming. 
% Need slspec for eddy_cuda slice-to-volume correction (in mrtrix dwipreproc)
% Code from fslwiki
% modify this script to run through all subjects on its own first
addpath(strcat('/cifs/hariri-long/Studies/DBIS/Imaging/sourcedata/sub-SUB_NUM_SUB/dwi')); 
mkdir '/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/mrtrix/sub-SUB_NUM_SUB'
AP_json = 'sub-SUB_NUM_SUB_acq-AP_dwi.json';
fp = fopen(AP_json,'r');
fcont = fread(fp);
fclose(fp);
cfcont = char(fcont');
i1 = strfind(cfcont,'SliceTiming');
i2 = strfind(cfcont(i1:end),'[');
i3 = strfind(cfcont((i1+i2):end),']');
cslicetimes = cfcont((i1+i2+1):(i1+i2+i3-2));
slicetimes = textscan(cslicetimes,'%f','Delimiter',',');
[sortedslicetimes,sindx] = sort(slicetimes{1});
mb = length(sortedslicetimes)/(sum(diff(sortedslicetimes)~=0)+1);
slspec = reshape(sindx,[mb length(sindx)/mb])'-1;
dlmwrite('/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/mrtrix/sub-SUB_NUM_SUB/slspec.txt',slspec,'delimiter',' ','precision','%3d');