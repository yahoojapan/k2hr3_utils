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
#PIPEFAILURE_FILE="/tmp/.pipefailure.$(od -An -tu4 -N4 /dev/random | tr -d ' \n')"

PROGRAM_NAME=$(basename "${0}")
SCRIPTDIR=$(dirname "${0}")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)
SRCTOP=$(cd "${SCRIPTDIR}"/.. || exit 1; pwd)
#BINDIR="${SCRIPTDIR}"

#
# Option variables
#
OPT_CLEAR="no"

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

#----------------------------------------------------------
# Usage function
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

#==========================================================
# Check Options
#==========================================================
while [ $# -ne 0 ]; do
	if [ "$1" = "" ]; then
		break

	elif [ "$1" = "-h" ] || [ "$1" = "-H" ] || [ "$1" = "--help" ] || [ "$1" = "--HELP" ]; then
		func_usage "${PROGRAM_NAME}"
		exit 0

	elif [ "$1" = "-c" ] || [ "$1" = "-C" ] || [ "$1" = "--clear" ] || [ "$1" = "--CLEAR" ]; then
		if [ "${OPT_CLEAR}" != "no" ]; then
			PRNERR "--clear(-c) option is already specified."
			exit 1
		fi
		OPT_CLEAR="yes"

	else
		PRNERR "$1 option is unknown."
		exit 1
	fi
	shift
done

#==========================================================
# Current processes state
#==========================================================
PRNTITLE "Current processes state"

# shellcheck disable=SC2009
ps ax | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www' | sed -e 's#^#    #g'

#==========================================================
# Stop processes
#==========================================================
PRNTITLE "Stop all processes"

#
# Stop K2HR3 APP
#
PRNMSG "Stop K2HR3 Application"

if [ -d "${SRCTOP}"/k2hr3-app ]; then
	cd "${SRCTOP}"/k2hr3-app || exit 1

	# shellcheck disable=SC2009
	if ps ax 2>/dev/null | grep -v grep | grep k2hr3-app | grep node | grep -q www; then
		if ({ sudo npm run stop || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Could not stop all k2hr3-app node process"
			exit 1
		fi
		PRNINFO "Succeed to stop all k2hr3-app node process"
	else
		PRNINFO "Already stop all k2hr3-app node process"
	fi
else
	PRNINFO "Already stop all k2hr3-app node process"
fi

#
# Stop K2HR3 REST API
#
PRNMSG "Stop K2HR3 REST API"

if [ -d "${SRCTOP}"/k2hr3-api ]; then
	cd "${SRCTOP}"/k2hr3-api || exit 1

	# shellcheck disable=SC2009
	if ps ax 2>/dev/null | grep -v grep | grep k2hr3-api | grep node | grep -q www; then
		if ({ sudo npm run stop || echo > "${PIPEFAILURE_FILE}"; } | sed -e 's|^|    |g') && rm "${PIPEFAILURE_FILE}" >/dev/null 2>&1; then
			PRNERR "Could not stop all k2hr3-api node process"
			exit 1
		fi
		PRNINFO "Succeed to stop all k2hr3-api node process"
	else
		PRNINFO "Already stop all k2hr3-api node process"
	fi
else
	PRNINFO "Already stop all k2hr3-api node process"
fi

#
# Stop CHMPX Slave node
#
PRNMSG "Stop CHMPX Slave node"

cd "${SRCTOP}" || exit 1

# shellcheck disable=SC2009
CHMPX_SLAVE_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}')

if [ -n "${CHMPX_SLAVE_PROCID}" ]; then
	/bin/sh -c "sudo kill -HUP ${CHMPX_SLAVE_PROCID}"
	sleep 10

	# shellcheck disable=SC2009
	CHMPX_SLAVE_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}')
	if [ -n "${CHMPX_SLAVE_PROCID}" ]; then
		PRNWARN "Could not stop CHMPX Slave process by HUP, then retry by KILL"

		/bin/sh -c "sudo kill -KILL ${CHMPX_SLAVE_PROCID}"
		sleep 10

		# shellcheck disable=SC2009
		CHMPX_SLAVE_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep slave.ini | grep -v '\-u nobody' | awk '{print $1}')
		if [ -n "${CHMPX_SLAVE_PROCID}" ]; then
			PRNERR "Could not stop all CHMPX slave process by KILL"
			exit 1
		fi
	fi
	PRNINFO "Succeed to stop all CHMPX slave process"
