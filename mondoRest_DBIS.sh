#!/bin/bash
#
# Script: mondoRest.sh
# Purpose: Take all minimally preprocessed fMRI Scans,combine them into one. Treating all scans as measurements of intrinsic connectivity. Rest + "Pseudo Rest"
# Author: Maxwell Elliott


###############################################################################
#
# Environment set up
#
###############################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=12G 
# -- END GLOBAL DIRECTIVE -- 

sub=$1
subDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/${sub}
outDir=${subDir}/mondoRest
tmpOutDir=$TMPDIR
tmpDir=${tmpOutDir}/tmp
minProcRest=${subDir}/rest/epiWarped.nii.gz
minProcFaces=${subDir}/faces/epiWarped.nii.gz
minProcStroop=${subDir}/stroop/epiWarped.nii.gz
minProcMid=${subDir}/mid/epiWarped.nii.gz
minProcFacename=${subDir}/facename/epiWarped.nii.gz
templateDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/Templates #pipenotes= update/Change away from HardCoding later
templatePre=dunedin115template_MNI_ #pipenotes= update/Change away from HardCoding later
antDir=${subDir}/antCT
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
	3dcalc -a ${tmpDir}/seg.wm.csf.erode.nii.gz -b ${subDir}/${task}/epiWarped.nii.gz -expr 'a*b' -prefix ${tmpDir}/${task}.wm.csf.nii.gz
	3dpc -pcsave 5 -prefix ${tmpDir}/pc${task}.wm.csf ${tmpDir}/${task}.wm.csf.nii.gz
	mv ${tmpDir}/pc${task}.wm.csf_vec.1D ${tmpOutDir}/
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
	awk -v thresh=$FDthresh '{if($1 > thresh) print NR}' ${subDir}/${task}/FD_FSL.1D | awk '{print ($1 - 1) " " $2}' > ${tmpDir}/raw${task}FDcensorTRs.1D #find TRs above threshold and subtract 1 from list to 0 index for afni's liking
	awk -v thresh=$DVARSthresh '{if($1 > thresh) print NR}' ${subDir}/${task}/DVARS.1D | awk '{print ($1) " " $2}' > ${tmpDir}/raw${task}DVARScensorTRs.1D #find TRs above threshold and Don't subtract 1 from list because DVARS is based on change from first TR and has one less value, value 1 will therefore be for afni 1 index (TR number 2)
	1deval -a ${tmpDir}/raw${task}FDcensorTRs.1D -expr "a+$cenTRdelta" > ${tmpOutDir}/FDcensorTRs${task}.1D
	1deval -a ${tmpDir}/raw${task}DVARScensorTRs.1D -expr "a+$cenTRdelta" > ${tmpOutDir}/DVARScensorTRs${task}.1D
done
#make subject mondoRest index lists
echo "task,rawLength,cenLength,rawBeginningTR,cenBeginningTR" >> ${tmpOutDir}/taskIndices.csv
numCenRest=$(cat ${tmpOutDir}/FDcensorTRsrest.1D ${tmpOutDir}/DVARScensorTRsrest.1D | sort -g | uniq | wc -w  )
restCenLength=$(echo "248 - $numCenRest" | bc -l)
echo "rest,248,${restCenLength},0,0" >> ${tmpOutDir}/taskIndices.csv
numCenFaces=$(cat ${tmpOutDir}/FDcensorTRsfaces.1D ${tmpOutDir}/DVARScensorTRsfaces.1D | sort -g | uniq | wc -w  )
facesCenLength=$(echo "200 - $numCenFaces" | bc -l)
echo "faces,200,$facesCenLength,248,${restCenLength}" >> ${tmpOutDir}/taskIndices.csv
numCenStroop=$(cat ${tmpOutDir}/FDcensorTRsstroop.1D ${tmpOutDir}/DVARScensorTRsstroop.1D | sort -g | uniq | wc -w  )
stroopCenLength=$(echo "209 - $numCenStroop" | bc -l)
stroopCenBeg=$(echo "$restCenLength + $facesCenLength" | bc -l)
echo "stroop,209,${stroopCenLength},448,${stoopCenBeg}" >> ${tmpOutDir}/taskIndices.csv
numCenMid=$(cat ${tmpOutDir}/FDcensorTRsmid.1D ${tmpOutDir}/DVARScensorTRsmid.1D | sort -g | uniq | wc -w  )
midCenLength=$(echo "232 - $numCenMid" | bc -l)
midCenBeg=$(echo "$restCenLength + $facesCenLength + $stroopCenLength" | bc -l)
echo "mid,232,${midCenLength},657,$midCenBeg" >> ${tmpOutDir}/taskIndices.csv
numCenFacename=$(cat ${tmpOutDir}/FDcensorTRsmid.1D ${tmpOutDir}/DVARScensorTRsmid.1D | sort -g | uniq | wc -w  )
facenameCenLength=$(echo "172 - $numCenFacename" | bc -l)
facenameCenBeg=$(echo "$restCenLength + $facesCenLength + $stroopCenLength + $midCenLength" | bc -l)
echo "facename,172,$facenameCenLength,889,$facenameCenBeg" >> ${tmpOutDir}/taskIndices.csv

