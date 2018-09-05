#!/bin/bash
###QUESTIONS FOR ANNCHEN
#runs faster if gunzip before running dwipreproc
#.mif.gz to save space but takes longer (in mrview too)

###NOTES
#matlab write to file
#*trace out directory structure
#as root: sudo -S mount -t cifs //oit-nas-fe12.oit.duke.edu/data_commons-hariri-long /home/vcm/dcc_vm/ -o username=mls99,password=,domain=WIN,uid=1000,gid=1000
#symlinks: replace ln -s with cp (server doesn't do symlinks)
#install gui version mrtrix on vm? qt5, openGL issues
#single tissue bc we only have b0 and b3000
#try just using first 500 subjects first (in pipeline2.0_DBIS/config) (-40 for template subset)
# # ran using : for id in `awk -F, '{print $1}' $H/Scripts/pipeline2.0_DBIS/config/first500scans.txt | sed 's/DMHDS//g' `; do sbatch $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_ALL.sh $id; done
#batch submit:
# # cd $H/Studies/DBIS/Imaging/derivatives/mrtrix
# # for id in sub*; do sbatch $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_ALL.sh $id; done
# # remember to change $1 to subject, not subnum
#maybe switch back t0 mem 24000 and don't specify nthreads? ~43min
###################################################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/mrtrix_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/mrtrix_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
# SBATCH --mem=30000 #for dwiintensitynorm, spherical deconvolution, and population_template use 30000
# SBATCH --partition gpu-common --gres=gpu:1 #for eddy in dwipreproc
# SBATCH -c 1
#SBATCH --mem=24000
#SBATCH -p scavenger
#SBATCH -x dcc-econ-01
# SBATCH -p common-large #for population_template (takes several days and makes a big temp dir so annoying if it gets bumped on scavenger)
# -- END GLOBAL DIRECTIVE -

###########################################ONE SUBJECT#############################################

# export PATH=/dscrhome/mls99/.local/bin/cuda-7.5/bin:$PATH
# export LD_LIBRARY_PATH=/dscrhome/mls99/.local/bin/cuda-7.5/lib:/dscrhome/mls99/.local/bin/cuda-7.5/lib64:$LD_LIBRARY_PATH

# # NOTE: input just subject number
# SUBNUM=$1
# subject=sub-$SUBNUM
# subject=$1
# SUBNUM=`echo $subject | sed 's/DMHDS/sub-/g'`
# topDir=$H/Studies/DBIS/Imaging
# outDir=$topDir/derivatives/mrtrix/$subject
# sourceDir=$topDir/sourcedata/$subject/dwi
# scriptsDir=$H/Scripts/pipeline2.0_DBIS

# cd $outDir
# rm mrtrix*
# cp $scriptsDir/json2slspec.m .

# dwidenoise $sourceDir/*AP_dwi.nii.gz $outDir/dwi_denoised.mif
# mrdegibbs $outDir/dwi_denoised.mif $outDir/dwi_denoised_unringed.mif -axes 0,1 #originally had axes 0,2 (coronal instead of axial - problem?)
# mrconvert $outDir/dwi_denoised_unringed.mif $outDir/dwi_denoised_unringed.nii.gz

# # Loop through template MATLAB script replacing subject
# if [[ ! -e $outDir/slspec.txt ]]; then
	# for i in ${scriptsDir}'/json2slspec.m'; do
		# sed -e 's@SUB_NUM_SUB@'$SUBNUM'@g' <$i> json2slspec.m
	# done
# # run script to get slice order for subject
	# /opt/apps/matlabR2016a/bin/matlab -nodisplay -singleCompThread < json2slspec.m
# fi

