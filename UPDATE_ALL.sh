#!/bin/sh

baseDir=/cifs/hariri-long/
scriptDir=$baseDir/Scripts/pipeline2.0_DBIS 
masterDir=$baseDir/Database/DBIS/Imaging/
outBase=$baseDir/Studies/DBIS/Imaging/derivatives/
# These files get written to so make sure they are closed before running this script!
logFile=$masterDir/LOG_processing.csv
notesFile=$masterDir/LOG_MRI_notes.csv
incFile=$masterDir/LOG_master_inclusion_list.csv
QAFile=$masterDir/QC/fMRI_FBIRN_QA.csv
T1QCFile=$masterDir/QC/T1_QC.csv

cd $baseDir/Studies/DBIS/Imaging/sourcedata

# first make a backup copy of the  master inclusion file
cp $incFile $masterDir/x_x.KEEP.OUT.x_x/LOGbackups/LOG_master_inclusion_list_bk_$(date | sed -e 's/ /_/g').csv

## SUBJECTS ids in BIDS format: sub-####
if [[ $# -eq 1 ]]; then 
	SUBJECTS=$1
else
	
	SUBJECTS=`ls -d sub-*`;
	
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
for SUBJ_BIDS in $SUBJECTS; do 

	SUBJ_NUM=${SUBJ_BIDS/sub-/}
	SUBJ_DMHDS=DMHDS$SUBJ_NUM
		
	finished=$(grep $SUBJ_DMHDS $logFile | cut -d, -f2)
	if [[ $finished -ne 1 ]]; then
		
		antDir=$outBase/ANTs/$SUBJ_BIDS
		freeDir=$outBase/freesurfer_v6.0/$SUBJ_BIDS

		submitted=0;

		## Run QA
		# # # ############################ need to update for BIDS format
		# # # if [ ! -e $baseDir/Studies/DBIS/QA/FBIRN_DMHDS/$SUBJ_DMHDS/index.html ]; then 
			# # # if [ -e $baseDir/Studies/DBIS/QA/$SUBJ_DMHDS ]; then 
				# # # rm -r $baseDir/Studies/DBIS/QA/$SUBJ_DMHDS; 
			# # # fi; 
			# # # sbatch $baseDir/Studies/DBIS/QA/runParticipantQA.sh $baseDir $SUBJ_DMHDS; submitted=1; 
		# # # fi

		## Process anatomical / EPIs / first level models
		# anat script checks if each component has been run before running it
		# end of anatomical script automatically submits epi_miProc for each task, which in turn automatically runs first-level glm
		if [[ ! -f ${antDir}/highRes_CorticalThicknessNormalizedToTemplate.nii.gz || \
			! -f ${antDir}/highRes_CorticalThicknessNormalizedToTemplate_blur6mm.nii.gz || \
			! -f ${antDir}/highRes_JacModVBM_blur8mm.nii ||  ! -f ${freeDir}/surf/rh.pial || \
			! -f ${freeDir}/surf/lh.woFLAIR.pial || \
			! -f ${freeDir}/SUMA/std.60.rh.thickness.niml.dset ]]; then
			sbatch -p scavenger $scriptDir/anat_DBIS.sh $SUBJ_NUM 1; submitted=1;
		fi
		
		## Process DTI
		if [ ! -e  $outBase/DTI_FSL/$SUBJ_BIDS/stats/ROIout.csv ]; then
			sbatch -p scavenger $scriptDir/DTI_DBIS.sh $SUBJ_NUM; submitted=1;
		fi

		## Run SPM VBM
		# arguments are: subject kernel_size prep_only vbm_only ("yes" or "no" for the last 2)
		if [ ! -e $outBase/VBM_SPM/$SUBJ_BIDS/DARTEL_8mm/smwc1HighRes.nii ]; then
			sbatch -p scavenger $scriptDir/VBM_SPM/vbm_dartel.sh $SUBJ_NUM 8 no no; submitted=1;
		fi

		## Run SUIT
		# arguments are: subject kernel_size prep_only vbm_only ("yes" or "no" for the last 2)
		if [ ! -e $outBase/SUIT/$SUBJ_BIDS/s4wcHighRes_seg1.nii ]; then
			sbatch -p scavenger $scriptDir/VBM_SPM/suit_batch.sh $SUBJ_NUM no no; submitted=1;
		fi
		
		## Add entry to log
		found=$(grep $SUBJ_DMHDS $logFile | wc -l)
		if [ $found -eq 0 ]; then
			jfile=$(ls $baseDir/Studies/DBIS/Imaging/sourcedata/$SUBJ_BIDS/anat/*T1*json | head -1);
			scandate=$(grep ScanDate $jfile | cut -d\" -f4);
			coil=$(grep Coil $jfile | cut -d\" -f4);
			echo $SUBJ_DMHDS,0,$(date),$scandate$(printf "%0.s,." {1..57}) >> $logFile; # printf is for multiple ",."s
			## Also other files
			echo $SUBJ_DMHDS$(printf "%0.s,." {1..7}) >> $T1QCFile;
			echo $SUBJ_DMHDS,$(date),$scandate$(printf "%0.s,." {1..18}) >> $QAFile;
			echo $SUBJ_DMHDS,$(date),$scandate,$coil$(printf "%0.s,." {1..18}) >> $notesFile;
			echo $SUBJ_DMHDS,$(date),$scandate$(printf "%0.s,." {1..38}) >> $incFile; # printf is for multiple ",."s
		fi		
		
		if [ $submitted -gt 0 ]; then echo "************************** Finished submitting jobs for $SUBJ_NUM***************************************"; fi

	fi # end if finished=1 in LOG_processing
	
done # loop through SUBJ



# # # ## Update phantom QA
# # # echo "************************** Running phantoms ***************************************"
# # # for f in `ls -d $baseDir/Studies/DBIS/QA/RAW_PHANTOM/Ph*`; do
	# # # if [ ! -e $baseDir/Studies/DBIS/QA/FBIRN_PHANTOM/$(basename $f) ] && [ ! -e $baseDir/Studies/DBIS/QA/FBIRN_PHANTOM/$(basename $f)_phantom-1 ]; then
		# # # sbatch $baseDir/Studies/DBIS/QA/runPhantomQA.sh $baseDir/ $(basename $f)
	# # # fi
# # # done
