#!usr/bin/perl

# getFacesEprime.pl
#
# This script takes in an eprime output text file, reads it, calculates accuracy and response time (per block), 
#  and writes the output to ResponseData.txt in the specified output directory
#
# Usage:  perl getFacesEprime.pl infile.txt outdir
# Input: infile.txt = eprime text file
# Assumptions:
#   -The DMHDS id appears in the file name between a "-" and ".txt" as in Matching-205.txt, where the ID is 205
#   -6 trials per block
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#
# Annchen Knodt 12/17/2011
# 4/16/14 - added RT calc for just correct trials (ARK)

# global variables
my $nShapesTrials = 30; 
my $nExpTrials = 6;		# Same for each expression
my $nFacesTrials = 24;		# including all expressions

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: getFacesEprime_batch.pl infile.txt outfile.txt\n";
  print "\tinfile = name of ePrime file to parse\n";
  print "\toutdir = desired directory for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outdir = $ARGV[1];

open LIST, "<$infile" or die "could not open $infile";
open OUT, ">$outdir/ResponseData.txt" or die "could not open $outdir/ResponseData.txt";

print "Reading file: $infile\n";
$infile =~ /-(\d+).txt/;
my $ID = $1; # ID from file name
my $subj = ""; # ID from file

open IN, "<$infile" or die "could not open $infile";
my $converted = 0;		# 0 for no, 1 for yes, 2 for fail
my $headerline = <IN>;
if ($headerline=~m/Header Start/) { # looks like we can read this file, procede without converting
	$converted = 0;
} else {	       # can't read the file correctly, try converting
	`iconv -f utf-16 -t utf-8 $infile > $outdir/converted.txt`; # convert to utf-8 format
	open IN, "$outdir/converted.txt" or die "could not open $outdir/converted.txt"; # use this line to run with the converted file   
	$converted = 1;
	$headerline = <IN>;
	if (!$headerline=~m/Header Start/) { # Still can't read the file
	  print "\tBlast! Could not read file $infile in original or utf-8 format.  Adding this to failedFiles.txt.\n";
	  $converted = 2;
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

  # read input file line by line
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
  
  my $DMHDSID = sprintf("DMHDS%04s", $ID);
  # print header to output file
  # print OUT "DMHDSID\tIDfromFileName\tIDfromFile\tdate\ttime\tOrder\tFacesAccuracy\tFacesAvgRT_allTrials\tFacesAvgRT_correctTrials\tShapesAccuracy\tShapesAvgRT_allTrials\tShapesAvgRT_correctTrials\tAngerAccuracy\tAngerAvgRT_allTrials\tAngerAvgRT_correctTrials\tFearAccuracy\tFearAvgRTallTrials\tFearAvgRT_correctTrials\tNeutralAccuracy\tNeutralAvgRT_allTrials\tNeutralAvgRT_correctTrials\tSurpriseAccuracy\tSurpriseAvgRT_allTrials\tSurpriseAvgRT_correctTrials\tFileName\n";
  # print OUT "$DMHDSID\t$ID\t$subj\t$date\t$time\t$order\t$avgFacesAcc\t$avgFacesRT\t$avgFacesRT_correct\t$avgShapesAcc\t$avgShapesRT\t$avgShapesRT_correct\t$avgAngerAcc\t$avgAngerRT\t$avgAngerRT_correct\t$avgFearAcc\t$avgFearRT\t$avgFearRT_correct\t$avgNeutralAcc\t$avgNeutralRT\t$avgNeutralRT_correct\t$avgSurpriseAcc\t$avgSurpriseRT\t$avgSurpriseRT_correct\t$infile\n";

  print OUT "DMHDSID: $DMHDSID\nIDfromFileName: $ID\nIDfromFile: $subj\ndate: $date\ntime: $time\nOrder: $order\nFacesAccuracy: $avgFacesAcc\nFacesAvgRT_allTrials: $avgFacesRT\nFacesAvgRT_correctTrials: $avgFacesRT_correct\nShapesAccuracy: $avgShapesAcc\nShapesAvgRT_allTrials: $avgShapesRT\nShapesAvgRT_correctTrials: $avgShapesRT_correct\n";
  print OUT "nAngerAccuracy: $avgAngerAcc\nAngerAvgRT_allTrials: $avgAngerRT\nAngerAvgRT_correctTrials: $avgAngerRT_correct\nFearAccuracy: $avgFearAcc\nFearAvgRTallTrials: $avgFearRT\nFearAvgRT_correctTrials: $avgFearRT_correct\nNeutralAccuracy: $avgNeutralAcc\nNeutralAvgRT_allTrials: $avgNeutralRT\nNeutralAvgRT_correctTrials: $avgNeutralRT_correct\nSurpriseAccuracy: $avgSurpriseAcc\nSurpriseAvgRT_allTrials: $avgSurpriseRT\nSurpriseAvgRT_correctTrials: $avgSurpriseRT_correct\nFileName: $infile\n";

  if ($converted==1) {
  `rm -f $outdir/converted.txt`;
  }

} # end if successfully read file

print "Done!\n\n";
	
