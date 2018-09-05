#!usr/bin/perl

# getFacenameEprime_batch.pl
#
# This script takes in a list of eprime output files as a text file, reads them, calculates accuracy and response time (per block), 
#  and writes the output to the specified file, one subject per line
#
# Usage:  perl getFacenameEprime_batch.pl infile.txt outfile.txt
# Input: infile.txt = list of files to parse - does not work if the file name list is generated in excel!
#  instead use "find /Volumes/Hariri/Takeda.01/Data/Behavioral/Eprime\ Response\ Data/FaceRecog/*.txt" (e.g. for Mac) on command line to list full path of the 
#  directory's contents and paste those to a text file
# Assumptions:
#   -The patient id appears in the file name between to hyphens, followed by the session number, eg in HaririFaces2_revise12-407-1.txt, the ID is 407-1
#   -6 trials per block
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#   -Total average RT is calc'd by summing the RTs across all of the blocks and then dividing by the number of responses acorss all of the blocks (rather than calc'ing for each block and then taking the average of those)
#
# Annchen Knodt 1/13/2012
# 5/4/17: changed file open to >> so the out file will contain all data

# global variables
my $nTrials = 24; # same for distractor and facename trials, n trials / block hard coded as 6

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: getFacenameEprime_batch.pl infile.txt outfile.txt\n";
  print "\tinfile = text file containing list of ePrime files to parse (one per line)\n";
  print "\toutfile = desired name for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outfile = $ARGV[1];

open LIST, "<$infile" or die "could not open $infile";
open OUT, ">>$outfile" or die "could not open $outfile";
open OUTF, ">failedFiles.txt" or die "could not open failedFiles.txt";

print "\n***Running getFacenameEprime_batch.pl***\nSee failedFiles.txt for list of unreadable files.\nAlso see comments in the script if you need help.\n\n";
# print header to output file
#print OUT "ID from file name\tID from file\tFacename accuracy\tFacename avg RT\tDistractor accuracy\tDistractor avg RT\tFacename1 accuracy\tFacename2 accuracy\tFacename3 accuracy\tFacename4 accuracy\tFacename1 avg RT\tFacename2 avg RT\tFacename3 avg RT\tFacename4 avg RT\tFacename1 respCt\tFacename2 respCt\tFacename3 respCt\tFacename4 respCt\tFile name\n";

# read file list line-by-line
while (my $file = <LIST>) {    
  chomp($file);
  print "Reading file: $file\n";
  $file =~ /Recog-(\d+-\d+)/;
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
  if ($converted!=2) {
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
    print OUT join("\t", $ID,$subj,$date,$time,$avgFnAcc,$avgFnRT,$avgDisAcc,$avgDisRT,@avgFnAccBlock,@avgFnRTblock,@fnRespCtBlock,$file," "),"\n";

    if ($converted==1) {
      `rm -f curfile.txt`;
    }
  }
}

print "Done!\n\n"
	
