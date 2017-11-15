#!/bin/sh

# This script takes anatomical data located under Data/anat and performs DTI processing:
# 
# *Dicom import with Chris ROrden's (mricron) dcm2nii
# *DTI preprocessing in FSL 
#
# TBSS is run per the instructions of the ENIGMA group: see http://enigma.ini.usc.edu/wp-content/uploads/2012/06/ENIGMA_TBSS_protocol.pdf and http://enigma.ini.usc.edu/wp-content/uploads/2012/06/ENIGMA_ROI_protocol.pdf
#	
# The ENIGMA instructions are written for processing a single batch of subjects, so we've made a few changes for processing single subjects in parallel.
# One difference is that the group stats output by TBSS (into the automatically generated "stats" folder) are deleted at the end of the script, 
#  since they're of no use in this context. If for some reason any of these images are needed, TBSS will need to be re-run differently
#
# 8/27/17: updated dcm2nii to our copy of dcm2niix, since the new default version of dcm2nii on the cluster wasn't working properly

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -S /bin/sh
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -m ea
#$ -l h_vmem=10G 
# -- END GLOBAL DIRECTIVE -- 
# -- BEGIN PRE-USER --
source /etc/biac_sge.sh
echo "----JOB [$JOB_NAME.$JOB_ID] START [`date`] on HOST [$HOSTNAME]----" 
# -- END PRE-USER --

# -- BEGIN USER DIRECTIVE --
# Send notifications to the following address
#$ -M SUB_USEREMAIL_SUB
# -- END USER DIRECTIVE --

## Initialize variables 
SUBJ=$1          												# This is the full subject folder name under Data
EXPERIMENT=`findexp DBIS.01`									# This will give the full path to ../Hariri/DBIS.01
OUTDIR=$EXPERIMENT/Analysis/All_Imaging/$SUBJ/DTI		        # This is the location of the subject's output directory
DATADIR=$EXPERIMENT/Data/OTAGO/$SUBJ/DMHDS	         			# This is the location of the subject's raw data directory
TEMPLATEDIR=$EXPERIMENT/Analysis/DTI/ENIGMA_templates			# This is where ENIGMA templates are stored
CONFIGDIR=$EXPERIMENT/Scripts/pipeline2.0_DBIS/config			# This is where the config files for topup and eddy are stored
export PATH=${EXPERIMENT/DBIS/DNS}/Scripts/Tools/mricrogl_lx:$PATH # need this for a copy of dcm2niix that works properly
export FSLPATH=/usr/local/packages/fsl-5.0.9/

## Make the subject specific output directories
mkdir -p $OUTDIR/PA
mkdir -p $OUTDIR/AP_MDDW

## import dicoms
firstPAfile=`ls $DATADIR/MR_POST_DWI_P-A_DIST_Change_180/*dcm | head -n 1`
firstAPfile=`ls $DATADIR/MR_MDDW_64_directions_ep2d_diff_p2s2/*dcm | head -n 1`
dcm2niix -z y -o $OUTDIR/AP_MDDW $firstAPfile # had to add -z y for dcm2niix to output nii.gz rahter than .nii
dcm2niix -z y -o $OUTDIR/PA $firstPAfile

## rename files to make easier to work with
## AP
cd $OUTDIR/AP_MDDW
filename=`ls MR*bval`
filename=${filename/.bval/}
mv $filename.bval AP_MDDW.bval
mv $filename.bvec AP_MDDW.bvec
mv $filename.nii.gz AP_MDDW.nii.gz
## PA: 3 b0s collected
cd $OUTDIR/PA
filename=`ls MR*gz`
mv $filename b0_PA.nii.gz

cd $OUTDIR

## sequence has one initial b0 image, then 6 at the end
## put them all in one image
fslroi AP_MDDW/AP_MDDW.nii.gz b0_AP_first 0 1
fslroi AP_MDDW/AP_MDDW.nii.gz b0_AP_last 65 6
fslmerge -t b0_ALL b0_AP_first b0_AP_last PA/b0_PA

