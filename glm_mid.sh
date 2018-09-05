#!/bin/bash

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/glm_mid.%j.out 
#SBATCH --error=/dscrhome/%u/glm_mid.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -- 

SUBJ_NUM=$1; # use just 4 digit number! E.g 0234 for DMHDS0234
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI

TOPDIR=/cifs/hariri-long
OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/epiMinProc_mid/sub-${SUBJ_NUM}
behaveDir=$TOPDIR/Studies/DBIS/Imaging/ResponseData
eprimeScript=$TOPDIR/Scripts/pipeline2.0_DBIS/behavioral/getMIDEprime.pl
BehavioralFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/Behavioral_mid.csv
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_ROImeans_mid_${runname}.csv
maskfile=$TOPDIR/Templates/DBIS/WholeBrain/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
rdir=$TOPDIR/Templates/DBIS/VS
outname=glm_output
SUBJ=DMHDS$SUBJ_NUM
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks

echo "----JOB [$SLURM_JOB_ID] SUBJ $SUBJ_NUM START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"

###### Read behavioral data ######
mkdir $OUTDIR/stimfiles
if [ -e $behaveDir/QuickStrike/QuickStrike-$SUBJ_NUM.txt ]; then
	perl $eprimeScript $behaveDir/QuickStrike/QuickStrike-$SUBJ_NUM.txt $OUTDIR
else
	if [ -e $behaveDir/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt ]; then
		perl $eprimeScript $behaveDir/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt $OUTDIR
	else
		echo "***Can't locate QuickStrike eprime txt file ($behaveDir/QuickStrike/QuickStrike-$SUBJ_NUM.txt or $behaveDir/QuickStrike/QuickStrike-${SUBJ_NUM:1:3}.txt). mid will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file, using a lock dir system to make sure only one process is doing this at a time
if [[ -e $OUTDIR/ResponseData.txt ]]; then 
	if [ ! -e $lockDir ]; then mkdir $lockDir; fi
	while true; do
		if mkdir $lockDir/mid_behav; then
			sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
			# first check for old values in master files and delete if found
			lineNum=$(grep -n $SUBJ $BehavioralFile | cut -d: -f1)
			if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $BehavioralFile; fi
			vals=`awk '{print $2}' $OUTDIR/ResponseData.txt`
			# # acc=$(grep accALL $OUTDIR/ResponseData.txt | awk '{print $2}')
			# # if [[ $(echo "$acc < .1" | bc ) -eq 1 ]]; then ok=0; else ok=1; fi		
			# on 8/16/18 Ahmad decided that we wouldn't impose much of an accuracy threshold for the workhorse variables
			# (it may come into play later when we are interested in effects related to successful trials)
			if [[ $acc -eq 0 ]]; then ok=0; else ok=1; fi
			echo .,$vals,$ok | sed 's/ /,/g' >> $BehavioralFile
			rm -r $lockDir/mid_behav
			break
		else
			sleep 2
		fi
	done
else
	echo "$OUTDIR/ResponseData.txt not found! Exiting!!"
	exit
fi

# create FD and DVARS outlier file to use for censoring
nTRs=232;
firstTRtoUse=12; # first two trials are dummy trials
mkdir -p $OUTDIR/$runname/contrasts
for i in `seq $firstTRtoUse $nTRs`; do 
	FD=`head -$i $OUTDIR/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$runname/outliers.1D; 

cd $OUTDIR/$runname

# count feedback conditions that are present for this subject
n_fbType=0; for f in `ls ../stimfiles/fb*txt`; do ct=`grep "." $f | wc -l`; if [ $ct -gt 0 ]; then n_fbType=$((n_fbType+1)); fi; done
# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
echo n_fbType: $n_fbType
fb0s=$(printf "%0.s0 " $(seq 1 $n_fbType))
echo "0 0 0 0 0 -1 0.5 0.5 0 $fb0s " > $OUTDIR/$runname/contrasts/gainAnt_gr_ctrlAnt.txt
echo "0 0 0 0 0 -1 1 0 0 $fb0s " > $OUTDIR/$runname/contrasts/smGainAnt_gr_ctrlAnt.txt
echo "0 0 0 0 0 -1 0 1 0 $fb0s " > $OUTDIR/$runname/contrasts/lgGainAnt_gr_ctrlAnt.txt

# arguments to stim_times are in seconds!
# glt arg should always be 1
# using polort 4 here per recommendation in afni_proc.py help documentation and 3dDeconvolve output
echo "3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz'[$((firstTRtoUse-1))..$((nTRs-1))]' -xout -polort 4 -mask $maskfile -num_stimts $((4+n_fbType)) \\" > run_3ddeconvolve.sh
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
echo "3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz'[$((firstTRtoUse-1))..$((nTRs-1))]' -matrix Decon.xmat.1D -mask $maskfile \\" >> run_3ddeconvolve.sh
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
# gzip ${outname}_tstats.nii
rm ${outname}.nii  ### this file contains coef, fstat, and tstat for each condition and contrast, so since we are saving coefs and tstats separately for SPM, i think the only thing we lose here is fstat, which we probably dont want anyway

# extract ROI means to master file, using a lock dir system to make sure only one process does this at a time
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
	if mkdir $lockDir/mid; then
		sleep 5 # seems like this is necessary to make sure any other processes are fully finished
		# first check for old values in master files and delete if found
		lineNum=$(grep -n $SUBJ $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $MasterFile; fi
		str=$SUBJ
		for roi in VS_5mm_L VS_5mm_R VS_10mm_L VS_10mm_R; do 
		    vals=$(3dROIstats -nzmean -mask $rdir/$roi.nii $OUTDIR/$runname/${outname}_coefs.nii | grep mid | awk '{print $3}'); 
		    str=$str,$(echo $vals | sed 's/ /,/g')
		done; 
		echo $str >> $MasterFile; 
		rm -r $lockDir/mid
		break
	else
		sleep 2
	fi
done

#4 digit subj number
sh $TOPDIR/Scripts/pipeline2.0_DBIS/getConditionsCensoredandSNR.sh $SUBJ_NUM mid

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/glm_mid.$SLURM_JOB_ID.out $OUTDIR/$runname/glm_mid.$SLURM_JOB_ID.out		 
# -- END POST-USER -- 
