#!/bin/sh
#
# K2HR3 DevPack in K2HR3 Utilities
#
# Copyright 2020 Yahoo! Japan Corporation.
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

#----------------------------------------------------------
# Environments
#----------------------------------------------------------
CMDLINE_PROCESS_NAME=$0
PROGRAM_NAME=`basename ${CMDLINE_PROCESS_NAME}`
SCRIPTPATH=`dirname ${CMDLINE_PROCESS_NAME}`
BINDIR=`cd ${SCRIPTPATH}; pwd`
SRCTOP=`cd ${SCRIPTPATH}/..; pwd`
CURRENT_TIME=`date -R`

#
# Escape sequence
#
CDEF=$(printf '\033[0m')
CREV=$(printf '\033[7m')
CRED=$(printf '\033[31m')
CGRN=$(printf '\033[32m')

#----------------------------------------------------------
# Options
#----------------------------------------------------------
func_usage()
{
	#
	# $1:	Program name
	#
	echo ""
	echo "Usage:  $1 [--no_interaction(-ni)] [--no_confirmation(-nc)] [--run_user(-ru) <user name>] [--server_port(-svrp) <number>]"
	echo "        [--server_ctlport(-svrcp) <number>] [--slave_ctlport(-slvcp) <number>] [--keystone_url(-ks) <url string>]"
	echo "        [--app_port(-appp) <number>] [--app_port_external(-apppe) <number>]"
	echo "        [--app_host(-apph) <hostname or ip>] [--app_host_external(-apphe) <hostname or ip>]"
	echo "        [--api_port(-apip) <number>] [--api_port_external(-apipe) <number>]"
	echo "        [--api_host(-apih) <hostname or ip>] [--api_host_external(-apihe) <hostname or ip>]"
	echo "        [--help(-h)]"
	echo ""
	echo "        --no_interaction(-ni)         Turn off interactive mode for unspecified option input and use default value"
	echo "        --run_user(-ru)               Specify the execution user of each process"
	echo "        --server_port(-svrp)          Specify CHMPX server node process port"
	echo "        --server_ctlport(-svrcp)      Specify CHMPX server node process control port"
	echo "        --slave_ctlport(-slvcp)       Specify CHMPX slave node process control port"
	echo "        --openstack_region(-osr)      Specify OpenStack(Keystone) Region(ex: RegionOne)"
	echo "        --keystone_url(-ks)           Specify OpenStack Keystone URL(ex: https://dummy.keystone.openstack/)"
	echo "        --app_port(-appp)             Specify K2HR3 Application port"
	echo "        --app_port_external(-apppe)   Specify K2HR3 Application external port(optional: specify when using a proxy)"
	echo "        --app_host(-apph)             Specify K2HR3 Application host"
	echo "        --app_host_external(-apphe)   Specify K2HR3 Application external host(optional: host as javascript download server)"
	echo "        --api_port(-apip)             Specify K2HR3 REST API port"
	echo "        --api_port_external(-apipe)   Specify K2HR3 REST API external port(optional: specify when using a proxy)"
	echo "        --api_host(-apih)             Specify K2HR3 REST API host"
	echo "        --api_host_external(-apihe)   Specify K2HR3 REST API external host(optional: specify when using a proxy)"
	echo "        --yes(-y)                     Specified when you do not want confirmation"
	echo "        --help(-h)                    print help"
	echo ""
}

#
# Utility Function for input
#
input_interaction()
{
	#
	# $1:	Input Message(puts stderr)
	# $2:	Input data type is number = yes(1)/no(0)
	# $3:	Whether to allow empty = yes(1)/no(0, empty)
	#
	INPUT_MSG=$1
	if [ "X$2" = "Xyes" -o  "X$2" = "XYES" -o "X$2" = "X1" ]; then
		IS_NUMBER=1
	else
		IS_NUMBER=0
	fi
	if [ "X$3" = "Xyes" -o  "X$3" = "XYES" -o "X$3" = "X1" ]; then
		IS_ALLOW_EMPTY=1
	else
		IS_ALLOW_EMPTY=0
	fi

	while true; do
		echo -n "${INPUT_MSG} : " 1>&2
		read INPUT_DATA

		if [ "X${INPUT_DATA}" = "X" ]; then
			if [ ${IS_ALLOW_EMPTY} -eq 1 ]; then
				break;
			else
				echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Not allow to input empty.${CDEF}" 1>&2
			fi
		else
			if [ ${IS_NUMBER} -ne 1 ]; then
				break;
			else
				expr "${INPUT_DATA}" + 1 >/dev/null 2>&1
				if [ $? -ge 2 ]; then
					echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The input data must be number.${CDEF}" 1>&2
				else
					break;
				fi
			fi
		fi
	done

	echo ${INPUT_DATA}
}