# # there are 7 b0s from AP and 3 b0s from PA so take just the first 3 from AP and combine with PA to get b0s.mif
# fslroi $sourceDir/*AP_dwi.nii.gz $outDir/b0_AP_first 0 1
# fslroi $sourceDir/*AP_dwi.nii.gz $outDir/b0_AP_last 65 2 #structure of AP is 0 3000(x64) 0 0 0 0 0 0
# fslroi $outDir/dwi_denoised_unringed.nii.gz $outDir/AP_dwi_mod 0 67 #remove extra b0s
# mrcat $outDir/b0_AP_first.nii.gz $outDir/b0_AP_last.nii.gz $sourceDir/*PA_dwi.nii.gz $outDir/b0s.mif -axis 3 #MLS: correct axis? leaving out flag determines axis # from images
# # remove last 4 0s from AP bvec and bval to have only 3 b0s (bval should be same for all subjects; bvec not - 3 lines)
# cat $sourceDir/*AP_dwi.bval | while read line; do
	# echo ${line::-8} >> $outDir/AP_dwi_mod.bval
# done
# cat $sourceDir/*AP_dwi.bvec | while read line; do
	# echo ${line::-8} >> $outDir/AP_dwi_mod.bvec 
# done

# # NOTE: chose to set mporder=8 as it is the low end of the FSL help page suggestion to use N/4 to N/2 where N is the number of slices in a volume (30 in this case). Shouldn't make much difference in subjects with low motion anyway.
# # NOTE: set slm=linear following mrtrix recommendation because sampling b3000 shell strongly asymmetric
# dwipreproc $outDir/AP_dwi_mod.nii.gz $outDir/dwi_preproc.mif -pe_dir AP -rpe_pair -se_epi $outDir/b0s.mif -json_import $sourceDir/*AP_dwi.json -fslgrad $outDir/AP_dwi_mod.bvec $outDir/AP_dwi_mod.bval -tempdir $outDir/tmp/ -eddy_options "--mporder=8 --slm=linear --slspec=$outDir/slspec.txt"

# #3) temporary brain mask
# dwi2mask $outDir/dwi_preproc.mif $outDir/dwi_temp_mask.mif

# # 4) bias field correction
# # echo "original parameters: dwibiascorrect -ants $outDir/dwi_preproc.mif $outDir/dwi_unbias.mif"
# dwibiascorrect -ants -ants.b [150] -ants.c [200x200,0.0] -ants.s 2 $outDir/dwi_preproc.mif $outDir/dwi_unbias.mif
# # NOTE: must use ants, not FSL, for fixel-based analysis later
# # NOTE: edited ants N4BiasFieldCorrection parameters because some subjects had very high relative intensity in the cerebellum after this step, resulting in 0 output further down the pipeline

# #5) clean up
# rm $outDir/json2slspec.m
# rm $outDir/dwi_denoised*
# rm $outDir/b0*
# rm $outDir/AP*
# rm $outDir/dwi_preproc*
# gzip $outDir/*.mif
# rm -Rf $outDir/dwibiascorrect-tmp*

###########################################ALL SUBJECTS############################################

subject=$1
topDir=$H/Studies/DBIS/Imaging
outDir=$topDir/derivatives/mrtrix
DTI_Dir=$topDir/derivatives/DTI_FSL
sourceDir=$topDir/sourcedata
scriptsDir=$H/Scripts/pipeline2.0_DBIS
templateDir=$outDir/template30

# gzip $outDir/sub*/*.mif

###preprocessing (start from scratch or use DTI_DBIS to get eddy_corrected_data - does steps 1 and 2)
# '''#notes: keeping track of what DTI_DBIS does
# fslmerge first and last AP_nii
# susceptibility correction (topup fslmaths bet)
# eddy correction (eddy - uses AP bvec and bval)
# *output at this point is eddy_corrected_data
# fit tensors? (dtifit on AP)'''

# subject_list=`cd ${outDir}; ls -1d sub*`
#python $H/Scripts/pipeline2.0_DBIS/spm_batch.py "$subject_list" --script $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_1-4.sh -u mls99 --max_run_time 4:0:0 --max_run_hours 72 --warning_time 24

# #single tissue CSD
# cd $topDir/derivatives/mrtrix/no_unbias

# while [[ $(squeue -u mls99 -p gpu-common | grep -c mrtrix) -gt 0 ]]; do
	# sleep 20
# done

