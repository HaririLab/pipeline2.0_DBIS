#!/bin/bash
#
# for each subject, creates a cifti space directory, projects minimally preprocessed task/rest fmri scans to that subject's cifti directory (including gfc), extracts mean time series using Glasser and Yeo parcellations, and generates QC pages
#
# OUTLINE:
# 1) ciftify_recon_all: create ciftify working directory for subject using freesurfer output (~3 hours)
#	note: need to include python for sys.argv to read in arguments properly
# 2) cifti_vis_recon_all: QA for each subject
#	MLS: input/output intensive. use parallel to run faster on cluster? write files to local storage then tar up all qc images before writing to disk
#	chrome $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ/qc.html #view QC summary page
#	wb_view $SUBJ/MNINonLinear/fsaverage_LR32k/${SUBJ}.32k_fs_LR.wb.spec #view 32k surface that will be used for fmri analysis
# 3) epiMinProc: minimally process tasks + rest, warp functional scans to anatomical T1w
# 4) mondoRest: combine task and rest epi to get GFC (rest + pseudo rest)
# 5) ciftify_subject_fmri: map preprocessed fMRI data to subjects' surfaces and resample subcortical (~12 min)
# 6) cifti_vis_fmri: QA for fmri data
#	chrome $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_${task_label}/qc.html
#	wb_view; first load the subject's fsaverage 32k wb.spec, then load $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/$task_label/${task_label}_Atlas_s0.dtseries.nii #cifti output
#	note: you may also load a parcellation that is in 32k cifti space (e.g. Glasser parcellation). In montage, set the top layer to the parcellation and the middle layer to the task dtseries (bottom should be subject sulc 32k dscalar but it doesn't seem to matter). 
#	click on the wrench next to the parcellation layer and select "Outline Color" or "Outline Label Color" to turn the parcellation into an outline-only overlay instead of fill
# 7) ciftify_meants: extract mean time series for subject task (Glasser parcellation) and resting state network (Yeo parcellation)
#	note: add --outputlabels /path/ to print out a text file with the indices, names, and colors of the ROIs in the atlas dlabel
# 8) extract mean time series for resting state network (Yeo parcellation)
# *9) run QC index for recon and fmri after generating QA for all subjects to get summary page (e.g. python $ciftify_scriptsDir/cifti_vis_recon_all.py index)

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
# for id in `awk -F, '{print $1}' ../ciftify_GFC/cifti_subject_list.txt`; do sbatch $H/Scripts/pipeline2.0_DBIS/ciftify_submit.sh $id; done


# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/ciftify.%j.out 
#SBATCH --error=/dscrhome/%u/ciftify.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=24000 # max is 64G on common partition, 64-240G on common-large
# SBATCH -c 1
#SBATCH -p scavenger
#SBATCH -x dcc-econ-01
# -- END GLOBAL DIRECTIVE -

###############################################################################################

SUBJ=$1 #SUBJ should be in the same format as the subject directory in derivatives/freesurfer_v6.0 (e.g. sub-0205 for DBIS)
subnum=$(echo $SUBJ | sed 's/sub-//g' ) #need subject number for epi_minProc
imagingDir=$H/Studies/DBIS/Imaging
gfcDir=$imagingDir/derivatives/ciftify_GFC/$SUBJ
ciftify_scriptsDir=/cifs/hariri-long/Scripts/Tools/python/ciftify/ciftify/bin
redo_GFC=0
all_epi=1
outfile=$imagingDir/derivatives/ciftify_GFC/check_submit_9-5.txt
# subject_list=`cd ${CIFTIFY_WORKDIR}; ls -1d sub*`

# ###0) for failed subjects start from scratch (may have interuppted while writing to file)
# if [[ ! -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii ]]; then
	# echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ no GFC dtseries - cleaning slate !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	# rm -Rf $CIFTIFY_WORKDIR/$SUBJ
	# rm -Rf $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ
	# for task in faces facename mid stroop rest; do
		# rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
	# done
	# rm -Rf $gfcDir
	# rm -Rf $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_GFC
	# echo "$SUBJ starting over" >> $outfile
