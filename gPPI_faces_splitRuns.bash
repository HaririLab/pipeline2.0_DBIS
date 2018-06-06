# Following instructions here: https://afni.nimh.nih.gov/CD-CorrAna

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.$TASK_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.$TASK_ID.out
# -- END GLOBAL DIRECTIVE -- 

BASEDIR=$(findexp DBIS.01)

index=${SGE_TASK_ID}
ID=$1 #`head -$index $BASEDIR/Analysis/All_Imaging/DNSids_faces1263.txt | tail -1` # $1

ROI=$BASEDIR/Analysis/SPM/ROI/NEW_PIPELINE/Amygdala/Tyszka_L_BL.nii # $2
OUTNAME=Tyszka_L_BL_splitRuns #$3
PROCDIR=$BASEDIR/Analysis/All_Imaging/$ID/faces/
OUTDIR=$TMPDIR
OUTDIRFINAL=$BASEDIR/Analysis/All_Imaging/$ID/faces/gPPI/$OUTNAME
FACESORDER=`grep "$ID" $BASEDIR/Analysis/All_Imaging/DataLocations.csv | cut -d, -f12`;
nTRs=43 # total number of TRs that will be used for each block (25 for faces + 9 for each adjacent shapes)
blockStarts=(10 54 98 142)
blockEnds=(52 96 140 184)

echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $ID START [`date`] on HOST [$HOSTNAME]----"
echo "***** Faces order is $FACESORDER *****"

mkdir -p $OUTDIRFINAL

# create files for conditions
## (tutorial gives instructions for how to do this with non-TR sync'd)
rm $OUTDIR/Shapes.1D; rm $OUTDIR/Faces.1D;
for i in `seq 1 19`; do echo 1 >> $OUTDIR/Shapes.1D; echo 0 >> $OUTDIR/Faces.1D; done
for i in `seq 1 25`; do echo 0 >> $OUTDIR/Shapes.1D; echo 1 >> $OUTDIR/Faces.1D; done
for i in `seq 1 19`; do echo 1 >> $OUTDIR/Shapes.1D; echo 0 >> $OUTDIR/Faces.1D; done

# create other stim data
waver -dt 2 -GAM -inline 1@1 > $OUTDIR/GammaHR.1D
# create shapes regressor by calculating the convolved regressor for the full block then trimming to adjancent half
# (note that the xmat file has a blank line at the end)
3dDeconvolve -nodata 63 2 -xout -num_stimts 1 -stim_times 1 '1D: 0 88' 'SPMG1(38)' -x1D_stop -x1D $OUTDIR/ShapesRegressor_extended
grep -v "#" $OUTDIR/ShapesRegressor_extended.xmat.1D | awk '{print $3}' | head -53 | tail -43 > $OUTDIR/ShapesRegressor.1D

cd $OUTDIR

# loop through blocks
for i in `seq 0 3`; do

	# extract the average time series of the ROI
	# we will do this for the entire adjacent shapes block, and then trim it to just the closest adjacent half after all convolution is done
	## andy (2013) uses 3dSynthesize to remove drift & motion effects and extract the seed ts from teh resulting cleaned data (doesn't use the cleaned data after that)
	## > however the afni instructions don't mention this and just suggest using the preprocessed ts from afni_proc, then uses 3dDetrend (which Andy skips)
	3dmaskave -mask $ROI -quiet $PROCDIR/epiWarped_blur6mm.nii.gz"[$((${blockStarts[$i]}-10))..$((${blockEnds[$i]}+10))]" > $OUTDIR/Seed_block$((i+1)).1D
	# detrend seed time series and transpose to column
	# Use \' to transpose Seed.1D
	3dDetrend -polort 1 -prefix $OUTDIR/SeedR_block$((i+1)) $OUTDIR/Seed_block$((i+1)).1D\'; 1dtranspose $OUTDIR/SeedR_block$((i+1)).1D $OUTDIR/Seed_ts_block$((i+1)).1D; rm $OUTDIR/SeedR_block$((i+1)).1D

	## Run 1dUpsample here for non-TR synchronized onsets?
	# generate impulse response function
	## change dt if non-TR sync'd
	# deconvolve seed time series
	# -FALTUNG fset fpre pen fac
	3dTfitter -RHS $OUTDIR/Seed_ts_block$((i+1)).1D -FALTUNG $OUTDIR/GammaHR.1D $OUTDIR/Seed_Neur_block$((i+1)) 012 0
	  
	for cond in Shapes Faces; do 
		
		# create the interaction regressors, starting with the interaction at the neuronal level, then reconvolving using waver
		### see instructions for additional steps if not sync'ed to TR grids
		1deval -a $OUTDIR/Seed_Neur_block$((i+1)).1D\' -b $OUTDIR/${cond}.1D -expr 'a*b' > $OUTDIR/Interaction_Neur${cond}_block$((i+1)).1D
		waver -GAM -peak 1 -TR 2 -input $OUTDIR/Interaction_Neur${cond}_block$((i+1)).1D -numout $((nTRs+20)) > $OUTDIR/Interaction_${cond}_block$((i+1)).1D
	
		# now trim the regressors to only include the adjacent half of the shapes blocks
		head -53 $OUTDIR/Interaction_${cond}_block$((i+1)).1D | tail -43 > $OUTDIR/Interaction_${cond}_trimmed_block$((i+1)).1D
		
		### ARK: scale Interaction regressor to have a peak of 1!  Testing this out to see if it changes results
		# there is at least one case (DNS1388/Tyszka_R_ALL Anger) where all values in Interaction_${cond}.1D are negative; in this case, scale to a min of -1 instead of a max of 1
		max=$(awk -v max=-999 '{if($1>max){max=$1}}END{print max}' $OUTDIR/Interaction_${cond}_trimmed_block$((i+1)).1D )
		if [[ $max -eq 0 ]]; then
			min=$(awk -v min=999 '{if($1<min){min=$1}}END{print min}' $OUTDIR/Interaction_${cond}_trimmed_block$((i+1)).1D )
			1deval -a $OUTDIR/Interaction_${cond}_trimmed_block$((i+1)).1D -expr "-a/$min" > $OUTDIR/Interaction_${cond}_trimmed_scaled_block$((i+1)).1D
		else
			1deval -a $OUTDIR/Interaction_${cond}_trimmed_block$((i+1)).1D -expr "a/$max" > $OUTDIR/Interaction_${cond}_trimmed_scaled_block$((i+1)).1D
		fi
		
	done
	
	# create the linear model
	maskfile=$BASEDIR/Analysis/Max/templates/DNS500/DNS500template_MNI_BrainExtractionMask_2mm.nii.gz
	# arguments to stim_times are in seconds!
	# glt arg should always be 1
	# using polort 3 here per recommendation in afni_proc.py help documentation
	## wasn't sure if censor should be any different/included here, but seems fine since they do here and gang doesn't call them out on it https://afni.nimh.nih.gov/afni/community/board/read.php?1,155395,155395#msg-155395

	outname=glm_output_$((i+1))
	3dDeconvolve -input $PROCDIR/epiWarped_blur6mm.nii.gz"[${blockStarts[$i]}..${blockEnds[$i]}]" -xout -mask $maskfile -num_stimts 4 \
	  -stim_file 1 ShapesRegressor.1D -stim_label 1 ShapesPair \
	  -stim_times 2 '1D: 18' 'SPMG1(50)' -stim_label 2 Faces1 \
	  -stim_file 3 Interaction_Shapes_trimmed_scaled_block$((i+1)).1D -stim_label 3 Interaction_Shapes_scaled_block$((i+1)) \
	  -stim_file 4 Interaction_Faces_trimmed_scaled_block$((i+1)).1D -stim_label 4 Interaction_Faces_scaled_block$((i+1)) \
	  -censor $PROCDIR/glm_AFNI_splitRuns_noShapes/outliers_block$((i+1)).1D \
	  -x1D Decon_$((i+1)) -x1D_stop
	3dREMLfit -input $PROCDIR/epiWarped_blur6mm.nii.gz"[${blockStarts[$i]}..${blockEnds[$i]}]" -matrix Decon_$((i+1)).xmat.1D -mask $maskfile \
	  -Rbuck ${outname}.nii.gz \
	  -noFDR -tout
	#3dTcat -prefix ${outname}_coefs.nii.gz ${outname}.nii.gz'[5]' ${outname}.nii.gz'[7]'
	#rm ${outname}.nii.gz

