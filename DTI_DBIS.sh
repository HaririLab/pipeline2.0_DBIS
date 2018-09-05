#!/bin/bash

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
#SBATCH --output=/dscrhome/%u/DTI_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/DTI_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -

source ~/.bash_profile

## Initialize variables 
SUBJ=$1          											# use just 4 digit number! E.g 0234 for DMHDS0234
INITRAND=$2	# add this option for using initrand when doing test / retest subjects (see call to eddy below)
TOPDIR=/cifs/hariri-long									# This will give the full path to ../Hariri/DBIS.01
if [[ $INITRAND == "initrand" ]]; then 
  OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/DTI_FSL_initrand/sub-$SUBJ;		        # This is the location of the subject's output directory
  prefix=DTI_initrand
else
  OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/DTI_FSL/sub-$SUBJ;		        # This is the location of the subject's output directory
  prefix=DTI
fi
DATADIR=$TOPDIR/Studies/DBIS/Imaging/sourcedata/sub-$SUBJ/dwi;         			# This is the location of the subject's raw data directory
TEMPLATEDIR=$TOPDIR/Templates/ThirdPartyOriginals/ENIGMA_templates			# This is where ENIGMA templates are stored
CONFIGDIR=$TOPDIR/Scripts/pipeline2.0_DBIS/config			# This is where the config files for topup and eddy are stored
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/${prefix}_ENIGMA_ROIs_averageFA.csv
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
graphicsDir=$TOPDIR/Studies/DBIS/Graphics
export FSLDIR=${TOPDIR}/Scripts/Tools/FSL/Centos-5.0.11 
export PATH=${TOPDIR}/Scripts/Tools/mricrogl_lx:$FSLDIR/bin:$PATH # need this for a copy of dcm2niix that works properly
export FSLPATH=/cifs/hariri-long/Scripts/Tools/FSL/Centos-5.0.11 # need this for path to LowerCingulum_1mm

echo "----JOB [$SLURM_JOB_ID] SUBJ $SUBJ START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"
## Make the subject specific output directories
mkdir -p $OUTDIR/PA
mkdir -p $OUTDIR/AP_MDDW

cd $OUTDIR

## import data
cp $DATADIR/sub-${SUBJ}_acq-AP_dwi.bval $OUTDIR/AP_MDDW/AP_MDDW.bval
cp $DATADIR/sub-${SUBJ}_acq-AP_dwi.bvec $OUTDIR/AP_MDDW/AP_MDDW.bvec
cp $DATADIR/sub-${SUBJ}_acq-AP_dwi.nii.gz $OUTDIR/AP_MDDW/AP_MDDW.nii.gz
cp $DATADIR/sub-${SUBJ}_acq-PA_dwi.bval $OUTDIR/PA/b0_PA.bval
cp $DATADIR/sub-${SUBJ}_acq-PA_dwi.bvec $OUTDIR/PA/b0_PA.bvec
cp $DATADIR/sub-${SUBJ}_acq-PA_dwi.nii.gz $OUTDIR/PA/b0_PA.nii.gz


## sequence has one initial b0 image, then 6 at the end
## put them all in one image
fslroi AP_MDDW/AP_MDDW.nii.gz b0_AP_first 0 1
fslroi AP_MDDW/AP_MDDW.nii.gz b0_AP_last 65 6
fslmerge -t b0_ALL b0_AP_first b0_AP_last PA/b0_PA

## use topup to estimate and correct for the susceptibility induced field (caused by the scusceptibility distribution of the subject's head)
# DCCnotes: I didn't have to provide a full path to the cnf file before - not sure if this is because it isn't being sourced quite the same way now, dif env, etc?
topup --imain=b0_ALL --datain=$CONFIGDIR/DTI_params.txt --config=$FSLDIR/src/topup/flirtsch/b02b0.cnf --out=topup_b0_ALL --iout=topup_corrected
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