else
	PRNINFO "Already stop all CHMPX Slave process"
fi

#
# Stop K2HDKC Server process
#
PRNMSG "Stop K2HDKC Server process"

cd "${SRCTOP}" || exit 1

# shellcheck disable=SC2009
K2HDKC_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
if [ -n "${K2HDKC_PROCID}" ]; then
	/bin/sh -c "sudo kill -HUP ${K2HDKC_PROCID}"
	sleep 10

	# shellcheck disable=SC2009
	K2HDKC_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
	if [ -n "${K2HDKC_PROCID}" ]; then
		PRNWARN "Could not stop all K2HDKC Server process by HUP, then retry by KILL"

		/bin/sh -c "sudo kill -KILL ${K2HDKC_PROCID}"
		sleep 10

		# shellcheck disable=SC2009
		K2HDKC_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep k2hdkc | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
		if [ -n "${K2HDKC_PROCID}" ]; then
			PRNERR "Could not stop all K2HDKC Server process by KILL"
			exit 1
		fi
	fi
	PRNINFO "Succeed to stop all K2HDKC Server process"
else
	PRNINFO "Already stop all K2HDKC Server process"
fi

#
# Stop CHMPX Server node
#
PRNMSG "Stop CHMPX Server node"

cd "${SRCTOP}" || exit 1

# shellcheck disable=SC2009
CHMPX_SERVER_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
if [ -n "${CHMPX_SERVER_PROCID}" ]; then
	/bin/sh -c "sudo kill -HUP ${CHMPX_SERVER_PROCID}"
	sleep 10

	# shellcheck disable=SC2009
	CHMPX_SERVER_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
	if [ -n "${CHMPX_SERVER_PROCID}" ]; then
		PRNWARN "Could not stop all CHMPX Server process by HUP, then retry by KILL"

		/bin/sh -c "sudo kill -KILL ${CHMPX_SERVER_PROCID}"
		sleep 10

		# shellcheck disable=SC2009
		CHMPX_SERVER_PROCID=$(ps ax 2>/dev/null | grep -v grep | grep chmpx | grep server.ini | grep -v '\-u nobody' | awk '{print $1}')
		if [ -n "${CHMPX_SERVER_PROCID}" ]; then
			PRNERR "Could not stop all CHMPX Server process by KILL"
			exit 1
		fi
	fi
	PRNINFO "Succeed to stop all CHMPX Server process"
else
	PRNINFO "Already stop all CHMPX Server process"
fi

#
# Reconfirm that all processes have been stopped
#
PRNMSG "Reconfirm that all processes have been stopped"

# shellcheck disable=SC2009
if ps ax 2>/dev/null | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -q -v 'node bin/www'; then
	PRNERR "Failed to stop some processes"
	echo ""
	# shellcheck disable=SC2009
	ps ax | grep -v grep | grep -e chmpx -e k2hdkc -e www | grep -v '\-u nobody' | grep -v 'node bin/www' | sed -e 's#^#    #g'
	exit 1
fi

PRNSUCCESS "Stop all processes"

#==========================================================
# Clean up files
#==========================================================
if [ "${OPT_CLEAR}" = "yes" ]; then
	PRNTITLE "Clean up files"

	sudo rm -rf log/* data/* conf/*.ini conf/*.cfg conf/README_NODE_PORT_FORWARDING k2hr3-api k2hr3-app k2hr3-api-*.tgz k2hr3-app-*.tgz

	PRNINFO "Succeed to clean up files"
fi

echo ""
echo "${CGRN}All K2HR3 cluster processes has been stop.${CDEF}"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
