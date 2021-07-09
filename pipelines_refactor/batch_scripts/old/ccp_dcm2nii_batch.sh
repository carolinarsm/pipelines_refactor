#!/bin/bash -x

# This version is for series grouped by task/rest and both phases together (each rest/task folder contains both phase encodings)
# CCP_HOME must be set in user's environment
. ${CCP_HOME}/mylib/myfunctions.sh 		# to .lib?

#################### FUNCTIONS ####################
# print help
function usage () {
#    echo -e "TO DO: edit this help\n\n"
    echo -e "./ccp_dcm2nii_batch.sh"
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

# Source environment for dicom conversion
#SETUP=$(get_value "SETUP_DCM2NII" "${CONFIG}")
#echo ""
#echo -e "SETUP SCRIPT\t:\t${SETUP}\n"

. ${CCP_HOME}/setup/setup_dcm2nii.sh	# sources dcm2nii, ccp_dcm2nii, dicom_hinfo

# hard coded these. Need updating to handle gradient fieldmaps
DISCARD_WORDS="localizer bias aahscout scout nav norm dwi secondary derived" # LIST OF DESCRIPTORS FOR IMAGES THAT SHOUDLN'T BE USED (lower case)
#SERIES_TYPES="spin rfmri t1w t2w tfmri"
SERIES_TYPES="fieldmap rfmri t1w t2w tfmri"


# read these from configuration file
SUB_ID=$(get_value "SUB_ID" "${CONFIG}")
IN_DIR=$(get_value "IN_DIR" "${CONFIG}")
OUT_DIR=$(get_value "OUT_DIR" "${CONFIG}")
FIELD=$(get_value "FIELD" "${CONFIG}")
PRINTCOM=$(get_value "PRINTCOM" ${CONFIG})
echo -e "DCM2NII\t\t:\t${DCM2NII}"
echo -e "CCP_DCM2NII\t:\t${CCP_DCM2NII}"
echo -e "DICOM_HINFO\t:\t${DICOM_HINFO}"

echo -e "CONFIG FILE\t:\t${CONFIG}"
echo -e "SUBJECT ID\t:\t${SUB_ID}"
echo -e "INPUT DIR\t:\t${IN_DIR}"
echo -e "OUT DIR\t\t:\t${OUT_DIR}"
echo -e "FIELD\t\t:\t${FIELD}"


if [[ ${PRINTCOM} == "echo" ]]; then
	exit 0
fi

# check folders
if [ ! -d "$IN_DIR" ]; then
  echo -e "ERROR\t:\t${IN_DIR} doesn't exist. Please, specify a valid input directory"
  usage
  exit 1
fi

OUT_DIR="${OUT_DIR}/${SUB_ID}/unprocessed/3T"
mkdir -p $OUT_DIR


#################### MAIN ####################
PREFIX="${SUB_ID}_${FIELD}_"
echo -e "PREFIX\t\t:\t${PREFIX}"



## EXTRACTING VALID SERIES ##
TFILE=$(mktemp)

for k in $(ls ${IN_DIR}); do 			# DEBUG	: folder must ONLY contain the numbered series directories

        SERIES_DIR="${IN_DIR}/${k}/DICOM" 	# DEBUG	: works with this pattern only (for now)
        if [ ! -d "$IN_DIR" ]; then
            echo "Error: Folder ${SERIES_DIR} doesn't exist "
            usage
            exit 1
        fi

	IMAGE=$(ls "${SERIES_DIR}" | grep -i -E '\.(dcm)$' 2>/dev/null | head -1)			# SELECT ONE IMAGE OF THE DICOM FOLDER TO EXTRACT HEADER INFO
	SubjID=$(${DICOM_HINFO} -no_name -tag 0010,0020 ${SERIES_DIR}/${IMAGE})		# Reding DICOM header tags
	Description=$(${DICOM_HINFO} -no_name -tag 0008,103e ${SERIES_DIR}/${IMAGE})
	Protocol=$(${DICOM_HINFO} -no_name -tag 0018,1030 ${SERIES_DIR}/${IMAGE})
	SeriesNum=$(${DICOM_HINFO} -no_name -tag 0020,0011 ${SERIES_DIR}/${IMAGE})
	ImgType=$(${DICOM_HINFO} -no_name -tag 0008,0008 ${SERIES_DIR}/${IMAGE})
	Sequence=$(${DICOM_HINFO} -no_name -tag 0018,0020 ${SERIES_DIR}/${IMAGE})
	SeriesUID=$(${DICOM_HINFO} -no_name -tag 0020,000e ${SERIES_DIR}/${IMAGE})
	seriesDate=$(${DICOM_HINFO} -no_name -tag 0008,0022 ${SERIES_DIR}/${IMAGE})
	seriesTime=$(${DICOM_HINFO} -no_name -tag 0008,0031 ${SERIES_DIR}/${IMAGE})


	echo ""
	echo -e "\tImage Type: ${ImgType}"
	echo -e "\tProtocol:	${Protocol}"
	echo -e "\tDescription: ${Description}"

	# Check if any of these fields contains a word that indicates that it's not an image of interest (see $DISCARD_WORDS)
	if contains_substring "${ImgType}" "${DISCARD_WORDS}" || contains_substring "${Protocol}" "${DISCARD_WORDS}" || contains_substring "${Description}" "${DISCARD_WORDS}"; then
		echo "Triple test is TRUE. Series is invalid"
	else
		echo "Triple test is FALSE. Series is valid"
    		printf "%s %s %s %s %s %s\n" \
                	"${seriesDate}" \
			"${seriesTime}" \
                	"${Description}" \
			"${SeriesNum}" \
			"${SERIES_DIR}" \
			"${OUT_DIR}" >> $TFILE
	fi

done #for all the series in the DICOM folder

# SORTING TABLE BY FIELDS (date.time, name, series number)
if [[ -e "sorted.txt" ]]; then
	rm sorted.txt
fi

sort -k 1,1 -k 2,2g -k 3,3 $TFILE  > sorted.txt # DEBUG: make this a temporal file too?
rm -rf $TFILE

cat sorted.txt


echo "Dicom series parsed..."

## GET INFO FROM THE SORTED LIST OF VALID SERIES
LIST="sorted.txt"

#number of experiments of each type
total_spinecho=$(($(grep -ic "fieldmap" "${LIST}")/2))
total_t1=$(grep -ic "T1w" "${LIST}")
total_t2=$(grep -ic "T2w" "${LIST}")
total_rest=$(($(grep -ic "rfMRI" "${LIST}")/4))
total_task=$(($(grep -ic "tfMRI" "${LIST}")/4))

# line numbers of each series type in the sorted list file
lineSPIN=$(grep -in "fieldmap" "${LIST}" |cut -f1 -d:)
lineT1W=$(grep -in "t1w" "${LIST}" |cut -f1 -d:)
lineT2W=$(grep -in "t2w" "${LIST}" |cut -f1 -d:)
lineREST=$(grep -in "rfmri" "${LIST}" |cut -f1 -d:)
lineTASK=$(grep -in "tfmri" "${LIST}" |cut -f1 -d:)
# to array
lineSPIN=(${lineSPIN})
lineT1W=(${lineT1W})
lineT2W=(${lineT2W})
lineREST=(${lineREST})
lineTASK=(${lineTASK})

# arrays that will contain the series numbers of each type
num_seriesSPIN=()
num_seriesT1W=()
num_seriesT2W=()
num_seriesREST=()
num_seriesTASK=()
# arrays that will contain the series names of each type
nameSPIN=()
nameT1W=()
nameT2W=()
nameREST=()
nameTASK=()


# read the sorted file line by line and fill the arrays
echo ""
while read LINE; do

    	arr=(${LINE})
    	seriesName=${arr[2]}
    	seriesNumber=${arr[3]}
    	result=''
    	return_match_string "${seriesName}" "${SERIES_TYPES}" result

   	case $result in

#     		spin)
     		fieldmap)
	  		num_seriesSPIN=( "${num_seriesSPIN[@]}" "$seriesNumber" )
          		nameSPIN=( "${nameSPIN[@]}" "$seriesName" )
                        ;;
     		t1w)
	  		num_seriesT1W=( "${num_seriesT1W[@]}" "$seriesNumber" )
          		nameT1W=( "${nameT1W[@]}" "$seriesName" )
          		;;
     		t2w)
	  		num_seriesT2W=( "${num_seriesT2W[@]}" "$seriesNumber" )
          		nameT2W=( "${nameT2W[@]}" "$seriesName" )

          		;;
     		rfmri)
	  		num_seriesREST=( "${num_seriesREST[@]}" "$seriesNumber" )
	  		nameREST=( "${nameREST[@]}" "$seriesName" )
          		;;
     		tfmri)
	  		num_seriesTASK=( "${num_seriesTASK[@]}" "$seriesNumber" )
	  		nameTASK=( "${nameTASK[@]}" "$seriesName" )
          		;;
     		*)
          		echo "Not a valid series type"
          		exit 1
          		;;
   	esac
       echo -e "## LINE ## '${LINE}' ## MATCHED AS ## '${result}' ##"  # example: '20140714 110124.484000 rfMRI_REST_RL_SBRef 11 DATA/SCANS_DICOM/11/DICOM ./OUTPUT/LS5179_V1_A'
