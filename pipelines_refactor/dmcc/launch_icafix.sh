#!/bin/bash

. "${CCP_HOME}/mylib/myfunctions.lib"

export CCP_TEMPLATES="${CCP_HOME}/templates"
echo -e "Templates\t:\t${CCP_TEMPLATES}"


#----- help function -----------------------------------------
function usage () {
    echo -e "$0"
    echo -e "\t-h --help \t\t- prints help\n\n."
    echo -e "\t-s --Subjects \t\t- subject ID. Use double quote for a list of subjects (mandatory)\n\n"
	echo -e "\t-t --Tasks \t\t- tasks list file (mandatory)\n\n"
    echo -e "\t-d --DataDir \t\t- HCP Study dir containing the subjects folders (mandatory)\n\n"
    echo -e "\t-q --Queue \t\t- Submit to cluster (optional)\n\n"

cat << EOF
	NOTE: This script will use a configuration template file pre-filled with the training
	data for the HCP Project (HCP_hp2000.RData) and a bandpass filter value of 2000.
	For different parameters, make your own configuration file based on the template and
	run the icafix script in '\${CCP_HOME}/batch_scripts' directly, passing the file as an
	argument.
EOF
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
	-s | --Subjects)
            list_subjects=$VALUE
            ;;
	-t | --Tasks)
            Taskfile=$VALUE
            ;;
	-d | --DataDir)
            outputdir="$(dirname "$VALUE")/$(basename "$VALUE")"
            outputdir=${outputdir%/}
            ;;
	-q | --Queue)
            qsub_flag=1
            ;;
	*)
			usage
			error_exit "unknown parameter \"$PARAM\""
            ;;
    esac
    shift
done


if [[ -z ${list_subjects} || -z ${Taskfile} || -z ${outputdir} ]] ; then
	usage
	error_exit "Missing or not assigned parameter(s)"
elif [[ ! -d ${outputdir} ]]; then
	usage
	error_exit "Cannot find ${outputdir}"
fi

echo ""
echo -e "Data dir\t:\t${outputdir}"
echo -e "Subjects\t:\t${subjects_list}"
echo ""


#----- copy and fill configuration file template -------------
Tmp=$(mktemp)
echo -e "\nTemp File\t:\t${Tmp}\n"
cp "${CCP_TEMPLATES}/config_icafix.cfg" "${Tmp}" || error_exit "Could not create configuration file."


#----- Read task file, extract resting state series and put in a list

Tasklist=""
while read line ; do

	if contains_substring "${line}" "_rest";then
		task=$(echo "${line}" | cut -d' ' -f1)
		Tasklist="${Tasklist} ${task}"
	fi

done < "${Taskfile}"

sed -i "s@STUDYFOLDERPLACEHOLDER@${outputdir}@g" "${Tmp}"
sed -i "s/SUBJECTPLACEHOLDER/${list_subjects}/g" "${Tmp}"
sed -i "s/BOLDPLACEHOLDER/${Tasklist}/g" "${Tmp}"

echo ""
cat "${Tmp}"
echo ""

#----- create and launch command -----------------------------
launch_command="${CCP_HOME}/batch_scripts/ccp_icafix_batch.sh -f=${Tmp}"

if [  ! -z "${qsub_flag}" ]; then
	launch_command="${launch_command} -q"
fi

echo -e "Running '${launch_command}'"
${launch_command}
