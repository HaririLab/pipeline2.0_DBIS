#!/bin/bash
# run with sbatch run_firstlevel_AFNI.bash SUBJ

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/glm_faces.%j.out 
#SBATCH --error=/dscrhome/%u/glm_faces.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
#SBATCH -p scavenger
# -- END GLOBAL DIRECTIVE -- 
SUBJ_NUM=$1 # use just 4 digit number! E.g 0234 for DMHDS0234
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI_splitRuns

TOPDIR=/cifs/hariri-long
OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/epiMinProc_faces/sub-${SUBJ_NUM}
behavDir=$TOPDIR/Studies/DBIS/Imaging/ResponseData
behavScript=$TOPDIR/Scripts/pipeline2.0_DBIS/behavioral/getFacesEprime.pl
BehavioralFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/Behavioral_faces.csv
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_ROImeans_faces_${runname}.csv
maskfile=$TOPDIR/Templates/DBIS/WholeBrain/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
rdir=$TOPDIR/Templates/DBIS/Amygdala

echo "----JOB [$SLURM_JOB_ID] SUBJ $SUBJ_NUM START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"

###### Read behavioral data ######
if [ -e $behavDir/Matching/Matching-${SUBJ_NUM}.txt ]; then
	perl $behavScript $behavDir/Matching/Matching-${SUBJ_NUM}.txt $OUTDIR
else
	if [ -e $behavDir/Matching/Matching-${SUBJ_NUM:1:3}.txt ]; then
		perl $behavScript $behavDir/Matching/Matching-${SUBJ_NUM:1:3}.txt $OUTDIR
	else
		echo "***Can't locate Matching eprime txt file ($behavDir/Matching/Matching-${SUBJ_NUM}.txt or $behavDir/Matching/Matching-${SUBJ_NUM:1:3}.txt). Faces will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file, using a lock dir system to make sure only one process is doing this at a time
if [[ -e $OUTDIR/ResponseData.txt ]]; then 
	if [ ! -e $lockDir ]; then mkdir $lockDir; fi
	while true; do
		if mkdir $lockDir/faces_behav; then
			sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
			# first check for old values in master files and delete if found
			lineNum=$(grep -n DMHDS$SUBJ_NUM $BehavioralFile | cut -d: -f1)
			if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $BehavioralFile; fi
			vals=`awk '{print $2}' $OUTDIR/ResponseData.txt`
			acc=$(grep FacesAccuracy $OUTDIR/ResponseData.txt | awk '{print $2}')
			if [[ $(echo "$acc < .5" | bc ) -eq 1 ]]; then ok=0; else ok=1; fi
			echo .,$vals,$ok | sed 's/ /,/g' >> $BehavioralFile
			rm -r $lockDir/faces_behav
			break
		else
			sleep 2
		fi
	done
else
	echo "$OUTDIR/ResponseData.txt not found! Exiting!!"
	exit
fi

# Get faces order 
if [[ $SUBJ_NUM == 0339 ]]; then # this sub's eprime file was accidentally overwritten with one having the wrong order 
	FACESORDER=1; 
else	
	FACESORDER=$(grep Order $OUTDIR/ResponseData.txt | cut -d" " -f2)
fi
echo "***Faces order is $FACESORDER***"

#####need this?			
# rm -r $OUTDIR/$runname
mkdir -p $OUTDIR/$runname/contrasts

