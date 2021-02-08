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
# A simple script to create a k2hr3-api server on localhost
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
VERSION=0.10.0
NPM_ARCHIVE_FILE=
IDENTITY_ENDPOINT=

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
        -h) usage_api;;
        -i) shift; IDENTITY_ENDPOINT="${1-}";;
        -r) DRYRUN=1;;
        -v) version;;
        *) break;;
    esac
    shift
done

# Determines the debug mode
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

# IDENTITY_ENDPOINT passed as an argument will override k2hr3_api_identity_endpoint defined in the ini file.
if test -n "${IDENTITY_ENDPOINT}"; then
    k2hr3_api_identity_endpoint=${IDENTITY_ENDPOINT}
    # update the value in setup_${COMPONENT}_${OS_NAME}.ini.
    for ini_file in ${SRCDIR}/setup_${COMPONENT}_${OS_NAME}.ini ${SRCDIR}/setup_${COMPONENT}_default.ini; do
        if test -f "${ini_file}"; then
            logger -t ${TAG} -p user.debug "configure_ini_file ${ini_file} k2hr3_api_identity_endpoint"
            configure_ini_file ${ini_file} k2hr3_api_identity_endpoint
            RET=$?
            if test "${RET}" -ne 0; then
                logger -t ${TAG} -p user.err "setup_ini_env should return zero, not ${RET}"
                exit 1
            fi
        else
            logger -t ${TAG} -p user.warn "${ini_file} not found. Skip updating"
        fi
    done
fi

########
# 2. Ensures that the k2hdkc data directory exists
# k2hr3_api saves the data to the data directory(for instance /var/k2hdkc/data).
#
logger -t ${TAG} -p user.info "2. Ensures that the k2hr3_api data directory exists"

# Loads functions defined in setup_chmpx_functions
if ! test -r "${SRCDIR}/../chmpx/setup_chmpx_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/../chmpx/setup_chmpx_functions should exist"
    exit 1
fi
. ./chmpx/setup_chmpx_functions

# Makes the k2hdkc data directory
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
# k2hr3_api saves the configuration file to the k2hdkc configuration directory(for instance /etc/k2hdkc) directory.
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
# 4. Adds new package repositories
# k2hr3_api needs Debian and RPM packages on https://packagecloud.io/antpickax/.
#
logger -t ${TAG} -p user.info "4. Adds a new package repository"

# Enables the packagecloud.io repo
enable_packagecloud_io_repository ${package_script_base_url-}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "enable_packagecloud_io_repository should return zero, not ${RET}"
    exit 1
fi

# Enables the nodesource repo
enable_nodesource_repository ${nodesource_url-}
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
# 5. Installs OS dependent packages
# k2hr3_api needs the nodejs, k2htpdtor, libfullock, k2hash, chmpx and k2hdkc package.
#
logger -t ${TAG} -p user.info "5. Installs OS dependent packages"

# Some distros pre-install k2hr3_api's required packages. In this case, users might
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
# 6. Configures the chmpx slave default configuration
# The default slave.ini contains dummy server name. You need to change it.
#
logger -t ${TAG} -p user.info "6. Configures the default chmpx slave configuration"

# Configures the chmpx slave default configuration file in INI file format
configure_chmpx_slave_ini ${SRCDIR}/../chmpx/slave.ini ${chmpx_server_name}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_chmpx_slave_ini should return zero, not ${RET}"
    exit 1
fi

########
# 7. Installs the configured chmpx slave config file
# k2hr3_api uses a configuration file(for instance /etc/k2hdkc/slave.ini) for chmpx.
#
logger -t ${TAG} -p user.info "7. Installs the configured chmpx slave config file"

# Installs the configured chmpx slave config file in INI format to ${chmpx_conf_file}
install_chmpx_ini ${SRCDIR}/../chmpx/slave.ini ${chmpx_conf_file}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_chmpx_ini should return zero, not ${RET}"
    exit 1
fi

########
# 8. Configures the chmpx slave's service manager default configuration
# We recommend chmpx slave process works as a service by systemd.
#
logger -t ${TAG} -p user.info "8. Configures the chmpx slave's service manager default configuration"

