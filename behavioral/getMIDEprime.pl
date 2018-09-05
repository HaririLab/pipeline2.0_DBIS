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
use List::MoreUtils 'pairwise';

# global variables 
my $nTrials = 12;		# same for each condition

# process command line arguments
if (scalar(@ARGV) != 2) {
  print "\nSyntax: perl getMIDEprime.pl infile.txt outdir\n";
  print "\tinfile = name of individual ePrime text file to parse\n";
  print "\toutdir = desired directory for output file\n\n";
  exit;
}
my $infile = $ARGV[0];
my $outdir = $ARGV[1];

open IN, "<$infile" or die "could not open $infile";
open OUT, ">$outdir/ResponseData.txt" or die "could not open $outdir/ResponseData.txt";
open OUT_ant_0, ">$outdir/stimfiles/cue+delay_0.txt" or die "could not open $outdir/stimfiles/cue+delay_0.txt";
open OUT_ant_1, ">$outdir/stimfiles/cue+delay_1.txt" or die "could not open $outdir/stimfiles/cue+delay_1.txt";
open OUT_ant_5, ">$outdir/stimfiles/cue+delay_5.txt" or die "could not open $outdir/stimfiles/cue+delay_5.txt";
open OUT_ant_load, ">$outdir/stimfiles/cue+delay_ALL_byLoad.txt" or die "could not open $outdir/stimfiles/cue+delay_ALL_byLoad.txt"; # for parametric load analysis
open OUT_target, ">$outdir/stimfiles/target.txt" or die "could not open $outdir/stimfiles/target.txt";
open OUT_fb_onsets_0_hit, ">$outdir/stimfiles/fb_onsets_0_hit.txt" or die "could not open $outdir/stimfiles/fb_onsets_0_hit.txt";
open OUT_fb_onsets_1_hit, ">$outdir/stimfiles/fb_onsets_1_hit.txt" or die "could not open $outdir/stimfiles/fb_onsets_1_hit.txt";
open OUT_fb_onsets_5_hit, ">$outdir/stimfiles/fb_onsets_5_hit.txt" or die "could not open $outdir/stimfiles/fb_onsets_5_hit.txt";
open OUT_fb_onsets_0_miss, ">$outdir/stimfiles/fb_onsets_0_miss.txt" or die "could not open $outdir/stimfiles/fb_onsets_0_miss.txt";
open OUT_fb_onsets_1_miss, ">$outdir/stimfiles/fb_onsets_1_miss.txt" or die "could not open $outdir/stimfiles/fb_onsets_1_miss.txt";
open OUT_fb_onsets_5_miss, ">$outdir/stimfiles/fb_onsets_5_miss.txt" or die "could not open $outdir/stimfiles/fb_onsets_5_miss.txt";

