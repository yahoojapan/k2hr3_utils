#!/bin/sh
#
# K2HR3 DevPack in K2HR3 Utilities
#
# Copyright 2020 Yahoo Japan Corporation.
#
# K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers
# common management information for the cloud.
# K2HR3 can dynamically manage information as "who", "what", "operate".
# These are stored as roles, resources, policies in K2hdkc, and the
# client system can dynamically read and modify these information.
#
# For the full copyright and license information, please view
# the licenses file that was distributed with this source code.
#
# AUTHOR:   Takeshi Nakatani
# CREATE:   Wed, Feb 19 2025
# REVISION:
#

#==============================================================
# Common Variables
#==============================================================
export LANG=C

#
# Instead of pipefail(for shells not support "set -o pipefail")
#
PIPEFAILURE_FILE="/tmp/.pipefailure.$(od -An -tu4 -N4 /dev/random | tr -d ' \n')"

PROGRAM_NAME=$(basename "${0}")
PROGRAM_PREFIX_NAME=$(echo "${PROGRAM_NAME}" | sed -e 's#\..*$##g' -e 's#_##g')
SCRIPTDIR=$(dirname "${0}")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)
DEVPACKTOP=$(cd "${SCRIPTDIR}"/.. 2>/dev/null || exit 1; pwd)
#SRCTOP=$(cd "${DEVPACKTOP}"/.. 2>/dev/null || exit 1; pwd)

#
# Special variable for this script name
#
IN_CONTAINER_SCRIPT_SUFFIX="_in_container.sh"
OVERRIDE_CONF_PREFIX_NAME=$(echo "${PROGRAM_NAME}" | sed  -e "s#${IN_CONTAINER_SCRIPT_SUFFIX}##g" -e 's#\..*$##g' -e 's#_##g')
OVERRIDE_CONF_FILENAME="override_${OVERRIDE_CONF_PREFIX_NAME}.conf"
OVERRIDE_CONF_FILEPATH=""

#
# Common variables
#
DEFAULT_WORK_CONF_DIRNAME="conf"
DEFAULT_WORK_LOGS_DIRNAME="logs"
DEFAULT_WORK_PIDS_DIRNAME="pids"
DEFAULT_WORK_DATA_DIRNAME="data"

DEFAULT_REPO_K2HR3_API_NAME="k2hr3_api"
DEFAULT_REPO_K2HR3_APP_NAME="k2hr3_app"
DEFAULT_REPO_K2HR3_API="https://github.com/yahoojapan/${DEFAULT_REPO_K2HR3_API_NAME}.git"
DEFAULT_REPO_K2HR3_APP="https://github.com/yahoojapan/${DEFAULT_REPO_K2HR3_APP_NAME}.git"

DEFAULT_K2HFILE_SUFFIX_NODENO_KEY="NODENO"
DEFAULT_K2HFILE_SUFFIX="_k2hdkc_${DEFAULT_K2HFILE_SUFFIX_NODENO_KEY}.k2h"

DEFAULT_MQ_QMAX=1024
DEFAULT_MQ_MSGMAX=1024

DEFAULT_RESERVED_IMAGE_ALPINE="alpine:3.21"
DEFAULT_RESERVED_IMAGE_FEDORA="fedora:41"
DEFAULT_RESERVED_IMAGE_ROCKY="rockylinux:9"
DEFAULT_RESERVED_IMAGE_UBUNTU="ubuntu:22.04"
DEFAULT_RESERVED_IMAGE_DEBIAN="debian:12"

CHMPX_SERVER_NODE_0_PIDFILE="chmpx_server_node_0.pid"
CHMPX_SERVER_NODE_1_PIDFILE="chmpx_server_node_1.pid"
CHMPX_SLAVE_NODE_0_PIDFILE="chmpx_slave_node_0.pid"
K2HDKC_SERVER_NODE_0_PIDFILE="k2hdkc_server_node_0.pid"
K2HDKC_SERVER_NODE_1_PIDFILE="k2hdkc_server_node_1.pid"

CHMPX_SERVER_NODE_0_LOGFILE="chmpx_server_node_0.log"
CHMPX_SERVER_NODE_1_LOGFILE="chmpx_server_node_1.log"
CHMPX_SLAVE_NODE_0_LOGFILE="chmpx_slave_node_0.log"
K2HDKC_SERVER_NODE_0_LOGFILE="k2hdkc_server_node_0.log"
K2HDKC_SERVER_NODE_1_LOGFILE="k2hdkc_server_node_1.log"

K2HR3_API_LOGFILE="k2hr3_api.log"
K2HR3_APP_LOGFILE="k2hr3_app.log"

K2HR3_REPO_ARCHIVES_DIR="/tmp"
K2HR3_API_REPO_TMP_DIR="${K2HR3_REPO_ARCHIVES_DIR}/${DEFAULT_REPO_K2HR3_API_NAME}"
K2HR3_APP_REPO_TMP_DIR="${K2HR3_REPO_ARCHIVES_DIR}/${DEFAULT_REPO_K2HR3_APP_NAME}"
K2HR3_API_REPO_ARCHIVE_FILE="${K2HR3_REPO_ARCHIVES_DIR}/${DEFAULT_REPO_K2HR3_API_NAME}.tgz"
K2HR3_APP_REPO_ARCHIVE_FILE="${K2HR3_REPO_ARCHIVES_DIR}/${DEFAULT_REPO_K2HR3_APP_NAME}.tgz"

PROC_WAIT_SEC=2
PROC_START_WAIT_SEC="${PROC_WAIT_SEC}"
PROC_STOP_WAIT_SEC="${PROC_WAIT_SEC}"
PROC_START_WAIT_COUNT=5
CONTAINER_START_WAIT_COUNT=30

#
# Environment dependent variables
#
RUN_IN_CONTAINER=0
CURRENT_USER=""
SUDO_PREFIX_CMD=""

CUR_NODE_OS_NAME=""
CUR_NODE_OS_VERSION=""
K2HR3_NODE_OS_NAME=0
K2HR3_NODE_OS_VERSION=""
K2HR3_NODE_OS_TYPE_NUMBER=0
K2HR3_NODE_CONTAINER_NAME=""
STATUS_PACKAGECLOUD_REPO=0

SCHEME_HTTP_PROXY=""
SCHEME_HTTPS_PROXY=""

PKGMGR=""
INSTALL_BASE_PKG_LIST=""
INSTALL_PKG_LIST=""

BACKUP_SUFFIX=""

#
# Variables for configuration files
#
K2HDKC_K2H_PATH=""
K2HDKC_SERVER_NODE_0_CONF_FILE=""
K2HDKC_SERVER_NODE_1_CONF_FILE=""
K2HDKC_SLAVE_NODE_0_CONF_FILE=""

K2HR3_APP_CONF_FILE=""
K2HR3_API_CONF_FILE=""

K2HDKC_SERVER_NODE_0_PORT=0
K2HDKC_SERVER_NODE_0_CTLPORT=0
K2HDKC_SERVER_NODE_1_PORT=0
K2HDKC_SERVER_NODE_1_CTLPORT=0
K2HDKC_SLAVE_NODE_0_CTLPORT=0
K2HR3_APP_PORT=0
K2HR3_API_PORT=0

K2HR3_APP_HOST=""
K2HR3_APP_URL=""
K2HR3_API_HOST=""
K2HR3_API_URL=""

#
# Option variables (this has default value)
#
IS_INTERACTIVE=1
IS_USE_PACKAGECLOUD=1

NODEJS_VERSION="22"
REPO_K2HR3_API=""
REPO_K2HR3_APP=""

CURRENT_DIR=$(pwd)
WORK_DIR=$(cd "." || exit 1; pwd)

#
# Option variables (this has not default value)
#
RUN_MODE=""
RUN_CONTAINER=""
WORK_CONF_DIR=""
WORK_LOGS_DIR=""
WORK_PIDS_DIR=""
WORK_DATA_DIR=""
REPO_K2HR3_API_DIR=""
REPO_K2HR3_APP_DIR=""
EXTERNAL_HOST=""
NPM_REGISTORIES=""

#==============================================================
# Common Variables and Utility functions
#==============================================================
#
# Escape sequence
#
if [ -t 1 ] || echo "${PROGRAM_NAME}" | grep -q -i "${IN_CONTAINER_SCRIPT_SUFFIX}"; then
	# shellcheck disable=SC2034
	CBLD=$(printf '\033[1m')
	CREV=$(printf '\033[7m')
	CRED=$(printf '\033[31m')
	CYEL=$(printf '\033[33m')
	CGRN=$(printf '\033[32m')
	CDEF=$(printf '\033[0m')
else
	# shellcheck disable=SC2034
	CBLD=""
	CREV=""
	CRED=""
	CYEL=""
	CGRN=""
	CDEF=""
fi

#--------------------------------------------------------------
# Message functions
#--------------------------------------------------------------
PRNERR()
{
	echo "${CBLD}${CRED}[ERROR]${CDEF} ${CRED}$*${CDEF}"
}

PRNWARN()
{
	echo "${CYEL}${CREV}[WARNING]${CDEF} $*"
}

PRNMSG()
{
	echo ""
	echo "${CYEL}${CREV}[MSG]${CDEF} $*"
}

PRNINFO()
{
	echo "${CREV}[INFO]${CDEF} $*"
}

PRNTITLE()
{
	echo ""
	echo "${CGRN}---------------------------------------------------------------------${CDEF}"
	echo "${CGRN}${CREV}[TITLE]${CDEF} ${CGRN}$*${CDEF}"
	echo "${CGRN}---------------------------------------------------------------------${CDEF}"
}

PRNSUCCESS()
{
	echo ""
	echo "${CGRN}[SUCCESS]${CDEF} $*"
	echo ""
}

#--------------------------------------------------------------
# Interaction function
#--------------------------------------------------------------
#
# $1:	Input Message(puts stderr)
# $2:	Input data type is number = yes(1)/no(0, default)
# $3:	Whether to allow empty    = yes(1, default)/no(0)
#
# $?					: result(0(always))
# INTERACTION_RESULT	: input value
#
input_interaction()
{
	INTERACTION_RESULT=""

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		INPUT_MSG="Input values"
	else
		INPUT_MSG="$1"
		shift
	fi
	if [ $# -lt 1 ] || [ -z "$1" ]; then
		IS_NUMBER=0
	elif echo "$1" | grep -q -i -e "^y$" -e "^yes$" -e "^1$"; then
		IS_NUMBER=1
		shift
	else
		IS_NUMBER=0
		shift
	fi
	if [ $# -lt 1 ] || [ -z "$1" ]; then
		IS_ALLOW_EMPTY=1
	elif echo "$1" | grep -q -i -e "^n$" -e "^no$" -e "^0$"; then
		IS_ALLOW_EMPTY=0
	else
		IS_ALLOW_EMPTY=1
	fi

	_PARSE_INPUT_MSGS=$(echo "${INPUT_MSG}" | sed -e 's#[[:space:]]#\\_#g' | tr ';' ' ')
	IS_LOOP=1
	while [ "${IS_LOOP}" -eq 1 ]; do
		_FIRST_MSG_LINE=1
		for _ONE_MSG_LINE in ${_PARSE_INPUT_MSGS}; do
			if [ "${_FIRST_MSG_LINE}" -eq 1 ]; then
				printf "%s[INPUT]%s " "${CREV}" "${CDEF}"
				_FIRST_MSG_LINE=0
			else
				printf "\n        "
			fi
			_ONE_MSG_LINE=$(echo "${_ONE_MSG_LINE}" | sed -e 's#[\\][_]# #g')
			printf "%s" "${_ONE_MSG_LINE}"
		done
		printf " > "

		read -r INTERACTION_RESULT

		if [ -z "${INTERACTION_RESULT}" ]; then
			if [ "${IS_ALLOW_EMPTY}" -eq 1 ]; then
				IS_LOOP=0
			else
				PRNERR "Not allow to input empty."
			fi
		else
			if [ "${IS_NUMBER}" -ne 1 ]; then
				IS_LOOP=0
			else
				if echo "${INTERACTION_RESULT}" | grep -q "[^0-9]"; then
					PRNERR "The input value must be number"
				else
					IS_LOOP=0
				fi
			fi
		fi
	done

	return 0
}

#==============================================================
# Override Functions/Variables
#==============================================================
# The following functions and variables are built in so that they
# can be overridden.
#
# You can change the default behavior by defining the following
# functions in the "override_devk2hr3.conf" file.
#
#	[functions]	addition_setup_default_variables()
#				addition_print_help_option()
#				addition_print_variables_info()
#				addition_parse_input_parameters()
#				addition_interactive_options()
#				addition_varidate_options()
#				addition_validate_host_environments()
#				addition_setup_container_launch_options()
#				addition_setup_container_script_options()
#				addition_setup_k2hr3_conf_variables()
#				addition_setup_package_repositories()
#
#	[variables]	ADDITION_PARSE_OPTION_RESULT
#				ADDITION_USED_PARAMTER_COUNT
#				ADDITION_CONTAINER_OPTION
#				ADDITION_IN_CONTAINER_OPTION
#				ADDITION_API_CONF_KEYSTONE
#				ADDITION_APP_CONF_VARIDATOR
#				ADDITION_APP_CONF_ADDITIONAL_KEYS
#
# The override functions are I/Fs, and the default behavior
# (for OpenStack Keystone) calls the following functions:
#
#	[functions]	builtin_addition_setup_default_variables()
#				builtin_addition_print_help_option()
#				builtin_addition_print_variables_info()
#				builtin_addition_parse_input_parameters()
#				builtin_addition_interactive_options()
#				builtin_addition_varidate_options()
#				builtin_addition_validate_host_environments()
#				builtin_addition_setup_container_launch_options()
#				builtin_addition_setup_container_script_options()
#				builtin_addition_setup_k2hr3_conf_variables()
#				builtin_addition_setup_package_repositories()
#
# If you want to override, overwrite the override functions in
# "override_devk2hr3.conf". And don't forget to define the
# variables.
#
# [Background]
# The K2HR3 system can use OpenStack Keystone or OIDC for user
# authentication.
# The default(without override) of this script sets authentication
# using OpenStack Keystone.
# This can be overridden to change to a different authentication
# method. You can customize it by preparing a "override_devk2hr3.conf"
# file that mimics the following functions and variables.
#
#--------------------------------------------------------------
# Additional functions : Override functions(variables) I/F
#--------------------------------------------------------------
#
# Setup default variables for additional functions
#
addition_setup_default_variables()
{
	if ! builtin_addition_setup_default_variables; then
		return 1
	fi
	return 0
}

#
# Print help option string for additional functions
#
addition_print_help_option()
{
	if ! builtin_addition_print_help_option; then
		return 1
	fi
	return 0
}

#
# Print variables information for additional functions
#
addition_print_variables_info()
{
	if ! builtin_addition_print_variables_info "$@"; then
		return 1
	fi
	return 0
}

#
# Parse input options for additional functions
#
addition_parse_input_parameters()
{
	if ! builtin_addition_parse_input_parameters "$@"; then
		return 1
	fi
	return 0
}

#
# Interactive or Set default variables for additional functions 
#
addition_interactive_options()
{
	if ! builtin_addition_interactive_options "$@"; then
		return 1
	fi
	return 0
}

#
# Varidate options for additional functions
#
addition_varidate_options()
{
	if ! builtin_addition_varidate_options "$@"; then
		return 1
	fi
	return 0
}

#
# Check host environments for additional functions
#
addition_validate_host_environments()
{
	if ! builtin_addition_validate_host_environments "$@"; then
		return 1
	fi
	return 0
}

#
# Setup container launch options for additional functions
#
addition_setup_container_launch_options()
{
	if ! builtin_addition_setup_container_launch_options; then
		return 1
	fi
	return 0
}

#
# Setup script running in container options for additional functions
#
addition_setup_container_script_options()
{
	if ! builtin_addition_setup_container_script_options; then
		return 1
	fi
	return 0
}

#
# Setup K2HR3 configuration variables for additional functions
#
addition_setup_k2hr3_conf_variables()
{
	if ! builtin_addition_setup_k2hr3_conf_variables "$@"; then
		return 1
	fi
	return 0
}

#
# Setup package repository for additional functions
#
addition_setup_package_repositories()
{
	if ! builtin_addition_setup_package_repositories "$@"; then
		return 1
	fi
	return 0
}

#--------------------------------------------------------------
# Built-in additional functions(variables)
#--------------------------------------------------------------
#
# Setup default variables for OpenStack authentication
#
# [Setup variables]
#	ADDITION_DEFAULT_KEYSTONE_URL
#	ADDITION_KEYSTONE_URL
#
builtin_addition_setup_default_variables()
{
	ADDITION_DEFAULT_KEYSTONE_URL="https://localhost/"
	ADDITION_KEYSTONE_URL=""
	return 0
}

#
# Print help option string for OpenStack authentication
#
# [Using variables]
#	ADDITION_DEFAULT_KEYSTONE_URL
#
builtin_addition_print_help_option()
{
	echo "   --keystone_url(-ks) [url]       Specify OpenStack Keystone URL. (default: ${ADDITION_DEFAULT_KEYSTONE_URL})"
	return 0
}

#
# Print variables information for OpenStack authentication
#
# [Using variables]
#	ADDITION_KEYSTONE_URL
#
builtin_addition_print_variables_info()
{
	echo "[Additional configuration information]"
	echo "    OpenStack Keystone URL                    : ${ADDITION_KEYSTONE_URL}"
	echo ""

	return 0
}

#
# Parse input options for OpenStack authentication
#
# [INPUT]
#	$1		first option
#	$2		second option
#
# [OUTPUT]
#	result	0($1 is this option case)/1($1 is not this option)
#
# [Setup variables]
#	ADDITION_PARSE_OPTION_RESULT	: 0(success)/1(failure)
#	ADDITION_USED_PARAMTER_COUNT
#	ADDITION_KEYSTONE_URL
#
builtin_addition_parse_input_parameters()
{
	ADDITION_PARSE_OPTION_RESULT=1
	ADDITION_USED_PARAMTER_COUNT=0

	if [ -z "$1" ]; then
		return 1
	fi
	if ! echo "$1" | grep -q -i -e "^-ks$" -e "^--keystone_url$"; then
		return 1
	fi
	ADDITION_USED_PARAMTER_COUNT=1

	if [ -n "${ADDITION_KEYSTONE_URL}" ]; then
		PRNERR "--keystone_url(-ks) option is already specified(${ADDITION_DEFAULT_KEYSTONE_URL})"
		return 0
	fi
	if [ -z "$2" ]; then
		PRNERR "--keystone_url(-ks) option needs parameter."
		return 0
	fi
	ADDITION_KEYSTONE_URL="$2"
	ADDITION_PARSE_OPTION_RESULT=0
	ADDITION_USED_PARAMTER_COUNT=2

	return 0
}

#
# Interactive or Set default variables for OpenStack authentication 
#
# [INPUT]
#	$1		interactive mode: 1(interactive)/0(not)
#
# [Setup variables]
#	ADDITION_KEYSTONE_URL
#
builtin_addition_interactive_options()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	if [ -n "${ADDITION_KEYSTONE_URL}" ]; then
		# Already setup value, so nothing to do.
		return 0
	fi


	if [ "$1" -eq 1 ]; then
		_IS_LOOP=1
		while [ "${_IS_LOOP}" -eq 1 ]; do
			input_interaction "OpenStack Keystone URL (empty is use default: \"${ADDITION_DEFAULT_KEYSTONE_URL}\")"

			if [ -z "${INTERACTION_RESULT}" ]; then
				# use default value
				ADDITION_KEYSTONE_URL="${ADDITION_DEFAULT_KEYSTONE_URL}"
				_IS_LOOP=0
			else
				ADDITION_KEYSTONE_URL="${INTERACTION_RESULT}"
				_IS_LOOP=0
			fi
		done
	elif [ "$1" -eq 0 ]; then
		#
		# Set default value
		#
		ADDITION_KEYSTONE_URL="${ADDITION_DEFAULT_KEYSTONE_URL}"
	else
		PRNERR "Parameter error: first argument is $1, not 1 nor 0."
		return 1
	fi

	return 0
}

#
# Varidate options for OpenStack authentication
#
# [INPUT]
#	$1		: Run mode
#
# [Using variables]
#	ADDITION_KEYSTONE_URL
#
builtin_addition_varidate_options()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	if [ "$1" = "start" ]; then
		if [ -z "${ADDITION_KEYSTONE_URL}" ]; then
			PRNERR "In $1 mode, must specify the --keystone_url(-ks) option."
			return 1
		fi
	else
		if [ -n "${ADDITION_KEYSTONE_URL}" ]; then
			PRNERR "In $1 mode, the --keystone_url(-ks) option cannot be specified."
			return 1
		fi
	fi
	return 0
}

#
# Check host environments for OpenStack authentication
#
builtin_addition_validate_host_environments()
{
	return 0
}

#
# Setup container launch options for OpenStack authentication
#
# [Setup variables]
#	ADDITION_CONTAINER_OPTION
#
builtin_addition_setup_container_launch_options()
{
	ADDITION_CONTAINER_OPTION=""
	return 0
}

#
# Setup script running in container options for OpenStack authentication
#
# [Using variables]
#	ADDITION_KEYSTONE_URL
#
# [Setup variables]
#	ADDITION_IN_CONTAINER_OPTION	: Add values
#
builtin_addition_setup_container_script_options()
{
	if [ -n "${ADDITION_KEYSTONE_URL}" ]; then
		ADDITION_IN_CONTAINER_OPTION="${ADDITION_IN_CONTAINER_OPTION} --keystone_url ${ADDITION_KEYSTONE_URL}"
	fi
	return 0
}

#
# Setup K2HR3 configuration variables for OpenStack authentication
#
# [Using variables]
#	ADDITION_KEYSTONE_URL
#
# [Setup variables]
#	ADDITION_API_CONF_KEYSTONE
#	ADDITION_APP_CONF_VARIDATOR
#	ADDITION_APP_CONF_ADDITIONAL_KEYS
#
builtin_addition_setup_k2hr3_conf_variables()
{
	ADDITION_API_CONF_KEYSTONE=$(
		echo "    'keystone': {"
		echo "        'type':         'openstackapiv3',"
		echo "        'eptype':       'list',"
		echo "        'epfile':       null,"
		echo "        'eplist': {"
		echo "            'testregion':   '${ADDITION_KEYSTONE_URL}'"
		echo '        }'
		echo '    },'
	)
	ADDITION_APP_CONF_VARIDATOR="userValidateCredential"
	ADDITION_APP_CONF_ADDITIONAL_KEYS=""

	return 0
}

