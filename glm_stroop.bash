#!/bin/bash

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=12G 
# -- END GLOBAL DIRECTIVE -- 

BASEDIR=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/
OUTDIR=$BASEDIR/Analysis/All_Imaging/
TASKDIR=stroop_redo
BehavioralFile=$BASEDIR/Data/ALL_DATA_TO_USE/fMRI_Behavioral/Stroop.csv
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI

SUBJ=$1;
echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $SUBJ START [`date`] on HOST [$HOSTNAME]----"

###### Read behavioral data ######
SUBJ_NUM=$(echo $SUBJ | cut -c6-)
if [ -e $BASEDIR/Data/Behavioral/Colors/Colors-$SUBJ_NUM.txt ]; then
	perl $BASEDIR/Scripts/Behavioral/getStroopEprime.pl $BASEDIR/Data/Behavioral/Colors/Colors-$SUBJ_NUM.txt $OUTDIR/$SUBJ/$TASKDIR
else
	if [ -e $BASEDIR/Data/Behavioral/Colors/Colors-${SUBJ_NUM:1:3}.txt ]; then
		perl $BASEDIR/Scripts/Behavioral/getStroopEprime.pl $BASEDIR/Data/Behavioral/Colors/Colors-${SUBJ_NUM:1:3}.txt $OUTDIR/$SUBJ/$TASKDIR
	else
		echo "***Can't locate STroop eprime txt file ($BASEDIR/Data/Behavioral/Colors/Colors-$SUBJ_NUM.txt or $BASEDIR/Data/Behavioral/Colors/Colors-${SUBJ_NUM:1:3}.txt). Stroop will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file
found=$(grep $SUBJ $BehavioralFile | wc -l)
if [ $found -eq 0 ]; then
	vals=`awk '{print $2}' $OUTDIR/$SUBJ/$TASKDIR/ResponseData.txt`
	echo .,$vals | sed 's/ /,/g' >> $BehavioralFile
fi

mkdir -p $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts

