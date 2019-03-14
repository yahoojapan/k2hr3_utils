K2HR3 Utilities(k2hr3-utils)
----------------------------
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/yahoojapan/k2hr3_utils/blob/master/COPYING)
[![GitHub forks](https://img.shields.io/github/forks/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/network)
[![GitHub stars](https://img.shields.io/github/stars/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/yahoojapan/k2hr3_utils.svg)](https://github.com/yahoojapan/k2hr3_utils/issues)
[![CodeFactor](https://www.codefactor.io/repository/github/yahoojapan/k2hr3_utils/badge)](https://www.codefactor.io/repository/github/yahoojapan/k2hr3_utils)

This repository contains utilities for [K2HR3](https://k2hr3.antpick.ax/), which is a role-based ACL system developed in [Yahoo Japan Corporation](https://about.yahoo.co.jp/info/en/company/)

## **K2HR3** - **K2H**dkc based **R**esource and **R**oles and policy **R**ules

![K2HR3 system](https://k2hr3.antpick.ax/images/top_k2hr3.png)

### K2HR3 system overview
**K2HR3** (**K2H**dkc based **R**esource and **R**oles and policy **R**ules) is one of extended **RBAC** (**R**ole **B**ased **A**ccess **C**ontrol) system.  
K2HR3 works as RBAC in cooperation with **OpenStack** which is one of **IaaS**(Infrastructure as a Service), and also provides useful functions for using RBAC.  

K2HR3 is a system that defines and controls **HOW**(policy Rule), **WHO**(Role), **WHAT**(Resource), as RBAC.  
Users of K2HR3 can define **Role**(WHO) groups to access freely defined **Resource**(WHAT) and control access by **policy Rule**(HOW).  
By defining the information and assets required for any system as a **Resource**(WHAT), K2HR3 system can give the opportunity to provide access control in every situation.  

K2HR3 provides **+SERVICE** feature, it **strongly supports** user system, function and information linkage.

![K2HR3 system overview](https://k2hr3.antpick.ax/images/overview_abstract.png)

K2HR3 is built [k2hdkc](https://github.com/yahoojapan/k2hdkc), [k2hash](https://github.com/yahoojapan/k2hash), [chmpx](https://github.com/yahoojapan/chmpx) and [k2hash transaction plugin](https://github.com/yahoojapan/k2htp_dtor) components by [AntPickax](https://antpick.ax/).

### K2HR3 Utilities
**K2HR3 Utilities** is a utility for the quick setup K2HR3 system.  
This will easily set up all the subcomponents of the K2HR3 system([K2HR3 Web Application](https://k2hr3.antpick.ax/usage_app.html) and Web Server, [K2HR3 REST API](https://k2hr3.antpick.ax/api.html), K2HR3 Data Server([k2hdkc](https://github.com/yahoojapan/k2hdkc)), [K2HR3 OpenStack Notification Listener](https://k2hr3.antpick.ax/detail_osnl.html)).
You can test the K2HR3 system in this environment.
**Before using K2HR3 Utilities**, OpenStack must be set up in the your environment.

**How to use K2HR3 Utilities** is explained in [K2HR3 Setup](https://k2hr3.antpick.ax/setup.html).
- [devcluster/](/devcluster)  
  A tool to create a `K2HR3` system in localhost

### Documents
[K2HR3 Document](https://k2hr3.antpick.ax/indexja.html)  
[K2HR3 Web Application Usage](https://k2hr3.antpick.ax/usage_app.html)  
[K2HR3 REST API Usage](https://k2hr3.antpick.ax/api.html)  
[K2HR3 OpenStack Notification Listener Usage](https://k2hr3.antpick.ax/detail_osnl.html)  
[K2HR3 Watcher Usage](https://k2hr3.antpick.ax/tools.html)  
[K2HR3 Utilities for Setup](https://k2hr3.antpick.ax/setup.html)  

[About k2hdkc](https://k2hdkc.antpick.ax/)  
[About k2hash](https://k2hash.antpick.ax/)  
[About chmpx](https://chmpx.antpick.ax/)  
[About k2hash transaction plugin](https://k2htpdtor.antpick.ax/)  

[About AntPickax](https://antpick.ax/)  

### Repositories
[K2HR3 main repository](https://github.com/yahoojapan/k2hr3)  
[K2HR3 Web Application repository](https://github.com/yahoojapan/k2hr3_app)  
[K2HR3 REST API repository](https://github.com/yahoojapan/k2hr3_api)  
[K2HR3 OpenStack Notification Listener](https://github.com/yahoojapan/k2hr3_osnl)  
[K2HR3 Utilities](https://github.com/yahoojapan/k2hr3_utils)  

[k2hdkc](https://github.com/yahoojapan/k2hdkc)  
[k2hash](https://github.com/yahoojapan/k2hash)  
[chmpx](https://github.com/yahoojapan/chmpx)  
[k2hash transaction plugin](https://github.com/yahoojapan/k2htp_dtor)  

### License
This software is released under the MIT License, see the license file.

### AntPickax
K2HR3 is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2018 Yahoo Japan Corporation.
