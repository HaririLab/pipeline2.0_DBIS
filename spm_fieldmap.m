%-----------------------------------------------------------------------
% SPM BATCH SETUP
%
%    The Laboratory of Neurogenetics, 2015
%       By Annchen Knodt, Duke University
%       Vanessa Sochat, Duke University
%       Patrick Fisher, University of Pittsburgh
%
% Change log:
%       10/26/15: Adapted from DNS pipeline
%
%-----------------------------------------------------------------------

% % Suppress 'beep.m' name confict warning, beware that this might suppress something relevant!!
% warning('off', 'MATLAB:dispatcher:nameConflict');
% fprintf('\n**Note: MATLAB:dispatcher:nameConflict warnings have been suppressed**\n');

% % Add necessary paths for BIAC, then SPM and data folders
spmPath = '/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Scripts/Tools/spm12'; addpath(genpath(spmPath));

%Here we set some directory variables to make navigation easier
homedir='/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/'; 
datadir='/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Data/OTAGO/';

% spm('defaults','fmri');spm_jobman('initcfg');                               % Initialize SPM JOBMAN


%% IMPORT FIELDMAP
% Get DICOM images and run import
images=dir(fullfile(datadir,'/SUB_SUBJECT_SUB/DMHDS/MR_gre_field_mapping_2mm/*.dcm')); numimages = length(images);
if(length(images)>0)
    for j=1:numimages; imagearray{j}=[datadir '/SUB_SUBJECT_SUB/DMHDS/MR_gre_field_mapping_2mm/' images(j).name]; end;
    matlabbatch{1}.spm.util.dicom.data = imagearray;
    matlabbatch{1}.spm.util.dicom.root = 'flat';
    matlabbatch{1}.spm.util.dicom.outdir = {[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB']};
    matlabbatch{1}.spm.util.dicom.convopts.format = 'nii';
    matlabbatch{1}.spm.util.dicom.convopts.icedims = 0;
    clear imagearray;
    spm_jobman('run',matlabbatch);  clear matlabbatch

    % change the name to make it easier to work with. 
    % there should be 3 sDMHDS*.nii files!  typically 0006...01 & 02.nii and 0007...02.nii
    % the first 2 are magnitude images, and the first should have the shorter echo
    % the third is the phase difference image, calculated by the scanner
    images=dir([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/s*nii']);
    fprintf('***Renaming %s to magnitude_image_1.nii***\n',images(1).name);
    movefile([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/' images(1).name],[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/magnitude_image_1.nii']);
    fprintf('***Deleting magnitude_image_2 file %s***\n',images(2).name);
    delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/' images(2).name]);
    fprintf('***Renaming %s to phase_dif.nii***\n',images(3).name);
    movefile([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/' images(3).name],[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/phase_dif.nii']);
else
    fprintf('****Couldnt find fieldmap!!!****\n\n');
end

%% CALCULATE FIELDMAP
gunzip([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/tmp/epi_dt.nii.gz']);

matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.phase = {[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/phase_dif.nii,1']};
% use first magnitude images since it is the shorter echo and shoud have better contrast
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.magnitude = {[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/magnitude_image_1.nii,1']};
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.et = [4.92 7.38];
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.maskbrain = 1;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.defaults.defaultsval.blipdir = 1;  % ORIGINALLY USED -1
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
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.session(1).epi = {[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/tmp/epi_dt.nii,1']};
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.matchvdm = 1;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.sessname = 'session';
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.writeunwarped = 0;
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.anat = '';
matlabbatch{1}.spm.tools.fieldmap.presubphasemag.subj.matchanat = 0;

spm_jobman('run',matlabbatch);  clear matlabbatch     %Execute the job and clear matlabbatch

%% APPLY FIELDMAP WITH REALIGN AND UNWARP
% Get V000 images
for j=1:SUB_NUMTRS_SUB; imagearray{j}=sprintf('%s/SUB_SUBJECT_SUB/SUB_TASK_SUB/tmp/epi_dt.nii,%d',homedir,j); end; 
matlabbatch{1}.spm.spatial.realignunwarp.data.scans = imagearray;
matlabbatch{1}.spm.spatial.realignunwarp.data.pmscan = {[homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/vdm5_scphase_dif.nii']};
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
s_file = [homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/tmp/rp_epi_dt.txt']
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
    dlmwrite([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/motion_spm_rad.1D'],M,'delimiter',' ')
    dlmwrite([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/motion_spm_deg.1D'],[M(:,1:3) rot_deg],'delimiter',' ')
    dlmwrite([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/FD.1D'],FD,'delimiter',' ')
else
    fprintf('****Error: %s does NOT exist.*****\n', s_file);
end

%% clean up
gzip([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/vdm5_scphase_dif.nii']);
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/vdm5_scphase_dif.nii']);
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/magnitude_image_1.nii']); 
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/phase_dif.nii']); 
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/fpm_scphase_dif.nii']);
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/bmaskmagnitude_image_1.nii']);
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/mmagnitude_image_1.nii']);
delete([homedir '/SUB_SUBJECT_SUB/SUB_TASK_SUB/scphase_dif.nii']);

