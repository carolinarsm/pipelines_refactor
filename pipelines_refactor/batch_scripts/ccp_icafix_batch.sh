#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

#----- help function -----------------------------------
function usage () {
    echo -e "$0"
    echo -e "\t-h --help \t\t- prints help"
    echo -e "\t-f --InFile \t\t- configuration file\n\n"
}

#----- read command line options -----------------------
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
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done


#----- source environment setup for HCP Pipelines -----
. "${CCP_HOME}/setup/setup_hcp.sh"


if [[ ! -f "${CONFIG}" ]]; then
        error_exit "Cannot open file ${CONFIG}."
fi


FixScript="${FSL_FIXDIR}/hcp_fix"
StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjects=$(get_value "SUBJECTS_LIST" "${CONFIG}")

echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJECTS\t:\t${Subjects}"


bandpass=$(get_value "BANDPASS" ${CONFIG})
TrainingData=$(get_value "TRAINING_DATA" ${CONFIG})
bolds=$(get_value "BOLD_NAMES" ${CONFIG})

for Subject in $Subjects; do

	InputDir="${StudyFolder}/${Subject}/MNINonLinear/Results"

	for bold in $bolds; do

		echo "  ${bold}"
		InputFile="${InputDir}/${bold}/${bold}.nii.gz"

		if [[ ! -e "${InputFile}" ]]; then
			echo -e "WARNING : Cannot find file ${InputFile}. Will skip it."
		else


			HCP_COMMAND="${FixScript} ${InputFile} ${bandpass} ${TrainingData}"

			echo
			echo -e "HCP PIPELINES COMMAND :\n"
			echo "${HCP_COMMAND}"
			echo


	#if use FSL_QUEUE; then
	#	"QUEUE="-q hcp_priority.q"
	#	queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	#	${queuing_command} ${FixScript} ${InputFile} ${bandpass} ${TrainingData}

	#else

# ====================== create pbs script ===================
############# HERE FILE ########
cat > "${Subject}_${bold}_icafix.pbs" << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=1,mem=20gb,vmem=20gb,walltime=24:00:00
#PBS -N ${Subject}_${bold}_icafix
#PBS -j oe
#PBS -o ${Subject}_${bold}_icafix.log


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


. "${CCP_HOME}/mylib/myfunctions.lib"
. "${CCP_HOME}/setup/setup_hcp.sh"

${HCP_COMMAND}

wait
chmod -R 775 ${StudyFolder}/${Subject}

EOF

# ====================== end pbs script ===================


			if [  ! -z "${qsub_flag}" ]; then
				chmod 750 "${Subject}_${bold}_icafix.pbs"
				qsub "${Subject}_${bold}_icafix.pbs"
			fi
		fi # series exist
	done # bolds
done # subjects
