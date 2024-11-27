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
# CREATE:   Tue Oct 20 2020
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
SCRIPTDIR=$(dirname "${0}")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)
SRCTOP=$(cd "${SCRIPTDIR}"/.. || exit 1; pwd)
#BINDIR="${SCRIPTDIR}"

#
# Option variables
#
OPT_NO_INTERACTIVE="no"
OPT_NO_COMFIRMATION=""
OPT_RUNUSER=""
OPT_CHMPX_SERVER_PORT=
OPT_CHMPX_SERVER_CTLPORT=
OPT_CHMPX_SLAVE_CTLPORT=
OPT_OPENSTACK_REGION=""
OPT_KEYSTONE_URL=""
OPT_K2HR3_APP_PORT=
OPT_K2HR3_APP_PORT_EXTERNAL=
OPT_K2HR3_APP_HOST=
OPT_K2HR3_APP_HOST_EXTERNAL=
OPT_K2HR3_API_PORT=
OPT_K2HR3_API_PORT_EXTERNAL=
OPT_K2HR3_API_HOST=
OPT_K2HR3_API_HOST_EXTERNAL=

#==============================================================
# Common Variables and Utility functions
#==============================================================
#
# Escape sequence
#
if [ -t 1 ]; then
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
	echo ""
	echo "${CBLD}${CRED}[ERROR]${CDEF} ${CRED}$*${CDEF}"
}

PRNWARN()
{
	echo "    ${CYEL}${CREV}[WARNING]${CDEF} $*"
}

PRNMSG()
{
	echo ""
	echo "    ${CYEL}${CREV}[MSG]${CDEF} $*"
}

PRNINFO()
{
	echo "    ${CREV}[INFO]${CDEF} $*"
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
}

