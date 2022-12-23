#!/bin/sh
#
# K2HR3 Utilities
#
# Copyright 2018 Yahoo Japan Corporation.
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
# CREATE:   Tue Nov 12 2019
# REVISION:
#

# This program puts ansible vault password as a file in the working directory
# This program decode base64 encoded data and decrypts it and puts it as a file in the working directory

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
TAG=$(basename $0 -s)
VAULT_PASSWORD=${1-}
SSLKEY=${2-}
SSLKEY_FILE=${3-}

if test -z "${VAULT_PASSWORD}"; then
	logger -t ${TAG} -p user.err "Usage: init.sh password [encrypted-sslkey] [decrypted-sslkey]"
	exit 1
fi

cat <<EOF>.vault_password
${VAULT_PASSWORD}
EOF
if ! test -f ".vault_password" ; then
	logger -t ${TAG} -p user.err "[ERROR] .vault_password file does not exist"
	exit 1
fi

# defined SSLKEY should be base64 decoded.
if test -n "${SSLKEY}" -a -n "${SSLKEY_FILE}"; then
	cat <<EOF>${SSLKEY_FILE}.base64
${SSLKEY}
EOF
	base64 -d ${SSLKEY_FILE}.base64 | tee ${SSLKEY_FILE}

	# ensures SSLKEY file exists
	if ! test -f "${SSLKEY_FILE}" ; then
		logger -t ${TAG} -p user.err "[ERROR] ${SSLKEY_FILE} file does not exist"
		exit 1
	fi
	# decrypts SSLKEY file
	if ! test -z "${SSLKEY}"; then
		ansible-vault decrypt --vault-password-file=.vault_password ${SSLKEY_FILE}
		if test "${?}" != 0; then
			logger -t ${TAG} -p user.err "[ERROR] ansible-vault decryption error"
			exit 1
		fi
	fi
fi

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
