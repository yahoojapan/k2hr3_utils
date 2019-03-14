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
# A simple script to create a k2hr3-app server on localhost
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

if ! test -r "${SRCDIR}/../cluster_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../cluster_functions should exist"
    exit 1
fi
. ${SRCDIR}/../cluster_functions

# Parses cli args
while true; do
    case "${1-}" in
        -d) DEBUG=1;;
        -f) shift; NPM_ARCHIVE_FILE="${1-}";;
        -h) usage;;
        -r) DRYRUN=1;;
        -v) version;;
        *) break;;
    esac
    shift
done

# DEBUG determines the logger option
if test "${DEBUG}" -eq 1; then
    TAG="$(basename $0) -s"
else
    TAG=$(basename $0)
fi

# The first message is always visible.
logger -t $(basename $0) -s -p user.info "$(basename $0) ${VERSION}"

########
# 1. Initializes environments.
# Sets the OS_NAME of the target host and loads the ${OS_NAME}.ini if exists.
#
logger -t ${TAG} -p user.info "1. Initializes environments"

if ! test -r "${SRCDIR}/../cluster_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../cluster_functions should exist"
    exit 1
fi
. ${SRCDIR}/../cluster_functions

# Sets the current OS and the service manager
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

########
# 2. Adds new package repositories
# nodesource provides the nodejs v10 and npm.
#
logger -t ${TAG} -p user.info "2. Adds a new package repository"

# Enables the packagecloud.io repo for the future usage
enable_packagecloud_io_repository ${package_script_base_url-}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "enable_packagecloud_io_repository should return zero, not ${RET}"
    exit 1
fi

# Enables the nodesource repo
enable_nodesource_repository ${nodesource_url}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "enable_nodesource_repository should return zero, not ${RET}"
    exit 1
fi

# Enables the softwarecollections repo
if test "${OS_NAME}" = "centos"; then
    setup_package_repository ${copr_url-}
    RET=$?
    if test "${RET}" -ne 0; then
        logger -t ${TAG} -p user.err "setup_package_repository should return zero, not ${RET}"
        exit 1
    fi
fi

########
# 3. Installs OS dependent packages
# k2hr3_app needs the nodejs.
#
logger -t ${TAG} -p user.info "3. Installs OS dependent packages"

# Some distros pre-install k2hr3_app's required packages. In this case, users might
# define empty ${package_install_pkg} value in their initial configuration file.
# We call the setup_install_os_packages function if package_install_pkgs defined.
if test -n "${package_install_pkgs-}"; then
    setup_install_os_packages "${package_install_pkgs-}"
    RET=$?
    if test "${RET}" -ne 0; then
        logger -t ${TAG} -p user.err "setup_install_os_packages should return zero, not ${RET}"
        exit 1
    fi
else
    logger -t ${TAG} -p user.err "package_install_pkgs is zero"
fi

########
# 4. Install the k2hr3-app npm package
# The k2hr3-app package provides an interactive UIs.
#
logger -t ${TAG} -p user.info "4. Install the k2hr3-app npm package"

if ! test -n "${npm_default_user}"; then
    logger -t ${TAG} -p user.err "npm_default_user should be nonzero, ${npm_default_user}"
    exit 1
fi

add_npm_user "${npm_default_user}"
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "add_npm_user should return zero, not ${RET}"
    exit 1
fi

setup_npm_userhome "${npm_default_user}"
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_npm_userhome should return zero, not ${RET}"
    exit 1
fi

# Runs app/setup_app_node_module.sh as node command executer
app_node_module_sh="./setup_app_node_module.sh -t ${TAG}"

# Adds the DEBUG option if DEBUG is enabled
if test "${DEBUG}" -eq 1; then
    app_node_module_sh="${app_node_module_sh} -d"
fi

# Adds the NPM_ARCHIVE_FILE option if NPM_ARCHIVE_FILE exists
if test -n "${NPM_ARCHIVE_FILE}"; then
    if test -f "${NPM_ARCHIVE_FILE}"; then
        # Remenber to call 'basename' function
        # Because an archive file stays /home/k2hr3/k2hr3-app-0.0.1.tgz
        app_node_module_sh="${app_node_module_sh} -f $(basename ${NPM_ARCHIVE_FILE})"
    else
        logger -t ${TAG} -p user.debug "${NPM_ARCHIVE_FILE} must be a URL"
        app_node_module_sh="${app_node_module_sh} -f ${NPM_ARCHIVE_FILE}"
    fi
fi

########
# setup_app_node_module.sh do the followings::
#   5. Configures the default local.json of the k2hr3-app package.
#   You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#   6. Installs the configured local.json of the k2hr3-app package.
#   `k2hr3_app` node module uses it.
#

# Switches 'k2hr3' user and fork a new shell process::
#   $ sudo su - k2hr3 sh -c "sh ./setup_app_node_module.sh -d"
logger -t ${TAG} -p user.info "sudo su - ${npm_default_user} sh -c \"${app_node_module_sh}\""
if test -z "${DRYRUN-}"; then
    sudo su - ${npm_default_user} sh -c "sh ${app_node_module_sh}"
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
        exit 1
    fi
fi

# A workaround for the root owned log file problem.
#
# Description on the problem::
#   The k2hr3-app's log file owner should be ${npm_default_user}, but currently owner is root!
#   In this situation, installation will fail.
#
# A workaround::
#   Changes the file owner to the "right" owner, ${npm_default_user} again.
#
patch_for_change_logdir_owner ${npm_default_user}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_npm_userhome should return zero, not ${RET}"
    exit 1
fi

########
# 7. Configures the k2hr3-app's service manager default configuration
# We recommend k2hr3-app processes work as a service by systemd.
#
logger -t ${TAG} -p user.info "7. Configures the k2hr3-app's service manager default configuration"
if ! test -r "${SRCDIR}/setup_${COMPONENT}_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/setup_${COMPONENT}_functions should exist"
    exit 1
fi
. ${SRCDIR}/setup_${COMPONENT}_functions

# Determines the service management file which file format depends on a service manager of the target OS
if test "${SERVICE_MANAGER}" = "systemd"; then
    service_manager_file=${SRCDIR}/../service_manager/k2hr3-app.service
else
    logger -t ${TAG} -p user.err "SERVICE_MANAGER must be either systemd, not ${SERVICE_MANAGER}"
    exit 1
fi
# Configures the k2hr3-app's service manager default configuration
configure_k2hr3_app_service_manager_file ${SERVICE_MANAGER} ${service_manager_file} ${k2hr3_app_runuser} ${node_debug}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_k2hr3_app_service_manager_file should return zero, not ${RET}"
    exit 1
fi

########
# 8. Installs the k2hr3-app service manager configuration and enables it
# systemd controls k2hr3-app
#
logger -t ${TAG} -p user.info "8. Installs the k2hr3-app service manager configuration and enables it"

install_service_manager_conf ${SERVICE_MANAGER} k2hr3-app
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