print "Reading file: $infile\n";
$infile =~ /-(\d+).txt/;
my $ID = $1; # ID from file name
my $subj = ""; # ID from file
my $converted = 0;		# 0 for no, 1 for yes, 2 for fail
my $headerline = <IN>;
if ($headerline=~m/Header Start/) { # looks like we can read this file, proceed without converting
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

# initialize variables for this subject
my $RTsum0 = $RTsum1 = $RTsum5 = 0;
my $earlyCt0 = $earlyCt1 = $earlyCt5 = 0;
my $lateCt0 = $lateCt1 = $lateCt5 = 0;
my $total = 0;
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
					push @delayDurations0, $duration/1000+2; # include duration of cue
				} elsif ($condition eq '$1') { 
					push @delayDurations1, $duration/1000+2; # include duration of cue
				} elsif ($condition eq '$5') { 
					push @delayDurations5, $duration/1000+2; # include duration of cue
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
			elsif ($line=~ m/CumulativeTotal:/) { 
				$total = $';
				$total =~ s/\D//g;
			} 
			elsif ($line==EOF) {	## end of file
			} else { # This doesn't make logical sense to me, but somehow it works...
				print "Invalid line:\n $line";
			}
		} #end if in dummy
	} #end while loop through lines
	
	
	my $totCueCt = $#cueOnsets0 + $#cueOnsets1 + $#cueOnsets5 + 3; # $# gives index of last array element
	if ($totCueCt!=36) {
		print "\tBlast! Could only read $totCueCt/36 trials.\n";
		die;
	} 
	else {  # calculate the stats, being careful not to divide by 0
	
		## calculate and print out values needed for processing BOLD data
		my $startTime = $cueOnsets1[0] - 4000; # first actual ITI is 4 seconds, so subtract that from first actual trial (which is a $1 cue) to get start time
		@cueOnsets0 = map { ($_ - $startTime)/1000 } @cueOnsets0; 
		@cueOnsets1 = map { ($_ - $startTime)/1000 } @cueOnsets1;
		@cueOnsets5 = map { ($_ - $startTime)/1000 } @cueOnsets5;
		@delayOnsets0 = map { ($_ - $startTime)/1000 } @delayOnsets0;
		@delayOnsets1 = map { ($_ - $startTime)/1000 } @delayOnsets1;
		@delayOnsets5 = map { ($_ - $startTime)/1000 } @delayOnsets5;
		@fbOnsets0 = map { ($_ - $startTime)/1000 } @fbOnsets0;
		@fbOnsets1 = map { ($_ - $startTime)/1000 } @fbOnsets1;
		@fbOnsets5 = map { ($_ - $startTime)/1000 } @fbOnsets5;
		
		my @cueOnsetsALL = @cueOnsets0;
		push(@cueOnsetsALL,@cueOnsets1,@cueOnsets5);
		my @delayDurationsALL = @delayDurations0;
		push(@delayDurationsALL,@delayDurations1,@delayDurations5);
		my @fbOnsetsALL = @fbOnsets0;
		push(@fbOnsetsALL,@fbOnsets1,@fbOnsets5);
		# foreach my $x (@delayDurationsALL) { $x = $x + 2000; }; # now this encompasses the whole anticipation duration: 2s cue + fixation duration
		my @targetOnsets = pairwise { $a + $b } @cueOnsetsALL, @delayDurationsALL;
		my @targetDurations = pairwise { $a - $b } @fbOnsetsALL, @targetOnsets;
		
		for my $i ( 0 .. $#cueOnsets0 ) {
			print OUT_ant_0 $cueOnsets0[$i], ":", $delayDurations0[$i] ,"\n";
			print OUT_ant_1 $cueOnsets1[$i], ":", $delayDurations1[$i] ,"\n";
			print OUT_ant_5 $cueOnsets5[$i], ":", $delayDurations5[$i] ,"\n";
			print OUT_ant_load $cueOnsets0[$i], ,"*1:", $delayDurations0[$i] ,"\n";
			print OUT_ant_load $cueOnsets1[$i], ,"*2:", $delayDurations1[$i] ,"\n";
			print OUT_ant_load $cueOnsets5[$i], ,"*3:", $delayDurations5[$i] ,"\n";
		}
		for my $i ( 0 .. $#targetOnsets ) {
			print OUT_target $targetOnsets[$i], ":", $targetDurations[$i] ,"\n";
		}
		
		for($i=0;$i<=$#fbOnsets0;$i++){ 
			if ($accuracy0[$i]==1){ print OUT_fb_onsets_0_hit "$fbOnsets0[$i]\n"; }
			else { print OUT_fb_onsets_0_miss "$fbOnsets0[$i]\n"; }
		}
		for($i=0;$i<=$#fbOnsets1;$i++){ 
			if ($accuracy1[$i]==1){	print OUT_fb_onsets_1_hit "$fbOnsets1[$i]\n"; }
			else { print OUT_fb_onsets_1_miss "$fbOnsets1[$i]\n"; }
		}
		for($i=0;$i<=$#fbOnsets5;$i++){ 
			if ($accuracy5[$i]==1){	print OUT_fb_onsets_5_hit "$fbOnsets5[$i]\n"; }
			else { print OUT_fb_onsets_5_miss "$fbOnsets5[$i]\n"; }
		}  
		
		## calculate and print out summary values 
		my $acc0 = (eval join '+', @accuracy0) / $nTrials;
		my $acc1 = (eval join '+', @accuracy1) / $nTrials;
		my $acc5 = (eval join '+', @accuracy5) / $nTrials;
		my $accALL = ($acc0+$acc1+$acc5)/3;
	
		my $avgRT0 = $avgRT1 = $avgRT5 = 0;
		if($acc0 != 0 ){ $avgRT0 = $RTsum0 / (eval join '+', @accuracy0); }
		if($acc1 != 0 ){ $avgRT1 = $RTsum1 / (eval join '+', @accuracy1); }
		if($acc5 != 0 ){ $avgRT5 = $RTsum5 / (eval join '+', @accuracy5); }
	
		my $DMHDSID = sprintf("DMHDS%04s", $ID);
		print OUT "DMHDSID: $DMHDSID\nIDfromFileName: $ID\nIDfromFile: $subj\ndate: $date\ntime: $time\ninitTargetDur: $initTargetDur\ntotal: $total\naccALL: $accALL\nearlyCt0: $earlyCt0\nearlyCt1: $earlyCt1\nearlyCt5: $earlyCt5\nlateCt0: $lateCt0\nlateCt1: $lateCt1\nlateCt5: $lateCt5\nacc0: $acc0\nacc1: $acc1\nacc5: $acc5\navgRT0: $avgRT0\navgRT1: $avgRT1\navgRT5: $avgRT5\ninfile: $infile\n";      
		
	} # end if successfully read all trials
	
	if ($converted==1) {
		`rm -f $outdir/converted.txt`;
	}
	

} # end if successfully read file



print "Done!\n\n";
	
