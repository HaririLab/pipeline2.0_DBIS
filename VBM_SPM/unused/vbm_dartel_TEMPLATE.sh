#!/bin/sh

# --------------SPM BATCH VBM TEMPLATE ----------------
# 
# This script process anatomical data in Analysis/SPM/Processed/anat
#
# 3/18/16: adapted from DNS (Annchen)
# 10/18/16: increased mem from 8G to 12G
# ----------------------------------------------------

# There are 2 USER sections 
#  1. USER DIRECTIVE: If you want mail notifications when
#     your job is completed or fails you need to set the 
#     correct email address.
#		   
#  2. USER SCRIPT: Add the user script in this section.
#     Within this section you can access your experiment 
#     folder using $EXPERIMENT. All paths are relative to this variable
#     eg: $EXPERIMENT/Data $EXPERIMENT/Analysis	
#     By default all terminal output is routed to the " Analysis "
#     folder under the Experiment directory i.e. $EXPERIMENT/Analysis
#     To change this path, set the OUTDIR variable in this section
#     to another location under your experiment folder
#     eg: OUTDIR=$EXPERIMENT/Analysis/GridOut 	
#     By default on successful completion the job will return 0
#     If you need to set another return code, set the RETURNCODE
#     variable in this section. To avoid conflict with system return 
#     codes, set a RETURNCODE higher than 100.
#     eg: RETURNCODE=110
#     Arguments to the USER SCRIPT are accessible in the usual fashion
#     eg:  $1 $2 $3
# The remaining sections are setup related and don't require
# modifications for most scripts. They are critical for access
# to your data  	 

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -S /bin/sh
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -m ea
#$ -l h_vmem=12G ##Annchen
# -- END GLOBAL DIRECTIVE -- 

# -- BEGIN PRE-USER --
#Name of experiment whose data you want to access 
EXPERIMENT=${EXPERIMENT:?"Experiment not provided"}

source /etc/biac_sge.sh

EXPERIMENT=`biacmount $EXPERIMENT`
EXPERIMENT=${EXPERIMENT:?"Returned NULL Experiment"}

if [ $EXPERIMENT = "ERROR" ]
then
	exit 32
else 
#Timestamp
echo "----JOB [$JOB_NAME.$JOB_ID] START [`date`] on HOST [$HOSTNAME]----" 
# -- END PRE-USER --
# **********************************************************

# -- BEGIN USER DIRECTIVE --
# Send notifications to the following address
#$ -M SUB_USEREMAIL_SUB

# -- END USER DIRECTIVE --

# -- BEGIN USER SCRIPT --
# User script goes here


# ------------------------------------------------------------------------------
#  Variables and Path Preparation
# ------------------------------------------------------------------------------

# Initialize input variables (fed in via python script)
SUBJ=SUB_SUBNUM_SUB                # This is the full subject folder name under Data
RUN=SUB_RUNNUM_SUB                 # This is a run number, if applicable
ANATFOLDER=SUB_ANATFOL_SUB         # This is the name of the anatomical folder
PREPONLY=SUB_PREPONLY_SUB
VBMONLY=SUB_VBMONLY_SUB
KERNELSIZE=SUB_SIZEK_SUB


# Initialize other variables to pass on to matlab template script
OUTDIR=$EXPERIMENT/Analysis/SPM/Processed/$SUBJ       # This is the subject output directory top
SCRIPTDIR=$EXPERIMENT/Scripts/SPM/VBM                 # This is the location of our MATLAB script templates
BIACROOT=/usr/local/packages/MATLAB/BIAC              # This is where matlab is installed on the custer

mkdir -p $OUTDIR

# ------------------------------------------------------------------------------
#  Running VBM
# ------------------------------------------------------------------------------

# Change into directory where template exists, save subject specific script
cd $SCRIPTDIR

# Loop through template script replacing keywords
for i in 'vbm_dartel.m'; do
sed -e 's@SUB_BIACROOT_SUB@'$BIACROOT'@g' \
 -e 's@SUB_SCRIPTDIR_SUB@'$SCRIPTDIR'@g' \
 -e 's@SUB_SUBJECT_SUB@'$SUBJ'@g' \
 -e 's@SUB_MOUNT_SUB@'$EXPERIMENT'@g' \
 -e 's@SUB_ANATEXT_SUB@'$ANATEXT'@g' \
 -e 's@SUB_JUSTPREP_SUB@'$PREPONLY'@g' \
 -e 's@SUB_JUSTVBM_SUB@'$VBMONLY'@g' \
 -e 's@SUB_KS_SUB@'$KERNELSIZE'@g' \
 -e 's@SUB_ANATFOLDER_SUB@'$ANATFOLDER'@g' <$i> $OUTDIR/vbm_dartel_${RUN}.m
done
 
# Change to output directory and run matlab on input script
cd $OUTDIR

# ------------------------------------------------------------------------------
# Preparing Virtual Display
# ------------------------------------------------------------------------------

#First we choose an int at random from 100-500, which will be the location in
#memory to allocate the display
RANDINT=$[( $RANDOM % ($[500 - 100] + 1)) + 100 ]
echo "the random integer for Xvfb is ${RANDINT}";

#Now we need to see if this number is already being used for Xvfb on the node.  We can
#tell because when it is active, it will have a "lock file"

while [ -e "/tmp/.X11-unix/X${RANDINT}" ]
do
      echo "lock file was already created for $RANDINT";
      echo "Trying a new number...";
      RANDINT=$[( $RANDOM % ($[500 - 100] + 1)) + 100 ]
      echo "the random integer for Xvfb is ${RANDINT}";
done

#Initialize Xvfb, put buffer output in TEMP directory
Xvfb :$RANDINT -fbdir $TMPDIR &

/usr/local/bin/matlab -display :$RANDINT < vbm_dartel_${RUN}.m

echo "Done running vbm_dartel.m in matlab\n"

#If the lock was created, delete it
if [ -e "/tmp/.X11-unix/X${RANDINT}" ]
      then
      echo "lock file was created";
      echo "cleaning up my lock file";
      rm /tmp/.X${RANDINT}-lock;
      rm /tmp/.X11-unix/X${RANDINT};
      echo "lock file was deleted";
fi


# Convert display .ps file to PDF
cd $OUTDIR/anat/VBM_DARTEL_SUB_SIZEK_SUBmm

NOW=$(date +"%Y%b%d")
PSFILE=spm_$NOW
if [ -e "$PSFILE.ps" ]; then
ps2pdf $PSFILE.ps
rm $PSFILE.ps
else
echo "Error: Reg check post script file does not exist"; 
fi

# -- END USER SCRIPT -- #

# **********************************************************
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
OUTDIR=${OUTDIR:-$EXPERIMENT/Analysis/SPM/Processed/$SUBJ}
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$JOB_NAME.$JOB_ID.out	 
RETURNCODE=${RETURNCODE:-0}
exit $RETURNCODE
fi
# -- END POST USER-- 
