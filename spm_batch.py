#!/usr/bin/env python
import sys,os,time,re,datetime,smtplib,argparse

#------SPM_BATCH.py---------------------------
#
# The original version of this script used for preprocessing in SPM can be
# found in COPIEDFROMBIAC/DNS. This script has been adapted to run the
# subject and group-level steps of the mrtrix pipeline for fibre density
# and cross section analysis of DWI data. I'm attempting to make this more
# general as well.
#
# 5/10/11: Modified by Annchen for use by different people
# 2/14/12: Updated to account for additional rest run - now generates the folder "restALL" in Processed and Analyzed with data from all 256 time points
#	   (the folder "rest" contains the data from the first run (128 timepoints) as before)
#	   The user can choose whether to run just the first run (restrun="yes") and/or the whole session (restALLrun="yes")
# 9/9/14: Updated for new DNS protocol - dropping rest and adding numLS & faceName
# 2/13/15: Updated to accommodate structurals in .nii.gz format rather than DCM
#		(there are no longer "series###" folders in Data/Anat, so changed to specify only the 3 digit numbers)
# 8/21/18: Updated for slurm, data commons, and bids and altered for use with mrtrix
#		#NOTE: only works with python 2 but check for 3 issues (module load Anaconda3/5.1.0)
#########user section#########################

parser = argparse.ArgumentParser()
parser.add_argument("-u","--user", help="indicate user submitting jobs and email to send job notices to")
parser.add_argument("-n", "--numnodes", type=int, help="number of nodes on cluster", default=0)
parser.add_argument("--maintain_n_jobs", type=int, help="leave one in q to keep them moving through", default=100)
parser.add_argument("--min_jobs", type=int, help="minimum number of jobs to keep in q even when crowded", default=5)
parser.add_argument("--n_fake_jobs", type=int, help="during business hours, pretend there are extra jobs to try and leave a few spots open", default=50)
parser.add_argument("--sleep_time", type=int, help="pause time (sec) between job count checks", default=20)
parser.add_argument("--max_run_time", help="maximum time any job is allowed to run in the format days-hours:minutes:seconds", default="12:0:0")
parser.add_argument("--max_run_hours", type=int, help="maximum number of hours submission script can run", default=24)
parser.add_argument("--warning_time", type=int, help="send out a warning after this many hours informing you that the deamon is still running", default=18)
parser.add_argument("-p","--partition", help="which partition job will be submitted to", default="common")
parser.add_argument("--script", help="script path for all job submissions - don't include sbatch or -p here")
parser.add_argument("--command_args", help="string of commands (not including subject) to accompany sbatch if necessary")
parser.add_argument("--command", type=int, help="0 if script is a bash script with just subject as input, 1 if script is a string with the command and arguments")
parser.add_argument("--subjects", help="space delimited string of subjects to process (in bids format)")
args = parser.parse_args()

#user specific constants
username = args.user                              #your cluster login name (use what shows up in squeue)
useremail = username+"@duke.edu"                 	#email to send job notices to
partition = args.partition							#partition jobs will be submitted to
script = args.script
command = args.command
# template_f = file("spm_batch_TEMPLATE.sh")      #job template location (on head node)
# experiment = "DNS.01"                           #experiment name for qsub
numnodes = args.numnodes                                     #number of nodes on cluster
if numnodes == 0:
	nodeinfo = os.popen("sinfo -O nodes -p %s" % (partition)) #MLS: deprecated
	# nodeinfo = Popen("sinfo -O nodes -p %s" % (partition), shell=True, stdout=PIPE).stdout
	nodeinfo_list = nodeinfo.readlines()
	for line in nodeinfo_list:
		if line != "NODES":
			numnodes = int(line)
maintain_n_jobs = args.maintain_n_jobs                           #leave one in q to keep them moving through
min_jobs = args.min_jobs                                    #minimum number of jobs to keep in q even when crowded
n_fake_jobs = args.n_fake_jobs                                #during business hours, pretend there are extra jobs to try and leave a few spots open
sleep_time = args.sleep_time                                 #pause time (sec) between job count checks
max_run_time = args.max_run_time                              ##maximum time any job is allowed to run in the format days-hours:minutes:seconds"
max_run_hours= args.max_run_hours	                        #maximum number of hours submission script can run
warning_time= args.warning_time                                 #send out a warning after this many hours informing you that the deamon is still running
                                                #make job files  these are the lists to be traversed
                                                #all iterated items must be in "[ ]" separated by commas
