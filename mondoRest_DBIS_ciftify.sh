#!/bin/bash
#
# Script: mondoRest_DBIS_ciftify.sh
# Purpose: Take all minimally preprocessed fMRI Scans,combine them into one. Treating all scans as measurements of intrinsic connectivity. Rest + "Pseudo Rest" . Do this on the ciftify surface
# Author: Maxwell Elliott


###############################################################################
#
# Environment set up
#
###############################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/epi_minProc_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/epi_minProc_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=16000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -


 
sub=$1  ##Just the number
TOPDIR=/cifs/hariri-long
scriptDir=$TOPDIR/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
imagingDir=$TOPDIR/Studies/DBIS/Imaging
QADir=$imagingDir/derivatives/QA/sub-${sub}
antDir=$imagingDir/derivatives/ANTs/sub-${sub}
subDir=${imagingDir}/derivatives/epiMinProc_${task}/sub-${sub}
freeDir=$imagingDir/derivatives/freesurfer_v6.0/sub-${sub}
ciftify_reconDir=$imagingDir/derivatives/ciftify/sub-${sub}
minProcRest=$imagingDir/derivatives/ciftify_epiMinProc_rest/sub-${sub}/epi2highRes.nii.gz
minProcFaces=$imagingDir/derivatives/ciftify_epiMinProc_faces/sub-${sub}/epi2highRes.nii.gz
minProcStroop=$imagingDir/derivatives/ciftify_epiMinProc_stroop/sub-${sub}/epi2highRes.nii.gz
minProcMid=$imagingDir/derivatives/ciftify_epiMinProc_mid/sub-${sub}/epi2highRes.nii.gz
minProcFacename=$imagingDir/derivatives/ciftify_epiMinProc_facename/sub-${sub}/epi2highRes.nii.gz
outDir=$imagingDir/derivatives/ciftify_GFC/sub-${sub}
tmpDir=${outDir}/tmp
antPre="highRes_"

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
3dresample -input ${ciftify_reconDir}/T1w/T1w.nii.gz -dxyz $voxSize -prefix ${tmpDir}/refTemplate4epi.nii.gz
3dcalc -a ${antDir}/${antPre}BrainSegmentationPosteriors3.nii.gz -b ${antDir}/${antPre}BrainSegmentationPosteriors1.nii.gz -expr 'step(a-0.95)+step(b-0.95)' -prefix ${tmpDir}/tmp.seg.wm.csf.nii.gz
3dresample -input ${tmpDir}/tmp.seg.wm.csf.nii.gz -master ${tmpDir}/refTemplate4epi.nii.gz -prefix ${tmpDir}/seg.wm.csf.nii.gz
3dmerge -1clust_depth 5 5 -prefix ${tmpDir}/seg.wm.csf.depth.nii.gz ${tmpDir}/seg.wm.csf.nii.gz
3dcalc -a ${tmpDir}/seg.wm.csf.depth.nii.gz -expr 'step(a-1)' -prefix ${tmpDir}/seg.wm.csf.erode.nii.gz ##pipenotes:for DBIS may want to edit this to move further away from WM because of smaller voxels

for task in rest faces stroop mid facename;do
	3dcalc -a ${tmpDir}/seg.wm.csf.erode.nii.gz -b $imagingDir/derivatives/ciftify_epiMinProc_${task}/sub-${sub}/epi2highRes.nii.gz -expr 'a*b' -prefix ${tmpDir}/${task}.wm.csf.nii.gz
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
	awk -v thresh=$FDthresh '{if($1 > thresh) print NR}' ${imagingDir}/derivatives/epiMinProc_${task}/sub-${sub}/FD_FSL.1D | awk '{print ($1 - 1) " " $2}' > ${tmpDir}/raw${task}FDcensorTRs.1D #find TRs above threshold and subtract 1 from list to 0 index for afni's liking
	awk -v thresh=$DVARSthresh '{if($1 > thresh) print NR}' ${imagingDir}/derivatives/epiMinProc_${task}/sub-${sub}/DVARS.1D | awk '{print ($1) " " $2}' > ${tmpDir}/raw${task}DVARScensorTRs.1D #find TRs above threshold and Don't subtract 1 from list because DVARS is based on change from first TR and has one less value, value 1 will therefore be for afni 1 index (TR number 2)
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
cat ${imagingDir}/derivatives/epiMinProc_rest/sub-${sub}/motion_spm_deg.1D ${imagingDir}/derivatives/epiMinProc_faces/sub-${sub}/motion_spm_deg.1D ${imagingDir}/derivatives/epiMinProc_stroop/sub-${sub}/motion_spm_deg.1D ${imagingDir}/derivatives/epiMinProc_mid/sub-${sub}/motion_spm_deg.1D ${imagingDir}/derivatives/epiMinProc_facename/sub-${sub}/motion_spm_deg.1D > ${outDir}/allmotion.1D
cat ${imagingDir}/derivatives/epiMinProc_rest/sub-${sub}/motion_deriv.1D ${imagingDir}/derivatives/epiMinProc_faces/sub-${sub}/motion_deriv.1D ${imagingDir}/derivatives/epiMinProc_stroop/sub-${sub}/motion_deriv.1D ${imagingDir}/derivatives/epiMinProc_mid/sub-${sub}/motion_deriv.1D ${imagingDir}/derivatives/epiMinProc_facename/sub-${sub}/motion_deriv.1D > ${outDir}/allmotion_deriv.1D
cat ${outDir}/pcrest.wm.csf_vec.1D ${outDir}/pcfaces.wm.csf_vec.1D ${outDir}/pcstroop.wm.csf_vec.1D ${outDir}/pcmid.wm.csf_vec.1D ${outDir}/pcfacename.wm.csf_vec.1D > ${outDir}/allCompCorr.1D

####Project everything out
clist=$(cat ${outDir}/censorTRs.1D)
lenC=$(echo $clist | wc -w )

if [[ $lenC == 0 ]];then
	3dTproject -input ${minProcRest} ${minProcFaces} ${minProcFacename} ${minProcMid} ${minProcStroop} -prefix ${outDir}/epiPrepped.nii.gz -ort ${outDir}/allmotion.1D -ort ${outDir}/allmotion_deriv.1D -ort ${outDir}/allCompCorr.1D -ort ${imagingDir}/derivatives/GFC/sub-${sub}/TaskRegressors.txt -polort 1 -bandpass 0.008 0.10
##comments: Decided again a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
else
	3dTproject -input ${minProcRest} ${minProcFaces} ${minProcFacename} ${minProcMid} ${minProcStroop} -prefix ${outDir}/epiPrepped.nii.gz -CENSORTR $clist -ort ${outDir}/allmotion.1D -ort ${outDir}/allmotion_deriv.1D -ort ${outDir}/allCompCorr.1D -ort ${imagingDir}/derivatives/GFC/sub-${sub}/TaskRegressors.txt -polort 1 -bandpass 0.008 0.10
##comments: Decided against a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
fi

#rm -r $tmpDir

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $outDir/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER --
