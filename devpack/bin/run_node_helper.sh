#!/bin/sh
#
# K2HR3 DevPack in K2HR3 Utilities
#
# Copyright 2020 Yahoo! Japan Corporation.
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
# AUTHOR:   Takeshi Nakatani
# CREATE:   Tue Oct 20 2020
# REVISION:
#

#
# [NOTE]
# We need to set an arbitrary umask when running npm with sudo.
# However, it is assumed that umask cannot be specified due to system sudoers.
# So instead of running npm directly with sudo, run it via this script.
# This script sets the umask before running npm.
#
if [ $# -ne 1 ]; then
	exit 1
fi

BASE_DIR=$1
if [ ! -d ${BASE_DIR} ]; then
	exit 1
fi
cd ${BASE_DIR} >/dev/null 2>&1

OLD_UMASK=`umask`
umask 0000

npm run start
if [ $? -ne 0 ]; then
	exit $?
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