done # loop through blocks
  
# now relabel the files according to expression
case $FACESORDER in
	1) fear=1; neut=2; ange=3; surp=4; ;; # FNAS
	2) fear=2; neut=1; ange=4; surp=3; ;; # NFSA
	3) fear=3; neut=4; ange=1; surp=2; ;; # ASFN
	4) fear=4; neut=3; ange=2; surp=1; ;; # SANF
	*)  echo "Invalid faces order $FACESORDER!!! Exiting."
		exit; ;;
esac	

3dcalc -prefix fear_gr_shapes.nii.gz -a glm_output_${fear}.nii.gz'[5]' -b glm_output_${fear}.nii.gz'[7]' -expr '(b-a)' 
3dcalc -prefix neutral_gr_shapes.nii.gz -a glm_output_${neut}.nii.gz'[5]' -b glm_output_${neut}.nii.gz'[7]' -expr '(b-a)' 
3dcalc -prefix anger_gr_shapes.nii.gz -a glm_output_${ange}.nii.gz'[5]' -b glm_output_${ange}.nii.gz'[7]' -expr '(b-a)' 
3dcalc -prefix surprise_gr_shapes.nii.gz -a glm_output_${surp}.nii.gz'[5]' -b glm_output_${surp}.nii.gz'[7]' -expr '(b-a)' 
3dcalc -prefix faces_gr_shapes_avg.nii.gz -a  fear_gr_shapes.nii.gz -b neutral_gr_shapes.nii.gz -c anger_gr_shapes.nii.gz -d surprise_gr_shapes.nii.gz -expr '(a+b+c+d)/4'
3dcalc -prefix anger_gr_neutral.nii.gz -a glm_output_${ange}.nii.gz'[7]' -b glm_output_${neut}.nii.gz'[7]' -expr '(a-b)' 
3dcalc -prefix fear_gr_neutral.nii.gz -a glm_output_${fear}.nii.gz'[7]' -b glm_output_${neut}.nii.gz'[7]' -expr '(a-b)' 
3dcalc -prefix anger+fear_gr_neutral.nii.gz -a glm_output_${ange}.nii.gz'[7]' -b glm_output_${fear}.nii.gz'[7]' -c glm_output_${neut}.nii.gz'[7]' -expr '((a+b)/2-c)' 
3dcalc -prefix habit_1g2g3g4.nii.gz -a glm_output_1.nii.gz'[7]' -b glm_output_2.nii.gz'[7]' -c glm_output_3.nii.gz'[7]' -d glm_output_4.nii.gz'[7]' -expr '(0.75*a+0.25*b-0.25*c-0.75*d)'
  
rm glm_output*.nii.gz
rm Interaction*1D 
rm Seed*1D 
gunzip *nii.gz

cp -r $OUTDIR/* $OUTDIRFINAL
 
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.${SGE_TASK_ID}.out $OUTDIRFINAL/$JOB_NAME.$JOB_ID.${SGE_TASK_ID}.out	 
# -- END POST-USER --   
  
