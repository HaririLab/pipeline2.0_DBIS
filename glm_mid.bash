#!/bin/bash

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=12G 
# -- END GLOBAL DIRECTIVE -- 

BASEDIR=`biacmount DBIS.01`
OUTDIR=$BASEDIR/Analysis/All_Imaging/
BehavioralFile=$BASEDIR/Data/ALL_DATA_TO_USE/testing/DBIS_BEHAVIORAL_mid.csv
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI
MasterFile=$BASEDIR/Data/ALL_DATA_TO_USE/testing/BOLD_mid_$runname.csv

SUBJ=$1;
echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $SUBJ START [`date`] on HOST [$HOSTNAME]----"

###### Read behavioral data ######
mkdir $OUTDIR/$SUBJ/mid/stimfiles
SUBJ_NUM=$(echo $SUBJ | cut -c6-)
if [ -e $BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-$SUBJ_NUM.txt ]; then
	perl $BASEDIR/Scripts/Behavioral/getMIDEprime.pl $BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-$SUBJ_NUM.txt $OUTDIR/$SUBJ/mid
else
	if [ -e $BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt ]; then
		perl $BASEDIR/Scripts/Behavioral/getMIDEprime.pl $BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt $OUTDIR/$SUBJ/mid
	else
		echo "***Can't locate QuickStrike eprime txt file ($BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-$SUBJ_NUM.txt or $BASEDIR/Data/Behavioral/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt). mid will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file
found=$(grep $SUBJ $BehavioralFile | wc -l)
if [ $found -eq 0 ]; then
	vals=`awk '{print $2}' $OUTDIR/$SUBJ/mid/ResponseData.txt`
	echo .,$vals | sed 's/ /,/g' >> $BehavioralFile
fi