done < ${LIST}




#######################################################################################################################################
## DICOM TO NIFTI AND MOVE TO NIFTI FOLDERS ##


TFILE=$(mktemp)
echo ""
echo -e "\n\n###### Starting DICOM to NIFTI conversion ######"
echo -e "this may take a few minutes\n\n"
echo ""

## FM ##
########
for ((i=1; i<=${total_spinecho}; ++i )) ; do

	nii_folder="${OUT_DIR}/FieldMap${i}"
	mkdir -p ${nii_folder}

	for k in {2..1}; do

        	idx=$((2*${i}-${k}))
        	TDIR=$(mktemp -d)

		echo -e "\n\n\n"
		echo -e "Converting series ${IN_DIR}/${num_seriesSPIN[$idx]}/DICOM to ${nii_folder}/${PREFIX}${nameSPIN[$idx]}.nii.gz"  
		# conversion to nifti
        	${CCP_DCM2NII} --DicomFolder="$IN_DIR/${num_seriesSPIN[$idx]}/DICOM" --OutDir="$TDIR" > /dev/null 2>&1
        	nii_exists=$(extension_exists "nii" "${TDIR}")
		echo -e "\nNII exists?\t:\t${nii_exists}"

		if $nii_exists; then
	                filename=$(find_nii "$TDIR")
			echo -e "NII filename\t:\t${filename}"