# fi

###1) ciftify_recon_all: create ciftify working directory for subject using freesurfer output (~3 hours)
echo "################################# checking for ciftify subj dir $SUBJ #################################"
if [[ ! -e $CIFTIFY_WORKDIR/$SUBJ ]]; then 
	echo "################################# running recon_all $SUBJ #################################"
	python $ciftify_scriptsDir/ciftify_recon_all.py --no-symlinks $SUBJ
	echo "################################# running cifti recon qc #################################"
	python $ciftify_scriptsDir/cifti_vis_recon_all.py subject $SUBJ
	#note: need to include python for sys.argv to read in arguments properly
elif [[ ! -e $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ ]]; then 
	python $ciftify_scriptsDir/cifti_vis_recon_all.py subject $SUBJ
fi
if [[ ! -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Native/MSMSulc/R.transformed_and_reprojected.func.gii ]] || [[ ! $(ls -l $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/fsaverage_LR32k | wc -l) -eq 28 ]]; then 
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! recon_all incomplete for $SUBJ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	if [[ -e $CIFTIFY_WORKDIR/$SUBJ ]]; then 
		echo "################################### deleting incomplete CIFTIFY DIR $SUBJ #################################"
		rm -Rf $CIFTIFY_WORKDIR/$SUBJ
		rm -Rf $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ
	fi
	echo "################################# running recon_all $SUBJ #################################"
	python $ciftify_scriptsDir/ciftify_recon_all.py --no-symlinks $SUBJ
	echo "################################# running cifti recon qc #################################"
	python $ciftify_scriptsDir/cifti_vis_recon_all.py subject $SUBJ
	#note: need to include python for sys.argv to read in arguments properly
fi

# ###2) ciftify_vis_recon_all: QA for each subject
# #MLS: input/output intensive. use parallel to run faster on cluster? write files to local storage then tar up all qc images before writing to disk
# python $ciftify_scriptsDir/cifti_vis_recon_all.py subject $SUBJ
# #chrome $CIFTIFY_WORKDIR/qc_recon_all/$SUBJ/qc.html #view QC summary page
# #wb_view $SUBJ/MNINonLinear/fsaverage_LR32k/${SUBJ}.32k_fs_LR.wb.spec #view 32k surface that will be used for fmri analysis



