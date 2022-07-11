# k2hr3 installation for development

This guide provides instructions on a k2hr3 system installation for development.

## TLDR

The following commands will create your own k2hr3 system in localhost.

```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git && cd k2hr3_utils/devcluster
$ sh cluster.sh \
   -s http://127.0.0.1/identity \
   -t rabbit://guest:guest@127.0.0.1:5672/
```

As you see, you must pass two arguments at least:
* An OpenStack Identity Endpoint URL  
  For example, 'http://127.0.0.1/identity' which means an identity server works in localhost.
* An OpenStack Message Broker Server URL  
  For example, 'rabbit://guest:guest@127.0.0.1:5672/' means a RabbitMQ server works in localhost. The user 'guest' with the password 'guest' can login.  

## k2hr3 architecture overview

This chapter describes the k2hr3 system overview. k2hr3 consists of the following 5 components.

* k2hr3_app  
  provides an interactive UIs for human operators to configure their ACL roles, rules and resources.
* k2hr3_api  
  provides REST APIs which are used by k2hr3_app and k2hr3_osnl to save ACL roles, rules and resources and load them in k2hr3_dkc.
* k2hr3_dkc  
  stores ACL roles, rules, resources and other k2hr3 system data.
* OpenStack  
  [OpenStack](https://www.openstack.org/) is a software platform for cloud  computing developed by the [OpenStack](https://www.openstack.org/) community.
* k2hr3_osnl  
  is a plugin for [OpenStack](https://www.openstack.org/) Notification Listener which looks at incomming messages from  [OpenStack](https://www.openstack.org/) services and invokes the k2hr3_api delete API with parameters of a removed instance-id and its ip-addresses.
* k2hr3 system overview figure  
![deploy-k2hr3_overview](img/k2hr3_utils_1.png)

## k2hr3 system requirements

Please note follwoing requirements of each components.

| Component  | Mininum hosts(for production) | OS(Linux)                                       | others                |
|:-----------|:------------------------------|:------------------------------------------------|:----------------------|
| k2hr3_dkc  | 1(3)                          | Debian-9, Fedora-29(28), CentOS-7, Ubuntu-18.04 |                       |
| k2hr3_api  | 1(2)                          | Debian-9, Fedora-29(28), CentOS-7, Ubuntu-18.04 | Node.js v10 or higher |
| k2hr3_app  | 1(2)                          | Debian-9, Fedora-29(28), CentOS-7, Ubuntu-18.04 | Node.js v10 or higher |
| k2hr3_osnl | 1(2)                          | Debian-9, Fedora-29(28), CentOS-7, Ubuntu-18.04 | Python3.5 or higher   |

## k2hr3 components installation order

This chapter instructs the installation order of k2hr3 components.

### TLDR

We recommend the following installation order:

* 1 OpenStack or k2hr3_dkc  
* 2 k2hr3_api  
* 3 k2hr3_app or k2hr3_osnl  

### Rationale

[OpenStack](https://www.openstack.org/) services should start before k2hr3_api starts, because k2hr3_api use [OpenStack](https://www.openstack.org/) Service Endpoints. That means [OpenStack](https://www.openstack.org/) should be installed before k2hr3_api. k2hr3_api reads and writes data in k2hr3_dkc. Thant means k2hr3_dkc should be installed before k2h3r_api and k2hr3_api should be installed before k2hr3_app and k2hr3_osnl. k2hr3_dkc is an independent component from [OpenStack](https://www.openstack.org/). k2hr3_app and k2hr3_osnl are independent of each other. Therefore you need not to think their installation orders. As a result, following installation order is recommended.

* OpenStack or k2hr3_dkc  
* k2hr3_api  
* k2hr3_app or k2hr3_osnl  

## (1) OpenStack configuration

This chapter instructs [OpenStack](https://www.openstack.org/) configurations for k2hr3. If you have not deployed [OpenStack](https://www.openstack.org/), see the [OpenStack Rocky Deployment Guides](https://docs.openstack.org/rocky/deploy/) and please deploy it first. [Devstack](https://docs.openstack.org/devstack/latest/) is one of the best solution for those who will deploy [OpenStack](https://www.openstack.org/) for development usage.

![deploy-openstack](img/k2hr3_utils_2.png)

Technically, [OpenStack](https://www.openstack.org/)  services emit notification messages by the [oslo.messaging](https://docs.openstack.org/oslo.messaging/latest/). The [oslo.messaging](https://docs.openstack.org/oslo.messaging/latest/) defines the messaging driver in the configuration file. For instance, [OpenStack neutron](https://docs.openstack.org/neutron/latest/) uses the **messagingv2** driver in the following configuration:
```
    [oslo_messaging_notifications]
    #
    # From oslo.messaging
    #
    # The Drivers(s) to handle sending notifications. Possible values are
    # messaging, messagingv2, routing, log, test, noop (multi valued)
    # Deprecated group/name - [DEFAULT]/notification_driver
    driver = messagingv2
```

A message driver determines the message format. Here is a sample message by [OpenStack neutron](https://docs.openstack.org/neutron/latest/) configured to use the **messagingv2** driver.
```
{
    "event_type": "port.delete.end",
    "message_id": "76c35877-9d0c-4faf-b4e5-7c51828f37a0",
    "payload": {
        ...
        "device_id": "12345678-1234-5678-1234-567812345678",
        "device_owner": "compute:nova",
        "extra_dhcp_opts": [],
        "fixed_ips": [
            {
                "ip_address": "172.16.0.1",
                "subnet_id": "subnet01-ffff-ffff-ffff-ffffffffffff"
            },
            {
                "ip_address": "2001:db8::6",
                "subnet_id": "subnet02-ffff-ffff-ffff-ffffffffffff"
            }
        ],
        ...
    },
    "priority": "INFO",
    "publisher_id": "network.hostname.domain_name",
    "timestamp": "2018-11-25 09:00:06.842727"
```

k2hr3_osnl assumes messages formatted by **messagingv2** driver as a default because they contain IPs and instance unique ids, which are important for k2hr3 to work properly. If your [OpenStack](https://www.openstack.org/) services uses **messaging** driver, please refer the [Parsing versioned messages from OpenStack nova](https://k2hr3-osnl.readthedocs.io/en/hotx/usage.html#parsing-versioned-messages-from-openstack-nova) to change the configuration for  k2hr3_osnl.

If you don't know much about the [driver](https://docs.openstack.org/neutron/latest/configuration/neutron.html#oslo-messaging-notifications]) what your [OpenStack neutron](https://docs.openstack.org/neutron/latest/) uses, Please examine your /etc/neutron/neutron.conf or ask your [OpenStack](https://www.openstack.org/) system administrators.

(2) k2hr3_dkc
--------------

This chapter instructs k2hr3_dkc installation.
![deploy-k2hr3_dkc](img/k2hr3_utils_3.png)

### TLDR

The following command will install k2hr3_dkc on an Openstack virtual machine.
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git && cd k2hr3_utils/devcluster/src
$ sh dkc/setup_dkc_main.sh
```

k2hr3_dkc consists of 3 subcomponents.
* [chmpx](https://github.com/yahoojapan/chmpx/wiki) is a transparent proxy server that coordinate read and write requests from clents to [k2hdkc](https://github.com/yahoojapan/k2hdkc/wiki).  
* [k2hdkc](https://github.com/yahoojapan/k2hdkc/wiki) is a distributed KVS cluster that receives client requests via [chmpx](https://github.com/yahoojapan/chmpx/wiki). The backend is [k2hash](https://github.com/yahoojapan/k2hash/wiki).  
* [k2hash](https://github.com/yahoojapan/k2hash/wiki) is a key-value database file.  

Here are summary of installation procedures:

1. Initializes environments  
  Detects the OS_NAME of the target host and loads installation configurations.
2. Ensures that the k2hdkc data directory exists  
  k2hr3_dkc requires a directory for saving data
3. Ensures that the k2hdkc configuration directory exists  
  k2hr3_dkc requires a directory for its configuration file
4. Adds a new package repository  
  k2hr3_dkc needs binary packages on https://packagecloud.io/antpickax/.
5. Installs binary packages  
  k2hr3_dkc needs the k2htpdtor, libfullock, k2hash, chmpx and k2hdkc.
6. Configures the chmpx default configuratoin  
  The default k2hdkc.ini contains dummy server name. You need to change it.
7. Installs the configured chmpx config file  
  k2hr3_dkc uses a configuration file(for instance /etc/antpickax/k2hdkc.ini) for [chmpx](https://github.com/yahoojapan/chmpx).
8. Configures the chmpx's service manager default configuration  
  We recommend [chmpx](https://github.com/yahoojapan/chmpx) processes work as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
9. Installs the chmpx service manager configuration and enables it  
  [systemd](https://freedesktop.org/wiki/Software/systemd/) controls [chmpx](https://github.com/yahoojapan/chmpx).
10. Configures the k2hdkc's service manager default configuration  
  We recommend [k2hdkc](https://github.com/yahoojapan/k2hdkc) processes work as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
11. Installs the k2hdkc service manager configuration and enables it  
  [systemd](https://freedesktop.org/wiki/Software/systemd/) controls [k2hdkc](https://github.com/yahoojapan/k2hdkc).


(3) k2hr3_api
--------------

This chapter instructs the k2hr3_api installation.
![deploy-k2hr3_api](img/k2hr3_utils_4.png)

### TLDR

The following command will install k2hr3_api on an Openstack virtual machine.
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git && cd k2hr3_utils/devcluster
$ sh api/setup_api_main.sh -f https:github.com/yahoojapan/k2hr3_api#semver:0.0.1
```

k2hr3_api primarily consists of 2 subcomponents.
* [chmpx](https://github.com/yahoojapan/chmpx/wiki) is a transparent proxy server that coordinate read and write requests from clents to [k2hdkc](https://github.com/yahoojapan/k2hdkc/wiki).  
* [Node.js](https://nodejs.org) is a HTTP server, which accepts HTTP request from k2hr3-app and k2hr3-osnl.  

Here are summary of installation procedures:

1. Initializes environments  
   Detects the OS_NAME of the target host and loads installation configurations.
2. Ensures that the k2hdkc data directory exists  
  k2hr3_dkc requires a directory for saving data
3. Ensures that the k2hdkc configuration directory exists  
  k2hr3_dkc requires a directory for its configuration file
4. Adds new package repositories  
  k2hr3_api needs Debian and RPM packages on https://packagecloud.io/antpickax/.
  [nodesource](https://github.com/nodesource/distributions) provides the nodejs and npm.
  [softwarecollections](http://softwarecollections.org/) provides the devtoolset package for centos.
5. Installs binary packages  
  k2hr3_api needs the nodejs, k2htpdtor, libfullock, k2hash, chmpx and k2hdkc.
6. Configures the chmpx slave default configuration  
  The default chmpx.ini contains dummy server name. You need to change it.
7. Installs the configured chmpx slave config file  
  k2hr3_api uses a configuration file(for instance /etc/k2hdkc/chmpx.ini) for [chmpx](https://github.com/yahoojapan/chmpx).
8. Configures the chmpx slave's service manager default configuration  
  We recommend [chmpx](https://github.com/yahoojapan/chmpx) process works as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
9. Configures the chmpx slave's service manager default configuration  
  [systemd](https://freedesktop.org/wiki/Software/systemd/)) controls [chmpx](https://github.com/yahoojapan/chmpx).
10. Installs devel packages to build the k2hdkc node module  
  The k2hdkc node module requires header files of libfullock, k2hash, chmpx and k2hdkc.
11. Installs npm packages  
  The k2hdkc npm package is a node addon package which provides the k2hdkc driver functions.
  The k2hr3-api package provies the REST APIs.
12. Configures the default local.json of the k2hr3-api package.  
  You need to change SSL certs path and add frontend server ip-addresses to the local.json.
13. Installs the configured local.json of the k2hr3-api package.  
  k2hr3_api node module uses it.
14. Configures the k2hr3-api's service manager default configuration  
  We recommend k2hr3-api processes work as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
15. Installs the k2hr3-api service manager configuration and enables it  
  [systemd](https://freedesktop.org/wiki/Software/systemd/) controls k2hr3-api.


(4) k2hr3_app
---------------

This chapter instructs the k2hr3_app installation.
![deploy-k2hr3_api](img/k2hr3_utils_5.png)

### TLDR

The following command will install k2hr3_app on an Openstack virtual machine.
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git && cd k2hr3_utils/devcluster
$ sh app/setup_app_main.sh sh -f https:github.com/yahoojapan/k2hr3_app#semver:0.0.1
```

k2hr3_api primarily consists of one subcomponents.
* [Node.js](https://nodejs.org) is a HTTP server process.  

Here are summary of installation procedures:

1. Initializes environments  
  Detects the OS_NAME of the target host and loads installation configurations.
2. Adds a new package repository  
  [nodesource](https://github.com/nodesource/distributions) provides the nodejs and npm.
3. Installs binary packages  
  k2hr3_app needs the nodejs.
4. Install the k2hr3-app npm package  
  The k2hr3-app package provides an interactive UIs.
5. Configures the default local.json of the k2hr3-app package  
  You need to change SSL certs path and add API server ip-addresses to the local.json.
6. Installs the configured local.json of the k2hr3-app package  
  k2hr3_app node module uses it.
7. Configures the k2hr3-app's service manager default configuration  
  We recommend k2hr3-api processes work as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
8. Installs the k2hr3-app service manager configuration and enables it  
  [systemd](https://freedesktop.org/wiki/Software/systemd/) controls k2hr3-app nodejs process.

(5) k2hr3_osnl
----------------

This chapter instructs the k2hr3_osnl deployment. If you don’t have Python3.5 or higher and pip installed, this [Python installation guide](http://docs.python-guide.org/en/latest/starting/installation/) can guide you through the process.
![deploy-k2hr3_osnl](img/k2hr3_utils_6.png)

### TLDR

The following command will install k2hr3_osnl on an Openstack virtual machine.
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git && cd k2hr3_utils/devcluster
$ sh osnl/setup_osnl.sh -t rabbit://stackrabbit:devstack@127.0.0.1:5672/
```

k2hr3_osnl primarily consists of two subcomponents.
* [OpenStack Oslo.messaging](https://github.com/openstack/oslo.messaging) is an OpenStack library for messaging.  
* Python3. [OpenStack Oslo.messaging](https://github.com/openstack/oslo.messaging) is a Python module. We select Python3 because [OpenStack Technical Committee](https://governance.openstack.org/tc/) stated that All OpenStack projects must complete the work for Python 3 support by the end of the T cycle which I believe means the middle of 2019. Please see the [2018-05-29 Python2 Deprecation Timeline](https://governance.openstack.org/tc/resolutions/20180529-python2-deprecation-timeline.html) for details.  

Here are summary of installation procedures:

1. Initializes environments.  
  Detects the OS_NAME of the target host and loads installation configurations.
2. Adds a new package repository.  
  [SCLo](https://www.softwarecollections.org/en/scls/user/rhscl/) provides the [rh-python35](https://www.softwarecollections.org/en/scls/rhscl/rh-python35/) pkg for CentOS6 and the [rh-python36](https://www.softwarecollections.org/en/scls/rhscl/rh-python36/) pkg for CentOS7.
3. Installs the system package(python3).  
  python3 provides library to run k2hr3_osnl.
4. Installs the k2hr3-osnl pypi package.  
  k2hr3_osnl provides to listen to notification messages from OpenStack.
5. Configures the k2hr3_onsl.conf.  
  You need to change the K2hr3 API server and OpenStack Message Queue server.
6. Installs a systemd configuration for k2hr3_osnl  
  We recommend the k2hr3_osnl Python process works as a service by [systemd](https://freedesktop.org/wiki/Software/systemd/).
7. Registers and enables k2hr3_osnl to systemd.  
  [systemd](https://freedesktop.org/wiki/Software/systemd/) controls k2hr3_osnl Python process.
