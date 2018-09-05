

addpath(genpath(regexprep('SUB_MOUNT_SUB/Scripts/Tools/spm12','DBIS.01','DNS.01'))); % includes SUIT toolbox
spm('defaults','fmri')
spm_jobman('initcfg');

copyfile('SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/HighRes.nii.gz','SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/VBM_DARTEL_SUB_KS_SUBmm/');
gunzip('SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/VBM_DARTEL_SUB_KS_SUBmm/HighRes.nii.gz')
	
%% run TIV
matlabbatch{1}.spm.util.tvol.matfiles = {'SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/VBM_DARTEL_SUB_KS_SUBmm/HighRes_seg8.mat'};
matlabbatch{1}.spm.util.tvol.tmax = 3;
matlabbatch{1}.spm.util.tvol.mask = {regexprep('SUB_MOUNT_SUB/Scripts/Tools/spm12/tpm/mask_ICV.nii,1','DBIS.01','DNS.01')};
matlabbatch{1}.spm.util.tvol.outf = 'TIV';

spm_jobman('run_nogui',matlabbatch);

delete('SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/VBM_DARTEL_SUB_KS_SUBmm/HighRes.*');
movefile('SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/TIV.csv','SUB_MOUNT_SUB/Analysis/SPM/Processed/SUB_SUBJECT_SUB/anat/VBM_DARTEL_SUB_KS_SUBmm');
