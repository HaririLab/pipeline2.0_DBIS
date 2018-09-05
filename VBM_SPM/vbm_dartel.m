%-----------------------------------------------------------------------
% RUN DARTEL FOR VBM
% FWHM moothing kernel size subbed in from bash script (SUB_KS_SUB)
% output goes into anat/VBM_DARTEL_(kernelSize)mm
%
% 11/5/15 ARK
%-----------------------------------------------------------------------

spm_path = '/cifs/hariri-long/Scripts/Tools/spm12'; addpath(genpath(spm_path)); % includes SUIT toolbox
spm8path = '/cifs/hariri-long/Scripts/Tools/spm8';
spm('defaults','fmri')
spm_jobman('initcfg');

if strcmp('SUB_JUSTVBM_SUB','no')
    % copy T1 to SUIT dir
	copyfile('SUB_T1_SUB','SUB_OUTDIR_SUB/HighRes.nii.gz');
	gunzip('SUB_OUTDIR_SUB/HighRes.nii.gz');
end

if strcmp('SUB_JUSTPREP_SUB','no')
    
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {['SUB_OUTDIR_SUB/HighRes.nii,1']};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {[spm_path '/tpm/TPM.nii,1']};
    matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
    matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 1];
    matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {[spm_path '/tpm/TPM.nii,2']};
    matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
    matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 1];
    matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {[spm_path '/tpm/TPM.nii,3']};
    matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[spm_path '/tpm/TPM.nii,4']};
    matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[spm_path '/tpm/TPM.nii,5']};
    matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[spm_path '/tpm/TPM.nii,6']};
    matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0];
    matlabbatch{2}.spm.tools.dartel.warp1.images = {
        {'SUB_OUTDIR_SUB/rc1HighRes.nii,1'}
        {'SUB_OUTDIR_SUB/rc2HighRes.nii,1'}
        }';
    matlabbatch{2}.spm.tools.dartel.warp1.settings.rform = 0;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(1).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(1).rparam = [4 2 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(1).K = 0;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(1).template = {[spm8path '/toolbox/vbm8/Template_1_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(2).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(2).rparam = [2 1 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(2).K = 0;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(2).template = {[spm8path '/toolbox/vbm8/Template_2_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(3).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(3).rparam = [1 0.5 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(3).K = 1;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(3).template = {[spm8path '/toolbox/vbm8/Template_3_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(4).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(4).rparam = [0.5 0.25 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(4).K = 2;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(4).template = {[spm8path '/toolbox/vbm8/Template_4_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(5).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(5).rparam = [0.25 0.125 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(5).K = 4;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(5).template = {[spm8path '/toolbox/vbm8/Template_5_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(6).its = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(6).rparam = [0.25 0.125 1e-06];
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(6).K = 6;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.param(6).template = {[spm8path '/toolbox/vbm8/Template_6_IXI550_MNI152.nii']};
    matlabbatch{2}.spm.tools.dartel.warp1.settings.optim.lmreg = 0.01;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.optim.cyc = 3;
    matlabbatch{2}.spm.tools.dartel.warp1.settings.optim.its = 3;
    matlabbatch{3}.spm.tools.dartel.mni_norm.template = {''};
    matlabbatch{3}.spm.tools.dartel.mni_norm.data.subj.flowfield = {'SUB_OUTDIR_SUB/u_rc1HighRes.nii'};
    matlabbatch{3}.spm.tools.dartel.mni_norm.data.subj.images = {
        'SUB_OUTDIR_SUB/c1HighRes.nii'
        'SUB_OUTDIR_SUB/c2HighRes.nii'
        };
    matlabbatch{3}.spm.tools.dartel.mni_norm.vox = [1.5 1.5 1.5];
    matlabbatch{3}.spm.tools.dartel.mni_norm.bb = [NaN NaN NaN
        NaN NaN NaN];
    matlabbatch{3}.spm.tools.dartel.mni_norm.preserve = 1; % 1= preserve amount, "modulation"
    matlabbatch{3}.spm.tools.dartel.mni_norm.fwhm = [SUB_KS_SUB SUB_KS_SUB SUB_KS_SUB];
	%% run TIV
	matlabbatch{4}.spm.util.tvol.matfiles = {'SUB_OUTDIR_SUB/HighRes_seg8.mat'};
	matlabbatch{4}.spm.util.tvol.tmax = 3;
	matlabbatch{4}.spm.util.tvol.mask = {[spm_path '/tpm/mask_ICV.nii,1']};
	matlabbatch{4}.spm.util.tvol.outf = 'TIV';

    spm_jobman('run',matlabbatch);  clear matlabbatch
	
    cd('SUB_OUTDIR_SUB/');

    %%clean up
    gzip('SUB_OUTDIR_SUB/c1HighRes.nii');
    delete('SUB_OUTDIR_SUB/u*nii');
    delete('SUB_OUTDIR_SUB/c*nii');
    delete('SUB_OUTDIR_SUB/HighRes.*');
    delete('SUB_OUTDIR_SUB/rc*');
    
end

exit

