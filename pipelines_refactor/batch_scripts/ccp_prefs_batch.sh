#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

#----- help function -----------------------------------------

function usage () {
	echo -e "./ccp_prefs.sh.sh"
	echo -e "\t-h --help \t\t- prints help"
	echo -e "\t-f --InFile \t\t- configuration file (mandatory)\n\n"
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
		-f | --InFile)
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

#----- read configuration file -------------------------------

if [[ ! -f "${CONFIG}" ]]; then
	error_exit "Cannot open file ${CONFIG}."
fi


StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjects=$(get_value "SUBJECTS_LIST" "${CONFIG}")

echo ""
echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJECTS\t:\t${Subjects}"
echo ""


#----- FROM HCP Pipelines ------------------------------------

# Readout Distortion Correction:
AvgrdcSTRING=$(get_value "AVGRDC_STRING" "${CONFIG}")

# Variables related to using Siemens specific Gradient Echo Field Maps
MagnitudeInputName=$(get_value "MAGNITUDE_INPUT_NAME" "${CONFIG}")
PhaseInputName=$(get_value "PHASE_INPUT_NAME" "${CONFIG}")

TE=$(get_value "TE" "${CONFIG}")

#   Variables related to using Spin Echo Field Maps
SpinEchoPhaseEncodeNeg=$(get_value "SPIN_ECHO_NEG" "${CONFIG}")
SpinEchoPhaseEncodePos=$(get_value "SPIN_ECHO_POS" "${CONFIG}")


# Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples)
DwellTime=$(get_value "DWELL_TIME" "${CONFIG}") # 0.000580002668012

# Spin Echo Unwarping Direction
# Note: +x or +y are not supported. For positive values, do not include the + sign
SEUnwarpDir=$(get_value "SE_UNWARP_DIR" "${CONFIG}")   # "x"

# Topup Configuration file
TopupConfig=$(get_value "TOPUP_CONFIG" "${CONFIG}")

# General Electric stuff
GEB0InputName=$(get_value "GEB0_INPUT_NAME" "${CONFIG}")

# Templates
T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz" #Hires T1w MNI template
T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz" #Hires brain extracted MNI template
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" #Lowres T1w MNI template
T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz" #Hires T2w MNI Template
T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz" #Hires T2w brain extracted MNI Template
T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz" #Lowres T2w MNI Template
TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz" #Hires MNI brain mask template
Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #Lowres MNI brain mask template

# Structural Scan Settings (set all to NONE if not doing readout distortion correction)
# The values set below are for the HCP Protocol using the Siemens Connectom Scanner
T1wSampleSpacing=$(get_value "T1W_SAMPLE_SPACING" "${CONFIG}") #DICOM field (0019,1018) in s or "NONE" if not used
T2wSampleSpacing=$(get_value "T2W_SAMPLE_SPACING" "${CONFIG}") #DICOM field (0019,1018) in s or "NONE" if not used
UnwarpDir=$(get_value "UNWARP_DIR" "${CONFIG}") # z appears to be best for Siemens Gradient Echo Field Maps or "NONE" if not used

# Other Config Settings
BrainSize=$(get_value "BRAIN_SIZE" "${CONFIG}") #BrainSize in mm, 150 for humans
FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config

GradientDistortionCoeffs=$(get_value "GRADIENT_DISTORTION_COEFFS" "${CONFIG}") # Set to NONE to skip gradient distortion correction


for Subject in $Subjects; do
	echo -e "\nSubject\t:\t${Subject}\n"

	# T1w images
	numT1ws=$(ls "${StudyFolder}/${Subject}/unprocessed/3T" | grep -c T1w_MPR )
	echo "Found ${numT1ws} T1w Images for subject ${Subject}"
	T1wInputImages=""
	i=1
	while [ $i -le "$numT1ws" ] ; do
		T1wInputImages=$(echo "${T1wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR${i}/${Subject}_3T_T1w_MPR${i}.nii.gz@")
		i=$((i+1))
	done

	# T2w images
	numT2ws=$(ls "${StudyFolder}/${Subject}/unprocessed/3T" | grep -c T2w_SPC )
	echo "Found ${numT2ws} T2w Images for subject ${Subject}"
	T2wInputImages=""
	i=1
	while [ $i -le "$numT2ws" ] ; do
		T2wInputImages=$(echo "${T2wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC${i}/${Subject}_3T_T2w_SPC${i}.nii.gz@")
		i=$((i+1))
	done

	# Field Maps
	if [[ "${MagnitudeInputName}" != "NONE" ]]; then
		MagnitudeInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${MagnitudeInputName}"
		PhaseInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${PhaseInputName}"
	fi

	if [[ "${SpinEchoPhaseEncodePositive}" != "NONE" ]]; then
	SpinEchoPhaseEncodeNegative="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_${SpinEchoPhaseEncodeNeg}"
	SpinEchoPhaseEncodePositive="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_${SpinEchoPhaseEncodePos}"
	fi


#----- generate command to execute ---------------------------

read -r -d '' HCP_COMMAND << EOF
${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \\
	--path=$StudyFolder \\
	--subject=$Subject \\
	--t1=$T1wInputImages \\
	--t2=$T2wInputImages \\
	--t1template=$T1wTemplate \\
	--t1templatebrain=$T1wTemplateBrain \\
	--t1template2mm=$T1wTemplate2mm \\
	--t2template=$T2wTemplate \\
	--t2templatebrain=$T2wTemplateBrain \\
	--t2template2mm=$T2wTemplate2mm \\
	--templatemask=$TemplateMask \\
	--template2mmmask=$Template2mmMask \\
	--brainsize=$BrainSize \\
	--fnirtconfig=$FNIRTConfig \\
	--fmapmag=$MagnitudeInputName \\
	--fmapphase=$PhaseInputName \\
	--echodiff=$TE \\
	--SEPhaseNeg=$SpinEchoPhaseEncodeNegative \\
	--SEPhasePos=$SpinEchoPhaseEncodePositive \\
	--echospacing=$DwellTime \\
	--seunwarpdir=$SEUnwarpDir \\
	--t1samplespacing=$T1wSampleSpacing \\
	--t2samplespacing=$T2wSampleSpacing \\
	--unwarpdir=$UnwarpDir \\
	--gdcoeffs=$GradientDistortionCoeffs \\
	--avgrdcmethod=$AvgrdcSTRING \\
	--topupconfig=$TopupConfig \\
	--printcom=$PRINTCOM

EOF

	echo
	echo -e "HCP PIPELINES COMMAND :\n"
	echo "${HCP_COMMAND}"
	echo

# ====================== create pbs script ===================
############# HERE FILE ########
cat > ${Subject}_prefs.pbs << EOF
#!/bin/bash
#PBS -l nodes=1:ppn=1,mem=5gb,vmem=10gb,walltime=4:00:00
#PBS -N ${Subject}_prefs
#PBS -j oe
#PBS -o ${Subject}_prefs.log

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

	if [ ! -z "${qsub_flag}" ]; then
		# qsub_flag=1
		chmod 750 "${Subject}_prefs.pbs"
		qsub "${Subject}_prefs.pbs"
	fi


done # for Subjects