#experiment variables
subnums_string = args.subjects
subnums = subnums_string.split()
# runs = [1]                   #[ run01 ] range cuts the last number off any single runs should still be in [ ] or can be runs=range(1,2)
# anatnumber = "003_2-2"     #(usually series002) folder under Data/Anat that includes the anatomical dicom images
# tone = "006"           #t1 folder (series005) if it doesn't exist, leave blank
# facesfolder = "run005_01"     #folder (usually run004_02) with the rest functional data (in V00*.img/.hdr format)
# cardsfolder = "run005_02"    #folder (usually run004_03) with the 2nd rest run functional data (in V00*.img/.hdr format)
# numlsfolder = "run005_03"    #folder (usually run004_04) with the faces functional data (in V00*.img/.hdr format)
# facenamefolder = "run005_04"    #folder (usually run004_05) with the cards functional data (in V00*.img/.hdr format)

# # processing choices
# facesrun = "yes"             #"yes" runs preprocessing and single subject analysis for faces, "no" skips
# cardsrun = "yes"             #"yes" runs preprocessing and single subject analysis for cards, "no" skips
# numlsrun = "yes"             #"yes" runs preprocessing and single subject analysis for first rest run, "no" skips
# facenamerun = "yes"          #"yes" runs preprocessing and single subject analysis for whole rest session (both runs), "no" skips
# ### If all runs are set to "yes" and justfunc is	set to "no" the script will automatically delete any existing Analyzed/Processed folders for each of the subjects ###
# justfunc = "no"              # "yes" skips anatomical processing.  To be used if you have manually set origin of anatomicals and then copied the anatomical into each functional folders
# imageprep = "yes"             # yes ONLY copies over images and imports dicoms to allow for manual AC PC realign and segmentation

# # in case you want to use a manual order number (rather than it being automatically determined from eprime file)
# usemanualorder = "no"	# leave it at "no" but switch to "yes" only if you want to use manual order
# manualordernum = "1"                #the script will automatically determine the order number, but if it can't it will default to this

####!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!###############################################

def daemonize(stdin='/dev/null',stdout='/dev/null',stderr='/dev/null'):
	try:
		#try first fork
		pid=os.fork()
		if pid>0:
			sys.exit(0)
	except OSError, e: #if python 3, do except OSError as e
		sys.stderr.write("for #1 failed: (%d) %s\n" % (e.errno,e.strerror))
		sys.exit(1)
	os.chdir("/")
	os.umask(0)
	os.setsid()
	try:
		#try second fork
		pid=os.fork()
		if pid>0:
			sys.exit(0)
	except OSError as e:
			sys.stderr.write("for #2 failed: (%d) %s\n" % (e.errno, e.strerror))
			sys.exit(1)
	for f in sys.stdout, sys.stderr: f.flush()
	si=file(stdin,'r')
	so=file(stdout,'a+')
	se=file(stderr,'a+',0)
	os.dup2(si.fileno(),sys.stdin.fileno())
	os.dup2(so.fileno(),sys.stdout.fileno())
	os.dup2(se.fileno(),sys.stderr.fileno())



start_dir = os.getcwd()

daemonize('/dev/null',os.path.join(start_dir,'daemon.log'),os.path.join(start_dir,'daemon.log'))
sys.stdout.close()
os.chdir(start_dir)
temp=time.localtime()
hour,minute,second=temp[3],temp[4],temp[5]
prev_hr=temp[3]
t0=str(hour)+':'+str(minute)+':'+str(second)
log_name=os.path.join(start_dir,'daemon.log')
log=file(log_name,'w')
log.write('Daemon started at %s with pid %d\n' %(t0,os.getpid()))
log.write('To kill this process type "kill %s" at the head node command line\n' % os.getpid())
log.close()
t0=time.time()
master_clock=0

# status_cmd = "squeue -p %s" % (partition)
# status = os.popen(status_cmd)
# status_list = status.readlines()
# serverURL=socket.getfqdn()
# log=file(log_name,'a+')
# log.write(serverURL)
# log.close()
# for line in status_list:
	# if (line.find(" R ") > -1):
		# log=file(log_name,'a+')
		# log.write('R')
		# log.close()
	# elif (line.find(" PD ") > -1):
		# log=file(log_name,'a+')
		# log.write('P')
		# log.close()		
# #build allowed timedelta
# kill_time_limit = datetime.timedelta(minutes=max_run_time)


