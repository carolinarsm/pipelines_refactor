#/bin/bash


. "${CCP_HOME}/mylib/myfunctions.lib"

export CCP_TEMPLATES="${CCP_HOME}/templates"
echo -e "Templates\t:\t${CCP_TEMPLATES}"

#----- help function -----------------------------------------
function usage () {

	echo -e "$0"
	echo -e "\t-h --help \t\t- prints help\n\n."
	echo -e "\t-s --Subjects \t\t- subject ID. Use double quote for a list of subjects (mandatory)\n\n"
	echo -e "\t-t --Tasks \t\t- tasks list file (mandatory)\n\n"
	echo -e "\t-m --MB \t\t- MB factor, 4 or 8 (mandatory)\n\n"
	echo -e "\t-b --Block \t\t- Step of HCP Pipelines to run\t:\tvolume,surface (mandatory)\n\n"
	echo -e "\t-d --DataDir \t\t- HCP Study dir containing the subjects folders (mandatory)\n\n"
	echo -e "\t-q --Queue \t\t- Submit to cluster (optional)\n\n"

cat << EOF
	NOTE: This script will use a configuration template file pre-filled with parameter values
	used in the DMCC scans acquisition, available in '\${CCP_HOME}/templates'.
	For different parameters, make your own configuration file based on the template and
	run the scripts in '\${CCP_HOME}/batch_scripts' directly, passing the file as an argument.

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
		-m | --MB)
            mb_factor=$VALUE
        ;;
		-b | --Block)
            block=$VALUE
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


if [[ -z ${list_subjects} || -z ${mb_factor} || -z ${block} || -z ${Taskfile} || -z ${outputdir} ]] ; then
	usage
	error_exit "Missing or not assigned parameter(s)"
elif [[ ! -d ${outputdir} ]]; then
	error_exit "Cannot find ${outputdir}"
fi


echo ""
echo -e "working dir\t:\t${pwd}"
echo -e "Subjects\t:\t${list_subjects}"
echo -e "Block\t\t:\t${block}"
echo -e "Output dir\t:\t${outputdir}"
echo ""



#----- copy and fill configuration file template -------------
Tmp=$(mktemp)
echo -e "\nTemp File\t:\t${Tmp}\n"
cp "${CCP_TEMPLATES}/config_functional_MB${mb_factor}.cfg" "${Tmp}" || error_exit "ERROR: Incorrect MB factor value."


# Read task file and make task and phase encoding strings (too bothersome to input in command line)
Tasklist=""
PElist=""
while read line ; do

	task=$(echo "${line}" | cut -d' ' -f1)
	pe=$(echo "${line}" | cut -d' ' -f2)

	Tasklist="${Tasklist} ${task}"
	PElist="${PElist} ${pe}"

done < "${Taskfile}"



sed -i "s@STUDYFOLDERPLACEHOLDER@${outputdir}@g" "${Tmp}"
sed -i "s/SUBJECTPLACEHOLDER/${list_subjects}/g" "${Tmp}"

sed -i "s/TASKPLACEHOLDER/${Tasklist}/g" "${Tmp}"
sed -i "s/PHASEENCODINGPLACEHOLDER/${PElist}/g" "${Tmp}"

echo ""
cat "${Tmp}"
echo ""


#----- create and launch command -----------------------------

launch_command="${CCP_HOME}/batch_scripts/ccp_${block}_batch.sh -f=${Tmp}"

if [  ! -z "${qsub_flag}" ]; then
	launch_command="${launch_command} -q"
fi

echo -e "Running '${launch_command}'"
${launch_command}
