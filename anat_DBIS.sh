#!/bin/bash
#
# Script: anat_DBIS.sh
# Purpose: Pipeline for processing T1 anatomical images for the DNS study
# Author: Maxwell Elliott
# Date: 2/24/17
#		10/12/17: ARK added "GLOBAL DIRECTIVE"s to move output to subject antCT dir
#				  ARK added unzip VBM image for use in SPM


###########!!!!!!!!!Pipeline to do!!!!!!!!!!!!!#############
#1)make citations #citations
#2)Follow up on #pipeNotes using ctrl f pipeNotes.... Made these when I knew a trick or something I needed to do later
#3) 3drefit all files in MNI space with -space MNI -view tlrc
#4) maybe add a cut of brain stem, seems to be some issues with this and could add robustness
#5) add optimization to template Brain Mask, 3dzcut then inflate to help with slight cutting of top gyri

###########!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!###########################

###############################################################################
#
# Environment set up
#
###############################################################################

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/anat_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/anat_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=24000 # max is 64G on common partition, 64-240G on common-large
# -- END GLOBAL DIRECTIVE -

source ~/.bash_profile

sub=$1 # use just 4 digit number! E.g 0234 for DMHDS0234
threads=$2
TOPDIR=/cifs/hariri-long
imagingDir=$TOPDIR/Studies/DBIS/Imaging
QADir=$imagingDir/derivatives/QA/sub-${sub}
antDir=$imagingDir/derivatives/ANTs/sub-${sub}
freeDir=$imagingDir/derivatives/freesurfer_v6.0/sub-${sub}
tmpDir=${antDir}/tmp
antPre="highRes_" #pipenotes= Change away from HardCoding laterF
templateDir=$TOPDIR/Templates/DBIS/WholeBrain #pipenotes= update/Change away from HardCoding later
templatePre=dunedin115template_MNI #pipenotes= update/Change away from HardCoding later
anatDir=$imagingDir/sourcedata/sub-${sub}/anat
#flairDir=$TOPDIR/Data/OTAGO/${sub}/DMHDS/MR_3D_SAG_FLAIR_FS-_1.2_mm/
graphicsDir=$TOPDIR/Studies/DBIS/Graphics
MasterDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
#T1=$2 #/mnt/BIAC/munin4.dhe.duke.edu/Hariri/DNS.01/Data/Anat/20161103_21449/bia5_21449_006.nii.gz #pipenotes= update/Change away from HardCoding later
if [ ${#threads} -eq 0 ]; then threads=1; fi # antsRegistrationSyN won't work properly if $threads is empty
# baseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#DCCnotes: do all this in bash_profile instead?
scriptDir=$TOPDIR/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$threads
export OMP_NUM_THREADS=$threads
export SUBJECTS_DIR=$imagingDir/derivatives/freesurfer_v6.0
export FREESURFER_HOME=$TOPDIR/Scripts/Tools/FreeSurfer/freesurfer
export ANTSPATH=$TOPDIR/Scripts/Tools/ants-2.2.0/bin/
export PATH=$PATH:${scriptDir}/:${scriptDir/DBIS/common}/:${scriptDir}/utils/  #DCCnotes: do this all in bash_profile?

echo "----JOB [$SLURM_JOB_ID] SUBJ $sub START [`date`] on HOST [$HOSTNAME]----" 
echo "----CALL: $0 $@----"

##Set up directory
mkdir -p $QADir
mkdir -p $antDir
mkdir -p $tmpDir
cd $antDir

T1=${tmpDir}/anat.nii.gz
FLAIR=${tmpDir}/flair.nii.gz
updated_freesurfer=0; # flag so we know whether we need to re-write extracted values to files

#if [[ ! -f $T1 ]];then
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!NO T1, skipping Anat Processing and Epi processing will also be unavailable!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	exit
#fi

if [[ ! -f ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate.nii.gz ]];then
	bestT1=$(ls $anatDir/*T1w.nii.gz | tail -n1)
	3dcopy ${bestT1} $T1
	sizeT1=$(@GetAfniRes ${T1})
	echo $sizeT1
	#if [[ $sizeT1 != "0.875000 0.875000 0.900000" ]];then
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!T1 is the Wrong Size, wrong number of slices!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	#	exit
	#fi
	###Rigidly align, to avoid future processing issues
	antsRegistrationSyN.sh -d 3 -t r -f ${templateDir}/${templatePre}.nii.gz -m $T1 -n $threads -o ${antDir}/${antPre}r
	#Make Montage of sub T1 brain extraction to check quality
	echo ""
	echo "#########################################################################################################"
	echo "########################################ANTs Cortical Thickness##########################################"
	echo "#########################################################################################################"
	echo ""
	###Run antCT
	which antsCorticalThickness.sh
	antsCorticalThickness.sh -d 3 -a ${antDir}/${antPre}rWarped.nii.gz -e ${templateDir}/${templatePre}.nii.gz -m ${templateDir}/${templatePre}_BrainCerebellumProbabilityMask.nii.gz -p ${templateDir}/${templatePre}_BrainSegmentationPosteriors%d.nii.gz -t ${templateDir}/${templatePre}_Brain.nii.gz -o ${antDir}/${antPre}
else
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Skipping antCT, Completed Previously!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
fi
##Smooth Cortical Thickness for 2nd level
# ARK updated this from FWHM 8 to 6 on 2/15/18 since that's what had been run in all DNS subjects (DNS used GMSegWarped30 but that shouldnt make much dif)
if [[ ! -f ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate_blur6mm.nii ]];then
	3dBlurInMask -input ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate.nii.gz -mask ${templateDir}/${templatePre}_AvgGMSegWarped25connected.nii.gz -FWHM 6 -prefix ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate_blur6mm.nii.gz
	gunzip ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate_blur6mm.nii.gz # need to unzip so folks can use it in SPM
fi
###Make VBM and smooth
if [[ ! -f ${antDir}/${antPre}JacModVBM_blur8mm.nii.gz ]] && [[ ! -f ${antDir}/${antPre}JacModVBM_blur8mm.nii ]];then
	antsApplyTransforms -d 3 -r ${templateDir}/${templatePre}.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors2.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${antDir}/${antPre}GMwarped.nii.gz
	antsApplyTransforms -d 3 -r ${templateDir}/${templatePre}.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors4.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${antDir}/${antPre}SCwarped.nii.gz
	antsApplyTransforms -d 3 -r ${templateDir}/${templatePre}.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors5.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${antDir}/${antPre}BSwarped.nii.gz
	antsApplyTransforms -d 3 -r ${templateDir}/${templatePre}.nii.gz -i ${antDir}/${antPre}BrainSegmentationPosteriors6.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -o ${antDir}/${antPre}CBwarped.nii.gz
	3dcalc -a ${antDir}/${antPre}GMwarped.nii.gz -b ${antDir}/${antPre}SCwarped.nii.gz -c ${antDir}/${antPre}CBwarped.nii.gz -d ${antDir}/${antPre}BSwarped.nii.gz -e ${templateDir}/${templatePre}_blurMask25.nii.gz -i ${antDir}/${antPre}SubjectToTemplateLogJacobian.nii.gz -expr '(a*equals(e,1)+b*equals(e,2)+c*equals(e,3)+d*equals(e,4))*i' -prefix ${antDir}/${antPre}JacModVBM.nii.gz
	3dcalc -a ${antDir}/${antPre}GMwarped.nii.gz -b ${antDir}/${antPre}SCwarped.nii.gz -c ${antDir}/${antPre}CBwarped.nii.gz -d ${antDir}/${antPre}BSwarped.nii.gz -e ${templateDir}/${templatePre}_blurMask25.nii.gz -expr '(a*equals(e,1)+b*equals(e,2)+c*equals(e,3)+d*equals(e,4))' -prefix ${antDir}/${antPre}noModVBM.nii.gz
	3dBlurInMask -input ${antDir}/${antPre}JacModVBM.nii.gz -Mmask ${templateDir}/${templatePre}_blurMask25.nii.gz -FWHM 8 -prefix ${antDir}/${antPre}JacModVBM_blur8mm.nii.gz
	3dBlurInMask -input ${antDir}/${antPre}noModVBM.nii.gz -Mmask ${templateDir}/${templatePre}_blurMask25.nii.gz -FWHM 8 -prefix ${antDir}/${antPre}noModVBM_blur8mm.nii.gz
	gunzip ${antDir}/${antPre}JacModVBM_blur8mm.nii.gz # unzip for use in SPM
fi
###Make Brain Extraction QA montages
if [[ ! -f ${QADir}/anat.BrainExtractionCheckAxial.png ]] || [[ ! -f ${QADir}/anat.BrainExtractionCheckSag.png ]] || [[ ! -f ${QADir}/anat.antCTCheck.png ]];then
	echo ""
	echo "#########################################################################################################"
	echo "####################################Make QA montages######################################"
	echo "#########################################################################################################"
	echo ""
	##Make Cortical Thickness QA montage
	ConvertScalarImageToRGB 3 ${antDir}/${antPre}CorticalThickness.nii.gz ${tmpDir}/corticalThicknessRBG.nii.gz none red none 0 1 #convert for Ants Montage
	3dcalc -a ${tmpDir}/corticalThicknessRBG.nii.gz -expr 'step(a)' -prefix ${tmpDir}/corticalThicknessRBGstep.nii.gz 
	CreateTiledMosaic -i ${antDir}/${antPre}BrainSegmentation0N4.nii.gz -r ${tmpDir}/corticalThicknessRBG.nii.gz -o ${QADir}/anat.antCTCheck.png -a 0.35 -t -1x-1 -d 2 -p mask -s [5,mask,mask] -x ${tmpDir}/corticalThicknessRBGStep.nii.gz -f 0x1  #Create Montage taking images in axial slices every 5 slices
	ConvertScalarImageToRGB 3 ${antDir}/${antPre}ExtractedBrain0N4.nii.gz ${tmpDir}/highRes_BrainRBG.nii.gz none red none 0 10
	3dcalc -a ${tmpDir}/highRes_BrainRBG.nii.gz -expr 'step(a)' -prefix ${tmpDir}/highRes_BrainRBGstep.nii.gz
	CreateTiledMosaic -i ${antDir}/${antPre}BrainSegmentation0N4.nii.gz -r ${tmpDir}/highRes_BrainRBG.nii.gz -o ${QADir}/anat.BrainExtractionCheckAxial.png -a 0.5 -t -1x-1 -d 2 -p mask -s [5,mask,mask] -x ${tmpDir}/highRes_BrainRBGstep.nii.gz -f 0x1
	CreateTiledMosaic -i ${antDir}/${antPre}BrainSegmentation0N4.nii.gz -r ${tmpDir}/highRes_BrainRBG.nii.gz -o ${QADir}/anat.BrainExtractionCheckSag.png -a 0.5 -t -1x-1 -d 0 -p mask -s [5,mask,mask] -x ${tmpDir}/highRes_BrainRBGstep.nii.gz -f 0x1
fi

### Now submit jobs to run EPI preprocessing (check if it's already been done in case we are re-running this script to add something like CT etc)
# do this before freesurfer because freesurfer takes a long time and epis don't depend on any freesurfer output
for task in faces stroop mid facename; do
	if [ ! -e $imagingDir/derivatives/epiMinProc_$task/sub-$sub/epiWarped_blur6mm.nii.gz ]; then
		sbatch $scriptDir/epi_minProc_DBIS.sh $sub $task 1
	fi
done
if [ ! -e $imagingDir/derivatives/epiMinProc_rest/sub-$sub/epiWarped.nii.gz ]; then
	sbatch $scriptDir/epi_minProc_DBIS.sh $sub rest 1
fi

### Now run freesurfer
if [[ ! -f ${freeDir}/surf/rh.pial ]];then
	###Prep for Freesurfer with PreSkull Stripped
	#Citation: followed directions from https://surfer.nmr.mgh.harvard.edu/fswiki/UserContributions/FAQ (search skull)
	echo ""
	echo "#########################################################################################################"
	echo "#####################################FreeSurfer Surface Generation#######################################"
	echo "#########################################################################################################"
	echo ""
	###Pipenotes: Currently not doing highRes processing. Can't get it to run without crashing. Also doesn't add that much to our voxels that are already near 1mm^3
	##Set up options file to allow for sub mm voxel high res run of FreeSurfer
	#echo "mris_inflate -n 15" > ${tmpDir}/expert.opts
	#Run
	rm -r ${freeDir}
	cd $imagingDir/derivatives/freesurfer_v6.0
	#mksubjdirs ${sub}
	#cp -R ${FREESURFER_HOME}/subjects/fsaverage ${subDir}/
	#mri_convert ${antDir}/${antPre}ExtractedBrain0N4.nii.gz ${freeDir}/mri/001.mgz
	${FREESURFER_HOME}/bin/recon-all_noLink -all -s sub-$sub -openmp $threads -i ${antDir}/${antPre}rWarped.nii.gz ##Had to edit recon-all to remove soft links in white matter step, links not allowed on BIAC
	#cp ${freeDir}/mri/T1.mgz ${freeDir}/mri/brainmask.auto.mgz
	#cp ${freeDir}/mri/brainmask.auto.mgz ${freeDir}/mri/brainmask.mgz
	#recon-all -autorecon2 -autorecon3 -s $sub -openmp $threads
	recon-all -s sub-$sub -localGI -openmp $threads		
	updated_freesurfer=1
else
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!Skipping FreeSurfer, Completed Previously!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
fi
if [[ ! -f ${freeDir}/surf/lh.woFLAIR.pial ]];then
	
	bestFlair=$(ls $anatDir/*T2w.nii.gz | tail -n1)
	3dcopy ${bestFlair} $FLAIR
	
	if [[ -f $FLAIR ]];then
		echo ""
		echo "#########################################################################################################"
		echo "#####################################Cleanup of Surface With FLAIR#######################################"
		echo "#########################################################################################################"
		echo ""
		recon-all -subject sub-$sub -FLAIR $FLAIR -FLAIRpial -autorecon3 -openmp $threads #citation: https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all#UsingT2orFLAIRdatatoimprovepialsurfaces
		rm -r ${freeDir}/SUMA ##Removed because if SUMA has already been run, it will be based on wrong pial once we run recon-all with flair
		updated_freesurfer=1
	fi
	
fi

### Now add freesurfer values to Master files, using a lock dir system to make sure only one process is doing this at a time
if [[ $updated_freesurfer -eq 1 ]]; then
	if [ ! -e $lockDir ]; then mkdir $lockDir; fi
	while true; do
		if mkdir $lockDir/freesurfer; then
			sleep 5 # seems like this is necessary to make sure any other processes have fully finished		
			for file in `ls $MasterDir/FreeSurfer_[aBw]*csv`; do
				# check for old values in master files and delete if found
				lineNum=$(grep -n DMHDS$sub $file | cut -d: -f1);
				if [ $lineNum -gt 0 ]; then
					sed -ci "${lineNum}d" $file
				fi
			done
			for f in `ls $freeDir/stats/lh*stats $freeDir/stats/[aw]*stats`; do
				if [ $f != $freeDir/stats/lh.curv.stats ]; then # this file is different so skip it
					measures=`grep "ColHeaders" $f | cut -d" " -f3-`; # skip first "#" and "ColHeaders" so col numbers line up with data
					fname=${f/$freeDir\/stats\//}
					fname_short=${fname/lh./}
					i=1; 
					for measure in $measures; do 
						if [ $measure != StructName ] && [ $measure != Index ] && [ $measure != SegId ]; then 
							vals_L=`grep -v "#" $freeDir/stats/${fname} | awk -v colnum=$i '{print $colnum}'`; 
							str_L=$(echo DMHDS$sub,$vals_L | sed 's/ /,/g')
							if [[ $f == *"/lh."* ]]; then
								vals_R=`grep -v "#" $freeDir/stats/${fname/lh/rh} | awk -v colnum=$i '{print $colnum}'`; 
								str_R=$(echo $vals_R | sed 's/ /,/g')
								echo $str_L,$str_R	>> ${MasterDir}/FreeSurfer_${fname_short/.stats/}_${measure}.csv; 
							else
								echo $str_L	>> ${MasterDir}/FreeSurfer_${fname_short/.stats/}_${measure}.csv; 
							fi
						fi; 
						i=$((i+1)); 
					done
				fi
			done
			# now get the aseg whole-brain summary measures, which are formatted differently than the others
			vals=$(grep Measure $freeDir/stats/aseg.stats | awk -F", " '{print $4}')
			echo DMHDS$sub $vals	| sed -e 's/ /,/g' >> ${MasterDir}/FreeSurfer_aseg_SummaryMeasures.csv; 
			# clean up
			rm -r $lockDir/freesurfer
			break
		else
			sleep 5
		fi
	done
fi	
		
#Run SUMA
if [[ ! -f ${freeDir}/SUMA/std.60.rh.thickness.niml.dset ]];then
	echo ""
	echo "#########################################################################################################"
	echo "######################################Map Surfaces to SUMA and AFNI######################################"
	echo "#########################################################################################################"
	echo ""
	cd ${freeDir}
	rm -r ${freeDir}/SUMA # SUMA will fail if the file ${sub}_SurfVol.nii.gz already exists, so best to delete any output from old run and start fresh
	@SUMA_Make_Spec_FS_lgi -NIFTI -ld 60 -sid sub-$sub
	#ConvertDset -o_gii -input ${freeDir}/SUMA/std.60.lh.area.niml.dset -prefix ${freeDir}/SUMA/std.60.lh.area
	#ConvertDset -o_gii -input ${freeDir}/SUMA/std.60.rh.area.niml.dset -prefix ${freeDir}/SUMA/std.60.rh.area
	#ConvertDset -o_gii -input ${freeDir}/SUMA/std.60.lh.thickness.niml.dset -prefix ${freeDir}/SUMA/std.60.lh.thickness
	#ConvertDset -o_gii -input ${freeDir}/SUMA/std.60.rh.thickness.niml.dset -prefix ${freeDir}/SUMA/std.60.rh.thickness
else
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!Skipping SUMA_Make_Spec, Completed Previously!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
fi
### Prep images to send to subjects
found=$(grep DMHDS$sub $graphicsDir/Brain_Images/finished_processing.txt | wc -l);
if [ $found -eq 0 ]; then
	mkdir -p $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/uncropped_T1/front;
	mkdir -p $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/uncropped_T1/top;
	mkdir -p $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/uncropped_T1/side;
	mkdir -p $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/MoreImages_3D;
	mv ${antDir}/tmp/anat.nii.gz $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/HighRes.nii.gz 
	#cp ${antDir}/${antPre}ExtractedBrain0N4.nii.gz $graphicsDir/Brain_Images/ReadyToProcess/DMHDS$sub/c1HighRes.nii.gz # switching to using SPM segment instead
fi

### copy files for vis check
cp ${QADir}/anat.BrainExtractionCheckAxial.png $graphicsDir/Data_Check/NewPipeline/anat.BrainExtractionCheckAxial/DMHDS$sub.png
cp ${QADir}/anat.BrainExtractionCheckSag.png $graphicsDir/Data_Check/NewPipeline/anat.BrainExtractionCheckSag/DMHDS$sub.png
cp ${QADir}/anat.antCTCheck.png $graphicsDir/Data_Check/NewPipeline/anat.antCTCheck/DMHDS$sub.png

#cleanup
#mv highRes_* antCT/ #pipeNotes: add more deletion and clean up to minimize space, think about deleting Freesurfer and some of SUMA output
# # # # leave this out for now until completely finished with testing!
rm -r ${antDir}/${antPre}BrainNormalizedToTemplate.nii.gz ${antDir}/${antPre}TemplateToSubject* 
rm -r ${antDir}/tmp ${freeDir}/SUMA/${sub}_.*spec  ${freeDir}/SUMA/lh.* ${freeDir}/SUMA/rh.*
gzip ${freeDir}/SUMA/*.nii 

#Run ciftify once epi preprocessing complete
while [[ ! -e $imagingDir/derivatives/epiMinProc_rest/sub-$sub/epiWarped.nii.gz || ! -e $imagingDir/derivatives/epiMinProc_facename/sub-$sub/epiWarped.nii.gz || ! -e $imagingDir/derivatives/epiMinProc_faces/sub-$sub/epiWarped.nii.gz || ! -e $imagingDir/derivatives/epiMinProc_mid/sub-$sub/epiWarped.nii.gz || ! -e $imagingDir/derivatives/epiMinProc_stroop/sub-$sub/epiWarped.nii.gz ]]; do
	sleep 1h
done
sbatch $TOPDIR/Scripts/pipeline2.0_DBIS/ciftify_DBIS.sh sub-$sub
 
# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/anat_DBIS.$SLURM_JOB_ID.out $antDir/anat_DBIS.$SLURM_JOB_ID.out 
# -- END POST-USER -- 
