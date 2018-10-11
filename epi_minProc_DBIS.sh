#!/bin/bash
#
# Script: epi_minProc_DBIS.sh
# Purpose: Pipeline for minProc of all EPI data for DBIS
# Author: Maxwell Elliott
# Date: 06/26/17


###########!!!!!!!!!Pipeline to do!!!!!!!!!!!!!#############
#1)make citations #citations
#2)Follow up on #pipeNotes using ctrl f pipeNotes.... Made these when I knew a trick or something I needed to do later


###########!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!###########################

###############################################################################
#
# Environment set up
#
###############################################################################

####Changes to be made from single band pipeline
#1) Slice Time Correction: Need a more complicated system to account for slice acquisition. Afni has tool to make volume with timing information
#2) Re-test alignment with EPI, may be alternate optimized parameters
#3) Bo unwarping, consider using epi_reg approach https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6b6c4ba1.1404

# --- BEGIN GLOBAL DIRECTIVE -- 
#SBATCH --output=/dscrhome/%u/epi_minProc_DBIS.%j.out 
#SBATCH --error=/dscrhome/%u/epi_minProc_DBIS.%j.out 
# SBATCH --mail-user=%u@duke.edu
# SBATCH --mail-type=END
#SBATCH --mem=16000 # max is 64G on common partition, 64-240G on common-large
#SBATCH -p scavenger
# -- END GLOBAL DIRECTIVE -

source ~/.bash_profile

sub=$1 # use just 4 digit number! E.g 0234 for DMHDS0234
task=$2
threads=$3

