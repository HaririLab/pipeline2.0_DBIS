#!usr/bin/perl

# getFacenameEprime.pl
#
# This script takes in an eprime output text file, reads it, calculates accuracy and response time (per block), 
#  and writes the output to ResponseData.txt in the specified output directory
#
# Usage:  perl getFacenameEprime.pl infile.txt outdir
# Input: infile.txt = eprime text file
# Assumptions:
#   -The DMHDS id appears in the file name between a "-" and ".txt" as in Matching-205.txt, where the ID is 205
#   -4 blocks of 6 trials
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#
# Annchen Knodt 1/13/2012

# global variables
my $nTrials = 24; # same for distractor and facename trials, n trials / block hard coded as 6

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: getFacenameEprime_batch.pl infile.txt outfile.txt\n";
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

  # initialize variables for this subject
  my $distractorRTsum = $facenameRTsum = 0;
  my $distractorRespCt = $facenameRespCt = 0;
  my $distractorAccSum = $facenameAccSum = 0;
  my @fnRTsumBlock = (0,0,0,0); # one entry for each block
  my @fnRespCtBlock = (0,0,0,0); # one entry for each block
  my @fnAccSumBlock = (0,0,0,0); # one entry for each block

  my $blockNum=-1;
  my $index=0;
  my $date="";
  my $time="";

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
      } elsif ($line=~ m/InstructProc/){
	$blockNum++;
	if($blockNum<3){$index=0}elsif($blockNum<6){$index=1}elsif($blockNum<9){$index=2}else{$index=3} #couldn't find an easy way
      } elsif ($line=~ m/DistractorSlide.ACC/) { # in Distractor
	$ACC = $';
	$ACC =~ s/\D//g;
	$distractorAccSum+=$ACC;
      } elsif ($line=~ m/DistractorSlide.RT:/) { # in Distractor
	$RT = $';
	$RT =~ s/\D//g;
	$distractorRTsum+=$RT;
	if ($RT!=0) {
	  $distractorRespCt++;
	}
      } elsif ($line=~ m/RecallSlide2.ACC/) { # in facename recall
	$ACC = $';
	$ACC =~ s/\D//g;
	$fnAccSumBlock[$index]+=$ACC;
      } elsif ($line=~ m/RecallSlide2.RT:/) { # in facename recall
	$RT = $';
	$RT =~ s/\D//g;
	$fnRTsumBlock[$index]+=$RT;
	if ($RT!=0) {
	  $fnRespCtBlock[$index]++;
	}
      } elsif ($line==EOF) {	## end of file
      } else { # This doesn't make logical sense to me, but somehow it works...
	print "Invalid line:\n $line";
      }
    }
    my $totFnRespCt = $fnRespCtBlock[0]+$fnRespCtBlock[1]+$fnRespCtBlock[2]+$fnRespCtBlock[3]; 

    my $totFnRTsum = $fnRTsumBlock[0]+$fnRTsumBlock[1]+$fnRTsumBlock[2]+$fnRTsumBlock[3]; 
    my $totFnAccSum = $fnAccSumBlock[0]+$fnAccSumBlock[1]+$fnAccSumBlock[2]+$fnAccSumBlock[3]; 
    my $avgFnRT = 0;
    if($totFnRespCt!=0) {$avgFnRT=$totFnRTsum/$totFnRespCt;}
    my $avgFnAcc = $totFnAccSum/$nTrials;
    my $avgDisRT = 0;
    if($distractorRespCt!=0) {$avgDisRT=$distractorRTsum/$distractorRespCt;}
    my $avgDisAcc = $distractorAccSum/$nTrials;
    my @avgFnRTblock = (0,0,0,0);
    for(my $i=0; $i<4; $i++){ if($fnRespCtBlock[$i]!=0) { $avgFnRTblock[$i]=$fnRTsumBlock[$i]/$fnRespCtBlock[$i];}  }
    my @avgFnAccBlock = ($fnAccSumBlock[0]/6,$fnAccSumBlock[1]/6,$fnAccSumBlock[2]/6,$fnAccSumBlock[3]/6);  

	my $DMHDSID = sprintf("DMHDS%04s", $ID);

   print OUT "DMHDSID: $DMHDSID\nIDfromFileName: $ID\nIDfromFile: $subj\ndate: $date\ntime: $time\nFacenameAccuracy: $avgFnAcc\nFacenameAvgRT: $avgFnRT\nDistractorAccuracy: $avgDisAcc\nDistractorAvgRT: $avgDisRT\nFacename1accuracy: $avgFnAccBlock[0]\nFacename2accuracy: $avgFnAccBlock[1]\nFacename3accuracy: $avgFnAccBlock[2]\nFacename4accuracy: $avgFnAccBlock[3]\n";
   print OUT "Facename1avgRT: $avgFnRTblock[0]\nFacename2avgRT: $avgFnRTblock[1]\nFacename3avgRT: $avgFnRTblock[2]\nFacename4avgRT: $avgFnRTblock[3]\nFacename1respCt: $fnRespCtBlock[0]\nFacename2respCt: $fnRespCtBlock[1]\nFacename3respCt: $fnRespCtBlock[2]\nFacename4respCt: $fnRespCtBlock[3]\nFileName: $infile\n";

    if ($converted==1) {
      `rm -f $outdir/converted.txt`;
    }
}

print "Done!\n\n"
	
