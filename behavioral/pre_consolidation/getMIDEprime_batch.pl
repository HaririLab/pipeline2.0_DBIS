#!usr/bin/perl

# getMIDEprime_batch.pl
#
# This script takes in a list of eprime output files as a text file, reads them, calculates accuracy, response time, 
#   and many other ratios/stats (overall and per block and condition) and writes the tab-delimited output to the specified file, one subject per line
#
# Usage:  perl getMIDEprime_batch.pl infile.txt outfile.txt
# Input: infile.txt = list of files to parse - does not work if the file name list is generated in excel!
#  instead use "find /Volumes/Hariri/DNS.01/Data/Behavioral/Cards" (e.g. for Mac) on command line to list full path of the 
#  directory's contents and paste those to a text file
# Assumptions:
#   -12 trials per condition
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#
# Annchen Knodt 12/22/2015
# 9/5/16: removed trigger lines (Dunedin scanner triggers at start of paradigm rather than disdaq)
# 5/4/17: changed file open to >> so the out file will contain all data

#use warnings;

# global variables 
my $nTrials = 12;		# same for each condition

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: perl getMIDEprime_batch.pl infile.txt outfile.txt\n";
  print "\tinfile = text file containing list of ePrime files to parse (one per line)\n";
  print "\toutfile = desired name for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outfile = $ARGV[1];

open LIST, "<$infile" or die "could not open $infile";
open OUT, ">>$outfile" or die "could not open $outfile";
open OUTF, ">failedFiles.txt" or die "could not open failedFiles.txt";

print "\n***Running getMIDEprime_batch.pl***\nSee failedFiles.txt for list of unreadable files.\nAlso see comments in the script if you need help.\n\n";

# print header to output file
#print OUT "\n";
#print OUT "\n";

