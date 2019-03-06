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

# A simple script to easily create a k2hr3 system on localhost
#
# This script installs k2hr3 system on localhost. It calls each of following
# four subcommands sequentially:
#
#   1. dkc/setup_dkc_main.sh
#      Constructs a k2hr3-dkc distributed cluster.
#   2. api/setup_api_main.sh
#      Constructs a k2hr3-api server.
#   3. app/setup_app_main.sh
#      Constructs a k2hr3-app server.
#   4. osnl/setup_osnl_main.sh
#      Constructs a k2hr3-osnl server.
#
# Every processes will start soon after reboot by service manager, systemd.
#

# Sets the default locale. LC_ALL has precedence over other LC* variables.
unset LANG
unset LANGUAGE
LC_ALL=en_US.utf8
export LC_ALL

# Sets PATH. setup_*.sh uses useradd command
PATH=${PATH}:/usr/sbin:/sbin

# Defines environments
API_NPM_ARCHIVE_FILE=
APP_NPM_ARCHIVE_FILE=
OSNL_PYPI_ARCHIVE_FILE=
IDENTITY_ENDPOINT=
TRANSPORT_URL=
VERSION=0.0.1
CLUSTER_STARTTIME=$(date +%s)

usage_cluster() {
    echo "usage : $(basename $0) [-d] [-f file] [-o file] [-p file] [-h] [-t url] [-v]"
    echo "    -d        print debug messages"
    echo "    -i file   k2hr3-api package file path(or URL)"
    echo "    -o file   k2hr3-osnl package file path(or URL)"
    echo "    -p file   k2hr3-app package file path(or URL)"
    echo "    -h        display this message and exit"
    echo "    -s url    OpenStack Identity Service Endpoint(Default: 'http://127.0.0.1/identity')"
    echo "    -t url    TransportURL(Default: 'rabbit://guest:guest@127.0.0.1:5672/')"
    echo "    -v        display version and exit"
    echo ""
    exit 1
}

# parses cli args
while true; do
    case "${1-}" in
        -d) DEBUG=1;;
        -h) usage_cluster;;
        -i) shift; API_NPM_ARCHIVE_FILE="${1-}";;
        -o) shift; OSNL_PYPI_ARCHIVE_FILE="${1-}";;
        -p) shift; APP_NPM_ARCHIVE_FILE="${1-}";;
        -s) shift; IDENTITY_ENDPOINT="${1-}";;
        -t) shift; TRANSPORT_URL="${1-}";;
        -v) version;;
        *) break;;
    esac
    shift
done

# The first message is always visible.
logger -t $(basename $0) -s -p user.info "$(basename $0) ${VERSION}"

for component in dkc api app osnl; do
    SCRIPT=${component}/setup_${component}.sh
    if test -f "${SCRIPT}"; then
        if test -n "${DEBUG}"; then
            SCRIPT="${SCRIPT} -d"
        fi
        case "${component}" in
            dkc)
                logger -t $(basename $0) -s -p user.info "sh ${SCRIPT}"
                sh ${SCRIPT}
            ;;
            api)
                logger -t $(basename $0) -s -p user.info "sh ${SCRIPT} -f ${API_NPM_ARCHIVE_FILE} -i ${IDENTITY_ENDPOINT}"
                sh ${SCRIPT} -f ${API_NPM_ARCHIVE_FILE} -i ${IDENTITY_ENDPOINT}
            ;;
            app)
                logger -t $(basename $0) -s -p user.info "sh ${SCRIPT} -f ${APP_NPM_ARCHIVE_FILE}"
                sh ${SCRIPT} -f ${APP_NPM_ARCHIVE_FILE}
            ;;
            osnl)
                logger -t $(basename $0) -s -p user.info "sh ${SCRIPT} -f ${OSNL_PYPI_ARCHIVE_FILE} -t ${TRANSPORT_URL}"
                sh ${SCRIPT} -f ${OSNL_PYPI_ARCHIVE_FILE} -t ${TRANSPORT_URL}
            ;;
            *) break;;
        esac
        if test "${?}" != 0; then
            logger -t $(basename $0) -s -p user.error "[ERROR] ${SCRIPT} should return 0"
            exit 1
        fi
    else
        logger -t $(basename $0) -s -p user.err "[ERROR] no ${SCRIPT}"
        exit 1
    fi
done

# The final message displays the time elapsed.
ELAPSED=$(expr $(date +%s) - ${CLUSTER_STARTTIME})
logger -t $(basename $0) -s -p user.info "completed in ${ELAPSED} seconds"

exit 0

#
# VIM modelines
#
# vim:set ts=4 fenc=utf-8:
#
