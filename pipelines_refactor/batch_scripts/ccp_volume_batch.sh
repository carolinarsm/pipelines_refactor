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

#----- source environment setup for HCP Pipelines ------------

. "${CCP_HOME}/setup/setup_hcp.sh"

if [[ ! -f "${CONFIG}" ]]; then
        error_exit "Cannot open file ${CONFIG}."
fi

StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjects=$(get_value "SUBJECTS_LIST" "${CONFIG}")


echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJECTS\t:\t${Subjects}"
echo -e "PRINTCOM\t:\t${PRINTCOM}"

#----- read configuration file -------------------------------
#----- FROM HCP Pipelines ------------------------------------

Tasklist=$(get_value "TASK_LIST" "${CONFIG}")
PhaseEncodinglist=$(get_value "PHASE_ENCODING_LIST" "${CONFIG}") #x for RL, x- for LR, y for PA, y- for AP

DwellTime=$(get_value "DWELL_TIME" "${CONFIG}") #Echo Spacing or Dwelltime of fMRI image, set to NONE if not used. Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode$
DistortionCorrection=$(get_value "DISTORTION_CORRECTION" "${CONFIG}") #FIELDMAP or TOPUP, distortion correction is required for accurate processing
BiasCorrection=$(get_value "BIAS_CORRECTION" "${CONFIG}")

SEPhaseEncodeNegative=$(get_value "SPIN_ECHO_NEG" "${CONFIG}")
SEPhaseEncodePositive=$(get_value "SPIN_ECHO_POS" "${CONFIG}")

MagnitudeInputName=$(get_value "MAGNITUDE_INPUT_NAME" "${CONFIG}") #Expects 4D Magnitude volume with two 3D timepoints, set to NONE if using TOPUP
PhaseInputName=$(get_value "PHASE_INPUT_NAME" "${CONFIG}") #Expects a 3D Phase volume, set to NONE if using TOPUP

DeltaTE=$(get_value "DELTA_TE" "${CONFIG}") #2.46ms for 3T, 1.02ms for 7T, set to NONE if using TOPUP
FinalFMRIResolution=$(get_value "FINAL_FMRI_RESOLUTION" "${CONFIG}") #Target final resolution of fMRI data. 2mm is recommended for 3T HCP data, 1.6mm for 7T HCP data (i.e. should match acquired resolution).  Use 2.0 or 1.0 to avoid standard FSL $

GradientDistortionCoeffs=$(get_value "GRADIENT_DISTORTION_COEFFS" "${CONFIG}") #Gradient distortion correction coefficents, set to NONE to turn off
TopUpConfig=$(get_value "TOPUP_CONFIG" "${CONFIG}") #Topup config if using TOPUP, set to NONE if using regular FIELDMAP

MCType=$(get_value "MC_TYPE" "${CONFIG}")

for Subject in $Subjects; do

	i=1
	for fMRIName in $Tasklist ; do
		echo "  ${fMRIName}"
		UnwarpDir=$(echo $PhaseEncodinglist | cut -d " " -f $i)
		fMRITimeSeries="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${fMRIName}.nii.gz"

		if [[ ! -e "${fMRITimeSeries}" ]]; then
			echo -e "WARNING : Cannot find ${fMRITimeSeries}. Will skip it.\n"
		else

			fMRISBRef="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${fMRIName}_SBRef.nii.gz" #A single band reference image (SBRef) is recommended if using multiband, set to NONE if you want to use the first volume of the timeseries for motion correction
			SpinEchoPhaseEncodeNegative="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${SEPhaseEncodeNegative}" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data, AP in 7T HCP data), set to NONE if using regular FIELDMAP
			SpinEchoPhaseEncodePositive="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${SEPhaseEncodePositive}" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data, PA in 7T HCP data), set to NONE if using regular FIELDMAP

#----- generate command to execute ---------------------------

read -r -d '' HCP_COMMAND << EOF
${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \\
    --path=$StudyFolder \\
    --subject=$Subject \\
    --fmriname=$fMRIName \\
    --fmritcs=$fMRITimeSeries \\
    --fmriscout=$fMRISBRef \\
    --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \\
    --SEPhasePos=$SpinEchoPhaseEncodePositive \\
    --fmapmag=$MagnitudeInputName \\
    --fmapphase=$PhaseInputName \\
    --echospacing=$DwellTime \\
    --echodiff=$DeltaTE \\
    --unwarpdir=$UnwarpDir \\
    --fmrires=$FinalFMRIResolution \\
    --dcmethod=$DistortionCorrection \\
    --gdcoeffs=$GradientDistortionCoeffs \\
    --topupconfig=$TopUpConfig \\
    --printcom=$PRINTCOM \\
    --biascorrection=$BiasCorrection \\
    --mctype=${MCType}

EOF

			echo
			echo -e "HCP PIPELINES COMMAND :\n"
			echo "${HCP_COMMAND}"
			echo

# ====================== create pbs script ===================

############# HERE FILE ########
cat > ${Subject}_${fMRIName}_volume.pbs << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=1,mem=20gb,vmem=20gb,walltime=24:00:00
#PBS -N ${Subject}_${fMRIName}_hcp_volume
#PBS -j oe
#PBS -o ${Subject}_${fMRIName}_volume.log

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
# ====================== end pbs script ===================

#----- submit to cluster queue -------------------------------

			if [  ! -z "${qsub_flag}" ]; then
				chmod 750 "${Subject}_${fMRIName}_volume.pbs"
				qsub "${Subject}_${fMRIName}_volume.pbs"
			fi
		fi # series exist

    	i=$(($i+1))
	done # Tasks
done # Subjects