# read file list line-by-line
while (my $file = <LIST>) {    
  chomp($file);
  print "Reading file: $file\n";
  $file =~ /-(\d+).txt/;
  my $ID = $1; # ID from file name
  my $subj = ""; # ID from file

  open IN, "<$file" or die "could not open $file";  
  my $converted = 0;		# 0 for no, 1 for yes, 2 for fail
  my $headerline = <IN>;
  if ($headerline=~m/Header Start/) { # looks like we can read this file, procede without converting
    $converted = 0;
  } else {	       # can't read the file correctly, try converting
    `iconv -f utf-16 -t utf-8 $file > curfile.txt`; # convert to utf-8 format
    open IN, "curfile.txt" or die "could not open curfile.txt"; # use this line to run with the converted file   
    $converted = 1;
    $headerline = <IN>;
    if (!$headerline=~m/Header Start/) { # still can't read the file
      print "\tBlast! Could not read file $file in original or utf-8 format. Adding this to failedFiles.txt.\n";
      $converted = 2;
      print OUTF "$file could not be read even after converting to utf-8 format\n";
    }
  }

  
	if (length($ID)==3){
		$ID = "0$ID";
	}  
  #`mkdir ../../Analysis/SPM/Processed/DMHDS$ID`;
  # open OUT2, ">../../Analysis/SPM/Processed/DMHDS$ID/MIDeprime_$ID.txt" or die "could not open MIDeprime_$ID.txt";

  # initialize variables for this subject
  my $RTsum0 = $RTsum1 = $RTsum5 = 0;
  my $earlyCt0 = $earlyCt1 = $earlyCt5 = 0;
  my $lateCt0 = $lateCt1 = $lateCt5 = 0;
  my $total = 0;
  # variables to keep track of how man times the subject saw each type of feedback in each block
  my @cueOnsets0 = @cueOnsets1 = @cueOnsets5;
  my @delayOnsets0 = @delayOnsets1 = @delayOnsets5;
  my @fbOnsets0 = @fbOnsets1 = @fbOnsets5;
  my @delayDurations0 = @delayDurations1 = @delayDurations5;
  my @accuracy0 = @accuracy1 = @accuracy5;
 
  my $date="";
  my $time="";
  my $initTargetDur="";  

  if ($converted!=2) { # go ahead and parse the file
    my $blockNum = 0;	       # to keep track of which block (out of win/loss blocks) we're in
	my $inDummy = 0;		# to keep track of whether we are in the first two dummy blocks
    my $condition = ""; 
    while (my $line = <IN>) {
      chomp($line);

      if ($line=~ m/Subject:/) { 
		$subj = $';
		$subj =~ s/\D//g;
      } elsif ($line=~ m/SessionDate: /){
        $date = $';
        $date =~ s/\s//g;
      } elsif ($line=~ m/SessionTime: /){
        $time = $';
        $time =~ s/\s//g;
      } elsif ($line=~ m/InitTargetDuration: /){
	$initTargetDur=$';
	$initTargetDur =~ s/\D//g;
	}

      if ($line=~ m/Procedure:/) {   
		if ($line=~ m/Dummy/) {   
			$inDummy = 1;
		} else {
			$inDummy = 0;
		}
      } 
	  
	  if($inDummy == 0){
	  
		  if ($line=~ m/Cue: \$0/) { # in $0 trial
		$condition='$0';
		  }
		  elsif ($line=~ m/Cue: \$1/) { # in $1 trial
		$condition='$1';
		  }
		  elsif ($line=~ m/Cue: \$5/) { # in $5 trial
		$condition='$5';
		  }
		  elsif ($line=~ m/Display.OnsetTime:/) {
			my $onset = $';
			$onset =~ s/\D//g;
			  if ($condition eq '$0') { 
				push @cueOnsets0, $onset;
			  } elsif ($condition eq '$1') { 
				push @cueOnsets1, $onset;
			  } elsif ($condition eq '$5') { 
				push @cueOnsets5, $onset;
			  } else {
				print "Unknown cue condition: $condition\n";
			  }					
		  } 
		  elsif ($line=~ m/Fixation.OnsetTime:/) {
			my $onset = $';
			$onset =~ s/\D//g;
			  if ($condition eq '$0') { 
				push @delayOnsets0, $onset;
			  } elsif ($condition eq '$1') { 
				push @delayOnsets1, $onset;
			  } elsif ($condition eq '$5') { 
				push @delayOnsets5, $onset;
			  } else {
				print "Unknown condition: $condition\n";
			  }					
		  }
		  elsif ($line=~ m/Fixation.Duration:/) {
			my $duration = $';
			$duration =~ s/\D//g;
			  if ($condition eq '$0') { 
				push @delayDurations0, $duration;
			  } elsif ($condition eq '$1') { 
				push @delayDurations1, $duration;
			  } elsif ($condition eq '$5') { 
				push @delayDurations5, $duration;
			  } else {
				print "Unknown condition: $condition\n";
			  }					
		  }
		  elsif ($line=~ m/Fixation.RT:/) {
			my $RT = $';
			$RT =~ s/\D//g;
			if ($RT>0) {
			  if ($condition eq '$0') { 
				$earlyCt0++;
			  } elsif ($condition eq '$1') { 
				$earlyCt1++;
			  } elsif ($condition eq '$5') { 
				$earlyCt5++;
			  } else {
				print "Unknown condition: $condition\n";
			  }	
			}				
		  }
		  elsif ($line=~ m/Feedback:/) {
			my $feedback = $';
			$feedback =~ s/\s//g;
			# print "***" . $feedback . "***\n";
			my $acc = 0;
			if ($feedback eq 'HIT') {
				$acc = 1;
			}
			  if ($condition eq '$0') { 
				push @accuracy0, $acc;
			  } elsif ($condition eq '$1') { 
				push @accuracy1, $acc;
			  } elsif ($condition eq '$5') { 
				push @accuracy5, $acc;
			  } else {
				print "Unknown acc condition: $condition\n";
			  }					
		  }
		 elsif ($line=~ m/Target.RT:/) {
			my $RT = $';
			$RT =~ s/\D//g;
			  if ($condition eq '$0') { 
				$RTsum0+=$RT;
			  } elsif ($condition eq '$1') { 
				$RTsum1+=$RT;
			  } elsif ($condition eq '$5') { 
				$RTsum5+=$RT;
			  } else {
				print "Unknown acc condition: $condition\n";
			  }					
		  }
		 elsif ($line=~ m/Pause.RT:/) {
			my $RT = $';
			$RT =~ s/\D//g;
			if ($RT>0){
			  if ($condition eq '$0') { 
				$lateCt0++;
			  } elsif ($condition eq '$1') { 
				$lateCt1++;
			  } elsif ($condition eq '$5') { 
				$lateCt5++;
			  } else {
				print "Unknown pause condition: $condition\n";
			  }
			}					
		  }
		  elsif ($line=~ m/Feedback.OnsetTime:/) {
			my $onset = $';
			$onset =~ s/\D//g;
			  if ($condition eq '$0') { 
				push @fbOnsets0, $onset;
			  } elsif ($condition eq '$1') { 
				push @fbOnsets1, $onset;
			  } elsif ($condition eq '$5') { 
				push @fbOnsets5, $onset;
			  } else {
				print "Unknown fb condition: $condition\n";
			  }					
		  }
		  elsif ($line=~ m/CumulativeTotal:/) { # trigger time is at end of file
			$total = $';
			$total =~ s/\D//g;
		  } 
		  elsif ($line==EOF) {	## end of file
		  } else { # This doesn't make logical sense to me, but somehow it works...
			print "Invalid line:\n $line";
		  }
		}
    } #end while loop through lines

      # print "@cueOnsets0\n@cueOnsets1\n@cueOnsets5\n";
      # my $tot =  (eval join '+', @accuracy0);
      # print "tot $tot\n";

    my $totCueCt = $#cueOnsets0 + $#cueOnsets1 + $#cueOnsets5 + 3; # $# gives index of last array element
    if ($totCueCt!=36) {
      print "\tBlast! Could only read $totCueCt/36 trials. Adding file $file to failedFiles.txt.\n";
      print OUTF "$file only read $totCueCt/36 trials\n";      
    } 
    else {  # calculate the stats, being careful not to divide by 0

	
      my $acc0 = (eval join '+', @accuracy0) / $nTrials;
      my $acc1 = (eval join '+', @accuracy1) / $nTrials;
      my $acc5 = (eval join '+', @accuracy5) / $nTrials;
      my $accALL = ($acc0+$acc1+$acc5)/3;

	  my $avgRT0 = $avgRT1 = $avgRT5 = 0;
	  if($acc0 != 0 ){
		$avgRT0 = $RTsum0 / (eval join '+', @accuracy0);
	  }
	  if($acc1 != 0 ){
		$avgRT1 = $RTsum1 / (eval join '+', @accuracy1);
	  }
	  if($acc5 != 0 ){
		$avgRT5 = $RTsum5 / (eval join '+', @accuracy5);
	  }

      print OUT join("\t", $ID,$subj,$file,$date,$time,$initTargetDur,$total,$accALL,$earlyCt0,$earlyCt1,$earlyCt5,$lateCt0,$lateCt1,$lateCt5,$acc0,$acc1,$acc5,$avgRT0,$avgRT1,$avgRT5," "), "\n";      

	  # my $startTime = $cueOnsets1[0] - 4000; # first actual ITI is 4 seconds, so subtract that from first actual trial (which is a $1 cue) to get start time
	  # @cueOnsets0 = map { $_ - $startTime } @cueOnsets0; 
      # @cueOnsets1 = map { $_ - $startTime } @cueOnsets1;
      # @cueOnsets5 = map { $_ - $startTime } @cueOnsets5;
      # @delayOnsets0 = map { $_ - $startTime } @delayOnsets0;
      # @delayOnsets1 = map { $_ - $startTime } @delayOnsets1;
      # @delayOnsets5 = map { $_ - $startTime } @delayOnsets5;
      # @fbOnsets0 = map { $_ - $startTime } @fbOnsets0;
      # @fbOnsets1 = map { $_ - $startTime } @fbOnsets1;
      # @fbOnsets5 = map { $_ - $startTime } @fbOnsets5;
      # for($i=0;$i<=$#cueOnsets0;$i++){ 
	# print OUT2 "$cueOnsets0[$i]\t$delayOnsets0[$i]\t$delayDurations0[$i]\t$fbOnsets0[$i]\t$accuracy0[$i]\n";
      # }
      # for($i=0;$i<=$#cueOnsets1;$i++){ 
	# print OUT2 "$cueOnsets1[$i]\t$delayOnsets1[$i]\t$delayDurations1[$i]\t$fbOnsets1[$i]\t$accuracy1[$i]\n";
      # }
      # for($i=0;$i<=$#cueOnsets5;$i++){ 
	# print OUT2 "$cueOnsets5[$i]\t$delayOnsets5[$i]\t$delayDurations5[$i]\t$fbOnsets5[$i]\t$accuracy5[$i]\n";
      # }

    }

    if ($converted==1) {
      `rm -f curfile.txt`;
    }

    reset 'c'; reset 'f'; reset 'd'; reset 'a';

  } # end if successfully read file

}

print "Done!\n\n";
	
