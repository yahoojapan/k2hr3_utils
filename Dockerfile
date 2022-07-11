# syntax=docker/dockerfile:1
#
# K2HR3 K2HR3 Utilities
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
# AUTHOR:   Hirotaka Wakabayashi
# CREATE:   Thu, 14 Nov 2019
# REVISION:
#

# [See]
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
# https://docs.docker.com/develop/develop-images/multistage-build/

FROM python:3.6-alpine as build

RUN apk --update --no-cache add build-base libffi-dev openssl-dev
RUN pip3 install --upgrade pip
RUN pip3 install --prefix=/install ansible

FROM python:3.6-alpine

LABEL maintainer="antpickax@mail.yahoo.co.jp"

RUN mkdir /lib64 \
    && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2 \
    && apk --update --no-cache add git curl openssh-client rsync bash

COPY --from=build /install /usr/local

WORKDIR /ansible

CMD [ "ansible-playbook", "--version" ]

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
