#!/bin/bash

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/glm_facename.%j.out 
#SBATCH --error=/dscrhome/%u/glm_facename.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -- 

SUBJ_NUM=$1; # use just 4 digit number! E.g 0234 for DMHDS0234
fthr=0.5; dthr=2.5; # FD and DVARS thresholds
runname=glm_AFNI

TOPDIR=/cifs/hariri-long
OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/epiMinProc_facename/sub-$SUBJ_NUM
behavDir=$TOPDIR/Studies/DBIS/Imaging/ResponseData/
behavScript=$TOPDIR/Scripts/pipeline2.0_DBIS/behavioral/getFacenameEprime.pl
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
BehavioralFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/Behavioral_facename.csv
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_ROImeans_facename_$runname.csv
maskfile=$TOPDIR/Templates/DBIS/WholeBrain/dunedin115template_MNI_BrainExtractionMask_2mmDil1.nii.gz
rdir=$TOPDIR/Templates/DBIS/Hippocampus/
outname=glm_output


echo "----JOB [$SLURM_JOB_ID] SUBJ $SUBJ_NUM START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"

###### Read behavioral data ######
if [ -e $behavDir/NameGame/NameGame-$SUBJ_NUM.txt ]; then
	echo "running: $behavScript $behavDir/NameGame/NameGame-$SUBJ_NUM.txt $OUTDIR"
	perl $behavScript $behavDir/NameGame/NameGame-$SUBJ_NUM.txt $OUTDIR
else
	if [ -e $behavDir/NameGame/NameGame-${SUBJ_NUM:1:3}.txt ]; then
		echo "running: $behavScript $behavDir/NameGame/NameGame-${SUBJ_NUM:1:3}.txt $OUTDIR"
		perl $behavScript $behavDir/NameGame/NameGame-${SUBJ_NUM:1:3}.txt $OUTDIR
	else
		echo "***Can't locate facename eprime txt file ($behavDir/NameGame/NameGame-${SUBJ_NUM}.txt or $behavDir/NameGame/NameGame-${SUBJ_NUM:1:3}.txt). Facename will not be run!***";
		exit 32;
	fi	
fi
# write response data summary stats to master file, using a lock dir system to make sure only one process is doing this at a time
if [[ -e $OUTDIR/ResponseData.txt ]]; then 
	if [ ! -e $lockDir ]; then mkdir $lockDir; fi
	while true; do
		if mkdir $lockDir/facename_behav; then
			sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
			# first check for old values in master files and delete if found
			lineNum=$(grep -n DMHDS$SUBJ_NUM $BehavioralFile | cut -d: -f1)
			if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $BehavioralFile; fi
			vals=`awk '{print $2}' $OUTDIR/ResponseData.txt`
			acc=$(grep FacenameAccuracy $OUTDIR/ResponseData.txt | awk '{print $2}')
			if [[ $acc -eq 0 ]]; then ok=0; else ok=1; fi
			echo .,$vals,$ok | sed 's/ /,/g' >> $BehavioralFile
			rm -r $lockDir/facename_behav
			break
		else
			sleep 2
		fi
	done
else
	echo "$OUTDIR/ResponseData.txt not found! Exiting!!"
	exit
fi

mkdir -p $OUTDIR/$runname/contrasts

# create FD and DVARS outlier file to use for censoring
for i in `seq 172`; do 
	FD=`head -$i $OUTDIR/FD.1D | tail -1`; 
	if [[ $FD == *"e"* ]]; then FD=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	if [ $i -eq 1 ]; then DVARS=0; else DVARS=`head -$((i-1)) $OUTDIR/DVARS.1D | tail -1`; fi; 
	if [[ $DVARS == *"e"* ]]; then DVARS=0; fi  ### sometimes its so small that it gets spit out in scientific notation which will cause below to fail, so just set to 0
	echo $(( 1 - $(echo "$FD > $fthr || $DVARS > $dthr" | bc -l) )); 
done > $OUTDIR/$runname/outliers.1D; 