#
# Setup package repository for OpenStack authentication
#
builtin_addition_setup_package_repositories()
{
	return 0
}

#==============================================================
# Utility functions
#==============================================================
#--------------------------------------------------------------
# [Utilities] Setup environment dependent variables
#--------------------------------------------------------------
#
# Setup OS type number which container or localhost
#
# [Using Variables]
#	RUN_CONTAINER
#	RUN_IN_CONTAINER
#
# [Setup variables]
#	CUR_NODE_OS_NAME
#	CUR_NODE_OS_VERSION
#	K2HR3_NODE_OS_NAME
#	K2HR3_NODE_OS_VERSION
#	K2HR3_NODE_OS_TYPE_NUMBER
#	K2HR3_NODE_CONTAINER_NAME
#
setup_k2hr3_system_os_type_number()
{
	#
	# OS type
	#
	if [ ! -f /etc/os-release ]; then
		PRNERR "Not found /etc/os-release file."
		return 1
	fi
	CUR_NODE_OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g' | tr -d '\n')
	CUR_NODE_OS_VERSION=$(grep '^VERSION_ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^VERSION_ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g' | tr -d '\n')

	#
	# Get the OS name to make the determination
	#
	if [ "${RUN_IN_CONTAINER}" -eq 0 ]; then
		if [ -n "${RUN_CONTAINER}" ]; then
			# This script starts a container, so it determines the OS name from the
			# OS image name of the container to be started.
			#
			_TMP_OS_VERSION=$(echo "${RUN_CONTAINER}" | sed -e 's#^.*:##g' | tr -d '\n')

			if echo "${RUN_CONTAINER}" | grep -q -i "alpine"; then
				_TMP_OS_NAME="alpine"
			elif echo "${RUN_CONTAINER}" | grep -q -i "ubuntu"; then
				_TMP_OS_NAME="ubuntu"
			elif echo "${RUN_CONTAINER}" | grep -q -i "debian"; then
				_TMP_OS_NAME="debian"
			elif echo "${RUN_CONTAINER}" | grep -q -i -e "rocky" -e "rockylinux"; then
				_TMP_OS_NAME="rocky"
			elif echo "${RUN_CONTAINER}" | grep -q -i -e "fedora"; then
				_TMP_OS_NAME="fedora"
			else
				#
				# Unknown container OS name type
				#
				if [ "${IS_INTERACTIVE}" -eq 0 ]; then
					PRNERR "Unknown OS type of \"${RUN_CONTAINER}\" image. To use this image, run this script interactively(not specify \"--yes(-y)\" option)."
					return 1
				fi

				while [ "${_IS_LOOP}" -eq 1 ]; do
					input_interaction "What OS type is the ${RUN_CONTAINER} image? (\"alpine:<version>\", \"ubuntu:<version>\", \"debian:<version>\", \"rockylinux(rocky):<version>\", \"fedora:<version>\")" "no" "no"

					if [ -z "${INTERACTION_RESULT}" ]; then
						PRNERR "Empty cannot be specified."
					else
						_IS_LOOP=0
						_TMP_OS_VERSION=$(echo "${INTERACTION_RESULT}" | sed -e 's#^.*:##g' | tr -d '\n')

						if echo "${INTERACTION_RESULT}" | grep -q -i "^alpine$"; then
							_TMP_OS_NAME="alpine"
						elif echo "${INTERACTION_RESULT}" | grep -q -i "^ubuntu$"; then
							_TMP_OS_NAME="ubuntu"
						elif echo "${INTERACTION_RESULT}" | grep -q -i "^debian$"; then
							_TMP_OS_NAME="debian"
						elif echo "${INTERACTION_RESULT}" | grep -q -i -e "^rockylinux$" -e "^rocky$"; then
							_TMP_OS_NAME="rocky"
						elif echo "${INTERACTION_RESULT}" | grep -q -i "^fedora$"; then
							_TMP_OS_NAME="fedora"
						else
							PRNERR "Unknown value(${INTERACTION_RESULT})."
							_IS_LOOP=1
						fi
					fi
				done
			fi
			#
			# Container name
			#
			K2HR3_NODE_CONTAINER_NAME="k2hr3_${_TMP_OS_NAME}"

		else
			# The environment this script runs in is not a container, and it does not
			# start any containers, so it is determined by the OS name.
			#
			_TMP_OS_NAME="${CUR_NODE_OS_NAME}"
			_TMP_OS_VERSION="${CUR_NODE_OS_VERSION}"
		fi
	else
		# The environment in which this script is being executed is inside a container,
		# so it is determined by the container's OS name.
		#
		_TMP_OS_NAME="${CUR_NODE_OS_NAME}"
		_TMP_OS_VERSION="${CUR_NODE_OS_VERSION}"
	fi

	#
	# Determine the number according to the OS type of the k2hr3 system execution environment
	#
	K2HR3_NODE_OS_NAME="${_TMP_OS_NAME}"
	K2HR3_NODE_OS_VERSION="${_TMP_OS_VERSION}"

	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
		K2HR3_NODE_OS_TYPE_NUMBER=1
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "ubuntu"; then
		K2HR3_NODE_OS_TYPE_NUMBER=2
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "debian"; then
		K2HR3_NODE_OS_TYPE_NUMBER=3
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "rocky"; then
		K2HR3_NODE_OS_TYPE_NUMBER=4
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "fedora"; then
		K2HR3_NODE_OS_TYPE_NUMBER=5
	else
		PRNERR "Unknown OS type(${K2HR3_NODE_OS_NAME})."
		return 1
	fi

	return 0
}

#
# Setup PROXY variables
#
# [NOTE]
# K2HR3_NODE_OS_NAME must be set before calling this function.
#
# [Set variables]
#	HTTP_PROXY				: exports
#	HTTPS_PROXY				: exports
#	NO_PROXY				: exports
#	SCHEME_HTTP_PROXY		: not export
#	SCHEME_HTTPS_PROXY		: not export
#
set_variable_for_proxy()
{
	_CUR_HTTP_PROXY=""
	_CUR_HTTPS_PROXY=""
	_CUR_NO_PROXY=""
	_SETUP_HTTP_PROXY=""
	_SETUP_HTTPS_PROXY=""

	#
	# Case precedence and consistency
	#
	if [ -n "${HTTP_PROXY}" ]; then
		_CUR_HTTP_PROXY="${HTTP_PROXY}"
	elif [ -n "${http_proxy}" ]; then
		_CUR_HTTP_PROXY="${http_proxy}"
	fi
	if [ -n "${HTTPS_PROXY}" ]; then
		_CUR_HTTPS_PROXY="${HTTPS_PROXY}"
	elif [ -n "${https_proxy}" ]; then
		_CUR_HTTPS_PROXY="${https_proxy}"
	fi
	if [ -n "${NO_PROXY}" ]; then
		_CUR_NO_PROXY="${NO_PROXY}"
	elif [ -n "${no_proxy}" ]; then
		_CUR_NO_PROXY="${no_proxy}"
	fi

	#
	# Variables with and without schema
	#
	if [ -n "${_CUR_HTTP_PROXY}" ]; then
		if echo "${_CUR_HTTP_PROXY}" | grep -q -i -e "^http://" -e "^https://"; then
			SCHEME_HTTP_PROXY="${_CUR_HTTP_PROXY}"
			_CUR_HTTP_PROXY=$(echo "${_CUR_HTTP_PROXY}" | sed -e "s|^http://||gi" -e "s|^https://||gi" | tr -d '\n')
		else
			SCHEME_HTTP_PROXY="http://${_CUR_HTTP_PROXY}"
		fi
	fi
	if [ -n "${_CUR_HTTPS_PROXY}" ]; then
		if echo "${_CUR_HTTPS_PROXY}" | grep -q -i -e "^http://" -e "^https://"; then
			SCHEME_HTTPS_PROXY="${_CUR_HTTPS_PROXY}"
			_CUR_HTTPS_PROXY=$(echo "${_CUR_HTTPS_PROXY}" | sed -e "s|^http://||gi" -e "s|^https://||gi" | tr -d '\n')
		else
			SCHEME_HTTPS_PROXY="http://${_CUR_HTTPS_PROXY}"
		fi
	fi

	#
	# Environment variables for each OS type
	#
	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
		_SETUP_HTTP_PROXY="${SCHEME_HTTP_PROXY}"
		_SETUP_HTTPS_PROXY="${SCHEME_HTTPS_PROXY}"
	else
		_SETUP_HTTP_PROXY="${_CUR_HTTP_PROXY}"
		_SETUP_HTTPS_PROXY="${_CUR_HTTPS_PROXY}"
	fi

	#
	# Exports
	#
	if [ -n "${_SETUP_HTTP_PROXY}" ]; then
		HTTP_PROXY="${_SETUP_HTTP_PROXY}"
		http_proxy="${_SETUP_HTTP_PROXY}"
		export HTTP_PROXY
		export http_proxy
	else
		unset HTTP_PROXY
		unset http_proxy
	fi
	if [ -n "${_SETUP_HTTPS_PROXY}" ]; then
		HTTPS_PROXY="${_SETUP_HTTPS_PROXY}"
		https_proxy="${_SETUP_HTTPS_PROXY}"
		export HTTPS_PROXY
		export https_proxy
	else
		unset HTTPS_PROXY
		unset https_proxy
	fi

	if [ -n "${_CUR_NO_PROXY}" ]; then
		NO_PROXY="${_CUR_NO_PROXY}"
		no_proxy="${_CUR_NO_PROXY}"
		export NO_PROXY
		export no_proxy
	else
		unset NO_PROXY
		unset no_proxy
	fi

	return 0
}

#
# Setup variables about package repositories and proxies
#
# [Use variables]
#	K2HR3_NODE_OS_NAME
#
# [Setup variables]
#	CURRENT_USER
#	SUDO_PREFIX_CMD
#	K2HR3_APP_LANG
#	STATUS_PACKAGECLOUD_REPO
#	DEBIAN_FRONTEND				: export
#
set_variable_for_host_environments()
{
	#
	# Whoami
	#
	CURRENT_USER=$(id -u -n)
	if [ "${CURRENT_USER}" != "root" ]; then
		if command -v sudo >/dev/null 2>&1; then
			SUDO_PREFIX_CMD="sudo"
		else
			PRNERR "Not found sudo command, please install it before run this script."
			return 1
		fi
	else
		SUDO_PREFIX_CMD=""
	fi

	#
	# packagecloud.io repository
	#
	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
		if [ -f /etc/apk/repositories ]; then
			if grep "packagecloud.io" /etc/apk/repositories | sed -e "s|#.*$||g" | grep -q "antpickax"; then
				STATUS_PACKAGECLOUD_REPO=1
			else
				STATUS_PACKAGECLOUD_REPO=0
			fi
		else
			STATUS_PACKAGECLOUD_REPO=0
		fi
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		if [ -f /etc/apt/sources.list.d/antpickax_stable.list ]; then
			STATUS_PACKAGECLOUD_REPO=1
		else
			STATUS_PACKAGECLOUD_REPO=0
		fi

	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if dnf repolist --enabled 2>/dev/null | grep -q antpickax; then
			STATUS_PACKAGECLOUD_REPO=1
		elif dnf repolist --disabled 2>/dev/null | grep -q antpickax; then
			STATUS_PACKAGECLOUD_REPO=0
		else
			STATUS_PACKAGECLOUD_REPO=0
		fi
	else
		PRNERR "Unknown OS type(${K2HR3_NODE_OS_NAME})."
		return 1
	fi

	#
	# LANG
	#
	# [NOTE]
	# Currently, the only supported language other than English is Japanese.
	#
	if echo "${LANG}" | grep -q -i 'ja'; then
		K2HR3_APP_LANG="ja"
	else
		K2HR3_APP_LANG="en"
	fi

	#
	# Special environment
	#
	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		DEBIAN_FRONTEND="noninteractive"
		export DEBIAN_FRONTEND
	fi

	return 0
}

#
# Setup variables about installing packages
#
# [Use variables]
#	K2HR3_NODE_OS_NAME
#
# [Setup variables]
#	PKGMGR
#	INSTALL_BASE_PKG_LIST
#	INSTALL_PKG_LIST
#
setup_variables_for_install_packages()
{
	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
		PKGMGR="apk"
		INSTALL_BASE_PKG_LIST="bash sudo git vim gcc g++ make procps curl sysstat net-tools bind-tools iproute2 traceroute"
		INSTALL_PKG_LIST="nodejs npm python3 k2hdkc-dev"

	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "ubuntu"; then
		PKGMGR="apt-get"
		INSTALL_BASE_PKG_LIST="sudo git vim gcc g++ make procps sudo curl hostname net-tools dnsutils iputils-ping iproute2 traceroute"
		INSTALL_PKG_LIST="nodejs k2hdkc-dev"

	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "debian"; then
		PKGMGR="apt-get"
		INSTALL_BASE_PKG_LIST="sudo git vim gcc g++ make procps sudo curl hostname net-tools dnsutils iputils-ping iproute2 traceroute"
		INSTALL_PKG_LIST="nodejs k2hdkc-dev"

	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "rocky"; then
		PKGMGR="dnf"
		INSTALL_BASE_PKG_LIST="sudo git vim gcc g++ make procps curl hostname psmisc net-tools bind-utils iputils iproute traceroute"
		INSTALL_PKG_LIST="nodejs k2hdkc-devel"

	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "fedora"; then
		PKGMGR="dnf"
		INSTALL_BASE_PKG_LIST="sudo git vim gcc g++ make procps curl hostname psmisc net-tools bind-utils iputils iproute traceroute"
		INSTALL_PKG_LIST="nodejs k2hdkc-devel"

	else
		PRNERR "Unknown OS type(${K2HR3_NODE_OS_NAME})."
		return 1
	fi
	return 0
}

