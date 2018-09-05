#!/bin/bash

id=$1 # use just 4 digit number! E.g 0234 for DMHDS0234
task=$2
TOPDIR=/cifs/hariri-long									
MasterFile=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_QC_${task}.csv
lockDir=$TOPDIR/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/locks
adir=$TOPDIR/Studies/DBIS/Imaging/derivatives

SNRmeans=(27.0349 40.14108 22.2969 28.1866 48.55082); SNRsds=(3.03419 5.59263 3.20752 3.03648 6.001119);
# changed second SNR mean/sd (stroop) from 45.998/6.4601 8/21/18
SNRmean_stroop2=48.34049; SNRsd_stroop2=7.558543 # for stroop we also need to check dlPFC ROI

# set the threshold above which an entry in the design matrix is considered a time point ("kept") for the given condition/regressor
thr=0.5

case $task in
	faces) 
		prefix=$adir/epiMinProc_faces/sub-$id/glm_AFNI_splitRuns/
		for i in `seq 1 4`; do grep -v "#" $prefix/Decon_$i.xmat.1D | awk '{print $3}' > $prefix/Decon.xmat.tmp${i}.1D; done
		pr -mts" " $prefix/Decon.xmat.tmp1.1D $prefix/Decon.xmat.tmp2.1D $prefix/Decon.xmat.tmp3.1D $prefix/Decon.xmat.tmp4.1D > $prefix/Decon.xmat.1D;
		runname=glm_AFNI_splitRuns; firstCol=1; regressors=(f1 f2 f3 f4); 
		roi=$TOPDIR/Templates/DBIS/Amygdala/Tyszka_ALL_bilat.nii
		t=0 # for indexing SNRmeans and sds
		;; 
	facename) 
		runname=glm_AFNI; firstCol=5; regressors=(enc dist rec); 
		roi=$TOPDIR/Templates/DBIS/Hippocampus/Hippocampus_AAL_bilat.nii
		t=3
		;; 
	stroop) 
		runname=glm_AFNI; firstCol=5; regressors=(Incongruent_correct Congruent_correct Incongruent_incorrect Congruent_incorrect); 
		roi=$TOPDIR/Templates/DBIS/ACC/dACC_4_19_27_BA24peak_5mm.nii
		roi2=$TOPDIR/Templates/DBIS/dlPFC/dlPFC_-44_9_29_BA9and46peak_5mm.nii
		t=1
		;; 
	mid) 
		runname=glm_AFNI; firstCol=6; regressors=(Ctrl_anticipation SmGain_anticipation LgGain_anticipation Target fb_0_hit fb_0_miss fb_1_hit fb_1_miss fb_5_hit fb_5_miss); 
		roi=$TOPDIR/Templates/DBIS/VS/VS_10mm_bilat.nii
		t=2
		;; 
	rest)
		roi=$TOPDIR/Templates/DBIS/Atlases/Power2011_264/power264_gm10_2mm_binary.nii.gz
		t=4
		;;
	*)  echo "Invalid task $task!!! Exiting."
		exit; 
		;;
esac



