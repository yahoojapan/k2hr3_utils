#!/bin/sh
#
# K2HR3 Utilities
#
# Copyright 2018 Yahoo! Japan Corporation.
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
# AUTHOR:   Hirotaka Wakabayashi
# CREATE:   Mon Jul 9 2018
# REVISION:
#

#
# A simple script to install k2hr3-api node module on localhost.
# ${npm_default_user} invokes this script to install node modules to ${HOME}.
#

# Sets the default locale. LC_ALL has precedence over other LC* variables.
unset LANG
unset LANGUAGE
LC_ALL=en_US.utf8
export LC_ALL

# Sets PATH. setup_*.sh uses useradd command
PATH=${PATH}:/usr/sbin:/sbin

# an unset parameter expansion will fail
set -u

# umask 022 is enough
umask 022

# Defines environments
COMPONENT=api
DEBUG=0
SRCDIR=$(cd $(dirname "$0") && pwd)
SERVICE_MANAGER_DIR=${SRCDIR}/../service_manager
STARTTIME=$(date +%s)
VERSION=0.9.1
NPM_ARCHIVE_FILE=

# Parses cli args
while true; do
	case "${1-}" in
		-d) DEBUG=1;;
		-f) shift; NPM_ARCHIVE_FILE="${1-}";;
		-h) usage;;
		-t) shift; TAG="${1-}";;
		-v) version;;
		*) break;;
	esac
	shift
done

# Determines the TAG
if test -z "${TAG-}"; then
	# Determines the debug mode
	if test "${DEBUG}" -eq 1; then
		TAG="$(basename $0) -s"
	else
		TAG=$(basename $0)
	fi
fi

# The first message is always visible.
logger -t $(basename $0) -s -p user.info "$(basename $0) ${VERSION}"

# Loads cluster common functions
if ! test -r "${SRCDIR}/../cluster_functions"; then
	logger -t ${TAG} -p user.err "${SRCDIR}/../cluster_functions should exist"
	exit 1
fi
. ${SRCDIR}/../cluster_functions

# Loads functions if setup_app_node_module_functions file exists
if test -r "${SRCDIR}/setup_${COMPONENT}_node_module_functions"; then
	. ${SRCDIR}/setup_${COMPONENT}_node_module_functions
fi

 npm_init
logger -t ${TAG} -p user.debug "npm_init"
npm_init
RET=$?
if test "${RET}" -ne 0; then
	logger -t ${TAG} -p user.err "npm_init should return zero, not ${RET}"
	exit 1
fi

########
# k2hr3-api specific code exists from here below
#

# Check if a compiler exists in PATH
if test "${OS_NAME}" = "centos" -a "${OS_VERSION}" != "8"; then
	# checkif devtoolset-? in package_install_dev_pkgs
	for devtoolset in devtoolset-7 devtoolset-6 devtoolset-4; do
		if test -f "/opt/rh/${devtoolset}/enable"; then
			logger -t ${TAG} -p user.debug "echo ${package_install_dev_pkgs} | grep ${devtoolset}"
			echo ${package_install_dev_pkgs} | grep ${devtoolset} > /dev/null 2>&1
			RESULT=$?
			if test "${RESULT}" -eq 0; then
				logger -t ${TAG} -p user.debug "source /opt/rh/${devtoolset}/enable"
				set +u
				source /opt/rh/${devtoolset}/enable
				set -u
				break
			else
				logger -t ${TAG} -p user.warn "RESULT should be zero, not ${RESULT}"
			fi
		else
			logger -t ${TAG} -p user.err  "[NO] no ${devtoolset} found"
			exit 1
		fi
	done

	# No devtoolset in centos means a fatal error.
	GPP_PATH=$(which g++)
	if test "${GPP_PATH}" = ""; then
		logger -t ${TAG} -p user.err "g++ should found, not ${GPP_PATH}"
		exit 1
	fi
fi

#
# Makes a node app environment in a temporary directory
#
TMPDIR=$(mktemp -d)
if ! test -d "${TMPDIR}"; then
	logger -t ${TAG} -p user.err "[NO] no ${TMPDIR}"
	exit 1
fi
cd ${TMPDIR}

# Detects a package archive file.
if ! test -n "${NPM_ARCHIVE_FILE}"; then
	# this command overrite existing k2hr3-api-*.tgz.
	npm pack k2hr3-${COMPONENT}
	if test "${?}" != 0; then
		logger -t ${TAG} -p user.err "[NO] npm pack k2hr3-${COMPONENT}"
		rm -rf ${TMPDIR}
		exit 1
	fi
	NPM_ARCHIVE_FILE=$(ls k2hr3-${COMPONENT}-*.tgz)
fi

# Unzips the package archive file.
tar xzf ${NPM_ARCHIVE_FILE}
if test "${?}" != 0; then
	logger -t ${TAG} -p user.err "[NO] tar xzf ${NPM_ARCHIVE_FILE}"
	rm -rf ${TMPDIR}
	exit 1
fi

# Package directory shows up after unzip the archive file
if ! test -d "package"; then
	logger -t ${TAG} -p user.err "[NO] no package dir"
	rm -rf ${TMPDIR}
	exit 1