## use topup to estimate and correct for the susceptibility induced field (caused by the scusceptibility distribution of the subject's head)
topup --imain=b0_ALL --datain=$CONFIGDIR/DTI_params.txt --config=b02b0.cnf --out=topup_b0_ALL --iout=topup_corrected
echo "***Running fslmaths***"
fslmaths topup_corrected -Tmean topup_corrected
## now extract the brain
echo "***Running bet***"
bet topup_corrected topup_corrected_brain -m -c 48 58 26
## double check topup correction
# fslroi AP_MDDW/AP_MDDW.nii.gz tmp 0 1; for i in {28..36..2}; do slicer tmp.nii.gz -z -$i z$i.png; done
# pngappend z28.png + z30.png + z32.png + z34.png + z36.png b0AP_ax.png
# fslroi PA/b0_PA.nii.gz tmp 0 1; for i in {28..36..2}; do slicer tmp.nii.gz -z -$i z$i.png; done
# pngappend z28.png + z30.png + z32.png + z34.png + z36.png b0PA_ax.png; rm z*png
# fslroi topup_corrected_brain.nii.gz tmp 0 1; for i in {28..36..2}; do slicer tmp.nii.gz -z -$i z$i.png; done
# pngappend z28.png + z30.png + z32.png + z34.png + z36.png b0_topup_corrected.png; rm z*png

## before running eddy, need to take out default cluster FSL path and add paths to newer FSL version (might not actually need to worry about cluster FSL actually since turns out newer version is eddy_openmp?)
#export PATH=/home/ark19/linux/experiments/DNS.01/Scripts/Tools/FSL/fsl/bin:/usr/local/packages/freesurfer_v5.3.0/bin:/usr/local/packages/freesurfer_v5.3.0/fsfast/bin:/usr/local/packages/freesurfer_v5.3.0/tktools:/usr/local/packages/freesurfer_v5.3.0/mni/bin:/opt/gridengine/bin/lx24-amd64:/usr/local/packages/bxh_xcede_tools-1.11.10-lsb30.x86_64/bin:/usr/local/packages/bxh_xcede_tools-1.11.10-lsb30.x86_64/lib:/usr/local/packages/camino/bin:/usr/lib64/openmpi/bin:/usr/sbin:/sbin:/usr/local/packages/dcmtk-3.6.0/bin:/usr/local/packages/jvs/bin:/usr/local/packages/liblinear-1.51:/usr/local/packages/libsvm-2.9:/usr/local/packages/gengen:/usr/local/packages/ants-2.1.0:/usr/local/packages/AtlasWerks_v0.1.3/bin/:/usr/local/packages/afni_gcc33_64:/usr/local/packages/dtk-v0.6.3:/usr/local/packages/camino/bin:/usr/local/packages/camino/man:/usr/local/packages/camino-trackvis-0.2/bin:/usr/local/packages/mricron:/usr/local/packages/weka-3-6-6:/usr/local/packages/dsistudio-20141020:/usr/local/packages/mrtrix-0.2.12/bin:/usr/local/packages/mrtrix-0.2.12/lib:/usr/local/packages/fcma-toolbox/bin:/usr/local/packages/freesurfer_v5.3.0/bin:/usr/local/packages/freesurfer_v5.3.0/fsfast/bin:/usr/local/packages/freesurfer_v5.3.0/tktools:/usr/local/packages/freesurfer_v5.3.0/mni/bin:/opt/gridengine/bin/lx24-amd64:/usr/local/packages/bxh_xcede_tools-1.11.10-lsb30.x86_64/bin:/usr/local/packages/bxh_xcede_tools-1.11.10-lsb30.x86_64/lib:/usr/local/packages/camino/bin:/usr/lib64/openmpi/bin:/usr/sbin:/sbin:/usr/local/packages/dcmtk-3.6.0/bin:/usr/local/packages/jvs/bin:/usr/local/packages/liblinear-1.51:/usr/local/packages/libsvm-2.9:/usr/local/packages/gengen:/usr/local/packages/ants-2.1.0:/usr/local/packages/AtlasWerks_v0.1.3/bin/:/usr/local/packages/afni_gcc33_64:/usr/local/packages/dtk-v0.6.3:/usr/local/packages/camino/bin:/usr/local/packages/camino/man:/usr/local/packages/camino-trackvis-0.2/bin:/usr/local/packages/mricron:/usr/local/packages/weka-3-6-6:/usr/local/packages/dsistudio-20141020:/usr/local/packages/mrtrix-0.2.12/bin:/usr/local/packages/mrtrix-0.2.12/lib:/usr/local/packages/fcma-toolbox/bin:/tmp/9659583.1.interact.q:/usr/local/bin:/bin:/usr/bin:/usr/local/packages/simnibs_2.0.1/bin:/usr/local/packages/simnibs_2.0.1/fem_efield:/usr/local/packages/simnibs_2.0.1/mri2mesh:/usr/local/sbin:/usr/local/packages/simnibs_2.0.1/bin:/usr/local/packages/simnibs_2.0.1/fem_efield:/usr/local/packages/simnibs_2.0.1/mri2mesh:/home/ark19/linux/bin
## add path to eddy_openmp
## plain old "eddy" on the cluster's FSL installation threw an error and forum searches revealed that the older version of the installation had a bug... the more recent version then uses eddy_openmp
export PATH=${EXPERIMENT/DBIS.01/DNS.01}/Scripts/Tools/FSL/fsl/bin:$PATH

