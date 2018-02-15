#!/bin/sh

baseDir=/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01
scriptDir=$baseDir/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
logFile=$baseDir/Analysis/All_Imaging/LOG.csv
masterDir=$baseDir/Data/ALL_DATA_TO_USE/Imaging/

# copy master stats files from dir that is for script to write to only to dir that is for people to use; 
##could also use something like ls --ignore '*QC*' for the non-QC files?
echo "************************** Copying master stats files ***************************************"
cp $masterDir/x_x.KEEP.OUT.x_x/*QC* $masterDir/QC
cp $masterDir/x_x.KEEP.OUT.x_x/BOLD_R* $masterDir
cp $masterDir/x_x.KEEP.OUT.x_x/DTI_E* $masterDir
cp $masterDir/x_x.KEEP.OUT.x_x/Free* $masterDir
cp $masterDir/x_x.KEEP.OUT.x_x/VBM* $masterDir

cd $baseDir/Data/OTAGO

for SUBJ in `ls -d DMHDS[01]*`; do 

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
			! -f ${antDir}/highRes_CorticalThicknessNormalizedToTemplate_blur8mm.nii.gz || \
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
			echo $SUBJ,0,0,0,0,0,0,0,0,0,0,0,0,0 >> $logFile;
		fi
		
		if [ $submitted -gt 0 ]; then echo "************************** Finished submitting jobs for $SUBJ***************************************"; fi
		
	fi
	
done

echo "************************** Running phantoms ***************************************"

## Update phantom QA
for f in `ls -d Ph*`; do
	if [ ! -e $baseDir/Analysis/QA/FBIRN_PHANTOM/$f ] && [ ! -e $baseDir/Analysis/QA/FBIRN_PHANTOM/${f}_phantom-1 ]; then
		qsub -m ea -M ark19@duke.edu $baseDir/Analysis/QA/runPhantomQA.bash $baseDir/ $f
	fi
done