#			echo "Compressing NII files ....."
        	        gzip $filename
            		filename=$(find_niigz "${TDIR}")
#			echo "NII.GZ filename\t:\t${filename}"

            		cp "${filename}" "${nii_folder}/${PREFIX}${nameSPIN[$idx]}.nii.gz"
            		printf "%s %s\n" "${lineSPIN[$idx]}" "${nii_folder}/${PREFIX}${nameSPIN[$idx]}.nii.gz"  >> $TFILE
       		else
            		echo "ERROR: conversion of ${filename} from DICOM to NIFTI failed. Check folders."
            		exit 1
       		fi
		rm -rf $TDIR
    	done
done



## T1W ##
#########
for ((i=1; i<=${total_t1}; ++i )) ; do

	nii_folder="${OUT_DIR}/T1w_MPR${i}"
        mkdir -p $nii_folder

	idx=$((${i}-1))
	TDIR=$(mktemp -d)

	echo -e "\n\n\n"
	echo -e "Converting series ${IN_DIR}/${num_seriesT1W[$idx]}/DICOM to ${nii_folder}/${PREFIX}T1w_MPR${i}.nii.gz"
        ${CCP_DCM2NII} --DicomFolder="$IN_DIR/${num_seriesT1W[$idx]}/DICOM" --OutDir="${TDIR}" > /dev/null 2>&1
        nii_exists=$(extension_exists "nii" "${TDIR}")
	echo -e "\nNII exists?\t:\t${nii_exists}"

        if $nii_exists; then
                filename=$(find_nii "$TDIR")
		echo -e "NII filename\t:\t${filename}"
		echo "Compressing NII files ....."
                gzip $filename

		filename=$(find_niigz "${TDIR}")
		echo "NII.GZ filename\t:\t${filename}"	
 
            	cp "${filename}" "${nii_folder}/${PREFIX}T1w_MPR${i}.nii.gz"
            	printf "%s %s\n" "${lineT1W[$idx]}" "${nii_folder}/${PREFIX}T1w_MPR${i}.nii.gz"  >> $TFILE
       	else
            	echo "Error with dicom to nifti conversion. Check folders."
            	exit 1
       	fi
       	rm -rf $TDIR

done # for i

