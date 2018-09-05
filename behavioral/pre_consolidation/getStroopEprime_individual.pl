#!usr/bin/perl

# getStroopEprime_batch.pl
#
# This script takes in a single eprime output text file, parses it, and prints out onset times in accuracy to be read
# by MATLAB during first level processing
#
# Usage:  perl getStroopEprime_individual.pl infile.txt outdir
# Input: infile.txt = name of individual ePrime text file to parse
# Assumptions:
#   -The strings "TrialDisplay.ACC:" and "TrialDisplay.RT:" only appear once during each trial, in that order
#   -12 trials per block, 6 blocks
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#
# Annchen Knodt 12/17/2011, adapted from getCardsEprime in Aug 2016
# 9/5/16: removed trigger lines (Dunedin scanner triggers at start of paradigm rather than disdaq)
# 10/11/16: adapted to be run individually from BOLD processing pipeline

#use warnings;

# global variables 
my $nTrials = 72;		# total trials, i.e. both conditions
my @con1 = (0..11); # trial indices of congruent block 1
my @con2 = (24..35); # trial indices of congruent block 2
my @con3 = (48..59); # trial indices of congruent block 3
my @incon1 = (12..23); # trial indices of incongruent block1
my @incon2 = (36..47); # trial indices of incongruent block2
my @incon3 = (60..71); # trial indices of incongruent block3

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: perl getStroopEprime_batch.pl infile.txt outdir\n";
  print "\tinfile = name of individual ePrime text file to parse\n";
  print "\toutdir = desired dir to send output files, will produce Stroop_acc.txt and Stroop_onset.txt in that dir\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outdir = $ARGV[1];

open OUTACC, ">$outdir/Stroop_acc.txt" or die "could not open >$outdir/Stroop_acc.txt";
open OUTONSET, ">$outdir/Stroop_onsets.txt" or die "could not open >$outdir/Stroop_onsets.txt";
open IN, "<$infile" or die "could not open $infile";  

print "\n***Running getStroopEprime_individual.pl***\n";

# read file list line-by-line
$infile =~ /-(\d+)-/;
my $ID = $1; # ID from file name

my $converted = 0;		# 0 for no, 1 for yes, 2 for fail
my $headerline = <IN>;
if ($headerline=~m/Header Start/) { # looks like we can read this file, procede without converting
$converted = 0;
} else {	       # can't read the file correctly, try converting
`iconv -f utf-16 -t utf-8 $infile > $outdir/curfile.txt`; # convert to utf-8 format
open IN, "$outdir/curfile.txt" or die "could not open $outdir/curfile.txt"; # use this line to run with the converted file   
$converted = 1;
$headerline = <IN>;
if (!$headerline=~m/Header Start/) { # still can't read the file
  print "\tBlast! Could not read file $infile in original or utf-8 format.\n";
  $converted = 2;
}
}


if ($converted!=2) { # go ahead and parse the file

# initialize variables for this subject
my @correct = (0) x $nTrials; # whether each trial was correct (1) or not (0)
my @RT = (0) x $nTrials; # RT for each trial
my @onsets = (0) x $nTrials; # RT for each trial
my $subj = ""; # ID from file
my $trialNum = 0;	       # to keep track of which trial we're on

while (my $line = <IN>) {
  chomp($line);

  if ($line=~ m/Subject:/) { 
	$subj = $';
	$subj =~ s/\D//g;
  } 
  
  elsif ($line=~ m/TrialDisplay.ACC:/) { 
	$correct[$trialNum] = $';
	$correct[$trialNum] =~ s/\D//g;
  }

  elsif ($line=~ m/TrialDisplay.RT:/) { 
	$RT[$trialNum] = $';
	$RT[$trialNum] =~ s/\D//g;
	$trialNum++;		
  } 
  
  elsif ($line=~ m/TrialDisplay.OnsetTime:/) { 
	$onsets[$trialNum] = $';
	$onsets[$trialNum] =~ s/\D//g;
  } 

  elsif ($line==EOF) {	## end of file
  } else { # This doesn't make logical sense to me, but somehow it works...
	print "Invalid line:\n $line";
  }

} #end while loop through lines


my $con1acc = eval join '+', @correct[@con1]; 
my $con2acc = eval join '+', @correct[@con2]; 
my $con3acc = eval join '+', @correct[@con3]; 
my $incon1acc = eval join '+', @correct[@incon1]; 
my $incon2acc = eval join '+', @correct[@incon2]; 
my $incon3acc = eval join '+', @correct[@incon3]; 

my @con1responded = grep { $_ != 0 } @RT[@con1];
my @con2responded = grep { $_ != 0 } @RT[@con2];
my @con3responded = grep { $_ != 0 } @RT[@con3];
my @incon1responded = grep { $_ != 0 } @RT[@incon1];
my @incon2responded = grep { $_ != 0 } @RT[@incon2];
my @incon3responded = grep { $_ != 0 } @RT[@incon3];

#	print ("1\n");
#	print join("\t", @con1responded);
#	print ("1\n");

my $con1respCt = $#con1responded+1;
my $con2respCt = $#con2responded+1;
my $con3respCt = $#con3responded+1;
my $incon1respCt = $#incon1responded+1;
my $incon2respCt = $#incon2responded+1;
my $incon3respCt = $#incon3responded+1;

my $con1RT = $con2RT = $con3RT = $incon1RT = $incon2RT = $incon3RT = 0;
if ( $con1respCt!=0 && $con2respCt!=0 && $con3respCt!=0 && $incon1respCt!=0 && $incon2respCt!=0 && $incon3respCt!=0 ){
	$con1RT = (eval join '+', @RT[@con1])/$con1respCt; 
	$con2RT = (eval join '+', @RT[@con2])/$con2respCt; 
	$con3RT = (eval join '+', @RT[@con3])/$con3respCt; 
	$incon1RT = (eval join '+', @RT[@incon1])/$incon1respCt; 
	$incon2RT = (eval join '+', @RT[@incon2])/$incon2respCt; 
	$incon3RT = (eval join '+', @RT[@incon3])/$incon3respCt; 
} else {
	print "One or more non-responsive blocks for $subj. Not scoring!\n";
}


# print OUT join("\t", $ID,$subj,$file,$con1acc,$con2acc,$con3acc,$incon1acc,$incon2acc,$incon3acc,$con1RT,$con2RT,$con3RT,$incon1RT,$incon2RT,$incon3RT,$con1respCt,$con2respCt,$con3respCt,$incon1respCt,$incon2respCt,$incon3respCt," "), "\n";      

# print out files to be read by MATLAB for use in first-level models
if (length($subj)==3){
	$subj = "0$subj";
}
# # `mkdir ../../Analysis/SPM/Processed/DMHDS$subj`;
print OUTACC join("\n",@correct);
print OUTACC "\n";

my $startTime = $onsets[0] - 2000; # first fixation is 2 seconds, so subtract that from first onset to get start time
@onsets = map { $_ - $startTime } @onsets; 
  
print OUTONSET join("\n",@onsets);
print OUTONSET "\n";

# clean up
if ($converted==1) {
  `rm -f $outdir/curfile.txt`;
}

} # end if successfully read file


print "Done!\n\n";
	
