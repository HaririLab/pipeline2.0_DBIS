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
#SBATCH --mem=12000
#SBATCH -p scavenger
# -- END GLOBAL DIRECTIVE -

###########################################ONE SUBJECT#############################################

subject=$1
topDir=$H/Studies/DBIS/Imaging
outDir=$topDir/derivatives/mrtrix
DTI_Dir=$topDir/derivatives/DTI_FSL
sourceDir=$topDir/sourcedata
scriptsDir=$H/Scripts/pipeline2.0_DBIS
templateDir=$outDir/template40

# mkdir $outDir
cd $outDir
#11) register subject FODs to FOD template
mrregister $outDir/$subject/wmfod.mif.gz -mask1 $outDir/$subject/dwi_mask_up.mif.gz $templateDir/wmfod_template.mif.gz -nl_warp $outDir/$subject/subject2template_warp.mif.gz $outDir/$subject/template2subject_warp.mif.gz

#12) compute intersection of all subject masks in temlate space
mrtransform $outDir/$subject/dwi_mask_up.mif.gz -warp $outDir/$subject/subject2template_warp.mif.gz -interp nearest -datatype bit $outDir/$subject/dwi_mask_template.mif.gz

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