## T2W ##
#########
for ((i=1; i<=$total_t2; ++i )) ; do

        nii_folder="${OUT_DIR}/T2w_SPC${i}"
        mkdir -p $nii_folder

	idx=$((${i}-1))
        TDIR=$(mktemp -d)

	echo -e "\n\n\n"
	echo -e "Converting series ${IN_DIR}/${num_seriesT2W[$idx]}/DICOM to ${nii_folder}/${PREFIX}T2w_SPC${i}.nii.gz"
        ${CCP_DCM2NII} --DicomFolder="$IN_DIR/${num_seriesT2W[$idx]}/DICOM" --OutDir="$TDIR" > /dev/null 2>&1
        nii_exists=$(extension_exists "nii" "$TDIR") #check if there is a nii file in the origin folder
	echo -e "\nNII exists?\t:\t${nii_exists}"

	if $nii_exists ;then #if there is a nii, gzip it (gaziop failed with the option '-g y' used in dcm2nii directly for very large files)
		filename=$(find_nii "$TDIR")
                echo "NII filename\t:\t${filename}"
                echo "Compressing NII files ....."
		gzip $filename

		filename=$(find_niigz "${TDIR}")
		echo -e "NII.GZ filename\t:\t${filename}"

                cp "${filename}" "${nii_folder}/${PREFIX}T2w_SPC${i}.nii.gz"
                printf "%s %s\n" "${lineT2W[$idx]}" "${nii_folder}/${PREFIX}T2w_SPC${i}.nii.gz"  >> $TFILE

       	else
            	echo "Error with dicom to nifti conversion. Check folders."
            	exit 1
       	fi
	rm -rf $TDIR

done # for i



## BEFORE CONTINUING, SERIES POLARITY TYPE
# Determine if the series are RL/LR or AP/PA
polarity_type=$(series_polarity ${nameTASK[1]})

if contains_substring ${polarity_type} "_ap _pa"; then
	POS="AP"
	NEG="PA"
else
	POS="RL"
	NEG="LR"
fi

## REST ##
##########
for ((i=1; i<=$total_rest; ++i )) ; do              # each i --> $ 4 rest series (RL/AP standard and ref, LR/PA standard and Ref) 

#	nii_folder_RL="$OUT_DIR/rfMRI_REST${i}_RL"
#    	nii_folder_LR="$OUT_DIR/rfMRI_REST${i}_LR"
#    	mkdir -p $nii_folder_RL
#    	mkdir -p $nii_folder_LR

	mkdir -p "${OUT_DIR}/rfMRI_REST${i}_${POS}"
        mkdir -p "${OUT_DIR}/rfMRI_REST${i}_${NEG}"

    	for k in {4..1}; do

        	idx=$((4*${i}-${k}))
        	TDIR=$(mktemp -d) #one for each series!!!
		#[DEBUG]: testing this line here
		polarity=$(series_polarity ${nameREST[$idx]})

		echo -e "\n\n\n"
		echo -e "Converting series ${IN_DIR}/${num_seriesREST[$idx]}/DICOM to NIFTI; series name\t:\t$OUT_DIR/rfMRI_REST${i}${polarity}"
        	${CCP_DCM2NII} --DicomFolder="$IN_DIR/${num_seriesREST[$idx]}/DICOM" --OutDir="$TDIR" > /dev/null 2>&1
		nii_exists=$(extension_exists "nii" "$TDIR") 
		echo -e "\nNII exists?\t:\t${nii_exists}"


	        if $nii_exists; then
	                filename=$(find_nii "$TDIR")
			echo -e "NII filename\t:\t${filename}"
			echo "Compressing NII files ....."
        	        gzip $filename
                	filename=$(find_niigz "$TDIR") # this filename output includes full path from origin folder (not absolute)!!
			echo "NII.GZ filename\t:\t${filename}"			

#                	polarity=$(series_polarity ${nameREST[$idx]})

			if is_sbref ${nameREST[$idx]}; then
            			newname="rfMRI_REST${i}${polarity}_SBRef.nii.gz"
        		else
            			newname="rfMRI_REST${i}${polarity}.nii.gz"
        		fi

                	cp "${filename}" "$OUT_DIR/rfMRI_REST${i}${polarity}/${PREFIX}${newname}"
                	printf "%s %s\n" "${lineREST[$idx]}" "$OUT_DIR/rfMRI_REST${i}${polarity}/${PREFIX}${newname}"  >> $TFILE

       		else
            		echo "Error with dicom to nifti conversion. Check folders."
            		exit 1
       		fi
       		rm -rf $TDIR
    	done