# for id in sub*; do
	# if [[ -e sub*/dwi_unbias.mif.gz ]]; then mv sub* $outDir; fi
# done

# #5) global intensity normalization
# #required for AFD analysis. normalization using group-wise registration. careful with space
# mkdir -p $outDir/dwiintensitynorm2/dwi_input
# mkdir $outDir/dwiintensitynorm2/mask_input
# foreach $outDir/sub* : cp IN/dwi_unbias.mif.gz $outDir/dwiintensitynorm2/dwi_input/NAME.mif.gz
# foreach $outDir/sub* : cp IN/dwi_temp_mask.mif.gz $outDir/dwiintensitynorm2/mask_input/NAME.mif.gz
# cd $outDir/dwiintensitynorm2
# dwiintensitynorm $outDir/dwiintensitynorm2/dwi_input/ $outDir/dwiintensitynorm2/mask_input/ $outDir/dwiintensitynorm2/dwi_output/ $outDir/dwiintensitynorm2/fa_template.mif.gz $outDir/dwiintensitynorm2/fa_template_wm_mask.mif
# #MLS: shutil.copy permission error (chmod) during population_template step. I changed it to shutil.copyfile in dwiintensitynorm (copy = shutil.copyfile) and it works, idk if that's gonna be a problem later
# #note: takes a ton of space but should be deleted upon completion (check for tmp in dwiintensitynorm dir)

# foreach dwi_output/* : cp IN $outDir/PRE/dwi_norm.mif.gz #MLS: used mv to save space. This doesn't work bc PRE doesn't cut off mif and gz
# cd dwi_output
# for id in sub*; do cp $id /cifs/hariri-long/Studies/DBIS/Imaging/derivatives/mrtrix/${id%%.*}/dwi_norm.mif.gz; done
# #NOTE: use dwi2tensor to add new subjects, alter mask, or reapply intensity normalization to all subjs (I moved instead of copied dwi_output to individual subject folders to save space but have more flexibility if you duplicate

# #5b) new subjects intensity norm
cd $outDir
for id in sub*; do
	if [[ ! -e $outDir/$id/dwi_norm.mif.gz ]]; then
		dwi2tensor $id/dwi_unbias.mif.gz -mask $id/dwi_temp_mask.mif.gz - | tensor2metric - -fa - | mrregister -force dwiintensitynorm/fa_template.mif.gz - -mask2 $id/dwi_temp_mask.mif.gz -nl_scale 0.5,0.75,1.0 -nl_niter 5,5,15 -nl_warp - /tmp/dummy_file.mif.gz | mrtransform dwiintensitynorm/fa_template_wm_mask.mif.gz -template $id/dwi_unbias.mif.gz -warp - - | dwinormalise $id/dwi_unbias.mif.gz - dwiintensitynorm/dwi_output/$id.mif.gz
cd dwi_output
for id in sub*; do cp $id /cifs/hariri-long/Studies/DBIS/Imaging/derivatives/mrtrix/${id%%.*}/dwi_norm.mif.gz; done
#NOTE: check scale factors applied during normalization are not influenced by variable of interest using mrinfo sub*/dwi_norm.mif.gz -property dwi_norm_scale_factor
# ###################################################################################################

# #6) compute avg white matter response function
# dwi2response tournier $outDir/$subject/dwi_norm.mif.gz $outDir/$subject/response.txt
# subject_list=`cd ${outDir}; ls -1d sub*`
#python $H/Scripts/pipeline2.0_DBIS/spm_batch.py $subject_list --script $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_6.sh -u mls99 --max_run_time 4:0:0 --max_run_hours 72 --warning_time 24

# #check response functions
# cd $outDir
# for id in sub*; do
	# if [[ -e $outDir/$id/response.txt ]]; then
		# for n in `awk -F, '{print $0}' $outDir/$id/response.txt`; do
			# if [[ ${n%.*} -gt 3000 ]]; then echo $id $n; fi
		# done
	# fi
# done

# for id in sub-02*; do
	# if [[ ! -e $outDir/$id/response.txt ]]; then
		# mv $outDir/$id $outDir/no_unbias
	# fi
