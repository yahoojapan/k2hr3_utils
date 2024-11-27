# K2HR3 DEVPACK

## Overview
This directory is a environment construction tool for developers to build the minimum K2HR3 system with one HOST(Virtual Machine).  
By expanding this directory and executing the script, you can build the K2HR3 system on one host.  

## About the environment for launching the K2HR3 system
The HOST that starts the K2HR3 system can be baremetal or Virtual Machine.  

If you use a Virtual Machine in a devstack or an environment that requires PROXY settings to access from outside the NODE HOST of that Virtual Machine, you must set the Openstack Network and NODE HOST appropriately.  
This tool outputs a sample HAProxy configuration file and an Openstack Security Group configuration method document to support such environments.  
You can refer to them and configure them appropriately.  

### About the PROXY environment variable
If you need HTTP(S) PROXY settings to access externally from your environment, please provide them with environment variables.  
They are used to access OS package and NPM package repositories.  

## Run devpack.sh
Run `devpack.sh` to build the K2HR3 system.  
This tool runs on the HOST(Virtual Machine) that builds the K2HR3 system.

### (1) Login and Set environments
Login to the HOST(Virtual Machine) that builds the K2HR3 system as user with privileges.  

If your environment requires HTTP(S) PROXY, please set those environment variables.  
Also, please make sure that you can access the OS package repository and NPM package repository from this HOST.(ex. Including DNS allocation)  
This tool uses the sudo command, so don't forget to edit sudoers file(or etc) for inheriting these PROXY environment variables.