fi
cd package

# Makes a node app environment in this directory
npm install
if test "${?}" != 0; then
	logger -t ${TAG} -p user.err "[NO] npm install"
	rm -rf ${TMPDIR}
	exit 1
fi

########
# 12. Configures the local.json for the k2hr3-api package.
# You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#
logger -t ${TAG} -p user.debug "12. Configures the local.json for the k2hr3-${COMPONENT} package."

# Runs local-json.js if exists.
if test -f "${SRCDIR}/local-json.js"; then
	node ${SRCDIR}/local-json.js ${SRCDIR}/setup_${COMPONENT}_${OS_NAME}.ini ./local.json
	if test "${?}" != 0; then
		rm -rf ${TMPDIR}
		logger -t ${TAG} -p user.err "node ${SRCDIR}/local-json.js ${SRCDIR}/setup_${COMPONENT}_${OS_NAME}.ini ./local.json"
		exit 1
	fi

	if test -f "./local.json"; then
		install -C -D -g users -m 0444 -o ${USER} -v ./local.json ./config/local.json
		if test "${?}" != 0; then
			logger -t ${TAG} -p user.err "[NO] install -C -D -g users -m 0444 -o ${USER} -v ./local.json ./config/local.json"
			rm -rf ${TMPDIR}
			exit 1
		fi
	else
		logger -t ${TAG} -p user.err "[NO] ./local.json not found"
		exit 1
	fi
else
	logger -t ${TAG} -p user.debug "${SRCDIR}/local-json.js not found, which is not a problem."
fi

########
# 13. Installs the configured local.json of the k2hr3-api package.
# You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#
logger -t ${TAG} -p user.debug "13. Installs the configured local.json of the k2hr3-${COMPONENT} package"

# Invokes an error if no local.json found
if ! test -f "./config/local.json"; then
	logger -t ${TAG} -p user.err "[NO] no ./config/local.json found"
	rm -rf ${TMPDIR}
	exit 1
fi

# Copies something like a nodejs libraries to the "lib" directory
for file in ${SRCDIR}/*.js; do
	if test -f "${file}"; then
		install -C -g users -m 0444 -o ${USER} -v ${file} ./lib/
		if test "${?}" != 0; then
			logger -t ${TAG} -p user.err "[NO] install -C -D -m 0444 -o ${USER} -v ${file} ./lib/"
			rm -rf ${TMPDIR}
			exit 1
		fi
	else
		logger -t ${TAG} -p user.err "[NO] ${file} not found"
		rm -rf ${TMPDIR}
		exit 1
	fi
done

# Installs server a cert and a key
if test -f "${SRCDIR}/key.pem" -a -f "${SRCDIR}/cert.pem"; then
	install -C -D -g users -m 0400 -o ${USER} -v ${SRCDIR}/key.pem ./config/key.pem
	install -C -D -g users -m 0444 -o ${USER} -v ${SRCDIR}/cert.pem ./config/cert.pem
else
	openssl genrsa 2024 > ./config/key.pem
	if ! test -f "./config/key.pem"; then
		logger -t ${TAG} -p user.err "[NO] ./config/key.pem not found"
		rm -rf ${TMPDIR}
		exit 1
	fi
	chmod 400 ./config/key.pem
	openssl req -new -key ./config/key.pem -sha256 -config ${SRCDIR}/openssl_sample.conf  > ./config/cert.csr
	openssl x509 -req -days 3650 -signkey ./config/key.pem < ./config/cert.csr > ./config/cert.pem
fi

cd ${HOME}
if test -d "k2hr3-${COMPONENT}.old"; then
	NOW=$(date +%s)
	mv -f k2hr3-${COMPONENT}.old k2hr3-${COMPONENT}.old.${NOW}
	if test "${?}" != 0; then
		logger -t ${TAG} -p user.err "[NO] mv -f k2hr3-${COMPONENT}.old k2hr3-${COMPONENT}.old.${NOW}"
		rm -rf ${SRCDIR}
		exit 1
	fi
fi

if test -d "k2hr3-${COMPONENT}"; then
	mv k2hr3-${COMPONENT} k2hr3-${COMPONENT}.old
	if test "${?}" != 0; then
		logger -t ${TAG} -p user.err "[NO] mv k2hr3-${COMPONENT} k2hr3-${COMPONENT}.old"
		rm -rf ${SRCDIR}
		exit 1
	fi
fi

mv ${TMPDIR}/package k2hr3-${COMPONENT}
if test "${?}" != 0; then
	logger -t ${TAG} -p user.err "[NO] mv ${TMPDIR}/package k2hr3-${COMPONENT}"
	mv k2hr3-${COMPONENT}.old k2hr3-${COMPONENT}
	rm -rf ${SRCDIR} ${TMPDIR}
	exit 1
fi

# The final message displays the time elapsed.
ELAPSED=$(expr $(date +%s) - ${STARTTIME})
logger -t $(basename $0) -s -p user.info "completed in ${ELAPSED} seconds"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
