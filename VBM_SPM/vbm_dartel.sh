#!/bin/sh

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/vbm_dartel.%j.out 
#SBATCH --error=/dscrhome/%u/vbm_dartel.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -

# ------------------------------------------------------------------------------
#  Variables and Path Preparation
# ------------------------------------------------------------------------------

# Initialize input variables 
SUBJ_NUM=$1 	# use just 4 digit number! E.g 0234 for DMHDS0234
KERNELSIZE=$2
PREPONLY=$3
VBMONLY=$4
echo "----JOB [$SLURM_JOB_ID] SUBJ $SUBJ_NUM START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"

# Initialize other variables to pass on to matlab template script
TOPDIR=/cifs/hariri-long
OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/VBM_SPM/sub-$SUBJ_NUM/DARTEL_${KERNELSIZE}mm       # This is the subject output directory top
SCRIPTDIR=$TOPDIR/Scripts/pipeline2.0_DBIS/VBM_SPM   											    # This is the location of our MATLAB script templates
graphicsDir=$TOPDIR/Studies/DBIS/Graphics/Brain_Images/
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/VBM_SPM_DARTEL_TIV.csv

# check for T1 file
t1=$(ls $TOPDIR/Studies/DBIS/Imaging/sourcedata/sub-$SUBJ_NUM/anat/sub-${SUBJ_NUM}*_T1w.nii.gz | tail -1) # assume that last scan collected was best
if [[ ${#t1} -eq 0 ]]; then 
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Could not find T1 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	exit
fi

rm -r $OUTDIR # get rid of any previous runs
mkdir -p $OUTDIR
# Change into directory where template exists, save subject specific script
# Loop through template script replacing keywords
for i in $SCRIPTDIR/vbm_dartel.m; do
sed -e 's@SUB_SUBJECT_SUB@'$SUBJ_NUM'@g' \
 -e 's@SUB_MOUNT_SUB@'$TOPDIR'@g' \
 -e 's@SUB_OUTDIR_SUB@'$OUTDIR'@g' \
 -e 's@SUB_T1_SUB@'$t1'@g' \
 -e 's@SUB_JUSTPREP_SUB@'$PREPONLY'@g' \
 -e 's@SUB_JUSTVBM_SUB@'$VBMONLY'@g' \
 -e 's@SUB_KS_SUB@'$KERNELSIZE'@g' <$i> $OUTDIR/vbm_dartel_1.m
done
 
# Change to output directory and run matlab on input script
cd $OUTDIR

/opt/apps/matlabR2016a/bin/matlab -nodisplay -singleCompThread < vbm_dartel_1.m 

echo "Done running vbm_dartel.m in matlab\n" 

# use ants function to create a QA snapshot (from the info it doesn't seem like all these parameters should be necessary, but got an error when I pared it down)
outfile=$OUTDIR/smwc1HighRes.nii
CreateTiledMosaic -i $outfile -o ${outfile/.nii/_check.png} -t -1x-1 -s [10,20,100] -r $outfile -a 0 -d 2 -p mask -x $outfile -f 0x1 -p 0
cp ${outfile/.nii/_check.png} $TOPDIR/Studies/DBIS/Graphics/Data_Check/NewPipeline/VBM.smwc1HighRes_check/DMHDS$SUBJ_NUM.png

# move grey matter segment to brain images directory
mkdir -p $graphicsDir/ReadyToProcess/DMHDS$SUBJ_NUM
mv $OUTDIR/c1HighRes.nii.gz $graphicsDir/ReadyToProcess/DMHDS$SUBJ_NUM/c1HighRes.nii.gz

# write TIV estimates to master file
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
	while true; do
		if mkdir $lockDir/freesurfer; then
			sleep 5 # seems like this is necessary to make sure any other processes have fully finished	
			# first check for old values in master files and delete if found
			lineNum=$(grep -n DMHDS$SUBJ_NUM $MasterFile | cut -d: -f1)
			if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $MasterFile; fi
			echo DMHDS$SUBJ_NUM,$(tail -1 $OUTDIR/TIV.csv | cut -d, -f2-) >> $MasterFile
			rm -r $lockDir/freesurfer
			break
		else
			sleep 5
		fi
	done
fi

# **********************************************************
# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/vbm_dartel.$SLURM_JOB_ID.out $OUTDIR/vbm_dartel.$SLURM_JOB_ID.out 
# -- END POST-USER -- 

