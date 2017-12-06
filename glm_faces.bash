#!/bin/bash
# run with qsub run_firstlevel_AFNI.bash SUBJ

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
# -- END GLOBAL DIRECTIVE -- 

EXPERIMENT=`biacmount DBIS.01`

# index=${SGE_TASK_ID}
OUTDIR=$EXPERIMENT/Analysis/All_Imaging/
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI_splitRuns

SUBJ=$1
firstDigit=$(echo $SUBJ | cut -c6)
if [ $firstDigit -eq 2 ]; then # this is a retest scan
	EXAMID=$(echo $SUBJ | cut -c6-10)
else
	EXAMID=$(echo $SUBJ | cut -c6-9)
fi

###### Get faces order ######
if [ $SUBJ -eq DMHDS0339 ]; then # this sub's eprime file was accidentally overwritten with one having the wrong order 
	FACESORDER=1; 
else	
	eprimeFile=`ls $EXPERIMENT/Data/Behavioral/Matching/Matching-$EXAMID.txt 2> /dev/null`;
	if [[ $eprimeFile ]]; then
		echo "Reading order number from $eprimeFile"
	else
		echo "***Could not find $EXPERIMENT/Data/Behavioral/Matching/Matching-$EXAMID.txt, trying -${EXAMID:1:3}.txt instead***";
		fileCount=`ls $EXPERIMENT/Data/Behavioral/Matching/Matching-${EXAMID:1:3}.txt 2> /dev/null | wc -l`;
		if [ $fileCount -eq 1 ]; then
			eprimeFile=`ls $EXPERIMENT/Data/Behavioral/Matching/Matching-${EXAMID:1:3}.txt 2> /dev/null`;
			echo "***Found it! $eprimeFile***"
		else
			echo "***Error: could not find eprime file to get faces order, quitting!!! (Check Data/Behavioral/Matching or consider changing input variables to use manual faces order)***"
			exit 32
		fi
	fi
	# order number is stored in ListChoice variable
	FACESORDER=`grep "ListChoice" $eprimeFile | head -n 1 | awk '{print $2}'`
	if [[ $FACESORDER ]]; then
		echo "***Faces order is $FACESORDER***"
	else
		echo "***Attempting to convert $eprimeFile****"
		iconv -f utf-16 -t utf-8 $eprimeFile > $EXPERIMENT/Data/Behavioral/tmp_$SUBJ.txt
		FACESORDER=`grep "ListChoice" $EXPERIMENT/Data/Behavioral/tmp_$SUBJ.txt | head -n 1 | awk '{print $2}'`
		FACESORDER=$(echo $FACESORDER | cut -c1-1) # just take first character, looks like from the above command it extracts 2 chars including some whitespace char
		rm $EXPERIMENT/Data/Behavioral/tmp_$SUBJ.txt
		if [[ $FACESORDER ]]; then
			echo "***Faces order is $FACESORDER***"
		else
			echo "***Error: could not read faces order from $eprimeFile, quitting!!! (consider changing input variables to use manual faces order)***"
			exit 32
		fi
	fi
fi

rm -r $OUTDIR/$SUBJ/faces/$runname
mkdir -p $OUTDIR/$SUBJ/faces/$runname/contrasts