## correct for eddy currents. eddy output is not brain masked, but mask gets applied again in dtifit so its output is just brain
## set --initrand to true to ensure identical results between runs
## we started out using eddy_openmp bc the cluster's version of eddy had a bug; initrand doesn't work with _openmp it seems, but the cluster has now been updated with fsl-5.0.9, and now eddy works, so we'll just use that
## however, eddy in fsl-5.0.9 doesn't work with repol - there's a patch, but eddy_openmp in 5.0.10 DOES work with repol (still not with initrand though), and I installed it to Tools/FSL
## repol -> replace outliers from out of plane movements (If uncorrected this will affect any measures derived from the data)
## ol_type -> outlier type : both looks at multiband groups as a unit as well as slices individually
# export PATH=${TOPDIR/DBIS/DNS}/Scripts/Tools/FSL/fsl-5.0.10/fsl/bin:$PATH
# which eddy_openmp
# eddy_openmp --initrand=true --imain=AP_MDDW/AP_MDDW --mask=topup_corrected_brain_mask.nii.gz --acqp=$CONFIGDIR/DTI_params.txt --index=$CONFIGDIR/DTI_index.txt --bvecs=AP_MDDW/AP_MDDW.bvec --bvals=AP_MDDW/AP_MDDW.bval --topup=topup_b0_ALL --out=eddy_corrected_data --mb=3 --repol --ol_type=both
##DCCnotes: eddy_openmp 5.0.9 that I installed on DCC did not have the --ol_type option. Not sure if this is bc I'm using a dif linux version or if my above notes aren't entirely accurate. Updated to the Centos-5.0.11 and it works now.
if [[ $INITRAND == "initrand" ]]; then
  eddy --initrand=true --imain=AP_MDDW/AP_MDDW --mask=topup_corrected_brain_mask.nii.gz --acqp=$CONFIGDIR/DTI_params.txt --index=$CONFIGDIR/DTI_index.txt --bvecs=AP_MDDW/AP_MDDW.bvec --bvals=AP_MDDW/AP_MDDW.bval --topup=topup_b0_ALL --out=eddy_corrected_data 
else
  eddy_openmp --imain=AP_MDDW/AP_MDDW --mask=topup_corrected_brain_mask.nii.gz --acqp=$CONFIGDIR/DTI_params.txt --index=$CONFIGDIR/DTI_index.txt --bvecs=AP_MDDW/AP_MDDW.bvec --bvals=AP_MDDW/AP_MDDW.bval --topup=topup_b0_ALL --out=eddy_corrected_data --mb=3 --repol --ol_type=both
fi

## use fsl's dtifit to fit tensors
dtifit -k eddy_corrected_data.nii.gz -m topup_corrected_brain_mask.nii.gz -o fitted_data -r AP_MDDW/AP_MDDW.bvec -b AP_MDDW/AP_MDDW.bval

## prep for trackVis (just using this to generate images to send to SMs for now), needs all b0 volumes to be at beginning
finished=$(grep DMHDS$SUBJ $graphicsDir/Brain_Images/finished_processing.txt | wc -l)
if [ $finished -eq 0 ]; then
	if [ ! -e $graphicsDir/Brain_Images/ReadyToProcess_DTI/DMHDS$SUBJ/eddy_corrected_data_trackVis.nii.gz ]; then
		fslroi eddy_corrected_data.nii.gz tmp_b3000volumes 1 64
		fslroi eddy_corrected_data.nii.gz tmp_b0_AP_first_corrected 0 1 # ARK added this 7/31/18 - think beforeI was using uncorrected b0 volumes, and this should be slightly better
		fslroi eddy_corrected_data.nii.gz tmp_b0_AP_last_corrected 65 6 # ARK added this 7/31/18 - think beforeI was using uncorrected b0 volumes, and this should be slightly better
		fslmerge -t eddy_corrected_data_trackVis tmp_b0_AP_first_corrected tmp_b0_AP_last_corrected tmp_b3000volumes
		rm tmp_*
		mkdir $graphicsDir/Brain_Images/ReadyToProcess_DTI/DMHDS$SUBJ
		mv eddy_corrected_data_trackVis.nii.gz $graphicsDir/Brain_Images/ReadyToProcess_DTI/DMHDS$SUBJ
	fi
