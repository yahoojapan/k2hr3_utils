K2HR3 Utilities(k2hr3-utils)
============================
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/yahoojapan/k2hr3_utils/blob/master/COPYING)
[![GitHub forks](https://img.shields.io/github/forks/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/network)
[![GitHub stars](https://img.shields.io/github/stars/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/issues)

This repository contains utilities for [K2HR3](https://k2hr3.antpick.ax/), which is a role-based ACL system developed in [Yahoo Japan Corporation](https://about.yahoo.co.jp/info/en/company/)

## **K2HR3** - **K2H**dkc based **R**esource and **R**oles and policy **R**ules

![K2HR3 system](https://k2hr3.antpick.ax/images/top_k2hr3.png)

[K2HR3](https://k2hr3.antpick.ax/) is a RBAC (Role Based Access Control) system. [K2HR3](https://k2hr3.antpick.ax/) is designed to primarily work in a private cloud environment, which is dedicated to deliver services to a single organization. [K2HR3](https://k2hr3.antpick.ax/)-0.9.0 works with [OpenStack](https://www.openstack.org/).

The primary feature is called **+SERVICE** that enables service owners in cloud environments to control their resources. [K2HR3](https://k2hr3.antpick.ax/) as a RBAC system defines the three primary elements: role, rule(or policy rule) and resource. Every host is defined as a member of roles in [K2HR3](https://k2hr3.antpick.ax/) and a host can access resources in a way followed by rules.

* Role  
  Defines a collection of a host(or an IP address) that access assets in a service.
* Rule(or Policy Rule)  
  Defines a group of actions(read and write) over assets in a service and a permission(allow or deny) to the group of actions.
* Resource  
  Defines a value(string or object) as an asset in a service. A value can contains data in any form: text or binary. A text data can be a key, a token or an URL.

![K2HR3 system overview](https://k2hr3.antpick.ax/images/overview_abstract.png)

### K2HR3 System Overview

The following figure shows the [K2HR3](https://k2hr3.antpick.ax/) system overview.

![K2HR3 Setup overview](https://k2hr3.antpick.ax/images/setup_overview.png)

## K2HR3 Utilities

We provide the following utilities for [K2HR3](https://k2hr3.antpick.ax/).

- [devcluster/](/devcluster)  
  A tool to quickly bring up a complete K2HR3 system in a Linux(Debian9, Ubuntu18.04, Fedora29 or CentOS7) host.
- [devpack/](/devpack)  
  A tool to build a trial environment of K2HR3 system in one host.

## Documents

Here are documents including other components.

[K2HR3 Document](https://k2hr3.antpick.ax/index.html)  
[K2HR3 Web Application Usage](https://k2hr3.antpick.ax/usage_app.html)  
[K2HR3 REST API Usage](https://k2hr3.antpick.ax/api.html)  
[K2HR3 OpenStack Notification Listener Usage](https://k2hr3.antpick.ax/detail_osnl.html)  
[K2HR3 Watcher Usage](https://k2hr3.antpick.ax/tools.html)  
[K2HR3 Get Resource Usage](https://k2hr3.antpick.ax/tools.html)  
[K2HR3 Utilities for Setup](https://k2hr3.antpick.ax/setup.html)  
[K2HR3 Demonstration](https://demo.k2hr3.antpick.ax/)  

[About k2hdkc](https://k2hdkc.antpick.ax/)  
[About k2hash](https://k2hash.antpick.ax/)  
[About chmpx](https://chmpx.antpick.ax/)  
[About k2hash transaction plugin](https://k2htpdtor.antpick.ax/)  

[About AntPickax](https://antpick.ax/)  

## Repositories

Here are repositories including other components.

[K2HR3 main repository](https://github.com/yahoojapan/k2hr3)  
[K2HR3 Web Application repository](https://github.com/yahoojapan/k2hr3_app)  
[K2HR3 REST API repository](https://github.com/yahoojapan/k2hr3_api)  
[K2HR3 OpenStack Notification Listener](https://github.com/yahoojapan/k2hr3_osnl)  
[K2HR3 Utilities](https://github.com/yahoojapan/k2hr3_utils)  
[K2HR3 Container Registration Sidecar](https://github.com/yahoojapan/k2hr3_sidecar)  
[K2HR3 Get Resource](https://github.com/yahoojapan/k2hr3_get_resource)  

[k2hdkc](https://github.com/yahoojapan/k2hdkc)  
[k2hash](https://github.com/yahoojapan/k2hash)  
[chmpx](https://github.com/yahoojapan/chmpx)  
[k2hash transaction plugin](https://github.com/yahoojapan/k2htp_dtor)  

## Packages

Here are packages including other components.

[k2hr3-app(npm packages)](https://www.npmjs.com/package/k2hr3-app)  
[k2hr3-api(npm packages)](https://www.npmjs.com/package/k2hr3-api)  
[k2hr3-osnl(python packages)](https://pypi.org/project/k2hr3-osnl/)  
[k2hr3.sidecar(dockerhub)](https://hub.docker.com/r/antpickax/k2hr3.sidecar)  
[k2hr3-get-resource(packages)](https://packagecloud.io/app/antpickax/stable/search?q=k2hr3-get-resource)  

## License

This software is released under the MIT License, see the license file(COPYING).

## AntPickax

[AntPickax](https://antpick.ax/) is an open source team in [Yahoo Japan Corporation](https://about.yahoo.co.jp/info/en/company/).