# done

###########################################ALL SUBJECTS############################################
# cd $outDir
# average_response -force $outDir/sub*/response.txt $outDir/group_average_response.txt
###################################################################################################

# if [[ ! -e $outDir/$subject/dwi_upsampled.mif.gz ]]; then
# #7) upsample DWI data before computing FODs to increase anatomical contrast
# #recommends upsampling to voxel size 1.33 mm unless resolution is already higher
	# mrresize $outDir/$subject/dwi_norm.mif.gz -vox 1.3 $outDir/$subject/dwi_upsampled.mif.gz
# fi
# if [[ ! -e $outDir/$subject/dwi_mask_up.mif.gz ]]; then
# #8) compute upsampled brain mask images
	# dwi2mask $outDir/$subject/dwi_upsampled.mif.gz $outDir/$subject/dwi_mask_up.mif.gz
# ###NOTE: check that ALL individual subject masks include ALL regions of brain to analyze. 
# #Any individual subj mask excluding a region will lead to region exluded from entire analysis
# #manually correct masks if necessary
# fi
# if [[ ! -e $outDir/$subject/wmfod.mif.gz ]]; then
# #9) spherical deconvolution
	# foreach $outDir/$subject : dwiextract IN/dwi_upsampled.mif.gz - \| dwi2fod msmt_csd - $outDir/group_average_response.txt IN/wmfod.mif.gz -mask IN/dwi_mask_up.mif.gz
# # #NOTE: using multi-shell multi-tissue constrained spherical deconvolution although we have single shell data to benefit from hard non-negativity contraint (more robust)
# fi

# if [[ ! -e $outDir/$subject/wmfod.mif.gz ]]; then
	# mrresize -force $outDir/$subject/dwi_norm.mif.gz -vox 1.3 $outDir/$subject/dwi_upsampled.mif.gz
	# dwi2mask -force $outDir/$subject/dwi_upsampled.mif.gz $outDir/$subject/dwi_mask_up.mif.gz
	# foreach $outDir/$subject : dwiextract IN/dwi_upsampled.mif.gz - \| dwi2fod msmt_csd - $outDir/group_average_response.txt IN/wmfod.mif.gz -mask IN/dwi_mask_up.mif.gz
# fi
#python $H/Scripts/pipeline2.0_DBIS/spm_batch.py $subject_list --script $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_7-9.sh -u mls99 --max_run_time 4:0:0 --max_run_hours 72 --warning_time 24

###########################################ALL SUBJECTS############################################
#10) DBIS unbiased FOD template
###NOTE: time intensive. make template from subset of ~40 subjects by putting all FOD images into 1 folder
# mkdir -p $templateDir/fod_input
# mkdir $templateDir/mask_input
# # #copy all FOD images and masks into the input folder (JUST the 40!!!!)
# # foreach $outDir/subset40/sub* : cp IN/wmfod.mif.gz $templateDir/fod_input/PRE.mif.gz ";" cp IN/dwi_mask_up.mif.gz $templateDir/mask_input/PRE.mif.gz
# for id in `awk -F, '{print $1}' $H/Scripts/pipeline2.0_DBIS/config/first500scans.txt | head -31 | sed 's/DMHDS/sub-/g' `; do 
	# cp $outDir/$id/wmfod.mif.gz $templateDir/fod_input/$id.mif.gz
	# cp $outDir/$id/dwi_mask_up.mif.gz $templateDir/mask_input/$id.mif.gz
# done

# population_template $templateDir/fod_input -mask_dir $templateDir/mask_input $templateDir/wmfod_template.mif.gz -voxel_size 1.3

# #if there are any holes in the template mask, do this to figure out which subject mask(s) are problematic and see if you can manually correct or exclude them:
# foreach sub* : mrconvert IN/dwi_mask_up.mif.gz IN/dwi_mask_up.nii.gz
# 3dTcat sub*/dwi_mask_up.nii.gz -prefix all_mask_up
# #open in afni to click through masks to identify which one is causing a hole in the population template mask. exclude and redo if necessary
###################################################################################################