# Determines the service management file which file format depends on a service manager of the target OS
if test "${SERVICE_MANAGER}" = "systemd"; then
    service_manager_file=${SRCDIR}/../service_manager/chmpx-slave.service
else
    logger -t ${TAG} -p user.err "SERVICE_MANAGER must be either systemd, not ${SERVICE_MANAGER}"
    exit 1
fi
# Configures the chmpx's service manager default configuration
is_k2hdkc=0
configure_chmpx_service_manager_file ${SERVICE_MANAGER} ${service_manager_file} ${k2hr3_api_runuser} ${chmpx_conf_file} ${chmpx_msg_max} ${is_k2hdkc} ${chmpx_loglevel}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_chmpx_service_manager_file should return zero, not ${RET}"
    exit 1
fi

########
# 9. Installs the chmpx-slave service manager configuration and enables it
# systemd controls chmpx.
#
logger -t ${TAG} -p user.info "9. Installs the chmpx-slave service manager configuration and enables it"

install_service_manager_conf ${SERVICE_MANAGER} chmpx-slave
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# 10. Installs devel packages to build the k2hdkc node module.
# k2hdkc node module requires header files of libfullock, k2hash, chmpx and k2hdkc.
#
logger -t ${TAG} -p user.info "10. Installs devel packages to build the k2hdkc node module"

if test -n "${package_install_dev_pkgs}"; then
    setup_install_os_packages "${package_install_dev_pkgs}"
    RET=$?
    if test "${RET}" -ne 0; then
        logger -t ${TAG} -p user.err "setup_install_os_packages should return zero, not ${RET}"
        exit 1
    fi
else
    logger -t ${TAG} -p user.err "package_install_dev_pkgs should be nonzero, ${package_install_dev_pkgs}"
    exit 1
fi

########
# 11. Installs npm packages
# The k2hdkc node module requires node-gyp as a global npm package and nan as a local package.
# The k2hdkc npm package is a node addon package which provides the k2hdkc driver functions.
# The k2hr3-api package provies the REST APIs.
#
logger -t ${TAG} -p user.info "11. Installs npm packages"

if ! test -n "${npm_default_user}"; then
    logger -t ${TAG} -p user.err "npm_default_user should be nonzero, ${npm_default_user}"
    exit 1
fi
add_npm_user ${npm_default_user}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "add_npm_user should return zero, not ${RET}"
    exit 1
fi

setup_npm_userhome ${npm_default_user}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "setup_npm_userhome should return zero, not ${RET}"
    exit 1
fi

# Runs api/setup_api_node_module.sh as node command executer
node_api_module_sh="${SRCDIR}/setup_api_node_module.sh"

# Adds the DEBUG option if DEBUG is enabled
if test "${DEBUG}" -eq 1; then
    node_api_module_sh="${node_api_module_sh} -d"
fi

# Adds the NPM_ARCHIVE_FILE option if NPM_ARCHIVE_FILE exists
if test -n "${NPM_ARCHIVE_FILE}"; then
    if test -f "${NPM_ARCHIVE_FILE}"; then
        # Remenber to call 'basename' function
        # Because an archive file stays /home/k2hr3/k2hr3-api-0.0.1.tgz
        node_api_module_sh="${node_api_module_sh} -f $(basename ${NPM_ARCHIVE_FILE})"
    else
        logger -t ${TAG} -p user.err "${NPM_ARCHIVE_FILE} must be a URL"
        node_api_module_sh="${node_api_module_sh} -f ${NPM_ARCHIVE_FILE}"
    fi
fi

########
# setup_api_node_module.sh do the followings::
#   12. Configures the default local.json of the k2hr3-api package.
#   You need to change SSL certs path and add frontend server ip-addresses to the local.json.
#   13. Installs the configured local.json of the k2hr3-api package.
#   `k2hr3_api` node module uses it.
#

# Switches 'k2hr3' user and fork a new shell process::
#   $ sudo su - k2hr3 sh -c "sh ./setup_api_node_module.sh -d"
logger -t ${TAG} -p user.debug "sudo su - ${npm_default_user} sh -c \"${node_api_module_sh}\""
if test -z "${DRYRUN-}"; then
    sudo su - ${npm_default_user} sh -c "sh ${node_api_module_sh}"
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "RESULT should be zero, not ${RESULT}"
        exit 1
    fi