fi

## now run TBSS per ENIGMA pipeline
# use ENIGMA template (at least for now) bc Dunedin FOV is same and seems to work well
echo "Running tbss in FSL"
tbss_1_preproc fitted_data_FA.nii.gz
tbss_2_reg -t $TEMPLATEDIR/ENIGMA_DTI_FA.nii.gz
tbss_3_postreg -S

## apply resulting warp to MD image as well (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/TBSS/UserGuide: "Using non-FA Images in TBSS" suggests this is ok)
applywarp --ref=${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz --in=fitted_data_MD --warp=FA/fitted_data_FA_FA_to_target_warp --out=fitted_data_MD_to_target

## apply mask to normalized FA and MD images
fslmaths FA/fitted_data_FA_FA_to_target.nii.gz -mas $TEMPLATEDIR/ENIGMA_DTI_FA_mask.nii.gz FA/fitted_data_FA_FA_to_target_masked.nii.gz
fslmaths fitted_data_MD_to_target.nii.gz -mas $TEMPLATEDIR/ENIGMA_DTI_FA_mask.nii.gz fitted_data_MD_to_target_masked.nii.gz
 
## now skeletonize images by projecting the ENIGMA skeleton onto them
# a lower cingulum mask is included here because since that region is such a large bundle of fibers, 
#  the projection needs to incorporate 3 dimensions rather than only 2 as it does for the rest
# -i input image
# -p projectargs <skel_thresh> <distancemap> <search_rule_mask> <4Ddata> <projected_4Ddata> (requires_5_arguments)
# -s alternative skeleton
tbss_skeleton -i FA/fitted_data_FA_FA_to_target_masked.nii.gz  -p 0.049 $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton_mask_dst ${FSLPATH}/data/standard/LowerCingulum_1mm.nii.gz FA/fitted_data_FA_FA_to_target_masked.nii.gz stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz -s $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton_mask.nii.gz

## now extract ENIGMA ROIs
cd $TOPDIR/Templates/ThirdPartyOriginals/ENIGMA_ROI	

./singleSubjROI_exe ENIGMA_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz JHU-WhiteMatter-labels-1mm.nii.gz $OUTDIR/stats/ROIout $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz	
./singleSubjROI_exe LeftUF_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz rThresh10_LeftUF.nii.gz $OUTDIR/stats/ROIout_L_UF $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz
./singleSubjROI_exe RightUF_look_up_table.txt $TEMPLATEDIR/ENIGMA_DTI_FA_skeleton.nii.gz rThresh10_RightUF.nii.gz $OUTDIR/stats/ROIout_R_UF $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz

tail -1 $OUTDIR/stats/ROIout_L_UF.csv >> $OUTDIR/stats/ROIout.csv
tail -1 $OUTDIR/stats/ROIout_R_UF.csv >> $OUTDIR/stats/ROIout.csv
rm $OUTDIR/stats/ROIout_*_UF.csv

# print ROI values to master file, using a lock dir system to make sure only one process is trying to do this at a time
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
  if  mkdir $lockDir/DTI; then
	sleep 5  # seems like this is necessary to make sure any other processes have finished
    for file in $MasterFile ${MasterFile/averageFA/nVoxels} ${MasterFile/ENIGMA_ROIs_averageFA/QC}; do
		lineNum=$(grep -n DMHDS$SUBJ $file | cut -d: -f1);
		if [ $lineNum -gt 0 ]; then sed -ci "${lineNum}d" $file; fi # delete old line from file
	done
	vals1=$(tail -n +2 $OUTDIR/stats/ROIout.csv | cut -d, -f2 )
	vals2=$(tail -n +2 $OUTDIR/stats/ROIout.csv | cut -d, -f3 )
	echo DMHDS$SUBJ,$vals1 | sed 's/ /,/g' >> $MasterFile
	echo DMHDS$SUBJ,$vals2 | sed 's/ /,/g' >> ${MasterFile/averageFA/nVoxels}
	# print eddy QC stats to master file
	rms_list=$(awk '{print $2}' $OUTDIR/eddy_corrected_data.eddy_movement_rms); 
	rms_max=$(echo "${rms_list[*]}" | sort -nr | head -n1); 
	rrms_list=$(awk '{print $2}' $OUTDIR/eddy_corrected_data.eddy_restricted_movement_rms); 
	rrms_max=$(echo "${rrms_list[*]}" | sort -nr | head -n1); 
	str=DMHDS$SUBJ,$rms_max,$rrms_max
	for thr in 0 4 9; do
		flaggedSliceSums=$(awk '{ for(i=1; i<=NF;i++) j+=$i; print j; j=0 }' $OUTDIR/eddy_corrected_data.eddy_outlier_map | tail -71)
		nVolumesAboveThr=0; for i in `echo $flaggedSliceSums`; do if [[ $i -gt $thr ]]; then nVolumesAboveThr=$((nVolumesAboveThr+1)); fi; done; 
		str=$str,$nVolumesAboveThr 
	done	
	if [[ $(echo "$rms_max > 3" | bc ) -eq 1 ]]; then ok=0; else ok=1; fi
	echo "$str,$ok" >> ${MasterFile/ENIGMA_ROIs_averageFA/QC}
	rm -r $lockDir/DTI
	break
  else
    sleep 2
  fi
done
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

# print final skeleton image to png for easy visual inspection using slicer with -a option to print each view; this is hella easier than the other FA/MD vis checking code but leave that for now
slicer $OUTDIR/stats/fitted_data_FA_FA_to_target_masked_FAskel.nii.gz -a Final_Skeleton.png

## Clean Up
# at least for starting out, we'll be strict about deleting the larger files, 
# especially those that are just a few steps from dcm import and can easily be re-generated
cd $OUTDIR
rm AP_MDDW/*nii.gz
rm PA/*nii.gz
rm FA/target.nii.gz
rm FA/fitted_data_FA_FA_to_target.nii.gz
rm eddy_corrected_data.eddy_outlier_free_data.nii.gz # this is just the data with the outliers replaced (NOT eddy corrected)
rm fitted_data_MD_to_target.nii.gz
rm b0*nii.gz
rm -r origdata # this just contains fitted_data_FA.nii.gz, which is the same as FA/fitted_data_FA_FA.nii.gz except not masked
# these images are generated by TBSS to give group level statistics, which aren't relevant here since we're running individuals
rm stats/all_FA*
rm stats/mean_FA*
# rm eddy_corrected_data.nii.gz ????????????? it's huge but might need it (135MB)
# unzip final normalized FA file to allow for use in SPM
gunzip FA/fitted_data_FA_FA_to_target_masked.nii.gz

mkdir QA
mv *png QA
mv FA/slicesdir QA

cp $OUTDIR/QA/Final_Skeleton.png $graphicsDir/Data_Check/NewPipeline/DTI.Final_Skeleton/DMHDS$SUBJ.png
cp $OUTDIR/QA/FA_normalized_ENIGMA.png $graphicsDir/Data_Check/NewPipeline/DTI.FA_normalized_ENIGMA/DMHDS$SUBJ.png
cp $OUTDIR/QA/MD_normalized_ENIGMA.png $graphicsDir/Data_Check/NewPipeline/DTI.MD_normalized_ENIGMA/DMHDS$SUBJ.png



# -- END USER SCRIPT -- #


# **********************************************************
# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/DTI_DBIS.$SLURM_JOB_ID.out $OUTDIR/DTI_DBIS.$SLURM_JOB_ID.out 
# -- END POST-USER -- 


