#!/bin/sh

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/suit_batch.%j.out 
#SBATCH --error=/dscrhome/%u/suit_batch.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=12000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -

# Initialize input variables (fed in via python script)
SUBJ_NUM=$1                # use just 4 digit number! E.g 0234 for DMHDS0234
PREPONLY=$2
SUITONLY=$3

# Initialize other variables to pass on to matlab template script
TOPDIR=/cifs/hariri-long
OUTDIR=$TOPDIR/Studies/DBIS/Imaging/derivatives/SUIT/sub-$SUBJ_NUM       # This is the subject output directory top
SCRIPTDIR=$TOPDIR/Scripts/pipeline2.0_DBIS/VBM_SPM                 # This is the location of our MATLAB script templates
graphicsDir=$TOPDIR/Studies/DBIS/Graphics


# check for T1 file
t1=$(ls $TOPDIR/Studies/DBIS/Imaging/sourcedata/sub-$SUBJ_NUM/anat/sub-${SUBJ_NUM}*_T1w.nii.gz | tail -1) # assume that last scan collected was best
if [[ ${#t1} -eq 0 ]]; then 
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Could not find T1 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	exit
fi

# Change into directory where template exists, save subject specific script
cd $SCRIPTDIR

if [[ $SUITONLY == "no" ]]; then rm -r $OUTDIR; fi # get rid of any previous runs

mkdir -p $OUTDIR
# Loop through template script replacing keywords
for i in 'suit_batch.m'; do
sed -e 's@SUB_SCRIPTDIR_SUB@'$SCRIPTDIR'@g' \
 -e 's@SUB_SUBJECT_SUB@'$SUBJ_NUM'@g' \
 -e 's@SUB_OUTDIR_SUB@'$OUTDIR'@g' \
 -e 's@SUB_T1_SUB@'$t1'@g' \
 -e 's@SUB_JUSTPREP_SUB@'$PREPONLY'@g' \
 -e 's@SUB_JUSTSUIT_SUB@'$SUITONLY'@g' <$i> $OUTDIR/suit_batch_1.m
done
 
# Change to output directory and run matlab on input script
cd $OUTDIR

/opt/apps/matlabR2016a/bin/matlab -nodisplay -singleCompThread < suit_batch_1.m

echo "Done running suit_batch.m in matlab\n"

# Convert display .ps file to PDF
slicesdir s4wcHighRes_seg1.nii
cp slicesdir/s4wcHighRes_seg1.png $graphicsDir/Data_Check/NewPipeline/VBM.SUIT/DMHDS${SUBJ_NUM}_anat_SUIT_s4wcHighRes_seg1.png
cp slicesdir/s4wcHighRes_seg1.png ./ 
rm -r slicesdir

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/suit_batch.$SLURM_JOB_ID.out $OUTDIR/suit_batch.$SLURM_JOB_ID.out 
# -- END POST-USER -- 