# create FD and DVARS outlier file to use for censoring
nTRs=209;
if [ "$SUBJ" == "DMHDS0234" ]; then nTRs=208; fi
echo "nTRs: $nTRs"
for i in `seq $nTRs`; do 
	FD=`head -$i $OUTDIR/$SUBJ/$TASKDIR/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/$SUBJ/$TASKDIR/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$SUBJ/$TASKDIR/$runname/outliers.1D; 

# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
n_incorrect_con=$(less $OUTDIR/$SUBJ/$TASKDIR/onsets/con_incorrect_onsets.txt | wc -l);
if [ $n_incorrect_con -gt 0 ]; then any_incorrect_con=1; else any_incorrect_con=0; fi
n_incorrect_incon=$(less $OUTDIR/$SUBJ/$TASKDIR/onsets/incon_incorrect_onsets.txt | wc -l);
if [ $n_incorrect_incon -gt 0 ]; then any_incorrect_incon=1; else any_incorrect_incon=0; fi
if [ $((any_incorrect_con+any_incorrect_incon)) -eq 0 ]; then 
	echo "0 0 0 0 1 -1" > $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts/incon_gr_con.txt
elif [ $((any_incorrect_con+any_incorrect_incon)) -eq 1 ]; then
	echo "0 0 0 0 1 -1 0" > $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts/incon_gr_con.txt
	if [ $any_incorrect_incon -eq 1 ]; then
		echo "0 0 0 0 -1 0 1" > $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts/inconIncorrect_gr_incon.txt
	fi
elif [ $((any_incorrect_con+any_incorrect_incon)) -eq 2 ]; then
	echo "0 0 0 0 1 -1 0 0 " > $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts/incon_gr_con.txt
	echo "0 0 0 0 -1 0 1 0" > $OUTDIR/$SUBJ/$TASKDIR/$runname/contrasts/inconIncorrect_gr_incon.txt
fi

cd $OUTDIR/$SUBJ/$TASKDIR/$runname
maskfile=${BASEDIR}/Analysis/Max/templates/DBIS115/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
outname=glm_output
# arguments to stim_times are in seconds!
# glt arg should always be 1
# using polort 3 here per recommendation in afni_proc.py help documentation
echo "3dDeconvolve -input $OUTDIR/$SUBJ/$TASKDIR/epiWarped_blur6mm.nii.gz -xout -polort 3 -mask $maskfile -num_stimts $((2+any_incorrect_incon+any_incorrect_con)) \\" >> run_3ddeconvolve.sh
echo "-stim_times 1 ../onsets/incon_correct_onsets.txt 'SPMG1(3)' -stim_label 1 Incongruent_correct \\" >> run_3ddeconvolve.sh
echo "-stim_times 2 ../onsets/con_correct_onsets.txt 'SPMG1(3)' -stim_label 2 Congruent_correct \\" >> run_3ddeconvolve.sh
nextCondNum=3;
if [ $any_incorrect_incon -gt 0 ]; then echo "-stim_times $nextCondNum ../onsets/incon_incorrect_onsets.txt 'SPMG1(3)' -stim_label $nextCondNum Incongruent_incorrect \\" >> run_3ddeconvolve.sh; nextCondNum=4; fi # incorrect trials
if [ $any_incorrect_con -gt 0 ]; then echo "-stim_times $nextCondNum ../onsets/con_incorrect_onsets.txt 'SPMG1(3)' -stim_label $nextCondNum Congruent_incorrect \\" >> run_3ddeconvolve.sh; fi # incorrect trials
echo "-censor outliers.1D \\" >> run_3ddeconvolve.sh
echo "-full_first -tout -errts ${outname}_errts.nii.gz \\" >> run_3ddeconvolve.sh
echo "-glt 1 contrasts/incon_gr_con.txt -glt_label 1 incon_gr_con \\" >> run_3ddeconvolve.sh
if [ $any_incorrect_incon -gt 0 ]; then echo "-glt 1 contrasts/inconIncorrect_gr_incon.txt -glt_label 2 inconIncorrect_gr_incon \\" >> run_3ddeconvolve.sh; fi
echo "-x1D_stop" >> run_3ddeconvolve.sh
echo "" >> run_3ddeconvolve.sh
echo "3dREMLfit -input $OUTDIR/$SUBJ/$TASKDIR/epiWarped_blur6mm.nii.gz -matrix Decon.xmat.1D -mask $maskfile \\" >> run_3ddeconvolve.sh
echo "-Rbuck ${outname}.nii \\" >> run_3ddeconvolve.sh
echo "-noFDR -tout -Rerrts ${outname}_Rerrts.nii.gz" >> run_3ddeconvolve.sh
 
sh run_3ddeconvolve.sh

# extract coefs and tstats for workign with in SPM  
# first volume in output bucket (index 0!) is Full_Fstat, then there are 2 volumes for each condition (Coef, Tstat)
# so, the first contrast volume # is 2*(N conditions) + 1
if [ $((any_incorrect_con+any_incorrect_incon)) -eq 0 ]; then 		# all correct
	3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[5]'
	3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[6]'
elif [ $((any_incorrect_con+any_incorrect_incon)) -eq 1 ]; then		# incorrect trials in just 1 condition
	if [ $any_incorrect_incon -eq 1 ]; then							# just incon
		3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[7]' ${outname}.nii'[9]'
		3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[8]' ${outname}.nii'[10]'
	else															# just con
		3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[7]'
		3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[8]'
	fi
elif [ $((any_incorrect_con+any_incorrect_incon)) -eq 2 ]; then		# incorrect trials in both conditions
	3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[9]' ${outname}.nii'[11]'
	3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[10]' ${outname}.nii'[12]'
fi

# calculate variance of residual time series, I think this is analogous to SPM's ResMS image, in case we want this at some point
3dTstat -stdev -prefix ${outname}_Rerrts_sd.nii.gz ${outname}_Rerrts.nii.gz 
fslmaths ${outname}_Rerrts_sd.nii.gz -sqr ${outname}_Rerrts_var.nii.gz
rm ${outname}_Rerrts.nii.gz
rm ${outname}_Rerrts_sd.nii.gz
gzip ${outname}_tstats.nii
rm ${outname}.nii   ### this file contains coef, fstat, and tstat for each condition and contrast, so since we are saving coefs and tstats separately for SPM, i think the only thing we lose here is fstat, which we probably dont want anyway

sh $BASEDIR/Scripts/pipeline2.0_DBIS/scripts/getConditionsCensored.bash $SUBJ stroop

# do this for calculating censored conditions later
grep -v "#" Decon.xmat.1D | grep "1" > Decon.xmat.1D.matOnly

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$SUBJ/$TASKDIR/$runname/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 
