#!/bin/bash
#
# Script: mondoRest.sh
# Purpose: Take all minimally preprocessed fMRI Scans,combine them into one. Treating all scans as measurements of intrinsic connectivity. Rest + "Pseudo Rest"
# Author: Maxwell Elliott


##############################################################################
#
# Environment set up
#
###############################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/GFC_noTaskReg_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/GFC_noTaskReg_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE  

sub=$1
TOPDIR=/cifs/hariri-long
imagingDir=$TOPDIR/Studies/DBIS/Imaging/derivatives

outDir=${imagingDir}/GFC_noTaskReg/${sub}
subDir=$outDir
#tmpOutDir=$TMPDIR
tmpDir=${outDir}/tmp
minProcRest=${imagingDir}/epiMinProc_rest/${sub}/epiWarped.nii.gz
minProcFaces=${imagingDir}/epiMinProc_faces/${sub}/epiWarped.nii.gz
minProcStroop=${imagingDir}/epiMinProc_stroop/${sub}/epiWarped.nii.gz
minProcMid=${imagingDir}/epiMinProc_mid/${sub}/epiWarped.nii.gz
minProcFacename=${imagingDir}/epiMinProc_facename/${sub}/epiWarped.nii.gz
templateDir=${TOPDIR}/Templates/DBIS/Wholebrain/ #pipenotes= update/Change away from HardCoding later
templatePre=dunedin115template_MNI_ #pipenotes= update/Change away from HardCoding later
antDir=${imagingDir}/ANTs/${sub}
antPre="highRes_" #pipenotes= Change away from HardCoding later
FDthresh=.35 #pipenotes= Change away from HardCoding later, also find citations for what you decide likely power 2014, minimun of .5 fd 20DVARS suggested
DVARSthresh=1.55 #pipenotes= Change away from HardCoding later, also find citations for what you decide

echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $sub START [`date`] on HOST [$HOSTNAME]----"

mkdir -p $tmpDir

if [[ ! -f ${minProcRest} && ${minProcFaces} && ${minProcStroop} && ${minProcMid} && ${minProcFacename} ]];then
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!Missing at least one minProc Dir!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!need to run epi_minProc_DBIS.sh first before this script!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
	exit
fi
voxSize=$(@GetAfniRes ${minProcRest})
3dresample -input ${templateDir}/${templatePre}Brain.nii.gz -dxyz $voxSize -prefix ${tmpDir}/refTemplate4epi.nii.gz
antsApplyTransforms -d 3 -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${tmpDir}/BrainSegmentationPosteriors1Warped2Template.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors1.nii.gz
antsApplyTransforms -d 3 -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${tmpDir}/BrainSegmentationPosteriors3Warped2Template.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors3.nii.gz
3dcalc -a ${tmpDir}/BrainSegmentationPosteriors3Warped2Template.nii.gz -b ${tmpDir}/BrainSegmentationPosteriors1Warped2Template.nii.gz -expr 'step(a-0.95)+step(b-0.95)' -prefix ${tmpDir}/seg.wm.csf.nii.gz
3dmerge -1clust_depth 5 5 -prefix ${tmpDir}/seg.wm.csf.depth.nii.gz ${tmpDir}/seg.wm.csf.nii.gz
3dcalc -a ${tmpDir}/seg.wm.csf.depth.nii.gz -expr 'step(a-1)' -prefix ${tmpDir}/seg.wm.csf.erode.nii.gz ##pipenotes:for DBIS may want to edit this to move further away from WM because of smaller voxels

for task in rest faces stroop mid facename;do
	3dcalc -a ${tmpDir}/seg.wm.csf.erode.nii.gz -b ${imagingDir}/epiMinProc_${task}/${sub}/epiWarped.nii.gz -expr 'a*b' -prefix ${tmpDir}/${task}.wm.csf.nii.gz
	3dpc -pcsave 5 -prefix ${tmpDir}/pc${task}.wm.csf ${tmpDir}/${task}.wm.csf.nii.gz
	mv ${tmpDir}/pc${task}.wm.csf_vec.1D ${outDir}/
	####Setup Censoring
	if [[ $task == "rest" ]];then
		cenTRdelta=0
	elif [[ $task == "faces" ]];then
		cenTRdelta=248
	elif [[ $task == "stroop" ]];then
		cenTRdelta=448
	elif [[ $task == "mid" ]];then
		cenTRdelta=657
	elif [[ $task == "facename" ]];then
		cenTRdelta=889
	else
		echo "failure in task censoring $task not found"
		exit
	fi
	awk -v thresh=$FDthresh '{if($1 > thresh) print NR}' ${imagingDir}/epiMinProc_${task}/${sub}/FD_FSL.1D | awk '{print ($1 - 1) " " $2}' > ${tmpDir}/raw${task}FDcensorTRs.1D #find TRs above threshold and subtract 1 from list to 0 index for afni's liking
	awk -v thresh=$DVARSthresh '{if($1 > thresh) print NR}' ${imagingDir}/epiMinProc_${task}/${sub}/DVARS.1D | awk '{print ($1) " " $2}' > ${tmpDir}/raw${task}DVARScensorTRs.1D #find TRs above threshold and Don't subtract 1 from list because DVARS is based on change from first TR and has one less value, value 1 will therefore be for afni 1 index (TR number 2)
	1deval -a ${tmpDir}/raw${task}FDcensorTRs.1D -expr "a+$cenTRdelta" > ${outDir}/FDcensorTRs${task}.1D
	1deval -a ${tmpDir}/raw${task}DVARScensorTRs.1D -expr "a+$cenTRdelta" > ${outDir}/DVARScensorTRs${task}.1D