def _check_jobs(username, n_fake_jobs, max_run_time, partition):
#careful, looks like all vars are global
#see how many jobs we have  in

	#set number of jobs to maintain based on time of day.
	cur_time = datetime.datetime.now() #get current time  #time.localtime()  #get current time
	if (cur_time.weekday > 4) | (cur_time.hour < 8) | (cur_time.hour > 17):
		n_other_jobs = 0
	else: #its a weekday, fake an extra 6 jobs to leave 5 nodes open
		n_other_jobs = n_fake_jobs

	n_jobs = 0
	status_cmd = "squeue -p %s" % (partition)
	status = os.popen(status_cmd) #MLS: deprecated
	# status = Popen(status_cmd, shell=True, stdout=PIPE).stdout
	status_list = status.readlines()

	for line in status_list:
		#are these active or queued jobs?
		if (line.find(" R ") > -1):
			running = 1
		elif (line.find(" PD ") > -1):   #all following jobs are in queue not running
			running = 0

		#if job is mine
		if (line.find(username) > 0):   #name is in the line
			n_jobs = n_jobs + 1
			if running == 1:   #if active job, check how long its been running and delete it if too long
				job_info = line.split()  #get job information
				job_day_time = job_info[5].split("-")	#separate job runtime into days and [h,m,s]
				if len(job_day_time) > 1:
					job_days = int(job_day_time[0])
					job_time = job_day_time[1].split(":")
				else:
					job_days = 0
					job_time = job_day_time[0].split(":")
				max_day_time = max_run_time.split("-") #get max job runtime into same format
				if len(max_day_time) > 1:
					max_days = int(max_day_time[0])
					max_time = max_day_time[1].split(":")
				else:
					max_days = 0
					max_time = max_day_time[0].split(":")				
				if ( job_days > max_days ):
					os.system("scancel %s" % (job_info[0]))	#delete the runaway job
					print("Job %s was deleted because it ran for more than the maximum time." % (job_info[0]))
				elif ( job_days == max_days ) & ( int(job_time[0]) > int(max_time[0]) ):
					os.system("scancel %s" % (job_info[0]))
					print("Job %s was deleted because it ran for more than the maximum time." % (job_info[0]))
				elif ( job_days == max_days ) & ( int(job_time[0]) == int(max_time[0]) ) & ( int(job_time[1]) > int(max_time[1]) ):
					os.system("scancel %s" % (job_info[0]))
					print("Job %s was deleted because it ran for more than the maximum time." % (job_info[0]))

		# if line starts " ###" and didn't fail (can't tell if an interactive job bc other jobs might be called bash?)
		elif bool(re.match( "^\d+", line )) & (line.find("failed") < 0):
			n_other_jobs = n_other_jobs + 1
	return n_jobs, n_other_jobs

#make a directory to write job files to and store the start directory
tmp_dir = str(os.getpid())
os.mkdir(tmp_dir)

#read in template 
# template = template_f.read()
# template_f.close()
os.chdir(tmp_dir)