## correct for eddy currents. eddy output is not brain masked, but mask gets applied again in dtifit so its output is just brain
eddy_openmp --imain=AP_MDDW/AP_MDDW --mask=topup_corrected_brain_mask.nii.gz --acqp=$CONFIGDIR/DTI_params.txt --index=$CONFIGDIR/DTI_index.txt --bvecs=AP_MDDW/AP_MDDW.bvec --bvals=AP_MDDW/AP_MDDW.bval --topup=topup_b0_ALL --out=eddy_corrected_data
# eddy_openmp --imain=data --mask=topup_corrected_brain_c_mask.nii.gz --acqp=params.txt --index=index.txt --bvecs=bvecs.txt --bvals=bvals.txt --topup=topup_b0_ALL --repol --out=eddy_corrected_data_repol

## use fsl's dtifit to fit tensors
dtifit -k eddy_corrected_data.nii.gz -m topup_corrected_brain_mask.nii.gz -o fitted_data -r AP_MDDW/AP_MDDW.bvec -b AP_MDDW/AP_MDDW.bval

## prep for trackVis (just using this to generate images to send to SMs for now), needs all b0 volumes to be at beginning
finished=$($EXPERIMENT/Graphics/Brain_Images/ReadyToProcess/finished_processing.txt | wc -l)
if [ $finished -eq 0 ]; then
	if [ ! -e $EXPERIMENT/Graphics/Brain_Images/DTI_toProcess/$SUBJ/eddy_corrected_data_trackVis.nii.gz ]; then
		fslroi eddy_corrected_data.nii.gz tmp_b3000volumes 1 64
		fslmerge -t eddy_corrected_data_trackVis b0_AP_first b0_AP_last tmp_b3000volumes
		rm tmp_b3000volumes*
		mkdir $EXPERIMENT/Graphics/Brain_Images/DTI_toProcess/$SUBJ
		mv eddy_corrected_data_trackVis.nii.gz $EXPERIMENT/Graphics/Brain_Images/DTI_toProcess/$SUBJ
	fi
fi

