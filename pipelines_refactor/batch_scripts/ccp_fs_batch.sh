#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

#----- help function -----------------------------------------

function usage () {
	echo -e "./ccp_fs.sh"
	echo -e "Runs on the results of ccp_prefs must have been run on the data already"
	echo -e "\t-h --help \t\t- prints help"
	echo -e "\t-f --InFile \t\t- configuration file\n\n"
	echo -e "\t-q \t\t- submit to cluster option\n\n"
}

#----- read command line options -----------------------------

while [ "$1" != "" ]; do
	PARAM=$(echo "$1" | awk -F= '{print $1}')
	VALUE=$(echo "$1" | awk -F= '{print $2}')
	case $PARAM in
		-h | --help)
			usage
			exit
			;;
		-f | --InFile) #dicoms
			CONFIG="$(dirname "$VALUE")/$(basename "$VALUE")"
			;;
		-q)
			qsub_flag=1
			;;
		*)
			usage
			error_exit "ERROR: unknown parameter \"$PARAM\""
			;;
	esac
	shift
done


#----- source environment setup for HCP Pipelines ------------
. "${CCP_HOME}/setup/setup_hcp.sh"

#----- read configuration file -------------------------------
if [[ ! -f "${CONFIG}" ]]; then
        error_exit "Cannot open file ${CONFIG}."
fi

StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjects=$(get_value "SUBJECTS_LIST" "${CONFIG}")

echo ""
echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJECTS \t:\t${Subjects}"
echo ""



#----- FROM HCP Pipelines ------------------------------------

for Subject in $Subjects; do

	SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
	T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
	T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
	T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)


#----- generate command to execute ---------------------------

read -r -d '' HCP_COMMAND << EOF
${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh \\
    --subject=$Subject \\
    --subjectDIR=$SubjectDIR \\
    --t1=$T1wImage \\
    --t1brain=$T1wImageBrain \\
    --t2=$T2wImage \\
    --printcom=$PRINTCOM

EOF

	echo
	echo -e "HCP PIPELINES COMMAND :\n"
	echo "${HCP_COMMAND}"
	echo


# ====================== create pbs script ===================
############# HERE FILE ########
cat > ${Subject}_fs.pbs << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=8,mem=10gb,vmem=20gb,walltime=14:00:00
#PBS -N ${Subject}_fs
#PBS -j oe
#PBS -o ${Subject}_fs.log

##########################################
#                                        #
#   Output some useful job information.  #
#                                        #
##########################################

echo ------------------------------------------------------
echo -n 'Job is running on node '; cat \$PBS_NODEFILE
echo ------------------------------------------------------
echo PBS: qsub is running on \$PBS_O_HOST
echo PBS: originating queue is \$PBS_O_QUEUE
echo PBS: executing queue is \$PBS_QUEUE
echo PBS: working directory is \$PBS_O_WORKDIR
echo PBS: execution mode is \$PBS_ENVIRONMENT
echo PBS: job identifier is \$PBS_JOBID
echo PBS: job name is \$PBS_JOBNAME
echo PBS: node file is \$PBS_NODEFILE
NODES=\$(cat \$PBS_NODEFILE)
echo PBS: nodes \$NODES
echo PBS: current home directory is \$PBS_O_HOME
echo PBS: PATH = \$PBS_O_PATH
echo ------------------------------------------------------


. "${CCP_HOME}/mylib/myfunctions.lib"
. "${CCP_HOME}/setup/setup_hcp.sh"

${HCP_COMMAND}

wait
chmod -Rf 775 "${StudyFolder}/${Subject}"

EOF


#----- submit to cluster queue -------------------------------

	if [  ! -z "${qsub_flag}" ]; then
		chmod 750 "${Subject}_fs.pbs"
		qsub "${Subject}_fs.pbs"
	fi

done # for Subjects

