#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"
#################### FUNCTIONS ####################
# print help
function usage () {
#    echo -e "TO DO: edit this help\n\n"
    echo -e "$0"
    echo -e "\t-h --help \t\t- prints help"
    echo -e "\t-f --InFile \t\t- configuration file\n\n"
}

#################### COMMAND LINE OPTIONS AND CONFIGURATION FILES ####################
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -f | --InFile) #dicoms
            CONFIG="$(dirname $VALUE)/$(basename $VALUE)"
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

################ ENVIRONMENT/OTHER VARIABLES SETUP #######################

. "${CCP_HOME}/setup/setup_hcp.sh"      # sources variables for HCP Pipelines


StudyFolder=$(get_value "STUDY_FOLDER" "${CONFIG}")
Subjlist=$(get_value "SUBJLIST" "${CONFIG}")
PRINTCOM=$(get_value "PRINTCOM" "${CONFIG}")


echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "STUDY FOLDER\t:\t${StudyFolder}"
echo -e "SUBJ LIST\t:\t${Subjlist}"
echo -e "PRINTCOM\t:\t${PRINTCOM}"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

TaskNameList=$(get_value "TASKNAMELIST" "${CONFIG}")
#TaskNameList=""
#TaskNameList="${TaskNameList} BOLD1"
#TaskNameList="${TaskNameList} EMOTION"
#TaskNameList="${TaskNameList} GAMBLING"
#TaskNameList="${TaskNameList} LANGUAGE"
#TaskNameList="${TaskNameList} MOTOR"
#TaskNameList="${TaskNameList} RELATIONAL"
#TaskNameList="${TaskNameList} SOCIAL"
#TaskNameList="${TaskNameList} WM"

for TaskName in ${TaskNameList}
do
	LevelOneTasksList="tfMRI_${TaskName}_RL@tfMRI_${TaskName}_LR" 	#Delimit runs with @ and tasks with space
	LevelOneFSFsList="tfMRI_${TaskName}_RL@tfMRI_${TaskName}_LR" 	#Delimit runs with @ and tasks with space
	LevelTwoTaskList="tfMRI_${TaskName}" #Space delimited list
	LevelTwoFSFList="tfMRI_${TaskName}" #Space delimited list

# [TO DO]: Modify next part to read from .cfg file

	SmoothingList=$(get_value "SMOOTHING_FWHM" "${CONFIG}") #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
	LowResMesh="32" #32 if using HCP minimal preprocessing pipeline outputs
	GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
	OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
	Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
	TemporalFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI
	VolumeBasedProcessing=$(get_value "VOLUME_BASED" "${CONFIG}") #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  
	RegNames="NONE" # Use NONE to use the default surface registration
	ParcellationList="NONE" # Use NONE to perform dense analysis, non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation superseeds smoothing (i.e. smoothing is done)
	ParcellationFileList="NONE" # Absolute path the parcellation dlabel file


	for RegName in ${RegNames} ; do
		j=1
		for Parcellation in ${ParcellationList} ; do
			ParcellationFile=`echo "${ParcellationFileList}" | cut -d " " -f ${j}`

			for FinalSmoothingFWHM in $SmoothingList ; do
				echo $FinalSmoothingFWHM
				i=1
				for LevelTwoTask in $LevelTwoTaskList ; do
					echo "  ${LevelTwoTask}"

					LevelOneTasks=`echo $LevelOneTasksList | cut -d " " -f $i`
					LevelOneFSFs=`echo $LevelOneFSFsList | cut -d " " -f $i`
					LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
					LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`

					for Subject in $Subjlist ; do
						echo "    ${Subject}"

						${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh \
						    --path=$StudyFolder \
						    --subject=$Subject \
						    --lvl1tasks=$LevelOneTasks \
						    --lvl1fsfs=$LevelOneFSFs \
						    --lvl2task=$LevelTwoTask \
						    --lvl2fsf=$LevelTwoFSF \
						    --lowresmesh=$LowResMesh \
						    --grayordinatesres=$GrayOrdinatesResolution \
						    --origsmoothingFWHM=$OriginalSmoothingFWHM \
						    --confound=$Confound \
						    --finalsmoothingFWHM=$FinalSmoothingFWHM \
						    --temporalfilter=$TemporalFilter \
						    --vba=$VolumeBasedProcessing \
						    --regname=$RegName \
						    --parcellation=$Parcellation \
						    --parcellationfile=$ParcellationFile

					done

					i=$(($i+1))

				done

			done

			j=$(( ${j}+1 ))

		done

	done

done
