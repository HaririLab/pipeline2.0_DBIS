#!/bin/bash
# run with qsub run_firstlevel_AFNI.bash SUBJ

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=12G 
# -- END GLOBAL DIRECTIVE -- 

BASEDIR=$(findexp DBIS.01)
OUTDIR=$BASEDIR/Analysis/All_Imaging/
BehavioralFile=$BASEDIR/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/Behavioral_Faces.csv
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI_splitRuns
MasterFile=$BASEDIR/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/fMRI_ROImeans_faces_$runname.csv

SUBJ=$1
echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $SUBJ START [`date`] on HOST [$HOSTNAME]----"

###### Read behavioral data ######
SUBJ_NUM=$(echo $SUBJ | cut -c6-)
if [ -e $BASEDIR/Data/Behavioral/Matching/Matching-$SUBJ_NUM.txt ]; then
	perl $BASEDIR/Scripts/Behavioral/getFacesEprime.pl $BASEDIR/Data/Behavioral/Matching/Matching-$SUBJ_NUM.txt $OUTDIR/$SUBJ/faces
else
	if [ -e $BASEDIR/Data/Behavioral/Matching/Matching-${SUBJ_NUM:1:3}.txt ]; then
		perl $BASEDIR/Scripts/Behavioral/getFacesEprime.pl $BASEDIR/Data/Behavioral/Matching/Matching-${SUBJ_NUM:1:3}.txt $OUTDIR/$SUBJ/faces
	else
		echo "***Can't locate Matching eprime txt file ($BASEDIR/Data/Behavioral/Matching/Matching-$SUBJ_NUM.txt or $BASEDIR/Data/Behavioral/Matching/Matching-${SUBJ_NUM:1:3}.txt). Faces will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file, using a lock dir system to make sure only one process is doing this at a time
lockDir=$BASEDIR/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/locks
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
	if mkdir $lockDir/faces_behav; then
		sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
		# first check for old values in master files and delete if found
		lineNum=$(grep -n $SUBJ $BehavioralFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -i "${lineNum}d" $BehavioralFile; fi
		vals=`awk '{print $2}' $OUTDIR/$SUBJ/faces/ResponseData.txt`
		acc=$(grep FacesAccuracy $OUTDIR/$SUBJ/faces/ResponseData.txt | awk '{print $2}')
		if [[ $(echo "$acc < .5" | bc ) -eq 1 ]]; then ok=-1; else ok=1; fi
		echo .,$vals,$ok | sed 's/ /,/g' >> $BehavioralFile
		rm -r $lockDir/faces_behav
		break
	else
		sleep 2
	fi
done

# Get faces order 
if [[ $SUBJ == DMHDS0339 ]]; then # this sub's eprime file was accidentally overwritten with one having the wrong order 
	FACESORDER=1; 
else	
	FACESORDER=$(grep Order $OUTDIR/$SUBJ/faces/ResponseData.txt | cut -d" " -f2)
fi
echo "***Faces order is $FACESORDER***"
			
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
maskfile=${BASEDIR}/Analysis/Templates/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz

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

# extract ROI means to master file, using a lock dir system to make sure only one processes does this at a time 
lockDir=$BASEDIR/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/locks
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
	if mkdir $lockDir/faces; then
		sleep 5 # seems like this is necessary to make sure any other processes have fully finished
		# first check for old values in master files and delete if found
		lineNum=$(grep -n $SUBJ $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -i "${lineNum}d" $MasterFile; fi
		rdir=$BASEDIR/Analysis/ROI/Amygdala
		str=$SUBJ
		for con in anger_gr_neutral fear_gr_neutral anger+fear_gr_neutral faces_gr_shapes_avg; do
		    for roi in Tyszka_ALL_L Tyszka_ALL_R Tyszka_BL_L Tyszka_BL_R Tyszka_CM_L Tyszka_CM_R; do 
			vals=$(3dROIstats -nzmean -mask $rdir/$roi.nii $con.nii.gz | grep Faces | awk '{print $3}'); 
			str=$str,$(echo $vals | sed 's/ /,/g')
		    done; 
		done
		echo $str >> $MasterFile; 
		rm -r $lockDir/faces
		break
	else
		sleep 2
	fi
done

sh $BASEDIR/Scripts/pipeline2.0_DBIS/scripts/getConditionsCensored.bash $SUBJ faces

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$SUBJ/faces/$runname/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 