# create FD and DVARS outlier file to use for censoring
for i in `seq 200`; do 
	FD=`head -$i $OUTDIR/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$runname/outliers.1D; 

head -53 $OUTDIR/$runname/outliers.1D | tail -43 > $OUTDIR/$runname/outliers_block1.1D; 
head -97 $OUTDIR/$runname/outliers.1D | tail -43 > $OUTDIR/$runname/outliers_block2.1D; 
head -141 $OUTDIR/$runname/outliers.1D | tail -43 > $OUTDIR/$runname/outliers_block3.1D; 
head -185 $OUTDIR/$runname/outliers.1D | tail -43 > $OUTDIR/$runname/outliers_block4.1D; 

# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
echo "0 0 -1 1" > $OUTDIR/$runname/contrasts/faceBlock_gr_shapesBlocks.txt

cd $OUTDIR/$runname

## Faces block 1 > adjacent shapes blocks
outname=glm_output_1
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz'[10..52]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces1 \
  -censor outliers_block1.1D \
  -x1D Decon_1 -x1D_stop
3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz'[10..52]' -matrix Decon_1.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 2 > adjacent shapes blocks
outname=glm_output_2
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz'[54..96]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces2 \
  -censor outliers_block2.1D \
  -x1D Decon_2 -x1D_stop
3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz'[54..96]' -matrix Decon_2.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 3 > adjacent shapes blocks
outname=glm_output_3
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz'[98..140]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces3 \
  -censor outliers_block3.1D \
  -x1D Decon_3 -x1D_stop
3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz'[98..140]' -matrix Decon_3.xmat.1D -mask $maskfile \
  -Rbeta ${outname}_betas.nii.gz \
  -noFDR 

## Faces block 4 > adjacent shapes blocks
outname=glm_output_4
# arguments to stim_times are in seconds!
3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz'[142..184]' -xout -mask $maskfile -num_stimts 1 \
  -stim_times 1 '1D: 18' 'SPMG1(50)' -stim_label 1 Faces4 \
  -censor outliers_block4.1D \
  -x1D Decon_4 -x1D_stop
3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz'[142..184]' -matrix Decon_4.xmat.1D -mask $maskfile \
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
3dcalc -prefix anger_gr_neutral.nii -a anger_betas.nii.gz'[2]' -b anger_betas.nii.gz'[0]' -c neutral_betas.nii.gz'[2]' -d neutral_betas.nii.gz'[0]' -expr '(a+b-(c+d))' 
3dcalc -prefix fear_gr_neutral.nii -a fear_betas.nii.gz'[2]' -b fear_betas.nii.gz'[0]' -c neutral_betas.nii.gz'[2]' -d neutral_betas.nii.gz'[0]' -expr '(a+b-(c+d))' 
3dcalc -prefix anger+fear_gr_neutral.nii  -a anger_betas.nii.gz'[2]' -b anger_betas.nii.gz'[0]' -c fear_betas.nii.gz'[2]' -d fear_betas.nii.gz'[0]' -e neutral_betas.nii.gz'[2]' -f neutral_betas.nii.gz'[0]' -expr '((a+b+c+d)/2-(e+f))' 
3dcalc -prefix faces_gr_shapes_avg.nii  -a anger_betas.nii.gz'[2]' -b fear_betas.nii.gz'[2]' -c neutral_betas.nii.gz'[2]' -d surprise_betas.nii.gz'[2]' -expr '((a+b+c+d)/4)' 

# extract ROI means to master file, using a lock dir system to make sure only one processes does this at a time 
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
	if mkdir $lockDir/faces; then
		sleep 5 # seems like this is necessary to make sure any other processes have fully finished
		# first check for old values in master files and delete if found
		lineNum=$(grep -n DMHDS$SUBJ_NUM $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $MasterFile; fi
		str=DMHDS$SUBJ_NUM
		for con in anger_gr_neutral fear_gr_neutral anger+fear_gr_neutral faces_gr_shapes_avg; do
		    for roi in Tyszka_ALL_L Tyszka_ALL_R Tyszka_BL_L Tyszka_BL_R Tyszka_CM_L Tyszka_CM_R; do 
			vals=$(3dROIstats -nzmean -mask $rdir/$roi.nii $con.nii | grep Faces | awk '{print $3}'); 
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

sh $TOPDIR/Scripts/pipeline2.0_DBIS/getConditionsCensoredandSNR.sh $SUBJ_NUM faces # use just 4 digit number! E.g 0234 for DMHDS0234

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/glm_faces.$SLURM_JOB_ID.out $OUTDIR/$runname/glm_faces.$SLURM_JOB_ID.out	
# -- END POST-USER -- 
