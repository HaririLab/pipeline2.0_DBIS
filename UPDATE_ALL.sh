#!/bin/sh

baseDir=$(findexp DBIS.01)
scriptDir=$baseDir/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
masterDir=$baseDir/Data/ALL_DATA_TO_USE/Imaging/
logFile=$masterDir/LOG_processing.csv
QAFile=$masterDir/QC/fMRI_FBIRN_QA.csv
notesFile=$masterDir/LOG_MRI_notes.csv
incFile=$masterDir/LOG_master_inclusion_list.csv
behavColNums=(27 28 23 24); behavColNums_master=(25 31 37 43); tasks=(Faces Stroop MID Facename);

cd $baseDir/Data/OTAGO

if [[ $# -eq 1 ]]; then 
	SUBJECTS=$1
else
	SUBJECTS=`ls -d DMHDS[01]*`;
	
	# copy master stats files from dir that is for script to write to only to dir that is for people to use; 
	##could also use something like ls --ignore '*QC*' for the non-QC files?
	echo "************************** Copying master stats files ***************************************"
	cp $masterDir/x_x.KEEP.OUT.x_x/*QC* $masterDir/QC
	cp $masterDir/x_x.KEEP.OUT.x_x/fMRI_R* $masterDir
	cp $masterDir/x_x.KEEP.OUT.x_x/DTI_E* $masterDir
	cp $masterDir/x_x.KEEP.OUT.x_x/Free* $masterDir/FreeSurfer
	cp $masterDir/x_x.KEEP.OUT.x_x/VBM* $masterDir
	cp $masterDir/x_x.KEEP.OUT.x_x/Behav* $masterDir/fMRI_Behavioral
	
fi

echo "************************** Updating subjects who haven't been processed ***************************************"
for SUBJ in $SUBJECTS; do 

	finished=$(grep $SUBJ $logFile | cut -d, -f2)
	if [[ $finished -ne 1 ]]; then
	
		outDir=$baseDir/Analysis/All_Imaging/$SUBJ
		antDir=${outDir}/antCT
		freeDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/FreeSurfer_AllSubs/${SUBJ}

		submitted=0;

		## Run QA
		if [ ! -e $baseDir/Analysis/QA/FBIRN_DMHDS/$SUBJ/index.html ]; then 
			if [ -e $baseDir/Analysis/QA/$SUBJ ]; then 
				rm -r $baseDir/Analysis/QA/$SUBJ; 
			fi; 
			qsub -m ea -M ark19@duke.edu $baseDir/Analysis/QA/runParticipantQA.sh $baseDir/ $SUBJ; submitted=1;
		fi

		## Process anatomical / EPIs / first level models
		# anat script checks if each component has been run before running it
		# end of anatomical script automatically submits epi_miProc for each task, which in turn automatically runs first-level glm
		if [[ ! -f ${antDir}/highRes_CorticalThicknessNormalizedToTemplate.nii.gz || \
			! -f ${antDir}/highRes_CorticalThicknessNormalizedToTemplate_blur6mm.nii.gz || \
			! -f ${antDir}/highRes_JacModVBM_blur8mm.nii ||  ! -f ${freeDir}/surf/rh.pial || \
			! -f ${freeDir}/surf/lh.woFLAIR.pial || \
			! -f ${freeDir}/SUMA/std.60.rh.thickness.niml.dset ]]; then
			qsub -m ea -M ark19@duke.edu $scriptDir/anat_DBIS.sh $SUBJ 1; submitted=1;
		fi
		
		## Process DTI
		if [ ! -e  $outDir/DTI/stats/ROIout.csv ]; then
			qsub -m ea -M ark19@duke.edu $scriptDir/DTI_DBIS.bash $SUBJ; submitted=1;
		fi

		## Run SPM VBM
		# arguments are: subject kernel_size prep_only vbm_only ("yes" or "no" for the last 2)
		if [ ! -e $baseDir/Analysis/SPM/Processed/$SUBJ/anat/VBM_DARTEL_8mm/smwc1HighRes.nii ]; then
			qsub -m ea -M ark19@duke.edu $baseDir/Scripts/SPM/VBM/vbm_dartel.sh $SUBJ 8 no no; submitted=1;
		fi

		## Add entry to log
		found=$(grep $SUBJ $logFile | wc -l)
		if [ $found -eq 0 ]; then
			dcm1=$(ls $baseDir/Data/OTAGO/$SUBJ/DMHDS/MR_t1_0.9_mprage_sag_iso_p2/*dcm | head -1)
			scandate=$(dicom_hdr $dcm1 | grep "ID Study Date" | cut -d"/" -f5)
			echo $SUBJ,0,$(date),$scandate$(printf "%0.s,0" {1..54}) >> $logFile; # printf is for multiple ",0"s
			## Also QA file
			echo $SUBJ,$(date),$scandate >> $QAFile;
			echo $SUBJ,$(date),$scandate >> $notesFile;
			echo $SUBJ,0,$(date),$scandate$(printf "%0.s,0" {1..56}) >> $incFile; # printf is for multiple ",0"s
		fi		
		
		if [ $submitted -gt 0 ]; then echo "************************** Finished submitting jobs for $SUBJ***************************************"; fi
		
	fi

	## update master inclusion file
	#echo "************************** Updating master inclusion file ***************************************"
	finalized=$(grep $SUBJ $incFile | cut -d, -f2)
	if [[ $finalized -ne 1 ]]; then
		# behavioral check
		for i in `seq 0 3`; do 
			behav=$(grep $SUBJ $masterDir/fMRI_Behavioral/Behavioral_${tasks[$i]}.csv | cut -d, -f${behavColNums[$i]});
			awk -F, -v OFS=',' -v subj=$SUBJ -v val=$behav -v col=${behavColNums_master[$i]} '$1==subj{$col=val}1'
		done
	fi
	
done # loop through SUBJ



## Update phantom QA
echo "************************** Running phantoms ***************************************"
for f in `ls -d Ph*`; do
	if [ ! -e $baseDir/Analysis/QA/FBIRN_PHANTOM/$f ] && [ ! -e $baseDir/Analysis/QA/FBIRN_PHANTOM/${f}_phantom-1 ]; then
		qsub -m ea -M ark19@duke.edu $baseDir/Analysis/QA/runPhantomQA.bash $baseDir/ $f
	fi
done
