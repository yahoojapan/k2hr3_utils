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


function setup_service_manager {
	logger -t ${TAG} -p user.info "default.sh setup_service_manager"

	########
	# 9. Enables the chmpx service manager
	# systemd controls chmpx.
	#
	logger -t ${TAG} -p user.info "9. Enables the chmpx service manager configuration"

	enable_service_manager ${SERVICE_MANAGER} chmpx
	RET=$?
	if test "${RET}" -ne 0; then
		logger -t ${TAG} -p user.err "enable_service_manager should return zero, not ${RET}"
		exit 1
	fi

	########
	# 11. Enables Installs the k2hdkc service manager configuration
	# systemd controls k2hdkc
	#
	logger -t ${TAG} -p user.info "11. Enables the k2hdkc service manager configuration"

	enable_service_manager ${SERVICE_MANAGER} k2hdkc
	RET=$?
	if test "${RET}" -ne 0; then
		logger -t ${TAG} -p user.err "enable_service_manager should return zero, not ${RET}"
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
	logger -t ${TAG} -p user.info "default.sh setup_service_manager done"
	return 0
}

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
