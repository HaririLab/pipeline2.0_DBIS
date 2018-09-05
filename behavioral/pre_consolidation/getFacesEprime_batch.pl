#!usr/bin/perl

# getFacesEprime_batch.pl
#
# This script takes in a list of eprime output files as a text file, reads them, calculates accuracy and response time (per block), 
#  and writes the output to the specified file, one subject per line
#
# Usage:  perl getFacesEprime_batch.pl infile.txt outfile.txt
# Input: infile.txt = list of files to parse - does not work if the file name list is generated in excel!
#  instead use "find /Volumes/Hariri/DNS.01/Data/Behavioral/Faces" (e.g. for Mac) on command line to list full path of the 
#  directory's contents and paste those to a text file
# Assumptions:
#   -The DNS id appears in the file name between to hyphens, eg in HaririFaces2_revise12-407-1.txt, the ID is 407
#   -6 trials per block
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#   -I should add a catch for being unable to open a file (currently dies) and for any response count = 0 (currently skips subject)
#
# Annchen Knodt 12/17/2011
# 4/16/14 - added RT calc for just correct trials (ARK)
# 5/4/17: changed file open to >> so the out file will contain all data

# global variables
my $nShapesTrials = 30; 
my $nExpTrials = 6;		# Same for each expression
my $nFacesTrials = 24;		# including all expressions

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: getFacesEprime_batch.pl infile.txt outfile.txt\n";
  print "\tinfile = text file containing list of ePrime files to parse (one per line)\n";
  print "\toutfile = desired name for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outfile = $ARGV[1];

open LIST, "<$infile" or die "could not open $infile";
open OUT, ">>$outfile" or die "could not open $outfile";
open OUTF, ">failedFiles.txt" or die "could not open failedFiles.txt";

print "\n***Running getFacesEprime_batch.pl***\nSee failedFiles.txt for list of unreadable files.\nAlso see comments in the script if you need help.\n\n";

# print header to output file
#print OUT "ID from file name\tID from file\tOrder#\tFaces accuracy\tFaces avg RT - all trials\tFaces avg RT - correct trials\tShapes accuracy\tShapes avg RT - all trials\tShapes avg RT - correct trials\tAnger accuracy\tAnger avg RT - all trials\tAnger avg RT - correct trials\tFear accuracy\tFear avg RT - all trials\tFear avg RT - correct trials\tNeutral accuracy\tNeutral avg RT - all trials\tNeutral avg RT - correct trials\tSurprise accuracy\tSurprise avg RT - all trials\tSurprise avg RT - correct trials\tFile name\n";

