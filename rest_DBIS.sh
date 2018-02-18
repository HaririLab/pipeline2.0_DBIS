#!/bin/bash
#
# Script: rest_DNS.sh
# Purpose: Take a minimally preprocessed Resting State Scan and finish preprocessing so that subject is ready for Group Analyses
# Author: Maxwell Elliott

################Steps to include#######################
#1)despike
#2)motion Regress 12 params
#3)censor
#4) bandpass
#5) compcorr
#6) 

###Eventually
#surface
#graph Analysis construction


###############################################################################
#
# Environment set up
#
###############################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=16G 
# -- END GLOBAL DIRECTIVE -- 

sub=$1
subDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/${sub}
outDir=${subDir}/rest
tmpOutDir=$TMPDIR
tmpDir=${tmpOutDir}/tmp
minProcEpi=${outDir}/epiWarped.nii.gz
templateDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/Templates #pipenotes= update/Change away from HardCoding later
templatePre=dunedin115template_MNI_ #pipenotes= update/Change away from HardCoding later
antDir=${subDir}/antCT
antPre="highRes_" #pipenotes= Change away from HardCoding later
FDthresh=.25 #pipenotes= Change away from HardCoding later, also find citations for what you decide likely power 2014, minimun of .5 fd 20DVARS suggested
DVARSthresh=1.55 #pipenotes= Change away from HardCoding later, also find citations for what you decide

mkdir -p $tmpDir
##Nest minProc within overarching rest directory
if [[ ! -f ${minProcEpi} ]];then
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!No minimally processed Rest Scan Found!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!need to run epi_minProc_DBIS.sh first before this script!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
	exit
fi

###Extract CompCor Components
voxSize=$(@GetAfniRes ${minProcEpi})
numTR=$(3dinfo -nv ${minProcEpi})
##Check to make sure rest scans are the same size
if [[ $numTR != 248 ]];then
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Rest scan is not 248 TRs!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!Check data & minProc Pipeline to make sure things add up!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
	exit
fi
3dresample -input ${templateDir}/${templatePre}Brain.nii.gz -dxyz $voxSize -prefix ${tmpDir}/refTemplate4epi.nii.gz
antsApplyTransforms -d 3 -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${tmpDir}/BrainSegmentationPosteriors1Warped2Template.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors1.nii.gz
antsApplyTransforms -d 3 -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${tmpDir}/BrainSegmentationPosteriors3Warped2Template.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors3.nii.gz
3dcalc -a ${tmpDir}/BrainSegmentationPosteriors3Warped2Template.nii.gz -b ${tmpDir}/BrainSegmentationPosteriors1Warped2Template.nii.gz -expr 'step(a-0.95)+step(b-0.95)' -prefix ${tmpDir}/seg.wm.csf.nii.gz
3dmerge -1clust_depth 5 5 -prefix ${tmpDir}/seg.wm.csf.depth.nii.gz ${tmpDir}/seg.wm.csf.nii.gz
3dcalc -a ${tmpDir}/seg.wm.csf.depth.nii.gz -expr 'step(a-1)' -prefix ${tmpDir}/seg.wm.csf.erode.nii.gz ##pipenotes:for DBIS may want to edit this to move further away from WM because of smaller voxels

3dcalc -a ${tmpDir}/seg.wm.csf.erode.nii.gz -b ${outDir}/epiWarped.nii.gz -expr 'a*b' -prefix ${tmpDir}/rest.wm.csf.nii.gz
3dpc -pcsave 5 -prefix ${tmpDir}/pcRest.wm.csf ${tmpDir}/rest.wm.csf.nii.gz
mv ${tmpDir}/pcRest.wm.csf_vec.1D ${tmpOutDir}/
####Setup Censoring
awk -v thresh=$FDthresh '{if($1 > thresh) print NR}' ${outDir}/FD.1D | awk '{print ($1 - 1) " " $2}' > ${tmpOutDir}/FDcensorTRs.1D #find TRs above threshold and subtract 1 from list to 0 index for afni's liking
awk -v thresh=$DVARSthresh '{if($1 > thresh) print NR}' ${outDir}/DVARS.1D | awk '{print ($1) " " $2}' > ${tmpOutDir}/DVARScensorTRs.1D #find TRs above threshold and Don't subtract 1 from list because DVARS is based on change from first TR and has one less value, value 1 will therefore be for afni 1 index (TR number 2)

cat ${tmpOutDir}/FDcensorTRs.1D ${tmpOutDir}/DVARScensorTRs.1D | sort -g | uniq > ${tmpOutDir}/censorTRs.1D #combine DVARS and FD TRs above threshold 
###cat ${outDir}/pcRest*.wm.csf_vec.1D > ${outDir}/allCompCorr.1D

####Project everything out
####################### replaced allmotion.1D with motion_spm_deg.1D and allmotion_deriv.1D with motion_deriv.1D
clist=$(cat ${outDir}/censorTRs.1D)
lenC=$(echo $clist | wc -w )
if [[ $lenC == 0 ]];then
	3dTproject -input ${outDir}/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz  -prefix ${tmpOutDir}/epiPrepped_blur6mm.nii.gz -ort ${outDir}/motion_spm_deg.1D -ort ${outDir}/motion_deriv.1D -ort ${tmpOutDir}/pcRest.wm.csf_vec.1D -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided again a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
else
	3dTproject -input ${outDir}/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz -prefix ${tmpOutDir}/epiPrepped_blur6mm.nii.gz -CENSORTR $clist -ort ${outDir}/motion_spm_deg.1D -ort ${outDir}/motion_deriv.1D -ort ${tmpOutDir}/pcRest.wm.csf_vec.1D -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided against a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
fi

rm -r $tmpDir
cp -r $tmpOutDir/* $outDir
#pipenotes: Cen options in 3dTproject start at 0, currently ours based on awk start with 1. Make sure to subtract 1 before giving to tproject!!!!

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $outDir/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 