#--------------------------------------------------------------
# Interaction function
#--------------------------------------------------------------
#
# $1:	Input Message(puts stderr)
# $2:	Input data type is number = yes(1)/no(0)
# $3:	Whether to allow empty = yes(1)/no(0, empty)
#
# $?					: result(0/1)
# INTERACTION_RESULT	: user input string
#
input_interaction()
{
	INTERACTION_RESULT=""

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		PRNERR "Wrong parameter"
		return 1
	fi
	INPUT_MSG="$1 > "
	shift

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		PRNERR "Wrong parameter"
		return 1
	elif [ "$1" = "yes" ] || [ "$1" = "YES" ] || [ "$1" -eq 1 ]; then
		IS_NUMBER=1
	else
		IS_NUMBER=0
	fi
	shift

	if [ $# -lt 1 ] || [ -z "$1" ]; then
		IS_ALLOW_EMPTY=0
	elif [ "$1" = "yes" ] || [ "$1" = "YES" ] || [ "$1" -eq 1 ]; then
		IS_ALLOW_EMPTY=1
	else
		IS_ALLOW_EMPTY=0
	fi

	IS_LOOP=1
	while [ "${IS_LOOP}" -eq 1 ]; do
		printf "${CREV}[INPUT]${CDEF} %s" "${INPUT_MSG}"
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
					PRNERR "The input data must be number"
				else
					IS_LOOP=0
				fi
			fi
		fi
	done

	return 0
}

#--------------------------------------------------------------
# Utility Function for waiting processes up
#--------------------------------------------------------------
#
# $1:	Process name for waiting
# $2:	String for filtering the result of ps command
# $3:	Unit wait time
# $4:	Count for retrying
#
wait_process_running()
{
	if [ $# -lt 4 ]; then
		PRNERR "Wrong parameter"
		return 1
	fi

	WAIT_PROCESSES="$1"
	FILTER_STRING="$2"
	WAIT_TIME="$3"
	MAXIMUM_COUNT="$4"
	if [ -z "${WAIT_PROCESSES}" ] || [ -z "${FILTER_STRING}" ] || [ -z "${WAIT_TIME}" ] || [ -z "${MAXIMUM_COUNT}" ] || [ -z "${MAXIMUM_COUNT}" ]; then
		PRNERR "Wrong parameter"
		return 1
	fi
	if echo "${WAIT_TIME}" | grep -q "[^0-9]"; then
		PRNERR "Wrong parameter"
		return 1
	fi
	if echo "${MAXIMUM_COUNT}" | grep -q "[^0-9]"; then
		PRNERR "Wrong parameter"
		return 1
	fi

	while [ "${MAXIMUM_COUNT}" -gt 0 ]; do
		sleep "${WAIT_TIME}"
		# shellcheck disable=SC2009
		if ps ax | grep "${WAIT_PROCESSES}" | grep -q "${FILTER_STRING}"; then
			return 0
		fi
		MAXIMUM_COUNT=$((MAXIMUM_COUNT - 1))
	done

	return 1
}

#----------------------------------------------------------
# Usage function
#----------------------------------------------------------
func_usage()
{
	#
	# $1:	Program name
	#
	echo ""
	echo "Usage:  $1 [--no_interaction(-ni)] [--no_confirmation(-nc)]"
	echo "        [--run_user(-ru) <user name>] [--openstack_region(-osr) <region name>] [--keystone_url(-ks) <url string>]"
	echo "        [--server_port(-svrp) <number>] [--server_ctlport(-svrcp) <number>] [--slave_ctlport(-slvcp) <number>]"
	echo "        [--app_port(-appp) <number>]         [--app_port_external(-apppe) <number>]"
	echo "        [--app_host(-apph) <hostname or ip>] [--app_host_external(-apphe) <hostname or ip>]"
	echo "        [--api_port(-apip) <number>]         [--api_port_external(-apipe) <number>]"
	echo "        [--api_host(-apih) <hostname or ip>] [--api_host_external(-apihe) <hostname or ip>]"
	echo "        [--help(-h)]"
	echo ""
	echo "[Options]"
	echo "  Common:"
	echo "        --help(-h)                    print help"
	echo "        --no_interaction(-ni)         Turn off interactive mode for unspecified option input and use default value"
	echo "        --run_user(-ru)               Specify the execution user of each process"
	echo "        --openstack_region(-osr)      Specify OpenStack(Keystone) Region(ex: RegionOne)"
	echo "        --keystone_url(-ks)           Specify OpenStack Keystone URL(ex: https://dummy.keystone.openstack/)"
	echo "  CHMPX / K2HKDC:"
	echo "        --server_port(-svrp)          Specify CHMPX server node process port"
	echo "        --server_ctlport(-svrcp)      Specify CHMPX server node process control port"
	echo "        --slave_ctlport(-slvcp)       Specify CHMPX slave node process control port"
	echo "  K2HR3 APP:"
	echo "        --app_port(-appp)             Specify K2HR3 Application port"
	echo "        --app_port_external(-apppe)   Specify K2HR3 Application external port(optional: specify when using a proxy)"
	echo "        --app_port_private(-apppp)    Specify K2HR3 Application private port(optional: specify when openstack)"
	echo "        --app_host(-apph)             Specify K2HR3 Application host"
	echo "        --app_host_external(-apphe)   Specify K2HR3 Application external host(optional: host as javascript download server)"
	echo "        --app_host_private(-apphp)    Specify K2HR3 Application private host(optional: specify when openstack)"
	echo "  K2HR3 API:"
	echo "        --api_port(-apip)             Specify K2HR3 REST API port"
	echo "        --api_port_external(-apipe)   Specify K2HR3 REST API external port(optional: specify when using a proxy)"
	echo "        --api_port_private(-apipp)    Specify K2HR3 REST API private port(optional: specify when openstack)"
	echo "        --api_host(-apih)             Specify K2HR3 REST API host"
	echo "        --api_host_external(-apihe)   Specify K2HR3 REST API external host(optional: specify when using a proxy)"
	echo "        --api_host_private(-apihp)    Specify K2HR3 REST API private host(optional: specify when openstack)"
	echo ""
	echo "[Environments]"
	echo "        If PROXY environment variables(HTTP(s)_PROXY, NO_PROXY) are detected,"
	echo "        environment variable settings (including sudo) and npm settings are"
	echo "        automatically performed."
	echo ""
}

#==========================================================
# Check Options
#==========================================================
while [ $# -ne 0 ]; do
	if [ -z "$1" ]; then
		break

	elif [ "$1" = "-h" ] || [ "$1" = "-H" ] || [ "$1" = "--help" ] || [ "$1" = "--HELP" ]; then
		func_usage "${PROGRAM_NAME}"
		exit 0

	elif [ "$1" = "-ni" ] || [ "$1" = "-NI" ] || [ "$1" = "--no_interaction" ] || [ "$1" = "--NO_INTERACTION" ]; then
		if [ "${OPT_NO_INTERACTIVE}" != "no" ]; then
			PRNERR "--no_interaction(-ni) option is already specified."
			exit 1
		fi
		OPT_NO_INTERACTIVE="yes"

	elif [ "$1" = "-nc" ] || [ "$1" = "-NC" ] || [ "$1" = "--no_confirmation" ] || [ "$1" = "--NO_CONFIRMATION" ]; then
		if [ -n "${OPT_NO_COMFIRMATION}" ]; then
			PRNERR "--no_confirmation(-nc) option is already specified."
			exit 1
		fi
		OPT_NO_COMFIRMATION="yes"

	elif [ "$1" = "-ru" ] || [ "$1" = "-RU" ] || [ "$1" = "--run_user" ] || [ "$1" = "--RUN_USER" ]; then
		if [ -n "${OPT_RUNUSER}" ]; then
			PRNERR "--run_user(-ru) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--run_user(-ru) option needs parameter."
			exit 1
		fi
		OPT_RUNUSER="$1"

	elif [ "$1" = "-svrp" ] || [ "$1" = "-SVRP" ] || [ "$1" = "--server_port" ] || [ "$1" = "--SERVER_PORT" ]; then
		if [ -n "${OPT_CHMPX_SERVER_PORT}" ]; then
			PRNERR "--server_port(-svrp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--server_port(-svrp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --server_port(-svrp) option must be number."
			exit 1
		fi
		OPT_CHMPX_SERVER_PORT="$1"

	elif [ "$1" = "-svrcp" ] || [ "$1" = "-SVRCP" ] || [ "$1" = "--server_ctlport" ] || [ "$1" = "--SERVER_CTLPORT" ]; then
		if [ -n "${OPT_CHMPX_SERVER_CTLPORT}" ]; then
			PRNERR "--server_ctlport(-svrcp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--server_ctlport(-svrcp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --server_ctlport(-svrcp) option must be number."
			exit 1
		fi
		OPT_CHMPX_SERVER_CTLPORT="$1"

	elif [ "$1" = "-slvcp" ] || [ "$1" = "-SLVCP" ] || [ "$1" = "--slave_ctlport" ] || [ "$1" = "--SLAVE_CTLPORT" ]; then
		if [ -n "${OPT_CHMPX_SLAVE_CTLPORT}" ]; then
			PRNERR "--slave_ctlport(-slvcp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--slave_ctlport(-slvcp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --slave_ctlport(-slvcp) option must be number."
			exit 1
		fi
		OPT_CHMPX_SLAVE_CTLPORT="$1"

	elif [ "$1" = "-osr" ] || [ "$1" = "-OSR" ] || [ "$1" = "--openstack_region" ] || [ "$1" = "--OPENSTACK_REGION" ]; then
		if [ -n "${OPT_OPENSTACK_REGION}" ]; then
			PRNERR "--openstack_region(-osr) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--openstack_region(-osr) option needs parameter."
			exit 1
		fi
		OPT_OPENSTACK_REGION="$1"

	elif [ "$1" = "-ks" ] || [ "$1" = "-KS" ] || [ "$1" = "--keystone_url" ] || [ "$1" = "--KEYSTONE_URL" ]; then
		if [ -n "${OPT_KEYSTONE_URL}" ]; then
			PRNERR "--keystone_url(-ks) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--keystone_url(-ks) option needs parameter."
			exit 1
		fi
		OPT_KEYSTONE_URL="$1"

	elif [ "$1" = "-appp" ] || [ "$1" = "-APPP" ] || [ "$1" = "--app_port" ] || [ "$1" = "--APP_PORT" ]; then
		if [ -n "${OPT_K2HR3_APP_PORT}" ]; then
			PRNERR "--app_port(-appp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_port(-appp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --app_port(-appp) option must be number."
			exit 1
		fi
		OPT_K2HR3_APP_PORT="$1"

	elif [ "$1" = "-apppe" ] || [ "$1" = "-APPPE" ] || [ "$1" = "--app_port_external" ] || [ "$1" = "--APP_PORT_EXTERNAL" ]; then
		if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
			PRNERR "--app_port_external(-apppe) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_port_external(-apppe) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --app_port_external(-apppe) option must be number."
			exit 1
		fi
		OPT_K2HR3_APP_PORT_EXTERNAL="$1"

	elif [ "$1" = "-apppp" ] || [ "$1" = "-APPPP" ] || [ "$1" = "--app_port_private" ] || [ "$1" = "--APP_PORT_PRIVATE" ]; then
		if [ -n "${OPT_K2HR3_APP_PORT_PRIVATE}" ]; then
			PRNERR "--app_port_private(-apppp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_port_private(-apppp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --app_port_private(-apppp) option must be number."
			exit 1
		fi
		OPT_K2HR3_APP_PORT_PRIVATE="$1"

	elif [ "$1" = "-apph" ] || [ "$1" = "-APPH" ] || [ "$1" = "--app_host" ] || [ "$1" = "--APP_HOST" ]; then
		if [ -n "${OPT_K2HR3_APP_HOST}" ]; then
			PRNERR "--app_host(-apph) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_host(-apph) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_APP_HOST="$1"

	elif [ "$1" = "-apphe" ] || [ "$1" = "-APPHE" ] || [ "$1" = "--app_host_external" ] || [ "$1" = "--APP_HOST_EXTERNAL" ]; then
		if [ -n "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
			PRNERR "--app_host_external(-apphe) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_host_external(-apphe) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_APP_HOST_EXTERNAL="$1"

	elif [ "$1" = "-apphp" ] || [ "$1" = "-APPHP" ] || [ "$1" = "--app_host_private" ] || [ "$1" = "--APP_HOST_PRIVATE" ]; then
		if [ -n "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
			PRNERR "--app_host_private(-apphp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--app_host_private(-apphp) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_APP_HOST_PRIVATE="$1"

	elif [ "$1" = "-apip" ] || [ "$1" = "-APIP" ] || [ "$1" = "--api_port" ] || [ "$1" = "--API_PORT" ]; then
		if [ -n "${OPT_K2HR3_API_PORT}" ]; then
			PRNERR "--api_port(-apip) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_port(-apip) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --api_port(-apip) option must be number."
			exit 1
		fi
		OPT_K2HR3_API_PORT="$1"

	elif [ "$1" = "-apipe" ] || [ "$1" = "-APIPE" ] || [ "$1" = "--api_port_external" ] || [ "$1" = "--API_PORT_EXTERNAL" ]; then
		if [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
			PRNERR "--api_port_external(-apipe) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_port_external(-apipe) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --api_port_external(-apipe) option must be number."
			exit 1
		fi
		OPT_K2HR3_API_PORT_EXTERNAL="$1"

	elif [ "$1" = "-apipp" ] || [ "$1" = "-APIPP" ] || [ "$1" = "--api_port_private" ] || [ "$1" = "--API_PORT_PRIVATE" ]; then
		if [ -n "${OPT_K2HR3_API_PORT_PRIVATE}" ]; then
			PRNERR "--api_port_private(-apipp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_port_private(-apipp) option needs parameter."
			exit 1
		fi
		if echo "$1" | grep -q "[^0-9]"; then
			PRNERR "The parameter of --api_port_private(-apipp) option must be number."
			exit 1
		fi
		OPT_K2HR3_API_PORT_PRIVATE="$1"

	elif [ "$1" = "-apih" ] || [ "$1" = "-APIH" ] || [ "$1" = "--api_host" ] || [ "$1" = "--API_HOST" ]; then
		if [ -n "${OPT_K2HR3_API_HOST}" ]; then
			PRNERR "--api_host(-apih) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_host(-apih) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_API_HOST="$1"

	elif [ "$1" = "-apihe" ] || [ "$1" = "-APIHE" ] || [ "$1" = "--api_host_external" ] || [ "$1" = "--API_HOST_EXTERNAL" ]; then
		if [ -n "${OPT_K2HR3_API_HOST_EXTERNAL}" ]; then
			PRNERR "--api_host_external(-apihe) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_host_external(-apihe) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_API_HOST_EXTERNAL="$1"

	elif [ "$1" = "-apihp" ] || [ "$1" = "-APIHP" ] || [ "$1" = "--api_host_private" ] || [ "$1" = "--API_HOST_PRIVATE" ]; then
		if [ -n "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then
			PRNERR "--api_host_private(-apihp) option is already specified."
			exit 1
		fi
		shift
		if [ $# -eq 0 ] || [ -z "$1" ]; then
			PRNERR "--api_host_private(-apihp) option needs parameter."
			exit 1
		fi
		OPT_K2HR3_API_HOST_PRIVATE="$1"

	else
		PRNERR "$1 option is unknown."
		exit 1
	fi
	shift
done

#
# Interaction or set default values
#
if [ "${OPT_NO_INTERACTIVE}" != "yes" ]; then
	if	[ -z "${OPT_RUNUSER}" ]					|| \
		[ -z "${OPT_CHMPX_SERVER_PORT}" ]		|| \
		[ -z "${OPT_CHMPX_SERVER_CTLPORT}" ]	|| \
		[ -z "${OPT_CHMPX_SLAVE_CTLPORT}" ]		|| \
		[ -z "${OPT_OPENSTACK_REGION}" ]		|| \
		[ -z "${OPT_KEYSTONE_URL}" ]			|| \
		[ -z "${OPT_K2HR3_APP_PORT}" ]			|| \
		[ -z "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]	|| \
		[ -z "${OPT_K2HR3_APP_PORT_PRIVATE}" ]	|| \
		[ -z "${OPT_K2HR3_APP_HOST}" ]			|| \
		[ -z "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]	|| \
		[ -z "${OPT_K2HR3_APP_HOST_PRIVATE}" ] 	|| \
		[ -z "${OPT_K2HR3_API_PORT}" ]			|| \
		[ -z "${OPT_K2HR3_API_PORT_EXTERNAL}" ]	|| \
		[ -z "${OPT_K2HR3_API_PORT_PRIVATE}" ] 	|| \
		[ -z "${OPT_K2HR3_API_HOST}" ]			|| \
		[ -z "${OPT_K2HR3_API_HOST_EXTERNAL}" ]	|| \
		[ -z "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then

		echo "${CGRN}-----------------------------------------------------------${CDEF}"
		echo "${CGRN}Input options${CDEF}"
		echo "${CGRN}-----------------------------------------------------------${CDEF}"

		if [ -z "${OPT_RUNUSER}" ]; then
			if ! input_interaction "Execution user of all processes" "no"; then
				exit 1
			fi
			OPT_RUNUSER="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_CHMPX_SERVER_PORT}" ]; then
			if ! input_interaction "CHMPX Server node port number" "yes"; then
				exit 1
			fi
			OPT_CHMPX_SERVER_PORT="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_CHMPX_SERVER_CTLPORT}" ]; then
			if ! input_interaction "CHMPX Server node control port number" "yes"; then
				exit 1
			fi
			OPT_CHMPX_SERVER_CTLPORT="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_CHMPX_SLAVE_CTLPORT}" ]; then
			if ! input_interaction "CHMPX Slave node control port number" "yes"; then
				exit 1
			fi
			OPT_CHMPX_SLAVE_CTLPORT="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_OPENSTACK_REGION}" ]; then
			if ! input_interaction "OpenStack(Keystone) Region(ex. \"RegionOne\")" "no"; then
				exit 1
			fi
			OPT_OPENSTACK_REGION="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_KEYSTONE_URL}" ]; then
			if ! input_interaction "OpenStack Keystone URL(ex. \"http(s)://....\")" "no"; then
				exit 1
			fi
			OPT_KEYSTONE_URL="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_PORT}" ]; then
			if ! input_interaction "K2HR3 Application port number" "yes"; then
				exit 1
			fi
			OPT_K2HR3_APP_PORT="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
			if ! input_interaction "K2HR3 Application external port number(enter empty if not present)" "yes" "yes"; then
				exit 1
			fi
			OPT_K2HR3_APP_PORT_EXTERNAL="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_PORT_PRIVATE}" ]; then
			if ! input_interaction "K2HR3 Application private port number(enter empty if not present)" "yes" "yes"; then
				exit 1
			fi
			OPT_K2HR3_APP_PORT_PRIVATE="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_HOST}" ]; then
			if ! input_interaction "K2HR3 Application hostname or IP address" "no"; then
				exit 1
			fi
			OPT_K2HR3_APP_HOST="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
			if ! input_interaction "K2HR3 Application external hostanme or IP address(enter empty if not present)" "no" "yes"; then
				exit 1
			fi
			OPT_K2HR3_APP_HOST_EXTERNAL="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
			if ! input_interaction "K2HR3 Application private hostanme or IP address(enter empty if not present)" "no" "yes"; then
				exit 1
			fi
			OPT_K2HR3_APP_HOST_PRIVATE="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_PORT}" ]; then
			if ! input_interaction "K2HR3 REST API port number" "yes"; then
				exit 1
			fi
			OPT_K2HR3_API_PORT="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
			if ! input_interaction "K2HR3 REST API external port number(enter empty if not present)" "yes" "yes"; then
				exit 1
			fi
			OPT_K2HR3_API_PORT_EXTERNAL="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_PORT_PRIVATE}" ]; then
			if ! input_interaction "K2HR3 REST API private port number(enter empty if not present)" "yes" "yes"; then
				exit 1
			fi
			OPT_K2HR3_API_PORT_PRIVATE="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_HOST}" ]; then
			if ! input_interaction "K2HR3 REST API hostname or IP address" "no"; then
				exit 1
			fi
			OPT_K2HR3_API_HOST="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_HOST_EXTERNAL}" ]; then
			if ! input_interaction "K2HR3 REST API external hostanme or IP address(enter empty if not present)" "no" "yes"; then
				exit 1
			fi
			OPT_K2HR3_API_HOST_EXTERNAL="${INTERACTION_RESULT}"
		fi
		if [ -z "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then
			if ! input_interaction "K2HR3 REST API private hostanme or IP address(enter empty if not present)" "no" "yes"; then
				exit 1
			fi
			OPT_K2HR3_API_HOST_PRIVATE="${INTERACTION_RESULT}"
		fi
	fi
else
	if [ -z "${OPT_RUNUSER}" ]; then
		#OPT_RUNUSER="root"
		OPT_RUNUSER="nobody"
	fi
	if [ -z "${OPT_CHMPX_SERVER_PORT}" ]; then
		OPT_CHMPX_SERVER_PORT=18020
	fi
	if [ -z "${OPT_CHMPX_SERVER_CTLPORT}" ]; then
		OPT_CHMPX_SERVER_CTLPORT=18021
	fi
	if [ -z "${OPT_CHMPX_SLAVE_CTLPORT}" ]; then
		OPT_CHMPX_SLAVE_CTLPORT=18031
	fi
	if [ -z "${OPT_OPENSTACK_REGION}" ]; then
		OPT_OPENSTACK_REGION="RegionOne"
	fi
	if [ -z "${OPT_KEYSTONE_URL}" ]; then
		OPT_KEYSTONE_URL="https://dummy.keystone.openstack/"
	fi
	if [ -z "${OPT_K2HR3_APP_PORT}" ]; then
		OPT_K2HR3_APP_PORT=80
	fi
	if [ -z "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
		OPT_K2HR3_APP_PORT_EXTERNAL=
	fi
	if [ -z "${OPT_K2HR3_APP_PORT_PRIVATE}" ]; then
		OPT_K2HR3_APP_PORT_PRIVATE=
	fi
	if [ -z "${OPT_K2HR3_APP_HOST}" ]; then
		OPT_K2HR3_APP_HOST="localhost"
	fi
	if [ -z "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
		OPT_K2HR3_APP_HOST_EXTERNAL=
	fi
	if [ -z "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
		OPT_K2HR3_APP_HOST_PRIVATE=
	fi
	if [ -z "${OPT_K2HR3_API_PORT}" ]; then
		OPT_K2HR3_API_PORT=18080
	fi
	if [ -z "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
		OPT_K2HR3_API_PORT_EXTERNAL=
	fi
	if [ -z "${OPT_K2HR3_API_PORT_PRIVATE}" ]; then
		OPT_K2HR3_API_PORT_PRIVATE=
	fi
	if [ -z "${OPT_K2HR3_API_HOST}" ]; then
		OPT_K2HR3_API_HOST="localhost"
	fi
	if [ -z "${OPT_K2HR3_API_HOST_EXTERNAL}" ]; then
		OPT_K2HR3_API_HOST_EXTERNAL=
	fi
	if [ -z "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then
		OPT_K2HR3_API_HOST_PRIVATE=
	fi
fi

#==========================================================
# Print options
#==========================================================
#
# Make strings for display
#
if [ -z "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
	DISP_K2HR3_APP_PORT_EXTERNAL="(empty: using K2HR3 Application port)"
else
	DISP_K2HR3_APP_PORT_EXTERNAL="${OPT_K2HR3_APP_PORT_EXTERNAL}"
fi
if [ -z "${OPT_K2HR3_APP_PORT_PRIVATE}" ]; then
	DISP_K2HR3_APP_PORT_PRIVATE="(empty: using K2HR3 Application port)"
else
	DISP_K2HR3_APP_PORT_PRIVATE="${OPT_K2HR3_APP_PORT_PRIVATE}"
fi
if [ -z "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
	DISP_K2HR3_APP_HOST_EXTERNAL="(empty: using K2HR3 Application host instead)"
else
	DISP_K2HR3_APP_HOST_EXTERNAL="${OPT_K2HR3_APP_HOST_EXTERNAL}"
fi
if [ -z "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
	DISP_K2HR3_APP_HOST_PRIVATE="(empty: using K2HR3 Application host instead)"
else
	DISP_K2HR3_APP_HOST_PRIVATE="${OPT_K2HR3_APP_HOST_PRIVATE}"
fi
if [ -z "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
	DISP_K2HR3_API_PORT_EXTERNAL="(empty: using K2HR3 REST API port)"
else
	DISP_K2HR3_API_PORT_EXTERNAL="${OPT_K2HR3_API_PORT_EXTERNAL}"
fi
if [ -z "${OPT_K2HR3_API_PORT_PRIVATE}" ]; then
	DISP_K2HR3_API_PORT_PRIVATE="(empty: using K2HR3 REST API port)"
else
	DISP_K2HR3_API_PORT_PRIVATE="${OPT_K2HR3_API_PORT_PRIVATE}"
fi
if [ -z "${OPT_K2HR3_API_HOST_EXTERNAL}" ]; then
	DISP_K2HR3_API_HOST_EXTERNAL="(empty: using K2HR3 REST API host instead)"
else
	DISP_K2HR3_API_HOST_EXTERNAL="${OPT_K2HR3_API_HOST_EXTERNAL}"
fi
if [ -z "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then
	DISP_K2HR3_API_HOST_PRIVATE="(empty: using K2HR3 REST API host instead)"
else
	DISP_K2HR3_API_HOST_PRIVATE="${OPT_K2HR3_API_HOST_PRIVATE}"
fi

#
# Check PROXY environments and Make strings for display
#
if [ -n "${HTTP_PROXY}" ] && [ -z "${http_proxy}" ]; then
	http_proxy="${HTTP_PROXY}"
	export http_proxy
elif [ -z "${HTTP_PROXY}" ] && [ -n "${http_proxy}" ]; then
	HTTP_PROXY="${http_proxy}"
	export HTTP_PROXY
fi
if [ -n "${HTTPS_PROXY}" ] && [ -z "${https_proxy}" ]; then
	https_proxy="${HTTPS_PROXY}"
	export https_proxy
elif [ -z "${HTTPS_PROXY}" ] && [ -n "${https_proxy}" ]; then
	HTTPS_PROXY="${https_proxy}"
	export HTTPS_PROXY
fi
if [ -n "${NO_PROXY}" ] && [ -z "${no_proxy}" ]; then
	no_proxy="${NO_PROXY}"
	export no_proxy
elif [ -z "${NO_PROXY}" ] && [ -n "${no_proxy}" ]; then
	NO_PROXY="${no_proxy}"
	export NO_PROXY
fi
if [ -z "${HTTP_PROXY}" ]; then
	DISP_HTTP_PROXY="(empty)"
else
	DISP_HTTP_PROXY="${HTTP_PROXY}"
fi
if [ -z "${HTTPS_PROXY}" ]; then
	DISP_HTTPS_PROXY="(empty)"
else
	DISP_HTTPS_PROXY="${HTTPS_PROXY}"
fi
if [ -z "${NO_PROXY}" ]; then
	DISP_NO_PROXY="(empty)"
else
	DISP_NO_PROXY="${NO_PROXY}"
fi

#
# Print messages
#
echo "${CGRN}-----------------------------------------------------------${CDEF}"
echo "${CGRN}Options${CDEF}"
echo "${CGRN}-----------------------------------------------------------${CDEF}"
echo "OpenStack(keystone) Region:      ${OPT_OPENSTACK_REGION}"
echo "OpenStack keystone URL:          ${OPT_KEYSTONE_URL}"
echo "Execution user name:             ${OPT_RUNUSER}"
echo ""
echo "CHMPX server port:               ${OPT_CHMPX_SERVER_PORT}"
echo "CHMPX server control port:       ${OPT_CHMPX_SERVER_CTLPORT}"
echo "CHMPX slave port:                ${OPT_CHMPX_SLAVE_CTLPORT}"
echo ""
echo "K2HR3 Application port:          ${OPT_K2HR3_APP_PORT}"
echo "K2HR3 Application external port: ${DISP_K2HR3_APP_PORT_EXTERNAL}"
echo "K2HR3 Application private port:  ${DISP_K2HR3_APP_PORT_PRIVATE}"
echo "K2HR3 Application host:          ${OPT_K2HR3_APP_HOST}"
echo "K2HR3 Application external host: ${DISP_K2HR3_APP_HOST_EXTERNAL}"
echo "K2HR3 Application private host:  ${DISP_K2HR3_APP_HOST_PRIVATE}"
echo ""
echo "K2HR3 REST API port:             ${OPT_K2HR3_API_PORT}"
echo "K2HR3 REST API external port:    ${DISP_K2HR3_API_PORT_EXTERNAL}"
echo "K2HR3 REST API private port:     ${DISP_K2HR3_API_PORT_PRIVATE}"
echo "K2HR3 REST API host:             ${OPT_K2HR3_API_HOST}"
echo "K2HR3 REST API external host:    ${DISP_K2HR3_API_HOST_EXTERNAL}"
echo "K2HR3 REST API private host:     ${DISP_K2HR3_API_HOST_PRIVATE}"
echo ""
echo "HTTP_PROXY Environment:          ${DISP_HTTP_PROXY}"
echo "HTTPS_PROXY Environment:         ${DISP_HTTPS_PROXY}"
echo "NO_PROXY Environment:            ${DISP_NO_PROXY}"

if [ "${OPT_NO_COMFIRMATION}" != "yes" ]; then
	IS_LOOP=1
	while [ "${IS_LOOP}" -eq 1 ]; do
		printf "%s" "${CREV}[INPUT]${CDEF} Do you want to continue? [yes(y)/no(n)]: "
		read -r CONFIRM_DATA

		if [ -z "${CONFIRM_DATA}" ]; then
			PRNERR "The input data must be \"yes(y)\" or \"no(n)\"."
		elif [ "${CONFIRM_DATA}" = "Y" ] || [ "${CONFIRM_DATA}" = "y" ] || [ "${CONFIRM_DATA}" = "YES" ] || [ "${CONFIRM_DATA}" = "yes" ]; then
			IS_LOOP=0
			echo ""
		elif [ "${CONFIRM_DATA}" = "N" ] || [ "${CONFIRM_DATA}" = "n" ] || [ "${CONFIRM_DATA}" = "NO" ] || [ "${CONFIRM_DATA}" = "no" ]; then
			PRNINFO "Terminate this process."
			exit 0
		else
			PRNERR "The input data must be \"yes(y)\" or \"no(n)\"."
		fi
	done
fi

#==========================================================
# Set variables and Install packages
#==========================================================
PRNTITLE "Set variables and Install packages"

#
# Whoami
#
CUR_USER_NAME=$(id -u -n)

if [ "${CUR_USER_NAME}" != "root" ]; then
	SUDO_PREFIX_CMD="sudo"
else
	SUDO_PREFIX_CMD=""
fi

#
# Home directory permission
#
/bin/sh -c "${SUDO_PREFIX_CMD} chmod +rx ${HOME}"

#
# Set PROXY environments to sudoers
#
if [ -n "${HTTP_PROXY}" ] || [ -n "${HTTPS_PROXY}" ] || [ -n "${NO_PROXY}" ]; then
	if ! /bin/sh -c "${SUDO_PREFIX_CMD} grep '^Defaults' /etc/sudoers" | grep env_keep | grep -q -i -e HTTP_PROXY -e HTTPS_PROXY -e no_proxy; then
		#
		# Need to add proxy environments to sudoers
		#
		PRNMSG "Set PROXY environments to sudoers"
		if ! echo 'Defaults    env_keep += "no_proxy NO_PROXY https_proxy http_proxy HTTPS_PROXY HTTP_PROXY"' | /bin/sh -c "${SUDO_PREFIX_CMD} tee -a /etc/sudoers" >/dev/null; then
			PRNERR "Failed to set PROXY environments to sudoers"
			exit 1
		fi
		PRNINFO "Succeed to set PROXY environments to sudoers"
	fi
fi

#
# Check OS type and Set variables/repositories
#
_OS_ID=$(grep '^ID=' /etc/os-release | sed -e 's/ID=//g' -e 's/"//g')

if echo "${_OS_ID}" | grep -q -i 'centos'; then
	PKG_INSTALLER="yum"
	PACKAGECLOUD_URL="https://packagecloud.io/install/repositories/antpickax/stable/script.rpm.sh"
	NODJS_SETUP_URL="https://rpm.nodesource.com/setup_18.x"

	K2HDKC_DEV_PACKAGE="k2hdkc-devel k2htpdtor"

	#
	# Update package cache
	#
	PRNMSG "Update package cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} update -y -q" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update package cache"
		exit 1
	fi
	PRNINFO "Succeed to update package cache"

	#
	# Setup epel repository
	#
	PRNMSG "Setup OS package repositories(epel)"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y epel-release" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install epel repository"
		exit 1
	fi
	PRNINFO "Succeed to setup OS package repositories(epel)"

elif echo "${_OS_ID}" | grep -q -i 'fedora'; then
	PKG_INSTALLER="dnf"
	PACKAGECLOUD_URL="https://packagecloud.io/install/repositories/antpickax/stable/script.rpm.sh"
	NODJS_SETUP_URL="https://rpm.nodesource.com/setup_18.x"

	K2HDKC_DEV_PACKAGE="k2hdkc-devel k2htpdtor"

	#
	# Cleanup OS package repository cache
	#
	PRNMSG "Cleanup OS package repository cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} clean all" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install epel repository"
		exit 1
	fi
	PRNINFO "Succeed to cleanup OS package repository cache"

	#
	# Update package cache
	#
	PRNMSG "Update package cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} update -y -q" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update package cache"
		exit 1
	fi
	PRNINFO "Succeed to update package cache"

elif echo "${_OS_ID}" | grep -q -i 'rocky'; then
	PKG_INSTALLER="dnf"
	PACKAGECLOUD_URL="https://packagecloud.io/install/repositories/antpickax/stable/script.rpm.sh"
	NODJS_SETUP_URL="https://rpm.nodesource.com/setup_18.x"

	K2HDKC_DEV_PACKAGE="k2hdkc-devel k2htpdtor"

	#
	# Cleanup OS package repository cache
	#
	PRNMSG "Cleanup OS package repository cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} clean all" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install epel repository"
		exit 1
	fi
	PRNINFO "Succeed to cleanup OS package repository cache"

	#
	# Update package cache
	#
	PRNMSG "Update package cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} update -y -q" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update package cache"
		exit 1
	fi
	PRNINFO "Succeed to update package cache"

	#
	# Setup epel/crb/powertools repository
	#
	PRNMSG "Setup OS package repositories(epel/CRB/powrtools)"

	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y 'dnf-command(config-manager)'" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install dnf-command(config-manager)"
		exit 1
	fi

	_MAJOR_VERSION=$(grep '^VERSION_ID=' /etc/os-release | sed -e 's/VERSION_ID=//g' -e 's/"//g' -e 's/\..*//g')
	if [ -n "${_MAJOR_VERSION}" ] && [ "${_MAJOR_VERSION}" -eq 9 ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to install epel repository"
			exit 1
		fi
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} config-manager --enable epel" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to enable epel repository"
			exit 1
		fi
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} config-manager --enable crb" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to enable CRB repository"
			exit 1
		fi

	elif [ -n "${_MAJOR_VERSION}" ] && [ "${_MAJOR_VERSION}" -eq 8 ]; then
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to install epel repository"
			exit 1
		fi
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} config-manager --enable epel" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to enable epel repository"
			exit 1
		fi
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} config-manager --enable powertools" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to enable powertools repository"
			exit 1
		fi
	else
		PRNERR "Not support RockyLinux version(${_MAJOR_VERSION})."
		exit 1
	fi
	PRNINFO "Succeed to setup OS package repositories(epel/CRB/powrtools)"

elif echo "${_OS_ID}" | grep -q -i 'ubuntu'; then
	PKG_INSTALLER="apt-get"
	PACKAGECLOUD_URL="https://packagecloud.io/install/repositories/antpickax/stable/script.deb.sh"
	NODJS_SETUP_URL="https://deb.nodesource.com/setup_18.x"

	K2HDKC_DEV_PACKAGE="k2hdkc-dev k2htpdtor"

	#
	# Update package cache
	#
	PRNMSG "Update package cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} update -y -q" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update package cache"
		exit 1
	fi
	PRNINFO "Succeed to update package cache"

elif echo "${_OS_ID}" | grep -q -i 'debian'; then
	PKG_INSTALLER="apt-get"
	PACKAGECLOUD_URL="https://packagecloud.io/install/repositories/antpickax/stable/script.deb.sh"
	NODJS_SETUP_URL="https://deb.nodesource.com/setup_18.x"

	K2HDKC_DEV_PACKAGE="k2hdkc-dev k2htpdtor"

	#
	# Update package cache
	#
	PRNMSG "Update package cache"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} update -y -q" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to update package cache"
		exit 1
	fi
	PRNINFO "Succeed to update package cache"

else
	PRNERR "OS ID(${_OS_ID}) is not supported."
	exit 1
fi

#
# Setup packaagecloud.io repository
#
PRNMSG "Setup packaagecloud.io repository"
if ({ /bin/sh -c "curl -s ${PACKAGECLOUD_URL} | ${SUDO_PREFIX_CMD} -E bash -" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to setup packaagecloud.io repository"
	exit 1
fi
PRNINFO "Succeed to setup packaagecloud.io repository"

#
# Install base packages
#
if echo "${_OS_ID}" | grep -q -i -e 'centos' -e 'fedora' -e 'rocky'; then
	#
	# Install packages for build
	#
	PRNMSG "Install Development Tools packages"
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} groupinstall -y 'Development Tools'" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install Development Tools packages"
		exit 1
	fi
	PRNINFO "Succeed to install Development Tools packages"

else	# ubuntu or debian
	#
	# Install packages for build
	#
	if ! dpkg -l | grep -q -i 'build-essential'; then
		PRNMSG "Install build-essential packages"
		if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y build-essential" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Failed to install build-essential packages"
			exit 1
		fi
		PRNINFO "Succeed to install build-essential packages"
	fi
fi

#
# Upgrade NodeJS
#
PRNMSG "Upgrade NodeJS"
if ({ /bin/sh -c "curl -sL ${NODJS_SETUP_URL} | ${SUDO_PREFIX_CMD} -E bash -" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to upgrade NodeJS"
	exit 1
fi
PRNINFO "Succeed to upgrade NodeJS"

#
# Install nodejs packages
#
PRNMSG "Install nodejs packages"
if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y nodejs" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to install nodejs packages"
	exit 1
fi
PRNINFO "Succeed to install nodejs packages"

#
# Set configuarion for npm
#
PRNMSG "Set configuarion for npm"

if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set registry http://registry.npmjs.org/" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to set registory to npm configuration"
	exit 1
fi
if [ -n "${HTTP_PROXY}" ]; then
	if echo "${HTTP_PROXY}" | grep -q '^http.*://'; then
		NPM_HTTP_PROXY="${HTTP_PROXY}"
	else
		NPM_HTTP_PROXY="http://${HTTP_PROXY}"
	fi
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set proxy ${NPM_HTTP_PROXY}" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to set proxy to npm configuration"
		exit 1
	fi
fi
if [ -n "${HTTPS_PROXY}" ]; then
	if echo "${HTTPS_PROXY}" | grep -q '^http.*://'; then
		NPM_HTTPS_PROXY="${HTTPS_PROXY}"
	else
		NPM_HTTPS_PROXY="http://${HTTPS_PROXY}"
	fi
	if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set https-proxy ${NPM_HTTPS_PROXY}" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to set https-proxy to npm configuration"
		exit 1
	fi
fi
if ({ /bin/sh -c "${SUDO_PREFIX_CMD} npm -g config set registry http://registry.npmjs.org/" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to set registory to npm configuration"
	exit 1
fi
PRNINFO "Succeed to set configuarion for npm"

#
# Install K2HDKC/etc packages
#
PRNMSG "Install ${K2HDKC_DEV_PACKAGE} packages"
if ({ /bin/sh -c "${SUDO_PREFIX_CMD} ${PKG_INSTALLER} install -y ${K2HDKC_DEV_PACKAGE}" || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Failed to install ${K2HDKC_DEV_PACKAGE} packages"
	exit 1
fi
PRNINFO "Succeed to install ${K2HDKC_DEV_PACKAGE} packages"

PRNSUCCESS "Set variables and Install packages"

#==========================================================
# Generate configurations
#==========================================================
PRNTITLE "Generate configurations"

cd "${SRCTOP}" || exit 1

#----------------------------------------------------------
# Generate CHMPX configurations
#----------------------------------------------------------
PRNMSG "Generate CHMPX configurations"

#
# Set directories
#
if ! /bin/sh -c "${SUDO_PREFIX_CMD} mkdir -p ${SRCTOP}/log"		|| \
   ! /bin/sh -c "${SUDO_PREFIX_CMD} mkdir -p ${SRCTOP}/data"	|| \
   ! /bin/sh -c "${SUDO_PREFIX_CMD} chmod 0777 ${SRCTOP}/log"	|| \
   ! /bin/sh -c "${SUDO_PREFIX_CMD} chmod 0777 ${SRCTOP}/data"; then

	PRNERR "Failed to setup ${SRCTOP}/{log, data} directories."
	exit 1
fi

#
# Set msg_max
#
if ! echo 512 | /bin/sh -c "${SUDO_PREFIX_CMD} tee -a /proc/sys/fs/mqueue/msg_max" >/dev/null; then
	PRNWARN "Could not set msg_max to 512, but continue..."
else
	MSG_MAX_VALUE=$(cat /proc/sys/fs/mqueue/msg_max)
	if [ "${MSG_MAX_VALUE}" -lt 512 ]; then
		PRNWARN "Could not set msg_max to 512, but continue..."
	fi
fi

#
# Create server.ini/slave.ini
#
CURRENT_TIME=$(date -R)

if ! sed -e "s/__DATE__/${CURRENT_TIME}/g" -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__MODE_SETTING__/MODE\t\t\t= SERVER\nPORT\t\t\t= ${OPT_CHMPX_SERVER_PORT}\nCTLPORT\t\t\t= ${OPT_CHMPX_SERVER_CTLPORT}\nSELFCTLPORT\t\t= ${OPT_CHMPX_SERVER_CTLPORT}\n/g" -e "s/__SERVER_PORT__/${OPT_CHMPX_SERVER_PORT}/g" -e "s/__SERVER_CTLPORT__/${OPT_CHMPX_SERVER_CTLPORT}/g" -e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g" "${SRCTOP}"/conf/config.templ > "${SRCTOP}"/conf/server.ini; then
	PRNERR "Could not create(copy) server.ini configuration file."
	exit 1
fi
if ! sed -e "s/__DATE__/${CURRENT_TIME}/g" -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__MODE_SETTING__/MODE\t\t\t= SLAVE\nCTLPORT\t\t\t= ${OPT_CHMPX_SLAVE_CTLPORT}\nSELFCTLPORT\t\t= ${OPT_CHMPX_SLAVE_CTLPORT}/g" -e "s/__SERVER_PORT__/${OPT_CHMPX_SERVER_PORT}/g" -e "s/__SERVER_CTLPORT__/${OPT_CHMPX_SERVER_CTLPORT}/g" -e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g" "${SRCTOP}"/conf/config.templ > "${SRCTOP}"/conf/slave.ini; then
	PRNERR "Could not create(copy) slave.ini configuration file."
	exit 1
fi
PRNINFO "Succeed to generate CHMPX configurations"

#----------------------------------------------------------
# Check and Make variables
#----------------------------------------------------------
#
# Host lists
#
TMP_K2HR3_APP_HOSTS=""
TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST=""
if [ "${OPT_K2HR3_APP_HOST}" != "localhost" ]; then
	TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST="'localhost'"
fi
if [ -n "${TMP_K2HR3_APP_HOSTS}" ]; then
	TMP_K2HR3_APP_HOSTS="'${TMP_K2HR3_APP_HOSTS}'"
	TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST="${TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST},\n\t\t'${OPT_K2HR3_APP_HOST}'"
fi
if [ -n "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
	TMP_K2HR3_APP_HOSTS="${TMP_K2HR3_APP_HOSTS},\n\t\t'${OPT_K2HR3_APP_HOST_EXTERNAL}'"
	TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST="${TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST},\n\t\t'${OPT_K2HR3_APP_HOST_EXTERNAL}'"
fi
if [ -n "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
	TMP_K2HR3_APP_HOSTS="${TMP_K2HR3_APP_HOSTS},\n\t\t'${OPT_K2HR3_APP_HOST_PRIVATE}'"
	TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST="${TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST},\n\t\t'${OPT_K2HR3_APP_HOST_PRIVATE}'"
fi

#
# Providing defaults for unset values
#
if [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
	TMP_K2HR3_API_PORT_EXT="${OPT_K2HR3_API_PORT_EXTERNAL}"
else
	TMP_K2HR3_API_PORT_EXT="${OPT_K2HR3_API_PORT}"
fi
if [ -n "${OPT_K2HR3_API_PORT_PRIVATE}" ]; then
	TMP_K2HR3_API_PORT_PRI="${OPT_K2HR3_API_PORT_PRIVATE}"
else
	TMP_K2HR3_API_PORT_PRI="${OPT_K2HR3_API_PORT}"
fi
if [ -n "${OPT_K2HR3_API_HOST_EXTERNAL}" ]; then
	TMP_K2HR3_API_HOST_EXT="${OPT_K2HR3_API_HOST_EXTERNAL}"
else
	TMP_K2HR3_API_HOST_EXT="${OPT_K2HR3_API_HOST}"
fi
if [ -n "${OPT_K2HR3_API_HOST_PRIVATE}" ]; then
	TMP_K2HR3_API_HOST_PRI="${OPT_K2HR3_API_HOST_PRIVATE}"
else
	TMP_K2HR3_API_HOST_PRI="${OPT_K2HR3_API_HOST}"
fi
if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
	TMP_K2HR3_APP_PORT_EXT="${OPT_K2HR3_APP_PORT_EXTERNAL}"
else
	TMP_K2HR3_APP_PORT_EXT="${OPT_K2HR3_APP_PORT}"
fi
if [ -n "${OPT_K2HR3_APP_PORT_PRIVATE}" ]; then
	TMP_K2HR3_APP_PORT_PRI="${OPT_K2HR3_APP_PORT_PRIVATE}"
else
	TMP_K2HR3_APP_PORT_PRI="${OPT_K2HR3_APP_PORT}"
fi
if [ -n "${OPT_K2HR3_APP_HOST_EXTERNAL}" ]; then
	TMP_K2HR3_APP_HOST_EXT="${OPT_K2HR3_APP_HOST_EXTERNAL}"
else
	TMP_K2HR3_APP_HOST_EXT="${OPT_K2HR3_APP_HOST}"
fi
if [ -n "${OPT_K2HR3_APP_HOST_PRIVATE}" ]; then
	TMP_K2HR3_APP_HOST_PRI="${OPT_K2HR3_APP_HOST_PRIVATE}"
else
	TMP_K2HR3_APP_HOST_PRI="${OPT_K2HR3_APP_HOST}"
fi

#----------------------------------------------------------
# Setup K2HR3 API
#----------------------------------------------------------
PRNMSG "Setup K2HR3 API"

cd "${SRCTOP}" || exit 1

#
# Get K2HR3 API Archive and Expand it
#
if ({ npm pack k2hr3-api 2>&1 || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Could not get k2hr3-api npm package archive"
	exit 1
fi
if ! tar xvfz k2hr3-api*.tgz >/dev/null 2>&1; then
	PRNERR "Could not decompress k2hr3-api npm package archive"
	exit 1
fi
if [ ! -d package ]; then
	PRNERR "Could not find \"package\" directory"
	exit 1
fi
if ! mv package k2hr3-api; then
	PRNERR "Could not rename directory from \"package\" to \"k2hr3-api\""
	exit 1
fi
PRNINFO "Succeed to get K2HR3 API archive and expand it"

#
# Install dependency packages for K2HR3 API
#
cd k2hr3-api || exit 1

if ({ npm install 2>&1 || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	#
	# It rarely fails, but sometimes retrying succeeds
	#
	sleep 5
	if ({ npm install || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install dependency packages for k2hr3-api"
		exit 1
	fi
fi
PRNINFO "Succeed to install dependency packages for K2HR3 API"

#
# Check and Make variables for production.json
#
if [ -f "${SRCTOP}"/conf/custom_production_api.templ ]; then
	PRODUCTION_JSON_TEMPL="${SRCTOP}"/conf/custom_production_api.templ
elif [ -f "${SRCTOP}"/conf/production_api.templ ]; then
	PRODUCTION_JSON_TEMPL="${SRCTOP}"/conf/production_api.templ
fi
if [ -n "${PRODUCTION_JSON_TEMPL}" ]; then
	if ! sed																\
		-e "s#__BASE_DIR__#${SRCTOP}#g"										\
		-e "s/__OS_REGION__/${OPT_OPENSTACK_REGION}/g"						\
		-e "s#__KEYSTONE_URL__#${OPT_KEYSTONE_URL}#g"						\
		-e "s/__RUNUSER__/${OPT_RUNUSER}/g"									\
		-e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g"				\
		-e "s/__K2HR3_APP_HOSTS__/${TMP_K2HR3_APP_HOSTS_WITH_LOCALHOST}/g"	\
		-e "s/__K2HR3_APP_HOST__/${OPT_K2HR3_APP_HOST}/g"					\
		-e "s/__K2HR3_APP_HOST_EXT__/${TMP_K2HR3_APP_HOST_EXT}/g"			\
		-e "s/__K2HR3_APP_HOST_PRI__/${TMP_K2HR3_APP_HOST_PRI}/g"			\
		-e "s/__K2HR3_APP_PORT__/${OPT_K2HR3_APP_PORT}/g"					\
		-e "s/__K2HR3_APP_PORT_EXT__/${TMP_K2HR3_APP_PORT_EXT}/g"			\
		-e "s/__K2HR3_APP_PORT_PRI__/${TMP_K2HR3_APP_PORT_PRI}/g"			\
		-e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g"					\
		-e "s/__K2HR3_API_HOST_EXT__/${TMP_K2HR3_API_HOST_EXT}/g"			\
		-e "s/__K2HR3_API_HOST_PRI__/${TMP_K2HR3_API_HOST_PRI}/g"			\
		-e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g"					\
		-e "s/__K2HR3_API_PORT_EXT__/${TMP_K2HR3_API_PORT_EXT}/g"			\
		-e "s/__K2HR3_API_PORT_PRI__/${TMP_K2HR3_API_PORT_PRI}/g"			\
		"${PRODUCTION_JSON_TEMPL}" > "${SRCTOP}"/k2hr3-api/config/production.json; then

		PRNERR "Could not create(copy) production.json configuration file"
		exit 1
	fi
	PRNINFO "Found ${PRODUCTION_JSON_TEMPL}. The process will be started with production.json."
else
	PRNINFO "Any production_api.templ is not existed. The process will be started without production.json."
fi

#
# Check and Make variables for k2hr3-init.sh
#
CUSTOM_INIT_TEMPL="${SRCTOP}"/conf/custom_k2hr3-init.sh.templ
if [ -f "${CUSTOM_INIT_TEMPL}" ]; then
	if ! cp "${CUSTOM_INIT_TEMPL}" "${SRCTOP}"/k2hr3-api/config/k2hr3-init.sh.templ; then
		PRNERR "Could not copy k2hr3-init.sh.templ in k2hr3_api config directory for this devpack"
		exit 1
	fi
	PRNINFO "Found ${CUSTOM_INIT_TEMPL}. The process will be started with this."
else
	PRNINFO "${CUSTOM_INIT_TEMPL} is not existed. The process will be started with default k2hr3-init.sh.templ."
fi

#
# Check and Make variables for extdata scripts
#
for _custom_extdata_templ in "${SRCTOP}"/conf/custom_*.sh.templ; do
	if [ -f "${CUSTOM_INIT_TEMPL}" ]; then
		#
		# except CUSTOM_INIT_TEMPL
		#
		if [ "${CUSTOM_INIT_TEMPL}" != "${_custom_extdata_templ}" ]; then
			#
			# copy templates with renaming it
			#
			_extdata_templ_name=$(echo "${_custom_extdata_templ}" | sed -e 's#/#\n#g' | tail -1 | sed -e 's/custom_//g')
			if ! cp "${_custom_extdata_templ}" "${SRCTOP}"/k2hr3-api/config/"${_extdata_templ_name}"; then
				PRNERR "Could not copy ${_custom_extdata_templ} to ${SRCTOP}/k2hr3-api/config/${_extdata_templ_name}"
				exit 1
			fi
			PRNINFO "Found ${_custom_extdata_templ}. It is copied to ${SRCTOP}/k2hr3-api/config/${_extdata_templ_name}."
		fi
	fi
done

#
# Change run script for pid file
#
if ! sed -e 's/\.pid/_api.pid/g' "${SRCTOP}"/k2hr3-api/bin/run.sh > "${SRCTOP}"/k2hr3-api/bin/mod_run.sh	|| \
   ! chmod +x "${SRCTOP}"/k2hr3-api/bin/mod_run.sh															|| \
   ! mv "${SRCTOP}"/k2hr3-api/bin/run.sh "${SRCTOP}"/k2hr3-api/bin/run_orig.sh								|| \
   ! mv "${SRCTOP}"/k2hr3-api/bin/mod_run.sh "${SRCTOP}"/k2hr3-api/bin/run.sh; then

	PRNERR "Could not modify run.sh for this devpack"
	exit 1
fi

#
# Create log directory
#
if ! mkdir -p "${SRCTOP}"/k2hr3-api/log		|| \
   ! chmod 0777 "${SRCTOP}"/k2hr3-api/log; then

	PRNERR "Could not create ${SRCTOP}/k2hr3-api/log directory"
	exit 1
fi

#
# for npm log directory
#
if ! chmod 0777 ~/.npm/_logs; then
	PRNERR "could not change permission ~/.npm/_logs directory"
	exit 1
fi

PRNINFO "Succeed to setup K2HR3 API"

#----------------------------------------------------------
# Setup K2HR3 APP
#----------------------------------------------------------
PRNMSG "Setup K2HR3 APP"

cd "${SRCTOP}" || exit 1

#
# Get K2HR3 APP Archive and Expand it
#
if ({ npm pack k2hr3-app 2>&1 || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	PRNERR "Could not get k2hr3-app npm package archive"
	exit 1
fi
if ! tar xvfz k2hr3-app*.tgz >/dev/null 2>&1; then
	PRNERR "Could not decompress k2hr3-app npm package archive"
	exit 1
fi
if [ ! -d package ]; then
	PRNERR "Could not find \"package\" directory"
	exit 1
fi
if ! mv package k2hr3-app; then
	PRNERR "Could not rename directory from \"package\" to \"k2hr3-app\""
	exit 1
fi
PRNINFO "Succeed to get K2HR3 APP archive and expand it"

#
# Install dependency packages for K2HR3 API
#
cd k2hr3-app || exit 1

if ({ npm install 2>&1 || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
	#
	# It rarely fails, but sometimes retrying succeeds
	#
	sleep 5
	if ({ npm install || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
		PRNERR "Failed to install dependency packages for k2hr3-app"
		exit 1
	fi
fi
PRNINFO "Succeed to install dependency packages for K2HR3 APP"

#
# Check and Make variables for production.json
#
if [ -f "${SRCTOP}"/conf/custom_production_app.templ ]; then
	PRODUCTION_JSON_TEMPL="${SRCTOP}"/conf/custom_production_app.templ
elif [ -f "${SRCTOP}"/conf/production_app.templ ]; then
	PRODUCTION_JSON_TEMPL="${SRCTOP}"/conf/production_app.templ
fi
if [ -n "${PRODUCTION_JSON_TEMPL}" ]; then
	if ! sed														\
		-e "s#__BASE_DIR__#${SRCTOP}#g"								\
		-e "s/__RUNUSER__/${OPT_RUNUSER}/g"							\
		-e "s/__K2HR3_APP_HOSTS__/${TMP_K2HR3_APP_HOSTS}/g"			\
		-e "s/__K2HR3_APP_HOST__/${OPT_K2HR3_APP_HOST}/g"			\
		-e "s/__K2HR3_APP_HOST_EXT__/${TMP_K2HR3_APP_HOST_EXT}/g"	\
		-e "s/__K2HR3_APP_HOST_PRI__/${TMP_K2HR3_APP_HOST_PRI}/g"	\
		-e "s/__K2HR3_APP_PORT__/${OPT_K2HR3_APP_PORT}/g"			\
		-e "s/__K2HR3_APP_PORT_EXT__/${TMP_K2HR3_APP_PORT_EXT}/g"	\
		-e "s/__K2HR3_APP_PORT_PRI__/${TMP_K2HR3_APP_PORT_PRI}/g"	\
		-e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g"			\
		-e "s/__K2HR3_API_HOST_EXT__/${TMP_K2HR3_API_HOST_EXT}/g"	\
		-e "s/__K2HR3_API_HOST_PRI__/${TMP_K2HR3_API_HOST_PRI}/g"	\
		-e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g"			\
		-e "s/__K2HR3_API_PORT_EXT__/${TMP_K2HR3_API_PORT_EXT}/g"	\
		-e "s/__K2HR3_API_PORT_PRI__/${TMP_K2HR3_API_PORT_PRI}/g"	\
		"${PRODUCTION_JSON_TEMPL}" > "${SRCTOP}"/k2hr3-app/config/production.json; then

		PRNERR "Could not create(copy) production.json configuration file"
		exit 1
	fi
	PRNINFO "Found ${PRODUCTION_JSON_TEMPL}. The process will be started with production.json."
else
	PRNINFO "Any production_api.templ is not existed. The process will be started without production.json."
fi

#
# Change run script for pid file
#
if ! sed -e 's/\.pid/_app.pid/g' "${SRCTOP}"/k2hr3-app/bin/run.sh > "${SRCTOP}"/k2hr3-app/bin/mod_run.sh	|| \
   ! chmod +x "${SRCTOP}"/k2hr3-app/bin/mod_run.sh															|| \
   ! mv "${SRCTOP}"/k2hr3-app/bin/run.sh "${SRCTOP}"/k2hr3-app/bin/run_orig.sh								|| \
   ! mv "${SRCTOP}"/k2hr3-app/bin/mod_run.sh "${SRCTOP}"/k2hr3-app/bin/run.sh; then

	PRNERR "Could not modify run.sh for this devpack"
	exit 1
fi

#
# Create log directory
#
if ! mkdir -p "${SRCTOP}"/k2hr3-app/log		|| \
   ! chmod 0777 "${SRCTOP}"/k2hr3-app/log; then

	PRNERR "Could not create ${SRCTOP}/k2hr3-app/log directory"
	exit 1
fi

#
# for npm log directory(maybe already set by k2hr3 api setting)
#
if ! chmod 0777 ~/.npm/_logs; then
	PRNERR "Could not change permission ~/.npm/_logs directory"
	exit 1
fi

PRNINFO "Succeed to setup K2HR3 APP"

#----------------------------------------------------------
# Create HAProxy configuration for sample
#----------------------------------------------------------
if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ] || [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
	PRNMSG "Create HAProxy configuration for sample"

	cd "${SRCTOP}" || exit 1

	if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ]; then
		HA_K2HR3_APP_PORT_EXT="${OPT_K2HR3_APP_PORT_EXTERNAL}"
	else
		HA_K2HR3_APP_PORT_EXT="${OPT_K2HR3_APP_PORT}"
	fi
	if [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
		HA_K2HR3_API_PORT_EXT="${OPT_K2HR3_API_PORT_EXTERNAL}"
	else
		HA_K2HR3_API_PORT_EXT="${OPT_K2HR3_API_PORT}"
	fi

	if ! sed -e "s/__K2HR3_APP_PORT_EXT__/${HA_K2HR3_APP_PORT_EXT}/g" -e "s/__K2HR3_APP_PORT__/${OPT_K2HR3_APP_PORT}/g" -e "s/__K2HR3_APP_HOST__/${OPT_K2HR3_APP_HOST}/g" -e "s/__K2HR3_API_PORT_EXT__/${HA_K2HR3_API_PORT_EXT}/g" -e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g" -e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g" "${SRCTOP}"/conf/haproxy_example.templ > "${SRCTOP}"/conf/haproxy_example.cfg; then
		PRNERR "Could not create HAProxy configuration sample file"
		exit 1
	fi
	PRNINFO "Succeed to create HAProxy configuration for sample"
fi

#----------------------------------------------------------
# Create README_NODE_PORT_FORWARDING file
#----------------------------------------------------------
if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ] || [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
	PRNMSG "Create README_NODE_PORT_FORWARDING file"

	cd "${SRCTOP}" || exit 1

	{
		echo '               ABOUT NODE(devstack) PORT FORWARDING'
		echo '               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
		echo ''
		echo 'Explaining the settings required for the NODE(HOST) that launched the K2HR3'
		echo "cluster built by ${PROGRAM_NAME}."
		echo ''
		echo 'This K2HR3 cluster built on a devstack cluster instance requires external'
		echo 'access to the following ports:'
		echo ''
		echo "    K2HR3 REST API         : Through ${HA_K2HR3_API_PORT_EXT} to ${OPT_K2HR3_API_PORT}"
		echo "    K2HR3 Web Application  : Through ${HA_K2HR3_APP_PORT_EXT} to ${OPT_K2HR3_APP_PORT}"
		echo ''
		echo 'You can access these ports externally by adding/configuring a security group'
		echo 'and starting HAProxy.'
		echo ''
		echo 'The settings from the command line(CLI) are explained below:'
		echo ''
		echo '(1) Openstack environment'
		echo '    You need to use the openstack command to create a security group, so'
		echo '    please set related environment variables such as OS_XXXX in advance.'
		echo ''
		echo '    [NOTE]'
		echo '    You can download the RC file using Openstack GUI (Horizon), so you'
		echo '    can easily set environment variables using it.'
		echo ''
		echo ''
		echo '(2) Security Group'
		echo '    Add the security group for the instance launched this K2HR3 cluster.'
		echo ''
		echo '    First, create a security group:'
		echo ''
		echo '      openstack security group create <security group name: ex. k2hr3-devstack>'
		echo ''
		echo '    Next, set port control for K2HR3 REST API and K2HR3 Web Application to'
		echo '    the above security group:'
		echo ''
		echo "      openstack security group rule create --remote-ip 0.0.0.0/0 --protocol tcp --ingress --ethertype IPv4 --project <project id> --dst-port ${OPT_K2HR3_API_PORT} --description K2HR3-APP-ingress <security group name: ex. k2hr3-devstack>"
		echo "      openstack security group rule create --remote-ip 0.0.0.0/0 --protocol tcp --ingress --ethertype IPv4 --project <project id> --dst-port ${OPT_K2HR3_APP_PORT} --description K2HR3-API-ingress <security group name: ex. k2hr3-devstack>"
		echo ''
		echo '    Finally, add the security group you created to the instance:'
		echo ''
		echo '      openstack server add security group <server id> <security group id>'
		echo ''
		echo '    [NOTE]'
		echo '    If you have decided on the port number before starting the instance, you'
		echo '    can eliminate these steps by creating a security group in advance and'
		echo '    setting it in the instance to be started.'
		echo '    Or, you can also configure using the Openstack GUI(Horizon).'
		echo ''
		echo '(3) HAProxy'
		echo '    Start HAProxy on the NODE(HOST) running devstack and make the K2HR3'
		echo '    cluster accessible from outside the NODE.'
		echo ''
		echo "    This tool (${PROGRAM_NAME}) has created a sample configuration file for"
		echo '    HAProxy, so please copy it to the NODE host.'
		echo ''
		echo "      Sample : ${SRCTOP}/conf/haproxy_example.cfg"
		echo ''
		echo '    Start HAProxy by specifying this configuration file on NODE:'
		echo ''
		echo '      haproxy -f <configuration file> &'
		echo ''
		echo 'Now you can access this K2HR3 cluster you have built from the outside using'
		echo 'the following port:'
		echo ''
		echo "    K2HR3 REST API         : http://<node host>:${HA_K2HR3_API_PORT_EXT}/"
		echo "    K2HR3 Web Application  : http://<node host>:${HA_K2HR3_APP_PORT_EXT}/"
		echo ''
	} > "${SRCTOP}"/conf/README_NODE_PORT_FORWARDING

	PRNINFO "Succeed to create README_NODE_PORT_FORWARDING file"
fi

PRNSUCCESS "Generate configurations"

#==========================================================
# Run all processes
#==========================================================
PRNTITLE "Run all processes"

cd "${SRCTOP}" || exit 1

#
# Run CHMPX Server node
#
PRNMSG "Run CHMPX server node"

# shellcheck disable=SC2024
sudo -u "${OPT_RUNUSER}" chmpx -conf "${SRCTOP}"/conf/server.ini -d err >> "${SRCTOP}"/log/chmpx_server.log 2>&1 &
if ! wait_process_running "chmpx" "server.ini" 20 3; then
	PRNERR "Could not run chmpx server node"
	exit 1
fi
PRNINFO "Succeed to run CHMPX server node"

#
# Run K2HDKC processe
#
PRNMSG "Run K2HDKC server process"

# shellcheck disable=SC2024
sudo -u "${OPT_RUNUSER}" k2hdkc -conf "${SRCTOP}"/conf/server.ini -d err >> "${SRCTOP}"/log/k2hdkc.log 2>&1 &
if ! wait_process_running "k2hdkc" "server.ini" 20 3; then
	PRNERR "Could not run k2hdkc server process"
	exit 1
fi
PRNINFO "Succeed to run K2HDKC server process"

#
# Run CHMPX Slave node
#
PRNMSG "Run CHMPX slave node"

# shellcheck disable=SC2024
sudo -u "${OPT_RUNUSER}" chmpx -conf "${SRCTOP}"/conf/slave.ini -d err >> "${SRCTOP}"/log/chmpx_slave.log 2>&1 &
if ! wait_process_running "chmpx" "slave.ini" 20 3; then
	PRNERR "Could not run chmpx slave node"
	exit 1
fi
PRNINFO "Succeed to run CHMPX slave node"

#
# The chmpx processes have started but may take some time to initialize
#
sleep 20

#----------------------------------------------------------
# [NOTE]
# When k2hr3_api and k2hr3_app starts the node process, it gets the
# execution user from config and executes setuid.
# Then we want to start Nodejs as nobody to support it, but we can't
# run the npm command with root privileges using sudo.
# So run npm here as "sudo -u nobody", it run npm as nobody user
# instead of root directly.
#----------------------------------------------------------
#
# Run K2HR3 REST API
#
PRNMSG "Run K2HR3 REST API"
cd "${SRCTOP}"/k2hr3-api || exit 1

sudo -u "${OPT_RUNUSER}" npm run start 2>&1 | sed -e 's|^|    |g'
if ! wait_process_running "www" "k2hr3-api" 20 3; then
	PRNERR "Could not run k2hr3-api node process"
	exit 1
fi
PRNINFO "Succeed to run K2HR3 REST API"

#
# Run K2HR3 APP
#
PRNMSG "Run K2HR3 APP"
cd "${SRCTOP}"/k2hr3-app || exit 1

sudo -u "${OPT_RUNUSER}" npm run start 2>&1 | sed -e 's|^|    |g'
if ! wait_process_running "www" "k2hr3-app" 20 3; then
	PRNERR "Could not run k2hr3-app node process"
	exit 1
fi
PRNINFO "Succeed to run K2HR3 APP"

PRNSUCCESS "Run all processes"

#==========================================================
# Finish
#==========================================================
cd "${SRCTOP}" || exit 1

#
# Last check
#
# shellcheck disable=SC2009
BIN_PROCESSES=$(ps ax | grep -v grep | grep -e chmpx -e k2hdkc | grep -v -c '\-u nobody')
# shellcheck disable=SC2009
API_PROCESSES=$(ps ax | grep -v grep | grep -c 'k2hr3-api/bin/www')
# shellcheck disable=SC2009
APP_PROCESSES=$(ps ax | grep -v grep | grep -c 'k2hr3-app/bin/www')
if [ "${BIN_PROCESSES}" -ne 3 ] || [ "${API_PROCESSES}" -le 0 ] || [ "${APP_PROCESSES}" -le 0 ]; then
	PRNWARN "Some important processes could not be started yet."
fi

#
# Succeed
#
echo ""
echo "${CGRN}-----------------------------------------------------------${CDEF}"
echo "${CGRN}Launched K2HR3 cluster as devpack completed${CDEF}"
echo "${CGRN}-----------------------------------------------------------${CDEF}"
# shellcheck disable=SC2009
ps ax | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www' | sed -e 's#^#    #g'

if [ -n "${OPT_K2HR3_APP_PORT_EXTERNAL}" ] || [ -n "${OPT_K2HR3_API_PORT_EXTERNAL}" ]; then
	echo "--------------------------------------------------"
	echo "${CYEL}[NOTE]${CDEF}"
	echo "If you build K2HR3 on an instance launched on devstack, you"
	echo "will need to perform port forwarding to access the K2HR3"
	echo "system from the outside."
	echo ""
	echo "You can check its settings by browsing the memo file:"
	echo "    ${CGRN}${SRCTOP}/conf/README_NODE_PORT_FORWARDING${CDEF}"
	echo ""
	echo "Once configured, you can access the K2HR3 system using the"
	echo "URL below:"
	echo "    K2HR3 REST API         : ${CGRN}http://<node host>:${HA_K2HR3_API_PORT_EXT}/${CDEF}"
	echo "    K2HR3 Web Application  : ${CGRN}http://<node host>:${HA_K2HR3_APP_PORT_EXT}/${CDEF}"
	echo ""
fi

echo "--------------------------------------------------"
echo ""
echo "${CGRN}All K2HR3 cluster processes has been run.${CDEF}"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