# ## print subject space FA image to png for easy visual inspection (actually I think this is done automatically by tbss and output to slicesdir)
# num=25; for i in `seq 1 10`; do slicer fitted_data_FA.nii.gz -x -$num x$num.png; num=$((num+5)); done
# str="x25.png"; num=30; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+5)); done
# pngappend $str xrow1.png
# str="x50.png"; num=55; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+5)); done
# pngappend $str xrow2.png
# pngappend xrow1.png - xrow2.png FA_sag.png
# rm x*png
# num=5; for i in `seq 1 10`; do slicer fitted_data_FA.nii.gz -z -$num z$num.png; num=$((num+5)); done
# str="z5.png"; num=10; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+5)); done
# pngappend $str zrow1.png
# str="z30.png"; num=35; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+5)); done
# pngappend $str zrow2.png
# pngappend zrow1.png - zrow2.png FA_ax.png
# rm z*png
# num=20; for i in `seq 1 12`; do slicer fitted_data_FA.nii.gz -y -$num y$num.png; num=$((num+5)); done
# str="y20.png"; num=25; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+5)); done
# pngappend $str yrow1.png
# str="y50.png"; num=55; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+5)); done
# pngappend $str yrow2.png
# pngappend yrow1.png - yrow2.png FA_cor.png
# rm y*png
# pngappend FA_cor.png - FA_sag.png - FA_ax.png FA_ALL.png
# rm FA_cor.png; rm FA_sag.png; rm FA_ax.png

## now run TBSS per ENIGMA pipeline
# use ENIGMA template (at least for now) bc Dunedin FOV is same and seems to work well
echo "Running tbss in FSL"
tbss_1_preproc fitted_data_FA.nii.gz
tbss_2_reg -t $TEMPLATEDIR/ENIGMA_DTI_FA.nii.gz
tbss_3_postreg -S

## apply resulting warp to MD image as well (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/TBSS/UserGuide: "Using non-FA Images in TBSS" suggests this is ok)
applywarp --ref=${FSLPATH}/data/standard/FMRIB58_FA_1mm.nii.gz --in=fitted_data_MD --warp=FA/fitted_data_FA_FA_to_target_warp --out=fitted_data_MD_to_target

## apply mask to normalized FA and MD images
fslmaths FA/fitted_data_FA_FA_to_target.nii.gz -mas $TEMPLATEDIR/ENIGMA_DTI_FA_mask.nii.gz FA/fitted_data_FA_FA_to_target_masked.nii.gz
fslmaths fitted_data_MD_to_target.nii.gz -mas $TEMPLATEDIR/ENIGMA_DTI_FA_mask.nii.gz fitted_data_MD_to_target_masked.nii.gz
 
## now skeletonize images by projecting the ENIGMA skeleton onto them
# a lower cingulum mask is included here because since that region is such a large bundle of fibers, 
#  the projection needs to incorporate 3 dimensions rather than only 2 as it does for the rest
# -i input image
# -p projectargs <skel_thresh> <distancemap> <search_rule_mask> <4Ddata> <projected_4Ddata> (requires_5_arguments)
# -s alternative skeleton
tbss_skeleton -i FA/fitted_data_FA_FA_to_target_masked.nii.gz  -p 0.049 $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton_mask_dst ${FSLPATH}data/standard/LowerCingulum_1mm.nii.gz FA/fitted_data_FA_FA_to_target_masked.nii.gz stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz -s $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton_mask.nii.gz
 
## now extract ENIGMA ROIs
cd $EXPERIMENT/Analysis/DTI/ENIGMA_ROI

./singleSubjROI_exe ENIGMA_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz JHU-WhiteMatter-labels-1mm.nii.gz $OUTDIR/stats/ROIout $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz	
./singleSubjROI_exe LeftUF_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz rThresh10_LeftUF.nii.gz $OUTDIR/stats/ROIout_L_UF $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz
./singleSubjROI_exe RightUF_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz rThresh10_RightUF.nii.gz $OUTDIR/stats/ROIout_R_UF $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz

tail -1 $OUTDIR/stats/ROIout_L_UF.csv >> $OUTDIR/stats/ROIout.csv
tail -1 $OUTDIR/stats/ROIout_R_UF.csv >> $OUTDIR/stats/ROIout.csv
rm $OUTDIR/stats/ROIout_*_UF.csv

cd $OUTDIR

