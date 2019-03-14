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
# k2hr3-api specific code exists from here below
#

# Check if a compiler exists in PATH
if test "${OS_NAME}" = "centos"; then
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

logger -t ${TAG} -p user.debug "npm install k2hdkc"
npm install k2hdkc
RESULT=$?
if test "${RESULT}" -ne 0; then
    logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
    exit 1
fi

if test -n "${NPM_ARCHIVE_FILE}"; then
    logger -t ${TAG} -p user.debug "npm install ${NPM_ARCHIVE_FILE}"
    npm install ${NPM_ARCHIVE_FILE}
    RESULT=$?
else
    logger -t ${TAG} -p user.debug "npm install k2hr3-api"
    npm install k2hr3-api
    RESULT=$?
fi
if test "${RESULT}" -ne 0; then
    logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
    exit 1
fi

########
# 12. Configures the local.json for the k2hr3-api package.
# You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#
logger -t ${TAG} -p user.debug "12. Configures the local.json for the k2hr3-api package."

openstack_region=${k2hr3_api_region}
identity_endpoint=${k2hr3_api_identity_endpoint}
if test -n "${k2hr3_api_region}" -a -n "${identity_endpoint}"; then
    logger -t ${TAG} -p user.debug "perl -pi -e \"s|\"myregion\":\s+.*\s$|\"${openstack_region}\": \"${identity_endpoint}\"\n|s\" local_${COMPONENT}.json"
    perl -pi -e "s|\"myregion\":\s+.*\s$|\"${openstack_region}\": \"${identity_endpoint}\"\n|s" local_${COMPONENT}.json
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
        exit 1
    fi
else
    logger -t ${TAG} -p user.warn "openstack_region or identity_endpoint should not be empty, ${openstack_region} ${identity_endpoint}"
fi
logger -t ${TAG} -p user.debug "configure corsips in local_${COMPONENT}.json"
varval=$(eval echo "${k2hr3_api_corsips}"|perl -p -e "s/\'//g; s/\"//g; s/,/ /g")
ips=""
for ip in ${varval}; do
    if test "${ips}" != ""; then
        ips=$(printf "%s\"%s\"", "${ips}" "${ip}")
    else
        ips=$(printf "\"%s\"", "${ip}")
    fi
done
ips=$(echo "${ips}"|perl -p -e "s/,$//g")
if test -n "${ips}"; then
    logger -t ${TAG} -p user.debug "perl -pi -e \"BEGIN{undef $/;} s/corsips:\s+\[.*\],/\"corsips: [${ips}],/smg\" local_${COMPONENT}.json"
    perl -pi -e "BEGIN{undef $/;} s/corsips:\s+\[.*\],/\"corsips: [${ips}],/smg" local_${COMPONENT}.json
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
        exit 1
    fi
else
    logger -t ${TAG} -p user.warn "${corsips} should be nonzero, ${ips}"
fi

for varname in multiproc scheme runuser privatekey cert baseuri passphrase tenant delhostrole allowcredauth; do
    localname="k2hr3_api_${varname}"
    varval=$(eval echo "\${$localname}")
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

#
# Replaces k2hdkc_config and k2hdkc_port
#
logger -t ${TAG} -p user.debug "perl -pi -e \"BEGIN{undef $/;} s|\"k2hdkc\":\s+\{.*\}|\"k2hdkc\": {\n        \"config\": \"${k2hr3_api_k2hdkc_config}\",\n        \"port\": ${k2hr3_api_k2hdkc_port}\n    }\n}|smg\" local_${COMPONENT}.json"
perl -pi -e "BEGIN{undef $/;} s|\"k2hdkc\":\s+\{.*\}|\"k2hdkc\": {\n        \"config\": \"${k2hr3_api_k2hdkc_config}\",\n        \"port\": ${k2hr3_api_k2hdkc_port}\n    }\n}|smg" local_${COMPONENT}.json
RESULT=$?
if test "${RESULT}" -ne 0; then
    logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
    exit 1
fi

########
# 13. Installs the configured local.json of the k2hr3-api package.
# You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#
logger -t ${TAG} -p user.debug "13. Installs the configured local.json of the k2hr3-api package"

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
