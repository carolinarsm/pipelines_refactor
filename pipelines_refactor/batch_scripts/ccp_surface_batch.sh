#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

#----- help function -----------------------------------------

function usage () {
    echo -e "$0"
    echo -e "\t-h --help \t\t- prints help"
    echo -e "\t-f --InFile \t\t- configuration file\n\n"
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
            CONFIG="$(dirname $VALUE)/$(basename $VALUE)"
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

#----- source environment setup for HCP Pipelines ------------

. "${CCP_HOME}/setup/setup_hcp.sh"


if [[ ! -f "${CONFIG}" ]]; then
        error_exit "Cannot open file ${CONFIG}."
fi


#----- read configuration file -------------------------------

StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjects=$(get_value "SUBJECTS_LIST" "${CONFIG}")

echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJECTS\t:\t${Subjects}"

#----- FROM HCP Pipelines ------------------------------------

LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
FinalfMRIResolution=$(get_value "FINAL_FMRI_RESOLUTION" "${CONFIG}") #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
SmoothingFWHM=$(get_value "SMOOTHING_FWHM" "${CONFIG}") #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data
GrayordinatesResolution=$(get_value "GRAYORDINATES_RESOLUTION" "${CONFIG}") #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
RegName=$(get_value "REG_NAME" "${CONFIG}")

Tasklist=$(get_value "TASK_LIST" "${CONFIG}")

for Subject in $Subjects; do
	for fMRIName in $Tasklist ; do
	    fMRITimeSeries="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${fMRIName}.nii.gz"
    	    echo "  ${fMRIName}"

	    if [[ ! -e "${fMRITimeSeries}" ]]; then
		echo -e "WARNING: Cannot find ${fMRITimeSeries}. Will skip it."
	    else


#----- generate command to execute ---------------------------

read -r -d '' HCP_COMMAND << EOF
${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \\
    --path=$StudyFolder \\
    --subject=$Subject \\
    --fmriname=$fMRIName \\
    --lowresmesh=$LowResMesh \\
    --fmrires=$FinalfMRIResolution \\
    --smoothingFWHM=$SmoothingFWHM \\
    --grayordinatesres=$GrayordinatesResolution \\
    --regname=$RegName

EOF

			echo
			echo -e "HCP PIPELINES COMMAND :\n"
			echo "${HCP_COMMAND}"
			echo

# ====================== create pbs script ===================

############# HERE FILE ########
cat > ${Subject}_${fMRIName}_surface.pbs << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=1,mem=10gb,vmem=10gb,walltime=4:00:00
#PBS -N ${Subject}_${fMRIName}_surface
#PBS -j oe
#PBS -o ${Subject}_${fMRIName}_surface.log

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
chmod -R 775 ${StudyFolder}/${Subject}

EOF


#----- submit to cluster queue -------------------------------

			if [  ! -z "${qsub_flag}" ]; then
				chmod 750 "${Subject}_${fMRIName}_surface.pbs"
				qsub "${Subject}_${fMRIName}_surface.pbs"
			fi
		fi # series exist
	done # tasks
done # subjects
