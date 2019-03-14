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
# A simple script to create a k2hr3-osnl server on localhost
#

# Sets the default locale. LC_ALL has precedence over other LC* variables.
unset LANG
unset LANGUAGE
LC_ALL=en_US.utf8
export LC_ALL

# Sets PATH. setup_*.sh uses useradd command
PATH=$PATH:/usr/sbin:/sbin

# an unset parameter expansion will fail
set -u

# umask 022 is enough
umask 022

# defines environments
COMPONENT=osnl
DEBUG=0
SRCDIR=$(cd $(dirname "$0") && pwd)
SERVICE_MANAGER_DIR=${SRCDIR}/../service_manager
STARTTIME=$(date +%s)
VERSION=0.9.1
PYPI_ARCHIVE_FILE=
TRANSPORT_URL=

if ! test -r "${SRCDIR}/../cluster_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../cluster_functions should exist"
    exit 1
fi
. ${SRCDIR}/../cluster_functions

# parses cli args
while true; do
    case "${1-}" in
        -d) DEBUG=1;;
        -f) shift; PYPI_ARCHIVE_FILE="${1-}";;
        -h) usage_osnl;;
        -r) DRYRUN=1;;
        -t) shift; TRANSPORT_URL="${1-}";;
        -v) version;;
        *) break;;
    esac
    shift
done

# determines the debug mode
if test "${DEBUG}" -eq 1; then
    TAG="$(basename $0) -s"
else
    TAG=$(basename $0)
fi

# The first message is always visible.
logger -t $(basename $0) -s -p user.info "$(basename $0) ${VERSION}"

########
# 1. Initializes environments.
# Detects the OS_NAME of the target host and load deploy configuration for the ${OS_NAME} if exists.
#
logger -t ${TAG} -p user.info "1. Initializes environments"

# Determines the current OS and service manager
setup_os_env
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_os_env should return zero, not ${RET}"
    exit 1
fi

# Loads default settings
setup_ini_env
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_ini_env should return zero, not ${RET}"
    exit 1
fi

# TRANSPORT_URL passed as an argument will override k2hr3_osnl_transport_url defined in the ini file.
if test -n "${TRANSPORT_URL}"; then
    k2hr3_osnl_transport_url=${TRANSPORT_URL}
fi

########
# 2. Adds new package repositories
# nodesource provides the nodejs v10 and npm.
#
logger -t ${TAG} -p user.info "2. Adds a new package repository"

# Set package repository(optional)
#
setup_package_repository ${corp_url-}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_package_repository should return zero, not ${RET}"
    exit 1
fi

########
# 3. Installs the system package(python3).
# python3 provides library to run k2hr3_osnl.
#
logger -t ${TAG} -p user.info "3. Installs system packages"

# Install system packages
#
setup_install_os_packages "${package_install_pkgs-}"
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_install_os_packages should return zero, not ${RET}"
    exit 1
fi

########
# 4. Installs the k2hr3-osnl pypi package
# k2hr3_osnl provides to listen to notification messages from OpenStack.
#
logger -t ${TAG} -p user.info "4. Installs the k2hr3-osnl pypi package"

# Install pypi packages
#
if ! test -r "${SRCDIR}/setup_${COMPONENT}_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/setup_${COMPONENT}_functions should exist"
    exit 1
fi
. ${SRCDIR}/setup_${COMPONENT}_functions

# Adds the PYPI_ARCHIVE_FILE option if PYPI_ARCHIVE_FILE defined
# Note: PYPI_ARCHIVE_FILE might be a URL.
setup_osnl_pypi_module ${PYPI_ARCHIVE_FILE}

RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_osnl_pypi_module should return zero, not ${RET}"
    exit 1
fi

########
# 5. Configures the k2hr3_onsl.conf.
# You need to change the K2hr3 API server and OpenStack Message Queue server.
#
logger -t ${TAG} -p user.info "5. Configures the k2hr3-onsl.conf and Installs it"

# Configures k2hr3-onsl.conf
#
for varname in api_url transport_url; do
    logger -t ${TAG} -p user.debug "configure_conf_file ${varname}"
    configure_conf_file ${SRCDIR}/k2hr3-osnl.conf ${varname} k2hr3_osnl_
    RET=$?
    if test "${RET}" -ne 0; then
        logger -t ${TAG} -p user.err "setup_osnl_conf ${varname} should return zero, not ${RET}"
        exit 1
    fi
done

#
# Installs k2hr3-onsl.conf
#
install_conf ${SRCDIR}/k2hr3-osnl.conf ${k2hr3_osnl_conf_file}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_conf k2hr3_osnl.conf ${k2hr3_osnl_conf_file} should return zero, not ${RET}"
    exit 1
fi

########
# 6. Installs a systemd configuration for k2hr3_osnl
# We recommend the k2hr3_osnl Python process works as a service by systemd.
logger -t ${TAG} -p user.info "6. Installs a systemd configuration for k2hr3_osnl"

enable_scl_python_path
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "enable_scl_python_path should return zero, not ${RET}"
    exit 1
fi

logger -t ${TAG} -p user.debug "which k2hr3-osnl"
k2hr3_osnl_file=$(which k2hr3-osnl)
if test "${k2hr3_osnl_file}" = ""; then
    logger -t ${TAG} -p user.err "k2hr3-osnl should found, not ${k2hr3_osnl_file}"
    exit 1
fi

configure_osnl_service_manager_conf ${SERVICE_MANAGER} k2hr3-osnl ${k2hr3_osnl_runuser-} ${k2hr3_osnl_conf_file-} ${k2hr3_osnl_file-}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_osnl_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# 7. Registers and enables k2hr3_osnl to systemd
# systemd controls k2hr3_osnl Python process.
logger -t ${TAG} -p user.info "7. Registers and enables k2hr3_osnl to systemd"

install_service_manager_conf ${SERVICE_MANAGER} k2hr3-osnl
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# Start the service!
#
logger -t ${TAG} -p user.debug "sudo systemctl restart k2hr3-${COMPONENT}.service"
if test -z "${DRYRUN-}"; then
    sudo systemctl restart k2hr3-${COMPONENT}.service
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "'sudo systemctl restart k2hr3-${COMPONENT}.service' should return zero, not ${RESULT}"
        exit 1
    fi
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