# create contrast files
######### don't forget to change # of leading 0s if you change polort!!!
echo "0 0 0 0 1 -1 0" > $OUTDIR/$runname/contrasts/enc_gr_distr.txt
echo "0 0 0 0 0 -1 1" > $OUTDIR/$runname/contrasts/rec_gr_distr.txt
echo "0 0 0 0 1 0 -1" > $OUTDIR/$runname/contrasts/enc_gr_rec.txt

cd $OUTDIR/$runname
# arguments to stim_times are in seconds!
# glt arg should always be 1
# using polort 3 here per recommendation in afni_proc.py help documentation

3dDeconvolve -input $OUTDIR/epiWarped_blur6mm.nii.gz -xout -polort 3 -mask $maskfile -num_stimts 3 \
-stim_times 1 '1D: 4 88 172 256' 'SPMG1(21)' -stim_label 1 Encoding \
-stim_times 2 '1D: 29 113 197 281' 'SPMG1(21)' -stim_label 2 Distractor \
-stim_times 3 '1D: 54 138 222 306' 'SPMG1(30)' -stim_label 3 Recall \
-censor outliers.1D \
-full_first -fout -tout -errts ${outname}_errts.nii.gz \
-glt 1 contrasts/enc_gr_distr.txt -glt_label 1 enc_gr_distr \
-glt 1 contrasts/rec_gr_distr.txt -glt_label 2 rec_gr_distr \
-glt 1 contrasts/enc_gr_rec.txt -glt_label 3 enc_gr_rec \
-x1D_stop

3dREMLfit -input $OUTDIR/epiWarped_blur6mm.nii.gz -matrix Decon.xmat.1D -mask $maskfile \
  -Rbuck ${outname}.nii \
  -noFDR -tout -Rerrts ${outname}_Rerrts.nii.gz

# extract coefs and tstats for workign with in SPM  
# first volume in output bucket (index 0!) is Full_Fstat, then there are 2 volumes for each condition (Coef, Tstat)
# so, the first contrast volume # is 2*(N conditions) + 1
3dTcat -prefix ${outname}_coefs.nii ${outname}.nii'[7]' ${outname}.nii'[9]' ${outname}.nii'[11]' 
3dTcat -prefix ${outname}_tstats.nii ${outname}.nii'[8]' ${outname}.nii'[10]' ${outname}.nii'[12]'

# calculate variance of residual time series, I think this is analogous to SPM's ResMS image, in case we want this at some point
3dTstat -stdev -prefix ${outname}_Rerrts_sd.nii.gz ${outname}_Rerrts.nii.gz 
fslmaths ${outname}_Rerrts_sd.nii.gz -sqr ${outname}_Rerrts_var.nii.gz
rm ${outname}_Rerrts.nii.gz
rm ${outname}_Rerrts_sd.nii.gz
gzip ${outname}_tstats.nii
rm ${outname}.nii

# extract ROI means to master file, using a lock dir system to make sure only one process is doing this at a time
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do
	if mkdir $lockDir/facename; then
		sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
		# first check for old values in master files and delete if found
		lineNum=$(grep -n DMHDS$SUBJ_NUM $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $MasterFile; fi
		str=DMHDS$SUBJ_NUM
		for roi in Hippocampus_AAL_L Hippocampus_AAL_R; do 
		    vals=$(3dROIstats -nzmean -mask $rdir/$roi.nii $OUTDIR/$runname/${outname}_coefs.nii | grep facename | awk '{print $3}'); 
		    str=$str,$(echo $vals | sed 's/ /,/g')
		done; 
		echo $str >> $MasterFile; 
		rm -r $lockDir/facename
		break
	else
		sleep 2
	fi
done

sh $TOPDIR/Scripts/pipeline2.0_DBIS/getConditionsCensoredandSNR.sh $SUBJ_NUM facename


# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/glm_facename.$SLURM_JOB_ID.out $OUTDIR/$runname/glm_facename.$SLURM_JOB_ID.out 
# -- END POST-USER -- 