#--------------------------------------------------------------
# [Utilities] Setup configuration for MQ
#--------------------------------------------------------------
#
# Setup configuration for MQ(queues_max, msg_max)
#
# [Use variables]
#	SUDO_PREFIX_CMD
#	DEFAULT_MQ_QMAX
#	DEFAULT_MQ_MSGMAX
#
setup_configuration_for_mq()
{
	#
	# Setup queues_max value
	#
	PRNMSG "Setup queues_max value"

	if ({ /bin/sh -c "echo ${DEFAULT_MQ_QMAX} | ${SUDO_PREFIX_CMD} tee /proc/sys/fs/mqueue/queues_max >/dev/null 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNWARN "Failed to setup queues_max value, but continue..."
		echo "        Please set the value of queues_max manually:"
		echo "        echo \"1024\" > /proc/sys/fs/mqueue/queues_max"
		echo ""
	else
		PRNINFO "Succeed to setup queues_max value."
	fi

	#
	# Setup msg_max value
	#
	PRNMSG "Setup msg_max value"

	if ({ /bin/sh -c "echo ${DEFAULT_MQ_MSGMAX} | ${SUDO_PREFIX_CMD} tee /proc/sys/fs/mqueue/msg_max >/dev/null 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNWARN "Failed to setup msg_max value, but continue..."
		echo "        Please set the value of msg_max manually:"
		echo "        echo \"1024\" > /proc/sys/fs/mqueue/msg_max"
		echo ""
	else
		PRNINFO "Succeed to setup msg_max value."
	fi

	return 0
}

#--------------------------------------------------------------
# [Utilities] K2HR3 API/APP repository archives
#--------------------------------------------------------------
#
# Create K2HR3 API/APP repository archives
#
# [Use variables]
#	K2HR3_REPO_ARCHIVES_DIR
#	K2HR3_API_REPO_TMP_DIR
#	K2HR3_APP_REPO_TMP_DIR
#	K2HR3_API_REPO_ARCHIVE_FILE
#	K2HR3_APP_REPO_ARCHIVE_FILE
#	BACKUP_SUFFIX
#	REPO_K2HR3_API
#	REPO_K2HR3_APP
#
create_k2hr3_repository_archives()
{
	#
	# K2HR3 API repository
	#
	echo ""
	if [ -f "${K2HR3_API_REPO_ARCHIVE_FILE}" ]; then
		if ! rename_file_directory_and_create_directory "${K2HR3_API_REPO_ARCHIVE_FILE}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${K2HR3_API_REPO_ARCHIVE_FILE} file for backup."
			return 1
		fi
	fi
	if [ -d "${K2HR3_API_REPO_TMP_DIR}" ]; then
		if ! rename_file_directory_and_create_directory "${K2HR3_API_REPO_TMP_DIR}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${K2HR3_API_REPO_TMP_DIR} directory for backup."
			return 1
		fi
	fi
	cd "${K2HR3_REPO_ARCHIVES_DIR}" || exit 1

	if ({ /bin/sh -c "git clone ${REPO_K2HR3_API} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to clone K2HR3 API repository from ${REPO_K2HR3_API}"
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to clone K2HR3 API repository from ${REPO_K2HR3_API}"

	if ! tar cvf - "${DEFAULT_REPO_K2HR3_API_NAME}" 2>/dev/null | gzip - > "${K2HR3_API_REPO_ARCHIVE_FILE}" 2>/dev/null; then
		PRNERR "Failed to create archive ${K2HR3_API_REPO_ARCHIVE_FILE} for K2HR3 API."
		rm -rf "${K2HR3_API_REPO_TMP_DIR}"
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to to create archive ${K2HR3_API_REPO_ARCHIVE_FILE} for K2HR3 API."

	rm -rf "${K2HR3_API_REPO_TMP_DIR}"
	cd "${CURRENT_DIR}" || exit 1

	#
	# K2HR3 APP repository
	#
	echo ""
	if [ -f "${K2HR3_APP_REPO_ARCHIVE_FILE}" ]; then
		if ! rename_file_directory_and_create_directory "${K2HR3_APP_REPO_ARCHIVE_FILE}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${K2HR3_APP_REPO_ARCHIVE_FILE} file for backup."
			return 1
		fi
	fi
	if [ -d "${K2HR3_APP_REPO_TMP_DIR}" ]; then
		if ! rename_file_directory_and_create_directory "${K2HR3_APP_REPO_TMP_DIR}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${K2HR3_APP_REPO_TMP_DIR} directory for backup."
			return 1
		fi
	fi
	cd "${K2HR3_REPO_ARCHIVES_DIR}" || exit 1

	if ({ /bin/sh -c "git clone ${REPO_K2HR3_APP} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to clone K2HR3 APP repository from ${REPO_K2HR3_APP}"
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to clone K2HR3 APP repository from ${REPO_K2HR3_APP}"

	if ! tar cvf - "${DEFAULT_REPO_K2HR3_APP_NAME}" 2>/dev/null | gzip - > "${K2HR3_APP_REPO_ARCHIVE_FILE}" 2>/dev/null; then
		PRNERR "Failed to create archive ${K2HR3_APP_REPO_ARCHIVE_FILE} for K2HR3 APP."
		rm -rf "${K2HR3_APP_REPO_TMP_DIR}"
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to to create archive ${K2HR3_APP_REPO_ARCHIVE_FILE} for K2HR3 APP."

	rm -rf "${K2HR3_APP_REPO_TMP_DIR}"
	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#
# Extract K2HR3 API/APP repository archives
#
# [Use variables]
#	K2HR3_API_REPO_ARCHIVE_FILE
#	K2HR3_APP_REPO_ARCHIVE_FILE
#	REPO_K2HR3_API_DIR
#	REPO_K2HR3_APP_DIR
#	WORK_DIR
#	BACKUP_SUFFIX
#
extract_k2hr3_repository_archives()
{
	#
	# K2HR3 API archive
	#
	if [ ! -f "${K2HR3_API_REPO_ARCHIVE_FILE}" ]; then
		PRNERR "Not found ${K2HR3_API_REPO_ARCHIVE_FILE} archive file."
		return 1
	fi
	if [ -d "${REPO_K2HR3_API_DIR}" ]; then
		if ! rename_file_directory_and_create_directory "${REPO_K2HR3_API_DIR}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${REPO_K2HR3_API_DIR} file for backup."
			return 1
		fi
	fi
	cd "${WORK_DIR}" || exit 1

	if ! tar xvfzo "${K2HR3_API_REPO_ARCHIVE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to extract ${K2HR3_API_REPO_ARCHIVE_FILE} archive for K2HR3 API."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to extract ${K2HR3_API_REPO_ARCHIVE_FILE} archive for K2HR3 API."

	cd "${CURRENT_DIR}" || exit 1

	#
	# K2HR3 APP archive
	#
	if [ ! -f "${K2HR3_APP_REPO_ARCHIVE_FILE}" ]; then
		PRNERR "Not found ${K2HR3_APP_REPO_ARCHIVE_FILE} archive file."
		return 1
	fi
	if [ -d "${REPO_K2HR3_APP_DIR}" ]; then
		if ! rename_file_directory_and_create_directory "${REPO_K2HR3_APP_DIR}" "${BACKUP_SUFFIX}"; then
			PRNERR "Failed to rename ${REPO_K2HR3_APP_DIR} file for backup."
			return 1
		fi
	fi
	cd "${WORK_DIR}" || exit 1

	if ! tar xvfzo "${K2HR3_APP_REPO_ARCHIVE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to extract ${K2HR3_APP_REPO_ARCHIVE_FILE} archive for K2HR3 APP."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to extract ${K2HR3_APP_REPO_ARCHIVE_FILE} archive for K2HR3 APP."

	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#--------------------------------------------------------------
# [Utilities] Setup repository / packages
#--------------------------------------------------------------
#
# Setup package repositories and Install packages for alpine
#
# [Use variables]
#	K2HR3_NODE_OS_VERSION
#	SUDO_PREFIX_CMD
#	IS_USE_PACKAGECLOUD
#	STATUS_PACKAGECLOUD_REPO
#	PKGMGR
#	INSTALL_BASE_PKG_LIST
#	INSTALL_PKG_LIST
#
setup_repositories_packages_for_alpine()
{
	PRNMSG "Setup package repositories and Install packages for alpine"

	#
	# At first, always try to install base packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} add --no-progress --no-cache ${INSTALL_BASE_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install base packages(${INSTALL_BASE_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install base packages(${INSTALL_BASE_PKG_LIST})."

	#
	# Remove installed packages for reinstall
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
	else
		_FOUND_NODEJS_PACKAGE=0
	fi
	if [ "${_FOUND_K2HDKC_PACKAGE}" -eq 1 ] || [ "${_FOUND_NODEJS_PACKAGE}" -eq 1 ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} del ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to remove installed packages(${INSTALL_PKG_LIST})."
			return 1
		fi
		PRNINFO "Succeed to remove installed packages(${INSTALL_PKG_LIST})."
	else
		PRNINFO "Nothing to remove installed packages."
	fi

	#
	# Setup / Remove packagecloud.io repository
	#
	if [ "${IS_USE_PACKAGECLOUD}" -eq 1 ]; then
		if [ "${STATUS_PACKAGECLOUD_REPO}" -ne 1 ]; then
			#
			# Add packagecloud.io repository
			#
			if ({ /bin/sh -c "curl -s https://packagecloud.io/install/repositories/antpickax/stable/script.alpine.sh | ${SUDO_PREFIX_CMD} sh 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to add packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to add packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is existed, so nothing to do."
		fi
	else
		if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
			#
			# Remove packagecloud.io repository
			#
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} sed -i -e 's|^[[:space:]]*https://packagecloud.io/antpickax/.*||g' -e 's|^[[:space:]]*#.*packagecloud.io.*||g' /etc/apk/repositories 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to remove packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is not existed, so nothing to do."
		fi
	fi

	#
	# Install packages
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
	else
		_FOUND_NODEJS_PACKAGE=0
	fi

	#
	# Update packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -q --no-progress 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to ${PKGMGR} update command."
		return 1
	fi
	PRNINFO "Succeed to ${PKGMGR} update command."

	#
	# Upgrade packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} upgrade -q --no-progress 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to ${PKGMGR} upgrade command."
		return 1
	fi
	PRNINFO "Succeed to ${PKGMGR} upgrade command."

	#
	# Install packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} add --no-progress --no-cache ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install packages(${INSTALL_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install packages(${INSTALL_PKG_LIST})."

	PRNINFO "Succeed to setup package repositories and install packages for alpine"

	return 0
}

#
# Setup package repositories and Install packages for ubuntu/debian
#
# [Use variables]
#	NODEJS_VERSION
#	SUDO_PREFIX_CMD
#	IS_USE_PACKAGECLOUD
#	STATUS_PACKAGECLOUD_REPO
#	PKGMGR
#	INSTALL_BASE_PKG_LIST
#	INSTALL_PKG_LIST
#
setup_repositories_packages_for_ubuntu_debian()
{
	PRNMSG "Setup package repositories and Install packages for ubuntu/debian"

	#
	# Setup configuration for package manager
	#
	cat /dev/null > /etc/apt/apt.conf.d/00-aptproxy.conf
	if [ -n "${SCHEME_HTTP_PROXY}" ]; then
		echo "Acquire::http::Proxy \"${SCHEME_HTTP_PROXY}\";" >> /etc/apt/apt.conf.d/00-aptproxy.conf
	fi
	if [ -n "${SCHEME_HTTPS_PROXY}" ]; then
		echo "Acquire::https::Proxy \"${SCHEME_HTTPS_PROXY}\";" >> /etc/apt/apt.conf.d/00-aptproxy.conf
	fi

	#
	# Update
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -y -q 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update packages."
		return 1
	fi
	PRNINFO "Succeed to update packages."

	#
	# At first, always try to install base packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} install -y ${INSTALL_BASE_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install base packages(${INSTALL_BASE_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install base packages(${INSTALL_BASE_PKG_LIST})."

	#
	# Remove installed packages for reinstall
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
		_CUR_NODEJS_VERSION=$(node -v | awk -F '.' '{print $1}' | sed -e "s#^v##gi" | tr -d '\n')
	else
		_FOUND_NODEJS_PACKAGE=0
		_CUR_NODEJS_VERSION=""
	fi
	if [ "${_FOUND_K2HDKC_PACKAGE}" -eq 1 ] || [ "${_FOUND_NODEJS_PACKAGE}" -eq 1 ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} remove -y ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to remove installed packages(${INSTALL_PKG_LIST})."
			return 1
		fi
		_CUR_NODEJS_VERSION=""
		PRNINFO "Succeed to remove installed packages(${INSTALL_PKG_LIST})."
	else
		PRNINFO "Nothing to remove installed packages."
	fi

	#
	# Setup / Remove packagecloud.io repository
	#
	if [ "${IS_USE_PACKAGECLOUD}" -eq 1 ]; then
		if [ "${STATUS_PACKAGECLOUD_REPO}" -ne 1 ]; then
			#
			# Add packagecloud.io repository
			#
			if ({ /bin/sh -c "curl -s https://packagecloud.io/install/repositories/antpickax/stable/script.deb.sh | ${SUDO_PREFIX_CMD} bash 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to add packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to add packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is existed, so nothing to do."
		fi
	else
		if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
			#
			# Remove packagecloud.io repository
			#
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} rm -f /etc/apt/sources.list.d/antpickax_stable.list 2>/dev/null" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove packagecloud.io repository."
				return 1
			fi
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -qq -y 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to ${PKGMGR} update after remove packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to remove packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is not existed, so nothing to do."
		fi
	fi

	#
	# Setup NodeJS repository
	#
	if [ -z "${_CUR_NODEJS_VERSION}" ] || [ "${_CUR_NODEJS_VERSION}" != "${NODEJS_VERSION}" ]; then
		#
		# Remove NodeJS
		#
		if [ -n "${_CUR_NODEJS_VERSION}" ]; then
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} remove -y nodejs 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove installed nodejs package."
				return 1
			fi
			PRNINFO "Succeed to remove installed nodejs package."
		fi

		#
		# Remove existed nodejs repository
		#
		if [ -f /etc/apt/keyrings/nodesource.gpg ]; then
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove existed nodejs repository(gpg)."
				return 1
			fi
			PRNINFO "Succeed to remove existed nodejs repository(gpg)."
		fi
		if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove existed nodejs repository(source list)."
				return 1
			fi
			PRNINFO "Succeed to remove existed nodejs repository(source list)."
		fi

		#
		# Add nodejs repository
		#
		if ({ /bin/sh -c "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key 2>/dev/null | gpg --dearmor 2>/dev/null | ${SUDO_PREFIX_CMD} tee /etc/apt/keyrings/nodesource.gpg >/dev/null 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to download and create gpg file(/etc/apt/keyrings/nodesource.gpg)."
			return 1
		fi
		PRNINFO "Succeed to download and create gpg file(/etc/apt/keyrings/nodesource.gpg)."

		if ({ /bin/sh -c "echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODEJS_VERSION}.x nodistro main' | ${SUDO_PREFIX_CMD} tee /etc/apt/sources.list.d/nodesource.list >/dev/null 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to setup NodeJS v${NODEJS_VERSION} repository."
			return 1
		fi
		PRNINFO "Succeed to setup NodeJS v${NODEJS_VERSION} repository."
	else
		PRNINFO "Already setup NodeJS v${NODEJS_VERSION} repository, so skip this."
	fi

	#
	# Install packages
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
	else
		_FOUND_NODEJS_PACKAGE=0
	fi

	#
	# Update packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -qq -y 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to ${PKGMGR} update command."
		return 1
	fi
	PRNINFO "Succeed to ${PKGMGR} update command."

	#
	# Install packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} install -y ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install packages(${INSTALL_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install packages(${INSTALL_PKG_LIST})."

	PRNINFO "Succeed to setup package repositories and install packages for ubuntu/debian"

	return 0
}

#
# Setup package repositories and Install packages for ubuntu/debian
#
# [Use variables]
#	K2HR3_NODE_OS_NAME
#	K2HR3_NODE_OS_VERSION
#	NODEJS_VERSION
#	SUDO_PREFIX_CMD
#	IS_USE_PACKAGECLOUD
#	STATUS_PACKAGECLOUD_REPO
#	PKGMGR
#	INSTALL_BASE_PKG_LIST
#	INSTALL_PKG_LIST
#
setup_repositories_packages_for_rocky_fedora()
{
	PRNMSG "Setup package repositories and Install packages for rocky/fedora"

	#
	# Update
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -y -q 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update packages."
		return 1
	fi
	PRNINFO "Succeed to update packages."

	#
	# At first, always try to install base packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} install -y --skip-broken ${INSTALL_BASE_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install base packages(${INSTALL_BASE_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install base packages(${INSTALL_BASE_PKG_LIST})."

	#
	# Remove installed packages for reinstall
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
		_CUR_NODEJS_VERSION=$(node -v | awk -F '.' '{print $1}' | sed -e "s#^v##gi" | tr -d '\n')
	else
		_FOUND_NODEJS_PACKAGE=0
		_CUR_NODEJS_VERSION=""
	fi
	if [ "${_FOUND_K2HDKC_PACKAGE}" -eq 1 ] || [ "${_FOUND_NODEJS_PACKAGE}" -eq 1 ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} remove -y ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to remove installed packages(${INSTALL_PKG_LIST})."
			return 1
		fi
		_CUR_NODEJS_VERSION=""
		PRNINFO "Succeed to remove installed packages(${INSTALL_PKG_LIST})."
	else
		PRNINFO "Nothing to remove installed packages."
	fi

	#
	# Setup / Remove packagecloud.io repository
	#
	if [ "${IS_USE_PACKAGECLOUD}" -eq 1 ]; then
		if [ "${STATUS_PACKAGECLOUD_REPO}" -ne 1 ]; then
			#
			# Add packagecloud.io repository
			#
			if ({ /bin/sh -c "curl -s https://packagecloud.io/install/repositories/antpickax/stable/script.rpm.sh | ${SUDO_PREFIX_CMD} bash 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to add packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to add packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is existed, so nothing to do."
		fi
	else
		if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
			#
			# Remove packagecloud.io repository
			#
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} rm -f /etc/yum.repos.d/antpickax_stable.repo 2>/dev/null" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove packagecloud.io repository."
				return 1
			fi
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -q -y 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to ${PKGMGR} update after remove packagecloud.io repository."
				return 1
			fi
			PRNINFO "Succeed to remove packagecloud.io repository."
		else
			PRNINFO "Already packagecloud.io repository is not existed, so nothing to do."
		fi
	fi

	#
	# Setup NodeJS repository
	#
	if [ -z "${_CUR_NODEJS_VERSION}" ] || [ "${_CUR_NODEJS_VERSION}" != "${NODEJS_VERSION}" ]; then
		#
		# Remove NodeJS
		#
		if [ -n "${_CUR_NODEJS_VERSION}" ]; then
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} remove -y nodejs 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove installed nodejs package."
				return 1
			fi
			PRNINFO "Succeed to remove installed nodejs package."
		fi

		#
		# Remove existed nodejs repository
		#
		if [ -f /etc/yum.repos.d/nodesource-nodejs.repo ]; then
			if ({ /bin/sh -c "${SUDO_PREFIX_CMD} rm -f /etc/yum.repos.d/nodesource-nodejs.repo 2>/dev/null" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to remove existed nodejs repository."
				return 1
			fi
			PRNINFO "Succeed to remove existed nodejs repository."
		fi

		#
		# Add nodejs repository
		#
		if ({ /bin/sh -c "curl -fsSL https://rpm.nodesource.com/setup_${NODEJS_VERSION}.x 2>/dev/null | ${SUDO_PREFIX_CMD} bash 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to setup NodeJS v${NODEJS_VERSION} repository."
			return 1
		fi
		PRNINFO "Succeed to setup NodeJS v${NODEJS_VERSION} repository."
	else
		PRNINFO "Already setup NodeJS v${NODEJS_VERSION} repository, so skip this."
	fi

	#
	# Install packages
	#
	if command -v k2hdkc >/dev/null 2>&1; then
		_FOUND_K2HDKC_PACKAGE=1
	else
		_FOUND_K2HDKC_PACKAGE=0
	fi
	if command -v node >/dev/null 2>&1; then
		_FOUND_NODEJS_PACKAGE=1
	else
		_FOUND_NODEJS_PACKAGE=0
	fi

	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "rocky"; then
		#
		# Setup epel repository
		#
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} install -y --skip-broken epel-release 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to install epel-release package."
			return 1
		fi
		PRNINFO "Succeed to install epel-release package."

		#
		# Enable epel and crb(powertools)
		#
		_OS_MAJOR_VERSION=$(echo "${K2HR3_NODE_OS_VERSION}" | awk -F '.' '{print $1}' | tr -d '\n')
		_ADDITIONAL_REPO_NAME=""
		if [ "${_OS_MAJOR_VERSION}" -lt 8 ]; then
			PRNERR "OS version ${K2HR3_NODE_OS_VERSION} is too low to support."
			return 1
		elif [ "${_OS_MAJOR_VERSION}" -eq 8 ]; then
			_ADDITIONAL_REPO_NAME=$(dnf repolist | awk '{print $1}' | grep 'powertools' | tr '\n' ',' | sed -e 's#^,*##g' -e 's#,*$##g')
			if [ -n "${_ADDITIONAL_REPO_NAME}" ]; then
				_ADDITIONAL_REPO_NAME=",${_ADDITIONAL_REPO_NAME}"
			else
				PRNERR "Not found powertools repository, so skip to enable it. but maybe fail to install some packages."
			fi
		elif [ "${_OS_MAJOR_VERSION}" -eq 9 ]; then
			_ADDITIONAL_REPO_NAME=$(dnf repolist | awk '{print $1}' | grep 'crb' | tr '\n' ',' | sed -e 's#^,*##g' -e 's#,*$##g')
			if [ -n "${_ADDITIONAL_REPO_NAME}" ]; then
				_ADDITIONAL_REPO_NAME=",${_ADDITIONAL_REPO_NAME}"
			else
				PRNWARN "Not found crb repository, so try to specify \"crb\" repository directly."
				_ADDITIONAL_REPO_NAME=",crb"
			fi
		elif [ "${_OS_MAJOR_VERSION}" -gt 9 ]; then
			PRNERR "OS version ${K2HR3_NODE_OS_VERSION} is too high to support."
			return 1
		fi

		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} config-manager --enable epel${_ADDITIONAL_REPO_NAME} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to enable epel and ${_ADDITIONAL_REPO_NAME} repository."
			return 1
		fi
		PRNINFO "Succeed to enable epel and ${_ADDITIONAL_REPO_NAME} repository."
	fi

	#
	# Update packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} update -q -y 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to ${PKGMGR} update command."
		return 1
	fi
	PRNINFO "Succeed to ${PKGMGR} update command."

	#
	# Install packages
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKGMGR} install -y --skip-broken ${INSTALL_PKG_LIST} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install packages(${INSTALL_PKG_LIST})."
		return 1
	fi
	PRNINFO "Succeed to install packages(${INSTALL_PKG_LIST})."

	PRNINFO "Succeed to setup package repositories and install packages for rocky/fedora"

	return 0
}

#
# Setup package repositories and Install packages
#
# [Use variables]
#	K2HR3_NODE_OS_NAME
#	K2HR3_NODE_OS_VERSION
#	NODEJS_VERSION
#	SUDO_PREFIX_CMD
#	IS_USE_PACKAGECLOUD
#	STATUS_PACKAGECLOUD_REPO
#	PKGMGR
#	INSTALL_BASE_PKG_LIST
#	INSTALL_PKG_LIST
#
setup_repositories_packages()
{
	if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
		if ! setup_repositories_packages_for_alpine; then
			return 1
		fi
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		if ! setup_repositories_packages_for_ubuntu_debian; then
			return 1
		fi
	elif echo "${K2HR3_NODE_OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! setup_repositories_packages_for_rocky_fedora; then
			return 1
		fi
	else
		PRNERR "Unknown OS type(${K2HR3_NODE_OS_NAME})."
		return 1
	fi

	#
	# Additional setup repositories
	#
	if ! addition_setup_package_repositories "${K2HR3_NODE_OS_NAME}" "${K2HR3_NODE_OS_VERSION}"; then
		return 1
	fi

	return 0
}

#--------------------------------------------------------------
# [Utilities] Setup NPM/NodeJS
#--------------------------------------------------------------
#
# Setup configuration for npm command
#
# [Use variables]
#	SCHEME_HTTP_PROXY
#	SCHEME_HTTPS_PROXY
#	NPM_REGISTORIES
#
setup_npm_configuration()
{
	PRNMSG "Setup configuration for npm command"

	if [ -n "${SCHEME_HTTP_PROXY}" ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set proxy ${SCHEME_HTTP_PROXY} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to setup NPM configuration for proxy(HTTP_PROXY=${SCHEME_HTTP_PROXY})."
			return 1
		fi
		PRNINFO "Succeed to setup NPM configuration for proxy(HTTP_PROXY=${SCHEME_HTTP_PROXY})."
	fi
	if [ -n "${SCHEME_HTTPS_PROXY}" ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set https-proxy ${SCHEME_HTTPS_PROXY} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to setup NPM configuration for proxy(HTTPS_PROXY=${SCHEME_HTTPS_PROXY})."
			return 1
		fi
		PRNINFO "Succeed to setup NPM configuration for proxy(HTTPS_PROXY=${SCHEME_HTTPS_PROXY})."
	fi

	for _one_npm_registory in ${NPM_REGISTORIES}; do
		_ADD_NPMREG_NAME=$(echo "${_one_npm_registory}" | awk -F ',' '{print $1}' 2>/dev/null)
		_ADD_NPMREG_URL=$(echo "${_one_npm_registory}" | awk -F ',' '{print $2}' 2>/dev/null)

		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set ${_ADD_NPMREG_NAME} ${_ADD_NPMREG_URL} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to add NPM registory(${_ADD_NPMREG_NAME}=${_ADD_NPMREG_URL})."
			return 1
		fi
		PRNINFO "Succeed to add NPM registory(${_ADD_NPMREG_NAME}=${_ADD_NPMREG_URL})."
	done

	return 0
}

#--------------------------------------------------------------
# [Utilities] Setup Working Directories
#--------------------------------------------------------------
#
# Rename file/directory and Create a new directory
#
# [INPUT]
#	$1		: file/directory path
#	$2		: backup suffix(default: "backup")
#	$3		: 0(default: only backup) / 1(backup and create directory)
#
rename_file_directory_and_create_directory()
{
	if [ $# -lt 1 ] || [ -z "$1" ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_TARGET_PATH="$1"
	shift

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		_BACKUP_SUFFIX="backup"
	else
		_BACKUP_SUFFIX="$1"
		shift
	fi

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		_WITH_CREATION=0
	elif [ "$1" -eq 1 ]; then
		_WITH_CREATION=1
	else
		_WITH_CREATION=0
	fi

	#
	# Check file/directory existence
	#
	if [ -f "${_TARGET_PATH}" ]; then
		#
		# Rename file
		#
		if ({ /bin/sh -c "mv ${_TARGET_PATH} ${_TARGET_PATH}.${_BACKUP_SUFFIX} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to rename existed ${_TARGET_PATH} file to ${_TARGET_PATH}.${_BACKUP_SUFFIX}"
			return 1
		fi
		PRNINFO "Succeed to rename existed ${_TARGET_PATH} file to ${_TARGET_PATH}.${_BACKUP_SUFFIX}"
	elif [ -d "${_TARGET_PATH}" ]; then
		#
		# Rename directory
		#
		if ({ /bin/sh -c "mv ${_TARGET_PATH} ${_TARGET_PATH}.${_BACKUP_SUFFIX} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to rename existed ${_TARGET_PATH} directory to ${_TARGET_PATH}.${_BACKUP_SUFFIX}"
			return 1
		fi
		PRNINFO "Succeed to rename existed ${_TARGET_PATH} directory to ${_TARGET_PATH}.${_BACKUP_SUFFIX}"
	fi

	#
	# Create new directory
	#
	if [ "${_WITH_CREATION}" -eq 1 ]; then
		if ! mkdir -p "${_TARGET_PATH}" >/dev/null 2>&1; then
			PRNERR "Failed to create new ${_TARGET_PATH} directory."
			return 1
		fi
		PRNINFO "Succeed to create new ${_TARGET_PATH} directory."
	fi

	return 0
}

#
# Setup Working directories for git repositories and other(conf, logs, pids)
#
# [Using Variables]
#	CURRENT_DIR
#	WORK_DIR
#	WORK_CONF_DIR
#	WORK_LOGS_DIR
#	WORK_PIDS_DIR
#	WORK_DATA_DIR
#	REPO_K2HR3_API_DIR
#	REPO_K2HR3_APP_DIR
#	REPO_K2HR3_API
#	REPO_K2HR3_APP
#	BACKUP_SUFFIX
#
setup_working_directries()
{
	#
	# Check directories
	#
	if [ ! -d "${WORK_DIR}" ]; then
		PRNERR "Not found ${WORK_DIR} directory."
		return 1
	fi

	#
	# Setup other directories
	#
	PRNMSG "Setup other directories(conf, logs. pids)"

	if	! rename_file_directory_and_create_directory "${WORK_CONF_DIR}" "${BACKUP_SUFFIX}" 1 || \
		! rename_file_directory_and_create_directory "${WORK_LOGS_DIR}" "${BACKUP_SUFFIX}" 1 || \
		! rename_file_directory_and_create_directory "${WORK_PIDS_DIR}" "${BACKUP_SUFFIX}" 1 || \
		! rename_file_directory_and_create_directory "${WORK_DATA_DIR}" "${BACKUP_SUFFIX}" 1; then
		return 0
	fi

	#
	# Extract K2HR3 API/APP repository directory
	#
	PRNMSG "Extract K2HR3 API/APP repository directory(${REPO_K2HR3_API_DIR}, ${REPO_K2HR3_APP_DIR})"

	if ! extract_k2hr3_repository_archives; then
		PRNERR "Failed to extract API/APP repository directory(${REPO_K2HR3_API_DIR}, ${REPO_K2HR3_APP_DIR})."
		return 1
	fi
	PRNINFO "Succeed to extract API/APP repository directory(${REPO_K2HR3_API_DIR}, ${REPO_K2HR3_APP_DIR})."

	#
	# Install K2HR3 API node packages
	#
	PRNMSG "Install K2HR3 API node packages"

	cd "${REPO_K2HR3_API_DIR}" || exit 1

	if [ -d "${REPO_K2HR3_API_DIR}/node_modules" ]; then
		rm -rf "${REPO_K2HR3_API_DIR}/node_modules"
	fi
	if [ -f "${REPO_K2HR3_API_DIR}/package-lock.json" ]; then
		rm -f "${REPO_K2HR3_API_DIR}/package-lock.json"
	fi
	if ({ /bin/sh -c "npm install 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install K2HR3 API node packages."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	cd "${CURRENT_DIR}" || exit 1
	PRNINFO "Succeed to install K2HR3 API node packages."

	#
	# Install K2HR3 APP node packages and Build
	#
	PRNMSG "Install K2HR3 APP node packages and Build"

	cd "${REPO_K2HR3_APP_DIR}" || exit 1

	if [ -d "${REPO_K2HR3_APP_DIR}/node_modules" ]; then
		rm -rf "${REPO_K2HR3_APP_DIR}/node_modules"
	fi
	if [ -f "${REPO_K2HR3_APP_DIR}/package-lock.json" ]; then
		rm -f "${REPO_K2HR3_APP_DIR}/package-lock.json"
	fi
	if ({ /bin/sh -c "npm install 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install K2HR3 APP node packages."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	PRNINFO "Succeed to install K2HR3 APP node packages."

	if ({ /bin/sh -c "npm run build 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to build K2HR3 APP."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	cd "${CURRENT_DIR}" || exit 1
	PRNINFO "Succeed to build K2HR3 APP."

	return 0
}

#--------------------------------------------------------------
# [Utilities] Setup All Configuration files
#--------------------------------------------------------------
#
# Setup One Configuration files for K2HDKC cluster
#
# [INPUT]
#	$1		: Date string
#	$2		: Node Mode("server" / "slave")
#	$3		: K2HFILE path
#	$4		: K2HDKC self port
#	$5		: K2HDKC self control port
#	$6		: K2HDKC server(0) port
#	$7		: K2HDKC server(0) control port
#	$8		: K2HDKC server(1) port
#	$9		: K2HDKC server(1) control port
#	$10		: K2HDKC slave(0) control port
#	$11		: Output file path
#
create_one_k2hdkc_configuration_file()
{
	if [ $# -lt 11 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_TEMPL_DATE_STRING="$1"
	_TEMPL_NODE_MODE_STRING=$(echo "$2" | tr '[:lower:]' '[:upper:]')
	_TEMPL_K2HDKC_K2H_PATH="$3"
	_TEMPL_SELF_NODE_PORT="$4"
	_TEMPL_SELF_NODE_CTLPORT="$5"
	_TEMPL_K2HDKC_SERVER_NODE_0_PORT="$6"
	_TEMPL_K2HDKC_SERVER_NODE_0_CTLPORT="$7"
	_TEMPL_K2HDKC_SERVER_NODE_1_PORT="$8"
	_TEMPL_K2HDKC_SERVER_NODE_1_CTLPORT="$9"
	_TEMPL_K2HDKC_SLAVE_NODE_0_CTLPORT="${10}"
	_OUTPUT_FILEPATH="${11}"

	#
	# Create Configration file
	#
	{
		echo '#'
		echo '# K2HDKC FOR K2HR3 CONFIGURATION FILE in K2HR3 Utilities'
		echo '#'
		echo '# Copyright 2025 Yahoo Japan Corporation.'
		echo '#'
		echo '# K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers'
		echo '# common management information for the cloud.'
		echo '# K2HR3 can dynamically manage information as "who", "what", "operate".'
		echo '# These are stored as roles, resources, policies in K2hdkc, and the'
		echo '# client system can dynamically read and modify these information.'
		echo '#'
		echo '# For the full copyright and license information, please view'
		echo '# the licenses file that was distributed with this source code.'
		echo '#'
		echo '# AUTHOR:   Takeshi Nakatani'
		echo '# CREATE:   Fri Feb 21 2025'
		echo '# REVISION:'
		echo '#'
		echo ''
		echo '################################################################'
		echo '# NOTE:'
		echo '# - k2hdkc server node must not be use MQACK'
		echo '# - k2hash for k2hdkc is memory mode, because multi server node'
		echo '#   run on one server and we do not use configuration files for'
		echo '#   each process.'
		echo '################################################################'
		echo ''
		echo '#'
		echo '# GLOBAL SECTION'
		echo '#'
		echo '[GLOBAL]'
		echo 'FILEVERSION     = 1'
		echo "DATE            = ${_TEMPL_DATE_STRING}"
		echo 'GROUP           = K2HR3DKC'
		echo "MODE            = ${_TEMPL_NODE_MODE_STRING}"
		echo 'DELIVERMODE     = hash'
		echo 'MAXCHMPX        = 8'
		echo 'REPLICA         = 1'
		echo 'MAXMQSERVER     = 32'
		echo 'MAXMQCLIENT     = 32'
		echo 'MQPERATTACH     = 8'
		echo 'MAXQPERSERVERMQ = 8'
		echo 'MAXQPERCLIENTMQ = 8'
		echo 'MAXMQPERCLIENT  = 8'
		echo 'MAXHISTLOG      = 0'

		if [ "${_TEMPL_NODE_MODE_STRING}" = "SERVER" ]; then
			echo "PORT            = ${_TEMPL_SELF_NODE_PORT}"
		fi
		echo "CTLPORT         = ${_TEMPL_SELF_NODE_CTLPORT}"
		echo "SELFCTLPORT     = ${_TEMPL_SELF_NODE_CTLPORT}"
		echo 'RWTIMEOUT       = 5000'
		echo 'RETRYCNT        = 5000'
		echo 'CONTIMEOUT      = 5000'
		echo 'MQRWTIMEOUT     = 5000'
		echo 'MQRETRYCNT      = 5000'
		echo 'MQACK           = no'
		echo 'AUTOMERGE       = on'
		echo 'DOMERGE         = on'
		echo 'MERGETIMEOUT    = 0'
		echo 'SOCKTHREADCNT   = 8'
		echo 'MQTHREADCNT     = 8'
		echo 'MAXSOCKPOOL     = 8'
		echo 'SOCKPOOLTIMEOUT = 0'
		echo 'SSL             = no'
		echo 'K2HFULLMAP      = on'
		echo 'K2HMASKBIT      = 4'
		echo 'K2HCMASKBIT     = 4'
		echo 'K2HMAXELE       = 4'
		echo ''
		echo '#'
		echo '# SERVER NODES SECTION'
		echo '#'
		echo '# [VARIABLES]'
		echo '#    OS TYPE    = 1:alpine, 2:ubuntu, 3:debian, 4:rocky, 5:fedora'
		echo '# [FORMAT]'
		echo '#    PORT       = 8<OS TYPE>20/22 (ex. ALPINE, No.0 -> 8120)'
		echo '#    CTLPORT    = 8<OS TYPE>21/23 (ex. ALPINE, No.1 -> 8123)'
		echo '#'
		echo '[SVRNODE]'
		echo 'NAME            = 127.0.0.1'
		echo "PORT            = ${_TEMPL_K2HDKC_SERVER_NODE_0_PORT}"
		echo "CTLPORT         = ${_TEMPL_K2HDKC_SERVER_NODE_0_CTLPORT}"
		echo 'SSL             = no'
		echo ''
		echo '[SVRNODE]'
		echo 'NAME            = 127.0.0.1'
		echo "PORT            = ${_TEMPL_K2HDKC_SERVER_NODE_1_PORT}"
		echo "CTLPORT         = ${_TEMPL_K2HDKC_SERVER_NODE_1_CTLPORT}"
		echo 'SSL             = no'
		echo ''
		echo '#'
		echo '# SLAVE NODES SECTION'
		echo '#'
		echo '# [VARIABLES]'
		echo '#    OS TYPE    = 1:alpine, 2:ubuntu, 3:debian, 4:rocky, 5:fedora'
		echo '# [FORMAT]'
		echo '#    CTLPORT    = 8<OS TYPE>24 (ex. ALPINE, No.0 -> 8124)'
		echo '#'
		echo '[SLVNODE]'
		echo 'NAME            = [.]*'
		echo "CTLPORT         = ${_TEMPL_K2HDKC_SLAVE_NODE_0_CTLPORT}"
		echo 'SSL             = no'
		echo ''

		if [ "${_TEMPL_NODE_MODE_STRING}" = "SERVER" ]; then
			echo '#'
			echo '# K2HDKC SECTION'
			echo '#'
			echo '[K2HDKC]'
			echo '#RCVTIMEOUT     = 1000          ### Default(1000), timeout ms for receiving command result.'
			echo '#SVRNODEINI     = <file path>   ### Default(empty = same this file)'
			echo '#REPLCLUSTERINI = <file path>   ### Default(empty), for DTOR INI FILE because transaction chmpx is different from this file'
			echo '                                ###                 everything about dtor setting is specified in replclusterini file.'
			echo '                                ###                 If needs, you can set that dtor runs with plugin and putting file(transaction).'
			echo '#DTORTHREADCNT  = 1             ### Default(1), you MUST set same as the value in k2htpdtor configuration file'
			echo '#DTORCTP        = path.so       ### Default(k2htpdtor.so), custom transaction plugin path'
			echo 'K2HTYPE         = file          ### Default(file),  parameter can be set M/MEM/MEMORY / F/FILE / T/TEMP/TEMPORARY'
			echo "K2HFILE         = ${_TEMPL_K2HDKC_K2H_PATH}"
			echo 'K2HFULLMAP      = on            ### Default(on)'
			echo 'K2HINIT         = no            ### Default(no)'
			echo 'K2HMASKBIT      = 4'
			echo 'K2HCMASKBIT     = 4'
			echo 'K2HMAXELE       = 4'
			echo 'K2HPAGESIZE     = 256'
			echo '#PASSPHRASES    = <pass phrase> ### Default(empty), many entry is allowed. set either the PASSPHRASES or PASSFILE'
			echo '#PASSFILE       = <file path>   ### Default(empty), set either the PASSPHRASES or PASSFILE'
			echo '#HISTORY        = on            ### Default(no), MUST DO SOME WORK FOR MAKING HISTORY KEY DATA TO OTHER SERVERS'
			echo '#EXPIRE         = 300           ### Default(no), MUST SPECIFY THIS VALUE'
			echo '#ATTRPLUGIN     = <file path>   ### Default(empty), many entry is allowed, and calling sequence is same keywords in this file'
			echo '#MINTHREAD      = 1             ### Default(1), minimum processing thread count'
			echo 'MAXTHREAD       = 10            ### Default(100), maximum processing thread count'
			echo '#REDUCETIME     = 30            ### Default(30), time(second) for reducing processing thread to minimum thread count.'
			echo ''
		fi
		echo '#'
		echo '# Local variables:'
		echo '# tab-width: 4'
		echo '# c-basic-offset: 4'
		echo '# End:'
		echo '# vim600: noexpandtab sw=4 ts=4 fdm=marker'
		echo '# vim<600: noexpandtab sw=4 ts=4'
		echo '#'
	} > "${_OUTPUT_FILEPATH}"

	return 0
}

#
# Setup Configuration file for K2HR3 API
#
# [INPUT]
#	$1		: K2HDKC Slave Configuration file path
#	$2		: K2HDKC Slave Control Port
#	$3		: K2HR3 API URL
#	$4		: K2HR3 API Port
#	$5		: Process run user
#	$6		: Output file path
#
# [Using Variables]
#	ADDITION_API_CONF_KEYSTONE
#
create_k2hr3api_configuration_file()
{
	if [ $# -lt 6 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_TEMPL_K2HDKC_SLAVE_INI="$1"
	_TEMPL_K2HDKC_SLAVE_CTLPORT="$2"
	_TEMPL_K2HR3_API_URL="$3"
	_TEMPL_K2HR3_API_PORT="$4"
	_TEMPL_RUN_USER="$5"
	_OUTPUT_FILEPATH="$6"

	#
	# Create Configration file
	#
	{
		echo '/*'
		echo ' *'
		echo ' * K2HDKC FOR K2HR3 API CONFIGURATION FILE in K2HR3 Utilities'
		echo ' *'
		echo ' * Copyright 2025 Yahoo Japan Corporation.'
		echo ' *'
		echo ' * K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers'
		echo ' * common management information for the cloud.'
		echo ' * K2HR3 can dynamically manage information as "who", "what", "operate".'
		echo ' * These are stored as roles, resources, policies in K2hdkc, and the'
		echo ' * client system can dynamically read and modify these information.'
		echo ' *'
		echo ' * For the full copyright and license information, please view'
		echo ' * the licenses file that was distributed with this source code.'
		echo ' *'
		echo ' * AUTHOR:   Takeshi Nakatani'
		echo ' * CREATE:   Fri Feb 21 2025'
		echo ' * REVISION:'
		echo ' */'
		echo ''
		echo '//'
		echo '// [NOTICE]'
		echo '// The corsips is set ANY(*), this is for debugging in local host(conatiner).'
		echo '//'
		echo '{'
		echo "    'corsips': ["
		echo "        '*'"
		echo '    ],'
		echo ''

		if [ -n "${ADDITION_API_CONF_KEYSTONE}" ]; then
			echo "${ADDITION_API_CONF_KEYSTONE}"
		fi

		echo "    'k2hdkc': {"
		echo "        'config':   		'${_TEMPL_K2HDKC_SLAVE_INI}',"
		echo "        'port':     		${_TEMPL_K2HDKC_SLAVE_CTLPORT}"
		echo '    },'
		echo ''
		echo "    'multiproc':    		true,"
		echo "    'scheme':       		'http',"
		echo "    'port':         		${_TEMPL_K2HR3_API_PORT},"
		echo "    'runuser':      		'${_TEMPL_RUN_USER}',"
		echo "    'privatekey':   		'',"
		echo "    'cert':         		'',"
		echo "    'ca':           		'',"
		echo "    'logdir':           	'log',"
		echo "    'accesslogname':    	'access.log',"
		echo "    'consolelogname':   	'error.log',"
		echo "    'watcherlogname':   	'watcher.log',"
		echo "    'wconsolelogname':  	'watchererror.log',"
		echo ''
		echo "    'logrotateopt': {"
		echo "        'compress':         'gzip',"
		echo "        'interval':         '6h',"
		echo "        'initialRotation':  true"
		echo '    },'
		echo ''
		echo "    'userdata': {"
		echo "        'baseuri':          '${_TEMPL_K2HR3_API_URL}',"
		echo "        'cc_templ':         'config/k2hr3-cloud-config.txt.templ',"
		echo "        'script_templ':     'config/k2hr3-init.sh.templ',"
		echo "        'errscript_templ':  'config/k2hr3-init-error.sh.templ',"
		echo "        'algorithm':        'aes-256-cbc',"
		echo "        'passphrase':       'k2hr3_regpass'"
		echo '    },'
		echo ''
		echo "    'k2hr3admin': {"
		echo "        'tenant':           'admintenant',"
		echo "        'delhostrole':      'delhostrole'"
		echo '    },'
		echo ''
		echo "    'confirmtenant':        false,"
		echo ''
		echo "    'chkipconfig': {"
		echo "        'type':             'Listener'"
		echo '    },'
		echo ''
		echo "    'allowcredauth':        true"
		echo '}'
		echo ''
		echo '/*'
		echo ' * Local variables:'
		echo ' * tab-width: 4'
		echo ' * c-basic-offset: 4'
		echo ' * End:'
		echo ' * vim600: noexpandtab sw=4 ts=4 fdm=marker'
		echo ' * vim<600: noexpandtab sw=4 ts=4'
		echo ' */'
	} > "${_OUTPUT_FILEPATH}"

	return 0
}

#
# Setup Configuration file for K2HR3 APP
#
# [INPUT]
#	$1		: K2HR3 APP Port
#	$2		: K2HR3 API Host(hostname or IP address)
#	$3		: K2HR3 API Port
#	$4		: Process run user
#	$5		: Output file path
#
# [Using Variables]
#	ADDITION_APP_CONF_VARIDATOR
#	ADDITION_APP_CONF_ADDITIONAL_KEYS
#
create_k2hr3app_configuration_file()
{
	if [ $# -lt 5 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_TEMPL_K2HR3_APP_PORT="$1"
	_TEMPL_K2HR3_API_HOST="$2"
	_TEMPL_K2HR3_API_PORT="$3"
	_TEMPL_RUN_USER="$4"
	_OUTPUT_FILEPATH="$5"

	#
	# Create Configration file
	#
	{
		echo '/*'
		echo ' *'
		echo ' * K2HDKC FOR K2HR3 APP CONFIGURATION FILE in K2HR3 Utilities'
		echo ' *'
		echo ' * Copyright 2025 Yahoo Japan Corporation.'
		echo ' *'
		echo ' * K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers'
		echo ' * common management information for the cloud.'
		echo ' * K2HR3 can dynamically manage information as "who", "what", "operate".'
		echo ' * These are stored as roles, resources, policies in K2hdkc, and the'
		echo ' * client system can dynamically read and modify these information.'
		echo ' *'
		echo ' * For the full copyright and license information, please view'
		echo ' * the licenses file that was distributed with this source code.'
		echo ' *'
		echo ' * AUTHOR:   Takeshi Nakatani'
		echo ' * CREATE:   Fri Feb 21 2025'
		echo ' * REVISION:'
		echo ' */'
		echo ''
		echo '{'
		echo "    'scheme':           'http',"
		echo "    'port':             ${_TEMPL_K2HR3_APP_PORT},"
		echo "    'multiproc':        true,"
		echo "    'runuser':          '${_TEMPL_RUN_USER}',"
		echo "    'privatekey':       '',"
		echo "    'cert':             '',"
		echo "    'ca':               '',"
		echo "    'validator':        '${ADDITION_APP_CONF_VARIDATOR}',"

		if [ -n "${ADDITION_APP_CONF_ADDITIONAL_KEYS}" ]; then
			echo "${ADDITION_APP_CONF_ADDITIONAL_KEYS}"
		fi

		echo "    'lang':             '${K2HR3_APP_LANG}',"
		echo ''
		echo "    'logdir':           'log',"
		echo "    'accesslogname':    'access.log',"
		echo "    'consolelogname':   'error.log',"
		echo ''
		echo "    'logrotateopt': {"
		echo "        'compress':         'gzip',"
		echo "        'interval':         '6h',"
		echo "        'initialRotation':  true"
		echo '    },'
		echo ''
		echo "    'apischeme':        'http',"
		echo "    'apihost':          '${_TEMPL_K2HR3_API_HOST}',"
		echo "    'apiport':          ${_TEMPL_K2HR3_API_PORT},"
		echo ''
		echo "    'appmenu': ["
		echo '        {'
		echo "            'name':     'Document',"
		echo "            'url':      'https://k2hr3.antpick.ax/'"
		echo '        },'
		echo '        {'
		echo "            'name':     'Support',"
		echo "            'url':      'https://github.com/yahoojapan/k2hr3_app/issues'"
		echo '        }'
		echo '    ],'
		echo ''

		printf '    '\''userdata'\'':         '\''\\\n'
		printf '#include\\n\\\n'
		printf '{{= %%K2HR3_API_HOST_URI%% }}/v1/userdata/{{= %%K2HR3_USERDATA_INCLUDE_PATH%% }}\\n\\\n'
		printf ''\'',\n'
		printf '    '\''secretyaml'\'':       '\''\\\n'
		printf 'apiVersion: v1\\n\\\n'
		printf 'kind: Secret\\n\\\n'
		printf 'metadata:\\n\\\n'
		printf '  name: k2hr3-secret\\n\\\n'
		printf '  namespace: <input your name space>\\n\\\n'
		printf 'type: Opaque\\n\\\n'
		printf 'data:\\n\\\n'
		printf '  K2HR3_ROLETOKEN: {{= %%K2HR3_ROLETOKEN_IN_SECRET%% }}\\n\\\n'
		printf ''\'',\n'
		printf '    '\''sidecaryaml'\'':      '\''\\\n'
		printf 'apiVersion: v1\\n\\\n'
		printf 'kind: Pod\\n\\\n'
		printf 'metadata:\\n\\\n'
		printf '  labels:\\n\\\n'
		printf '    labelName: <label>\\n\\\n'
		printf '  name: <name>\\n\\\n'
		printf 'spec:\\n\\\n'
		printf '  #------------------------------------------------------------\\n\\\n'
		printf '  # K2HR3 Sidecar volume - start\\n\\\n'
		printf '  #------------------------------------------------------------\\n\\\n'
		printf '  volumes:\\n\\\n'
		printf '  - name: k2hr3-volume\\n\\\n'
		printf '    hostPath:\\n\\\n'
		printf '      path: /k2hr3-data\\n\\\n'
		printf '      type: DirectoryOrCreate\\n\\\n'
		printf '  #------------------------------------------------------------\\n\\\n'
		printf '  # K2HR3 Sidecar volume - end\\n\\\n'
		printf '  #------------------------------------------------------------\\n\\\n'
		printf '  containers:\\n\\\n'
		printf '    - name: <your container>\\n\\\n'
		printf '      image: <your image>\\n\\\n'
		printf '      volumeMounts:\\n\\\n'
		printf '      - mountPath: /k2hr3-volume\\n\\\n'
		printf '        name: k2hr3-volume\\n\\\n'
		printf '      command:\\n\\\n'
		printf '        - <your command...>\\n\\\n'
		printf '    #--------------------------------------------------------------------------\\n\\\n'
		printf '    # K2HR3 Sidecar - start\\n\\\n'
		printf '    #--------------------------------------------------------------------------\\n\\\n'
		printf '    - name: k2hr3-sidecar\\n\\\n'
		printf '      image: docker.io/antpickax/k2hr3.sidecar:0.1\\n\\\n'
		printf '      envFrom:\\n\\\n'
		printf '      - secretRef:\\n\\\n'
		printf '          name: k2hr3-secret\\n\\\n'
		printf '      env:\\n\\\n'
		printf '        - name: K2HR3_NODE_NAME\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: spec.nodeName\\n\\\n'
		printf '        - name: K2HR3_POD_NAME\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: metadata.name\\n\\\n'
		printf '        - name: K2HR3_POD_NAMESPACE\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: metadata.namespace\\n\\\n'
		printf '        - name: K2HR3_POD_IP\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: status.podIP\\n\\\n'
		printf '        - name: K2HR3_POD_SERVICE_ACCOUNT\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: spec.serviceAccountName\\n\\\n'
		printf '        - name: K2HR3_NODE_IP\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: status.hostIP\\n\\\n'
		printf '        - name: K2HR3_POD_ID\\n\\\n'
		printf '          valueFrom:\\n\\\n'
		printf '            fieldRef:\\n\\\n'
		printf '              fieldPath: metadata.uid\\n\\\n'
		printf '      volumeMounts:\\n\\\n'
		printf '      - mountPath: /k2hr3-volume\\n\\\n'
		printf '        name: k2hr3-volume\\n\\\n'
		printf '      command:\\n\\\n'
		printf '        - sh\\n\\\n'
		printf '        - -c\\n\\\n'
		printf '        - "while true; do sleep 30; done"\\n\\\n'
		printf '      lifecycle:\\n\\\n'
		printf '        postStart:\\n\\\n'
		printf '          exec:\\n\\\n'
		printf '            command:\\n\\\n'
		printf '              - sh\\n\\\n'
		printf '              - -c\\n\\\n'
		printf '              - "/usr/local/bin/k2hr3-k8s-init.sh -reg -rtoken %s{K2HR3_ROLETOKEN} -role {{= %%K2HR3_ROLEYRN_IN_SIDECAR%% }} {{= %%K2HR3_REST_API_HOST%% }}"\\n\\\n' "\$"
		printf '        preStop:\\n\\\n'
		printf '          exec:\\n\\\n'
		printf '            command:\\n\\\n'
		printf '              - sh\\n\\\n'
		printf '              - -c\\n\\\n'
		printf '              - "/usr/local/bin/k2hr3-k8s-init.sh -del -role {{= %%K2HR3_ROLEYRN_IN_SIDECAR%% }} {{= %%K2HR3_REST_API_HOST%% }}"\\n\\\n'
		printf '    #--------------------------------------------------------------------------\\n\\\n'
		printf '    # K2HR3 Sidecar - end\\n\\\n'
		printf '    #--------------------------------------------------------------------------\\n\\\n'
		printf ''\'',\n'

		echo "    'crcobj': {"
		echo "        'Test custom registration code':    null"
		echo '    }'
		echo '}'
		echo ''
		echo '/*'
		echo ' * Local variables:'
		echo ' * tab-width: 4'
		echo ' * c-basic-offset: 4'
		echo ' * End:'
		echo ' * vim600: noexpandtab sw=4 ts=4 fdm=marker'
		echo ' * vim<600: noexpandtab sw=4 ts=4'
		echo ' */'
	} > "${_OUTPUT_FILEPATH}"

	return 0
}

#
# Setup All Configuration files for K2HR3 system
#
# [Using Variables]
#	DEFAULT_K2HFILE_SUFFIX
#	K2HR3_NODE_OS_NAME
#	K2HR3_NODE_OS_TYPE_NUMBER
#	CURRENT_USER
#	WORK_CONF_DIR
#	WORK_DATA_DIR
#	EXTERNAL_HOST
#	BACKUP_SUFFIX
#	K2HDKC_K2H_PATH
#	K2HDKC_SERVER_NODE_0_CONF_FILE
#	K2HDKC_SERVER_NODE_1_CONF_FILE
#	K2HDKC_SLAVE_NODE_0_CONF_FILE
#	K2HR3_APP_CONF_FILE
#	K2HR3_API_CONF_FILE
#	K2HDKC_SLAVE_NODE_0_CTLPORT
#	K2HR3_APP_PORT
#	K2HR3_API_PORT
#	K2HR3_API_HOST
#	K2HR3_API_URL
#
create_configuration_files()
{
	PRNMSG "Setup Configuration files for K2HDKC cluster"

	#
	# Make additional configuration variables
	#
	#	ADDITION_API_CONF_KEYSTONE
	#	ADDITION_APP_CONF_VARIDATOR
	#	ADDITION_APP_CONF_ADDITIONAL_KEYS
	#
	if ! addition_setup_k2hr3_conf_variables "${RUN_IN_CONTAINER}"; then
		PRNERR "Failed to make additional configuration variables."
		return 1
	fi

	#
	# Configration files for server nodes(2 files) and slave node(1 file)
	#
	# ex) <workdir>/alpine_server_1.ini
	#
	_DATE_STRING=$(date -R)
	K2HDKC_K2H_PATH_NODE_0=$(echo "${K2HDKC_K2H_PATH}" | sed -e "s#${DEFAULT_K2HFILE_SUFFIX_NODENO_KEY}#0#g" | tr -d '\n')
	K2HDKC_K2H_PATH_NODE_1=$(echo "${K2HDKC_K2H_PATH}" | sed -e "s#${DEFAULT_K2HFILE_SUFFIX_NODENO_KEY}#1#g" | tr -d '\n')

	if	! rename_file_directory_and_create_directory "${K2HDKC_SERVER_NODE_0_CONF_FILE}" "${BACKUP_SUFFIX}" 0 || \
		! rename_file_directory_and_create_directory "${K2HDKC_SERVER_NODE_1_CONF_FILE}" "${BACKUP_SUFFIX}" 0 || \
		! rename_file_directory_and_create_directory "${K2HDKC_SLAVE_NODE_0_CONF_FILE}" "${BACKUP_SUFFIX}" 0; then

		PRNERR "Failed to rename existed ${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_[server_0|server_1|slave_0].ini files."
		return 1
	fi
	if	! create_one_k2hdkc_configuration_file "${_DATE_STRING}" "server" "${K2HDKC_K2H_PATH_NODE_0}" "${K2HDKC_SERVER_NODE_0_PORT}" "${K2HDKC_SERVER_NODE_0_CTLPORT}" "${K2HDKC_SERVER_NODE_0_PORT}" "${K2HDKC_SERVER_NODE_0_CTLPORT}"  "${K2HDKC_SERVER_NODE_1_PORT}" "${K2HDKC_SERVER_NODE_1_CTLPORT}" "${K2HDKC_SLAVE_NODE_0_CTLPORT}" "${K2HDKC_SERVER_NODE_0_CONF_FILE}" || \
		! create_one_k2hdkc_configuration_file "${_DATE_STRING}" "server" "${K2HDKC_K2H_PATH_NODE_1}" "${K2HDKC_SERVER_NODE_1_PORT}" "${K2HDKC_SERVER_NODE_1_CTLPORT}" "${K2HDKC_SERVER_NODE_0_PORT}" "${K2HDKC_SERVER_NODE_0_CTLPORT}"  "${K2HDKC_SERVER_NODE_1_PORT}" "${K2HDKC_SERVER_NODE_1_CTLPORT}" "${K2HDKC_SLAVE_NODE_0_CTLPORT}" "${K2HDKC_SERVER_NODE_1_CONF_FILE}" || \
		! create_one_k2hdkc_configuration_file "${_DATE_STRING}" "slave"  "${K2HDKC_K2H_PATH_NODE_0}" 0                              "${K2HDKC_SLAVE_NODE_0_CTLPORT}"  "${K2HDKC_SERVER_NODE_0_PORT}" "${K2HDKC_SERVER_NODE_0_CTLPORT}"  "${K2HDKC_SERVER_NODE_1_PORT}" "${K2HDKC_SERVER_NODE_1_CTLPORT}" "${K2HDKC_SLAVE_NODE_0_CTLPORT}" "${K2HDKC_SLAVE_NODE_0_CONF_FILE}"; then

		PRNERR "Failed to create ${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_[server_0|server_1|slave_0].ini files."
		return 1
	fi
	PRNINFO "Succeed to create ${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_[server_0|server_1|slave_0].ini files:"

	#
	# Configration files for K2HR3 API
	#
	if ! rename_file_directory_and_create_directory "${K2HR3_API_CONF_FILE}" "${BACKUP_SUFFIX}" 0; then
		PRNERR "Failed to rename existed ${K2HR3_API_CONF_FILE} file."
		return 1
	fi
	if ! create_k2hr3api_configuration_file "${K2HDKC_SLAVE_NODE_0_CONF_FILE}" "${K2HDKC_SLAVE_NODE_0_CTLPORT}" "${K2HR3_API_URL}" "${K2HR3_API_PORT}" "${CURRENT_USER}" "${K2HR3_API_CONF_FILE}"; then
		PRNERR "Failed to create ${K2HR3_API_CONF_FILE} file."
		return 1
	fi
	PRNINFO "Succeed to create ${K2HR3_API_CONF_FILE} files:"

	#
	# Configration files for K2HR3 APP
	#
	if ! rename_file_directory_and_create_directory "${K2HR3_APP_CONF_FILE}" "${BACKUP_SUFFIX}" 0; then
		PRNERR "Failed to rename existed ${K2HR3_APP_CONF_FILE} file."
		return 1
	fi
	if ! create_k2hr3app_configuration_file "${K2HR3_APP_PORT}" "${K2HR3_API_HOST}" "${K2HR3_API_PORT}" "${CURRENT_USER}" "${K2HR3_APP_CONF_FILE}"; then
		PRNERR "Failed to create ${K2HR3_APP_CONF_FILE} file."
		return 1
	fi
	PRNINFO "Succeed to create ${K2HR3_APP_CONF_FILE} files:"

	PRNINFO "Succeed to create All configuration files:"
	echo "        ${K2HDKC_SERVER_NODE_0_CONF_FILE}"
	echo "        ${K2HDKC_SERVER_NODE_1_CONF_FILE}"
	echo "        ${K2HDKC_SLAVE_NODE_0_CONF_FILE}"
	echo "        ${K2HR3_API_CONF_FILE}"
	echo "        ${K2HR3_APP_CONF_FILE}"
	echo ""

	return 0
}

#--------------------------------------------------------------
# [Utilities] Run/Stop processes
#--------------------------------------------------------------
#
# Make docker proxy environment options
#
# [Using Variables]
#	K2HR3_NODE_OS_NAME
#	HTTP_PROXY
#	HTTPS_PROXY
#	NO_PROXY
#	SCHEME_HTTP_PROXY
#	SCHEME_HTTPS_PROXY
#
# [Setup variables]
#	DOCKER_ENV_OPTIONS
#
setup_docker_proxy_env_options()
{
	#
	# Setup option for PROXY environments
	#
	DOCKER_ENV_OPTIONS=$(
		if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
			if [ -n "${SCHEME_HTTP_PROXY}" ]; then
				printf " -e HTTP_PROXY=%s" "${SCHEME_HTTP_PROXY}"
				printf " -e http_proxy=%s" "${SCHEME_HTTP_PROXY}"
			fi
			if [ -n "${SCHEME_HTTPS_PROXY}" ]; then
				printf " -e HTTPS_PROXY=%s" "${SCHEME_HTTPS_PROXY}"
				printf " -e https_proxy=%s" "${SCHEME_HTTPS_PROXY}"
			fi
			if [ -n "${NO_PROXY}" ]; then
				printf " -e NO_PROXY=%s" "${NO_PROXY}"
				printf " -e no_proxy=%s" "${NO_PROXY}"
			fi
		else
			if [ -n "${HTTP_PROXY}" ]; then
				printf " -e HTTP_PROXY=%s" "${HTTP_PROXY}"
				printf " -e http_proxy=%s" "${HTTP_PROXY}"
			fi
			if [ -n "${HTTPS_PROXY}" ]; then
				printf " -e HTTPS_PROXY=%s" "${HTTPS_PROXY}"
				printf " -e https_proxy=%s" "${HTTPS_PROXY}"
			fi
			if [ -n "${NO_PROXY}" ]; then
				printf " -e NO_PROXY=%s" "${NO_PROXY}"
				printf " -e no_proxy=%s" "${NO_PROXY}"
			fi
		fi
	)
	DOCKER_ENV_OPTIONS=$(echo "${DOCKER_ENV_OPTIONS}" | sed -e 's#^[[:space:]]*##g' -e 's#[[:space:]]*$##g')

	return 0
}

#
# Run Container and Script in container
#
# [INPUT]
#	$1		: Docker image path(ex. alpine:3.21)
#
# [Using Variables]
#	K2HR3_NODE_OS_NAME
#	K2HR3_NODE_CONTAINER_NAME
#	RUN_MODE
#	SCHEME_HTTP_PROXY
#	SCHEME_HTTPS_PROXY
#	HTTP_PROXY
#	HTTPS_PROXY
#	NO_PROXY
#	WORK_DIR
#	IS_USE_PACKAGECLOUD
#	NODEJS_VERSION
#	K2HR3_API_REPO_ARCHIVE_FILE
#	K2HR3_APP_REPO_ARCHIVE_FILE
#	OVERRIDE_CONF_FILEPATH
#	ADDITION_CONTAINER_OPTION
#	ADDITION_IN_CONTAINER_OPTION
#	EXTERNAL_HOST
#	NPM_REGISTORIES
#   K2HR3_APP_PORT
#   K2HR3_API_PORT
#
# [Setup variables]
#	CONTAINER_ID
#
run_container_script()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_IMAGE_PATH="$1"

	#
	# Make container name
	#
	_IMAGE_NAME=$(echo "${_IMAGE_PATH}" | sed -e 's#.*/##g' -e 's#:.*$##g')
	_IN_CONTAIER_SCRIPT_NAME="${PROGRAM_PREFIX_NAME}${IN_CONTAINER_SCRIPT_SUFFIX}"

	#
	# Make DOCKER_ENV_OPTIONS variable (for docker proxy environment options)
	#
	if ! setup_docker_proxy_env_options; then
		PRNERR "Failed to make DOCKER_ENV_OPTIONS variable (for docker proxy environment options)."
		return 1
	fi

	#
	# Port mapping options
	#
	if [ "${RUN_MODE}" = "start" ]; then
		_CONTAINER_PORT_OPTIONS=$(
			printf " -p %d:%d" "${K2HR3_APP_PORT}" "${K2HR3_APP_PORT}"
			printf " -p %d:%d" "${K2HR3_API_PORT}" "${K2HR3_API_PORT}"
		)
	else
		_CONTAINER_PORT_OPTIONS=""
	fi

	#
	# Additional container options (ADDITION_CONTAINER_OPTION)
	#
	if ! addition_setup_container_launch_options; then
		PRNERR "Failed to make ADDITION_CONTAINER_OPTION variable(for launching docker conatiner options)."
		return 1
	fi

	#
	# Additional script options (ADDITION_IN_CONTAINER_OPTION)
	#
	if ! addition_setup_container_script_options; then
		PRNERR "Failed to make ADDITION_IN_CONTAINER_OPTION variable by addition_setup_container_script_options."
		return 1
	fi

	#
	# Make all command options/parameters
	#
	_CONTAINER_ALL_OPTIONS=$(
		printf " --yes"
		printf " --workdir %s" "${WORK_DIR}"

		if [ "${RUN_MODE}" = "start" ]; then
			if [ "${IS_USE_PACKAGECLOUD}" -eq 0 ]; then
				printf " --not_use_pckagecloud"
			fi

			printf " --nodejs_version %s" "${NODEJS_VERSION}"
			printf " --repo_k2hr3_api %s" "${REPO_K2HR3_API}"
			printf " --repo_k2hr3_app %s" "${REPO_K2HR3_APP}"
			printf " --host_external %s"  "${EXTERNAL_HOST}"

			for _one_npm_registory in ${NPM_REGISTORIES}; do
				printf " --npm_registory %s" "${_one_npm_registory}"
			done

			if [ -n "${ADDITION_IN_CONTAINER_OPTION}" ]; then
				printf " %s" "${ADDITION_IN_CONTAINER_OPTION}"
			fi
		fi

		printf " %s" "${RUN_MODE}"
	)

	#
	# Run container
	#
	if [ "${RUN_MODE}" = "start" ]; then
		PRNMSG "Run docker container(${_IMAGE_NAME})"
		/bin/sh -c "docker run --privileged --init --name ${K2HR3_NODE_CONTAINER_NAME} ${_CONTAINER_PORT_OPTIONS} ${ADDITION_CONTAINER_OPTION} ${_IMAGE_PATH} /bin/sh -c \"tail -f /dev/null\" &"

		#
		# Check container running
		#
		CONTAINER_ID=""
		_WAIT_COUNT="${CONTAINER_START_WAIT_COUNT}"
		while [ "${_WAIT_COUNT}" -gt 0 ]; do
			sleep "${PROC_START_WAIT_SEC}"

			#
			# Is runnning
			#
			CONTAINER_ID=$(docker ps -f name="${K2HR3_NODE_CONTAINER_NAME}" -f status=running | grep -v 'CONTAINER ID' | awk '{print $1}' | tr -d '\n')
			if [ -z "${CONTAINER_ID}" ]; then
				#
				# Is exiting
				#
				CONTAINER_ID=$(docker ps -f name="${K2HR3_NODE_CONTAINER_NAME}" -f status=exited | grep -v 'CONTAINER ID' | awk '{print $1}' | tr -d '\n')
				if [ -n "${CONTAINER_ID}" ]; then
					#
					# Failed to run container
					#
					PRNERR "Failed to run container(command: docker run --privileged --init --name ${K2HR3_NODE_CONTAINER_NAME} ${_CONTAINER_PORT_OPTIONS} ${ADDITION_CONTAINER_OPTION} ${_IMAGE_PATH} /bin/sh -c \"tail -f /dev/null\")"
					return 1
				fi
				_WAIT_COUNT=$((_WAIT_COUNT - 1))
			else
				PRNINFO "Succeed to run container=${CONTAINER_ID} (command: docker run --privileged --init --name ${K2HR3_NODE_CONTAINER_NAME} ${_CONTAINER_PORT_OPTIONS} ${ADDITION_CONTAINER_OPTION} ${_IMAGE_PATH} /bin/sh -c \"tail -f /dev/null\")"
				_WAIT_COUNT=0
			fi
		done
		if [ -z "${CONTAINER_ID}" ]; then
			PRNERR "Timeouted, could not run container(command: docker run --privileged --init --name ${K2HR3_NODE_CONTAINER_NAME} ${_CONTAINER_PORT_OPTIONS} ${ADDITION_CONTAINER_OPTION} ${_IMAGE_PATH} /bin/sh -c \"tail -f /dev/null\")"
			return 1
		fi

		#
		# Copy this script and additional configuration into container
		#
		PRNMSG "Copy script(${PROGRAM_NAME}) into docker container(${CONTAINER_ID})"
		if ({ /bin/sh -c "docker cp ${SCRIPTDIR}/${PROGRAM_NAME} ${CONTAINER_ID}:/${_IN_CONTAIER_SCRIPT_NAME} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to copy script(${PROGRAM_NAME}) into docker container(${CONTAINER_ID}:/${_IN_CONTAIER_SCRIPT_NAME})"
			return 1
		fi
		PRNINFO "Succeed to copy script(${PROGRAM_NAME}) into docker container(${CONTAINER_ID}:/${_IN_CONTAIER_SCRIPT_NAME})"

		if [ -n "${OVERRIDE_CONF_FILEPATH}" ]; then
			PRNMSG "Copy additional configuration(${OVERRIDE_CONF_FILEPATH}) into docker container(${CONTAINER_ID})"
			if ({ /bin/sh -c "docker cp ${OVERRIDE_CONF_FILEPATH} ${CONTAINER_ID}:/${OVERRIDE_CONF_FILENAME} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
				PRNERR "Failed to copy additional configuration(${OVERRIDE_CONF_FILEPATH}) into docker container(${CONTAINER_ID}:/${OVERRIDE_CONF_FILENAME})"
				return 1
			fi
			PRNINFO "Succeed to copy additional configuration(${OVERRIDE_CONF_FILEPATH}) into docker container(${CONTAINER_ID}:/${OVERRIDE_CONF_FILENAME})"
		fi

		#
		# Copy K2HR3 API/APP archives into container
		#
		PRNMSG "Copy K2HR3 API/APP archives(${K2HR3_API_REPO_ARCHIVE_FILE}, ${K2HR3_APP_REPO_ARCHIVE_FILE}) into container(${CONTAINER_ID})"
		if ({ /bin/sh -c "docker cp ${K2HR3_API_REPO_ARCHIVE_FILE} ${CONTAINER_ID}:${K2HR3_API_REPO_ARCHIVE_FILE} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to copy K2HR3 API archives(${K2HR3_API_REPO_ARCHIVE_FILE}) into container(${CONTAINER_ID})"
			return 1
		fi
		if ({ /bin/sh -c "docker cp ${K2HR3_APP_REPO_ARCHIVE_FILE} ${CONTAINER_ID}:${K2HR3_APP_REPO_ARCHIVE_FILE} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to copy K2HR3 APP archives(${K2HR3_APP_REPO_ARCHIVE_FILE}) into container(${CONTAINER_ID})"
			return 1
		fi
		PRNINFO "Succeed to copy K2HR3 API/APP archives(${K2HR3_API_REPO_ARCHIVE_FILE}, ${K2HR3_APP_REPO_ARCHIVE_FILE}) into container(${CONTAINER_ID})"

		#
		# Create working directory
		#
		PRNMSG "Create working directory(${WORK_DIR}) in conatiner(${CONTAINER_ID})"
		if ({ /bin/sh -c "docker exec ${CONTAINER_ID} /bin/sh -c \"mkdir -p ${WORK_DIR}\" 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to create working directory(${WORK_DIR}) in conatiner(${CONTAINER_ID})"
			return 1
		fi
		PRNINFO "Succeed to create working directory(${WORK_DIR}) in conatiner(${CONTAINER_ID})"

	else
		#
		# Is runnning
		#
		CONTAINER_ID=$(docker ps -f name="${K2HR3_NODE_CONTAINER_NAME}" -f status=running | grep -v 'CONTAINER ID' | awk '{print $1}' | tr -d '\n')
		if [ -z "${CONTAINER_ID}" ]; then
			PRNERR "The container(name: ${K2HR3_NODE_CONTAINER_NAME}) is not runnning."
			return 1
		fi
	fi

	#
	# Run command in container
	#
	PRNMSG "Run ${_IN_CONTAIER_SCRIPT_NAME} in conatiner(${CONTAINER_ID})"
	if ({ /bin/sh -c "docker exec ${DOCKER_ENV_OPTIONS} ${CONTAINER_ID} /bin/sh -c \"/${_IN_CONTAIER_SCRIPT_NAME} ${_CONTAINER_ALL_OPTIONS}\" 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to run ${_IN_CONTAIER_SCRIPT_NAME} in conatiner(${CONTAINER_ID})"
		return 1
	fi
	PRNINFO "Succeed to run ${_IN_CONTAIER_SCRIPT_NAME} in conatiner(${CONTAINER_ID})"

	#
	# Stop container
	#
	if [ "${RUN_MODE}" = "stop" ]; then
		PRNMSG "Stop and remove docker container(${K2HR3_NODE_CONTAINER_NAME})"

		if ({ /bin/sh -c "docker stop ${K2HR3_NODE_CONTAINER_NAME} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to stop container(${K2HR3_NODE_CONTAINER_NAME})"
			return 1
		fi
		PRNINFO "Succeed to stop container(${K2HR3_NODE_CONTAINER_NAME})"

		if ({ /bin/sh -c "docker remove ${K2HR3_NODE_CONTAINER_NAME} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to remove container(${K2HR3_NODE_CONTAINER_NAME})"
			return 1
		fi
		PRNINFO "Succeed to remove container(${K2HR3_NODE_CONTAINER_NAME})"
	fi

	PRNSUCCESS "${_STR_RUN_TYPE_TITLE} K2HR3 system in Conatiner(${RUN_CONTAINER}: ${CONTAINER_ID} - ${K2HR3_NODE_CONTAINER_NAME})"

	if [ "${RUN_MODE}" = "start" ]; then
		echo "     Each process was launched in Docker container ${CGRN}${K2HR3_NODE_CONTAINER_NAME}${CDEF} (CONTAINER ID=${CGRN}${CONTAINER_ID}${CDEF})."
		echo "     You can attach to a container as follows:"
		echo "         \"${CGRN}docker exec -it ${K2HR3_NODE_CONTAINER_NAME} /bin/sh${CDEF}\""
		echo "         \"${CGRN}docker exec -it ${CONTAINER_ID} /bin/sh${CDEF}\""
		echo ""
	fi

	return 0
}

#
# Wait for stable execution state
#
# [INPUT]
#	$1		: PID
#	$2		: wait second
#	$3		: check state count
#
wait_process_running()
{
	if [ $# -lt 3 ]; then
		PRNERR "Wrong parameter"
		return 1
	fi
	_WAIT_PID="$1"
	_WAIT_SEC="$2"
	_WAIT_COUNT="$3"

	while [ "${_WAIT_COUNT}" -gt 0 ]; do
		sleep "${_WAIT_SEC}"

		# shellcheck disable=SC2009
		if ! ( ps -o pid,stat ax 2>/dev/null | grep -v 'PID' | awk '$2~/^[^Z]/ { print $1 }' | grep -q "^${_WAIT_PID}$" || exit 1 && exit 0 ); then
			# Not found process
			return 1
		fi
		_WAIT_COUNT=$((_WAIT_COUNT - 1))
	done

	#
	# Process kept to run for (wait second * count) second.
	#
	return 0
}

#
# Run one chmpx / k2hdkc server node
#
# [INPUT]
#	$1		: configuration file path
#	$2		: chmpx pid file path
#	$3		: chmpx log file path
#	$4		: k2hdkc pid file path
#	$5		: k2hdkc log file path
#
# [Using Variables]
#	PROC_START_WAIT_SEC
#	PROC_START_WAIT_COUNT
#
run_one_k2hdkc_server_node()
{
	if [ $# -lt 5 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_K2HDKC_CONF_FILE="$1"
	_CHMPX_PID_FILE="$2"
	_CHMPX_LOG_FILE="$3"
	_K2HDKC_PID_FILE="$4"
	_K2HDKC_LOG_FILE="$5"

	if [ ! -f "${_K2HDKC_CONF_FILE}" ]; then
		PRNERR "Not found ${_K2HDKC_CONF_FILE} configuration file for one K2HDKC server node."
		return 1
	fi

	cd "${WORK_DIR}" || exit 1

	#
	# Run chmpx server node
	#
	CHMDBGMODE="${CHMDBGMODE}" CHMDBGFILE="${CHMDBGFILE}" chmpx -conf "${_K2HDKC_CONF_FILE}" >"${_CHMPX_LOG_FILE}" 2>&1 &
	_CHMPX_PID=$!

	if ! wait_process_running "${_CHMPX_PID}" "${PROC_START_WAIT_SEC}" "${PROC_START_WAIT_COUNT}"; then
		PRNERR "Failed to run one chmpx server process."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	echo "${_CHMPX_PID}" > "${_CHMPX_PID_FILE}"

	#
	# Run k2hdkc server node
	#
	DKCDBGMODE="${DKCDBGMODE}" DKCDBGFILE="${DKCDBGFILE}" CHMDBGMODE="${CHMDBGMODE}" CHMDBGFILE="${CHMDBGFILE}" k2hdkc -conf "${_K2HDKC_CONF_FILE}" >"${_K2HDKC_LOG_FILE}" 2>&1 &
	_K2HDKC_PID=$!

	if ! wait_process_running "${_K2HDKC_PID}" "${PROC_START_WAIT_SEC}" "${PROC_START_WAIT_COUNT}"; then
		PRNERR "Failed to run one chmpx server process."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	echo "${_K2HDKC_PID}" > "${_K2HDKC_PID_FILE}"

	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#
# Run chmpx slave node
#
# [INPUT]
#	$1		: configuration file path
#	$2		: chmpx pid file path
#	$3		: chmpx log file path
#
# [Using Variables]
#	PROC_START_WAIT_SEC
#	PROC_START_WAIT_COUNT
#
run_chmpx_slave_node()
{
	if [ $# -lt 3 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_CHMPX_CONF_FILE="$1"
	_CHMPX_PID_FILE="$2"
	_CHMPX_LOG_FILE="$3"

	if [ ! -f "${_CHMPX_CONF_FILE}" ]; then
		PRNERR "Not found ${_CHMPX_CONF_FILE} configuration file for CHMPX slave node."
		return 1
	fi

	cd "${WORK_DIR}" || exit 1

	#
	# Run chmpx server node
	#
	CHMDBGMODE="${CHMDBGMODE}" CHMDBGFILE="${CHMDBGFILE}" chmpx -conf "${_CHMPX_CONF_FILE}" >"${_CHMPX_LOG_FILE}" 2>&1 &
	_CHMPX_PID=$!

	if ! wait_process_running "${_CHMPX_PID}" "${PROC_START_WAIT_SEC}" "${PROC_START_WAIT_COUNT}"; then
		PRNERR "Failed to run chmpx slave process."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	echo "${_CHMPX_PID}" > "${_CHMPX_PID_FILE}"

	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#
# Run k2hr3 api process
#
# [INPUT]
#	$1		: k2hr3 api log file path
#
run_k2hr3_api()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_K2HR3_API_LOG_FILE="$1"

	cd "${REPO_K2HR3_API_DIR}" || exit 1

	#
	# Run K2HR3 API node process
	#
	if ({ /bin/sh -c "npm run start 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to run K2HR3 API node process."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#
# Run k2hr3 app process
#
# [INPUT]
#	$1		: k2hr3 app log file path
#
run_k2hr3_app()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_K2HR3_APP_LOG_FILE="$1"

	cd "${REPO_K2HR3_APP_DIR}" || exit 1

	#
	# Run K2HR3 APP node process
	#
	if ({ /bin/sh -c "npm run start 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to run K2HR3 APP node process."
		cd "${CURRENT_DIR}" || exit 1
		return 1
	fi
	cd "${CURRENT_DIR}" || exit 1

	return 0
}

#
# Stop process by PID file
#
# [INPUT]
#	$1		: PID file
#
# [Using Variables]
#	SUDO_PREFIX_CMD
#	PROC_STOP_WAIT_SEC
#
stop_process_by_pidfile()
{
	if [ $# -lt 1 ]; then
		PRNERR "Parameter error"
		return 1
	fi
	_PID_FILE="$1"

	if [ ! -f "${_PID_FILE}" ]; then
		PRNERR "Not found ${_PID_FILE} PID file."
		return 1
	fi
	_STOP_PID=$(tr -d '\n' < "${_PID_FILE}")

	#
	# Check PID process running
	#
	# shellcheck disable=SC2009
	if ! ( ps -o pid,stat ax 2>/dev/null | grep -v 'PID' | awk '$2~/^[^Z]/ { print $1 }' | grep -q "^${_STOP_PID}$" || exit 1 && exit 0 ); then
		PRNINFO "Already stopped ${_STOP_PID} PID process."
		return 0
	fi

	#
	# Try to stop process by HUP
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} kill -HUP ${_STOP_PID} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNWARN "Failed to stop ${_STOP_PID} PID process by HUP."
	else
		sleep "${PROC_STOP_WAIT_SEC}"

		# shellcheck disable=SC2009
		if ! ( ps -o pid,stat ax 2>/dev/null | grep -v 'PID' | awk '$2~/^[^Z]/ { print $1 }' | grep -q "^${_STOP_PID}$" || exit 1 && exit 0 ); then
			#
			# Succeed to stop
			#
			PRNINFO "Succeed to stop ${_STOP_PID} PID process by HUP."
			return 0
		fi
		PRNWARN "Could not stop ${_STOP_PID} PID process by HUP."
	fi

	#
	# Try to stop process by KILL
	#
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} kill -KILL ${_STOP_PID} 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to stop ${_STOP_PID} PID process by KILL."
	else
		sleep "${PROC_STOP_WAIT_SEC}"

		# shellcheck disable=SC2009
		if ( ps -o pid,stat ax 2>/dev/null | grep -v 'PID' | awk '$2~/^[^Z]/ { print $1 }' | grep -q "^${_STOP_PID}$" || exit 1 && exit 0 ); then
			PRNERR "Could not stop ${_STOP_PID} PID process by KILL."
			return 1
		fi
	fi

	#
	# Succeed to stop
	#
	PRNINFO "Succeed to stop ${_STOP_PID} PID process by KILL."

	return 0
}

#----------------------------------------------------------
# [Utilities] Usage function
#----------------------------------------------------------
func_usage()
{
	#
	# $1:	Program name
	#
	echo ""
	echo "Usage:  $1 [options] { start(str) | stop(stp) }"
	echo ""
	echo "[Command]"
	echo "   start(str)                      Start K2HR3 systems"
	echo "   stop(stp)                       Stop K2HR3 systems"
	echo "   login(l)                        Login(attach) into K2HR3 systems container"
	echo ""
	echo "[Common Options]"
	echo "   --help(-h)                      Print help"
	echo "   --yes(-y)                       Runs no interactive mode. (default: interactive mode)"
	echo "   --workdir(-w)                   Specify the base directory path, cannot specify in the same directory as this script. (default: current directory or /work)"
	echo "   --container(-i) [...]           Run K2HR3 system in docker container."
	echo "                                   Specify the image as \"{<docker registry>/}<image name>:<tag>\":"
	echo "                                   ex) \"alpine:3.21\""
	echo "                                       \"docker.io/alpine:3.21\""
	echo "                                   You can use the defined images by specifying the following keywords in the image name:"
	echo "                                       \"alpine\"    -> alpine:3.21"
	echo "                                       \"fedora\"    -> fedora:41"
	echo "                                       \"rocky\"     -> rockylinux:9"
	echo "                                       \"ubuntu\"    -> ubuntu:22.04"
	echo "                                       \"debian\"    -> debian:12"
	echo ""
	echo "[Options: start]"
	echo "   --not_use_pckagecloud(-nopc)    Not use packages on packagecloud repository. (default: use packagecloud repository)"
	echo ""
	echo "   --nodejs_version(-node) [ver]   Specify NodeJS version like as \"18\", \"20\", \"22\". (default: 22)"
	echo "                                   In the case of ALPINE, it is automatically determined depending on the OS version."
	echo ""
	echo "   --repo_k2hr3_api(-repo_api)     Specify K2HR3 API repository url for cloning. (default: https://<github domain>/<org>/k2hr3_api.git)"
	echo "   --repo_k2hr3_api(-repo_app)     Specify K2HR3 APP repository url for cloning. (default: https://<github domain>/<org>/k2hr3_app.git)"
	echo ""
	echo "   --host_external(-eh) [host|ip]  Specify host(\"hostname\" or \"IP address\") for external access when run this in container. (REQUIRED option for container)"
	echo "   --npm_registory(-reg) [...]     Specify additional NPM registries in the following format:"
	echo "                                       \"<registory name>,<npm registory url>\""
	echo "                                       ex) \"registry,http://registry.npmjs.org/\""
	echo "                                   To register multiple registries, specify this option-value pair multiple times."

	#
	# Print help for additinal options
	#
	if ! addition_print_help_option; then
		PRNERR "Failed to print help additinal options."
		exit 1
	fi

	echo ""
	echo "[NOTE]"
	echo "   For ALPINE OS, the --nodejs_version (-node) option is ignored."
	echo "   This is because it depends on the version of the nodejs package present in the ALPINE"
	echo "   package repository."
	echo "   In ALPINE 3.19, it is v18, in 3.20 it is v20, and in 3.21 it is v22."
	echo ""
	echo "[Environments]"
	echo "   You can change the log levels for CHMPX, K2HDKC processes, etc. by setting the following"
	echo "   environment variables:"
	echo "       CHMDBGMODE, CHMDBGFILE"
	echo "       DKCDBGMODE, DKCDBGFILE"
	echo "   Please refer to the help for each program for details."
	echo ""
}

#==========================================================
# [Processing] Load additional configuration file
#==========================================================
PRNTITLE "Load additional configuration file"

if [ "${SCRIPTDIR}" = "/" ]; then
	_TMP_DIR_SEPARATOR=""
else
	_TMP_DIR_SEPARATOR="/"
fi
if [ -f "${SCRIPTDIR}${_TMP_DIR_SEPARATOR}${OVERRIDE_CONF_FILENAME}" ]; then
	OVERRIDE_CONF_FILEPATH="${SCRIPTDIR}${_TMP_DIR_SEPARATOR}${OVERRIDE_CONF_FILENAME}"
elif [ -f "${DEVPACKTOP}/conf/${OVERRIDE_CONF_FILENAME}" ]; then
	OVERRIDE_CONF_FILEPATH="${DEVPACKTOP}/conf/${OVERRIDE_CONF_FILENAME}"
else
	OVERRIDE_CONF_FILEPATH=""
fi
if [ -n "${OVERRIDE_CONF_FILEPATH}" ]; then
	# shellcheck disable=SC1090
	. "${OVERRIDE_CONF_FILEPATH}"
	PRNINFO "Succeed to load override configuration file(${OVERRIDE_CONF_FILEPATH})."
fi

#
# Setup default additional variables
#
if ! addition_setup_default_variables; then
	PRNERR "Failed to setup default additinal variables."
fi
PRNINFO "Succeed to setup default additinal variables."

#==========================================================
# [Processing] Parse and Check Options
#==========================================================
PRNTITLE "Parse and Check options"

#----------------------------------------------------------
# Parse Options
#----------------------------------------------------------
OPT_RUN_MODE=""
OPT_WORK_DIR=""
OPT_RUN_CONTAINER=""

OPT_NO_INTERACTIVE=0
OPT_NOT_USE_PACKAGECLOUD=0

OPT_NODEJS_VERSION=""
OPT_REPO_K2HR3_API=""
OPT_REPO_K2HR3_APP=""

OPT_EXTERNAL_HOST=""
OPT_NPM_REGISTORIES=""

while [ $# -ne 0 ]; do
	if [ -z "$1" ]; then
		break

	elif echo "$1" | grep -q -i -e "^-h$" -e "^--help$"; then
		func_usage "${PROGRAM_NAME}"
		exit 0

	elif echo "$1" | grep -q -i -e "^-y$" -e "^--yes$"; then
		if [ "${OPT_NO_INTERACTIVE}" -ne 0 ]; then
			PRNERR "--yes(-y) option is already specified."
			exit 1
		fi
		OPT_NO_INTERACTIVE=1

	elif echo "$1" | grep -q -i -e "^-w$" -e "^--workdir$"; then
		if [ -n "${OPT_WORK_DIR}" ]; then
			PRNERR "--workdir(-w) option is already specified(${OPT_WORK_DIR})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--workdir(-w) option needs parameter."
			exit 1
		fi
		if [ ! -d "$1" ]; then
			PRNWARN "$1 specified by --workdir(-w) option is not found in local host."
		fi
		OPT_WORK_DIR="$1"

	elif echo "$1" | grep -q -i -e "^-i$" -e "^--container$"; then
		if [ -n "${OPT_RUN_CONTAINER}" ]; then
			PRNERR "--container(-i) option is already specified(${OPT_RUN_CONTAINER})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--container(-i) option needs parameter."
			exit 1
		fi
		#
		# Check reserved key words
		#
		if echo "$1" | grep -q -i "^alpine$"; then
			OPT_RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_ALPINE}"
		elif echo "$1" | grep -q -i "^ubuntu$"; then
			OPT_RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_UBUNTU}"
		elif echo "$1" | grep -q -i "^debian$"; then
			OPT_RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_DEBIAN}"
		elif echo "$1" | grep -q -i -e "^rocky$" -e "^rockylinux$"; then
			OPT_RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_ROCKY}"
		elif echo "$1" | grep -q -i "^fedora$"; then
			OPT_RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_FEDORA}"
		else
			OPT_RUN_CONTAINER="$1"
		fi

	elif echo "$1" | grep -q -i -e "^-nopc$" -e "^--not_use_pckagecloud$"; then
		if [ "${OPT_NOT_USE_PACKAGECLOUD}" -ne 0 ]; then
			PRNERR "--not_use_pckagecloud(-nopc) option is already specified."
			exit 1
		fi
		OPT_NOT_USE_PACKAGECLOUD=1

	elif echo "$1" | grep -q -i -e "^-node$" -e "^--nodejs_version$"; then
		if [ -n "${OPT_NODEJS_VERSION}" ]; then
			PRNERR "--nodejs_version(-node) option is already specified(${OPT_NODEJS_VERSION})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--nodejs_version(-node) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter($1) of --nodejs_version(-node) option must be number(ex. 18, 20, 22, ...)."
			exit 1
		fi
		OPT_NODEJS_VERSION="$1"

	elif echo "$1" | grep -q -i -e "^-repo_api$" -e "^--repo_k2hr3_api$"; then
		if [ -n "${OPT_REPO_K2HR3_API}" ]; then
			PRNERR "--repo_k2hr3_api(-repo_api) option is already specified(${OPT_REPO_K2HR3_API})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--repo_k2hr3_api(-repo_api) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -e "^https://" -e "^git@" | grep -q "\.git"; then
			OPT_REPO_K2HR3_API="$1"
		else
			PRNERR "--repo_k2hr3_api(-repo_api) parameter must start with \"https://\" or \"git@\" and end with \".git\"."
			exit 1
		fi

	elif echo "$1" | grep -q -i -e "^-repo_app$" -e "^--repo_k2hr3_app$"; then
		if [ -n "${OPT_REPO_K2HR3_APP}" ]; then
			PRNERR "--repo_k2hr3_app(-repo_app) option is already specified(${OPT_REPO_K2HR3_APP})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--repo_k2hr3_app(-repo_app) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -e "^https://" -e "^git@" | grep -q "\.git"; then
			OPT_REPO_K2HR3_APP="$1"
		else
			PRNERR "--repo_k2hr3_app(-repo_app) parameter must start with \"https://\" or \"git@\" and end with \".git\"."
			exit 1
		fi

	elif echo "$1" | grep -q -i -e "^-eh$" -e "^--host_external$"; then
		if [ -n "${OPT_EXTERNAL_HOST}" ]; then
			PRNERR "--host_external(-eh) option is already specified(${OPT_EXTERNAL_HOST})"
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--host_external(-eh) option needs parameter."
			exit 1
		fi
		OPT_EXTERNAL_HOST="$1"

	elif echo "$1" | grep -q -i -e "^-reg$" -e "^--npm_registory$"; then
		# [NOTE]
		# This option can be specified multiple times.
		# The specified values will be accumulated in OPT_NPM_REGISTORIES, separated by space characters.
		#
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--npm_registory(-reg) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q '[[:space:]]'; then
			PRNERR "Wrong --npm_registory(-reg) option parameter($1), It must be \"<registory name>,<npm registory url>\"."
			exit 1
		elif echo "$1" | grep -q ','; then
			# Found sepalator(,), this is OK.
			:
		else
			# Not found sepalator(,)
			PRNERR "Wrong --npm_registory(-reg) option parameter($1), It must be \"<registory name>,<npm registory url>\"."
			exit 1
		fi

		if [ -z "${OPT_NPM_REGISTORIES}" ]; then
			OPT_NPM_REGISTORIES="$1"
		else
			OPT_NPM_REGISTORIES="${OPT_NPM_REGISTORIES} $1"
		fi

	# 
	# Parse additinal options
	#
	elif addition_parse_input_parameters "$1" "$2"; then
		if [ "${ADDITION_PARSE_OPTION_RESULT}" -eq 1 ]; then
			exit 1
		fi
		while [ "${ADDITION_USED_PARAMTER_COUNT}" -gt 1 ]; do
			shift
			ADDITION_USED_PARAMTER_COUNT=$((ADDITION_USED_PARAMTER_COUNT - 1))
		done

	else
		if [ -n "${OPT_RUN_MODE}" ]; then
			PRNERR "Command is already specified(${OPT_RUN_MODE})"
			exit 1
		elif echo "$1" | grep -q -i -e "^str$" -e "^start$"; then
			OPT_RUN_MODE="start"
		elif echo "$1" | grep -q -i -e "^stp$" -e "^stop$"; then
			OPT_RUN_MODE="stop"
		elif echo "$1" | grep -q -i -e "^l$" -e "^login$"; then
			OPT_RUN_MODE="login"
		else
			PRNERR "$1 option is unknown."
			exit 1
		fi
	fi
	shift
done

#----------------------------------------------------------
# Check if this script was called from within a container
#----------------------------------------------------------
if [ -e /.dockerenv ]; then
	RUN_IN_CONTAINER=1
else
	RUN_IN_CONTAINER=0
fi

#----------------------------------------------------------
# Check common options and parameters
#----------------------------------------------------------
#
# Check interaction option for common flags
#
if [ -z "${OPT_RUN_MODE}" ]; then
	PRNERR "Command(\"start\" or \"stop\" or \"login\") is not specified."
	exit 1
else
	RUN_MODE="${OPT_RUN_MODE}"
fi

if [ "${OPT_NO_INTERACTIVE}" -ne 0 ]; then
	IS_INTERACTIVE=0
	PRNINFO "NOT INTERACTIVATION MODE : it uses default values for options not specified."
fi

#
# Docker container
#
if [ -n "${OPT_RUN_CONTAINER}" ]; then
	if [ "${RUN_IN_CONTAINER}" -eq 1 ]; then
		PRNERR "This script run in conatiner, so you can not specify --container(-i) option."
		exit 1
	fi
	RUN_CONTAINER="${OPT_RUN_CONTAINER}"
else
	if [ "${RUN_IN_CONTAINER}" -eq 0 ]; then
		if [ "${IS_INTERACTIVE}" -eq 0 ]; then
			PRNWARN "Since no Docker image is specified, the container will not be started but k2hr3 system will be built on this host."
		else
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "Specify the Docker container image. If you do not want to run in a container, enter empty(${CGRN}\"\"${CDEF}).;Specify the image using \"${CGRN}{<docker registory>/}<image name>{:<version>}${CDEF}\" format.;Or specify one of the predefined values(\"${CGRN}alpine${CDEF}\", \"${CGRN}ubuntu${CDEF}\", \"${CGRN}debian${CDEF}\", \"${CGRN}rockylinux${CDEF}\"(${CGRN}rocky${CDEF}), \"${CGRN}fedora${CDEF}\").;Please input Docker Image"

				if [ -z "${INTERACTION_RESULT}" ]; then
					# use default value
					_IS_LOOP=0
				else
					if echo "${INTERACTION_RESULT}" | grep -q -i "^alpine$"; then
						RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_ALPINE}"
					elif echo "${INTERACTION_RESULT}" | grep -q -i "^ubuntu$"; then
						RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_UBUNTU}"
					elif echo "${INTERACTION_RESULT}" | grep -q -i "^debian$"; then
						RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_DEBIAN}"
					elif echo "${INTERACTION_RESULT}" | grep -q -i -e "^rocky$" -e "^rockylinux$"; then
						RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_ROCKY}"
					elif echo "${INTERACTION_RESULT}" | grep -q -i "^fedora$"; then
						RUN_CONTAINER="${DEFAULT_RESERVED_IMAGE_FEDORA}"
					else
						RUN_CONTAINER="${INTERACTION_RESULT}"
					fi
					_IS_LOOP=0
				fi
			done
		fi
	else
		if [ "${RUN_MODE}" = "login" ]; then
			PRNERR "Can not run the \"login\" command from within a container."
			exit 1
		fi
	fi
fi

#
# Work directory
#
if [ "${RUN_IN_CONTAINER}" -eq 1 ] || [ -n "${RUN_CONTAINER}" ]; then
	DEFAULT_WORK_DIR="/work"
else
	DEFAULT_WORK_DIR="."
fi
if [ -n "${OPT_WORK_DIR}" ]; then
	if [ "${RUN_MODE}" = "login" ]; then
		PRNERR "The --workdir(-w) option cannot be specified in the \"login\" command."
		exit 1
	fi
	WORK_DIR="${OPT_WORK_DIR}"
else
	if [ "${RUN_MODE}" != "login" ]; then
		if [ "${IS_INTERACTIVE}" -eq 1 ]; then
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "Work directory (empty is use default: \"${DEFAULT_WORK_DIR}\")"

				if [ -z "${INTERACTION_RESULT}" ]; then
					# use default value
					WORK_DIR="${DEFAULT_WORK_DIR}"
					_IS_LOOP=0
				else
					WORK_DIR="${INTERACTION_RESULT}"
					_IS_LOOP=0
				fi
			done
		fi
		if [ -z "${WORK_DIR}" ]; then
			PRNERR "Need to specify --workdir(-w) option."
			exit 1
		fi
	fi
fi

#
# Check Working directory
#
if [ "${RUN_MODE}" != "login" ]; then
	if [ -d "${WORK_DIR}" ]; then
		WORK_DIR=$(cd "${WORK_DIR}" || exit 1; pwd)

		if [ -z "${RUN_CONTAINER}" ] && [ "${RUN_IN_CONTAINER}" -eq 0 ]; then
			#
			# Check Working directory and Set K2HR3 API/APP repository and other directories
			#
			# [NOTE]
			# By design, the Working directory cannot be the same directory as the script.
			# This is because many files and directories will be created in the Working
			# directory, so it should be a separate directory.
			#
			if [ "${WORK_DIR}" = "${SCRIPTDIR}" ]; then
				PRNERR "The working directory(${WORK_DIR}) cannot be the same as the directory of this script."
				exit 1
			fi
		fi
	else
		#
		# Not found working directory
		#
		if [ -z "${RUN_CONTAINER}" ] && [ "${RUN_IN_CONTAINER}" -eq 0 ]; then
			#
			# Not run in container case(confirm to create directory in this host)
			#
			if [ "${IS_INTERACTIVE}" -ne 1 ]; then
				PRNERR "Not found working directory(${WORK_DIR})."
				exit 1
			fi

			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "Working directory(${WORK_DIR}) does not exist, do you create it? (yes/no(default))"
	
				if echo "${INTERACTION_RESULT}" | grep -q -i -e "^y$" -e "^yes$"; then
					_IS_LOOP=0
				else
					PRNERR "Please prepare a working directory and try again."
					exit 1
				fi
			done

			#
			# Create working directory
			#
			if ! mkdir -p "${WORK_DIR}" >/dev/null 2>&1; then
				PRNERR "Failed to create working directory(${WORK_DIR})."
				exit 1
			fi
			WORK_DIR=$(cd "${WORK_DIR}" || exit 1; pwd)

			if [ "${WORK_DIR}" = "${SCRIPTDIR}" ]; then
				PRNERR "The working directory(${WORK_DIR}) cannot be the same as the directory of this script."
				exit 1
			fi

		elif [ -n "${RUN_CONTAINER}" ] && [ "${RUN_IN_CONTAINER}" -eq 0 ]; then
			#
			# Not create working directory(Nothing to do)
			#
			:
		else
			#
			# Run on container
			#
			if ! mkdir -p "${WORK_DIR}" >/dev/null 2>&1; then
				PRNERR "Failed to create working directory(${WORK_DIR})."
				exit 1
			fi
		fi
	fi
fi

#----------------------------------------------------------
# Check the options and parameters depending on the Run mode
#----------------------------------------------------------
if [ "${RUN_MODE}" = "start" ]; then
	#
	# Start mode
	#
	if [ "${OPT_NOT_USE_PACKAGECLOUD}" -ne 0 ]; then
		IS_USE_PACKAGECLOUD=0
	fi

	#
	# Set option variables by interaction or default value
	#
	if [ "${IS_INTERACTIVE}" -eq 1 ]; then
		#
		# Interaction if option is not specified
		#

		#
		# NodeJS version
		#
		if [ -n "${OPT_NODEJS_VERSION}" ]; then
			NODEJS_VERSION="${OPT_NODEJS_VERSION}"
		else
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "NodeJS version for other than ALPINE - 18, 20, 22, ... (empty is use default: \"22\")" "yes"

				if [ -z "${INTERACTION_RESULT}" ]; then
					# use default value
					_IS_LOOP=0
				else
					NODEJS_VERSION="${INTERACTION_RESULT}"
					_IS_LOOP=0
				fi
			done
		fi

		#
		# External host accessing from outside container
		#
		if [ -n "${OPT_EXTERNAL_HOST}" ]; then
			EXTERNAL_HOST="${OPT_EXTERNAL_HOST}"

		elif [ "${RUN_IN_CONTAINER}" -eq 0 ] && [ -n "${RUN_CONTAINER}" ]; then
			#
			# The case when the container is currently running on a host outside
			# of the container and the container will be started later.
			#

			#
			# Get hostname or IP address as default
			#
			if ! _LOCALHOST_DEFAULT=$(uname -n 2>/dev/null); then
				_LOCALHOST_DEFAULT=$(ip -a address 2>/dev/null | grep inet | grep -v '127\.[0-9]*\.[0-9]*\.[0-9]*' | grep -v docker | grep -v 'br-' | head -1 | awk '{print $2}' | sed -e 's#/.*$##g' | tr -d '\n')
			fi
			if [ -n "${_LOCALHOST_DEFAULT}" ]; then
				_STR_LOCALHOST_DEFAULT=" (default: \"${_LOCALHOST_DEFAULT}\")"
			fi

			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "External host(\"hostname\" or \"IP address\") accessing from outside container${_STR_LOCALHOST_DEFAULT}"

				if [ -n "${INTERACTION_RESULT}" ]; then
					EXTERNAL_HOST="${INTERACTION_RESULT}"
					_IS_LOOP=0
				elif [ -n "${_LOCALHOST_DEFAULT}" ]; then
					EXTERNAL_HOST="${_LOCALHOST_DEFAULT}"
					_IS_LOOP=0
				fi
			done
		else
			#
			# Don't launch a container or Already running in a container
			#
			:
		fi

		# 
		# Interactive input additinal options
		#
		# [NOTE]
		# This process is done before the K2HR3 APP/API URL.
		# This is because it is a variable that is changed by Additional functions.
		#
		if ! addition_interactive_options "${IS_INTERACTIVE}"; then
			exit 1
		fi

		#
		# Additinal NPM registories
		#
		if [ -n "${OPT_NPM_REGISTORIES}" ]; then
			if [ -z "${NPM_REGISTORIES}" ]; then
				NPM_REGISTORIES="${OPT_NPM_REGISTORIES}"
			else
				NPM_REGISTORIES="${NPM_REGISTORIES} ${OPT_NPM_REGISTORIES}"
			fi
		else
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "Do you add additinal NPM Registries? (yes/no(default))"

				if echo "${INTERACTION_RESULT}" | grep -q -i -e "^y$" -e "^yes$"; then
					_IS_SUB_LOOP=1
					while [ "${_IS_SUB_LOOP}" -eq 1 ]; do
						_TMP_NPMREG_NAME=""
						_TMP_NPMREG_URL=""

						input_interaction " - Additinal registory name :" "no" "no"
						_TMP_NPMREG_NAME="${INTERACTION_RESULT}"

						input_interaction " - Additinal registory URL  :" "no" "no"
						_TMP_NPMREG_URL="${INTERACTION_RESULT}"

						if [ -n "${NPM_REGISTORIES}" ]; then
							NPM_REGISTORIES="${NPM_REGISTORIES} "
						fi
						NPM_REGISTORIES="${NPM_REGISTORIES}${_TMP_NPMREG_NAME},${_TMP_NPMREG_URL}"

						input_interaction " * Do you add more? (yes/no(default))"

						if echo "${INTERACTION_RESULT}" | grep -q -i -e "^y$" -e "^yes$"; then
							:
						else
							_IS_SUB_LOOP=0
							_IS_LOOP=0
						fi
					done
				else
					_IS_LOOP=0
				fi
			done
		fi

		#
		# K2HR3 API URL for cloning repository
		#
		if [ -n "${OPT_REPO_K2HR3_API}" ]; then
			REPO_K2HR3_API="${OPT_REPO_K2HR3_API}"
		else
			#
			# Interactive if recloning and default repository directory does not exist
			#
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "K2HR3 API url for cloning (empty is use default: \"${DEFAULT_REPO_K2HR3_API}\")"

				if [ -z "${INTERACTION_RESULT}" ]; then
					# use default value
					REPO_K2HR3_API="${DEFAULT_REPO_K2HR3_API}"
					_IS_LOOP=0
				elif echo "${INTERACTION_RESULT}" | grep -e "^https://" -e "^git@" | grep -q "\.git$"; then
					REPO_K2HR3_API="${INTERACTION_RESULT}"
					_IS_LOOP=0
				else
					PRNERR "${INTERACTION_RESULT} is not start with \"https://\" nor \"git@\" nor end with \".git\"."
				fi
			done
		fi

		#
		# K2HR3 APP URL for cloning repository
		#
		if [ -n "${OPT_REPO_K2HR3_APP}" ]; then
			REPO_K2HR3_APP="${OPT_REPO_K2HR3_APP}"
		else
			#
			# Interactive if recloning and default repository directory does not exist
			#
			_IS_LOOP=1
			while [ "${_IS_LOOP}" -eq 1 ]; do
				input_interaction "K2HR3 APP url for cloning (empty is use default: \"${DEFAULT_REPO_K2HR3_APP}\")"

				if [ -z "${INTERACTION_RESULT}" ]; then
					# use default value
					REPO_K2HR3_APP="${DEFAULT_REPO_K2HR3_APP}"
					_IS_LOOP=0
				elif echo "${INTERACTION_RESULT}" | grep -e "^https://" -e "^git@" | grep -q "\.git$"; then
					REPO_K2HR3_APP="${INTERACTION_RESULT}"
					_IS_LOOP=0
				else
					PRNERR "${INTERACTION_RESULT} is not start with \"https://\" nor \"git@\" nor end with \".git\"."
				fi
			done
		fi
	else
		#
		# Set value if option specified
		#
		if [ -n "${OPT_NODEJS_VERSION}" ]; then
			NODEJS_VERSION="${OPT_NODEJS_VERSION}"
		fi
		if [ -n "${OPT_REPO_K2HR3_API}" ]; then
			REPO_K2HR3_API="${OPT_REPO_K2HR3_API}"
		else
			REPO_K2HR3_API="${DEFAULT_REPO_K2HR3_API}"
		fi
		if [ -n "${OPT_REPO_K2HR3_APP}" ]; then
			REPO_K2HR3_APP="${OPT_REPO_K2HR3_APP}"
		else
			REPO_K2HR3_APP="${DEFAULT_REPO_K2HR3_APP}"
		fi
		if [ -n "${OPT_EXTERNAL_HOST}" ]; then
			EXTERNAL_HOST="${OPT_EXTERNAL_HOST}"
		fi
		if [ -n "${OPT_NPM_REGISTORIES}" ]; then
			if [ -z "${NPM_REGISTORIES}" ]; then
				NPM_REGISTORIES="${OPT_NPM_REGISTORIES}"
			else
				NPM_REGISTORIES="${NPM_REGISTORIES} ${OPT_NPM_REGISTORIES}"
			fi
		fi

		# 
		# Interactive input additinal options
		#
		if ! addition_interactive_options "${IS_INTERACTIVE}"; then
			exit 1
		fi
	fi

elif [ "${RUN_MODE}" = "stop" ] || [ "${RUN_MODE}" = "login" ]; then
	#
	# Stop/login mode
	#
	if [ "${OPT_NOT_USE_PACKAGECLOUD}" -ne 0 ]; then
		PRNERR "In ${RUN_MODE} mode, the --not_use_pckagecloud(-nopc) option cannot be specified."
		exit 1
	fi
	if [ -n "${OPT_NODEJS_VERSION}" ]; then
		PRNERR "In ${RUN_MODE} mode, the --nodejs_version(-node) option cannot be specified."
		exit 1
	fi
	if [ -n "${OPT_REPO_K2HR3_API}" ]; then
		PRNERR "In ${RUN_MODE} mode, the --repo_k2hr3_api(-repo_api) option cannot be specified."
		exit 1
	fi
	if [ -n "${OPT_REPO_K2HR3_APP}" ]; then
		PRNERR "In ${RUN_MODE} mode, the --repo_k2hr3_api(-repo_app) option cannot be specified."
		exit 1
	fi
	if [ -n "${OPT_EXTERNAL_HOST}" ]; then
		PRNERR "In ${RUN_MODE} mode, the --host_external(-eh) option cannot be specified."
		exit 1
	fi
	if [ -n "${OPT_NPM_REGISTORIES}" ]; then
		PRNERR "In ${RUN_MODE} mode, the --npm_registory(-reg) option cannot be specified."
		exit 1
	fi

	# 
	# Setup additional options
	#
	if ! addition_varidate_options "${RUN_MODE}"; then
		exit 1
	fi
else
	PRNERR "Unknown Run mode(${RUN_MODE})."
	exit 1
fi

#
# Set directory variables
#
if [ "${RUN_MODE}" != "login" ]; then
	REPO_K2HR3_API_DIR="${WORK_DIR}/${DEFAULT_REPO_K2HR3_API_NAME}"
	REPO_K2HR3_APP_DIR="${WORK_DIR}/${DEFAULT_REPO_K2HR3_APP_NAME}"
	WORK_CONF_DIR="${WORK_DIR}/${DEFAULT_WORK_CONF_DIRNAME}"
	WORK_LOGS_DIR="${WORK_DIR}/${DEFAULT_WORK_LOGS_DIRNAME}"
	WORK_PIDS_DIR="${WORK_DIR}/${DEFAULT_WORK_PIDS_DIRNAME}"
	WORK_DATA_DIR="${WORK_DIR}/${DEFAULT_WORK_DATA_DIRNAME}"
fi

echo ""
PRNINFO "Succeed to parse and check options"

#==========================================================
# [Processing] Environment dependent variables
#==========================================================
PRNTITLE "Setup environment dependent variables"

#----------------------------------------------------------
# Check and Setup OS(Container) information
#----------------------------------------------------------
PRNMSG "Check and Setup OS(Container) information"

#
# Setup variables:	CUR_NODE_OS_NAME
#					CUR_NODE_OS_VERSION
#					K2HR3_NODE_OS_NAME
#					K2HR3_NODE_OS_VERSION
#					K2HR3_NODE_OS_TYPE_NUMBER
#					K2HR3_NODE_CONTAINER_NAME
#
if ! setup_k2hr3_system_os_type_number; then
	PRNERR "Failed to check and setup OS(Container) information"
	exit 1
fi
PRNINFO "Succeed to check and setup OS(Container) information"

#----------------------------------------------------------
# Check and Setup PROXY variables
#----------------------------------------------------------
PRNMSG "Check and Setup PROXY variables"

#
# Setup variables:	HTTP_PROXY				(exports)
#					HTTPS_PROXY				(exports)
#					NO_PROXY				(exports)
#					SCHEME_HTTP_PROXY
#					SCHEME_HTTPS_PROXY
#
if ! set_variable_for_proxy; then
	PRNERR "Failed to check and setup PROXY variables"
	exit 1
fi
PRNINFO "Succeed to check and setup PROXY variables"

#----------------------------------------------------------
# Check and Setup variables for current/conatiner host OS
#----------------------------------------------------------
PRNMSG "Check and Setup variables for current/container host OS"

#
# Setup variables:	CURRENT_USER
#					SUDO_PREFIX_CMD
#					K2HR3_APP_LANG
#					STATUS_PACKAGECLOUD_REPO
#					DEBIAN_FRONTEND			(export)
#
#
if ! set_variable_for_host_environments; then
	PRNERR "Failed to check and setup variables for current host OS"
	exit 1
fi
PRNINFO "Succeed to check and setup variables for current host OS"

#----------------------------------------------------------
# Setup variables for configration files
#----------------------------------------------------------
K2HDKC_K2H_PATH="${WORK_DATA_DIR}/${K2HR3_NODE_OS_NAME}${DEFAULT_K2HFILE_SUFFIX}"
K2HDKC_SERVER_NODE_0_CONF_FILE="${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_server_0.ini"
K2HDKC_SERVER_NODE_1_CONF_FILE="${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_server_1.ini"
K2HDKC_SLAVE_NODE_0_CONF_FILE="${WORK_CONF_DIR}/${K2HR3_NODE_OS_NAME}_slave_0.ini"

K2HR3_APP_CONF_FILE="${WORK_DIR}/${DEFAULT_REPO_K2HR3_APP_NAME}/config/production.json5"
K2HR3_API_CONF_FILE="${WORK_DIR}/${DEFAULT_REPO_K2HR3_API_NAME}/config/production.json5"

K2HDKC_SERVER_NODE_0_PORT="8${K2HR3_NODE_OS_TYPE_NUMBER}20"
K2HDKC_SERVER_NODE_0_CTLPORT="8${K2HR3_NODE_OS_TYPE_NUMBER}21"
K2HDKC_SERVER_NODE_1_PORT="8${K2HR3_NODE_OS_TYPE_NUMBER}22"
K2HDKC_SERVER_NODE_1_CTLPORT="8${K2HR3_NODE_OS_TYPE_NUMBER}23"
K2HDKC_SLAVE_NODE_0_CTLPORT="8${K2HR3_NODE_OS_TYPE_NUMBER}24"

K2HR3_APP_PORT="1${K2HR3_NODE_OS_TYPE_NUMBER}080"
K2HR3_API_PORT="2${K2HR3_NODE_OS_TYPE_NUMBER}080"

if [ -n "${EXTERNAL_HOST}" ]; then
	K2HR3_API_HOST="${EXTERNAL_HOST}"
	K2HR3_APP_HOST="${EXTERNAL_HOST}"
else
	if command -v hostname >/dev/null 2>&1; then
		if _HOSTNAME_FQDN=$(hostname -f 2>/dev/null); then
			K2HR3_API_HOST="${_HOSTNAME_FQDN}"
			K2HR3_APP_HOST="${_HOSTNAME_FQDN}"
		else
			K2HR3_API_HOST="localhost"
			K2HR3_APP_HOST="localhost"
		fi
	else
		K2HR3_API_HOST="localhost"
		K2HR3_APP_HOST="localhost"
	fi
fi

K2HR3_API_URL="http://${K2HR3_API_HOST}:${K2HR3_API_PORT}"
K2HR3_APP_URL="http://${K2HR3_APP_HOST}:${K2HR3_APP_PORT}"

#----------------------------------------------------------
# Setup other variables
#----------------------------------------------------------
#
# String for backup name
#
BACKUP_DATE=$(date "+%Y%m%d-%H%M%S")
BACKUP_SUFFIX="backup_${BACKUP_DATE}"

#==========================================================
# [Processing] Run Login mode
#==========================================================
#
# Attach(exec) to a running container.
#
if [ "${RUN_MODE}" = "login" ]; then
	if docker ps | grep -q -i "${K2HR3_NODE_CONTAINER_NAME}"; then
		#
		# Found container
		#
		if echo "${K2HR3_NODE_CONTAINER_NAME}" | grep -q -i "alpine"; then
			_CONTAINER_LOGIN_SHELL="/bin/sh"
		else
			_CONTAINER_LOGIN_SHELL="/bin/bash"
		fi

		#
		# Make DOCKER_ENV_OPTIONS variable (for docker proxy environment options)
		#
		if ! setup_docker_proxy_env_options; then
			PRNERR "Failed to make DOCKER_ENV_OPTIONS variable (for docker proxy environment options)."
			return 1
		fi

		#
		# Attach(exec)
		#
		PRNTITLE "Login(attach) into ${K2HR3_NODE_CONTAINER_NAME} container"
		echo ""

		/bin/sh -c "docker exec ${DOCKER_ENV_OPTIONS} -it ${K2HR3_NODE_CONTAINER_NAME} ${_CONTAINER_LOGIN_SHELL}"

		echo ""
		PRNINFO "Logout from ${K2HR3_NODE_CONTAINER_NAME} container"
		echo ""
	else
		PRNERR "Not found \"${K2HR3_NODE_CONTAINER_NAME}\" container."
		exit 1
	fi
	exit 0
fi

#==========================================================
# [Processing] Prepare K2HR3 API/APP repository archive
#==========================================================
# [NOTE]
# Archive the repositories in advance, copy those into the container,
# and unpack the archives inside the container.
#
if [ "${RUN_IN_CONTAINER}" -eq 0 ] && [ "${RUN_MODE}" = "start" ]; then
	PRNMSG "Prepare K2HR3 API/APP repository archive"

	if ! create_k2hr3_repository_archives; then
		PRNERR "Failed to prepare K2HR3 API/APP repository archive."
		exit 1
	fi
	echo ""
	PRNINFO "Succeed to prepare K2HR3 API/APP repository archive."
fi

#==========================================================
# [Processing] Validate host environments by additional functions
#==========================================================
PRNMSG "Validate host environments"

if ! addition_validate_host_environments "${RUN_MODE}" "${RUN_IN_CONTAINER}"; then
	PRNERR "Failed to validate host environments."
	exit 1
fi
PRNINFO "Succeed to validate host environments."

#==========================================================
# [Processing] Run and Switch script in container
#==========================================================
if [ -n "${RUN_CONTAINER}" ]; then
	if [ "${RUN_MODE}" = "start" ]; then
		_STR_RUN_TYPE_TITLE="Launch"
	else
		_STR_RUN_TYPE_TITLE="Stop"
	fi
	PRNTITLE "${_STR_RUN_TYPE_TITLE} K2HR3 system in Conatiner(${RUN_CONTAINER})"

	#
	# Check docker command and daemon
	#
	if ! command -v docker >/dev/null 2>&1; then
		PRNERR "Not found docker command, Please prepare the Docker execution environment."
		exit 1
	fi
	if ! systemctl status docker >/dev/null 2>&1; then
		PRNERR "Not found docker daemon, Please prepare the Docker execution environment."
		exit 1
	fi

	#
	# Run this script in docker container
	#
	if ! run_container_script "${RUN_CONTAINER}"; then
		PRNERR "Failed to ${_STR_RUN_TYPE_TITLE} K2HR3 system in Conatiner(${RUN_CONTAINER})"
		exit 1
	fi
	exit 0
fi

#==========================================================
# [Processing] Run Stop mode
#==========================================================
#
# In stop mode, this is where you process and complete the script.
#
if [ "${RUN_MODE}" = "stop" ]; then
	PRNTITLE "Stop all processes"

	#
	# Stop K2HR3 APP processes
	#
	PRNMSG "Try to stop K2HR3 APP processes"

	if [ ! -d "${REPO_K2HR3_APP_DIR}" ]; then
		PRNWARN "Not found ${REPO_K2HR3_APP_DIR} directory for K2HR3 APP."
	else
		cd "${REPO_K2HR3_APP_DIR}" || exit 1

		if ({ /bin/sh -c "npm run stop 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNWARN "Failed to stop K2HR3 APP node processes."
		else
			PRNINFO "Stopped K2HR3 APP processes"
		fi
		cd "${CURRENT_DIR}" || exit 1
	fi

	#
	# Stop K2HR3 API processes
	#
	PRNMSG "Try to stop K2HR3 API processes"

	if [ ! -d "${REPO_K2HR3_API_DIR}" ]; then
		PRNWARN "Not found ${REPO_K2HR3_API_DIR} directory for K2HR3 API."
	else
		cd "${REPO_K2HR3_API_DIR}" || exit 1

		if ({ /bin/sh -c "npm run stop 2>&1" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNWARN "Failed to stop K2HR3 API node processes."
		else
			PRNINFO "Stopped K2HR3 API processes"
		fi
		cd "${CURRENT_DIR}" || exit 1
	fi

	#
	# Stop chmpx/k2hkdkc processes
	#
	PRNMSG "Try to stop chmpx/k2hdkc processes"

	if [ ! -d "${WORK_PIDS_DIR}" ]; then
		PRNWARN "Not found ${WORK_PIDS_DIR} directory, so can not stop chmpx/k2hdkc processes."
	else
		_STILL_RUN_PROCS=0
		if ! stop_process_by_pidfile "${WORK_PIDS_DIR}/${CHMPX_SLAVE_NODE_0_PIDFILE}"; then
			_STILL_RUN_PROCS=$((_STILL_RUN_PROCS + 1))
		fi
		if ! stop_process_by_pidfile "${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_1_PIDFILE}"; then
			_STILL_RUN_PROCS=$((_STILL_RUN_PROCS + 1))
		fi
		if ! stop_process_by_pidfile "${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_0_PIDFILE}"; then
			_STILL_RUN_PROCS=$((_STILL_RUN_PROCS + 1))
		fi
		if ! stop_process_by_pidfile "${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_1_PIDFILE}"; then
			_STILL_RUN_PROCS=$((_STILL_RUN_PROCS + 1))
		fi
		if ! stop_process_by_pidfile "${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_0_PIDFILE}"; then
			_STILL_RUN_PROCS=$((_STILL_RUN_PROCS + 1))
		fi
		if [ "${_STILL_RUN_PROCS}" -gt 0 ]; then
			PRNWARN "Could not stop some processes(${_STILL_RUN_PROCS}) about chmpx/k2hdkc, still those process is running."
		fi
	fi

	echo ""
	PRNINFO "Finished to stop all processes."
	echo ""

	exit 0
fi

#==========================================================
# [Processing] Setup variables
#==========================================================
PRNTITLE "Setup variables"

#----------------------------------------------------------
# Setup variables for installing packages
#----------------------------------------------------------
PRNMSG "Setup variables for installing packages"
if ! setup_variables_for_install_packages; then
	PRNERR "Failed to check and setup variables for current host OS"
	exit 1
fi
PRNINFO "Succeed to setup variables for installing packages"

#----------------------------------------------------------
# Check NodeJS version for only ALPINE
#----------------------------------------------------------
# In the case of ALPINE, the NODEJS version is fixed depending
# on the OS version.
# Here, we check the specified (or default) NodeJS version and
# force that version.
#
if echo "${K2HR3_NODE_OS_NAME}" | grep -q -i "alpine"; then
	PRNMSG "Check NodeJS version and ALPINE OS version."

	_OS_MAJOR_VERSION=$(echo "${K2HR3_NODE_OS_VERSION}" | awk -F '.' '{print $1}' | tr -d '\n')
	_OS_MINOR_VERSION=$(echo "${K2HR3_NODE_OS_VERSION}" | awk -F '.' '{print $2}' | tr -d '\n')
	if [ -z "${_OS_MINOR_VERSION}" ]; then
		_OS_MINOR_VERSION=0
	fi

	if [ "${_OS_MAJOR_VERSION}" -lt 3 ]; then
		PRNERR "ALPINE OS version ${K2HR3_NODE_OS_VERSION} is too low to support."
		exit 1
	elif [ "${_OS_MINOR_VERSION}" -lt 19 ]; then
		PRNERR "ALPINE OS version ${K2HR3_NODE_OS_VERSION} is too low to support."
		exit 1
	elif [ "${_OS_MINOR_VERSION}" -gt 21 ]; then
		PRNERR "ALPINE OS version ${K2HR3_NODE_OS_VERSION} is too high to support."
		exit 1
	fi

	if [ "${_OS_MINOR_VERSION}" -eq 19 ]; then
		if [ "${NODEJS_VERSION}" -ne 18 ]; then
			PRNWARN "NodeJS v${NODEJS_VERSION} was specified, but only NodeJS v18 can be used in ALPINE ${K2HR3_NODE_OS_VERSION}. This value will be ignored and v18 will be used."
		fi
		NODEJS_VERSION=18
	elif [ "${_OS_MINOR_VERSION}" -eq 20 ]; then
		if [ "${NODEJS_VERSION}" -ne 20 ]; then
			PRNWARN "NodeJS v${NODEJS_VERSION} was specified, but only NodeJS v20 can be used in ALPINE ${K2HR3_NODE_OS_VERSION}. This value will be ignored and v20 will be used."
		fi
		NODEJS_VERSION=20
	elif [ "${_OS_MINOR_VERSION}" -eq 21 ]; then
		if [ "${NODEJS_VERSION}" -ne 22 ]; then
			PRNWARN "NodeJS v${NODEJS_VERSION} was specified, but only NodeJS v22 can be used in ALPINE ${K2HR3_NODE_OS_VERSION}. This value will be ignored and v22 will be used."
		fi
		NODEJS_VERSION=22
	fi
	PRNINFO "Decided NodeJS version is v${NODEJS_VERSION} for AlPINE ${K2HR3_NODE_OS_VERSION}"
fi

PRNINFO "Succeed to setup variables"

#==========================================================
# [Processing] Print information
#==========================================================
PRNTITLE "Print Information"

#----------------------------------------------------------
# Set variable strings for printing
#----------------------------------------------------------
if [ "${IS_INTERACTIVE}" -eq 1 ]; then
	STR_INTERACTIVE="yes"
else
	STR_INTERACTIVE="no"
fi

if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
	STR_STATUS_PACKAGECLOUD_REPO="Found"
else
	STR_STATUS_PACKAGECLOUD_REPO="Not found"
fi
if [ "${IS_USE_PACKAGECLOUD}" -eq 1 ]; then
	if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
		STR_USE_PACKAGECLOUD="yes (already setup packagecloud.io repository)"
	else
		STR_USE_PACKAGECLOUD="yes (need to setup packagecloud.io repository)"
	fi
else
	if [ "${STATUS_PACKAGECLOUD_REPO}" -eq 1 ]; then
		STR_USE_PACKAGECLOUD="no (need to setup packagecloud.io repository)"
	else
		STR_USE_PACKAGECLOUD="no (nothing to do because packagecloud.io repository has not been configured yet)"
	fi
fi
if [ "${RUN_IN_CONTAINER}" -eq 1 ]; then
	STR_RUN_IN_CONTAINER="yes"
else
	STR_RUN_IN_CONTAINER="no"
fi

if [ -n "${HTTP_PROXY}" ]; then
	STR_HTTP_PROXY="${HTTP_PROXY}"
else
	STR_HTTP_PROXY="(empty)"
fi
if [ -n "${HTTPS_PROXY}" ]; then
	STR_HTTPS_PROXY="${HTTPS_PROXY}"
else
	STR_HTTPS_PROXY="(empty)"
fi
if [ -n "${NO_PROXY}" ]; then
	STR_NO_PROXY="${NO_PROXY}"
else
	STR_NO_PROXY="(empty)"
fi

#----------------------------------------------------------
# Print Information
#----------------------------------------------------------
STR_K2HDKC_K2H_PATH=$(echo "${K2HDKC_K2H_PATH}" | sed -e "s#${DEFAULT_K2HFILE_SUFFIX_NODENO_KEY}#<node number>#g" | tr -d '\n')

echo "[Script environments]"
echo "    Run mode                                  : ${RUN_MODE}"
echo "    Interactive mode                          : ${STR_INTERACTIVE}"
echo "    Current packagecloud.io repository        : ${STR_STATUS_PACKAGECLOUD_REPO}"
echo "    Need to setup packagecloud.io repository  : ${STR_USE_PACKAGECLOUD}"
echo ""
echo "[System resources]"
echo "    OS type                                   : ${K2HR3_NODE_OS_NAME}:${K2HR3_NODE_OS_VERSION}"
echo "    OS type number(k2hr3 system run on)       : ${K2HR3_NODE_OS_TYPE_NUMBER}"
echo "    Run in container                          : ${STR_RUN_IN_CONTAINER}"
echo "    NodeJS version                            : v${NODEJS_VERSION}"
echo ""
echo "    Package manager                           : ${PKGMGR}"
echo "    Install base packages                     : ${INSTALL_BASE_PKG_LIST}"
echo "    Install packages                          : ${INSTALL_PKG_LIST}"
echo ""
echo "    MQ queues_max                             : ${DEFAULT_MQ_QMAX}"
echo "    MQ msg_max                                : ${DEFAULT_MQ_MSGMAX}"
echo ""
echo "[Directories/Files]"
echo "    Top directory for working                 : ${WORK_DIR}"
echo "    configuration file directory              : ${WORK_CONF_DIR}"
echo "    log file directory                        : ${WORK_LOGS_DIR}"
echo "    PID file directory                        : ${WORK_PIDS_DIR}"
echo "    data file directory                       : ${WORK_DATA_DIR}"
echo "    K2HR3 API repository directory            : ${REPO_K2HR3_API_DIR}"
echo "    K2HR3 APP repository directory            : ${REPO_K2HR3_APP_DIR}"
echo "    K2HR3 API repository archive              : ${K2HR3_API_REPO_ARCHIVE_FILE}"
echo "    K2HR3 APP repository archive              : ${K2HR3_APP_REPO_ARCHIVE_FILE}"
echo "    Backup file/directory suffix              : .${BACKUP_SUFFIX}"
echo ""
echo "[Source codes]"
echo "    K2HR3 API URL for cloning                 : ${REPO_K2HR3_API}"
echo "    K2HR3 APP URL for cloning                 : ${REPO_K2HR3_APP}"
echo ""
echo "[Proxy Environments]"
echo "    HTTP_PROXY                                : ${STR_HTTP_PROXY}"
echo "    HTTPS_PROXY                               : ${STR_HTTPS_PROXY}"
echo "    NO_PROXY                                  : ${STR_NO_PROXY}"
echo ""

if [ -n "${SCHEME_HTTP_PROXY}" ] || [ -n "${SCHEME_HTTPS_PROXY}" ] || [ -n "${NPM_REGISTORIES}" ]; then
	echo "[NPM/NodeJS configuration]"
	if [ -n "${SCHEME_HTTP_PROXY}" ]; then
		echo "    HTTP_PROXY                                : ${SCHEME_HTTP_PROXY}"
	fi
	if [ -n "${SCHEME_HTTPS_PROXY}" ]; then
		echo "    HTTPS_PROXY                               : ${SCHEME_HTTPS_PROXY}"
	fi
	for _one_npm_registory in ${NPM_REGISTORIES}; do
		_ADD_NPMREG_NAME=$(echo "${_one_npm_registory}" | awk -F ',' '{print $1}' 2>/dev/null)
		_ADD_NPMREG_URL=$(echo "${_one_npm_registory}" | awk -F ',' '{print $2}' 2>/dev/null)
		echo "    Additional NPM registory                  : ${_ADD_NPMREG_NAME} = ${_ADD_NPMREG_URL}"
	done
	echo ""
fi

echo "[K2HR3 system information]"
echo "    K2HR3 APP port                            : ${K2HR3_APP_PORT}"
echo "    K2HR3 APP external host                   : ${K2HR3_APP_HOST}"
echo "    K2HR3 APP external URL                    : ${K2HR3_APP_URL}"
echo "    K2HR3 API port                            : ${K2HR3_API_PORT}"
echo "    K2HR3 API external host                   : ${K2HR3_API_HOST}"
echo "    K2HR3 API external URL                    : ${K2HR3_API_URL}"
echo ""
echo "    K2HR3 APP configuration file              : ${K2HR3_APP_CONF_FILE}"
echo "    K2HR3 API configuration file              : ${K2HR3_API_CONF_FILE}"
echo ""
echo "    K2HR3 APP log file(launching)             : ${K2HR3_APP_LOGFILE}"
echo "    K2HR3 API log file(launching)             : ${K2HR3_API_LOGFILE}"
echo ""
echo "    K2HDKC k2hash data file path              : ${STR_K2HDKC_K2H_PATH}"
echo "    K2HDKC server(0) port                     : ${K2HDKC_SERVER_NODE_0_PORT}"
echo "    K2HDKC server(0) control port             : ${K2HDKC_SERVER_NODE_0_CTLPORT}"
echo "    K2HDKC server(1) port                     : ${K2HDKC_SERVER_NODE_1_PORT}"
echo "    K2HDKC server(1) control port             : ${K2HDKC_SERVER_NODE_1_CTLPORT}"
echo "    K2HDKC slave(0) control port              : ${K2HDKC_SLAVE_NODE_0_CTLPORT}"
echo ""
echo "    K2HDKC server node(0) configuration file  : ${K2HDKC_SERVER_NODE_0_CONF_FILE}"
echo "    K2HDKC server node(1) configuration file  : ${K2HDKC_SERVER_NODE_1_CONF_FILE}"
echo "    K2HDKC slave  node(0) configuration file  : ${K2HDKC_SLAVE_NODE_0_CONF_FILE}"
echo ""
echo "    CHMPX server(0) pid file                  : ${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_0_PIDFILE}"
echo "    CHMPX server(1) pid file                  : ${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_1_PIDFILE}"
echo "    CHMPX slave(0) pid file                   : ${WORK_PIDS_DIR}/${CHMPX_SLAVE_NODE_0_PIDFILE}"
echo "    K2HDKC server(0) pid file                 : ${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_0_PIDFILE}"
echo "    K2HDKC server(1) pid file                 : ${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_1_PIDFILE}"
echo ""
echo "    CHMPX server(0) log file                  : ${WORK_LOGS_DIR}/${CHMPX_SERVER_NODE_0_LOGFILE}"
echo "    CHMPX server(1) log file                  : ${WORK_LOGS_DIR}/${CHMPX_SERVER_NODE_1_LOGFILE}"
echo "    CHMPX slave(0) log file                   : ${WORK_LOGS_DIR}/${CHMPX_SLAVE_NODE_0_LOGFILE}"
echo "    K2HDKC server(0) log file                 : ${WORK_LOGS_DIR}/${K2HDKC_SERVER_NODE_0_LOGFILE}"
echo "    K2HDKC server(1) log file                 : ${WORK_LOGS_DIR}/${K2HDKC_SERVER_NODE_1_LOGFILE}"
echo ""

#
# Print additional variables information
#
if ! addition_print_variables_info "${RUN_IN_CONTAINER}"; then
	PRNERR "Failed to print additinal variables information."
	exit 1
fi

#----------------------------------------------------------
# Confirmation
#----------------------------------------------------------
if [ "${IS_INTERACTIVE}" -eq 1 ]; then
	_IS_LOOP=1
	while [ "${_IS_LOOP}" -eq 1 ]; do
		input_interaction "Do you want to continue? [yes(y)/no(n)]"

		if echo "${INTERACTION_RESULT}" | grep -q -i -e "^y$" -e "^yes$"; then
			_IS_LOOP=0
			echo ""
		elif echo "${INTERACTION_RESULT}" | grep -q -i -e "^n$" -e "^no$"; then
			PRNINFO "Terminate this process."
			exit 0
		else
			PRNERR "The input data must be \"yes(y)\" or \"no(n)\"."
		fi
	done
fi

#==========================================================
# [Processing] before launch K2HR3 system
#==========================================================
#----------------------------------------------------------
# Setup configuration for MQ
#----------------------------------------------------------
PRNTITLE "Setup configuration for MQ"

if ! setup_configuration_for_mq; then
	PRNERR "Failed to setup configuration for MQ."
	exit 1
fi
echo ""
PRNINFO "Succeed to setup configuration for MQ."

#----------------------------------------------------------
# Setup package repositories and Install packages
#----------------------------------------------------------
PRNTITLE "Setup package repositories and Install packages"

if ! setup_repositories_packages; then
	PRNERR "Failed to setup package repositories and install packages."
	exit 1
fi
PRNINFO "Succeed to setup package repositories and install packages."

#----------------------------------------------------------
# Setup NPM/NodeJS configuration
#----------------------------------------------------------
PRNTITLE "Setup NPM/NodeJS configuration"

if ! setup_npm_configuration; then
	PRNERR "Failed to setup NPM/NodeJS configuration."
	exit 1
fi
PRNINFO "Succeed to setup NPM/NodeJS configuration."

#----------------------------------------------------------
# Setup Working Directories
#----------------------------------------------------------
PRNTITLE "Setup Working Directories(sub-directory: K2HR3 APP/API git repository, conf, logs, pids)"

if ! setup_working_directries; then
	PRNERR "Failed to setup working directories(sub-directory: K2HR3 APP/API git repository, conf, logs, pids)."
	exit 1
fi
PRNINFO "Succeed to setup working directories(sub-directory: K2HR3 APP/API git repository, conf, logs, pids)."

#----------------------------------------------------------
# Create All Configuration files
#----------------------------------------------------------
PRNTITLE "Create All Configuration files"

if ! create_configuration_files; then
	PRNERR "Failed to create All Configuration files."
	exit 1
fi
PRNINFO "Succeed to create All Configuration files."

#==========================================================
# [Processing] Run K2HR3 system processes
#==========================================================
PRNTITLE "Run K2HR3 system processes"

#
# K2HDKC Serer nodes
#
PRNMSG "Run K2HDKC server node processes"

if ! run_one_k2hdkc_server_node "${K2HDKC_SERVER_NODE_0_CONF_FILE}" "${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_0_PIDFILE}" "${WORK_LOGS_DIR}/${CHMPX_SERVER_NODE_0_LOGFILE}" "${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_0_PIDFILE}" "${WORK_LOGS_DIR}/${K2HDKC_SERVER_NODE_0_LOGFILE}"; then
	PRNERR "Failed to run K2HDKC server node(0) processes."
	exit 1
fi
PRNINFO "Succeed to run K2HDKC server node(0) processes."

if ! run_one_k2hdkc_server_node "${K2HDKC_SERVER_NODE_1_CONF_FILE}" "${WORK_PIDS_DIR}/${CHMPX_SERVER_NODE_1_PIDFILE}" "${WORK_LOGS_DIR}/${CHMPX_SERVER_NODE_1_LOGFILE}" "${WORK_PIDS_DIR}/${K2HDKC_SERVER_NODE_1_PIDFILE}" "${WORK_LOGS_DIR}/${K2HDKC_SERVER_NODE_1_LOGFILE}"; then
	PRNERR "Failed to run K2HDKC server node(1) processes."
	exit 1
fi
PRNINFO "Succeed to run K2HDKC server node(1) processes."

#
# K2HDKC Slave node
#
PRNMSG "Run K2HDKC slave node processes"

if ! run_chmpx_slave_node "${K2HDKC_SLAVE_NODE_0_CONF_FILE}" "${WORK_PIDS_DIR}/${CHMPX_SLAVE_NODE_0_PIDFILE}" "${WORK_LOGS_DIR}/${CHMPX_SLAVE_NODE_0_LOGFILE}"; then
	PRNERR "Failed to run K2HDKC slave node processes"
	exit 1
fi
PRNINFO "Succeed to run K2HDKC slave node processes"

#
# K2HR3 API
#
PRNMSG "Run K2HR3 API processes"

if ! run_k2hr3_api "${K2HR3_API_LOGFILE}"; then
	PRNERR "Failed to run K2HR3 API processes"
	exit 1
fi
PRNINFO "Succeed to run K2HR3 API processes"

#
# K2HR3 APP
#
PRNMSG "Run K2HR3 APP processes"

if ! run_k2hr3_app "${K2HR3_APP_LOGFILE}"; then
	PRNERR "Failed to run K2HR3 APP processes"
	exit 1
fi
PRNINFO "Succeed to run K2HR3 APP processes"

#==========================================================
# [Processing] Finish
#==========================================================
cd "${CURRENT_DIR}" || exit 1

PRNTITLE "Launched K2HR3 system"

echo "The K2HR3 system has started successfully."

if [ "${RUN_IN_CONTAINER}" -eq 1 ]; then
	echo "This K2HR3 system is running ${CGRN}in a container${CDEF}."
fi

echo "All files related to the K2HR3 system are extracted under the \"${CGRN}${WORK_DIR}${CDEF}\" directory."
echo ""
echo "You can operate the K2HR3 system by accessing the following URLs:"
echo "    K2HR3 REST API         : ${CGRN}${K2HR3_API_URL}${CDEF}"
echo "    K2HR3 Web Application  : ${CGRN}${K2HR3_APP_URL}${CDEF}"
echo "--------------------------------------------------"

PRNSUCCESS "${PROGRAM_NAME} Finished without any error."

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