### (2) Clone this repository
Clone this Git repository( [k2hr3_utils](https://github.com/yahoojapan/k2hr3_utils) ).  
_Please install the git command in advance_  
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git
$ cd devpack
```

### (3) Run devpack.sh
Run `devpack.sh`.  
Below is an explanation of the options and a startup example depending on the execution environment.  

#### Usage
For `devpack.sh` options, see `devpack.sh --help`.  
```
$ devpack.sh --help
  Usage:  devpack.sh [--no_interaction(-ni)] [--no_confirmation(-nc)]
          [--run_user(-ru) <user name>] [--openstack_region(-osr) <region name>] [--keystone_url(-ks) <url string>]
          [--server_port(-svrp) <number>] [--server_ctlport(-svrcp) <number>] [--slave_ctlport(-slvcp) <number>]
          [--app_port(-appp) <number>]         [--app_port_external(-apppe) <number>]
          [--app_host(-apph) <hostname or ip>] [--app_host_external(-apphe) <hostname or ip>]
          [--api_port(-apip) <number>]         [--api_port_external(-apipe) <number>]
          [--api_host(-apih) <hostname or ip>] [--api_host_external(-apihe) <hostname or ip>]
          [--help(-h)]
  
  [Options]
    Common:
          --help(-h)                    print help
          --no_interaction(-ni)         Turn off interactive mode for unspecified option input and use default value
          --run_user(-ru)               Specify the execution user of each process
          --openstack_region(-osr)      Specify OpenStack(Keystone) Region(ex: RegionOne)
          --keystone_url(-ks)           Specify OpenStack Keystone URL(ex: https://dummy.keystone.openstack/)
    CHMPX / K2HKDC:
          --server_port(-svrp)          Specify CHMPX server node process port
          --server_ctlport(-svrcp)      Specify CHMPX server node process control port
          --slave_ctlport(-slvcp)       Specify CHMPX slave node process control port
    K2HR3 APP:
          --app_port(-appp)             Specify K2HR3 Application port
          --app_port_external(-apppe)   Specify K2HR3 Application external port(optional: specify when using a proxy)
          --app_port_private(-apppp)    Specify K2HR3 Application private port(optional: specify when openstack)
          --app_host(-apph)             Specify K2HR3 Application host
          --app_host_external(-apphe)   Specify K2HR3 Application external host(optional: host as javascript download server)
          --app_host_private(-apphp)    Specify K2HR3 Application private host(optional: specify when openstack)
    K2HR3 API:
          --api_port(-apip)             Specify K2HR3 REST API port
          --api_port_external(-apipe)   Specify K2HR3 REST API external port(optional: specify when using a proxy)
          --api_port_private(-apipp)    Specify K2HR3 REST API private port(optional: specify when openstack)
          --api_host(-apih)             Specify K2HR3 REST API host
          --api_host_external(-apihe)   Specify K2HR3 REST API external host(optional: specify when using a proxy)
          --api_host_private(-apihp)    Specify K2HR3 REST API private host(optional: specify when openstack)
  
  [Environments]
          If PROXY environment variables(HTTP(s)_PROXY, NO_PROXY) are detected,
          environment variable settings (including sudo) and npm settings are
          automatically performed.
```
- --help(-h)  
Print help.
- --no_interaction(-ni)  
Turn off interactive mode for unspecified option input and use default value.
- --run_user(-ru)  
Specify the execution user of each process.
- --openstack_region(-osr)  
Specify OpenStack(Keystone) Region(ex: RegionOne).
- --keystone_url(-ks)  
Specify OpenStack Keystone URL(ex: https://dummy.keystone.openstack/).
- --server_port(-svrp)  
Specify CHMPX server node process port.
- --server_ctlport(-svrcp)  
Specify CHMPX server node process control port.
- --slave_ctlport(-slvcp)  
Specify CHMPX slave node process control port.
- --app_port(-appp)  
Specify K2HR3 Application port.
- --app_port_external(-apppe)  
Specify K2HR3 Application external port(optional: specify when using a proxy).
- --app_port_private(-apppp)  
Specify K2HR3 Application private port(optional: specify when openstack)
- --app_host(-apph)  
Specify K2HR3 Application host.
- --app_host_external(-apphe)  
Specify K2HR3 Application external host(optional: host as javascript download server).
- --app_host_private(-apphp)  
Specify K2HR3 Application private host(optional: specify when openstack)
- --api_port(-apip)  
Specify K2HR3 REST API port.
- --api_port_external(-apipe)  
Specify K2HR3 REST API external port(optional: specify when using a proxy).
- --api_port_private(-apipp)  
Specify K2HR3 REST API private port(optional: specify when openstack)
- --api_host(-apih)  
Specify K2HR3 REST API host.
- --api_host_external(-apihe)  
Specify K2HR3 REST API external host(optional: specify when using a proxy).
- --api_host_private(-apihp)  
Specify K2HR3 REST API private host(optional: specify when openstack)

##### NOTE
Specify these options(`--app_port_external(-apppe)`, `--app_host_external(-apphe)`, `--api_port_external(-apipe)`, `--api_host_external(-apihe)`), if your environment requires PROXY settings for external access.  
Otherwise, it can be omitted.  

#### Example : Not require PROXY
This case allows direct access to the K2HR3 system from outside. (PROXY is not required)  

These startup options( `--app_port_external(-apppe)`, `--app_host_external(-apphe)`, `--api_port_external(-apipe)`, `--api_host_external(-apihe)` ) are unnecessary.  

```
$ bin/devpack.sh -ni -nc --run_user nobody --openstack_region RegionOne  --keystone_url http://192.168.10.10/identity --app_host 192.168.10.20 --app_port 28080 --api_host 192.168.10.20 --api_port 18080
```

| Option             | Example value                 |
| ------------------ | ----------------------------- |
| --run_user         | nobody                        |
| --openstack_region | RegionOne                     |
| --keystone_url     | http://192.168.10.10/identity |
| --app_host         | 192.168.10.20                 |
| --app_port         | 28080                         |
| --api_host         | 192.168.10.20                 |
| --api_port         | 18080                         |

#### Example : Require PROXY
This is a case where the K2HR3 system cannot be accessed directly from the outside and PROXY settings are required.  

These startup options( `--app_port_external(-apppe)`, `--app_host_external(-apphe)`, `--api_port_external(-apipe)`, `--api_host_external(-apihe)` ) are required.  

```
$ bin/devpack.sh -ni -nc --run_user nobody --openstack_region RegionOne --keystone_url http://192.168.10.10/identity --app_host 192.168.10.20 --app_port 8082 --app_host_external 172.16.16.16 --app_port_external 28080 --api_host 192.168.10.20 --api_port 8081 --api_host_external 172.16.16.16 --api_port_external 18080
```

| Option               | Example value                 |
| -------------------- | ----------------------------- |
| --run_user           | nobody                        |
| --openstack_region   | RegionOne                     |
| --keystone_url       | http://192.168.10.10/identity |
| --app_host           | 192.168.10.20                 |
| --app_port           | 8082                          |
| --app_host_external  | 172.16.16.16                  |
| --app_port_external  | 28080                         |
| --api_host           | 192.168.10.20                 |
| --api_port           | 8081                          |
| --api_host_external  | 172.16.16.16                  |
| --api_port_external  | 18080                         |

### (4) Post-setting for PROXY is required
This is a case where the K2HR3 system cannot be accessed directly from the outside and PROXY settings are required.  

If the K2HR3 system cannot be accessed directly from the outside and PROXY settings are required, NODE HOST (HOST where the Virtual Machine is started) and Openstack Network settings are required.  
One of case is you built the K2HR3 system on a devstack Virtual Machine.  

This PROXY setting applies `Openstack Security Group` that releases specific ports(`K2HR3 REST API` and `K2HR3 Web Application`) to the Virtual Machine(Instance) that built the K2HR3 system.  
Also, start `HAProxy` to transfer requests to the Virtual Machine(Instance) that built the K2HR3 system.  

These sample configuration documents are output as `conf/README_NODE_PORT_FORWARDING` and `conf/haproxy_example.cfg` after the `devpack.sh` execution is completed.  

Please refer to the created `conf/README_NODE_PORT_FORWARDING` file and make settings.

## Run stopdevpack.sh
We provide a tool (stopdevpack.sh) to stop the K2HR3 system started with `devpack.sh`.  

You can stop the K2HR3 system using `stopdevpack.sh`.
```
$ bin/stopdevpack.sh
```
Also, you can stop and clean up files created by `devpack.sh`.  
```
$ bin/stopdevpack.sh --clear
```
For instructions on how to use this tool, please refer to the help below.
```
$ stopdevpack.sh --help
  
  Usage:  stopdevpack.sh [--clear(-c)] [--help(-h)]
  
          --clear(-c)       clear configuration, data and log files.
          --help(-h)        print help
```

### License
This software is released under the MIT License, see the license file.

### AntPickax
K2HR3 DEVPACK in K2HR3 Utilities is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2020 Yahoo Japan Corporation.