# read file list line-by-line
while (my $file = <LIST>) {    
  chomp($file);
  print "Reading file: $file\n";
  $file =~ /-(\d+)-/;
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
    if (!$headerline=~m/Header Start/) { # Still can't read the file
      print "\tBlast! Could not read file $file in original or utf-8 format.  Adding this to failedFiles.txt.\n";
      $converted = 2;
      print OUTF "$file could not be read even after converting to utf-8 format\n";
    }
  }

  if ($converted!=2) {

      my @RTsum=(0,0,0,0,0);
      my @RTsum_correct=(0,0,0,0,0);
      my @respCt=(0,0,0,0,0);
      my @accSum=(0,0,0,0,0);
      my $ACC=0; ##???
      my $order=0;
      my $date="";
      my $time="";
      my $condition; # 0=shapes 1=anger 2=fear 3=neutral 4=surprise

    while (my $line = <IN>) {

      chomp($line);
      if ($line=~ m/Subject:/) { 
		$subj = $';
		$subj =~ s/\D//g;
      } if ($line=~ m/ListChoice: (\d)/) { 
		$order = $1;
      } elsif ($line=~ m/SessionDate: /){
        $date = $';
        $date =~ s/\s//g;
      } elsif ($line=~ m/SessionTime: /){
        $time = $';
        $time =~ s/\s//g;
      } elsif ($line=~ m/ShapesTrialProbe.ACC/) { # in Shapes
		$ACC = $';
		$ACC =~ s/\D//g;
		$accSum[0]+=$ACC;
      } elsif ($line=~ m/ShapesTrialProbe.RT:/) { # in Shapes
		$RT = $';
		$RT =~ s/\D//g;
		$RTsum[0]+=$RT;
		if ($RT!=0) {
		  $respCt[0]++;
		}
		if ($ACC==1) { # we can do this bc the ACC line comes before the RT line
		$RTsum_correct[0]+=$RT;
		}
      } elsif ($line=~ m/SubStimulus: img\/([fans])/) { # in faces

	 my $firstletter = $1;
	 if ( $firstletter eq "a"){
	   $condition=1;
	 } elsif( $firstletter eq "f"){
	   $condition=2;
	 } elsif( $firstletter eq "n"){
	   $condition=3;
	 } elsif( $firstletter eq "s"){
	   	   $condition=4;
	 } 

      } elsif ($line=~m/FacesProcProbe.ACC:/) {
		$ACC = $';
		$ACC =~ s/\D//g;
		$accSum[$condition]+=$ACC;
      } elsif ($line=~ m/FacesProcProbe.RT:/) {
		$RT = $';
		$RT =~ s/\D//g;
		$RTsum[$condition]+=$RT;
		if ($RT!=0) {
		  $respCt[$condition]++;
		}
		if ($ACC==1) { # we can do this bc the ACC line comes before the RT line
		$RTsum_correct[$condition]+=$RT;
		} 	
      } elsif ($line==EOF) {	## end of file
      } else {
		print "Invalid line:\n $line";
      }
    }

    # if ($respCt[0]==0 || $respCt[1]==0 || $respCt[2]==0 || $respCt[3]==0 || $respCt[4]==0 || $accSum[0]==0 || $accSum[1]==0 || $accSum[2]==0 || $accSum[3]==0 || $accSum[4]==0) { # nonresponder
      # print "\tBlast! Could not read $file properly or subject did not respond at all for one or more trial types. Needs further investigation.\n";
      # print OUTF "$file one or more trial types' response counts is equal to 0: $respCt[0] $respCt[1] $respCt[2] $respCt[3] $respCt[4] \n";
    # } else {
	
	my $avgFacesRT = $avgShapesRT  = $avgFearRT = $avgAngerRT = $avgNeutralRT = $avgSurpriseRT = 0;
    if ( ($respCt[1]+$respCt[2]+$respCt[3]+$respCt[4])!=0 ){ $avgFacesRT = ($RTsum[1]+$RTsum[2]+$RTsum[3]+$RTsum[4])/($respCt[1]+$respCt[2]+$respCt[3]+$respCt[4]); }
	if ( $respCt[0]!=0 ) { $avgShapesRT = $RTsum[0]/$respCt[0]; }
	if ( $respCt[1]!=0 ) { $avgAngerRT = $RTsum[1]/$respCt[1]; }
	if ( $respCt[2]!=0 ) { $avgFearRT = $RTsum[2]/$respCt[2]; }
	if ( $respCt[3]!=0 ) { $avgNeutralRT = $RTsum[3]/$respCt[3]; }
	if ( $respCt[4]!=0 ) { $avgSurpriseRT = $RTsum[4]/$respCt[4]; }

    my $avgFacesAcc = ($accSum[1]+$accSum[2]+$accSum[3]+$accSum[4])/$nFacesTrials;
    my $avgShapesAcc = $accSum[0]/$nShapesTrials;
    my $avgFearAcc = $accSum[2]/$nExpTrials;
    my $avgAngerAcc = $accSum[1]/$nExpTrials;
    my $avgNeutralAcc = $accSum[3]/$nExpTrials;
    my $avgSurpriseAcc = $accSum[4]/$nExpTrials;

	my $avgFacesRT_correct = $avgShapesRT_correct  = $avgFearRT_correct = $avgAngerRT_correct = $avgNeutralRT_correct = $avgSurpriseRT_correct = 0;
	if ( ($accSum[1]+$accSum[2]+$accSum[3]+$accSum[4])!=0 ) { $avgFacesRT_correct = ($RTsum_correct[1]+$RTsum_correct[2]+$RTsum_correct[3]+$RTsum[4])/($accSum[1]+$accSum[2]+$accSum[3]+$accSum[4]); }
    if ( $accSum[0]!=0 ) { $avgShapesRT_correct = $RTsum_correct[0]/$accSum[0]; }
    if ( $accSum[1]!=0 ) { $avgAngerRT_correct = $RTsum_correct[1]/$accSum[1]; }
    if ( $accSum[2]!=0 ) { $avgFearRT_correct = $RTsum_correct[2]/$accSum[2]; }
    if ( $accSum[3]!=0 ) { $avgNeutralRT_correct = $RTsum_correct[3]/$accSum[3]; }
    if ( $accSum[4]!=0 ) { $avgSurpriseRT_correct = $RTsum_correct[4]/$accSum[4]; }
	
      print OUT "$ID\t$subj\t$date\t$time\t$order\t$avgFacesAcc\t$avgFacesRT\t$avgFacesRT_correct\t$avgShapesAcc\t$avgShapesRT\t$avgShapesRT_correct\t$avgAngerAcc\t$avgAngerRT\t$avgAngerRT_correct\t$avgFearAcc\t$avgFearRT\t$avgFearRT_correct\t$avgNeutralAcc\t$avgNeutralRT\t$avgNeutralRT_correct\t$avgSurpriseAcc\t$avgSurpriseRT\t$avgSurpriseRT_correct\t$file\n";
    # }
    if ($converted==1) {
      `rm -f curfile.txt`;
    }
	
  } # end if successfully read file
} # end while loop through lines

print "Done!\n\n";
	
