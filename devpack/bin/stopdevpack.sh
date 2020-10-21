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
	echo "Usage:  $1 [--clear(-c)] [--help(-h)]"
	echo ""
	echo "        --clear(-c)       clear configuration, data and log files."
	echo "        --help(-h)        print help"
	echo ""
}

#
# Check options
#
OPT_CLEAR=
while [ $# -ne 0 ]; do
	if [ "X$1" = "X" ]; then
		break

	elif [ "X$1" = "X-h" -o "X$1" = "X-H" -o "X$1" = "X--help" -o "X$1" = "X--HELP" ]; then
		func_usage $PROGRAM_NAME
		exit 0

	elif [ "X$1" = "X-c" -o "X$1" = "X-C" -o "X$1" = "X--clear" -o "X$1" = "X--CLEAR" ]; then
		if [ "X${OPT_CLEAR}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} --clear(-c) option is already specified.${CDEF}" 1>&2
			exit 1
		fi
		OPT_CLEAR="yes"

	else
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} $1 option is unknown.${CDEF}" 1>&2
		exit 1
	fi
	shift
done

#----------------------------------------------------------
# Current processes state
#----------------------------------------------------------
echo "-----------------------------------------------------------"
echo "${CGRN}Current processes state${CDEF}"
echo "-----------------------------------------------------------"
ps -ax | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www'

#----------------------------------------------------------
# Stop processes
#----------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "${CGRN}Stop all processes${CDEF}"
echo "-----------------------------------------------------------"
echo ""
echo "${CGRN}${CREV}[STOP]${CDEF} K2HR3 Application..."
cd ${SRCTOP}/k2hr3-app
ps ax 2>/dev/null | grep -v grep | grep k2hr3-app | grep node | grep www >/dev/null
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Already stop k2hr3-app node process${CDEF}" 1>&2
else
	sudo npm run stop
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop k2hr3-app node process${CDEF}" 1>&2
		exit 1
	else
		echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop k2hr3-app node process${CDEF}"
	fi
fi

echo ""
echo "${CGRN}${CREV}[STOP]${CDEF} K2HR3 REST API..."
cd ${SRCTOP}/k2hr3-api
ps ax 2>/dev/null | grep -v grep | grep k2hr3-api | grep node | grep www >/dev/null
if [ $? -ne 0 ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Already stop k2hr3-api node process${CDEF}" 1>&2
else
	sudo npm run stop
	if [ $? -ne 0 ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop k2hr3-api node process${CDEF}" 1>&2
		exit 1
	else
		echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop k2hr3-api node process${CDEF}"
	fi
fi

echo ""
echo "${CGRN}${CREV}[STOP]${CDEF} CHMPX slave node..."
cd ${SRCTOP}
CHMPX_SLAVE_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}'`
if [ "X${CHMPX_SLAVE_PROCID}" = "X" ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Already stop CHMPX slave process${CDEF}" 1>&2
else
	sudo kill -HUP ${CHMPX_SLAVE_PROCID}
	sleep 10
	CHMPX_SLAVE_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}'`
	if [ "X${CHMPX_SLAVE_PROCID}" != "X" ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop CHMPX slave process by HUP, then retry by KILL${CDEF}" 1>&2

		sudo kill -KILL ${CHMPX_SLAVE_PROCID}
		sleep 10
		CHMPX_SLAVE_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}'`
		if [ "X${CHMPX_SLAVE_PROCID}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop CHMPX slave process by KILL${CDEF}" 1>&2
			exit 1
		else
			echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop CHMPX slave process${CDEF}"
		fi
	else
		echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop CHMPX slave process${CDEF}"
	fi
fi

echo ""
echo "${CGRN}${CREV}[STOP]${CDEF} K2HDKC server process..."
cd ${SRCTOP}
K2HDKC_PROCID=`ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
if [ "X${K2HDKC_PROCID}" = "X" ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Already stop K2HDKC server process${CDEF}" 1>&2
else
	sudo kill -HUP ${K2HDKC_PROCID}
	sleep 10
	K2HDKC_PROCID=`ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
	if [ "X${K2HDKC_PROCID}" != "X" ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop K2HDKC server process by HUP, then retry by KILL${CDEF}" 1>&2

		sudo kill -KILL ${K2HDKC_PROCID}
		sleep 10
		K2HDKC_PROCID=`ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
		if [ "X${K2HDKC_PROCID}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop K2HDKC server process by KILL${CDEF}" 1>&2
			exit 1
		else
			echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop K2HDKC server process${CDEF}"
		fi
	else
		echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop K2HDKC server process${CDEF}"
	fi
fi

echo ""
echo "${CGRN}${CREV}[STOP]${CDEF} CHMPX server node..."
cd ${SRCTOP}
CHMPX_SERVER_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
if [ "X${CHMPX_SERVER_PROCID}" = "X" ]; then
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Already stop CHMPX server process${CDEF}" 1>&2
else
	sudo kill -HUP ${CHMPX_SERVER_PROCID}
	sleep 10
	CHMPX_SERVER_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
	if [ "X${CHMPX_SERVER_PROCID}" != "X" ]; then
		echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop CHMPX server process by HUP, then retry by KILL${CDEF}" 1>&2

		sudo kill -KILL ${CHMPX_SERVER_PROCID}
		sleep 10
		CHMPX_SERVER_PROCID=`ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}'`
		if [ "X${CHMPX_SERVER_PROCID}" != "X" ]; then
			echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop CHMPX server process by KILL${CDEF}" 1>&2
			exit 1
		else
			echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop CHMPX server process${CDEF}"
		fi
	else
		echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} stop CHMPX server process${CDEF}"
	fi
fi

#----------------------------------------------------------
# Check processes
#----------------------------------------------------------
ps -ax 2>/dev/null | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www' >/dev/null
if [ $? -eq 0 ]; then
	echo ""
	echo "${CRED}${CREV}[ERROR]${CDEF}${CRED} Could not stop some processes${CDEF}" 1>&2
	echo ""
	ps -ax 2>/dev/null | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www'
	echo ""
	exit 1
fi

#----------------------------------------------------------
# Clear files
#----------------------------------------------------------
if [ "X${OPT_CLEAR}" = "Xyes" ]; then
	echo ""
	echo "-----------------------------------------------------------"
	echo "${CGRN}Clean up files${CDEF}"
	echo "-----------------------------------------------------------"
	sudo rm -rf log/* data/* conf/*.ini conf/*.cfg k2hr3-ap*

	echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} cleaned up files.${CDEF}"
fi

echo ""
echo "${CGRN}${CREV}[SUCCESS]${CDEF}${CGRN} All processes has been stop.${CDEF}"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