# create FD and DVARS outlier file to use for censoring
for i in `seq 200`; do 
	FD=`head -$i $OUTDIR/$SUBJ/faces/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/$SUBJ/faces/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$SUBJ/faces/$runname/outliers.1D; 

head -53 $OUTDIR/$SUBJ/faces/$runname/outliers.1D | tail -43 > $OUTDIR/$SUBJ/faces/$runname/outliers_block1.1D; 
head -97 $OUTDIR/$SUBJ/faces/$runname/outliers.1D | tail -43 > $OUTDIR/$SUBJ/faces/$runname/outliers_block2.1D; 
head -141 $OUTDIR/$SUBJ/faces/$runname/outliers.1D | tail -43 > $OUTDIR/$SUBJ/faces/$runname/outliers_block3.1D; 
head -185 $OUTDIR/$SUBJ/faces/$runname/outliers.1D | tail -43 > $OUTDIR/$SUBJ/faces/$runname/outliers_block4.1D; 

# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
echo "0 0 -1 1" > $OUTDIR/$SUBJ/faces/$runname/contrasts/faceBlock_gr_shapesBlocks.txt

cd $OUTDIR/$SUBJ/faces/$runname
maskfile=${EXPERIMENT}/Analysis/Max/templates/DBIS115/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz

## Faces block 1 > adjacent shapes blocks
outname=glm_output_1
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[10..52]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces1 \
  -censor outliers_block1.1D \
  -x1D Decon_1 -x1D_stop
3dREMLfit -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[10..52]' -matrix Decon_1.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 2 > adjacent shapes blocks
outname=glm_output_2
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[54..96]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces2 \
  -censor outliers_block2.1D \
  -x1D Decon_2 -x1D_stop
3dREMLfit -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[54..96]' -matrix Decon_2.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 3 > adjacent shapes blocks
outname=glm_output_3
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[98..140]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces3 \
  -censor outliers_block3.1D \
  -x1D Decon_3 -x1D_stop
3dREMLfit -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[98..140]' -matrix Decon_3.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 4 > adjacent shapes blocks
outname=glm_output_4
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[142..184]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces4 \
  -censor outliers_block4.1D \
  -x1D Decon_4 -x1D_stop
3dREMLfit -input $OUTDIR/$SUBJ/faces/epiWarped_blur6mm.nii.gz'[142..184]' -matrix Decon_4.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

3dcalc -prefix habit_1g2g3g4.nii.gz  -a glm_output_1_betas.nii.gz'[2]' -b glm_output_1_betas.nii.gz'[0]' \
	-c glm_output_2_betas.nii.gz'[2]' -d glm_output_2_betas.nii.gz'[0]' \
	-e glm_output_3_betas.nii.gz'[2]' -f glm_output_3_betas.nii.gz'[0]' \
	-g glm_output_4_betas.nii.gz'[2]' -h glm_output_4_betas.nii.gz'[0]' -expr '(0.75*(a+b)+0.25*(c+d)-0.25*(e+f)-0.75*(g+h))'
  
case $FACESORDER in
	1) fear=1; neut=2; ange=3; surp=4; ;; # FNAS
	2) fear=2; neut=1; ange=4; surp=3; ;; # NFSA
	3) fear=3; neut=4; ange=1; surp=2; ;; # ASFN
	4) fear=4; neut=3; ange=2; surp=1; ;; # SANF
	5) fear=1; neut=2; ange=4; surp=3; ;; # FNSA
	6) fear=2; neut=1; ange=3; surp=4; ;; # NFAS
	7) fear=3; neut=4; ange=2; surp=1; ;; # SAFN
	8) fear=4; neut=3; ange=1; surp=2; ;; # ASNF
	9) fear=1; neut=3; ange=2; surp=4; ;; # FANS
	10) fear=2; neut=4; ange=1; surp=3; ;; # AFSN
	11) fear=3; neut=1; ange=4; surp=2; ;; # NSFA
	12) fear=4; neut=2; ange=3; surp=1; ;; # SNAF
	13) fear=1; neut=4; ange=2; surp=3; ;; # FASN
	14) fear=2; neut=3; ange=1; surp=4; ;; # AFNS
	15) fear=3; neut=2; ange=4; surp=1; ;; # SNFA
	16) fear=4; neut=1; ange=3; surp=2; ;; # NSAF
	17) fear=1; neut=3; ange=4; surp=2; ;; # FSNA
	18) fear=2; neut=4; ange=3; surp=1; ;; # SFAN
	19) fear=3; neut=1; ange=2; surp=4; ;; # NAFS
	20) fear=4; neut=2; ange=1; surp=3; ;; # ANSF
	21) fear=1; neut=4; ange=3; surp=2; ;; # FSAN
	22) fear=2; neut=3; ange=4; surp=1; ;; # SFNA
	23) fear=3; neut=2; ange=1; surp=4; ;; # ANFS
	24) fear=4; neut=1; ange=2; surp=3; ;; # NASF
	*)  echo "Invalid faces order $FACESORDER!!! Exiting."
		exit; ;;
esac

mv glm_output_${fear}_betas.nii.gz fear_betas.nii.gz
mv glm_output_${neut}_betas.nii.gz neutral_betas.nii.gz
mv glm_output_${ange}_betas.nii.gz anger_betas.nii.gz
mv glm_output_${surp}_betas.nii.gz surprise_betas.nii.gz

# for each of the *_betas.nii.gz, there are 3 sub-bricks: 0: Run#1Pol#0, 1: Run#1Pol#1, 2: Faces#0
# when we model without a shapes regressor, the "faces" coeficient represents the "faces>shapes" contrast, and the Pol0 coef is the baseline, or "shape" beta
# so, the faces BETA is obtained by adding the Pol0 coef to the faces coef
3dcalc -prefix anger_gr_neutral.nii.gz -a anger_betas.nii.gz'[2]' -b anger_betas.nii.gz'[0]' -c neutral_betas.nii.gz'[2]' -d neutral_betas.nii.gz'[0]' -expr '(a+b-(c+d))' 
3dcalc -prefix fear_gr_neutral.nii.gz -a fear_betas.nii.gz'[2]' -b fear_betas.nii.gz'[0]' -c neutral_betas.nii.gz'[2]' -d neutral_betas.nii.gz'[0]' -expr '(a+b-(c+d))' 
3dcalc -prefix anger+fear_gr_neutral.nii.gz  -a anger_betas.nii.gz'[2]' -b anger_betas.nii.gz'[0]' -c fear_betas.nii.gz'[2]' -d fear_betas.nii.gz'[0]' -e neutral_betas.nii.gz'[2]' -f neutral_betas.nii.gz'[0]' -expr '((a+b+c+d)/2-(e+f))' 
3dcalc -prefix faces_gr_shapes_avg.nii.gz  -a anger_betas.nii.gz'[2]' -b fear_betas.nii.gz'[2]' -c neutral_betas.nii.gz'[2]' -d surprise_betas.nii.gz'[2]' -expr '((a+b+c+d)/4)' 

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$SUBJ/faces/$runname/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 