#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

#----- help function -----------------------------------------

function usage () {
    echo -e "./ccp_postfs.sh"
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
            CONFIG="$(dirname "${VALUE}")/$(basename "${VALUE}")"
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
. "${CCP_HOME}/setup/setup_hcp.sh"      # sources environment for ccp_hcp --> done in pbs script too to be able to launch pbs script independently

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

#Input Variables
SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
GrayordinatesResolutions=$(get_value "GRAYORDINATES_RESOLUTION" "${CONFIG}") #Usually 2mm, if multiple delimit with @, must already exist in templates dir
HighResMesh="164" #Usually 164k vertices
LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
# RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
RegName=$(get_value "REG_NAME" "${CONFIG}")



for Subject in $Subjects; do


#----- generate command to execute ---------------------------

read -r -d '' HCP_COMMAND << EOF
${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh \\
    --path=$StudyFolder \\
    --subject=$Subject \\
    --surfatlasdir=$SurfaceAtlasDIR \\
    --grayordinatesdir=$GrayordinatesSpaceDIR \\
    --grayordinatesres=$GrayordinatesResolutions \\
    --hiresmesh=$HighResMesh \\
    --lowresmesh=$LowResMeshes \\
    --subcortgraylabels=$SubcorticalGrayLabels \\
    --freesurferlabels=$FreeSurferLabels \\
    --refmyelinmaps=$ReferenceMyelinMaps \\
    --regname=$RegName \\
    --printcom=$PRINTCOM

EOF

	echo
	echo -e "HCP PIPELINES COMMAND :\n"
	echo "${HCP_COMMAND}"
	echo


# ====================== create pbs script ===================
############# HERE FILE ########
cat > ${Subject}_postfs.pbs << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=1,mem=10gb,vmem=10gb,walltime=3:00:00
#PBS -N ${Subject}_postfs
#PBS -j oe
#PBS -o ${Subject}_postfs.log

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
chmod -Rf 775 "${StudyFolder}/${Subject}"

EOF

#----- submit to cluster queue -------------------------------
	if [  ! -z "${qsub_flag}" ]; then
		chmod 750 "${Subject}_postfs.pbs"
		qsub "${Subject}_postfs.pbs"
	fi

done # for subjects

