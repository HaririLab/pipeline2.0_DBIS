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
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
#$ -l h_vmem=24G 
# -- END GLOBAL DIRECTIVE -- 

sub=$1 #$1 or flag -s  #20161103_21449 #pipenotes= Change away from HardCoding later 
subDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/${sub} #pipenotes= Change away from HardCoding later
QADir=${subDir}/QA
antDir=${subDir}/antCT
freeDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/FreeSurfer_AllSubs/${sub}
tmpDir=${antDir}/tmp
antPre="highRes_" #pipenotes= Change away from HardCoding laterF
templateDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/Max/templates/DBIS115 #pipenotes= update/Change away from HardCoding later
templatePre=dunedin115template_MNI #pipenotes= update/Change away from HardCoding later
anatDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Data/OTAGO/${sub}/DMHDS/MR_t1_0.9_mprage_sag_iso_p2/
flairDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Data/OTAGO/${sub}/DMHDS/MR_3D_SAG_FLAIR_FS-_1.2_mm/
graphicsDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Graphics/Brain_Images/ReadyToProcess/
#T1=$2 #/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Data/Anat/20161103_21449/bia5_21449_006.nii.gz #pipenotes= update/Change away from HardCoding later
threads=$2
if [ ${#threads} -eq 0 ]; then threads=1; fi # antsRegistrationSyN won't work properly if $threads is empty
# baseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
baseDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
export PATH=$PATH:${baseDir}/scripts/:/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Analysis/Max/scripts/huginBin/bin/ #add dependent scripts to path #pipenotes= update/Change to DNS scripts
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$threads
export OMP_NUM_THREADS=$threads
export SUBJECTS_DIR=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/FreeSurfer_AllSubs/
export FREESURFER_HOME=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Analysis/Max/scripts/freesurfer
export ANTSPATH=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Analysis/Max/scripts/ants-2.2.0/bin/
export PATH=$PATH:${baseDir}/scripts/:${baseDir}/utils/:/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Analysis/Max/scripts/ants-2.2.0/bin/
echo "----JOB [$JOB_NAME.$JOB_ID] SUBJ $sub START [`date`] on HOST [$HOSTNAME]----" 

##Set up directory
mkdir -p $QADir
cd $subDir
mkdir -p $antDir
mkdir -p $tmpDir

T1=${tmpDir}/anat.nii.gz
FLAIR=${tmpDir}/flair.nii.gz

#if [[ ! -f $T1 ]];then
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!NO T1, skipping Anat Processing and Epi processing will also be unavailable!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#	exit
#fi

if [[ ! -f ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate.nii.gz ]];then
	Dimon -infile_prefix ${anatDir}/1.3.12.2.1107.5.2.19 -dicom_org -gert_create_dataset -use_obl_origin
	bestT1=$(ls OutBrick_run_0* | tail -n1)
	# check if Dimon import worked, if not try dcm2niix
	if [ ${#bestT1} -eq 0 ]; then
		echo "!!!!!!!!!!!!!!!!!!!! No output from Dimon t1 import, attempting with dcm2niix !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		firstDcm=$(ls ${anatDir}/1.3.12.2.1107.5.2.19* | head -1)
		/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DNS.01/Scripts/Tools/mricrogl_lx/dcm2niix -o ${tmpDir} ${firstDcm}
		gzip ${tmpDir}/MR*nii
		bestT1=$(ls ${tmpDir}/MR*nii.gz | tail -n1)
	fi
	3dcopy ${bestT1} ${tmpDir}/anat.nii.gz
	mv flair.nii.gz dimon* GERT* ${tmpDir} 
	mv OutBrick* ${tmpDir}
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
if [[ ! -f ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate_blur8mm.nii.gz ]];then
	3dBlurInMask -input ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate.nii.gz -mask ${templateDir}/${templatePre}_AvgGMSegWarped25connected.nii.gz -FWHM 8 -prefix ${antDir}/${antPre}CorticalThicknessNormalizedToTemplate_blur8mm.nii.gz
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
if [[ ! -f ${QADir}/anat.BrainExtractionCheckAxial.png ]];then
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
	cd /mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Analysis/All_Imaging/FreeSurfer_AllSubs/
	#mksubjdirs ${sub}
	#cp -R ${FREESURFER_HOME}/subjects/fsaverage ${subDir}/
	echo $freeDir
	#mri_convert ${antDir}/${antPre}ExtractedBrain0N4.nii.gz ${freeDir}/mri/001.mgz
	${FREESURFER_HOME}/bin/recon-all_noLink -all -s $sub -openmp $threads -i ${antDir}/${antPre}rWarped.nii.gz ##Had to edit recon-all to remove soft links in white matter step, links not allowed on BIAC
	#cp ${freeDir}/mri/T1.mgz ${freeDir}/mri/brainmask.auto.mgz
	#cp ${freeDir}/mri/brainmask.auto.mgz ${freeDir}/mri/brainmask.mgz
	#recon-all -autorecon2 -autorecon3 -s $sub -openmp $threads
	recon-all -s $sub -localGI -openmp $threads
	### Add freesurfer values to Master files
	MasterDir=/mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Data/ALL_DATA_TO_USE/testing/
	for file in `ls $MasterDir/FreeSurfer_[aBw]*csv`; do
		# check for old values in master files and delete if found
		lineNum=$(grep -n $sub $file | cut -d: -f1);
		if [ $lineNum -gt 0 ]; then
			sed -i "${lineNum}d" $file
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
					str_L=$(echo $sub,$vals_L | sed 's/ /,/g')
					if [[ $f == *"/lh."* ]]; then
						vals_R=`grep -v "#" $freeDir/stats/${fname/lh/rh} | awk -v colnum=$i '{print $colnum}'`; 
						str_R=$(echo $vals_R | sed 's/ /,/g')
						echo $str_L,$str_R	>> ${MasterDir}FreeSurfer_${fname_short/.stats/}_${measure}.csv; 
					else
						echo $str_L	>> ${MasterDir}FreeSurfer_${fname_short/.stats/}_${measure}.csv; 
					fi
				fi; 
				i=$((i+1)); 
			done
		fi
	done	
else
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!Skipping FreeSurfer, Completed Previously!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
fi
if [[ ! -f ${freeDir}/surf/lh.woFLAIR.pial ]];then
	Dimon -gert_to3d_prefix flair.nii.gz -infile_prefix ${flairDir}/1.3.12.2.1107.5.2.19 -dicom_org -gert_create_dataset -use_obl_origin
	mv flair.nii.gz dimon* GERT* ${tmpDir}
	if [[ -f $FLAIR ]];then
		echo ""
		echo "#########################################################################################################"
		echo "#####################################Cleanup of Surface With FLAIR#######################################"
		echo "#########################################################################################################"
		echo ""
		recon-all -subject $sub -FLAIR $FLAIR -FLAIRpial -autorecon3 -openmp $threads #citation: https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all#UsingT2orFLAIRdatatoimprovepialsurfaces
		rm -r ${freeDir}/SUMA ##Removed because SUMA surface will be based on wrong pial if above ran
	fi
fi
#Run SUMA
if [[ ! -f ${freeDir}/SUMA/std.60.rh.thickness.niml.dset ]];then
	echo ""
	echo "#########################################################################################################"
	echo "######################################Map Surfaces to SUMA and AFNI######################################"
	echo "#########################################################################################################"
	echo ""
	cd ${freeDir}
	@SUMA_Make_Spec_FS_lgi -NIFTI -ld 60 -sid $sub
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
found=$(grep $sub $graphicsDir/finished_processing.txt | wc -l);
if [ $found -eq 0 ]; then
	mkdir -p $graphicsDir/$sub/uncropped_T1/front;
	mkdir -p $graphicsDir/$sub/uncropped_T1/top;
	mkdir -p $graphicsDir/$sub/uncropped_T1/side;
	mkdir -p $graphicsDir/$sub/MoreImages_3D;
	mv ${antDir}/tmp/anat.nii.gz $graphicsDir/$sub/HighRes.nii.gz 
	cp ${antDir}/${antPre}ExtractedBrain0N4.nii.gz $graphicsDir/$sub/c1HighRes.nii.gz 
fi

### copy files for vis check
cp ${QADir}/anat.BrainExtractionCheckAxial.png /mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Graphics/Data_Check/NewPipeline/anat.BrainExtractionCheckAxial/$sub.png
cp ${QADir}/anat.BrainExtractionCheckSag.png /mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Graphics/Data_Check/NewPipeline/anat.BrainExtractionCheckSag/$sub.png
cp ${QADir}/anat.antCTCheck.png /mnt/BIAC/munin2.dhe.duke.edu/Hariri/DBIS.01/Graphics/Data_Check/NewPipeline/anat.antCTCheck/$sub.png

#cleanup
#mv highRes_* antCT/ #pipeNotes: add more deletion and clean up to minimize space, think about deleting Freesurfer and some of SUMA output
# # # # leave this out for now until completely finished with testing!
rm -r ${antDir}/${antPre}BrainNormalizedToTemplate.nii.gz ${antDir}/${antPre}TemplateToSubject* ${subDir}/dimon.files* ${subDir}/GERT_Reco* 
rm -r ${antDir}/tmp ${freeDir}/SUMA/${sub}_.*spec  ${freeDir}/SUMA/lh.* ${freeDir}/SUMA/rh.*
gzip ${freeDir}/SUMA/*.nii 

### Now run EPI preprocessing (if it has not been done; this should only happen in the case where we are re-running this script to add something like CT etc)
for task in faces stroop mid facename; do
	if [ ! -e $subDir/$task/epiWarped_blur6mm.nii.gz ]; then
		qsub $baseDir/epi_minProc_DBIS.sh $sub $task 1
	fi
done
 
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
mv $HOME/$JOB_NAME.$JOB_ID.out $antDir/$JOB_NAME.$JOB_ID.out	 
# -- END POST-USER -- 
