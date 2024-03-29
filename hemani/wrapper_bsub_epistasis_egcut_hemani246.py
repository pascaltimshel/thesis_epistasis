#!/usr/bin/env python2.7

import sys
import glob
import os

import datetime
import time
import argparse

sys.path.insert(1, '/cvar/jhlab/snpsnap/snpsnap') # do not use sys.path.insert(0, 'somepath'). path[0], is the directory containing the script that was used to invoke the Python interpreter.
import pplaunch
import pphelper
import pplogger

import re
import subprocess
import logging


import pdb

def test():
	try:
		FNULL = open(os.devnull, 'w')
		subprocess.Popen(["plink", "--silent", "--noweb"], stdout=FNULL, stderr=subprocess.STDOUT)
		FNULL.close()
	except Exception as e:
		raise Exception("Could not find plink as executable on path. Please check that you have used 'use Plink' (this is version 1.07 [USE IT!]; 'use PLINK' gives version v1.08p). Error msg: %s" % e.message)


def submit():
	processes = []
	for param in params:
		logger.info( "RUNNING: type=%s" % param )
		
		### Output dir
		dir_out="/cvar/jhlab/timshel/egcut/epistasis_plink_246probes_epil1eq1/{}".format(param)
		### Creating outdir
		if not os.path.exists(dir_out):
			os.makedirs(dir_out) # NOTE use of makedirs(): all intermediate-level directories needed to contain the leaf directory

		### Setting out_prefix
		out_prefix = dir_out + '/' + param # /cvar/jhlab/timshel/egcut/epistasis_plink_246probes/2570100/2570100
			# will give files: 2570100.log; 2570100.qt, ...

		### SAFETY CHECK - checking for existence previous files
		if os.path.exists(out_prefix+".epi.qt.summary"): # summary file is only outputted when the analysis is finished
			logger.critical( "%s | result file exists already. Skipping this..." % param )
			continue

		###################################### PLINK CALL - ######################################
		cmd = "plink --bfile {0}"\
						" --out {1}"\
						" --pheno {2}"\
						" --pheno-name {3}"\
						" --epistasis" \
						" --epi1 1" \
						" --noweb"\
						.format(\
							bfile, \
							out_prefix, \
							pheno, \
							param)

		logger.info( "Making call :\n%s" % cmd )

		jobname = "epi_" + param

		processes.append( pplaunch.LaunchBsub(cmd=cmd, queue_name=queue_name, mem=mem, jobname=jobname, projectname='epistasis', path_stdout=log_dir, file_output=None, no_output=False, email=email, email_status_notification=email_status_notification, email_report=email_report, logger=logger) ) #

	for p in processes:
		p.run()
		time.sleep(args.pause)
	return processes


def check_jobs(processes, logger):
	logger.info("PRINTING IDs")
	list_of_pids = []
	for p in processes:
		logger.info(p.id)
		list_of_pids.append(p.id)

	logger.info( " ".join(list_of_pids) )

	if args.multiprocess:
		logger.info( "Running report_status_multiprocess " )
		pplaunch.LaunchBsub.report_status_multiprocess(list_of_pids, logger) # MULTIPROCESS
	else:
		logger.info( "Running report_status" )
		pplaunch.LaunchBsub.report_status(list_of_pids, logger) # NO MULTIPROCESS


def ParseArguments():
	arg_parser = argparse.ArgumentParser(description="Python submission Wrapper")
	arg_parser.add_argument("--logger_lvl", help="Set level for logging", choices=['debug', 'info', 'warning', 'error'], default='info') # TODO: make the program read from STDIN via '-'
	arg_parser.add_argument("--multiprocess", help="Swtich; [default is false] if set use report_status_multiprocess. Requires interactive multiprocess session", action='store_true')
	#TODO: implement formatting option
	arg_parser.add_argument("--format", type=int, choices=[0, 1, 2, 3], help="Formatting option parsed to pplaunch", default=1)
	arg_parser.add_argument("--pause", type=int, help="Sleep time after run", default=2)
	
	args = arg_parser.parse_args()
	return args

def LogArguments():
	# PRINT RUNNING DESCRIPTION 
	now = datetime.datetime.now()
	logger.critical( '# ' + ' '.join(sys.argv) )
	logger.critical( '# ' + now.strftime("%a %b %d %Y %H:%M") )
	logger.critical( '# CWD: ' + os.getcwd() )
	logger.critical( '# COMMAND LINE PARAMETERS SET TO:' )
	for arg in dir(args):
		if arg[:1]!='_':
			logger.critical( '# \t' + "{:<30}".format(arg) + "{:<30}".format(getattr(args, arg)) ) ## LOGGING



###################################### Global params ######################################
#queue_name = "week" # [bhour, bweek] priority
queue_name = "hour" # [bhour, bweek] priority
# priority: This queue has a per-user limit of 10 running jobs, and a run time limit of three days.
mem="1" # gb      
	### RESULTS from EUR_chr_1 (largest chromosome)
email='pascal.timshel@gmail.com' # [use an email address 'pascal.timshel@gmail.com' or 'False'/'None']
email_status_notification=False # [True or False]
email_report=False # # [True or False]

current_script_name = os.path.basename(__file__).replace('.py','')

###################################### ARGUMENTS ######################################
args = ParseArguments()

bfile = "/cvar/jhlab/timshel/egcut/GTypes_hapmap2_expr/Prote_370k_251011.no_mixup.with_ETypes.chr_infered.SNPs781"
pheno = "/cvar/jhlab/timshel/egcut/ETypes_probes_norm_tonu/ExpressionDataCorrected4GWASPCs.ExpressionData.txt.QuantileNormalized.Log2Transformed.ProbesCentered.SamplesZTransformed.CovariatesRemoved.with_GTypes832.with_probes246.extract.transpose.txt"

file_probelist = "/cvar/jhlab/timshel/egcut/ETypes_probes_norm_tonu/hemani_probes246.txt"
###################################### Functions ######################################
#### Read file with probes to run
def read_phenotypes(filename):
	with open(filename, 'r') as f:
		lines = f.read().splitlines()
		return lines

#### RUN Variable Functions ####
params = read_phenotypes(file_probelist)

###################################### SETUP logging ######################################
current_script_name = os.path.basename(__file__).replace('.py','')
log_dir = "/cvar/jhlab/timshel/egcut/epistasis_plink_246probes" #OBS
if not os.path.exists(log_dir):
	os.mkdir(log_dir)
log_name = current_script_name + '_epil1eq1' # VARIABLE
logger = pplogger.Logger(name=current_script_name, log_dir=log_dir, log_format=1, enabled=True).get()
def handleException(excType, excValue, traceback, logger=logger):
	logger.error("Logging an uncaught exception", exc_info=(excType, excValue, traceback))
#### TURN THIS ON OR OFF: must correspond to enabled='True'/'False'
sys.excepthook = handleException
logger.info( "INSTANTIATION NOTE: placeholder" )
###########################################################################################

###################################### RUN FUNCTIONS ######################################
# RUN Initial functions
LogArguments()
test() # test that things are ok
processes = submit()



### Finishing
start_time_check_jobs = time.time()
check_jobs(processes, logger) # TODO: parse multiprocess argument?
elapsed_time = time.time() - start_time_check_jobs
logger.info( "Total Runtime for check_jobs: %s s (%s min)" % (elapsed_time, elapsed_time/60) )
logger.critical( "%s: finished" % current_script_name)










