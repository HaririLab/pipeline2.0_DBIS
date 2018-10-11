#!/bin/bash

if [[ $# -lt 1 ]]; then 
	echo "Usage: CHECK_ALL.sh ID <list>"
	echo "  ID = DMHDS0205 (e.g.)"
	echo "  list = optional flag to print everything on one line for easy listing of many subjects"
fi

ID=$1
mode=$2

# These files get written to so make sure they are closed before running this script!
BASEDIR=/cifs/hariri-long
masterDir=$BASEDIR/Database/DBIS/Imaging/
logFile=$masterDir/LOG_processing.csv
notesFile=$masterDir/LOG_MRI_notes.csv
incFile=$masterDir/LOG_master_inclusion_list.csv
QAFile=$masterDir/QC/fMRI_FBIRN_QA.csv
T1QCFile=$masterDir/QC/T1_QC.csv
DTIQCFile=$masterDir/x_x.KEEP.OUT.x_x/DTI_QC.csv

gdir=$BASEDIR/Studies/DBIS/Graphics/Data_Check/NewPipeline
bdir=$BASEDIR/Studies/DBIS/Graphics/Brain_Images/ReadyToProcess
qdir=$BASEDIR/Studies/DBIS/QA/DMHDS_images
adir=$BASEDIR/Studies/DBIS/Imaging/derivatives
ddir=$BASEDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x
declare -A nROImeans; nROImeans[facename]=7; nROImeans[mid]=13; nROImeans[faces]=25; nROImeans[stroop]=5;
export CIFTIFY_WORKDIR=/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify

# first make a backup copy of the  master inclusion file
cp $incFile $masterDir/x_x.KEEP.OUT.x_x/LOGbackups/LOG_master_inclusion_list_bk_$(date | sed -e 's/ /_/g').csv

bidsID=sub-${ID/DMHDS/} # this is the ID in new BIDS format, e.g. sub-1200
if [[ $mode != list ]]; then	
	echo $ID
else
	output_str=$ID
fi

if [[ -e $gdir/anat.antCTCheck/$ID.png || -e $gdir/anat.antCTCheck/alreadyChecked/$ID.png ]]; then a1=1; else a1=0; fi
if [[ -e $gdir/anat.BrainExtractionCheckAxial/$ID.png || -e $gdir/anat.BrainExtractionCheckAxial/alreadyChecked/$ID.png ]]; then a2=1; else a2=0; fi
if [[ -e $adir/VBM_SPM/$bidsID/DARTEL_8mm/smwc1HighRes.nii ]]; then a3=1; else a3=0; fi
ct=$(grep $ID $BASEDIR/Studies/DBIS/Graphics/Brain_Images/finished_processing.txt | wc -l); if [[ -e $bdir/$ID/c1HighRes.nii.gz && -e $bdir/$ID/HighRes.nii.gz  && -e ${bdir}_DTI/$ID/eddy_corrected_data_trackVis.nii.gz ]] || [[ $ct -gt 0 ]]; then a4=1; else a4=0; fi
if [[ -e $gdir/DTI.FA_normalized_ENIGMA/$ID.png || -e $gdir/DTI.FA_normalized_ENIGMA/alreadyChecked/$ID.png ]]; then d1=1; else d1=0; fi
if [[ -e $gdir/DTI.Final_Skeleton/$ID.png || -e $gdir/DTI.Final_Skeleton/alreadyChecked/$ID.png ]]; then d2=1; else d2=0; fi
if [[ -e $adir/DTI_FSL/$bidsID/stats/ROIout.csv ]]; then d3=1; else d3=0; fi
if [[ -e $qdir/$ID.jpg || -e $qdir/alreadyChecked/$ID.jpg ]]; then q1=1; else q1=0; fi
FSct=$(grep $ID $ddir/FreeSurfer_aparc.a2009s_ThickAvg.csv | awk -F, '{print NF}'); if [[ $FSct -eq 149 ]]; then a5=1; else a5=0; fi
if [ ! -f $adir/ANTs/$bidsID/highRes_CorticalThicknessNormalizedToTemplate_blur6mm.nii ]; then a6=0; else a6=1; fi
if [ ! -f $adir/ANTs/$bidsID/highRes_JacModVBM_blur8mm.nii ]; then a7=0; else a7=1; fi
if [[ ! -f $adir/SUIT/$bidsID/s4wcHighRes_seg1.nii ]] || [[ ! -f $adir/SUIT/$bidsID/s8wcHighRes_seg1.nii ]]; then a12=0; else a12=1; fi
if [ ! -f $adir/freesurfer_v6.0/$bidsID/surf/rh.pial ]; then a8=0; else a8=1; fi
if [ ! -f $adir/freesurfer_v6.0/$bidsID/surf/lh.woFLAIR.pial ]; then a9=0; else a9=1; fi
if [ ! -f $adir/freesurfer_v6.0/$bidsID/scripts/recon-all.done ]; then a10=0; else a10=1; fi
if [ ! -f $adir/freesurfer_v6.0/$bidsID/SUMA/std.60.rh.thickness.niml.dset ]; then a11=0; else a11=1; fi

if [[ $mode != list ]]; then	
	echo -e "  anat.CTChec:   $a1 \t.BExCh: $a2 \t.vbmNii: $a3 \t.brImg: $a4 \t.FSext: $a5 \t.CT: $a6 \t.VBM: $a7 \t.SUIT: $a12 \t.pial1: $a8 \t.pial2: $a9 \t.reconDone: $a10\t.SUMA: $a11"
	echo -e "  DTI.FAcheck:   $d1 \t.skeCh: $d2 \t.ROIout: $d3 \t\t\tQA.png: $q1" 
else	
	output_str="$output_str $a1 $a2 $a3 $a4 $a5 $a6 $a7 $a12 $a8 $a9 $a10 $a11 $d1 $d2 $d3 $q1"
fi

for task in rest faces stroop mid facename; do
	if [[ $task == rest ]]; then
		if [[ -e $adir/epiMinProc_${task}/$bidsID/epiWarped.nii.gz ]]; then t1=1; else t1=0; fi
	else
		if [[ -e $adir/epiMinProc_${task}/$bidsID/epiWarped_blur6mm.nii.gz ]]; then t1=1; else t1=0; fi
	fi
	if [[ -e $gdir/$task.epi2TemplateAlignmentCheck/$ID.png || -e $gdir/$task.epi2TemplateAlignmentCheck/alreadyChecked/$ID.png ]]; then t2=1; else t2=0; fi
	censorLog=$(grep $ID $ddir/fMRI_QC_${task}.csv | wc -l);
	if [[ $censorLog -eq 1 ]]; then t5=1; else t5=0; fi
	if [[ $task == faces ]]; then
		if [[ -e $adir/epiMinProc_${task}/$bidsID/glm_AFNI_splitRuns/faces_gr_shapes_avg.nii.gz ]]; then gunzip $adir/epiMinProc_${task}/$bidsID/glm_AFNI_splitRuns/*gr*.nii.gz; fi
		if [[ -e $adir/epiMinProc_${task}/$bidsID/glm_AFNI_splitRuns/faces_gr_shapes_avg.nii ]]; then t3=1; else t3=0; fi
		ROImeans=$(grep $ID $ddir/fMRI_ROImeans_faces_glm_AFNI_splitRuns.csv | awk -F, '{print NF}');
		if [[ $ROImeans -eq ${nROImeans[$task]} ]]; then t4=1; else t4=0; fi
	else
		if [[ $task == rest ]]; then	
			if [[ -e $adir/epiMinProc_${task}/$bidsID/fslFD35/epiPrepped_blur6mm.nii.gz ]]; then 
				t3=1; 
			else 
				df=$(grep "total number of fixed regressors (176) is too many for" $adir/epiMinProc_${task}/$bidsID/fslFD35/rest_DBIS.*.out 2>/dev/null | wc -l); # check if the issue is not enough degrees of freedom
				if [[ $df -gt 0 ]]; then t3=e; else t3=0; fi
			fi
			t4=-; 
		else
			if [[ -e $adir/epiMinProc_${task}/$bidsID/glm_AFNI/glm_output_coefs.nii ]]; then t3=1; else t3=0; fi
			ROImeans=$(grep $ID $ddir/fMRI_ROImeans_${task}_glm_AFNI.csv | awk -F, '{print NF}');
			if [[ $ROImeans -eq ${nROImeans[$task]} ]]; then t4=1; else t4=0; fi
		fi
	fi
	if [[ $mode != list ]]; then	
		echo -e "  $task.epi:\t $t1 \t.check: $t2 \t.glmout: $t3 \t.extra: $t4 \t.censo: $t5"
	else
		output_str="$output_str $t1 $t2 $t3 $t4 $t5"
	fi
done

if [[ $mode == list ]]; then 
	echo $output_str
fi

if [[ -e $CIFTIFY_WORKDIR/$bidsID/MNINonLinear/Native/MSMSulc/R.transformed_and_reprojected.func.gii ]]; then c1=1; else c1=0; fi #MSM ciftify recon all
if [[ -e $CIFTIFY_WORKDIR/$bidsID/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii ]]; then c2=1; else c2=0; fi
if [[ -e $CIFTIFY_WORKDIR/$bidsID/MNINonLinear/Results/GFC/GFC_Atlas_s0_Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR_meants.csv ]]; then c3=1; else c3=0; fi
if [[ $mode != list ]]; then	
	echo -e "  cifti.recon:\t $c1 \t.fmri: $c2 \t.parc: $c3"
else
	output_str="$output_str $c1 $c2 $c3"
fi
		
## update master inclusion file: 
# cp from the files in the top directory rather within the KEEP.OUT directory because the latter are still being written to
# use | tr -dc '[[:print:]]' to remove non-printing characters
behavColNums_master=(15 20 25 30 35); tasks=(rest faces stroop mid facename);
qaColNums=(21 18 17 20 19);
scanIssue_firstCol=5; scanIssueColNums_master=(13 15 19 24 29 34 39 41);
finalized=$(grep $ID $incFile | cut -d, -f4)
if [[ $finalized != "1" ]]; then
	for i in `seq 0 4`; do # loop through tasks
		# behavioral check for functionals only (0 is rest)
		if [[ $i -ne 0 ]]; then
			behav=$(grep $ID $masterDir/x_x.KEEP.OUT.x_x/Behavioral_${tasks[$i]}.csv | awk -F, '{print $NF}' | tr -dc '[[:print:]]');
			if [[ ${#behav} -eq 0 ]]; then behav=NA; fi
		fi
		# motion and SNR 
		SNR=$(grep $ID $masterDir/x_x.KEEP.OUT.x_x/fMRI_QC_${tasks[$i]}.csv | awk -F, '{print $NF}' | tr -dc '[[:print:]]');
		motion=$(grep $ID $masterDir/x_x.KEEP.OUT.x_x/fMRI_QC_${tasks[$i]}.csv | awk -F, '{print $(NF-1)}' | tr -dc '[[:print:]]');
		# qa 
		qa=$(grep $ID $masterDir/QC/fMRI_FBIRN_QA.csv | cut -d, -f${qaColNums[$i]} | tr -dc '[[:print:]]');
		# write to file; motion column in master is right after behav column for each task, followed by SNR then QA (so for rest just set behavColNum to number before motion)
		if [[ $i -ne 0 ]]; then 
			awk -F, -v OFS=',' -v subj=$ID -v b=$behav -v m=$motion -v s=$SNR -v q=$qa -v col_b=${behavColNums_master[$i]} -v col_m=$((behavColNums_master[$i]+1)) -v col_s=$((behavColNums_master[$i]+2)) -v col_q=$((behavColNums_master[$i]+3)) '$1==subj{$col_b=b; $col_m=m; $col_s=s; $col_q=q}1' $incFile > $masterDir/x_x.KEEP.OUT.x_x/tmp.csv
		else
			awk -F, -v OFS=',' -v subj=$ID -v m=$motion -v s=$SNR -v q=$qa -v col_m=$((behavColNums_master[$i]+1)) -v col_s=$((behavColNums_master[$i]+2)) -v col_q=$((behavColNums_master[$i]+3)) '$1==subj{$col_m=m; $col_s=s; $col_q=q}1' $incFile > $masterDir/x_x.KEEP.OUT.x_x/tmp.csv
		fi
		mv $masterDir/x_x.KEEP.OUT.x_x/tmp.csv $incFile
	done
	# t1
	T1ok=$(grep $ID $T1QCFile | awk -F, '{print $NF}' | tr -dc '[[:print:]]');
	# DTI
	DTIok=$(grep $ID $DTIQCFile | awk -F, '{print $NF}' | tr -dc '[[:print:]]');
	# write to file again
	awk -F, -v OFS=',' -v subj=$ID -v t=$T1ok -v d=$DTIok -v col_t=14 -v col_d=40 '$1==subj{$col_t=t; $col_d=d}1' $incFile > $masterDir/x_x.KEEP.OUT.x_x/tmp.csv
	mv $masterDir/x_x.KEEP.OUT.x_x/tmp.csv $incFile
	# MRI notes
	for i in `seq 0 7`; do # loop through all scans
		ok=$(grep $ID $notesFile | cut -d, -f$((scanIssue_firstCol+$i)) | tr -dc '[[:print:]]');
		if [[ $ok == "1f" ]]; then
			note=$(grep $ID $notesFile | cut -d, -f$((scanIssue_firstCol+$i+8)) | tr -dc '[[:print:]]'); # all notes columns follow all ok columns
			str="${ok}: $note"
		else
			str=$ok
		fi
		# last write to file
		awk -F, -v OFS=',' -v subj=$ID -v val="$str" -v col=${scanIssueColNums_master[$i]} '$1==subj{$col=val}1' $incFile > $masterDir/x_x.KEEP.OUT.x_x/tmp.csv
		mv $masterDir/x_x.KEEP.OUT.x_x/tmp.csv $incFile
	done
fi # end if finalized=1 in LOG_master_inclusion_list