cat ${tmpOutDir}/FDcensorTRs*.1D ${tmpOutDir}/DVARScensorTRs*.1D | sort -g | uniq > ${tmpOutDir}/censorTRs.1D #combine DVARS and FD TRs above threshold 
cat ${subDir}/rest/motion_spm_deg.1D ${subDir}/faces/motion_spm_deg.1D ${subDir}/stroop/motion_spm_deg.1D ${subDir}/mid/motion_spm_deg.1D ${subDir}/facename/motion_spm_deg.1D > ${tmpOutDir}/allmotion.1D
cat ${subDir}/rest/motion_deriv.1D ${subDir}/faces/motion_deriv.1D ${subDir}/stroop/motion_deriv.1D ${subDir}/mid/motion_deriv.1D ${subDir}/facename/motion_deriv.1D > ${tmpOutDir}/allmotion_deriv.1D
cat ${tmpOutDir}/pcrest.wm.csf_vec.1D ${tmpOutDir}/pcfaces.wm.csf_vec.1D ${tmpOutDir}/pcstroop.wm.csf_vec.1D ${tmpOutDir}/pcmid.wm.csf_vec.1D ${tmpOutDir}/pcfacename.wm.csf_vec.1D > ${tmpOutDir}/allCompCorr.1D

####Project everything out
clist=$(cat ${tmpOutDir}/censorTRs.1D)
lenC=$(echo $clist | wc -w )

if [[ $lenC == 0 ]];then
	3dTproject -input ${subDir}/rest/epiWarped.nii.gz ${subDir}/faces/epiWarped.nii.gz ${subDir}/stroop/epiWarped.nii.gz ${subDir}/mid/epiWarped.nii.gz ${subDir}/facename/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz  -prefix ${tmpOutDir}/epiPrepped_blur6mm.nii.gz -ort ${tmpOutDir}/allmotion.1D -ort ${tmpOutDir}/allmotion_deriv.1D -ort ${tmpOutDir}/allCompCorr.1D -ort ${outDir}/TaskRegressors.txt -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided again a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
else
	3dTproject -input ${subDir}/rest/epiWarped.nii.gz ${subDir}/faces/epiWarped.nii.gz ${subDir}/stroop/epiWarped.nii.gz ${subDir}/mid/epiWarped.nii.gz ${subDir}/facename/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz -prefix ${tmpOutDir}/epiPrepped_blur6mm.nii.gz -CENSORTR $clist -ort ${tmpOutDir}/allmotion.1D -ort ${tmpOutDir}/allmotion_deriv.1D -ort ${tmpOutDir}/allCompCorr.1D -ort ${outDir}/TaskRegressors.txt -polort 1 -bandpass 0.008 0.10 -blur 6
##comments: Decided against a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
fi

rm -r $tmpDir

##Now copy all files to the server using rsync for robustness
mkdir -p $outDir
rsync -r -v --stats --progress $tmpOutDir/* $outDir # check out -W option, --timeout
returncode=$?
##Doesn't always work the first time so check and try again if not
ct=1
while [[ $returncode -ne 0 ]] && [[ $ct -lt 5 ]]; do
	echo rsync return code: $?
	rsync -r -v --stats --progress $tmpOutDir/* $outDir # check out -W option, --timeout
	returncode=$?
	ct=$((ct+1))
done

#Extract timeSeries and corMat
/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Scripts/pipeline2.0_DBIS/utils/roi2CorMat.R -i ${outDir}/epiPrepped_blur6mm.nii.gz -r /mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/Templates/Power2011_264/power264_gm10_2mm.nii.gz > ${outDir}/CrossCorMat_Power264.txt

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $outDir/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER --
