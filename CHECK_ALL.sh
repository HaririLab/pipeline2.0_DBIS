#!/bin/bash

if [[ $# -lt 1 ]]; then 
	echo "Usage: CHECK_ALL.sh ID <list>"
	echo "  ID = DMHDS0205 (e.g.)"
	echo "  list = optional flag to print everything on one line for easy listing of many subjects"
fi

ID=$1
mode=$2

if [[ $mode != list ]]; then	
	echo $ID
else
	output_str=$ID
fi

BASEDIR=$(findexp DBIS.01)
gdir=$BASEDIR/Graphics/Data_Check/NewPipeline
bdir=$BASEDIR/Graphics/Brain_Images/ReadyToProcess
qdir=$BASEDIR/Analysis/QA/DMHDS_images
adir=$BASEDIR/Analysis/All_Imaging
vdir=$BASEDIR/Analysis/SPM/Processed
ddir=$BASEDIR/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x
declare -A nROImeans; nROImeans[facename]=7; nROImeans[mid]=13; nROImeans[faces]=25; nROImeans[stroop]=5;

if [[ -e $gdir/anat.antCTCheck/$ID.png || -e $gdir/anat.antCTCheck/alreadyChecked/$ID.png ]]; then a1=1; else a1=0; fi
if [[ -e $gdir/anat.BrainExtractionCheckAxial/$ID.png || -e $gdir/anat.BrainExtractionCheckAxial/alreadyChecked/$ID.png ]]; then a2=1; else a2=0; fi
if [[ -e $vdir/$ID/anat/VBM_DARTEL_8mm/smwc1HighRes.nii ]]; then a3=1; else a3=0; fi
if [[ -e $bdir/$ID/c1HighRes.nii.gz && -e $bdir/$ID/HighRes.nii.gz ]]; then a4=1; else a4=0; fi
if [[ -e $gdir/DTI.FA_normalized_ENIGMA/$ID.png || -e $gdir/DTI.FA_normalized_ENIGMA/alreadyChecked/$ID.png ]]; then d1=1; else d1=0; fi
if [[ -e $gdir/DTI.Final_Skeleton/$ID.png || -e $gdir/DTI.Final_Skeleton/alreadyChecked/$ID.png ]]; then d2=1; else d2=0; fi
if [[ -e $adir/$ID/DTI/stats/ROIout.csv ]]; then d3=1; else d3=0; fi
if [[ -e $qdir/$ID.jpg || -e $qdir/alreadyChecked/$ID.jpg ]]; then q1=1; else q1=0; fi
FSct=$(grep $ID $ddir/FreeSurfer_aparc.a2009s_ThickAvg.csv | awk -F, '{print NF}'); if [[ $FSct -eq 149 ]]; then a5=1; else a5=0; fi

if [[ $mode != list ]]; then	
	echo -e "  anat.CTChec:   $a1 \t.BExCh: $a2 \t.vbmNii: $a3 \t.brImg: $a4 \t.FSext: $a5"
	echo -e "  DTI.FAcheck:   $d1 \t.skeCh: $d2 \t.ROIout: $d3 \t\t\tQA.png: $q1" 
else	
	output_str="$output_str $a1 $a2 $a3 $a4 $a5 $d1 $d2 $d3 $q1"
fi

for task in rest faces stroop mid facename; do
	if [[ $task == rest ]]; then
		if [[ -e $adir/$ID/$task/epiWarped.nii.gz ]]; then t1=1; else t1=0; fi
	else
		if [[ -e $adir/$ID/$task/epiWarped_blur6mm.nii.gz ]]; then t1=1; else t1=0; fi
	fi
	if [[ -e $gdir/$task.epi2TemplateAlignmentCheck/$ID.png || -e $gdir/$task.epi2TemplateAlignmentCheck/alreadyChecked/$ID.png ]]; then t2=1; else t2=0; fi
	censorLog=$(grep $ID $ddir/BOLD_QC_${task}_nFramesKept.csv | wc -l);
	if [[ $censorLog -eq 1 ]]; then t5=1; else t5=0; fi
	if [[ $task == faces ]]; then
		if [[ -e $adir/$ID/$task/glm_AFNI_splitRuns/faces_gr_shapes_avg.nii.gz ]]; then t3=1; else t3=0; fi
		ROImeans=$(grep $ID $ddir/BOLD_ROImeans_faces_glm_AFNI_splitRuns.csv | awk -F, '{print NF}');
		if [[ $ROImeans -eq ${nROImeans[$task]} ]]; then t4=1; else t4=0; fi
	else
		if [[ $task == rest ]]; then	
			if [[ -e $adir/$ID/$task/fslFD35/epiPrepped_blur6mm.nii.gz ]]; then t3=1; else t3=0; fi
			t4=-; t5=-;
		else
			if [[ -e $adir/$ID/$task/glm_AFNI/glm_output_coefs.nii ]]; then t3=1; else t3=0; fi
			ROImeans=$(grep $ID $ddir/BOLD_ROImeans_${task}_glm_AFNI.csv | awk -F, '{print NF}');
			if [[ $task != stroop ]]; then
				if [[ $ROImeans -eq ${nROImeans[$task]} ]]; then t4=1; else t4=0; fi
			else
				if [[ $ROImeans -gt ${nROImeans[$task]} ]]; then t4=1; else t4=0; fi
			fi
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