done


## TASK ##
##########
for ((i=1; i<=${total_task}; ++i )) ; do

	task=$(echo "${nameTASK[4*${i}-4]}" | awk -F'_' '{print $2}')
#    	nii_folder_RL="${OUT_DIR}/tfMRI_${task}_RL"
#    	nii_folder_LR="$OUT_DIR/tfMRI_${task}_LR"
#    	mkdir -p $nii_folder_RL
#    	mkdir -p $nii_folder_LR

	mkdir -p "${OUT_DIR}/tfMRI_${task}_${POS}"
	mkdir -p "${OUT_DIR}/tfMRI_${task}_${NEG}"


    	for k in {4..1}; do
        	idx=$((4*${i}-${k}))
        	TDIR=$(mktemp -d)
		#[DEBUG]: testing this line here
		polarity=$(series_polarity ${nameTASK[$idx]})

		echo -e "\n\n\n"
		echo -e "Converting series ${IN_DIR}/${num_seriesTASK[$idx]}/DICOM to NIFTI; series name\t:\t$OUT_DIR/tfMRI_${task}${polarity}"
        	${CCP_DCM2NII} --DicomFolder="$IN_DIR/${num_seriesTASK[$idx]}/DICOM" --OutDir="$TDIR" > /dev/null 2>&1

              	#debug start
                ls -l $TDIR
                #debug end

        	nii_exists=$(extension_exists "nii" "$TDIR") #check if there is a nii.gz file in the origin folder
		echo -e "\nNII exists?\t:\t${nii_exists}"


        	if $nii_exists; then
	                filename=$(find_nii "$TDIR")
                        echo -e "NII filename\t:\t${filename}"
                        echo "Compressing NII files ....."
        	        gzip $filename # compress out of dcm2nii, because dcm2nii failed due to file size
                	filename=$(find_niigz "$TDIR") # this filename output includes full path from origin folder (not absolute)!!
                        echo "NII.GZ filename\t:\t${filename}"

#                	polarity=$(series_polarity ${nameTASK[$idx]})

                	if is_sbref ${nameTASK[$idx]}; then
                        	newname="tfMRI_${task}${polarity}_SBRef.nii.gz"
                	else
                        	newname="tfMRI_${task}${polarity}.nii.gz"
                	fi

                	cp "${filename}" "$OUT_DIR/tfMRI_${task}${polarity}/${PREFIX}${newname}"
                	printf "%s %s\n" "${lineTASK[$idx]}" "$OUT_DIR/tfMRI_${task}${polarity}/${PREFIX}${newname}"  >> $TFILE
       		else
            		echo "Error with dicom to nifti conversion. Check folders."
            		exit 1
       		fi
       		rm -rf $TDIR
    	done

done



echo -e "\n\n###### ENDED DICOM to NIFTI CONVERSION ######\n\n"
sort -k 1,1g $TFILE  > new_series_sorted.txt
rm -rf $TFILE


## ASSIGN SPIN ECHO PAIRS TO EACH BOLD AND STRUCTURAL
SE=()	# lines with the second spin echo of a pair
for ((i=0; i<=${total_spinecho}; ++i )) ; do
	idx=$((2*${i}+1))
	SE=( "${SE[@]}" "${lineSPIN[idx]}" )
done

echo ""
echo -e "SE\t:\t${SE[*]}"
echo ""

counter=0
while read LINE; do

    	line=(${LINE})
    	lowerline=$(echo ${line[1]} | awk '{print tolower($0)}')

    	if [[ $lowerline == *"fieldmap"* ]]; then

        	if [[ "${line[0]}" == "${SE[$counter]}" ]]; then
            		origin=$(dirname ${line[1]} )
            		echo -e "\n\nSPIN ECHO PAIR DETECTED IN ${origin}\n\n"
            		counter=$(($counter+1))
        	fi
    	else
        	destination=$(dirname ${line[1]})
        	cp ${origin}/*.nii.gz "${destination}"
        	echo -e "Copying ${origin} contents to ${destination}\n"
    	fi

done < new_series_sorted.txt


mv sorted.txt new_series_sorted.txt ${OUT_DIR}
exit 0

