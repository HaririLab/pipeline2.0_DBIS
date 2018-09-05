#!usr/bin/perl

# getMIDEprime_batch.pl
#
# This script takes in a single eprime output text file, parses it, and prints out onset times in accuracy to be read
# by MATLAB during first level processing
#
# Usage:  perl getMIDEprime_batch.pl infile.txt outfile.txt
# Input: infile.txt = name of individual ePrime text file to parse
# Assumptions:
#   -12 trials per condition
#
# Note: For some reason it is not straightforward to parse the eprime text files as they exist straight off the server.
#   Solution: in this script we convert to utf-8 format with the following command on the terminal:
#   iconv -f utf-16 -t utf-8 oldfile.txt > newfile.txt 
#
# Annchen Knodt 12/22/2015
# 9/5/16: removed trigger lines (Dunedin scanner triggers at start of paradigm rather than disdaq)
# 10/11/16: adapted to be run individually from BOLD processing pipeline

#use warnings;

# global variables 
my $nTrials = 12;		# same for each condition

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: perl getMIDEprime_batch.pl infile.txt outfile.txt\n";
  print "\tinfile = name of individual ePrime text file to parse\n";
  print "\toutfile = desired name for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outfile = $ARGV[1];

open IN, "<$infile" or die "could not open $infile";
open OUT, ">$outfile" or die "could not open $outfile";

print "\n***Running getMIDEprime_individual.pl***\n";

$infile =~ /-(\d+).txt/;
my $ID = $1; # ID from file name
my $subj = ""; # ID from file

my $converted = 0;		# 0 for no, 1 for yes, 2 for fail
my $headerline = <IN>;
if ($headerline=~m/Header Start/) { # looks like we can read this file, procede without converting
$converted = 0;
} else {	       # can't read the file correctly, try converting
`iconv -f utf-16 -t utf-8 $infile > curfile.txt`; # convert to utf-8 format
open IN, "curfile.txt" or die "could not open curfile.txt"; # use this line to run with the converted file   
$converted = 1;
$headerline = <IN>;
if (!$headerline=~m/Header Start/) { # still can't read the file
  print "\tBlast! Could not read file $infile in original or utf-8 format.\n";
  $converted = 2;
}
}

# prepend 0 if experimenter didn't include it
if (length($ID)==3){
	$ID = "0$ID";
}  

# initialize variables for this subject
my @cueOnsets0 = @cueOnsets1 = @cueOnsets5;
my @delayOnsets0 = @delayOnsets1 = @delayOnsets5;
my @fbOnsets0 = @fbOnsets1 = @fbOnsets5;
my @delayDurations0 = @delayDurations1 = @delayDurations5;
my @accuracy0 = @accuracy1 = @accuracy5;

if ($converted!=2) { # go ahead and parse the file
my $blockNum = 0;	       # to keep track of which block (out of win/loss blocks) we're in
my $inDummy = 0;		# to keep track of whether we are in the first two dummy blocks
my $condition = ""; 
while (my $line = <IN>) {
  chomp($line);

  if ($line=~ m/Subject:/) { 
	$subj = $';
	$subj =~ s/\D//g;
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
			die;
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
			die;
		  }					
	  }
	  elsif ($line==EOF) {	## end of file
	  } else { # This doesn't make logical sense to me, but somehow it works...
		print "Invalid line:\n $line";
	  }
	}
} #end while loop through lines


my $totCueCt = $#cueOnsets0 + $#cueOnsets1 + $#cueOnsets5 + 3; # $# gives index of last array element
if ($totCueCt!=36) {
  print "\tBlast! Could only read $totCueCt/36 trials.\n";
  die;
} 
else {  # calculate the stats, being careful not to divide by 0


  # my $acc0 = (eval join '+', @accuracy0) / $nTrials;
  # my $acc1 = (eval join '+', @accuracy1) / $nTrials;
  # my $acc5 = (eval join '+', @accuracy5) / $nTrials;
  # my $accALL = ($acc0+$acc1+$acc5)/3;

  # if($acc0 == 0 || $acc1 == 0 | $acc5 == 0){
	# print "All wrong for one or more trial types, skipping subj $subj!\n";
	# die;
  # }
  
  my $startTime = $cueOnsets1[0] - 4000; # first actual ITI is 4 seconds, so subtract that from first actual trial (which is a $1 cue) to get start time
  @cueOnsets0 = map { $_ - $startTime } @cueOnsets0; 
  @cueOnsets1 = map { $_ - $startTime } @cueOnsets1;
  @cueOnsets5 = map { $_ - $startTime } @cueOnsets5;
  @delayOnsets0 = map { $_ - $startTime } @delayOnsets0;
  @delayOnsets1 = map { $_ - $startTime } @delayOnsets1;
  @delayOnsets5 = map { $_ - $startTime } @delayOnsets5;
  @fbOnsets0 = map { $_ - $startTime } @fbOnsets0;
  @fbOnsets1 = map { $_ - $startTime } @fbOnsets1;
  @fbOnsets5 = map { $_ - $startTime } @fbOnsets5;
  for($i=0;$i<=$#cueOnsets0;$i++){ 
print OUT "$cueOnsets0[$i]\t$delayOnsets0[$i]\t$delayDurations0[$i]\t$fbOnsets0[$i]\t$accuracy0[$i]\n";
  }
  for($i=0;$i<=$#cueOnsets1;$i++){ 
print OUT "$cueOnsets1[$i]\t$delayOnsets1[$i]\t$delayDurations1[$i]\t$fbOnsets1[$i]\t$accuracy1[$i]\n";
  }
  for($i=0;$i<=$#cueOnsets5;$i++){ 
print OUT "$cueOnsets5[$i]\t$delayOnsets5[$i]\t$delayDurations5[$i]\t$fbOnsets5[$i]\t$accuracy5[$i]\n";
  }

}

if ($converted==1) {
  `rm -f curfile.txt`;
}

reset 'c'; reset 'f'; reset 'd'; reset 'a';

} # end if successfully read file



print "Done!\n\n";
	
