#!/bin/bash

echo -e "Performing environment setup for dicom to nifti conversion step ..."
### CCP_HCP CODE
#export CCP_HOME="/home/ccp_hcp/hcp/ccp_cluster_user"

### PYTHON VIRTUAL ENVIRONMENT
export PATH="/home/ccp_hcp/Enthought/Canopy_64bit/User/bin:${PATH}"	# canopy virtual python env

### SOURCE MY LIB
. "${CCP_HOME}/mylib/myfunctions.lib"

### DCM2NII (MRIcron's dcm2nii)
export DCM2NII="/act/src/mricron/dcm2nii"
export PATH="/act/src/mricron:${PATH}"
#/act/src/mricron/dcm2nii

### CCP's DCM2NII
export CCP_DCM2NII="${CCP_HOME}/mylib/ccp_dcm2nii.sh"

### AFNI (AFNI's dicom_hinfo)
export DICOM_HINFO="/act/src/AFNI-20150722/linux_openmp_64/dicom_hinfo"

### FSL
export FSLDIR=/act/fsl-5.0.8/
export FSL_DIR="${FSLDIR}"
. ${FSLDIR}/etc/fslconf/fsl.sh


### FREESURFER
export FREESURFER_HOME="/act/freesurfer-5.3.0-HCP"
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1		# newcluster


### Some feedback

echo ""
echo -e "Environment Setup:"
PYTHON_VERSION=$(which python)
FSL_VERSION=$(which fsl)
FREESURFER_VERSION=$(which freesurfer)
DCM2NII_VERSION=$(which dcm2nii)
DICOMHINFO_VERSION=$(which dicom_hinfo)


echo ${PATH}
echo -e "CCP_HOME\t:\t${CCP_HOME}"
echo -e "PYTHON version\t:\t${PYTHON_VERSION}"
echo -e "FSLDIR\t\t:\t${FSL_VERSION}"
echo -e "FREESURFER\t:\t${FREESURFER_VERSION}"
echo -e "DCM2NII\t\t:\t${DCM2NII_VERSION}"	   
echo -e "CCP_DCM2NII\t:\t${CCP_DCM2NII}"    
echo -e "DICOM_HINFO\t:\t${DICOMHINFO_VERSION}"       
echo ""


echo $(date) "This file was written by setup_dcm2nii.sh, from the ccp_hcp account, for debugging purposes" > greetings.txt

