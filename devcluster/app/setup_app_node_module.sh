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
# A simple script to install the k2hr3-app node module on localhost
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
COMPONENT=app
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
        -h) usage_app_node_module;;
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

logger -t ${TAG} -p user.info ". ${SRCDIR}/cluster_functions"
. ${SRCDIR}/cluster_functions

# npm_init
logger -t ${TAG} -p user.debug "npm_init"
npm_init
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "npm_init should return zero, not ${RET}"
    exit 1
fi

########
# k2hr3-app specific code exists from here below
#

if test -n "${NPM_ARCHIVE_FILE}"; then
    logger -t ${TAG} -p user.debug "npm install ${NPM_ARCHIVE_FILE}"
    npm install ${NPM_ARCHIVE_FILE}
    RESULT=$?
else
    logger -t ${TAG} -p user.debug "npm install k2hr3-app"
    npm install k2hr3-app
    RESULT=$?
fi
if test "${RESULT}" -ne 0; then
    logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
    exit 1
fi

########
#   5. Configures the default local.json of the k2hr3-app package.
#   You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#
logger -t ${TAG} -p user.info "5. Configures the default local.json of the k2hr3-app package"

for varname in scheme multiproc runuser privatekey cert apihost rejectUnauthorized; do
    keyname="k2hr3_app_${varname}"
    varval=$(eval echo "\${${keyname}}")
    if test -n "${varval}"; then
        logger -t ${TAG} -p user.debug "perl -pi -e \"s|\"${varname}\":\s+\"\S+\"|\"${varname}\": \"${varval}\"|\" local_${COMPONENT}.json"
        perl -pi -e "s|\"${varname}\":\s+\"\S+\"|\"${varname}\": \"${varval}\"|" local_${COMPONENT}.json
        RESULT=$?
        if test "${RESULT}" -ne 0; then
            logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
            exit 1
        fi
    else
        logger -t ${TAG} -p user.warn "${varname} should be nonzero, ${varval}"
    fi
    unset varval
done

for varname in port apiport; do
    keyname="k2hr3_app_${varname}"
    varval=$(eval echo "\${$keyname}")
    if test -n "${varval}"; then
        logger -t ${TAG} -p user.debug "perl -pi -e \"s|\"${varname}\":\s+\S+,|\"${varname}\": ${varval},|\" ./local_${COMPONENT}.json"
        perl -pi -e "s|\"${varname}\":\s+\S+,|\"${varname}\": ${varval},|" ./local_${COMPONENT}.json
        RESULT=$?
        if test "${RESULT}" -ne 0; then
            logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
            exit 1
        fi
    else
        logger -t ${TAG} -p user.warn "${varname} should be nonzero, ${varval}"
    fi
    unset varval
done

if test "${k2hr3_app_scheme}" = "https"; then
    if test -f "${k2hr3_app_privatekey}" -a -f "${k2hr3_app_cert}"; then
        logger -t ${TAG} -p user.debug "OK ${k2hr3_app_privatekey} and ${k2hr3_app_cert} exist"
        if test "${OS_NAME}" = "fedora" -o "${OS_NAME}" = "centos"; then
            k2hr3_app_ca="/etc/pki/tls/certs/ca-bundle.crt"
        elif test "${OS_NAME}" = "debian" -o "${OS_NAME}" = "ubuntu"; then
            k2hr3_app_ca="/etc/ssl/certs/ca-certificates.crt"
        else
            logger -t ${TAG} -p user.err "unsupported OS"
            exit 1
        fi
        logger -t ${TAG} -p user.debug "perl -pi -e \"s|\"ca\":\s+\"\S+\",|\"ca\": \"${k2hr3_app_ca}\",|\" ./local_${COMPONENT}.json"
        perl -pi -e "s|\"ca\":\s+\"\S+\",|\"ca\": \"${k2hr3_app_ca}\",|" ./local_${COMPONENT}.json
        RESULT=$?
        if test "${RESULT}" -ne 0; then
            logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
            exit 1
        fi
    else
        logger -t ${TAG} -p user.err "${k2hr3_app_privatekey} should exist, not ${k2hr3_app_privatekey}"
        exit 1
    fi
fi

########
#   6. Installs the configured local.json of the k2hr3-app package.
#   `k2hr3_app` node module uses it.
#
logger -t ${TAG} -p user.info "6. Installs the configured local.json of the k2hr3-app package"

logger -t ${TAG} -p user.debug "install_npm_local_json ${npm_default_user}"
install_npm_local_json ${npm_default_user}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_npm_local_json should return zero, not ${RET}"
    exit 1
fi

# The final message displays the time elapsed.
ELAPSED=$(expr $(date +%s) - ${STARTTIME})
logger -t $(basename $0) -s -p user.info "completed in ${ELAPSED} seconds"

exit 0

#
# VIM modelines
#
# vim:set ts=4 fenc=utf-8:
#