#
# Utility Function for waiting processes up
#
wait_process_running()
{
	#
	# $1:	Process name for waiting
	# $2:	String for filtering the result of ps command
	# $3:	Unit wait time
	# $4:	Count for retrying
	#
	WAIT_PROCESSES=$1
	FILTER_STRING=$2
	WAIT_TIME=$3
	MAXIMUM_COUNT=$4
	if [ "X${WAIT_PROCESSES}" = "X" -o "X${FILTER_STRING}" = "X" -o "X${WAIT_TIME}" = "X" -o "X${MAXIMUM_COUNT}" = "X" -o "X${MAXIMUM_COUNT}" = "X1" ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Internal error.${CDEF}" 1>&2
		return 1
	fi
	expr ${WAIT_TIME} + 0 >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Internal error.${CDEF}" 1>&2
		return 1
	fi
	expr ${MAXIMUM_COUNT} + 0 >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Internal error.${CDEF}" 1>&2
		return 1
	fi

	while [ ${MAXIMUM_COUNT} -gt 0 ]; do
		sleep ${WAIT_TIME}
		ps ax | grep ${WAIT_PROCESSES} | grep ${FILTER_STRING} >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			return 0
		fi
		MAXIMUM_COUNT=`expr ${MAXIMUM_COUNT} - 1`
	done

	return 1
}

#
# Check options
#
OPT_NO_INTERACTIVE=
OPT_NO_COMFIRMATION=
OPT_RUNUSER=
OPT_CHMPX_SERVER_PORT=
OPT_CHMPX_SERVER_CTLPORT=
OPT_CHMPX_SLAVE_CTLPORT=
OPT_OPENSTACK_REGION=
OPT_KEYSTONE_URL=
OPT_K2HR3_APP_PORT=
OPT_K2HR3_APP_PORT_EXTERNAL=
OPT_K2HR3_APP_HOST=
OPT_K2HR3_APP_HOST_EXTERNAL=
OPT_K2HR3_API_PORT=
OPT_K2HR3_API_PORT_EXTERNAL=
OPT_K2HR3_API_HOST=
OPT_K2HR3_API_HOST_EXTERNAL=
while [ $# -ne 0 ]; do
	if [ "X$1" = "X" ]; then
		break

	elif [ "X$1" = "X-h" -o "X$1" = "X-H" -o "X$1" = "X--help" -o "X$1" = "X--HELP" ]; then
		func_usage $PROGRAM_NAME
		exit 0

	elif [ "X$1" = "X-ni" -o "X$1" = "X-NI" -o "X$1" = "X--no_interaction" -o "X$1" = "X--NO_INTERACTION" ]; then
		if [ "X${OPT_NO_INTERACTIVE}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --no_interaction(-ni) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_NO_INTERACTIVE="yes"

	elif [ "X$1" = "X-nc" -o "X$1" = "X-NC" -o "X$1" = "X--no_confirmation" -o "X$1" = "X--NO_CONFIRMATION" ]; then
		if [ "X${OPT_NO_COMFIRMATION}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --no_confirmation(-nc) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_NO_COMFIRMATION="yes"

	elif [ "X$1" = "X-ru" -o "X$1" = "X-RU" -o "X$1" = "X--run_user" -o "X$1" = "X--RUN_USER" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --run_user(-ru) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_RUNUSER}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --run_user(-ru) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_RUNUSER=$1

	elif [ "X$1" = "X-svrp" -o "X$1" = "X-SVRP" -o "X$1" = "X--server_port" -o "X$1" = "X--SERVER_PORT" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --server_port(-svrp) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_CHMPX_SERVER_PORT}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --server_port(-svrp) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --server_port(-svrp) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_CHMPX_SERVER_PORT=$1

	elif [ "X$1" = "X-svrcp" -o "X$1" = "X-SVRCP" -o "X$1" = "X--server_ctlport" -o "X$1" = "X--SERVER_CTLPORT" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --server_ctlport(-svrcp) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_CHMPX_SERVER_CTLPORT}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --server_ctlport(-svrcp) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --server_ctlport(-svrcp) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_CHMPX_SERVER_CTLPORT=$1

	elif [ "X$1" = "X-slvcp" -o "X$1" = "X-SLVCP" -o "X$1" = "X--slave_ctlport" -o "X$1" = "X--SLAVE_CTLPORT" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --slave_ctlport(-slvcp) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_CHMPX_SLAVE_CTLPORT}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --slave_ctlport(-slvcp) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --slave_ctlport(-slvcp) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_CHMPX_SLAVE_CTLPORT=$1

	elif [ "X$1" = "X-osr" -o "X$1" = "X-OSR" -o "X$1" = "X--openstack_region" -o "X$1" = "X--OPENSTACK_REGION" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --openstack_region(-osr) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_OPENSTACK_REGION}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --openstack_region(-osr) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_OPENSTACK_REGION=$1

	elif [ "X$1" = "X-ks" -o "X$1" = "X-KS" -o "X$1" = "X--keystone_url" -o "X$1" = "X--KEYSTONE_URL" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --keystone_url(-ks) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_KEYSTONE_URL}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --keystone_url(-ks) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_KEYSTONE_URL=$1

	elif [ "X$1" = "X-appp" -o "X$1" = "X-APPP" -o "X$1" = "X--app_port" -o "X$1" = "X--APP_PORT" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_port(-appp) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_APP_PORT}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_port(-appp) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --app_port(-appp) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_APP_PORT=$1

	elif [ "X$1" = "X-apppe" -o "X$1" = "X-APPPE" -o "X$1" = "X--app_port_external" -o "X$1" = "X--APP_PORT_EXTERNAL" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_port_external(-apppe) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_port_external(-apppe) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --app_port_external(-apppe) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_APP_PORT_EXTERNAL=$1

	elif [ "X$1" = "X-apph" -o "X$1" = "X-APPH" -o "X$1" = "X--app_host" -o "X$1" = "X--APP_HOST" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_host(-apph) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_APP_HOST}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_host(-apph) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_APP_HOST=$1

	elif [ "X$1" = "X-apphe" -o "X$1" = "X-APPHE" -o "X$1" = "X--app_host_external" -o "X$1" = "X--APP_HOST_EXTERNAL" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_host_external(-apphe) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --app_host_external(-apphe) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_APP_HOST_EXTERNAL=$1

	elif [ "X$1" = "X-apip" -o "X$1" = "X-APIP" -o "X$1" = "X--api_port" -o "X$1" = "X--API_PORT" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_port(-apip) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_API_PORT}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_port(-apip) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --api_port(-apip) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_API_PORT=$1

	elif [ "X$1" = "X-apipe" -o "X$1" = "X-APIPE" -o "X$1" = "X--api_port_external" -o "X$1" = "X--API_PORT_EXTERNAL" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_port_external(-apipe) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_port_external(-apipe) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		expr "$1" + 1 >/dev/null 2>&1
		if [ $? -ge 2 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The parameter of --api_port_external(-apipe) option must be number.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_API_PORT_EXTERNAL=$1

	elif [ "X$1" = "X-apih" -o "X$1" = "X-APIH" -o "X$1" = "X--api_host" -o "X$1" = "X--API_HOST" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_host(-apih) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_API_HOST}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_host(-apih) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_API_HOST=$1

	elif [ "X$1" = "X-apihe" -o "X$1" = "X-APIHE" -o "X$1" = "X--api_host_external" -o "X$1" = "X--API_HOST_EXTERNAL" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_host_external(-apihe) option needs parameter.${CDEF}" 1>&2
			exit 1
		fi
		if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --api_host_external(-apihe) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_K2HR3_API_HOST_EXTERNAL=$1

	else
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} $1 option is unknown.${CDEF}" 1>&2
		exit 1
	fi
	shift
done

#
# Interaction
#
if [ "X${OPT_NO_INTERACTIVE}" != "Xyes" ]; then
	if [ "X${OPT_RUNUSER}" = "X" -o "X${OPT_CHMPX_SERVER_PORT}" = "X" -o "X${OPT_CHMPX_SERVER_CTLPORT}" = "X" -o "X${OPT_CHMPX_SLAVE_CTLPORT}" = "X" -o "X${OPT_OPENSTACK_REGION}" = "X" -o "X${OPT_KEYSTONE_URL}" = "X" -o "X${OPT_K2HR3_APP_PORT}" = "X" -o "X${OPT_K2HR3_APP_PORT_EXTERNAL}" = "X" -o "X${OPT_K2HR3_APP_HOST}" = "X" -o "X${OPT_K2HR3_APP_HOST_EXTERNAL}" = "X" -o "X${OPT_K2HR3_API_PORT}" = "X" -o "X${OPT_K2HR3_API_PORT_EXTERNAL}" = "X" -o "X${OPT_K2HR3_API_HOST}" = "X" -o "X${OPT_K2HR3_API_HOST_EXTERNAL}" = "X" ]; then
		echo "-----------------------------------------------------------" 1>&2
		echo "${CGRN}Input options${CDEF}" 1>&2
		echo "-----------------------------------------------------------" 1>&2

		if [ "X${OPT_RUNUSER}" = "X" ]; then
			OPT_RUNUSER=`input_interaction "Execution user of all processes" "no"`
		fi
		if [ "X${OPT_CHMPX_SERVER_PORT}" = "X" ]; then
			OPT_CHMPX_SERVER_PORT=`input_interaction "CHMPX Server node port number" "yes"`
		fi
		if [ "X${OPT_CHMPX_SERVER_CTLPORT}" = "X" ]; then
			OPT_CHMPX_SERVER_CTLPORT=`input_interaction "CHMPX Server node control port number" "yes"`
		fi
		if [ "X${OPT_CHMPX_SLAVE_CTLPORT}" = "X" ]; then
			OPT_CHMPX_SLAVE_CTLPORT=`input_interaction "CHMPX Slave node control port number" "yes"`
		fi
		if [ "X${OPT_OPENSTACK_REGION}" = "X" ]; then
			OPT_OPENSTACK_REGION=`input_interaction "OpenStack(Keystone) Region(ex. \"RegionOne\")" "no"`
		fi
		if [ "X${OPT_KEYSTONE_URL}" = "X" ]; then
			OPT_KEYSTONE_URL=`input_interaction "OpenStack Keystone URL(ex. \"http(s)://....\")" "no"`
		fi
		if [ "X${OPT_K2HR3_APP_PORT}" = "X" ]; then
			OPT_K2HR3_APP_PORT=`input_interaction "K2HR3 Application port number" "yes"`
		fi
		if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" = "X" ]; then
			OPT_K2HR3_APP_PORT_EXTERNAL=`input_interaction "K2HR3 Application external port number(enter empty if not present)" "yes" "yes"`
		fi
		if [ "X${OPT_K2HR3_APP_HOST}" = "X" ]; then
			OPT_K2HR3_APP_HOST=`input_interaction "K2HR3 Application hostname or IP address" "no"`
		fi
		if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" = "X" ]; then
			OPT_K2HR3_APP_HOST_EXTERNAL=`input_interaction "K2HR3 Application external hostanme or IP address(enter empty if not present)" "no" "yes"`
		fi
		if [ "X${OPT_K2HR3_API_PORT}" = "X" ]; then
			OPT_K2HR3_API_PORT=`input_interaction "K2HR3 REST API port number" "yes"`
		fi
		if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" = "X" ]; then
			OPT_K2HR3_API_PORT_EXTERNAL=`input_interaction "K2HR3 REST API external port number(enter empty if not present)" "yes" "yes"`
		fi
		if [ "X${OPT_K2HR3_API_HOST}" = "X" ]; then
			OPT_K2HR3_API_HOST=`input_interaction "K2HR3 REST API hostname or IP address" "no"`
		fi
		if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" = "X" ]; then
			OPT_K2HR3_API_HOST_EXTERNAL=`input_interaction "K2HR3 REST API external hostanme or IP address(enter empty if not present)" "no" "yes"`
		fi
	fi
else
	if [ "X${OPT_RUNUSER}" = "X" ]; then
		#OPT_RUNUSER="nobody"
		OPT_RUNUSER="root"
	fi
	if [ "X${OPT_CHMPX_SERVER_PORT}" = "X" ]; then
		OPT_CHMPX_SERVER_PORT=18020
	fi
	if [ "X${OPT_CHMPX_SERVER_CTLPORT}" = "X" ]; then
		OPT_CHMPX_SERVER_CTLPORT=18021
	fi
	if [ "X${OPT_CHMPX_SLAVE_CTLPORT}" = "X" ]; then
		OPT_CHMPX_SLAVE_CTLPORT=18031
	fi
	if [ "X${OPT_OPENSTACK_REGION}" = "X" ]; then
		OPT_OPENSTACK_REGION="RegionOne"
	fi
	if [ "X${OPT_KEYSTONE_URL}" = "X" ]; then
		OPT_KEYSTONE_URL="https://dummy.keystone.openstack/"
	fi
	if [ "X${OPT_K2HR3_APP_PORT}" = "X" ]; then
		OPT_K2HR3_APP_PORT=80
	fi
	if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" = "X" ]; then
		OPT_K2HR3_APP_PORT_EXTERNAL=
	fi
	if [ "X${OPT_K2HR3_APP_HOST}" = "X" ]; then
		OPT_K2HR3_APP_HOST="localhost"
	fi
	if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" = "X" ]; then
		OPT_K2HR3_APP_HOST_EXTERNAL=
	fi
	if [ "X${OPT_K2HR3_API_PORT}" = "X" ]; then
		OPT_K2HR3_API_PORT=18080
	fi
	if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" = "X" ]; then
		OPT_K2HR3_API_PORT_EXTERNAL=
	fi
	if [ "X${OPT_K2HR3_API_HOST}" = "X" ]; then
		OPT_K2HR3_API_HOST="localhost"
	fi
	if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" = "X" ]; then
		OPT_K2HR3_API_HOST_EXTERNAL=
	fi
fi

#
# Print options
#
if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" = "X" ]; then
	DISP_K2HR3_APP_PORT_EXTERNAL="(empty: using K2HR3 Application port)"
else
	DISP_K2HR3_APP_PORT_EXTERNAL=${OPT_K2HR3_APP_PORT_EXTERNAL}
fi
if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" = "X" ]; then
	DISP_K2HR3_APP_HOST_EXTERNAL="(empty: using K2HR3 Application host instead)"
else
	DISP_K2HR3_APP_HOST_EXTERNAL=${OPT_K2HR3_APP_HOST_EXTERNAL}
fi
if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" = "X" ]; then
	DISP_K2HR3_API_PORT_EXTERNAL="(empty: using K2HR3 REST API port)"
else
	DISP_K2HR3_API_PORT_EXTERNAL=${OPT_K2HR3_API_PORT_EXTERNAL}
fi
if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" = "X" ]; then
	DISP_K2HR3_API_HOST_EXTERNAL="(empty: using K2HR3 REST API host instead)"
else
	DISP_K2HR3_API_HOST_EXTERNAL=${OPT_K2HR3_API_HOST_EXTERNAL}
fi

echo "-----------------------------------------------------------"
echo "${CGRN}Options${CDEF}"
echo "-----------------------------------------------------------"
echo "Execution user name:             ${OPT_RUNUSER}"
echo "CHMPX server port:               ${OPT_CHMPX_SERVER_PORT}"
echo "CHMPX server control port:       ${OPT_CHMPX_SERVER_CTLPORT}"
echo "CHMPX slave port:                ${OPT_CHMPX_SLAVE_CTLPORT}"
echo "OpenStack(keystone) Region:      ${OPT_OPENSTACK_REGION}"
echo "OpenStack keystone URL:          ${OPT_KEYSTONE_URL}"
echo "K2HR3 Application port:          ${OPT_K2HR3_APP_PORT}"
echo "K2HR3 Application external port: ${DISP_K2HR3_APP_PORT_EXTERNAL}"
echo "K2HR3 Application host:          ${OPT_K2HR3_APP_HOST}"
echo "K2HR3 Application external host: ${DISP_K2HR3_APP_HOST_EXTERNAL}"
echo "K2HR3 REST API port:             ${OPT_K2HR3_API_PORT}"
echo "K2HR3 REST API external port:    ${DISP_K2HR3_API_PORT_EXTERNAL}"
echo "K2HR3 REST API host:             ${OPT_K2HR3_API_HOST}"
echo "K2HR3 REST API external host:    ${DISP_K2HR3_API_HOST_EXTERNAL}"
echo ""

if [ "X${OPT_NO_COMFIRMATION}" != "Xyes" ]; then
	while true; do
		echo -n " Do you want to continue? [Y/N]: " 1>&2
		read CONFIRM_DATA

		if [ "X${CONFIRM_DATA}" = "XY" -o "X${CONFIRM_DATA}" = "Xy" ]; then
			echo ""
			break;
		elif [ "X${CONFIRM_DATA}" = "XN" -o "X${CONFIRM_DATA}" = "Xn" ]; then
			echo "${CRED}${CREV}[BREAK]${CDEF}${CRED} Terminate this process.${CDEF}" 1>&2
			exit 0
		else
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} The input data must be \"Y\" or \"N\"${CDEF}" 1>&2
		fi
	done
fi

#----------------------------------------------------------
# Setup repositories
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Setup repositories${CDEF}"
echo "-----------------------------------------------------------"
#
# add packagecloud.io AntPickax
#
OS_ID=`cat /etc/os-release | grep '^ID=' | sed -e 's/ID=//g' -e 's/"//g'`
OS_ID_LIKE=`cat /etc/os-release | grep '^ID_LIKE=' | sed -e 's/ID_LIKE=//g' -e 's/"//g'`
OS_IDS="${OS_ID} ${OS_ID_LIKE}"

echo ${OS_IDS} | grep -i 'ubuntu' > /dev/null
if [ $? -eq 0 ]; then
	IS_DEBIAN=1
else
	IS_DEBIAN=0
fi
echo ${OS_IDS} | grep -i 'fedora' > /dev/null
if [ $? -eq 0 ]; then
	IS_FEDORA=1
else
	IS_FEDORA=0
fi

if [ ${IS_DEBIAN} -eq 1 ]; then
	PACKAGECLOUD_IO_URL=https://packagecloud.io/install/repositories/antpickax/stable/script.deb.sh
	PKG_INSTALLER=apt
elif [ ${IS_FEDORA} -eq 1 ]; then
	PACKAGECLOUD_IO_URL=https://packagecloud.io/install/repositories/antpickax/stable/script.rpm.sh
	PKG_INSTALLER=yum
else
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Unknown OS. Should be Ubuntu or CentOS.${CDEF}" 1>&2
	exit 1
fi

curl -s ${PACKAGECLOUD_IO_URL} | sudo bash
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not set repository to packagecloud.io for AntPickax${CDEF}" 1>&2
	exit 1
fi
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Setup packagecloud.io AntPickax repository.${CDEF}"

#----------------------------------------------------------
# Install packages
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Install packages${CDEF}"
echo "-----------------------------------------------------------"
sudo ${PKG_INSTALLER} -y update
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not update package repository${CDEF}" 1>&2
	exit 1
fi

# [NOTE]
# Default nodejs/npm in ubuntu is old and has some problem.
# So do upgrade nodejs and npm at first.
#
if [ ${IS_DEBIAN} -eq 1 ]; then
	curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
	K2HDKC_DEV_PACKAGE=k2hdkc-dev
else
	curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash -
	K2HDKC_DEV_PACKAGE=k2hdkc-devel
fi
sudo ${PKG_INSTALLER} install -y nodejs
sudo ${PKG_INSTALLER} install -y ${K2HDKC_DEV_PACKAGE} k2htpdtor
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not install ${K2HDKC_DEV_PACKAGE} k2htpdtor${CDEF}" 1>&2
	exit 1
fi
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Installed ${K2HDKC_DEV_PACKAGE} k2htpdtor nodejs npm${CDEF}"

#----------------------------------------------------------
# Generate configurations
#----------------------------------------------------------
cd ${SRCTOP}
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Generate CHMPX configurations${CDEF}"
echo "-----------------------------------------------------------"
#
# For permission
#
chmod 777 ${SRCTOP}/log >/dev/null 2>&1
chmod 777 ${SRCTOP}/data >/dev/null 2>&1

#
# For CHMPX
#
echo 512 | sudo tee -a /proc/sys/fs/mqueue/msg_max > /dev/null 2>&1
RESULT=`cat /proc/sys/fs/mqueue/msg_max`
if [ ${RESULT} -lt 512 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not set msg_max for mqueue${CDEF}" 1>&2
	exit 1
fi

cat ${SRCTOP}/conf/config.templ | sed -e "s/__DATE__/${CURRENT_TIME}/g" -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__MODE_SETTING__/MODE\t\t\t= SERVER\nPORT\t\t\t= ${OPT_CHMPX_SERVER_PORT}\nCTLPORT\t\t\t= ${OPT_CHMPX_SERVER_CTLPORT}\nSELFCTLPORT\t\t= ${OPT_CHMPX_SERVER_CTLPORT}\n/g" -e "s/__SERVER_PORT__/${OPT_CHMPX_SERVER_PORT}/g" -e "s/__SERVER_CTLPORT__/${OPT_CHMPX_SERVER_CTLPORT}/g" -e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g" > ${SRCTOP}/conf/server.ini
cat ${SRCTOP}/conf/config.templ | sed -e "s/__DATE__/${CURRENT_TIME}/g" -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__MODE_SETTING__/MODE\t\t\t= SLAVE\nCTLPORT\t\t\t= 18031\nSELFCTLPORT\t\t= 18031/g" -e "s/__SERVER_PORT__/${OPT_CHMPX_SERVER_PORT}/g" -e "s/__SERVER_CTLPORT__/${OPT_CHMPX_SERVER_CTLPORT}/g" -e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g" > ${SRCTOP}/conf/slave.ini
if [ ! -f ${SRCTOP}/conf/server.ini -o ! -f ${SRCTOP}/conf/slave.ini ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create(copy) ini configuration files${CDEF}" 1>&2
	exit 1
fi
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Generated configuration files : ${SRCTOP}/conf/server.ini, ${SRCTOP}/conf/slave.ini${CDEF}"

#----------------------------------------------------------
# Setup K2HR3 API
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Setup and Generate K2HR3 REST API configuration${CDEF}"
echo "-----------------------------------------------------------"
if [ ${IS_DEBIAN} -eq 1 ]; then
	# check build-essential package
	dpkg -l | grep build-essential >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		# install build-essential package for building k2hdkc nodejs addon
		sudo ${PKG_INSTALLER} install -y build-essential
	fi
else
	# install Development Tools
	sudo ${PKG_INSTALLER} groupinstall -y 'Development Tools'
fi

cd ${SRCTOP}
npm pack k2hr3-api
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not get k2hr3-api npm package archive${CDEF}" 1>&2
	exit 1
fi

tar xvfz k2hr3-api*.tgz
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not decompress k2hr3-api npm package archive${CDEF}" 1>&2
	exit 1
fi
if [ ! -d package ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not find \"package\" directory${CDEF}" 1>&2
	exit 1
fi

mv package k2hr3-api
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not rename directory from \"package\" to \"k2hr3-api\"${CDEF}" 1>&2
	exit 1
fi

cd k2hr3-api
npm install
if [ $? -ne 0 ]; then
	# It rarely fails, but sometimes retrying succeeds
	sleep 5
	npm install
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Failed to install dependency packages for k2hr3-api${CDEF}" 1>&2
		exit 1
	fi
fi

if [ "X${OPT_K2HR3_APP_HOST}" != "Xlocalhost" ]; then
	# Always set localhost
	TMP_K2HR3_APP_HOSTS="'localhost',\n\t\t"
fi
if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_APP_HOSTS="${TMP_K2HR3_APP_HOSTS}'${OPT_K2HR3_APP_HOST}',\n\t\t'${OPT_K2HR3_APP_HOST_EXTERNAL}'"
else
	TMP_K2HR3_APP_HOSTS="${TMP_K2HR3_APP_HOSTS}'${OPT_K2HR3_APP_HOST}'"
fi
if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT_EXTERNAL}
else
	TMP_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT}
fi
if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_API_HOST_EXT=${OPT_K2HR3_API_HOST_EXTERNAL}
else
	TMP_K2HR3_API_HOST_EXT=${OPT_K2HR3_API_HOST}
fi

# for production.json
if [ -f ${SRCTOP}/conf/custom_production_api.templ ]; then
	PRODUCTION_JSON_TEMPL=${SRCTOP}/conf/custom_production_api.templ
elif [ -f ${SRCTOP}/conf/production_api.templ ]; then
	PRODUCTION_JSON_TEMPL=${SRCTOP}/conf/production_api.templ
fi
if [ "X${PRODUCTION_JSON_TEMPL}" != "X" ]; then
	cat ${PRODUCTION_JSON_TEMPL} | sed -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__OS_REGION__/${OPT_OPENSTACK_REGION}/g" -e "s#__KEYSTONE_URL__#${OPT_KEYSTONE_URL}#g" -e "s/__RUNUSER__/${OPT_RUNUSER}/g" -e "s/__SLAVE_CTLPORT__/${OPT_CHMPX_SLAVE_CTLPORT}/g" -e "s/__K2HR3_APP_HOSTS__/${TMP_K2HR3_APP_HOSTS}/g" -e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g" -e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g" -e "s/__K2HR3_API_HOST_EXT__/${TMP_K2HR3_API_HOST_EXT}/g" -e "s/__K2HR3_API_PORT_EXT__/${TMP_K2HR3_API_PORT_EXT}/g" > ${SRCTOP}/k2hr3-api/config/production.json
	if [ ! -f ${SRCTOP}/k2hr3-api/config/production.json ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create(copy) production.json configuration file${CDEF}" 1>&2
		exit 1
	fi
	echo "${CREV}[INFO]${CDEF} Found ${PRODUCTION_JSON_TEMPL}. The process will be started with production.json." 1>&2
else
	echo "${CREV}[INFO]${CDEF} Any production_api.templ is not existed. The process will be started without production.json." 1>&2
fi

# for k2hr3-init.sh
CUSTOM_INIT_TEMPL=${SRCTOP}/conf/custom_k2hr3-init.sh.templ
if [ -f ${CUSTOM_INIT_TEMPL} ]; then
	cp ${CUSTOM_INIT_TEMPL} ${SRCTOP}/k2hr3-api/config/k2hr3-init.sh.templ
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not copy k2hr3-init.sh.templ in k2hr3_api config directory for this devpack${CDEF}" 1>&2
		exit 1
	fi
	echo "${CREV}[INFO]${CDEF} Found ${CUSTOM_INIT_TEMPL}. The process will be started with this." 1>&2
else
	echo "${CREV}[INFO]${CDEF} ${CUSTOM_INIT_TEMPL} is not existed. The process will be started with default k2hr3-init.sh.templ." 1>&2
fi

# for extdata scripts
CUSTOM_EXTDATA_TEMPLS=`ls ${SRCTOP}/conf/custom_*.sh.templ 2>/dev/null`
for _custom_extdata_templ in ${CUSTOM_EXTDATA_TEMPLS}; do
	# except CUSTOM_INIT_TEMPL_NAME
	if [ "X${CUSTOM_INIT_TEMPL}" != "X${_custom_extdata_templ}" ]; then
		# copy templates with renaming it
		_extdata_templ_name=`echo ${_custom_extdata_templ} | sed -e 's#/#\n#g' | tail -1 | sed -e 's/custom_//g'`
		cp ${_custom_extdata_templ} ${SRCTOP}/k2hr3-api/config/${_extdata_templ_name}

		echo "${CREV}[INFO]${CDEF} Found ${_custom_extdata_templ}. It is copied to ${SRCTOP}/k2hr3-api/config/${_extdata_templ_name}." 1>&2
	fi
done

# change run script for pid file
cat ${SRCTOP}/k2hr3-api/bin/run.sh | sed -e 's/\.pid/_api.pid/g' > ${SRCTOP}/k2hr3-api/bin/mod_run.sh
chmod +x ${SRCTOP}/k2hr3-api/bin/mod_run.sh
mv ${SRCTOP}/k2hr3-api/bin/run.sh ${SRCTOP}/k2hr3-api/bin/run_orig.sh
mv ${SRCTOP}/k2hr3-api/bin/mod_run.sh ${SRCTOP}/k2hr3-api/bin/run.sh
if [ ! -f ${SRCTOP}/k2hr3-api/bin/run.sh -o ! -f ${SRCTOP}/k2hr3-api/bin/run_orig.sh ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not modify run.sh for this devpack${CDEF}" 1>&2
	exit 1
fi

# for log directory
if [ ! -d ${SRCTOP}/k2hr3-api/log ]; then
	mkdir ${SRCTOP}/k2hr3-api/log
fi
chmod 0777 ${SRCTOP}/k2hr3-api/log
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create ${SRCTOP}/k2hr3-api/log directory${CDEF}" 1>&2
	exit 1
fi

echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Setup and Generated K2HR3 REST API configuration files : ${SRCTOP}/k2hr3-api/config/production.json${CDEF}"

#----------------------------------------------------------
# Setup K2HR3 APP
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Setup and Generate K2HR3 Application configuration${CDEF}"
echo "-----------------------------------------------------------"
cd ${SRCTOP}
npm pack k2hr3-app
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not get k2hr3-app npm package archive${CDEF}" 1>&2
	exit 1
fi

tar xvfz k2hr3-app*.tgz
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not decompress k2hr3-app npm package archive${CDEF}" 1>&2
	exit 1
fi
if [ ! -d package ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not find \"package\" directory${CDEF}" 1>&2
	exit 1
fi

mv package k2hr3-app
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not rename directory from \"package\" to \"k2hr3-app\"${CDEF}" 1>&2
	exit 1
fi

cd k2hr3-app
npm install
if [ $? -ne 0 ]; then
	# It rarely fails, but sometimes retrying succeeds
	sleep 5
	npm install
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Failed to install dependency packages for k2hr3-app${CDEF}" 1>&2
		exit 1
	fi
fi

if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_APP_HOSTS="'${OPT_K2HR3_APP_HOST}',\n\t\t'${OPT_K2HR3_APP_HOST_EXTERNAL}'"
else
	TMP_K2HR3_APP_HOSTS="'${OPT_K2HR3_APP_HOST}'"
fi
if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT_EXTERNAL}
else
	TMP_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT}
fi
if [ "X${OPT_K2HR3_API_HOST_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_API_HOST_EXT=${OPT_K2HR3_API_HOST_EXTERNAL}
else
	TMP_K2HR3_API_HOST_EXT=${OPT_K2HR3_API_HOST}
fi
if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_APP_PORT_EXT=${OPT_K2HR3_APP_PORT_EXTERNAL}
else
	TMP_K2HR3_APP_PORT_EXT=${OPT_K2HR3_APP_PORT}
fi
if [ "X${OPT_K2HR3_APP_HOST_EXTERNAL}" != "X" ]; then
	TMP_K2HR3_APP_HOST_EXT=${OPT_K2HR3_APP_HOST_EXTERNAL}
else
	TMP_K2HR3_APP_HOST_EXT=${OPT_K2HR3_APP_HOST}
fi

# for production.json
if [ -f ${SRCTOP}/conf/custom_production_app.templ ]; then
	PRODUCTION_JSON_TEMPL=${SRCTOP}/conf/custom_production_app.templ
elif [ -f ${SRCTOP}/conf/production_app.templ ]; then
	PRODUCTION_JSON_TEMPL=${SRCTOP}/conf/production_app.templ
fi
if [ "X${PRODUCTION_JSON_TEMPL}" != "X" ]; then
	cat ${PRODUCTION_JSON_TEMPL} | sed -e "s#__BASE_DIR__#${SRCTOP}#g" -e "s/__RUNUSER__/${OPT_RUNUSER}/g" -e "s/__K2HR3_APP_PORT__/${OPT_K2HR3_APP_PORT}/g" -e "s/__K2HR3_APP_HOST__/${OPT_K2HR3_APP_HOST}/g" -e "s/__K2HR3_APP_PORT_EXT__/${TMP_K2HR3_APP_PORT_EXT}/g" -e "s/__K2HR3_APP_HOST_EXT__/${TMP_K2HR3_APP_HOST_EXT}/g" -e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g" -e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g" -e "s/__K2HR3_API_HOST_EXT__/${TMP_K2HR3_API_HOST_EXT}/g" -e "s/__K2HR3_API_PORT_EXT__/${TMP_K2HR3_API_PORT_EXT}/g" > ${SRCTOP}/k2hr3-app/config/production.json
	if [ ! -f ${SRCTOP}/k2hr3-app/config/production.json ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create(copy) production.json configuration file${CDEF}" 1>&2
		exit 1
	fi
	echo "${CREV}[INFO]${CDEF} Found ${PRODUCTION_JSON_TEMPL}. The process will be started with production.json." 1>&2
else
	echo "${CREV}[INFO]${CDEF} Any production_api.templ is not existed. The process will be started without production.json." 1>&2
fi

# change run script for pid file
cat ${SRCTOP}/k2hr3-app/bin/run.sh | sed -e 's/\.pid/_app.pid/g' > ${SRCTOP}/k2hr3-app/bin/mod_run.sh
chmod +x ${SRCTOP}/k2hr3-app/bin/mod_run.sh
mv ${SRCTOP}/k2hr3-app/bin/run.sh ${SRCTOP}/k2hr3-app/bin/run_orig.sh
mv ${SRCTOP}/k2hr3-app/bin/mod_run.sh ${SRCTOP}/k2hr3-app/bin/run.sh
if [ ! -f ${SRCTOP}/k2hr3-app/bin/run.sh -o ! -f ${SRCTOP}/k2hr3-app/bin/run_orig.sh ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not modify run.sh for this devpack${CDEF}" 1>&2
	exit 1
fi

# for log directory
if [ ! -d ${SRCTOP}/k2hr3-app/log ]; then
	mkdir ${SRCTOP}/k2hr3-app/log
fi
chmod 0777 ${SRCTOP}/k2hr3-app/log
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create ${SRCTOP}/k2hr3-app/log directory${CDEF}" 1>&2
	exit 1
fi

echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Setup and Generated K2HR3 Application configuration files : ${SRCTOP}/k2hr3-app/config/production.json${CDEF}"

#----------------------------------------------------------
# Create HAProxy configuration for sample
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Generate HAProxy sample configuration${CDEF}"
echo "-----------------------------------------------------------"
cd ${SRCTOP}

if [ "X${OPT_K2HR3_APP_PORT_EXTERNAL}" != "X" ]; then
	HA_K2HR3_APP_PORT_EXT=${OPT_K2HR3_APP_PORT_EXTERNAL}
else
	HA_K2HR3_APP_PORT_EXT=${OPT_K2HR3_APP_PORT}
fi
if [ "X${OPT_K2HR3_API_PORT_EXTERNAL}" != "X" ]; then
	HA_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT_EXTERNAL}
else
	HA_K2HR3_API_PORT_EXT=${OPT_K2HR3_API_PORT}
fi
cat ${SRCTOP}/conf/haproxy_example.templ | sed -e "s/__K2HR3_APP_PORT_EXT__/${HA_K2HR3_APP_PORT_EXT}/g" -e "s/__K2HR3_APP_PORT__/${OPT_K2HR3_APP_PORT}/g" -e "s/__K2HR3_APP_HOST__/${OPT_K2HR3_APP_HOST}/g" -e "s/__K2HR3_API_PORT_EXT__/${HA_K2HR3_API_PORT_EXT}/g" -e "s/__K2HR3_API_PORT__/${OPT_K2HR3_API_PORT}/g" -e "s/__K2HR3_API_HOST__/${OPT_K2HR3_API_HOST}/g" > ${SRCTOP}/conf/haproxy_example.cfg
if [ ! -f ${SRCTOP}/conf/haproxy_example.cfg ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} could not create HAProxy configuration sample file${CDEF}" 1>&2
	exit 1
fi
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} Generated HAProxy sample configuration files : ${SRCTOP}/conf/haproxy_example.cfg${CDEF}"

#----------------------------------------------------------
# Run processes
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Start all processes${CDEF}"
echo "-----------------------------------------------------------"

echo "${CGRN}${CREV}[RUN]${CDEF} CHMPX server node..."
sudo -u ${OPT_RUNUSER} chmpx -conf ${SRCTOP}/conf/server.ini -d err >> ${SRCTOP}/log/chmpx_server.log 2>&1 &
wait_process_running chmpx server.ini 20 3
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not run chmpx server node${CDEF}" 1>&2
	exit 1
fi

echo "${CGRN}${CREV}[RUN]${CDEF} K2HDKC server process..."
sudo -u ${OPT_RUNUSER} k2hdkc -conf  ${SRCTOP}/conf/server.ini -d err >> ${SRCTOP}/log/k2hdkc.log 2>&1 &
wait_process_running k2hdkc server.ini 20 3
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not run k2hdkc server process${CDEF}" 1>&2
	exit 1
fi

echo "${CGRN}${CREV}[RUN]${CDEF} CHMPX slave node..."
sudo -u ${OPT_RUNUSER} chmpx -conf ${SRCTOP}/conf/slave.ini -d err >> ${SRCTOP}/log/chmpx_slave.log 2>&1 &
wait_process_running chmpx slave.ini 20 3
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not run chmpx slave node${CDEF}" 1>&2
	exit 1
fi

#
# The chmpx processes have started but may take some time to initialize
#
sleep 20

#
# [NOTE]
# Nodejs will be started as root, but internally it will be setuid and run as nobody.
# In k2hr3, log files and directories are created as root, which causes permission issues.
# rotating-file-stream(and fs.createWriteStream, etc.) has a mode option, but which doesn't work.
# Therefore, we use helper script for sudo and umask.
#
echo "${CGRN}${CREV}[RUN]${CDEF} K2HR3 REST API..."
sudo ${BINDIR}/run_node_helper.sh ${SRCTOP}/k2hr3-api
wait_process_running www k2hr3-api 20 3
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not run k2hr3-api node process${CDEF}" 1>&2
	exit 1
fi

echo "${CGRN}${CREV}[RUN]${CDEF} K2HR3 Application..."
sudo ${BINDIR}/run_node_helper.sh ${SRCTOP}/k2hr3-app
wait_process_running www k2hr3-app 20 3
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not run k2hr3-app node process${CDEF}" 1>&2
	exit 1
fi

#----------------------------------------------------------
# Success
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}K2HR3 DevPack launcher completed${CDEF}"
echo "-----------------------------------------------------------"
ps -ax | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www'
echo "--------------------------------------------------"
BIN_PROCESSES=`ps -ax | grep -v grep | grep -e chmpx -e k2hdkc | grep -v '\-u nobody' | wc -l`
API_PROCESSES=`ps -ax | grep -v grep | grep 'k2hr3-api/bin/www' | wc -l`
APP_PROCESSES=`ps -ax | grep -v grep | grep 'k2hr3-app/bin/www' | wc -l`
if [ ${BIN_PROCESSES} -ne 3 -o ${API_PROCESSES} -le 0 -o ${APP_PROCESSES} -le 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Some important processes could not be started.${CDEF}" 1>&2
	exit 1
fi
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} All K2HR3 processes has been run.${CDEF}"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
