%-----------------------------------------------------------------------
% RUN SUIT BATCH FOR CEREBELLAR VBM
%
% Utilizing SUIT toolbox, this script preprocesses high resolution t1
% images (cropping/ segmentation/ normalization/ and smoothing)
%
% 11/3/15 ARK
% 8/25/17 adapted for Dunedin, ARK
%-----------------------------------------------------------------------

spmPath = '/cifs/hariri-long/Scripts/Tools/spm12'; addpath(genpath(spmPath)); % includes SUIT toolbox

if strcmp('SUB_JUSTSUIT_SUB','no')
    % copy T1 to SUIT dir
	copyfile('SUB_T1_SUB','SUB_OUTDIR_SUB/HighRes.nii.gz');
	gunzip('SUB_OUTDIR_SUB/HighRes.nii.gz');
end

if strcmp('SUB_JUSTPREP_SUB','no')
    
    spm('defaults','fmri')
    spm_jobman('initcfg');
    
    % isolate cerebellum from rest of brain
    matlabbatch{1}.spm.tools.suit.isolate.source = {{'SUB_OUTDIR_SUB/HighRes.nii,1'}};
    matlabbatch{1}.spm.tools.suit.isolate.bb = [-76 76
        -108 -6
        -75 11];  % default
    matlabbatch{1}.spm.tools.suit.isolate.cerebral_range = 3.5;
    matlabbatch{1}.spm.tools.suit.isolate.cerebellar_range = 2.5;
    % create field maps for normalising to SUIT's template using DARTEL
    matlabbatch{2}.spm.tools.suit.normalise_dartel.subjND.gray = {'SUB_OUTDIR_SUB/HighRes_seg1.nii,1'};
    matlabbatch{2}.spm.tools.suit.normalise_dartel.subjND.white = {'SUB_OUTDIR_SUB/HighRes_seg2.nii,1'};
    matlabbatch{2}.spm.tools.suit.normalise_dartel.subjND.isolation = {'SUB_OUTDIR_SUB/c_HighRes_pcereb_corr.nii,1'};
    % normalize
    matlabbatch{3}.spm.tools.suit.reslice_dartel.subj.affineTr = {'SUB_OUTDIR_SUB/Affine_HighRes_seg1.mat'};
    matlabbatch{3}.spm.tools.suit.reslice_dartel.subj.flowfield = {'SUB_OUTDIR_SUB/u_a_HighRes_seg1.nii,1'};
    matlabbatch{3}.spm.tools.suit.reslice_dartel.subj.resample = {'SUB_OUTDIR_SUB/HighRes_seg1.nii,1'};
    matlabbatch{3}.spm.tools.suit.reslice_dartel.subj.mask = {'SUB_OUTDIR_SUB/c_HighRes_pcereb_corr.nii,1'};
    matlabbatch{3}.spm.tools.suit.reslice_dartel.jactransf = 1; % this is modulation: 1="preserve amount" (modulation), presumably "preserve concentration" (no modulation) = 0
    
    matlabbatch{3}.spm.tools.suit.reslice_dartel.K = 6;
    matlabbatch{3}.spm.tools.suit.reslice_dartel.bb = [-70 -100 -75
        70 -6 11];
    matlabbatch{3}.spm.tools.suit.reslice_dartel.vox = [2 2 2];
    matlabbatch{3}.spm.tools.suit.reslice_dartel.interp = 1;
    matlabbatch{3}.spm.tools.suit.reslice_dartel.prefix = 'wc';
    % now use SPM's standard smooth routine, using both a 4 and an 8mm kernel bc we'll want to look at both
    matlabbatch{4}.spm.spatial.smooth.data = {'SUB_OUTDIR_SUB/wcHighRes_seg1.nii,1'};
    matlabbatch{4}.spm.spatial.smooth.fwhm = [4 4 4];
    matlabbatch{4}.spm.spatial.smooth.dtype = 0;
    matlabbatch{4}.spm.spatial.smooth.im = 0;
    matlabbatch{4}.spm.spatial.smooth.prefix = 's4';
    matlabbatch{5}.spm.spatial.smooth.data = {'SUB_OUTDIR_SUB/wcHighRes_seg1.nii,1'};
    matlabbatch{5}.spm.spatial.smooth.fwhm = [8 8 8];
    matlabbatch{5}.spm.spatial.smooth.dtype = 0;
    matlabbatch{5}.spm.spatial.smooth.im = 0;
    matlabbatch{5}.spm.spatial.smooth.prefix = 's8';
	
    spm_jobman('run_nogui',matlabbatch);
    
    % clean up
    delete('SUB_OUTDIR_SUB/a*');
    delete('SUB_OUTDIR_SUB/c_*');
    delete('SUB_OUTDIR_SUB/HighRes*nii');
    delete('SUB_OUTDIR_SUB/HighRes*nii.gz');
    delete('SUB_OUTDIR_SUB/m*HighRes*');
    delete('SUB_OUTDIR_SUB/u_*');
    delete('SUB_OUTDIR_SUB/wc*');
    
end

exit

