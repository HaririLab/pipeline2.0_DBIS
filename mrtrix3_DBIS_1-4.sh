#!/bin/bash
###QUESTIONS FOR ANNCHEN
#runs faster if gunzip before running dwipreproc
#.mif.gz to save space? nii.gz? difference of about 10-20 MB per file

###NOTES
#matlab write to file
#*trace out directory structure
#as root: sudo -S mount -t cifs //oit-nas-fe12.oit.duke.edu/data_commons-hariri-long /home/vcm/dcc_vm/ -o username=mls99,password=,domain=WIN,uid=1000,gid=1000
#symlinks: replace ln -s with cp (server doesn't do symlinks)
#install gui version mrtrix on vm? qt5, openGL issues
#single tissue bc we only have b0 and b3000
#try just using first 500 subjects first (in pipeline2.0_DBIS/config)
# # ran using : for id in `awk -F, '{print $1}' $H/Scripts/pipeline2.0_DBIS/config/first500scans.txt | sed 's/DMHDS//g' `; do sbatch $H/Scripts/pipeline2.0_DBIS/mrtrix3_DBIS.sh $id; done
#maybe switch back t0 mem 24000 and don't specify nthreads? ~43min
###################################################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/mrtrix_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/mrtrix_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=24000
#SBATCH --partition gpu-common --gres=gpu:1
#SBATCH -c 6
# -- END GLOBAL DIRECTIVE -

###########################################ONE SUBJECT#############################################

# export PATH=/dscrhome/mls99/.local/bin/cuda-7.5/bin:$PATH
# export LD_LIBRARY_PATH=/dscrhome/mls99/.local/bin/cuda-7.5/lib:/dscrhome/mls99/.local/bin/cuda-7.5/lib64:$LD_LIB_PATH

subject=$1 #bids
SUBNUM=`echo $subject | sed 'ssub-//g'`
topDir=$H/Studies/DBIS/Imaging
outDir=$topDir/derivatives/mrtrix/$subject
sourceDir=$topDir/sourcedata/$subject/dwi
scriptsDir=$H/Scripts/pipeline2.0_DBIS

# mkdir $outDir
cd $outDir
cp $scriptsDir/json2slspec.m .

dwidenoise $sourceDir/*AP_dwi.nii.gz $outDir/dwi_denoised.mif
mrdegibbs $outDir/dwi_denoised.mif $outDir/dwi_denoised_unringed.mif -axes 0,1 #originally had axes 0,2 (coronal instead of axial - problem?)
mrconvert $outDir/dwi_denoised_unringed.mif $outDir/dwi_denoised_unringed.nii.gz

# Loop through template MATLAB script replacing subject
if [[ ! -e $outDir/slspec.txt ]]; then
	for i in ${scriptsDir}'/json2slspec.m'; do
		sed -e 's@SUB_NUM_SUB@'$SUBNUM'@g' <$i> json2slspec.m
	done
# run script to get slice order for subject
	/opt/apps/matlabR2016a/bin/matlab -nodisplay -singleCompThread < json2slspec.m
fi

# there are 7 b0s from AP and 3 b0s from PA so take just the first 3 from AP and combine with PA to get b0s.mif
fslroi $sourceDir/*AP_dwi.nii.gz $outDir/b0_AP_first 0 1
fslroi $sourceDir/*AP_dwi.nii.gz $outDir/b0_AP_last 65 2 #structure of AP is 0 3000(x64) 0 0 0 0 0 0
fslroi $outDir/dwi_denoised_unringed.nii.gz $outDir/AP_dwi_mod 0 67 #remove extra b0s
mrcat $outDir/b0_AP_first.nii.gz $outDir/b0_AP_last.nii.gz $sourceDir/*PA_dwi.nii.gz $outDir/b0s.mif -axis 3 #MLS: correct axis? leaving out flag determines axis # from images
# remove last 4 0s from AP bvec and bval to have only 3 b0s (bval should be same for all subjects; bvec not - 3 lines)
cat $sourceDir/*AP_dwi.bval | while read line; do
	echo ${line::-8} >> $outDir/AP_dwi_mod.bval
done
cat $sourceDir/*AP_dwi.bvec | while read line; do
	echo ${line::-8} >> $outDir/AP_dwi_mod.bvec 
done

# NOTE: chose to set mporder=8 as it is the low end of the FSL help page suggestion to use N/4 to N/2 where N is the number of slices in a volume (30 in this case). Shouldn't make much difference in subjects with low motion anyway.
# NOTE: set slm=linear following mrtrix recommendation because sampling b3000 shell strongly asymmetric
dwipreproc $outDir/AP_dwi_mod.nii.gz $outDir/dwi_preproc.mif -pe_dir AP -rpe_pair -se_epi $outDir/b0s.mif -json_import $sourceDir/*AP_dwi.json -fslgrad $outDir/AP_dwi_mod.bvec $outDir/AP_dwi_mod.bval -tempdir $outDir/tmp/ -eddy_options "--mporder=8 --slm=linear --slspec=$outDir/slspec.txt"

#3) temporary brain mask
dwi2mask $outDir/dwi_preproc.mif $outDir/dwi_temp_mask.mif

# 4) bias field correction
# echo "original parameters: dwibiascorrect -ants $outDir/dwi_preproc.mif $outDir/dwi_unbias.mif"
dwibiascorrect -ants -ants.b [150] -ants.c [200x200,0.0] -ants.s 2 $outDir/dwi_preproc.mif $outDir/dwi_unbias.mif
# NOTE: must use ants, not FSL, for fixel-based analysis later
# NOTE: edited ants N4BiasFieldCorrection parameters because some subjects had very high relative intensity in the cerebellum after this step, resulting in 0 output further down the pipeline

#5) clean up
rm $outDir/json2slspec.m
rm $outDir/dwi_denoised*
rm $outDir/b0*
rm $outDir/AP*
rm $outDir/dwi_preproc*
gzip $outDir/*.mif
rm -Rf $outDir/dwibiascorrect-tmp*

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
mv /dscrhome/$USER/mrtrix_DBIS.$SLURM_JOB_ID.out $outDir/mrtrix.$SLURM_JOB_ID.out 
# -- END POST-USER -- 
