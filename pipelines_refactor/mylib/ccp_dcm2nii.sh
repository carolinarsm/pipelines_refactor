#!/bin/bash 

#. ${CCP_HOME}/mylib/myfunctions.sh
# export DCM2NII="/export/MRIcron/dcm2nii" 		# it is exported in batch job, read from configuration file for ccp_dcm2nii_batch.sh
# TO DO: XOR of input arguments (init file XOR IN-OUT dirs) 
# put some system specific options here?
# Add line to catch arguments with wrong names (ex: Outdir instead of OutDir). Else, we get infinite loops in the while inside get_batch_options.
# Create automatic ini files? -> preferred method, to avoid human errors.
function usage()
{
    echo ""
    echo -e "./ccp_dcm2nii.sh"
    echo -e "Usage:\n\t./ccp_dcm2nii.sh --DicomFolder=<dicom folder name> --OutDir=<output folder name>"
    echo -e "\t./ccp_dcm2nii --IniFile=<filename.ini>\n"
    echo -e "Parameters:\n"
    echo -e "\tDicomFolder\t:\tinput folder containing dicom files"
    echo -e "\tOutDir\t\t:\toutput folder for generated NIFTI files"
    echo -e "\tIniFile\t\t:\tdcm2nii configuration file"
    echo ""
}

get_batch_options() {
    local arguments=($@)
    # echo ${arguments[0]}
    # echo ${arguments[1]}
    unset command_line_specified_input_folder
    unset command_line_specified_output_folder
    unset command_line_specified_ini_file

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    if [[ numArgs -eq 0 ]]; then
	echo "ERROR : No arguments given"
	usage
	exit 1
    fi

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}
        case ${argument} in
	    --help)
		usage
		exit
		;;
            --DicomFolder=*)
                command_line_specified_input_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --OutDir=*)
                command_line_specified_output_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --IniFile=*)
                command_line_specified_ini_file=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
	    *)
	        echo "ERROR: unknown parameter \"$argument\""
	        usage
	        exit 1
	        ;;
        esac
    done
}
get_batch_options $@


 set +x			# stop debugging from here

if [ -n "${command_line_specified_input_folder}" ]; then
	echo -e "Input Folder\t: ${command_line_specified_input_folder}"
    DicomFolder="${command_line_specified_input_folder}"
fi

if [ -n "${command_line_specified_output_folder}" ]; then
	echo -e "Output Folder\t: ${command_line_specified_output_folder}"
    OutDir="${command_line_specified_output_folder}"
fi

if [ -n "${command_line_specified_ini_file}" ]; then
		echo -e ".ini file\t: ${command_line_specified_run_local}\n\n"
    IniFile="${command_line_specified_ini_file}"
fi

# If output directory specified in .ini file doesn't exist, Niftis will be written to source directory

# Required:
# TODO: check dcm2nii exists and is part of the environment, or assign just like here:

# log originating call
echo "$@"


########################################## INPUTS ########################################## 

# This script will run dcm2nii on all the dicoms in the input folder, up to certain depth (default=5)
# Defaults are set up in the code, but can be overrun if an .ini file is given
#
# Defaults
#	decm2nii -4 y \			# Create 4D volumes
# 	-a y \ 				# Anonymize 
# 	-b /mydirpath/ccp_dcm2nii.ini \	# load settings from specified inifile,  '-b mydir/ccp_dcm2nii.ini'  
# 	(-c ? 				# Collapse input folders: Y,N = Y)
# 	-d y \				# Date in filenamame
# 	-e y \				# events (series/acq) in filename [filename.dcm -> s002a003.nii]: Y,N = Y
# 	(-f 				# Source filename [e.g. filename.par -> filename.nii]: Y,N = N)
# 	-g y \				# gzip output, filename.nii.gz [ignored if '-n n']: Y,N = Y
# 	(-i n\				# ID  in filename [filename.dcm -> johndoe.nii]: Y,N = N)
# 	-m n \ 				# manually prompt user to specify output format [NIfTI input only]: Y,N = Y
# 	(-n y \				# output .nii file [if no, create .hdr/.img pair]: Y,N = Y)
# 	-o '/myoutdirpath' \ 		# Output Directory, e.g. 'C:\TEMP' (if unspecified, source directory is used)
# 	-p y \				# Protocol in filename [filename.dcm -> TFE_T1.nii]: Y,N = Y
# 	-r n \				# Reorient image to nearest orthogonal: Y,N 
# 	(-s 				# SPM2/Analyze not SPM5/NIfTI [ignored if '-n y']: Y,N = N)
# 	-v y \				# Convert every image in the directory: Y,N = Y
# 	-x n \				# Reorient and crop 3D NIfTI images: Y,N = N
#

######################################### DO WORK ##########################################


#
if [ -n "${command_line_specified_ini_file}" ] ; then
	#this option includes the OutputDir in the .ini file
      echo -e "Loading configuration from ${IniFile} file\nStarting DICOM to NIfTI conversion."
	  echo -e "Dicoms: ${DicomFolder}"
      ${DCM2NII} -b ${IniFile} ${DicomFolder}

else
	echo -e "Starting DICOM to NIfTI conversion."
	echo "Dicoms: ${DicomFolder}"
	echo "Output Folder: ${OutDir}"
	# echo "Dicoms: ${DicomFolder}"
	${DCM2NII} -4 y \
	-a y \
	-d y \
	-e y \
	-g n \
	-m n \
	-n y \
	-o "${OutDir}" \
	-p y \
	-r n \
	-v y \
	-x n \
	${DicomFolder}
fi

set +x


IMAGE=$(ls "${OutDir}" | grep -i -E '\.(nii)$' | head -1)
echo -e "Output NII image\t:\t${IMAGE}"
# gzip "${OutDir}/*"
######################################### TO FIX ##########################################
# dcm Error: not a DICOM image: dicoms/17/.DS_Store , yup those mac osx files of doom
# dcm Error: not a DICOM image: dicoms/.DS_Store
#
# After getting NIFTIs, visual QA needs to be done to check for orientations.

# add fslreorient2std, to mimic HCP conversion pipeline?

