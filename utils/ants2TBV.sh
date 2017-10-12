####ants2TBV.sh

#calculates a better version of ants TBV. this TBV represents the total volume of voxels that are at least 25% probability of being one of the following: GM, WM, subCortex or Cerebellum
#excludes CSF and Brain stem

antsDir=$1 #full path to an ants directory. Probabably in an All_Imaging folder

cd $antsDir
3dcalc -a highRes_BrainSegmentationPosteriors2.nii.gz -b highRes_BrainSegmentationPosteriors3.nii.gz -c highRes_BrainSegmentationPosteriors4.nii.gz -d highRes_BrainSegmentationPosteriors6.nii.gz -expr 'step(extreme(a,b,c,d)-.25)' -prefix tmp.nii.gz
3dBrickStat -volume -mask tmp.nii.gz tmp.nii.gz
rm tmp.nii.gz
