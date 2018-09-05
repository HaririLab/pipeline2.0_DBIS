#!/bin/sh

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
# -- END GLOBAL DIRECTIVE -- 

# ------------------------------------------------------------------------------
#  Variables and Path Preparation
# ------------------------------------------------------------------------------

# Initialize input variables (fed in via python script)
SUBJ=$1
KERNELSIZE=$2
echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $SUBJ START [`date`] on HOST [$HOSTNAME]----"

# Initialize other variables to pass on to matlab template script
BASEDIR=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01
OUTDIR=$BASEDIR/Analysis/SPM/Processed/$SUBJ       # This is the subject output directory top
SCRIPTDIR=$BASEDIR/Scripts/SPM/VBM                 # This is the location of our MATLAB script templates


runs=$(ls $OUTDIR/getDartelTIV*.m | wc -l)
# Change into directory where template exists, save subject specific script
# Loop through template script replacing keywords
for i in $SCRIPTDIR/getDartelTIV.m; do
sed -e 's@SUB_SUBJECT_SUB@'$SUBJ'@g' \
 -e 's@SUB_MOUNT_SUB@'$BASEDIR'@g' \
 -e 's@SUB_KS_SUB@'$KERNELSIZE'@g' <$i> $OUTDIR/getDartelTIV_$((runs+1)).m
done
 
# Change to output directory and run matlab on input script
cd $OUTDIR
/usr/local/bin/matlab -nodisplay < getDartelTIV_$((runs+1)).m


# -- END USER SCRIPT -- #

# **********************************************************
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$JOB_NAME.$JOB_ID.out	 
RETURNCODE=${RETURNCODE:-0}
exit $RETURNCODE
fi
# -- END POST USER-- 
