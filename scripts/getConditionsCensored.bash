#!/bin/bash

id=$1
task=$2
EXPERIMENT=`findexp DBIS.01`									# This will give the full path to ../Hariri/DBIS.01
MasterFile=$EXPERIMENT/Data/ALL_DATA_TO_USE/testing/BOLD_${task}_nFramesKept.csv

adir=/home/ark19/linux/experiments/DBIS.01/Analysis/All_Imaging/

thr=0.5

case $task in
	faces) 
		for i in `seq 1 4`; do grep -v "#" $adir/$id/faces/glm_AFNI_splitRuns/Decon_$i.xmat.1D >> $adir/$id/faces/glm_AFNI_splitRuns/Decon.xmat.1D; done
		runname=glm_AFNI_splitRuns; firstCol=3; ;; 
	facename) runname=glm_AFNI; firstCol=5; ;; 
	stroop) runname=glm_AFNI; firstCol=5; ;; 
	mid) runname=glm_AFNI; firstCol=6; ;; 

	*)  echo "Invalid task $task!!! Exiting."
		exit; ;;
esac

lastCol=$(grep -v "#" $adir/$id/${task}/$runname/Decon.xmat.1D | head -1 | awk '{print NF}')

# first check for old values in master file and delete if found
lineNum=$(grep -n $id $MasterFile | cut -d: -f1)
if [ $lineNum -gt 0 ]; then	sed -i "${lineNum}d" $MasterFile; fi
str=$id;
for i in `seq $firstCol $lastCol`; do 
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
	str="$str,$ct"; 
done

echo $str >> $MasterFile

if [ $task == faces ]; then rm $adir/$id/faces/glm_AFNI_splitRuns/Decon.xmat.1D; fi

