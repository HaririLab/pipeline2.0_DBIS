%% SPM FIELDMAP
%% When creating pipeline2.0, we decided that SPM did the best fieldmap correction
%% 6/26/18: when we adapted the pipeline to the DCC / BIDS format, somehow the fieldmap correction got reversed!
%%	We really don't know why this happened, but since changing blipdir (presubphasemag module) from 1 to -1 solves the issue and results in results practically identical to previous, we will just go with it!
%%  As a result, the resulting field map (vdm5) image is the inverse of what it was before.
%%  Also, the vdm5 image has additional features outside the front of the brain that weren't there before (maybe they were masked or soemthign?) and this is perhaps why the resulting epi isn't 100% identical to before, but it shouldn't really matter!

spmPath = '/cifs/hariri-long/Scripts/Tools/spm12'; addpath(genpath(spmPath));

%Here we set some directory variables to make navigation easier
homedir='SUB_OUTDIR_SUB'; 
datadir='/cifs/hariri-long/Studies/DBIS/Imaging/sourcedata/sub-SUB_SUBJECT_SUB/fmap';

% spm('defaults','fmri');spm_jobman('initcfg');                               % Initialize SPM JOBMAN


%% IMPORT FIELDMAP
% there are 3 fieldmap "run" files
% the first 2 are magnitude images, and the first should have the shorter echo
% the third is the phase difference image, calculated by the scanner
if(exist([datadir '/sub-SUB_SUBJECT_SUB_magnitude1.nii.gz'])&&exist([datadir '/sub-SUB_SUBJECT_SUB_magnitude2.nii.gz'])&&exist([datadir '/sub-SUB_SUBJECT_SUB_phasediff.nii.gz']))
	copyfile([datadir '/*.nii.gz'],homedir);
	gunzip([homedir '/sub-SUB_SUBJECT_SUB_magnitude*.nii.gz' ]);
	gunzip([homedir '/sub-SUB_SUBJECT_SUB_phase*.nii.gz' ]);
else
    fprintf('****Couldnt find fieldmap!!!****\n\n');
end

%% CALCULATE FIELDMAP
gunzip([homedir '/tmp/epi_dt.nii.gz']);

matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.phase = {[homedir '/sub-SUB_SUBJECT_SUB_phasediff.nii,1']};
% use first magnitude images since it is the shorter echo and shoud have better contrast
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.magnitude = {[homedir '/sub-SUB_SUBJECT_SUB_magnitude1.nii,1']};
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.et = [4.92 7.38];
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.maskbrain = 1;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.blipdir = -1;  % USED 1 on BIAC, but -1 on DCC / BIDS format
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.tert = 36.3;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.epifm = 0;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.ajm = 0;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.uflags.method = 'Mark3D';
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.uflags.fwhm = 10;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.uflags.pad = 0;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.uflags.ws = 1;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.template = {[spmPath '/toolbox/FieldMap/T1.nii']};
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.fwhm = 5;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.nerode = 2;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.ndilate = 4;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.thresh = 0.5;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.mflags.reg = 0.02;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.session(1).epi = {[homedir '/tmp/epi_dt.nii,1']};
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.matchvdm = 1;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.sessname = 'session';
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.writeunwarped = 0;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.anat = '';
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.matchanat = 0;

spm_jobman('run',matlabbatch);  clear matlabbatch     %Execute the job and clear matlabbatch

%% APPLY FIELDMAP WITH REALIGN AND UNWARP
% Get V000 images
for j=1:SUB_NUMTRS_SUB; imagearray{j}=sprintf('%s/tmp/epi_dt.nii,%d',homedir,j); end; 
matlabbatch{1}.spm.spatial.realignunwarp.data.scans = imagearray;
matlabbatch{1}.spm.spatial.realignunwarp.data.pmscan = {[homedir '/vdm5_scsub-SUB_SUBJECT_SUB_phasediff.nii']};
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.quality = 0.9;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.sep = 4;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.fwhm = 5;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.rtm = 0;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.einterp = 2;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.ewrap = [0 0 0];
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.weight = {''};
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.basfcn = [12 12];
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.regorder = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.lambda = 100000;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.jm = 0;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.fot = [4 5];
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.sot = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.uwfwhm = 4;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.rem = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.noi = 5;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.expround = 'Average';
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.uwwhich = [2 1];
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.rinterp = 4;
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.mask = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.prefix = 'u';

spm_jobman('run',matlabbatch);  clear matlabbatch     %Execute the job and clear matlabbatch

%% Convert motion parameters, and get FD 
s_file = [homedir '/tmp/rp_epi_dt.txt']
if exist(s_file,'file')
    M=dlmread(s_file);
	rot_deg=zeros(size(M,1),3); % rotation in degrees
	rot_mm=zeros(size(M,1),3); % rotation in mm
    FD=zeros(size(M,1),1);
    for i=2:size(M,1)
        for j=4:6
            % (note that SPM displays rotation params in degrees but STORES them in radians in the rp files!!)
			% convert the rotation params from radians to mm by calculating displacement on the surface of a sphere of
            % radius 50 mm, which is the approx. mean dist. from the cerebral cortex to the center of the head (Power 2011)
			% also convert params to degrees to save for posterity
            rot_deg(i,j-3)=M(i,j)*180/pi;
			rot_mm(i,j-3)=M(i,j)*50;
        end
        FD(i)=abs(M(i-1,1)-M(i,1))+abs(M(i-1,2)-M(i,2))+abs(M(i-1,3)-M(i,3))+abs(rot_mm(i-1,1)-rot_mm(i,1))+abs(rot_mm(i-1,2)-rot_mm(i,2))+abs(rot_mm(i-1,3)-rot_mm(i,3));
    end
    dlmwrite([homedir '/motion_spm_rad.1D'],M,'delimiter',' ')
    dlmwrite([homedir '/motion_spm_deg.1D'],[M(:,1:3) rot_deg],'delimiter',' ')
    dlmwrite([homedir '/FD.1D'],FD,'delimiter',' ')
else
    fprintf('****Error: %s does NOT exist.*****\n', s_file);
end

%% clean up
gzip([homedir '/vdm5_scsub-SUB_SUBJECT_SUB_phasediff.nii']);
delete([homedir '/vdm5_scsub-SUB_SUBJECT_SUB_phasediff.nii']);
delete([homedir '/sub-SUB_SUBJECT_SUB_magnitude*.nii*']); 
delete([homedir '/sub-SUB_SUBJECT_SUB_phasediff.nii*']); 
delete([homedir '/fpm_scsub-SUB_SUBJECT_SUB_phasediff.nii']);
delete([homedir '/bmasksub-SUB_SUBJECT_SUB_magnitude1.nii']);
delete([homedir '/msub-SUB_SUBJECT_SUB_magnitude1.nii']);
delete([homedir '/scsub-SUB_SUBJECT_SUB_phasediff.nii']);

