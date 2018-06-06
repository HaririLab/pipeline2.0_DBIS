# Following instructions here: https://afni.nimh.nih.gov/CD-CorrAna


# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
# -- END GLOBAL DIRECTIVE -- 

BASEDIR=$(findexp DBIS.01)

index=${SGE_TASK_ID}
ID=$1 #`head -$index $BASEDIR/Analysis/All_Imaging/DNSids_faces1263.txt | tail -1` # $1

ROI=$BASEDIR/Analysis/ROI/Amygdala/Tyszka_ALL_L.nii # $2
OUTNAME=Tyszka_L_ALL #$3
PROCDIR=$BASEDIR/Analysis/All_Imaging/$ID/faces/
OUTDIR=$BASEDIR/Analysis/All_Imaging/$ID/faces/gPPI/$OUTNAME
FACESORDER=`grep Order $PROCDIR/ResponseData.txt | awk '{print $2}'`;
 
nTRs=200

echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $ID START [`date`] on HOST [$HOSTNAME]----"
echo "***** Faces order is $FACESORDER *****"

mkdir -p $OUTDIR/contrasts


# create FD and DVARS outlier file to use for censoring
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
for i in `seq 200`; do 
	FD=`head -$i $PROCDIR/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $PROCDIR/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/outliers.1D; 

# extract the average time series of the ROI
## andy (2013) uses 3dSynthesize to remove drift & motion effects and extract the seed ts from teh resulting cleaned data (doesn't use the cleaned data after that)
## > however the afni instructions don't mention this and just suggest using the preprocessed ts from afni_proc, then uses 3dDetrend (which Andy skips)
3dmaskave -mask $ROI -quiet $PROCDIR/epiWarped_blur6mm.nii.gz > $OUTDIR/Seed.1D
# Use \' to transpose Seed.1D
 
# detrend seed time series and transpose to column
## I'm not totally sure if 3 is the right polort to use here (doesn't say in the tutorial), but someone said here that they used it and Gang said it was fine: https://afni.nimh.nih.gov/afni/community/board/read.php?1,155395,155395#msg-155395
3dDetrend -polort 3 -prefix $OUTDIR/SeedR $OUTDIR/Seed.1D\'
1dtranspose $OUTDIR/SeedR.1D $OUTDIR/Seed_ts.1D
rm $OUTDIR/SeedR.1D

## Run 1dUpsample here for non-TR synchronized onsets?

# generate impulse response function
## change dt if non-TR sync'd
waver -dt 2 -GAM -inline 1@1 > $OUTDIR/GammaHR.1D
# deconvolve seed time series
# -FALTUNG fset fpre pen fac
3dTfitter -RHS $OUTDIR/Seed_ts.1D -FALTUNG $OUTDIR/GammaHR.1D $OUTDIR/Seed_Neur 012 0


# create files for conditions
## (tutorial gives instructions for how to do this with non-TR sync'd)
case $FACESORDER in
	1) blocks=(Fear Neutral Anger Surprise); weights=(-0.75 -0.25 0.25 0.75); ;; #FNAS
	2) blocks=(Neutral Fear Surprise Anger); weights=(-0.25 -0.75 0.75 0.25); ;; #NFSA
	3) blocks=(Anger Surprise Fear Neutral); weights=(0.25 0.75 -0.75 -0.25); ;; #ASFN
	4) blocks=(Surprise Anger Neutral Fear); weights=(0.75 0.25 -0.25 -0.75); ;; #SANF
	5) blocks=(Fear Neutral Surprise Anger); weights=(-0.75 -0.25 0.75 0.25); ;; # FNSA
	6) blocks=(Neutral Fear Anger Surprise); weights=(-0.25 -0.75 0.25 0.75); ;; # NFAS
	7) blocks=(Surprise Anger Fear Neutral); weights=(0.75 0.25 -0.75 -0.25); ;; # SAFN
	8) blocks=(Anger Surprise Neutral Fear); weights=(0.25 0.75 -0.25 -0.75); ;; # ASNF
	9) blocks=(Fear Anger Neutral Surprise); weights=(-0.75 0.25 -0.25 0.75); ;; # FANS
	10) blocks=(Anger Fear Surprise Neutral); weights=(0.25 -0.75 0.75 -0.25);  ;; # AFSN
	11) blocks=(Neutral Surprise Fear Anger); weights=(-0.25 0.75 -0.75 0.25);  ;; # NSFA
	12) blocks=(Surprise Neutral Anger Fear); weights=(0.75 -0.25 0.25 -0.75);  ;; # SNAF
	13) blocks=(Fear Anger Surprise Neutral); weights=(-0.75 0.25 0.75 -0.25);  ;; # FASN
	14) blocks=(Anger Fear Neutral Surprise); weights=(0.25 -0.75 -0.25 0.75);  ;; # AFNS
	15) blocks=(Surprise Neutral Fear Anger); weights=(0.75 -0.25 -0.75 0.25);  ;; # SNFA
	16) blocks=(Neutral Surprise Anger Fear); weights=(-0.25 0.75 0.25 -0.75);  ;; # NSAF
	17) blocks=(Fear Surprise Neutral Anger); weights=(-0.75 0.75 -0.25 0.25);  ;; # FSNA
	18) blocks=(Surprise Fear Anger Neutral); weights=(0.75 -0.75 0.25 -0.25);  ;; # SFAN
	19) blocks=(Neutral Anger Fear Surprise); weights=(-0.25 0.25 -0.75 0.75);  ;; # NAFS
	20) blocks=(Anger Neutral Surprise Fear); weights=(0.25 -0.25 0.75 -0.75);  ;; # ANSF
	21) blocks=(Fear Surprise Anger Neutral); weights=(-0.75 0.75 0.25 -0.25);  ;; # FSAN
	22) blocks=(Surprise Fear Neutral Anger); weights=(0.75 -0.75 -0.25 0.25);  ;; # SFNA
	23) blocks=(Anger Neutral Fear Surprise); weights=(0.25 -0.25 -0.75 0.75);  ;; # ANFS
	24) blocks=(Neutral Anger Surprise Fear); weights=(-0.25 0.25 0.75 -0.75);  ;; # NASF
	*)  echo "Invalid faces order $FACESORDER!!! Exiting."
		exit; ;;
esac	
for j in `seq 0 23`; do 
	for i in `seq 1 19`; do echo 1 >> $OUTDIR/Shapes.1D; echo 0 >> $OUTDIR/Fear.1D; echo 0 >> $OUTDIR/Neutral.1D; echo 0 >> $OUTDIR/Anger.1D; echo 0 >> $OUTDIR/Surprise.1D; done
	for i in `seq 1 25`; do echo 0 >> $OUTDIR/Shapes.1D; echo 1 >> $OUTDIR/${blocks[$j]}.1D; echo 0 >> $OUTDIR/${blocks[$(((j+1)%4))]}.1D; echo 0 >> $OUTDIR/${blocks[$(((j+2)%4))]}.1D; echo 0 >> $OUTDIR/${blocks[$(((j+3)%4))]}.1D; done
done
# final shapes block
for i in `seq 1 19`; do echo 1 >> $OUTDIR/Shapes.1D; echo 0 >> $OUTDIR/Fear.1D; echo 0 >> $OUTDIR/Neutral.1D; echo 0 >> $OUTDIR/Anger.1D; echo 0 >> $OUTDIR/Surprise.1D; done
  
# create the interaction regressors
### see instructions for additional steps if not sync'ed to TR grids
for cond in Shapes Fear Neutral Anger Surprise; do
	1deval -a $OUTDIR/Seed_Neur.1D\' -b $OUTDIR/${cond}.1D -expr 'a*b' > $OUTDIR/Interaction_Neur${cond}.1D
	waver -GAM -peak 1 -TR 2 -input $OUTDIR/Interaction_Neur${cond}.1D -numout $nTRs > $OUTDIR/Interaction_${cond}.1D
	### ARK: scale Interaction regressor to have a peak of 1! 
	# there is at least one case (DNS1388/Tyszka_R_ALL Anger) where all values in Interaction_${cond}.1D are negative; in this case, scale to a min of -1 instead of a max of 1
	max=$(awk -v max=-999 '{if($1>max){max=$1}}END{print max}' $OUTDIR/Interaction_${cond}.1D )
	if [[ $(echo "$max<=0" | bc) ]]; then
		min=$(awk -v min=999 '{if($1<min){min=$1}}END{print min}' $OUTDIR/Interaction_${cond}.1D )
		1deval -a $OUTDIR/Interaction_${cond}.1D -expr "-a/$min" > $OUTDIR/Interaction_${cond}_scaled.1D
	else
		1deval -a $OUTDIR/Interaction_${cond}.1D -expr "a/$max" > $OUTDIR/Interaction_${cond}_scaled.1D
	fi
done

# create contrast files
echo "0 0 0 0 0 0 0 0 0 -1 0.25 0.25 0.25 0.25 0" > $OUTDIR/contrasts/gPPI_Faces_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 -1 1 0 0 0 0" > $OUTDIR/contrasts/gPPI_Fear_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 -1 0 1 0 0 0" > $OUTDIR/contrasts/gPPI_Neutral_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 -1 0 0 1 0 0" > $OUTDIR/contrasts/gPPI_Anger_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 -1 0 0 0 1 0" > $OUTDIR/contrasts/gPPI_Surprise_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 0 0 -1 1 0 0" > $OUTDIR/contrasts/gPPI_Anger_gr_Neutral.txt
echo "0 0 0 0 0 0 0 0 0 0 1 -1 0 0 0" > $OUTDIR/contrasts/gPPI_Fear_gr_Neutral.txt
echo "0 0 0 0 0 0 0 0 0 -1 0.5 0 0.5 0 0" > $OUTDIR/contrasts/gPPI_AngerFear_gr_Shapes.txt
echo "0 0 0 0 0 0 0 0 0 0 0.5 -1 0.5 0 0" > $OUTDIR/contrasts/gPPI_AngerFear_gr_Neutral.txt
echo "0 0 0 0 0 0 0 0 0 0 ${weights[0]} ${weights[1]} ${weights[2]} ${weights[3]} 0" > $OUTDIR/contrasts/gPPI_Block4g3g2g1.txt; 

# create the linear model
cd $OUTDIR
maskfile=${BASEDIR}/Analysis/Templates/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
outname=glm_output
# arguments to stim_times are in seconds!
# glt arg should always be 1
# using polort 3 here per recommendation in afni_proc.py help documentation
## wasn't sure if censor should be any different/included here, but seems fine since they do here and gang doesn't call them out on it https://afni.nimh.nih.gov/afni/community/board/read.php?1,155395,155395#msg-155395
3dDeconvolve -input $PROCDIR/epiWarped_blur6mm.nii.gz -xout -polort 3 -mask $maskfile -num_stimts 11 \
  -stim_times 1 '1D: 0 88 176 264 352' 'SPMG1(38)' -stim_label 1 Shapes \
  -stim_times 2 '1D: 38' 'SPMG1(50)' -stim_label 2 Faces1 \
  -stim_times 3 '1D: 126' 'SPMG1(50)' -stim_label 3 Faces2 \
  -stim_times 4 '1D: 214' 'SPMG1(50)' -stim_label 4 Faces3 \
  -stim_times 5 '1D: 302' 'SPMG1(50)' -stim_label 5 Faces4 \
  -stim_file 6 Interaction_Shapes_scaled.1D -stim_label 6 Interaction_Shapes \
  -stim_file 7 Interaction_Fear_scaled.1D -stim_label 7 Interaction_Fear \
  -stim_file 8 Interaction_Neutral_scaled.1D -stim_label 8 Interaction_Neutral \
  -stim_file 9 Interaction_Anger_scaled.1D -stim_label 9 Interaction_Anger \
  -stim_file 10 Interaction_Surprise_scaled.1D -stim_label 10 Interaction_Surprise \
  -stim_file 11 Seed_ts.1D -stim_label 11 Seed_ts \
  -censor $OUTDIR/outliers.1D \
  -glt 1 contrasts/gPPI_Faces_gr_Shapes.txt -glt_label 1 gPPI_Faces_gr_Shapes \
  -glt 1 contrasts/gPPI_Fear_gr_Shapes.txt -glt_label 2 gPPI_Fear_gr_Shapes \
  -glt 1 contrasts/gPPI_Neutral_gr_Shapes.txt -glt_label 3 gPPI_Neutral_gr_Shapes \
  -glt 1 contrasts/gPPI_Anger_gr_Shapes.txt -glt_label 4 gPPI_Anger_gr_Shapes \
  -glt 1 contrasts/gPPI_Surprise_gr_Shapes.txt -glt_label 5 gPPI_Surprise_gr_Shapes \
  -glt 1 contrasts/gPPI_Anger_gr_Neutral.txt -glt_label 6 gPPI_Anger_gr_Neutral \
  -glt 1 contrasts/gPPI_Fear_gr_Neutral.txt -glt_label 7 gPPI_Fear_gr_Neutral \
  -glt 1 contrasts/gPPI_AngerFear_gr_Shapes.txt -glt_label 8 gPPI_AngerFear_gr_Shapes \
  -glt 1 contrasts/gPPI_AngerFear_gr_Neutral.txt -glt_label 9 gPPI_AngerFear_gr_Neutral \
  -glt 1 contrasts/gPPI_Block4g3g2g1.txt -glt_label 10 gPPI_Block4g3g2g1 \
  -x1D_stop

3dREMLfit -input $PROCDIR/epiWarped_blur6mm.nii.gz -matrix Decon.xmat.1D -mask $maskfile \
  -Rbuck ${outname}.nii \
  -noFDR -tout
  
# extract coefs and tstats for workign with in SPM  
# first volume in output bucket (index 0!) is Full_Fstat, then there are 2 volumes for each condition (Coef, Tstat)
# so, the first contrast volume # is 2*(N conditions) + 1
3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[23]' ${outname}.nii'[25]' ${outname}.nii'[27]' ${outname}.nii'[29]' ${outname}.nii'[31]' ${outname}.nii'[33]' ${outname}.nii'[35]' ${outname}.nii'[37]' ${outname}.nii'[39]'  ${outname}.nii'[41]' 
3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[24]' ${outname}.nii'[26]' ${outname}.nii'[28]' ${outname}.nii'[30]' ${outname}.nii'[32]' ${outname}.nii'[34]' ${outname}.nii'[36]' ${outname}.nii'[38]' ${outname}.nii'[40]'  ${outname}.nii'[42]'  

gzip ${outname}_tstats.nii
rm ${outname}.nii
 
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER --   
  