## print normalized FA image to png for easy visual inspection
num=25; for i in `seq 1 10`; do slicer FA/fitted_data_FA_FA_to_target_masked.nii.gz -x -$num x$num.png; num=$((num+10)); done
str="x25.png"; num=35; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+10)); done
pngappend $str xrow1.png
str="x75.png"; num=85; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+10)); done
pngappend $str xrow2.png
pngappend xrow1.png - xrow2.png FA_sag.png
rm x*png
num=5; for i in `seq 1 10`; do slicer FA/fitted_data_FA_FA_to_target_masked.nii.gz -z -$num z$num.png; num=$((num+15)); done
str="z5.png"; num=20; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+15)); done
pngappend $str zrow1.png
str="z80.png"; num=95; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+15)); done
pngappend $str zrow2.png
pngappend zrow1.png - zrow2.png FA_ax.png
rm z*png
num=20; for i in `seq 1 12`; do slicer FA/fitted_data_FA_FA_to_target_masked.nii.gz -y -$num y$num.png; num=$((num+15)); done
str="y20.png"; num=35; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+15)); done
pngappend $str yrow1.png
str="y110.png"; num=125; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+15)); done
pngappend $str yrow2.png
pngappend yrow1.png - yrow2.png FA_cor.png
rm y*png
pngappend FA_cor.png - FA_sag.png - FA_ax.png FA_normalized_ENIGMA.png
rm FA_cor.png; rm FA_sag.png; rm FA_ax.png

## print normalized MD image to png for easy visual inspection
num=25; for i in `seq 1 10`; do slicer fitted_data_MD_to_target_masked.nii.gz -x -$num x$num.png; num=$((num+10)); done
str="x25.png"; num=35; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+10)); done
pngappend $str xrow1.png
str="x75.png"; num=85; for i in `seq 1 4`; do str="$str + x$num.png"; num=$((num+10)); done
pngappend $str xrow2.png
pngappend xrow1.png - xrow2.png MD_sag.png
rm x*png
num=5; for i in `seq 1 10`; do slicer fitted_data_MD_to_target_masked.nii.gz -z -$num z$num.png; num=$((num+15)); done
str="z5.png"; num=20; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+15)); done
pngappend $str zrow1.png
str="z80.png"; num=95; for i in `seq 1 4`; do str="$str + z$num.png"; num=$((num+15)); done
pngappend $str zrow2.png
pngappend zrow1.png - zrow2.png MD_ax.png
rm z*png
num=20; for i in `seq 1 12`; do slicer fitted_data_MD_to_target_masked.nii.gz -y -$num y$num.png; num=$((num+15)); done
str="y20.png"; num=35; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+15)); done
pngappend $str yrow1.png
str="y110.png"; num=125; for i in `seq 1 5`; do str="$str + y$num.png"; num=$((num+15)); done
pngappend $str yrow2.png
pngappend yrow1.png - yrow2.png MD_cor.png
rm y*png
pngappend MD_cor.png - MD_sag.png - MD_ax.png MD_normalized_ENIGMA.png
rm MD_cor.png; rm MD_sag.png; rm MD_ax.png 


## Clean Up
# at least for starting out, we'll be strict about deleting the larger files, 
# especially those that are just a few steps from dcm import and can easily be re-generated
cd $OUTDIR
rm AP_MDDW/*nii.gz
rm PA/*nii.gz
rm FA/target.nii.gz
rm FA/fitted_data_FA_FA_to_target.nii.gz
rm fitted_data_MD_to_target.nii.gz
rm b0*nii.gz
rm -r origdata # this just contains fitted_data_FA.nii.gz, which is the same as FA/fitted_data_FA_FA.nii.gz except not masked
# these images are generated by TBSS to give group level statistics, which aren't relevant here since we're running individuals
rm stats/all_FA*
rm stats/mean_FA*
# rm eddy_corrected_data.nii.gz ????????????? it's huge but might need it (135MB)

mkdir QA
mv *png QA
mv FA/slicesdir QA




# -- END USER SCRIPT -- #

# **********************************************************
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
OUTDIR=${OUTDIR:-$EXPERIMENT/Analysis/DTI/SPM/$SUBJ}
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$JOB_NAME.$JOB_ID.out	 
RETURNCODE=${RETURNCODE:-0}
exit $RETURNCODE
# -- END POST USER--
