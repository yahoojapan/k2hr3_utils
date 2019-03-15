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
# A simple script to create a k2hr3-dkc server on localhost
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

# defines environments
COMPONENT=dkc
DEBUG=0
SRCDIR=$(cd $(dirname "$0") && pwd)
SERVICE_MANAGER_DIR=${SRCDIR}/../service_manager
STARTTIME=$(date +%s)
VERSION=0.9.1

if ! test -r "${SRCDIR}/../cluster_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../cluster_functions should exist"
    exit 1
fi
. ${SRCDIR}/../cluster_functions

# parses cli args
while true; do
    case "${1-}" in
        -d) DEBUG=1;;
        -h) usage_dkc;;
        -r) DRYRUN=1;;
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

########
# 2. Ensures that the k2hdkc data directory exists
# k2hr3_dkc saves the data to the data directory(for instance /var/k2hdkc/data).
#
logger -t ${TAG} -p user.info "2. Ensures that the k2hdkc data directory exists"

# Loads functions defined in setup_chmpx_functions
if ! test -r "${SRCDIR}/../chmpx/setup_chmpx_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../chmpx/setup_chmpx_functions should exist"
    exit 1
fi
. ./chmpx/setup_chmpx_functions

# Makes the k2hrkc data directory
runuser_varname=k2hr3_${COMPONENT}_runuser
runuser=$(eval echo "\${$runuser_varname}")
make_k2hdkc_data_dir ${runuser} ${k2hdkc_data_dir}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "make_k2hdkc_data_dir should return zero, not ${RET}"
    exit 1
fi

########
# 3. Ensures that the k2hdkc configuration directory exists
# k2hr3_dkc saves the configuration file to the k2hdkc configuration directory(for instance /etc/k2hdkc) directory.
#
logger -t ${TAG} -p user.info "3. Ensures that the k2hdkc configuration directory exists"

# Makes the k2hdkc configuration directory
k2hdkc_conf_dir=$(dirname ${chmpx_conf_file})
make_k2hdkc_conf_dir ${k2hdkc_conf_dir}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "make_k2hdkc_conf_dir should return zero, not ${RET}"
    exit 1
fi

########
# 4. Adds a new package repository
# k2hr3_dkc needs Debian and RPM packages on https://packagecloud.io/antpickax/.
#
logger -t ${TAG} -p user.info "4. Adds a new package repository"

# Enables the packagecloud.io repo
enable_packagecloud_io_repository ${package_script_base_url}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "enable_packagecloud_io_repository should return zero, not ${RET}"
    exit 1
fi

########
# 5. Installs OS dependent packages
# k2hr3_dkc needs the k2htpdtor, libfullock, k2hash, chmpx and k2hdkc.
#
logger -t ${TAG} -p user.info "5. Installs OS dependent packages"

# Some distros pre-install dkc required packages. In this case, users define
# empty ${package_install_pkg} value in their initial configuration file.
if test -n "${package_install_pkgs-}"; then
    setup_install_os_packages "${package_install_pkgs-}"
    RET=$?
    if test "${RET}" -ne 0; then
        logger -t ${TAG} -p user.err "setup_install_os_packages should return zero, not ${RET}"
        exit 1
    fi
fi

########
# 6. Configures the chmpx default configuration
# The default server.ini contains dummy server name. You need to change it.
#
logger -t ${TAG} -p user.info "6. Configures the default chmpx configuration"

# Configures the chmpx default configuration file in INI file format
configure_chmpx_server_ini ${SRCDIR}/../chmpx/server.ini ${chmpx_server_name} ${k2hdkc_data_dir}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_chmpx_server_ini should return zero, not ${RET}"
    exit 1
fi

########
# 7. Installs the configured chmpx config file
# k2hr3_dkc uses a configuration file(for instance /etc/k2hdkc/server.ini) for chmpx.
#
logger -t ${TAG} -p user.info "7. Installs the configured chmpx config file"

# Installs the configured chmpx config file in INI format to ${chmpx_conf_file}
install_chmpx_ini ${SRCDIR}/../chmpx/server.ini ${chmpx_conf_file}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_chmpx_ini should return zero, not ${RET}"
    exit 1
fi

########
# 8. Configures the chmpx's service manager default configuration
# We recommend chmpx process works as a service by systemd.
#
logger -t ${TAG} -p user.info "8. Configures the chmpx's service manager default configuration"

# Determines the service management file which file format depends on a service manager of the target OS
if test "${SERVICE_MANAGER}" = "systemd"; then
    service_manager_file=${SRCDIR}/../service_manager/chmpx.service
else
    logger -t ${TAG} -p user.err "SERVICE_MANAGER must be either systemd, not ${SERVICE_MANAGER}"
    exit 1
fi
# Configures the chmpx's service manager default configuration
is_k2hdkc=0
configure_chmpx_service_manager_file ${SERVICE_MANAGER} ${service_manager_file} ${k2hr3_dkc_runuser} ${chmpx_conf_file} ${chmpx_msg_max} ${is_k2hdkc} ${chmpx_loglevel}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_chmpx_service_manager_file should return zero, not ${RET}"
    exit 1
fi

########
# 9. Installs the chmpx service manager configuration and enables it
# systemd controls chmpx.
#
logger -t ${TAG} -p user.info "9. Installs the chmpx service manager configuration and enables it"

install_service_manager_conf ${SERVICE_MANAGER} chmpx
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# 10. Configures the k2hdkc's service manager default configuration
# We recommend k2hdkc processes work as a service by systemd.
#
logger -t ${TAG} -p user.info "10. Configures the k2hdkc's service manager default configuration"

# Determines the service management file which file format depends on a service manager of the target OS
if test "${SERVICE_MANAGER}" = "systemd"; then
    service_manager_file=${SRCDIR}/../service_manager/k2hdkc.service
else
    logger -t ${TAG} -p user.err "SERVICE_MANAGER must be either systemd, not ${SERVICE_MANAGER}"
    exit 1
fi
# Configures the k2hdkc's service manager default configuration
is_k2hdkc=1
configure_chmpx_service_manager_file ${SERVICE_MANAGER} ${service_manager_file} ${k2hr3_dkc_runuser} ${chmpx_conf_file} ${chmpx_msg_max} ${is_k2hdkc} ${k2hdkc_loglevel}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_chmpx_service_manager_file should return zero, not ${RET}"
    exit 1
fi

########
# 11. Installs the k2hdkc service manager configuration and enables it
# systemd controls k2hdkc
#
logger -t ${TAG} -p user.info "11. Installs the k2hdkc service manager configuration and enables it"

install_service_manager_conf ${SERVICE_MANAGER} k2hdkc
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# Start the service!
#
logger -t ${TAG} -p user.debug "sudo systemctl restart chmpx.service"
if test -z "${DRYRUN-}"; then
    sudo systemctl restart chmpx.service
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "'sudo systemctl restart chmpx.service' should return zero, not ${RESULT}"
        exit 1
    fi

    logger -t ${TAG} -p user.debug "sudo systemctl restart k2hdkc.service"
    sudo systemctl restart k2hdkc.service
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "'sudo systemctl restart k2hdkc.service' should return zero, not ${RESULT}"
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