done
#make subject mondoRest index lists
echo "task,rawLength,cenLength,rawBeginningTR,cenBeginningTR" >> ${outDir}/taskIndices.csv
numCenRest=$(cat ${outDir}/FDcensorTRsrest.1D ${outDir}/DVARScensorTRsrest.1D | sort -g | uniq | wc -w  )
restCenLength=$(echo "248 - $numCenRest" | bc -l)
echo "rest,248,${restCenLength},0,0" >> ${outDir}/taskIndices.csv
numCenFaces=$(cat ${outDir}/FDcensorTRsfaces.1D ${outDir}/DVARScensorTRsfaces.1D | sort -g | uniq | wc -w  )
facesCenLength=$(echo "200 - $numCenFaces" | bc -l)
echo "faces,200,$facesCenLength,248,${restCenLength}" >> ${outDir}/taskIndices.csv
numCenStroop=$(cat ${outDir}/FDcensorTRsstroop.1D ${outDir}/DVARScensorTRsstroop.1D | sort -g | uniq | wc -w  )
stroopCenLength=$(echo "209 - $numCenStroop" | bc -l)
stroopCenBeg=$(echo "$restCenLength + $facesCenLength" | bc -l)
echo "stroop,209,${stroopCenLength},448,${stoopCenBeg}" >> ${outDir}/taskIndices.csv
numCenMid=$(cat ${outDir}/FDcensorTRsmid.1D ${outDir}/DVARScensorTRsmid.1D | sort -g | uniq | wc -w  )
midCenLength=$(echo "232 - $numCenMid" | bc -l)
midCenBeg=$(echo "$restCenLength + $facesCenLength + $stroopCenLength" | bc -l)
echo "mid,232,${midCenLength},657,$midCenBeg" >> ${outDir}/taskIndices.csv
numCenFacename=$(cat ${outDir}/FDcensorTRsmid.1D ${outDir}/DVARScensorTRsmid.1D | sort -g | uniq | wc -w  )
facenameCenLength=$(echo "172 - $numCenFacename" | bc -l)
facenameCenBeg=$(echo "$restCenLength + $facesCenLength + $stroopCenLength + $midCenLength" | bc -l)
echo "facename,172,$facenameCenLength,889,$facenameCenBeg" >> ${outDir}/taskIndices.csv

cat ${outDir}/FDcensorTRs*.1D ${outDir}/DVARScensorTRs*.1D | sort -g | uniq > ${outDir}/censorTRs.1D #combine DVARS and FD TRs above threshold 
cat ${imagingDir}/epiMinProc_rest/${sub}/motion_spm_deg.1D ${imagingDir}/epiMinProc_faces/${sub}/motion_spm_deg.1D ${imagingDir}/epiMinProc_stroop/${sub}/motion_spm_deg.1D ${imagingDir}/epiMinProc_mid/${sub}/motion_spm_deg.1D ${imagingDir}/epiMinProc_facename/${sub}/motion_spm_deg.1D > ${outDir}/allmotion.1D
cat ${imagingDir}/epiMinProc_rest/${sub}/motion_deriv.1D ${imagingDir}/epiMinProc_faces/${sub}/motion_deriv.1D ${imagingDir}/epiMinProc_stroop/${sub}/motion_deriv.1D ${imagingDir}/epiMinProc_mid/${sub}/motion_deriv.1D ${imagingDir}/epiMinProc_facename/${sub}/motion_deriv.1D > ${outDir}/allmotion_deriv.1D
cat ${outDir}/pcrest.wm.csf_vec.1D ${outDir}/pcfaces.wm.csf_vec.1D ${outDir}/pcstroop.wm.csf_vec.1D ${outDir}/pcmid.wm.csf_vec.1D ${outDir}/pcfacename.wm.csf_vec.1D > ${outDir}/allCompCorr.1D

####Project everything out
clist=$(cat ${outDir}/censorTRs.1D)
lenC=$(echo $clist | wc -w )

if [[ $lenC == 0 ]];then
	3dTproject -input ${imagingDir}/epiMinProc_rest/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_faces/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_stroop/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_mid/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_facename/${sub}/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz  -prefix ${outDir}/epiPrepped_blur6mm.nii.gz -ort ${outDir}/allmotion.1D -ort ${outDir}/allmotion_deriv.1D -ort ${outDir}/allCompCorr.1D -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided again a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
else
	3dTproject -input ${imagingDir}/epiMinProc_rest/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_faces/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_stroop/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_mid/${sub}/epiWarped.nii.gz ${imagingDir}/epiMinProc_facename/${sub}/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz -prefix ${outDir}/epiPrepped_blur6mm.nii.gz -CENSORTR $clist -ort ${outDir}/allmotion.1D -ort ${outDir}/allmotion_deriv.1D -ort ${outDir}/allCompCorr.1D -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided against a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
fi

rm -r $tmpDir



#Extract timeSeries and corMat
${TOPDIR}/Scripts/utils/roi2CorMat.R -i ${outDir}/epiPrepped_blur6mm.nii.gz -r ${TOPDIR}/Templates/DBIS/Atlases/Power2011_264/power264_gm10_2mm.nii.gz > ${outDir}/CrossCorMat_Power264.txt

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/rest_DBIS.$SLURM_JOB_ID.out $outDir/rest_DBIS.$SLURM_JOB_ID.out 
# -- END POST-USER -- 