#11) register subject FODs to FOD template
# mrregister $outDir/$subject/wmfod.mif.gz -mask1 $outDir/$subject/dwi_mask_up.mif.gz $templateDir/wmfod_template.mif.gz -nl_warp $outDir/$subject/subject2template_warp.mif.gz $outDir/$subject/template2subject_warp.mif.gz

#12) compute intersection of all subject masks in temlate space
# mrtransform $outDir/$subject/dwi_mask_up.mif.gz -warp $outDir/$subject/subject2template_warp.mif.gz -interp nearest -datatype bit $outDir/$subject/dwi_mask_template.mif.gz

#python $H/Scripts/pipeline2.0_DBIS/spm_batch.py $subject_list --script $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS_11-12.sh -u mls99 --max_run_time 3:0:0 --max_run_hours 72 --warning_time 24

###########################################ALL SUBJECTS############################################
# mrmath $outDir/sub*/dwi_mask_template.mif.gz min $templateDir/template_mask.mif.gz -datatype bit
# #NOTE: check that resulting template mask includes ALL regions of brain intended for analysis

# #13) compute wm template analysis fixel mask
# fod2fixel -mask $templateDir/template_mask.mif.gz -fmls_peak_value 0.10 $templateDir/wmfod_template.mif.gz $templateDir/fixel_mask

# #if possible, visualize the fixel mask to see if the threshold was set too high
# #if there are any holes in the template mask, do this to figure out which subject mask(s) are problematic and see if you can manually correct or exclude them:
# foreach sub* : mrconvert IN/dwi_mask_up.mif.gz IN/dwi_mask_up.nii.gz
# 3dTcat sub*/dwi_mask_up.nii.gz -prefix all_mask_up
# #open in afni to click through masks to identify which one is causing a hole in the population template mask. exclude and redo if necessary
# #once the template mask looks good, check how many fixels are included in the fixel mask (should be several hundreds of thousands)
#mrinfo -size $templateDir/fixel_mask/directions.mif #look at the number on the left
###################################################################################################

rm $outDir/$subject/fod_in_temp_NO.mif.gz
rm -Rf $outDir/$subject/fixel_in_temp_NO
rm -Rf $outDir/$subject/fixel_in_temp
#NOTE: -force will overwrite output files but you'll still get error messages if the subject fixel directories aren't empty
#NOTE: the first time I ran this the last 28 or so jobs paused for 4 days while the rest had completed in minutes. Same thing happened when I deleted everything and reran all but with a different set of 28 subjects. They seemed to continue running (very slowly) 4 days later. Maybe compression time increases as more subjects are added?

#14) warp FOD to template (NO = not oriented)
mrtransform -force $outDir/$subject/wmfod.mif.gz -warp $outDir/$subject/subject2template_warp.mif.gz -noreorientation $outDir/$subject/fod_in_temp_NO.mif.gz

#15) estimate FD (segment each FOD lobe to find # and orientation of fixels in each voxel - contains AFD)
fod2fixel -force -mask $templateDir/template_mask.mif.gz $outDir/$subject/fod_in_temp_NO.mif.gz $outDir/$subject/fixel_in_temp_NO -afd fd.mif.gz

#16) reorient fixels
fixelreorient -force $outDir/$subject/fixel_in_temp_NO $outDir/$subject/subject2template_warp.mif.gz $outDir/$subject/fixel_in_temp
#remove fixel_in_temp_NO after this
rm -Rf fixel_in_temp_NO

#17) assign sub to template fixels
fixelcorrespondence -force $outDir/$subject/fixel_in_temp/fd.mif.gz $templateDir/fixel_mask $templateDir/fd $subject.mif.gz
#NOTE: $templateDir/fd will store fixel data files for each subject (each file corresponds to template fixels)

