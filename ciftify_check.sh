#!/bin/bash
#
# check that subject successfully completed ciftify
# source ~/.bash_profile
# export PATH=$PATH:/cifs/hariri-long/Scripts/Tools/python/ciftify/ciftify/bin:/cifs/hariri-long/Scripts/Tools/workbench/bin_rh_linux64
# export PYTHONPATH=$PYTHONPATH:/cifs/hariri-long/Scripts/Tools/python/ciftify
# export CIFTIFY_TEMPLATES=/cifs/hariri-long/Scripts/Tools/python/ciftify/ciftify/data
# export CIFTIFY_WORKDIR=/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify
# source /cifs/hariri-long/Scripts/bash_profile
# module load Anaconda3/5.1.0
# module load Parallel/20180322
# module load GCC/5.4.0
#note: need to pip install docopts and nilearn to your local python lib (not included in anaconda)
#note: msm needs more ram
# for id in `awk -F, '{print $1}' $H/Scripts/pipeline2.0_DBIS/config/first500scans.txt | head -100 | sed 's/DMHDS/sub-/g' `; do sbatch $H/Scripts/pipeline2.0_DBIS/ciftify_submit.sh $id; done
# for id in `awk -F, '{print $1}' $H/Scripts/pipeline2.0_DBIS/config/cifti_check.txt`; do sh $H/Scripts/pipeline2.0_DBIS/ciftify_check.sh $id; done

###############################################################################################

SUBJ=$1 #SUBJ should be in the same format as the subject directory in derivatives/freesurfer_v6.0 (e.g. sub-0205 for DBIS)
subnum=$(echo $SUBJ | sed 's/sub-//g' ) #need subject number for epi_minProc
imagingDir=/cifs/hariri-long/Studies/DBIS/Imaging
gfcDir=$imagingDir/derivatives/ciftify_GFC/$SUBJ
ciftify_scriptsDir=/cifs/hariri-long/Scripts/Tools/python/ciftify/ciftify/bin
# subject_list=`cd ${CIFTIFY_WORKDIR}; ls -1d sub*`
output_str=$SUBJ
out_sum=0
final_sum=0
AFNI_NIFTI_TYPE_WARN=NO
outfile=$imagingDir/derivatives/ciftify_GFC/check_all_9-5.txt

###1) ciftify_recon_all (r)
if [[ -e $CIFTIFY_WORKDIR/$SUBJ ]]; then r1=1; else r1=0; fi #cifti dir
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Native/MSMSulc/R.transformed_and_reprojected.func.gii ]]; then r2=1; else r2=0; fi #MSM
if [[ -e $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ ]]; then r3=1; else r3=0; fi
	# r3=1
	# r4=0
	# if [[ $( -A $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ | wc -l) -eq 16 ]]; then
		# r3=1
		# r4=1
	# fi
# else 
	# r3=0
	# r4=0 
# fi #qc recon all
output_str="$output_str $r1 $r2 $r3"
out_sum=$(($out_sum + $r1 +$r2 +$r3))
final_sum=$(($final_sum + $r3))

###2) epi (e)
epi_sum=0
for task in facename faces mid stroop rest; do
	if [[ -z "$(ls -A $imagingDir/sourcedata/$SUBJ/func/${SUBJ}_task-${task}*nii.gz)" ]]; then e1=0; echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task no source data !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"; else e1=1; fi
	e2=1
	if [[ ! -e $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz ]]; then 
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task excluded (threshold) !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		e2=-1
	elif [[ ! -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]]; then
		# echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task cifti missing !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		e2=0
	elif [[ ! $(3dinfo -nv $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz) ]]; then 
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task cifti incomplete !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		e2=0
	fi
	# fi	
	# if [[ -e $imagingDir/sourcedata/$SUBJ/func/${SUBJ}_task-${task}_bold.nii.gz ]]; then e1=1; else e1=0; fi
	# if [[ $task==rest ]]; then
		# if [[ -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]] && [[ $(3dinfo -nv $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz) ]]; then e2=1; else e2=0; fi
	# elif [[ -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]] && [[ $(3dinfo -nv $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped_blur6mm.nii.gz) ]]; then e2=1; else e2=0; fi
	output_str="$output_str $e1 $e2"
	out_sum=$(($out_sum + $e1 + $e2))
done

###3) mondoRest (g)
if [[ -e $gfcDir ]]; then g1=1; else g1=0; fi
if [[ -e $gfcDir/epiPrepped.nii.gz ]]; then g2=1; else g2=0; fi
output_str="$output_str $g1 $g2"
out_sum=$(($out_sum + $g1 +$g2))

###4) ciftify_fmri (f)
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC ]]; then f1=1; else f1=0; fi
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii ]]; then f2=1; else f2=0; fi
if [[ -e $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_GFC ]]; then f3=1; else f3=0; fi #qc dir
# if [[ -e $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_GFC ]] && [[ $(ls -A $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_GFC | wc -l) -eq 10 ]]; then echo "complete qc fmri"; fi #then f4=1; else f4=0; fi #qc recon all
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0_Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR_meants.csv ]]; then f5=1; else f5=0; fi
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0_RSN-networks.32k_fs_LR_meants.csv ]]; then f6=1; else f6=0; fi
if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0_Gordon333_FreesurferSubcortical.32k_fs_LR_meants.csv ]]; then f7=1; else f7=0; fi
output_str="$output_str $f1 $f2 $f3 $f5 $f6 $f7"
out_sum=$(($out_sum + $f1 + $f2 + $f3 + $f5 + $f6 + $f7))
final_sum=$(($final_sum + $f1 + $f2 + $f3 + $f5 + $f6 + $f7))

if [[ $out_sum -eq 21 ]]; then 
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ciftify GFC complete for $SUBJ (21)"
	echo "moving extra GFC files to cifti directory"
	for f in $gfcDir/*; do
		if [[ $f == "/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify_GFC/$SUBJ/epiPrepped.nii.gz" ]]; then 
			rm $f
		elif [[ $f == "/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify_GFC/$SUBJ/tmp" ]]; then 
			rm -Rf $f
		else
			mv $f $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC
		fi
	done
	rm -Rf $gfcDir
	echo "removing ciftify epiMinProc and GFC subdirectories"
	for task in facename faces mid stroop rest; do
		rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
	done
	echo "removing cifti GFC.nii"
	rm $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC.nii.gz #this file is 3GB and doesn't seem like we need it unless trying to do some fancy workbench stuff
elif [[ $final_sum -eq 7 ]]; then
	for f in $gfcDir/*; do
		if [[ $f == "/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify_GFC/$SUBJ/epiPrepped.nii.gz" ]]; then 
			rm $f
		elif [[ $f == "/cifs/hariri-long/Studies/DBIS/Imaging/derivatives/ciftify_GFC/$SUBJ/tmp" ]]; then 
			rm -Rf $f
		else
			mv $f $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC
		fi
	done
	rm -Rf $gfcDir
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!$SUBJ complete, removed GFC dir"
else
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ciftify check fail !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo $output_str >> $outfile
	echo $output_str
fi
# if [[ ! $final_sum -eq 7 ]]; then echo $output_str; fi