fi

# A workaround for root owner logs in the ${npm_run_user} directory
#
# Description on the problem::
#   The k2hr3-app's log file owner should be ${npm_default_user}, but the
#   current owner is root! This prevents from updating the k2hr3-api npm package.
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
# 14. Configures the k2hr3-api's service manager default configuration
# We recommend k2hr3-api processes work as a service by systemd.
#
logger -t ${TAG} -p user.info "14. Configures the k2hr3-api's service manager default configuration"

if ! test -r "${SRCDIR}/setup_${COMPONENT}_functions"; then
    logger -t ${TAG} -p user.err "${SRCDIR}/setup_${COMPONENT}_functions should exist"
    exit 1
fi
. ${SRCDIR}/setup_${COMPONENT}_functions

# Determines the service management file which file format depends on a service manager of the target OS
if test "${SERVICE_MANAGER}" = "systemd"; then
    service_manager_file=${SRCDIR}/../service_manager/k2hr3-api.service
else
    logger -t ${TAG} -p user.err "SERVICE_MANAGER must be either systemd, not ${SERVICE_MANAGER}"
    exit 1
fi
# Configures the k2hr3-api's service manager default configuration
configure_k2hr3_api_service_manager_file ${SERVICE_MANAGER} ${service_manager_file} ${k2hr3_api_runuser} ${node_debug} ${node_path}
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "configure_k2hr3_api_service_manager_file should return zero, not ${RET}"
    exit 1
fi

########
# 15. Installs the k2hr3-api service manager configuration and enables it
# systemd controls k2hr3-api
#
logger -t ${TAG} -p user.info "15. Installs the k2hr3-api service manager configuration and enables it"

install_service_manager_conf ${SERVICE_MANAGER} k2hr3-api
RET=$?
if test "${RET}" -ne 0; then
    logger -t ${TAG} -p user.err "install_service_manager_conf should return zero, not ${RET}"
    exit 1
fi

########
# Start the service!
#
logger -t ${TAG} -p user.debug "sudo systemctl restart chmpx-slave.service"
if test -z "${DRYRUN-}"; then
    sudo systemctl restart chmpx-slave.service
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "'sudo systemctl restart chmpx-slave.service' should return zero, not ${RESULT}"
        exit 1
    fi
fi

# A workaround for an old configuration value in k2hdkc
#
# Description on the problem::
#   "eplist" takes a region name as a key and an Identity service endpoint as a value.
#   ```
#   "eplist": {
#       "RegionOne": "http://172.16.0.1/identity"
#   }
#   ```
#   k2hr3-api saves the value as a subkey of "yrn:yahoo::::keystone" in k2hdkc.
#   Even if the value in the configuration file has updated, the value in k2hdkc will
#   not be updated. This confuse users who update the value in the configuration file.
#   because k2hr3-api still works under the previous(invisible) configurations.
#
# A workaround::
#   Deletes the region name key in cluster installation process. Every deployment
#   script should work idempotently for continuous integration.
#
logger -t ${TAG} -p user.debug "sleep 20 for chmpx-slave to start the service"
if test -z "${DRYRUN-}"; then
    sleep 20
    DATAFILE=/tmp/devcluster.data
    cat >> ${DATAFILE} << EOF
p yrn:yahoo::::keystone
rmsub yrn:yahoo::::keystone all
quit
EOF

    logger -t ${TAG} -p user.debug "sudo -u ${k2hr3_api_runuser} k2hdkclinetool -conf ${k2hr3_api_k2hdkc_config} -ctlport ${k2hr3_api_k2hdkc_port} -run ${DATAFILE}"
    sudo -u ${k2hr3_api_runuser} k2hdkclinetool -conf ${k2hr3_api_k2hdkc_config} -ctlport ${k2hr3_api_k2hdkc_port} -run ${DATAFILE}
    RESULT=$?
    if test "${RESULT}" -ne 0; then
        logger -t ${TAG} -p user.err "k2hdkclinetool should return zero, not ${RESULT}"
        exit 1
    fi


    logger -t ${TAG} -p user.debug "sudo systemctl restart k2hr3-${COMPONENT}.service"
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