#18) compute FC
warp2metric -force $outDir/$subject/subject2template_warp.mif.gz -fc $templateDir/fixel_mask $templateDir/fc $subject.mif.gz
###########################################ALL SUBJECTS############################################
# mkdir $templateDir/logfc
# cp $templateDir/fc/index.mif.gz $templateDir/fc/directions.mif.gz $templateDir/logfc
###################################################################################################
# mrcalc $templateDir/fc/${subject}.mif.gz -log $templateDir/log_fc/${subject}.mif.gz

# #19) compute FDC
# ###########################################ALL SUBJECTS############################################
# mkdir $templateDir/fdc
# cp $templateDir/fc/index.mif.gz $templateDir/fdc
# cp $templateDir/fc/directions.mif.gz $templateDir/fdc
# ###################################################################################################
# mrcalc $templateDir/fd/$subject.mif.gz $templateDir/fc/$subject.mif.gz -mult $templateDir/fdc/$subject.mif.gz

# #20) whole-brain fibre tractography
# ###########################################ALL SUBJECTS############################################
# cd $templateDir
# tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 wmfod_template.mif.gz -seed_image temlate_mask.mif.gz -mask template_mask.mif.gz -select 20000000 -cutoff 0.10 tracks_20_million.tck

# #21) reduce biases in tractogram densities
# tcksift tracks_20_million.tck wmfod_template.mif.gz tracks_2_million_sift.tck -term_number 2000000

# #22) statistical analysis
# #NOTE: this takes A LOT of memory, like 128G RAM. Check # fixels in template mask, maybe increase template voxel size a bit if crashing bc of memory
# #check # fixels: mrinfo -size ./fixel_template/directions.mif.gz
# fixelcfestats fd files.txt design_matrix.txt contrast_matrix.txt tracks_2_million_sift.txk stats_fd
# fixelcfestats log_fc files.txt design_matrix.txt contrast_matrix.txt tracks_2_million_sift.txk stats_log_fc
# fixelcfestats fdc files.txt design_matrix.txt contrast_matrix.txt tracks_2_million_sift.txk stats_fdc

# #23) visualize in mrview (have to install locally - don't have root permission on cluster)
# open population FOD template and overlay fixel images with vetor plot tool (can threshold p value)

# clean up
# rm $outDir/$subject/dwi_norm.mif.gz #after step 7
# rm $outDir/$subject/dwi_upsampled.mif.gz #after step 9 (huge file)
# rm $outDir/$subject/dwi_mask_up.mif.gz #after step 12
# rm -rf $templateDir/fod_input $templateDir/mask_input  #after step 10 - these are copied from subj dirs anyway
# rm -rf $outDir/$subject/fixel_in_temp_NO #remove this right after step 16
#NOTE: keep $outDir/dwi_unbias.mif.gz and $outDir/dwi_temp_mask.mif.gz in case you want to add more subjects or redefine the mask later
#NOTE: keep wmfod.mif.gz (FOD estimates)

###########################################CITATIONS############################################
# Andersson, J. L. & Sotiropoulos, S. N. An integrated approach to correction for off-resonance 
# effects and subject movement in diffusion MR imaging. NeuroImage, 2015, 125, 1063-1078
# Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.;
# Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, 
# J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and 
# structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219
# Skare, S. & Bammer, R. Jacobian weighting of distortion corrected EPI data. Proceedings of the 
# International Society for Magnetic Resonance in Medicine, 2010, 5063
# Andersson, J. L.; Skare, S. & Ashburner, J. How to correct susceptibility distortions in spin-echo 
# echo-planar images: application to diffusion tensor imaging. NeuroImage, 2003, 20, 870-888
# Andersson, J. L. R.; Graham, M. S.; Drobnjak, I.; Zhang, H.; Filippini, N. & Bastiani, M. Towards 
# a comprehensive framework for movement and distortion correction of diffusion MR images: Within 
# volume movement. NeuroImage, 2017, 152, 450-466

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
# rm /dscrhome/$USER/mrtrix_DBIS.$SLURM_JOB_ID.out
mv /dscrhome/$USER/mrtrix_DBIS.$SLURM_JOB_ID.out $outDir/$subject/mrtrix_18.$SLURM_JOB_ID.out 
# -- END POST-USER -- 
