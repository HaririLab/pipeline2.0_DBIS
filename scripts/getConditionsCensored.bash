#!/bin/bash

id=$1
task=$2
EXPERIMENT=`findexp DBIS.01`									# This will give the full path to ../Hariri/DBIS.01
MasterFile=$EXPERIMENT/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/BOLD_QC_${task}_nFramesKept.csv

adir=/home/ark19/linux/experiments/DBIS.01/Analysis/All_Imaging/

# set the threshold above which an entry in the design matrix is considered a time point ("kept") for the given condition/regressor
thr=0.5

case $task in
	faces) 
		prefix=$adir/$id/faces/glm_AFNI_splitRuns/
		for i in `seq 1 4`; do grep -v "#" $prefix/Decon_$i.xmat.1D | awk '{print $3}' > $prefix/Decon.xmat.tmp${i}.1D; done
		pr -mts" " $prefix/Decon.xmat.tmp1.1D $prefix/Decon.xmat.tmp2.1D $prefix/Decon.xmat.tmp3.1D $prefix/Decon.xmat.tmp4.1D > $prefix/Decon.xmat.1D;
		runname=glm_AFNI_splitRuns; firstCol=1; regressors=(f1 f2 f3 f4); ;; 
	facename) runname=glm_AFNI; firstCol=5; regressors=(enc dist rec); ;; 
	stroop) runname=glm_AFNI; firstCol=5; regressors=(Incongruent_correct Congruent_correct Incongruent_incorrect Congruent_incorrect); ;; 
	mid) runname=glm_AFNI; firstCol=6; regressors=(Ctrl_anticipation SmGain_anticipation LgGain_anticipation Target fb_0_hit fb_0_miss fb_1_hit fb_1_miss fb_5_hit fb_5_miss); ;; 

	*)  echo "Invalid task $task!!! Exiting."
		exit; ;;
esac

# write to master file, using a lock dir system to make sure only one processes does this at a time
lockDir=$EXPERIMENT/Data/ALL_DATA_TO_USE/Imaging/x_x.KEEP.OUT.x_x/locks
if [ ! -e $lockDir ]; then mkdir $lockDir; fi
while true; do 
	if mkdir $lockDir/censor_$task; then
		sleep 5 # this seems necessary to make sure that any other processes have fully finished
		# first check for old values in master file and delete if found
		lineNum=$(grep -n $id $MasterFile | cut -d: -f1)
		if [ $lineNum -gt 0 ]; then	sed -i "${lineNum}d" $MasterFile; fi
		str=$id;
		i=$firstCol;
		for r in ${regressors[@]}; do 
			if [[ $task == mid || $task == stroop ]]; then exists=$(grep $r $adir/$id/${task}/$runname/run_3ddeconvolve.sh | wc -l); else exists=1; fi
			if [[ $exists -gt 0 ]]; then
				ct=0; 
				for n in `grep -v "#" $adir/$id/${task}/$runname/Decon.xmat.1D | awk -v col=$i '{print $col}'`; do 
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
		done
		echo $str >> $MasterFile
		rm -r $lockDir/censor_$task
		break
	else
		sleep 2
	fi
done

if [[ $task == faces ]]; then rm $adir/$id/faces/glm_AFNI_splitRuns/Decon.xmat.tmp*; rm $adir/$id/faces/glm_AFNI_splitRuns/Decon.xmat.1D; fi