###5-8) check for different parts of GFC cifti fMRI and run steps as necessary (moved steps 3 & 4 in here bc now these output files get deleted upon completion)
if [[ ! -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0_Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR_meants.csv ]]; then
	###3) output: epi2highres.nii.gz
	for task in faces facename mid stroop rest; do
		if [[ ! -e $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz ]]; then 
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task excluded (threshold) !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			echo "$SUBJ $task excluded" >> $outfile
			all_epi=0
			rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
		elif [[ ! $(3dinfo -nv $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped_blur6mm.nii.gz) ]]; then 
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task epi wrong number TRs !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
		fi
		if [[ ! -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]]; then
			echo "################################# running epi $task $SUBJ #################################"
			sh $H/Scripts/pipeline2.0_DBIS/epi_minProc_DBIS_ciftify.sh $subnum $task
			redo_GFC=1
			if [[ ! -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]]; then
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task cifti failed !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				echo "$SUBJ $task cifti failed" >> $outfile;
				all_epi=0
			fi
		fi	
	done
		# if [[ $task==rest ]]; then
			# if [[ -e $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz ]] && [[ ! $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped.nii.gz) ]]; then 
				# echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task epi incomplete !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				# rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
		# elif [[ ! $(3dinfo -nv $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz) -eq $(3dinfo -nv $imagingDir/derivatives/epiMinProc_${task}/$SUBJ/epiWarped_blur6mm.nii.gz) ]]; then 
			# echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ $task epi incomplete !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			# rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ
		# fi
		# if [[ ! -e $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ/epi2highres.nii.gz ]]; then
			# echo "################################# running epi $task $SUBJ #################################"
			# sh $H/Scripts/pipeline2.0_DBIS/epi_minProc_DBIS_ciftify.sh $subnum $task
		# fi
	# done


	###4) output: epiPrepped.nii.gz (need above output of all tasks first)
	if [[ $all_epi -eq 0 ]]; then
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ not all tasks !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "$SUBJ incomplete tasks" >> $outfile
		# for task in faces facename mid stroop rest; do rm -Rf $imagingDir/derivatives/ciftify_epiMinProc_${task}/$SUBJ; done
		exit
	elif [[ ! -e $gfcDir/epiPrepped.nii.gz ]] || [[ $redo_GFC -eq 1 ]]; then
		echo "################################# no gfc epiprepped or redo #################################"
		rm -Rf $gfcDir
		sh $H/Scripts/pipeline2.0_DBIS/mondoRest_DBIS_ciftify.sh $subnum
		# if [[ -e $imagingDir/derivatives/GFC/$SUBJ/epiPrepped_blur6mm.nii.gz ]]; then
			# echo "################################# running mondoRest $SUBJ #################################"
			# sh $H/Scripts/pipeline2.0_DBIS/mondoRest_DBIS_ciftify.sh $subnum
		# else
			# echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! $SUBJ excluded from GFC (threshold) !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			# echo "$SUBJ GFC failed" >> $outfile
			# exit
		# fi
	fi

	if [[ ! -e $gfcDir/epiPrepped.nii.gz ]]; then echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! mondo rest failed !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"; echo "$SUBJ GFC failed" >> $outfile; exit; fi
	
	#5-8
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! no parcellation !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	if [[ ! -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii ]]; then
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! no dtseries !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		if [[ -e $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC ]]; then rm -Rf $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC; fi
		echo "################################# running cifti fmri #################################"
		python $ciftify_scriptsDir/ciftify_subject_fmri.py $gfcDir/epiPrepped.nii.gz $SUBJ GFC
		echo "################################# running cifti fmri qc #################################"
		python $ciftify_scriptsDir/cifti_vis_fmri.py subject GFC $SUBJ
	fi
	echo "################################# running Glasser parcellation #################################"
	python $ciftify_scriptsDir/ciftify_meants.py $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii $H/Scripts/Tools/python/ciftify/ciftify/data/HCP_S1200_GroupAvg_v1/Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR.dlabel.nii
	echo "################################# running Yeo parcellation #################################"
	python $ciftify_scriptsDir/ciftify_meants.py $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii $H/Scripts/Tools/python/ciftify/ciftify/data/HCP_S1200_GroupAvg_v1/RSN-networks.32k_fs_LR.dlabel.nii
	echo "################################# running Gordon parcellation #################################"
	python $ciftify_scriptsDir/ciftify_meants.py $CIFTIFY_WORKDIR/$SUBJ/MNINonLinear/Results/GFC/GFC_Atlas_s0.dtseries.nii $H/Scripts/Tools/python/ciftify/ciftify/data/null_WG33/Gordon333_FreesurferSubcortical.32k_fs_LR.dlabel.nii
fi
if [[ ! -e $CIFTIFY_WORKDIR/qc_fmri/${SUBJ}_GFC ]]; then 
	echo "################################# running cifti fmri qc #################################"
	python $ciftify_scriptsDir/cifti_vis_recon_all.py subject GFC $SUBJ
fi
echo "checking output and deleting extra files"
sh $H/Scripts/pipeline2.0_DBIS/ciftify_check.sh $SUBJ

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/ciftify.$SLURM_JOB_ID.out $CIFTIFY_WORKDIR/$SUBJ/ciftify.$SLURM_JOB_ID.out 
# -- END POST-USER -- 