# write to master file, using a lock dir system to make sure only one processes does this at a time
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do 
	if mkdir $lockDir/censorSNR_$task; then
		sleep 5 # this seems necessary to make sure that any other processes have fully finished
		
		ok_motion=1 # variable to keep track of whether to flag this subject for exclusion
		ok_SNR=1 # variable to keep track of whether to flag this subject for exclusion
		# first check for old values in master file and delete if found
		lineNum=$(grep -n DMHDS$id $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -ci "${lineNum}d" $MasterFile; fi
		str=DMHDS$id;
		
		if [[ $task != rest ]]; then
			# get conditions censored
			i=$firstCol;
			for r in ${regressors[@]}; do 
				if [[ $task == mid || $task == stroop ]]; then 
					exists=$(grep $r $adir/epiMinProc_$task/sub-$id/$runname/run_3ddeconvolve.sh | wc -l); 
				else 
					exists=$(ls $adir/epiMinProc_$task/sub-$id/$runname/Decon.xmat.1D | wc -l); 
				fi
				if [[ $exists -gt 0 ]]; then
					ct=0; 
					for n in `grep -v "#" $adir/epiMinProc_$task/sub-$id/$runname/Decon.xmat.1D | awk -v col=$i '{print $col}'`; do 
						if [ ${#n} -gt 0 ]; then
							# first deal with scientific notation
							value=$(echo ${n} | sed -e 's/[eE]+*/\*10\^/');
							val=$(echo $value | bc -l);
							ans=$(echo $val'>'$thr | bc -l); 
							if [ $ans -gt 0 ]; then 
								ct=$((ct+1)); 
							fi; 
						fi;
					done; 
					i=$((i+1));
				else
					ct=NA
				fi
				str="$str,$ct"; 
				if [[ $r != target && $r != fb* && $r != *_incorrect  ]]; then  # for the mid target & fb conditions, and the stroop incorrect conditions, we will ignore the 5 volume requirement
					if [[ $ct -lt 5 ]]; then ok_motion=0; fi
					if [[ $ct -eq NA ]]; then ok_motion=NA; fi
				fi
			done
		else
			ct=$(3dinfo -nv $adir/epiMinProc_$task/sub-$id/fslFD35/epiPrepped_blur6mm.nii.gz)
			str="$str,$ct"; 
			# for rest, epiPrepped won't exist if there are fewer than ~170 volumes remaining after censoring
			# in this case, ct will be "NO-DSET"; if we want we can add a further threshold for number of volumes here
			if [[ $ct -lt 100 ]]; then ok_motion=0; fi  
			if [[ ! -e $adir/epiMinProc_$task/sub-$id/epiWarped.nii.gz ]]; then ok_motion=NA; fi  
		fi
		
		# SNR check, commented code is what I used to get mean and SD from first 500 scans initially
		if [[ -e $adir/epiMinProc_$task/sub-$id/tSNR.EpiWarped.nii.gz ]]; then 
			snr_avg=$(3dROIstats -nzmean -mask $roi $adir/epiMinProc_$task/sub-$id/tSNR.EpiWarped.nii.gz | grep tSNR | awk '{print $4}'); 
			snr_min=$(echo ${SNRmeans[$t]} - 3*${SNRsds[$t]} | bc)
			if [[ $(echo $snr_avg '<' $snr_min | bc) -eq 1 ]]; then ok_SNR=0; fi
			if [[ $task == stroop ]]; then 
				# for stroop we also need to check dlPFC ROI
				snr_avg2=$(3dROIstats -nzmean -mask $roi2 $adir/epiMinProc_$task/sub-$id/tSNR.EpiWarped.nii.gz | grep tSNR | awk '{print $4}'); 
				snr_min2=$(echo $SNRmean_stroop2 - 3*$SNRsd_stroop2 | bc)			
				if [[ $(echo $snr_avg2 '<' $snr_min2 | bc) -eq 1 ]]; then ok_SNR=0; fi
				$snr_avg=$snr_avg,$snr_avg2 # so that both of these will print to the file
			fi
		else
			snr_avg=NA
			ok_SNR=NA
		fi
		##file=$H/Scripts/pipeline2.0_DBIS/config/first500scans.txt
		##for f in `ls $H/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_QC*`; do col=$(awk -F, '{print NF}' $f | head -1); for id in `cat $file`; do val=$(grep $id $f | cut -d, -f$col); if [[ ${#val} -gt 0 ]]; then echo $val >> tmpSNR_$f; fi; done; done
		##for f in `ls $H/Database/DBIS/Imaging/x_x.KEEP.OUT.x_x/fMRI_QC*`; do col=$(awk -F, '{print NF}' $f | head -1); mean=$(awk 'BEGIN{s=0;}{s=s+$1;}END{print s/NR;}' tmpSNR_$f); sd=$(awk '{sum+=$1; sumsq+=$1*$1} END {print sqrt(sumsq/NR - (sum/NR)^2)}' tmpSNR_$f); echo $f $mean $sd; done
		##SNRok=$(awk -F, -v m=${SNRmeans[$i]} -v s=${SNRsds[$i]} 'BEGIN{min=m-3*s;max=m+3*s} {if(length($NF)>0) if($NF<min || $NF>max) print -1; else print 1; else print 0;}' $masterDir/QC/fMRI_QC_${tasks[$i]}.csv) #used this for checking all at once
			
		# write to file
		echo $str,$snr_avg,$ok_motion,$ok_SNR >> $MasterFile
		
		rm -r $lockDir/censorSNR_$task
		break
	else
		sleep 2
	fi
done

if [[ $task == faces ]]; then rm $adir/epiMinProc_$task/sub-$id/glm_AFNI_splitRuns/Decon.xmat.tmp*; rm $adir/epiMinProc_$task/sub-$id/glm_AFNI_splitRuns/Decon.xmat.1D; fi

