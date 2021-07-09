#!/bin/bash

# original source: HCP Pipelines 3.6.0 --> SetUpHCPPipeline.sh

echo "Sourcing environment for HCP Pipelines... ... ..."

### CCP_HCP CODE
#export CCP_HOME="/home/ccp_hcp/hcp/ccp_cluster_user"


### PYTHON VIRTUAL ENVIRONMENT
export PATH=/home/ccp_hcp/Enthought/Canopy_64bit/User/bin:${PATH}

### SOURCE MY LIB
. "${CCP_HOME}/mylib/myfunctions.lib"
#export CCP_TEMPLATES="${CCP_HOME}/templates"


### FSL
export FSLDIR=/act/fsl-5.0.8/
export FSL_DIR="${FSLDIR}"
. ${FSLDIR}/etc/fslconf/fsl.sh

### FREESURFER
export FREESURFER_HOME="/act/freesurfer-5.3.0-HCP"
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1		# newcluster


### WORKBENCH
export CARET7DIR="/act/src/workbench-1.1.1/bin_rh_linux64"
export PATH="${PATH}:/act/src/workbench-1.1.1/bin_rh_linux64"


### HCP Pipelines
export HCPPIPEDIR=/home/ccp_hcp/hcp/Pipelines
export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
export HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config
export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
export HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
export HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts
export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
export MSMBin=${HCPPIPEDIR}/MSMBinaries


### SOME LIBRARY NEEDED BY HCP and FSL's FIX
export LD_LIBRARY_PATH=/export/matlab/MCR/R2014a/v83/runtime/glnx64/:/export/matlab/MCR/R2014a/v83/bin/glnx64/:/export/matlab/MCR/R2014a/v83/sys/os/glnx64:/act/netcdf-4.3.3.1/lib/:/act/src/AFNI-20150722/linux_openmp_64:${LD_LIBRARY_PATH}

### Some outputs

echo ""
echo -e "Environment Setup:"
PYTHON_VERSION=$(which python)
FSL_VERSION=$(which fsl)
FREESURFER_VERSION=$(which freesurfer)
WORKBENCH_VERSION=$(which wb_command)
echo -e "PYTHON version\t:\t${PYTHON_VERSION}"
echo -e "FSLDIR\t\t:\t${FSL_VERSION}"
echo -e "FREESURFER\t:\t${FREESURFER_VERSION}"
echo -e "WORKBENCH\t:\t${WORKBENCH_VERSION}"
echo -e "PATH\t\t:"
echo "${PATH}"
echo ""

### CHPC cluster: module load R
module load R

### ICAFIX folder
export FSL_FIXDIR=/home/ccp_hcp/hcp/fix1.06
