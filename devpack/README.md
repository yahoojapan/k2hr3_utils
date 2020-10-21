# K2HR3 DEVPACK

## Overview
This directory is a environment construction tool for developers to build the minimum K2HR3 system with one HOST(Virtual Machine).  
By expanding this directory and executing the script, you can build the K2HR3 system on one host.  

## About HOST
### Environment requires Proxy
If the HOST that runs the K2HR3 system cannot be accessed directly from the outside(using a browser), you need to setup HAProxy etc. and proxy HTTP requests to the K2HR3 Web Application and K2HR3 REST API.  
The K2HR3 DEVPACK's startup script outputs a sample configuration for starting HAProxy.

## Run
You can build a minimal K2HR3 system by following the steps below.

### git clone
```
$ git clone https://github.com/yahoojapan/k2hr3_utils.git
$ cd devpack
```

### Launch
You can startup the K2HR3 system by simply running `bin/devpack.sh` under this directory.

#### Parameters
Check the following parameters related to the environment before startup.
- Execution user  
The user name to start each process.(Ex: `nobody`)
- HOST to startup the K2HR3 system on  
The `hostanme` or `IP address` of the HOST that startup the K2HR3 system.  
If this value is omitted, `localhost` will be used.
- OpenStack Region  
The OpenStack region name.  
If you are using devstack, it will be `RegionOne`.
- Keystone(Identity) URL  
The URL of the OpenStack Keystone(Identiry).(Ex: `http://192.168.10.10/identity`)
- K2HR3 Web Application port number  
The port number for K2HR3 Web Application.(Ex: `80`)
- K2HR3 REST API port number  
The port number for the K2HR3 REST API.(Ex: `8080`)
- HOST when HAProxy is required  
In an environment that requires a Proxy, a `hostname` or `IP address` that can be accessed from the outside is required.  
This value is most often the `hostanme` or `IP address` of the HOST that startup the K2HR3 system.

#### Startup example(1)
This example is a case that does not require a Proxy.  
Specify with the following parameters.  
- Execution user : `nobody`
- HOST to startup the K2HR3 system on : `localhost`
- OpenStack Region : `RegionOne`
- Keystone(Identity) URL ： `http://192.168.10.10/identity`
- K2HR3 Web Application port number : `80`
- K2HR3 REST API port number : `8080`

```
$ bin/devpack.sh -ni -nc --run_user nobody --openstack_region RegionOne  --keystone_url http://192.168.10.10/identity --app_host localhost --app_port 80 --api_host localhost --api_port 8080
```

#### Startup example(2)
This example is a case that requires a Proxy.  
Specify with the following parameters.   

- Execution user : `nobody`
- HOST to startup the K2HR3 system on : `192.168.10.20`
- OpenStack Region : `RegionOne`
- Keystone(Identity) URL ： `http://192.168.10.10/identity`
- K2HR3 Web Application port number : `80`
- K2HR3 REST API port number : `8080`
- HOST for HAProxy : `172.16.16.16`
- K2HR3 Web Application port number on HAProxy : `28080`
- K2HR3 REST API port number on HAProxy : `18080`

```
$ bin/devpack.sh -ni -nc --run_user nobody --openstack_region RegionOne --keystone_url http://192.168.10.10/identity --app_host 192.168.10.20 --app_port 80 --app_host_external 172.16.16.16 --app_port_external 28080 --api_host 192.168.10.20 --api_port 8080 --api_host_external 172.16.16.16 --api_port_external 18080
```
After executing the above command, the `conf/haproxy_example.cfg` file is created.  
Use this configuration file to start HAProxy(ex. `haproxy -f haproxy_example.cfg`) on the HOST that startup the K2HR3 system.

### Stop
We provide a tool to stop the K2HR3 system started by this tool.  
Please execute as follows.  
```
$ bin/stopdevpack.sh
```
If you want to delete unnecessary files, specify the options as follows.  
```
$ bin/stopdevpack.sh --clear
```

### License
This software is released under the MIT License, see the license file.

### AntPickax
K2HR3 DEVPACK in K2HR3 Utilities is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2020 Yahoo Japan Corporation.