# create FD and DVARS outlier file to use for censoring
nTRs=232;
firstTRtoUse=12; # first two trials are dummy trials
mkdir -p $OUTDIR/$SUBJ/mid/$runname/contrasts
for i in `seq $firstTRtoUse $nTRs`; do 
	FD=`head -$i $OUTDIR/$SUBJ/mid/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/$SUBJ/mid/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$SUBJ/mid/$runname/outliers.1D; 

cd $OUTDIR/$SUBJ/mid/$runname

# count feedback conditions that are present for this subject
n_fbType=0; for f in `ls ../stimfiles/fb*txt`; do ct=`grep "." $f | wc -l`; if [ $ct -gt 0 ]; then n_fbType=$((n_fbType+1)); fi; done
# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
echo n_fbType: $n_fbType
fb0s=$(printf "%0.s0 " $(seq 1 $n_fbType))
echo "0 0 0 0 0 -1 0.5 0.5 0 $fb0s " > $OUTDIR/$SUBJ/mid/$runname/contrasts/gainAnt_gr_ctrlAnt.txt
echo "0 0 0 0 0 -1 1 0 0 $fb0s " > $OUTDIR/$SUBJ/mid/$runname/contrasts/smGainAnt_gr_ctrlAnt.txt
echo "0 0 0 0 0 -1 0 1 0 $fb0s " > $OUTDIR/$SUBJ/mid/$runname/contrasts/lgGainAnt_gr_ctrlAnt.txt

maskfile=${BASEDIR}/Analysis/Max/templates/DBIS115/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
outname=glm_output
# arguments to stim_times are in seconds!
# glt arg should always be 1
# using polort 4 here per recommendation in afni_proc.py help documentation and 3dDeconvolve output
echo "3dDeconvolve -input $OUTDIR/$SUBJ/mid/epiWarped_blur6mm.nii.gz'[$((firstTRtoUse-1))..$((nTRs-1))]' -xout -polort 4 -mask $maskfile -num_stimts $((4+n_fbType)) \\" >> run_3ddeconvolve.sh
echo "-stim_times_AM1 1 ../stimfiles/cue+delay_0.txt 'dmBLOCK(1)' -stim_label 1 Ctrl_anticipation \\" >> run_3ddeconvolve.sh
echo "-stim_times_AM1 2 ../stimfiles/cue+delay_1.txt 'dmBLOCK(1)' -stim_label 2 SmGain_anticipation \\" >> run_3ddeconvolve.sh
echo "-stim_times_AM1 3 ../stimfiles/cue+delay_5.txt 'dmBLOCK(1)' -stim_label 3 LgGain_anticipation \\" >> run_3ddeconvolve.sh
echo "-stim_times_AM1 4 ../stimfiles/target.txt 'dmBLOCK(1)' -stim_label 4 Target \\" >> run_3ddeconvolve.sh
nextCondNum=5;
for fb_type in 0_hit 0_miss 1_hit 1_miss 5_hit 5_miss; do
	trialct=`grep "." ../stimfiles/fb_onsets_${fb_type}.txt | wc -l`;
	if [ $trialct -gt 0 ]; then echo "-stim_times $nextCondNum ../stimfiles/fb_onsets_${fb_type}.txt 'SPMG1(2)' -stim_label $nextCondNum fb_${fb_type} \\" >> run_3ddeconvolve.sh; nextCondNum=$((nextCondNum+1)); fi 
done
echo "-censor outliers.1D \\" >> run_3ddeconvolve.sh
echo "-full_first -tout -errts ${outname}_errts.nii.gz \\" >> run_3ddeconvolve.sh
echo "-glt 1 contrasts/gainAnt_gr_ctrlAnt.txt -glt_label 1 gainAnt_gr_ctrlAnt \\" >> run_3ddeconvolve.sh
echo "-glt 1 contrasts/smGainAnt_gr_ctrlAnt.txt -glt_label 2 smGainAnt_gr_ctrlAnt \\" >> run_3ddeconvolve.sh
echo "-glt 1 contrasts/lgGainAnt_gr_ctrlAnt.txt -glt_label 3 lgGainAnt_gr_ctrlAnt \\" >> run_3ddeconvolve.sh
echo "-x1D_stop" >> run_3ddeconvolve.sh
echo "" >> run_3ddeconvolve.sh
echo "3dREMLfit -input $OUTDIR/$SUBJ/mid/epiWarped_blur6mm.nii.gz'[$((firstTRtoUse-1))..$((nTRs-1))]' -matrix Decon.xmat.1D -mask $maskfile \\" >> run_3ddeconvolve.sh
echo "-Rbuck ${outname}.nii \\" >> run_3ddeconvolve.sh
echo "-noFDR -tout -Rerrts ${outname}_Rerrts.nii.gz" >> run_3ddeconvolve.sh
 
sh run_3ddeconvolve.sh

# extract coefs and tstats for workign with in SPM  
# first volume in output bucket (index 0!) is Full_Fstat, then there are 2 volumes for each condition (Coef, Tstat)
# so, the first contrast volume # is 2*(N conditions) + 1 = 2 * ( 3 + n_fbType ) + 1
3dTcat -prefix ${outname}_coefs.nii ${outname}.nii"[$((2*(n_fbType+4)+1))]" ${outname}.nii"[$((2*(n_fbType+4)+3))]" ${outname}.nii"[$((2*(n_fbType+4)+5))]"
3dTcat -prefix ${outname}_tstats.nii ${outname}.nii.gz"[$((2*(n_fbType+4)+2))]" ${outname}.nii"[$((2*(n_fbType+4)+4))]" ${outname}.nii"[$((2*(n_fbType+4)+6))]"

# calculate variance of residual time series, I think this is analogous to SPM's ResMS image, in case we want this at some point
3dTstat -stdev -prefix ${outname}_Rerrts_sd.nii.gz ${outname}_Rerrts.nii.gz 
fslmaths ${outname}_Rerrts_sd.nii.gz -sqr ${outname}_Rerrts_var.nii.gz
rm ${outname}_Rerrts.nii.gz
rm ${outname}_Rerrts_sd.nii.gz
gzip ${outname}_tstats.nii
rm ${outname}.nii  ### this file contains coef, fstat, and tstat for each condition and contrast, so since we are saving coefs and tstats separately for SPM, i think the only thing we lose here is fstat, which we probably dont want anyway

# extract ROI means to master file
# first check for old values in master files and delete if found
lineNum=$(grep -n $SUBJ $MasterFile | cut -d: -f1)
if [ $lineNum -gt 0 ]; then	sed -i "${lineNum}d" $MasterFile; fi
rdir=$BASEDIR/Analysis/ROI/VS
str=$SUBJ
for roi in VS_5mm_L VS_5mm_R VS_10mm_L VS_10mm_R; do 
    vals=$(3dROIstats -nzmean -mask $rdir/$roi.nii $OUTDIR/$SUBJ/mid/$runname/${outname}_coefs.nii | grep mid | awk '{print $3}'); 
    str=$str,$(echo $vals | sed 's/ /,/g')
done; 
echo $str >> $MasterFile; 

sh $BASEDIR/Scripts/pipeline2.0_DBIS/scripts/getConditionsCensored.bash $SUBJ mid

# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$SUBJ/mid/$runname/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 