#for each subject
for subnum in subnums:
	#for each run
	# for run in runs:

	# #Check for changes in user settings #MLS: come back to this (invalid syntax ~/.bashrc
	# user_settings=("/hpchome/long/%s/.bash_profile") % (username)
	# if os.path.isfile(user_settings):
		# f=file(user_settings)
		# settings=f.readlines()
		# f.close()
		# for line in settings:
			# exec(line)

		# #define substitutions, make them in template
		# runstr = "%05d" %(run)
		# tmp_job_file = template.replace( "SUB_USEREMAIL_SUB", useremail )
		# tmp_job_file = tmp_job_file.replace( "SUB_SUBNUM_SUB", str(subnum) )
		# tmp_job_file = tmp_job_file.replace( "SUB_ANATNUM_SUB", str(anatnumber) )
 		# tmp_job_file = tmp_job_file.replace( "SUB_FACESFOLD_SUB", str(facesfolder) )
		# tmp_job_file = tmp_job_file.replace( "SUB_CARDSFOLD_SUB", str(cardsfolder) )
		# tmp_job_file = tmp_job_file.replace( "SUB_LSFOLD_SUB", str(numlsfolder) )
		# tmp_job_file = tmp_job_file.replace( "SUB_FNFOLD_SUB", str(facenamefolder) )
 		# tmp_job_file = tmp_job_file.replace( "SUB_RUNNUM_SUB", str(run) )
		# tmp_job_file = tmp_job_file.replace( "SUB_TONENUM_SUB", str(tone) )
		# tmp_job_file = tmp_job_file.replace( "SUB_LSRUN_SUB", str(numlsrun) )
		# tmp_job_file = tmp_job_file.replace( "SUB_FNRUN_SUB", str(facenamerun) )
		# tmp_job_file = tmp_job_file.replace( "SUB_FACESRUN_SUB", str(facesrun) )
		# tmp_job_file = tmp_job_file.replace( "SUB_CARDSRUN_SUB", str(cardsrun) )
		# tmp_job_file = tmp_job_file.replace( "SUB_JUSTFUNC_SUB", str(justfunc) )
		# tmp_job_file = tmp_job_file.replace( "SUB_PREONLY_SUB", str(imageprep) )
		# tmp_job_file = tmp_job_file.replace( "SUB_MANUALORDERNUM_SUB", str(manualordernum) )
		# tmp_job_file = tmp_job_file.replace( "SUB_USEMANUALORDER_SUB", str(usemanualorder) )
		# tmp_job_file = tmp_job_file.replace( "SUB_NAMELEN_SUB", str(len(username)) )

	# #make fname and write job file to cwd
	# tmp_job_fname = "_".join( ["SPM_DNS", subnum, runstr ] )
	# tmp_job_fname = ".".join( [ tmp_job_fname, "job" ] )
	# tmp_job_f = file( tmp_job_fname, "w" )
	# tmp_job_f.write(tmp_job_file)
	# tmp_job_f.close()


	#wait to submit the job until we have fewer than maintain in q
	n_jobs = maintain_n_jobs
	while n_jobs >= maintain_n_jobs:

		#count jobs
		n_jobs, n_other_jobs = _check_jobs(username, n_fake_jobs, max_run_time, partition)   #count jobs, delete jobs that are too old
		#adjust job submission by how may jobs are submitted
		#set to minimum number if all nodes are occupied
		#should still try to leave # open on weekdays
		if ((n_other_jobs+ n_jobs) > (numnodes+1)):
			n_jobs = maintain_n_jobs  - (min_jobs - n_jobs)

		if n_jobs >= maintain_n_jobs:
			time.sleep(sleep_time)
		elif n_jobs < maintain_n_jobs:
			# cmd = "sbatch -p %s %s %s"  % (partition, script, subnum)
			log=file(log_name,'a+')
			log.write('sbatch %s ' % subnum)
			log.close()
			# cmd = "echo %s %s %s"  % (partition, script, subnum)
			# dummy, f = os.popen2(cmd) #MLS: deprecated
			# p = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, close_fds=True)
			# (dummy, f) = (p.stdin, p.stdout)
			time.sleep(sleep_time)

	#Check what how long daemon has been running
	t1=time.time()
	hour=(t1-t0)/3600
	log=file(log_name,'a+')
	log.write('Daemon has been running for %s hours\n' % hour)
	log.close()
	now_hr=time.localtime()[3]
	if now_hr>prev_hr:
		master_clock=master_clock+1
	prev_hr=now_hr
	# serverURL="email.biac.duke.edu"
	# serverURL=socket.getfqdn()
	if master_clock==warning_time:
		headers="From: %s\r\nTo: %s\r\nSubject: Daemon job still running!\r\n\r\n" % (useremail,useremail)
		text="""Your daemon job has been running for %d hours.  It will be killed after %d.
		To kill it now, log onto the head node and type kill %d""" % (warning_time,max_run_hours,os.getpid())
		message=headers+text
		# mailServer=smtplib.SMTP(serverURL)
		# mailServer.sendmail(useremail,useremail,message)
		# mailServer.quit()
		log=file(log_name,'a+')
		log.write(message)
		log.close()
	elif master_clock==max_run_hours:
		headers="From: %s\r\nTo: %s\r\nSubject: Daemon job killed!\r\n\r\n" % (useremail,useremail)
		text="Your daemon job has been killed.  It has run for the maximum time alotted"
		message=headers+text
		# mailServer=smtplib.SMTP(serverURL)
		# mailServer.sendmail(useremail,useremail,message)
		# mailServer.quit()
		log=file(log_name,'a+')
		log.write(message)
		log.close()
		ID=os.getpid()
		os.system('kill '+str(ID))



#wait for jobs to complete
#delete them if they run too long
n_jobs = 1
while n_jobs > 0:
	n_jobs, n_other_jobs = _check_jobs(username, n_fake_jobs, max_run_time, partition)
	time.sleep(sleep_time)


#remove tmp out files move to start dir and delete tmpdir
#terminated jobs will prevent this from executing
#you will then have to clean up a "#####" directory with
# ".out" files written in it.
# cmd = "rm *.out"
# os.system(cmd)
# os.chdir(start_dir)
# os.rmdir(tmp_dir)
os.system("echo done")