TOPDIR=/cifs/hariri-long
scriptDir=$TOPDIR/Scripts/pipeline2.0_DBIS # using BASH_SOURCE doesn't work for cluster jobs bc they are saved as local copies to nodes
imagingDir=$TOPDIR/Studies/DBIS/Imaging
QADir=$imagingDir/derivatives/QA/sub-${sub}
antDir=$imagingDir/derivatives/ANTs/sub-${sub}
freeDir=$imagingDir/derivatives/freesurfer_v6.0/sub-${sub}
outDir=$imagingDir/derivatives/epiMinProc_$task/sub-${sub}
tmpDir=${outDir}/tmp
antPre="highRes_"
templateDir=$TOPDIR/Templates/DBIS/WholeBrain
templatePre=dunedin115template_MNI_ #pipenotes= update/Change away from HardCoding later
fieldMapDir=$imagingDir/sourcedata/fmap/sub-${sub}
graphicsDir=$TOPDIR/Studies/DBIS/Graphics/Brain_Images/
if [ ${#threads} -eq 0 ]; then threads=1; fi 
export PATH=$PATH:${scriptDir}/:${scriptDir/DBIS/common}/:${scriptDir}/utils/  #DCCnotes: do this all in bash_profile?

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$threads
export OMP_NUM_THREADS=$threads

echo "----JOB [$SLURM_JOB_ID] SUBJ $sub START [`date`] on HOST [$HOSTNAME]----"
echo "----CALL: $0 $@----"

# # ##Make sure anatomical has been run
# # if [ ! -e ${antDir}/${antPre}BrainSegmentation.nii.gz ]; then
	# # echo "#########################################################################################################"
	# # echo "###################### Processed anatomical not found, running anat_DBIS.sh #############################"
	# # echo "#########################################################################################################"
	# # sh /mnt/BIAC/munin4.dhe.duke.edu/Hariri/DBIS.01/Scripts/NewPipeline/anat_DBIS.sh $sub 1
# # fi

##Grab Epi and set up directories

if [[ $task == "faces" ]];then
	expLen=200
elif [[ $task == "mid" ]];then
	expLen=232
elif [[ $task == "stroop" ]];then
	expLen=209
elif [[ $task == "facename" ]];then
	expLen=172
elif [[ $task == "rest" ]];then
	expLen=248
else
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EPI task Name does not match faces, cards, numLS or facename!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		exit
fi

epiRaw=$(ls $imagingDir/sourcedata/sub-$sub/func/sub-${sub}_task-${task}*_bold.nii.gz | tail -1) # take second run if task was stopped and restarted
json=$(ls $imagingDir/sourcedata/sub-$sub/func/sub-${sub}_task-${task}*_bold.json | tail -1) # take second run if task was stopped and restarted

##Set up directory
rm -r $outDir # get rid of old runs if necessary
mkdir -p $QADir
mkdir -p $tmpDir
cd $outDir

# copy epi from sourcedata to working dir
cp $epiRaw ${tmpDir}/epi.nii.gz

###Check to make sure epi has correct number of TRs other exit and complain
expLen2=$(echo "$expLen-1" | bc)
lenEpi=$(3dinfo -nv ${tmpDir}/epi.nii.gz)
runCt=$(ls $imagingDir/sourcedata/sub-$sub/func/sub-${sub}*_task-${task}_bold.nii.gz | wc -l)
if [[ $lenEpi == $expLen || $lenEpi == $expLen2 ]];then
	echo "Found $runCt Epi runs. The last (or only) run matches the assumed length"
else
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!! EPI has wrong number of TRs! Detected $runCt runs, last is length $lenEpi !!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!EXITING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"	
	exit
fi

echo ""
echo "#########################################################################################################"
echo "#########################################Prep epi for warping############################################"
echo "#########################################################################################################"
echo ""
###Resample structural to voxel dimensions of epi for grid when applying warps
3dDespike -prefix ${tmpDir}/epi_d.nii.gz ${tmpDir}/epi.nii.gz #citation:Jo et al., 2014 #pipeNotes: do we want to do this on tasks?? #citation: Kalcher et al., 2013. Example of despiking in task analysis...at least some people do this... #citation: also https://afni.nimh.nih.gov/afni/community/board/read.php?1,141185,143682#msg-143682, small comment "helpful, more important in rest than task" 
# need to add -tpattern when adapting to BIDS format, bc the conversion to bids strips the slice timing information from the image header (which AFNI can read) and puts it in the json file instead
grep -A72 SliceTiming $json | tail -72 | sed 's/,//g' | sed 's/]//' > ${outDir}/SliceTiming.txt
3dTshift -tpattern @${outDir}/SliceTiming.txt -tzero 0 -prefix ${tmpDir}/epi_dt.nii.gz ${tmpDir}/epi_d.nii.gz #perform t-shifting and shift times to begining of TR as suggested by afni "As the comment states, the goal is to resample each voxel time series so that it is as if each volume was acquired at the beginning of each TR.  That way the slice timing will accurately match the stimulus timing." #citation: https://afni.nimh.nih.gov/pub/dist/edu/data/CD.expanded/AFNI_data6/FT_analysis/tutorial/t10_tshift.txt
# # 3dvolreg -base 0 -prefix ${tmpDir}/epi_dtv.nii.gz -zpad 1 -1Dfile ${outDir}/motion.1D ${tmpDir}/epi_dt.nii.gz # volume registation and extraction of motion trace; this is now done in SPM as part of the fieldmap operation


echo ""
echo "#########################################################################################################"
echo "######################################### Run field map in SPM ##########################################"
echo "#########################################################################################################"
echo ""

#gunzip ${tmpDir}/epi_dt.nii.gz
# Loop through template MATLAB script replacing keywords
for i in ${scriptDir}'/spm_fieldmap.m'; do
sed -e 's@SUB_SUBJECT_SUB@'$sub'@g' \
	-e 's@SUB_NUMTRS_SUB@'$expLen'@g' \
	-e 's@SUB_OUTDIR_SUB@'$outDir'@g' \
	-e 's@SUB_TASK_SUB@'$task'@g' <$i> spm_fieldmap.m
done
# run script
/opt/apps/matlabR2016a/bin/matlab -nodisplay -singleCompThread < spm_fieldmap.m

# clean up
rm ${tmpDir}/meanuepi_dt.nii
gzip ${tmpDir}/wfmag_epi_dt.nii
gzip ${tmpDir}/uepi_dt.nii
#gzip ${tmpDir}/epi_dt.nii
mv ${tmpDir}/uepi_dt.nii.gz ${tmpDir}/epi_dtv.nii.gz
rm ${tmpDir}/epi_dt.nii
3drefit -TR 2 -space ORIG -view orig ${tmpDir}/epi_dtv.nii.gz

3dAutomask -prefix ${tmpDir}/epi_ExtractionMask.nii.gz ${tmpDir}/epi_dtv.nii.gz #Create brain mask for extraction
3dcalc -a ${tmpDir}/epi_ExtractionMask.nii.gz -b ${tmpDir}/epi_dtv.nii.gz -expr 'a*b' -prefix ${tmpDir}/epi_dtvb.nii.gz #extract brain
3dTstat -prefix ${tmpDir}/epi_dtvbm.nii.gz ${tmpDir}/epi_dtvb.nii.gz # Create mean image for more robust alignment to sub T1
N4BiasFieldCorrection -i ${tmpDir}/epi_dtvbm.nii.gz #Correct image non-uniformities in mean(not analyzed just for registration) to improve coregistration

echo ""
echo "#########################################################################################################"
echo "###################Calculates Warps to align epi to template via subjects HighRes T1#####################"
echo "#########################################################################################################"
echo ""
###Only calculate for rest1 then apply to rest2 as they are volreged to same base

##Use BBR to align EPI to Subject HighRes #citation: ftp://ftp.nmr.mgh.harvard.edu/pub/articles/greve.2009.ni.63.BBR.pdf and https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FLIRT_BBR
##Comments: This method works much better in our data for a few reasons: First, a video 1 TR from each subjects aligned and warped EPI reveals much more stable and consisted alignment in BBR than rigid registration, White matter tracts are more clearer and consistently in the same location. Second tSNR maps clearly reveal this shift, old maps are shifted down with substantially worse tSNR in dorsal gray matter. Here tSNR is better in new pipeline on the order of 200%. in ventral areas old is generally better but we've decided this is because WM has higher tSNR and this signal is artifactually being pulled down into ventral GM because of poor alignment. For these reasons we are sticking to BBR and confident in combination of BBR and ants SYN. Without BBR ants SYN with rigid performed globally worse than old pipeline. This is probably because SYN just multiplies noise from poor epi alignment
3dcalc -a ${antDir}/${antPre}BrainSegmentation.nii.gz -expr 'equals(a,3)' -prefix ${tmpDir}/ExtractedBrain0N4_wmsegtmp.nii.gz
fslreorient2std ${tmpDir}/ExtractedBrain0N4_wmsegtmp.nii.gz ${tmpDir}/ExtractedBrain0N4_FSL_wmseg.nii.gz
fslreorient2std ${tmpDir}/epi_dtvbm.nii.gz ${tmpDir}/epi_dtvbmFSL.nii.gz
fslreorient2std ${antDir}/${antPre}BrainSegmentation0N4.nii.gz ${tmpDir}/BrainSegmentation0N4_FSL.nii.gz
robustfov -i ${tmpDir}/BrainSegmentation0N4_FSL.nii.gz
fslreorient2std ${antDir}/${antPre}ExtractedBrain0N4.nii.gz ${tmpDir}/ExtractedBrain0N4_FSL.nii.gz
robustfov -i ${tmpDir}/ExtractedBrain0N4_FSL.nii.gz

########################################### MAX START HERE ########################################################
##BBR register 
epi_reg --epi=${tmpDir}/epi_dtvbmFSL.nii.gz --t1=${tmpDir}/BrainSegmentation0N4_FSL.nii.gz --t1brain=${tmpDir}/ExtractedBrain0N4_FSL.nii.gz --out=${tmpDir}/epi2highResBBR -v
c3d_affine_tool -ref ${tmpDir}/ExtractedBrain0N4_FSL.nii.gz -src ${tmpDir}/epi_dtvbmFSL.nii.gz ${tmpDir}/epi2highResBBR.mat -fsl2ras -oitk ${outDir}/epi2highRes0GenericAffine.mat
#3dTstat -prefix ${tmpDir}/epi2highResBBRmean.nii.gz ${tmpDir}/epi2highResBBR.nii.gz
voxSize=$(@GetAfniRes ${tmpDir}/epi.nii.gz)
3dresample -input ${templateDir}/${templatePre}Brain.nii.gz -dxyz 2 2 2 -prefix ${tmpDir}/refTemplate4epi.nii.gz ##Citation: Decided to switch to resample to 2mm iso after testing and showing that group activation maps are more robust and significant when this step is added

##Apply Warps #citation: https://github.com/stnava/ANTs/wiki/antsCorticalThickness-and-antsLongitudinalCorticalThickness-output and https://github.com/maxwe128/restTools/blob/master/preprocessing/norm.func.spm12sa.csh 


antsApplyTransforms -d 3 -e 3 -i ${tmpDir}/epi_dtvbm.nii.gz -o ${tmpDir}/epiWarpedMean.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -t ${outDir}/epi2highRes0GenericAffine.mat -n Bspline #At first Bspline looked best but we switched back to Linear because of marked improvements in tSNR maps in linear compared to Bspline compared to oldSPM methods
antsApplyTransforms -d 3 -e 3 -i ${tmpDir}/epi_dtvbm.nii.gz -o ${tmpDir}/epiMean2highRes.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -t ${outDir}/epi2highRes0GenericAffine.mat -n Linear
antsApplyTransforms -d 3 -e 3 -i ${tmpDir}/epi_dtv.nii.gz -o ${outDir}/epiWarped.nii.gz -r ${tmpDir}/refTemplate4epi.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -t ${outDir}/epi2highRes0GenericAffine.mat -n Bspline 
3drefit -space MNI -view tlrc ${outDir}/epiWarped.nii.gz #Refit space of warped epi so that it can be viewed in MNI space within AFNI

#####Smooth Data 6mm will get output to about 11-13 FWHM on average
if [[ $task != "rest" ]];then
	##Smooth
	3dBlurInMask -input ${outDir}/epiWarped.nii.gz -mask ${templateDir}/${templatePre}BrainExtractionMask_2mmDil1.nii.gz -FWHM 6 -prefix ${tmpDir}/epiWarped_blur6mm.nii.gz ##comments: Decided again a more restricted blur in mask with different compartments for cerebellum etc, because that approach seemed to be slighly harming tSNR actually and did not help with peak voxel or extent analyses when applied to Faces contrast. Decided to use a dilated Brain Extraction mask because this at least gets rid of crap that is way outside of brain. This saves space (slightly) and aids with cleaner visualizations. A GM mask can still later be applied for group analyses, this way we at least leave that up to the user.
	##Scale: We do not scale rest at all (i.e. even in the next step rest_DNS), because it shouldn't matter for connectivity analysis, and at first we weren't too sure of the appropriate way to do so. May want to change this later though.
	3dTstat -prefix ${tmpDir}/mean.epiWarped_blur6mm.nii.gz ${tmpDir}/epiWarped_blur6mm.nii.gz
	3dcalc -a ${tmpDir}/epiWarped_blur6mm.nii.gz -b ${tmpDir}/mean.epiWarped_blur6mm.nii.gz -expr 'min(200, a/b*100)*step(a)*step(b)' -prefix ${outDir}/epiWarped_blur6mm.nii.gz ##pipenotes: this is scaling all values to have comparaple beta weights across subjects. Make sure to indicate in wiki entry that the unblurred data is not scaled!!!! Also the scaling was motivated by this post #citation: https://afni.nimh.nih.gov/pub/dist/edu/data/CD.expanded/AFNI_data6/FT_analysis/tutorial/t14_scale.txt and is not being done for rest currently.  
fi

echo ""
echo "#########################################################################################################"
echo "###############Get Motion and QA vals and make Aligment Montage for Visual Inspection####################"
echo "#########################################################################################################"
echo ""
######Calculation of motion, DVARs, alignment correlation and plots to have for censoring and QC
# Note that FD is also calculated in spm_fieldmap, per Power 2012, and output to ${outDir}/FD.1D. The values for this version tend to be a bit higher (making for stricter censoring) than those generated by FSL below (FD_FSL.1D). 
# As such we ended up using FD.1D for task censoring, but FD_FSL.1D for rest, where we use a much lower censoring threshold.
#Calculate FD, #citation: Power et al., 2012 
fsl_motion_outliers -i ${tmpDir}/epi_dt.nii.gz -o ${tmpDir}/conf -s ${outDir}/FD_FSL.1D --fd #Use fsl tools because the automatically do it the same as Power 2012 #citation: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FSLMotionOutliers
fsl_motion_outliers --nomoco --dvars -m ${tmpDir}/epi_ExtractionMask.nii.gz -o ${tmpDir}/tempConf -s ${outDir}/fslDVARS.1D -i ${tmpDir}/epi_dtvb.nii.gz #calc FSL style for the purpose of comparison #pipenotes: might want to remove
#Caluclate DVARS #citation: Nichols, 2013
DVARS.sh ${tmpDir}/epi_dtv.nii.gz ${outDir}/DVARS.1D  ##Use Tom Nichols standardized DVARs #pipenotes: here is one paper with a standardized DVARs threshold(1.8) #citation: https://pdfs.semanticscholar.org/8b64/7293808a4903e877f93d8241428b7596a909.pdf
#Calculate derivative of motion params for confound regression, #citation: Power et al., 2014
1d_tool.py -infile ${outDir}/motion_spm_deg.1D -derivative -write ${outDir}/motion_deriv.1D
#calculate TRs above threshold
awk -v thresh=".25" '{if($1 > thresh) print NR}' ${outDir}/FD.1D > ${outDir}/FD.25TRs.1D #find TRs above threshold 
awk -v thresh=".5" '{if($1 > thresh) print NR}' ${outDir}/FD.1D > ${outDir}/FD.5TRs.1D #find TRs above threshold 
###Make QC vals file, spatial correlations for each warp, and anything else from http://ccpweb.wustl.edu/pdfs/2013hcp2_barch.pdf

##Make QC/QA montages
#pipenotes: consider making carpet plots and WC-RSFC plots for at least all connectivity pipelines before and after preprocessing
3dresample -input ${templateDir}/${templatePre}BrainExtractionMask.nii.gz -master ${tmpDir}/refTemplate4epi.nii.gz -prefix ${tmpDir}/refTemplateBrainMask.nii.gz
#tSNR
3dTstat -cvarinvNOD -prefix ${tmpDir}/tSNR.nii.gz ${tmpDir}/epi_dtvb.nii.gz #mean/temporal sd,  #citation: same as Marcus et al., 2013 tSNR
3dTstat -cvarinvNOD -prefix ${outDir}/tSNR.EpiWarped.nii.gz ${outDir}/epiWarped.nii.gz #pipenotes: file can be used in futre to define group masks like in SPM if wanted
tSNR=$(3dBrickStat -mask ${tmpDir}/epi_ExtractionMask.nii.gz ${tmpDir}/tSNR.nii.gz | sed "s/ *//g" | sed "s/\t\t*//g" )
#smoothness before and after warping
rawFWHM=$(3dFWHMx -mask ${tmpDir}/epi_ExtractionMask.nii.gz -combine ${tmpDir}/epi_dtvb.nii.gz | cut -d " " -f11 | sed "s/ *//g" | sed "s/\t\t*//g" )
warpedFWHM=$(3dFWHMx -mask ${tmpDir}/refTemplateBrainMask.nii.gz -combine ${outDir}/epiWarped.nii.gz | cut -d " " -f11 | sed "s/ *//g" | sed "s/\t\t*//g" )
#Motion QC Measures
nVols=$(3dinfo -nv ${outDir}/epiWarped.nii.gz)
FDavg=$(1d_tool.py -show_mmms -infile ${outDir}/FD.1D | sed 's/ /,/g' | cut -d "," -f15 | sed '/^$/d')
FDsd=$(1d_tool.py -show_mmms -infile ${outDir}/FD.1D | sed 's/ /,/g' | cut -d "," -f25 | sed '/^$/d')
DVARSavg=$(1d_tool.py -show_mmms -infile ${outDir}/DVARS.1D | sed 's/ /,/g' | cut -d "," -f15 | sed '/^$/d')
DVARSsd=$(1d_tool.py -show_mmms -infile ${outDir}/DVARS.1D | sed 's/ /,/g' | cut -d "," -f25 | sed '/^$/d')
numCenFD25=$(cat ${outDir}/FD.25TRs.1D | wc -l)
numCenFD50=$(cat ${outDir}/FD.5TRs.1D | wc -l)
FD25Per=$(echo "${numCenFD25}/${nVols}" | bc -l | cut -c1-5)
FD50Per=$(echo "${numCenFD50}/${nVols}" | bc -l | cut -c1-5)
#spatial correlations between epi and highres, epi and Template, and highRes and template as a crude index of alignment quality
antsApplyTransforms -d 3 -i ${antDir}/${antPre}ExtractedBrain0N4.nii.gz -o ${tmpDir}/BrainNormalizedToTemplate.nii.gz -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -r ${antDir}/${antPre}ExtractedBrain0N4.nii.gz -n Linear
epi2TemplateCor=$(3ddot -mask ${tmpDir}/refTemplateBrainMask.nii.gz ${tmpDir}/refTemplate4epi.nii.gz ${tmpDir}/epiWarpedMean.nii.gz | sed "s/ *//g" | sed "s/\t\t*//g" )
epi2highResCor=$(3ddot -mask ${antDir}/${antPre}BrainExtractionMask.nii.gz ${antDir}/${antPre}ExtractedBrain0N4.nii.gz ${tmpDir}/epi2highResBBR.nii.gz | sed "s/ *//g"| sed "s/\t\t*//g")
highRes2TemplateCor=$(3ddot -mask ${templateDir}/${templatePre}BrainExtractionMask.nii.gz  ${tmpDir}/BrainNormalizedToTemplate.nii.gz ${templateDir}/${templatePre}Brain.nii.gz | sed "s/ *//g" | sed "s/\t\t*//g")
#set up QC table for subject
echo "tSNR,rawFWHM,warpedFWHM,FDavg,FDsd,DVARSavg,DVARSsd,FD25Per,FD50Per,epi2TemplateCor,epi2highResCor,highRes2TemplateCor" > ${QADir}/${task}.QCmeasures.txt
echo "$tSNR,$rawFWHM,$warpedFWHM,$FDavg,$FDsd,$DVARSavg,$DVARSsd,$FD25Per,$FD50Per,$epi2TemplateCor,$epi2highResCor,$highRes2TemplateCor" >> ${QADir}/${task}.QCmeasures.txt
######Make Edges and montage of warped edges overlain target Struct to check alignment

##epi Alignment to HighRes with BBR T1 White Matter Edges on EPI
ConvertScalarImageToRGB 3 ${tmpDir}/epi2highResBBR_fast_wmedge.nii.gz ${tmpDir}/epi2highResBBREdgesRBG.nii.gz none red none 0 10 #convert for Ants Montage
3dcalc -a ${tmpDir}/epi2highResBBREdgesRBG.nii.gz -expr 'step(a)' -prefix ${tmpDir}/epi2highResBBREdgesRBGstep.nii.gz #Make mask to make Edges stand out
CreateTiledMosaic -i ${tmpDir}/epi2highResBBR.nii.gz -r ${tmpDir}/epi2highResBBREdgesRBG.nii.gz -o ${QADir}/${task}.epi2HighResBBRAlignmentCheckAxial.png -a 0.8 -t -1x-1 -d 2 -p mask -s [5,mask,mask] -x ${tmpDir}/epi2highResBBREdgesRBGstep.nii.gz -f 0x1  #Create Montage taking images in axial slices every 5 slices
CreateTiledMosaic -i ${tmpDir}/epi2highResBBR.nii.gz -r ${tmpDir}/epi2highResBBREdgesRBG.nii.gz -o ${QADir}/${task}.epi2HighResBBRAlignmentCheckCoronal.png -a 0.8 -t -1x-1 -d 1 -p mask -s [5,mask,mask] -x ${tmpDir}/epi2highResBBREdgesRBGstep.nii.gz -f 0x1
##HighRes Alignment to Template
3dedge3 -input ${tmpDir}/BrainNormalizedToTemplate.nii.gz -prefix ${tmpDir}/highRes2TemplateWarpedEdges.nii.gz  #Detect edges
ConvertScalarImageToRGB 3 ${tmpDir}/highRes2TemplateWarpedEdges.nii.gz ${tmpDir}/highRes2TemplateEdgesRBG.nii.gz none red none 0 10 #convert for Ants Montage
3dcalc -a ${tmpDir}/highRes2TemplateEdgesRBG.nii.gz -expr 'step(a)' -prefix ${tmpDir}/highRes2TemplateEdgesRBGstep.nii.gz #Make mask to make Edges stand out
CreateTiledMosaic -i ${templateDir}/${templatePre}BrainSegmentation0N4.nii.gz -r ${tmpDir}/highRes2TemplateEdgesRBG.nii.gz -o ${QADir}/${task}.highRes2TemplateAlignmentCheck.png -a 0.8 -t -1x-1 -d 2 -p mask -s [5,mask,mask] -x ${tmpDir}/highRes2TemplateEdgesRBGstep.nii.gz -f 0x1  #Create Montage taking images in axial slices every 5 slices
##epiWarpedMean to Template
antsApplyTransforms -d 3 -e 3 -i ${tmpDir}/epi_dtvbm.nii.gz -o ${tmpDir}/epiWarpedMeanHR.nii.gz -r ${templateDir}/${templatePre}BrainSegmentation0N4.nii.gz  -t ${antDir}/${antPre}SubjectToTemplate1Warp.nii.gz -t ${antDir}/${antPre}SubjectToTemplate0GenericAffine.mat -t ${outDir}/epi2highRes0GenericAffine.mat -n Linear
3dedge3 -input ${tmpDir}/epiWarpedMeanHR.nii.gz -prefix ${tmpDir}/epi2TemplateWarpedEdges.nii.gz  #Detect edges
ConvertScalarImageToRGB 3 ${tmpDir}/epi2TemplateWarpedEdges.nii.gz ${tmpDir}/epi2TemplateEdgesRBG.nii.gz none red none 0 10 #convert for Ants Montage
3dcalc -a ${tmpDir}/epi2TemplateEdgesRBG.nii.gz -expr 'step(a)' -prefix ${tmpDir}/epi2TemplateEdgesRBGstep.nii.gz #Make mask to make Edges stand out
CreateTiledMosaic -i ${templateDir}/${templatePre}BrainSegmentation0N4.nii.gz -r ${tmpDir}/epi2TemplateEdgesRBG.nii.gz -o ${QADir}/${task}.epi2TemplateAlignmentCheck.png -a 0.8 -t -1x-1 -d 2 -p mask -s [5,mask,mask] -x ${tmpDir}/epi2TemplateEdgesRBGstep.nii.gz -f 0x1  #Create Montage taking images in axial slices every 5 slices

##Montages to check B0 unwarping
3dresample -master ${tmpDir}/epi2highResBBR.nii.gz -inset ${tmpDir}/epi_dtv.nii.gz'[0]' -prefix ${tmpDir}/epiPostb0.nii.gz
3dresample -master ${tmpDir}/epi2highResBBR.nii.gz -inset ${tmpDir}/epi_dt.nii.gz'[0]' -prefix ${tmpDir}/epiPreb0.nii.gz
CreateTiledMosaic -i ${tmpDir}/epiPreb0.nii.gz -r ${tmpDir}/epiPreb0.nii.gz -o ${QADir}/${task}.preB0.png -a 0 -t -1x-1 -d 2 -p mask -s [15,0,120] -x ${tmpDir}/epiPreb0.nii.gz -f 0x1 -p 0
CreateTiledMosaic -i ${tmpDir}/epiPostb0.nii.gz -r ${tmpDir}/epiPostb0.nii.gz -o ${QADir}/${task}.postB0.png -a 0 -t -1x-1 -d 2 -p mask -s [15,0,120] -x ${tmpDir}/epiPostb0.nii.gz -f 0x1 -p 0

### copy files for vis check
cp ${QADir}/$task.epi2TemplateAlignmentCheck.png $TOPDIR/Studies/DBIS/Graphics/Data_Check/NewPipeline/$task.epi2TemplateAlignmentCheck/DMHDS$sub.png

##Clean up
rm -r $tmpDir

##run first level model
if [ $task != "rest" ]; then
	sbatch -p scavenger $scriptDir/glm_$task.sh $sub
else
	if [ ! -e $outDir/fslFD35/epiPrepped_blur6mm.nii.gz ]; then 
		sbatch -p scavenger $scriptDir/rest_DBIS.sh $sub
	fi
fi

# -- BEGIN POST-USER -- 
echo "----JOB [$SLURM_JOB_ID] STOP [`date`]----" 
mv /dscrhome/$USER/epi_minProc_DBIS.$SLURM_JOB_ID.out $outDir/epi_minProc_DBIS.$SLURM_JOB_ID.out 
# -- END POST-USER -- 


##########Citations
#Jo, H. J., Gotts, S. J., Reynolds, R. C., Bandettini, P. A., Martin, A., Cox, R. W., & Saad, Z. S. (2013). Effective preprocessing procedures virtually eliminate distance-dependent motion artifacts in resting state FMRI. Journal of Applied Mathematics, 2013. http://doi.org/10.1155/2013/935154
#Kalcher, K., Boubela, R. N., Huf, W., Biswal, B. B., Baldinger, P., Sailer, U., … Windischberger, C. (2013). RESCALE: Voxel-specific task-fMRI scaling using resting state fluctuation amplitude. NeuroImage, 70, 80–88. http://doi.org/10.1016/j.neuroimage.2012.12.019
#Marcus, D. S., Harms, M. P., Snyder, A. Z., Jenkinson, M., Wilson, J. A., Glasser, M. F., … Van Essen, D. C. (2013). Human Connectome Project informatics: Quality control, database services, and data visualization. NeuroImage, 80, 202–219. http://doi.org/10.1016/j.neuroimage.2013.05.077
#Nichols, 2013 http://www2.warwick.ac.uk/fac/sci/statistics/staff/academic-research/nichols/scripts/fsl/StandardizedDVARS.pdf and https://www2.warwick.ac.uk/fac/sci/statistics/staff/academic-research/nichols/scripts/fsl/DVARS.sh
#Power, J. D., Barnes, K. A., Snyder, A. Z., Schlaggar, B. L., & Petersen, S. E. (2012). Spurious but systematic correlations in functional connectivity MRI networks arise from subject motion. NeuroImage, 59(3), 2142–2154. http://doi.org/10.1016/j.neuroimage.2011.10.018

