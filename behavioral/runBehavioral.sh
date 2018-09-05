#echo "Usage: sh runBehavioral.sh N (where N is number of days back to pull files from)"


rm colorslist.txt
for f in `ls /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/Colors/*txt`; do 
  found=`grep $f colorsout.txt | wc -l`
  if [ $found -eq 0 ]; then
    echo $f >> colorslist.txt
  fi
  #start=`echo $f | grep -b -o "-"`; 
  #start=`echo ${start/":-"/}`; 
  #fin=`echo $f | grep -b -o ".txt"`; 
  #fin=`echo ${fin/":.txt"/}`; 
  #id=`echo $f | cut -c$((start+2))-$fin`; 
  #if [ ${#id} -eq 3 ]; then
  #  id=0$id;
  #else
  #  if [ ${#id} -ne 4]; then
  #    echo "***Invalid id $id. Skipping***";
  #    continue;
  #  fi
  #fi 
done

rm faceslist.txt
for f in `ls /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/Matching/*txt`; do 
  found=`grep $f facesout.txt | wc -l`
  if [ $found -eq 0 ]; then
    echo $f >> faceslist.txt
  fi
done

rm fnlist.txt
for f in `ls /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/NameGame/*txt`; do 
  found=`grep $f fnout.txt | wc -l`
  if [ $found -eq 0 ]; then
    echo $f >> fnlist.txt
  fi
done

rm MIDlist.txt
for f in `ls /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/QuickStrike/*txt`; do 
  found=`grep $f MIDout.txt | wc -l`
  if [ $found -eq 0 ]; then
    echo $f >> MIDlist.txt
  fi
done

#find /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/Colors/*txt -mtime -$nDays > colorslist.txt
#find /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/Matching/*txt -mtime -$nDays > faceslist.txt
#find /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/NameGame/*txt -mtime -$nDays > fnlist.txt
#find /home/ark19/linux/experiments/DBIS.01/Data/Behavioral/QuickStrike/*txt -mtime -$nDays > MIDlist.txt

perl getFacenameEprime_batch.pl fnlist.txt fnout.txt
perl getFacesEprime_batch.pl faceslist.txt facesout.txt
perl getMIDEprime_batch.pl MIDlist.txt MIDout.txt
perl getStroopEprime_batch.pl colorslist.txt colorsout.txt

