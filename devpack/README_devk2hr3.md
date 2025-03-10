# devk2hr3.sh - Developer Environment for K2HR3

## Overview
`devk2hr3.sh` is a tool to create an environment for checking, debugging, and testing the operation of the **K2HR3 System**.  

This tool can build a minimal **K2HR3 System** on the host where the tool is started or in a Docker container on that host.  
You can build an environment for the purpose of development and checking the **K2HR3 System**.  

## About built K2HR3 System
This tool starts all **K2HR3 System** components(programs) in one host(or container).  
The following components(programs) will be started:  

- K2HDKC Server Node ( K2HDKC process + CHMPX process ) \* 2
- CHMPX Slave Node ( CHMPX process ) \* 1
- K2HR3 REST API ( k2hr3 api nodejs processes ) \* 1
- K2HR3 Web Application ( k2hr3 app nodejs processes ) \* 1

This is the minimum processes for the **K2HR3 System**.  

## Supported OS
The supported OS for this tool creating the **K2HR3 System** are shown below:  

- ubuntu ( 22.04 recommended )
- debian ( 12 recommended )
- fedora ( 41 recommended )
- rockylinux ( 9 recommended )
- alpine ( 3.21 recommended )

If you are creating **K2HR3 System** on a host, run this tool on a host with one of the above OS installed.  
If you are creating it in a container, prepare the `Docker Service` and specify one of the above OS to this tool.  

### Multiple K2HR3 System
You can create multiple K2HR3 Systems simultaneously in the host and in the container.  
However, you cannot create K2HR3 Systems on the same OS type.  
For example, you can create one K2HR3 System on the `ubuntu` host and also create one K2HR3 System in the `alpine` container at the same time.  

The port numbers used by the K2HR3 System are different for each OS, allowing them to be started simultaneously.  

## Construction Procedure
### Preparation
#### Host Settings
###### Case of creating on a host
Prepare a host with one of the OSs listed in the previous section.  

##### Case of creating in a container
Prepare a host with the `Docker Service` installed. ( [Reference](https://docs.docker.com/) )  
If you want to use your own Docker Registry, set it up in advance.  
Also, if necessary to use images from DockerHub, set up users, access tokens, etc.  

#### Environment Variables
If you want to use a `PROXY` for communication outside the host, please set Environment Variables such as `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` in advance.  

### Execute devk2hr3.sh
Once the preparations are complete, run `devk2hr3.sh`.  

`devk2hr3.sh` can be executed interactively, so you can start it as follows and fill in the questions to build it.(The following example shows how to create on the host.)  

```
$ k2hr3_utils/devpack/bin/devk2hr3.sh start
  ---------------------------------------------------------------------
  [TITLE] Load additional configuration file
  ---------------------------------------------------------------------
  [INFO] Succeed to setup default additinal variables.
  
  ---------------------------------------------------------------------
  [TITLE] Parse and Check options
  ---------------------------------------------------------------------
  [INPUT] Specify the Docker container image. If you do not want to run in a container, enter empty("").
          Specify the image using "{<docker registory>/}<image name>{:<version>}" format.
          Or specify one of the predefined values("alpine", "ubuntu", "debian", "rockylinux"(rocky), "fedora").
          Please input Docker Image >
  [INPUT] Work directory (empty is use default: ".") > /home/k2hr3
  [INPUT] NodeJS version for other than ALPINE - 18, 20, 22, ... (empty is use default: "22") >
  [INPUT] OpenStack Keystone URL (empty is use default: "https://localhost/") >
  [INPUT] Do you add additinal NPM Registries? (yes/no(default)) >
  ...
  ...
```
_The options for `devk2hr3.sh` are explained below._  

When the creation is complete, the following will be displayed:  
```
---------------------------------------------------------------------
[TITLE] Launched K2HR3 system
---------------------------------------------------------------------
The K2HR3 system has started successfully.
All files related to the K2HR3 system are extracted under the "/home/k2hr3" directory.

You can operate the K2HR3 system by accessing the following URLs:
    K2HR3 REST API         : http://<host name(fqdn)>:24080
    K2HR3 Web Application  : http://<host name(fqdn)>:14080
--------------------------------------------------

[SUCCESS] devk2hr3.sh Finished without any error.
```
When you access the URL of `K2HR3 Web Application` shown above, the K2HR3 Web Application screen will be displayed.  

This completes the construction of the **K2HR3 System**.  

# Detail

## devk2hr3.sh Help
Below is the help for the `devk2hr3.sh` tool.
```
$ devk2hr3.sh --help
  
  Usage:  devk2hr3.sh [options] { start(str) | stop(stp) }
  
  [Command]
     start(str)                      Start K2HR3 systems
     stop(stp)                       Stop K2HR3 systems
     login(l)                        Login(attach) into K2HR3 systems container
  
  [Common Options]
     --help(-h)                      Print help
     --yes(-y)                       Runs no interactive mode. (default: interactive mode)
     --workdir(-w)                   Specify the base directory path, cannot specify in the same directory as this script. (default: current directory or /work)
     --container(-i) [...]           Run K2HR3 system in docker container.
                                     Specify the image as "{<docker registry>/}<image name>:<tag>":
                                     ex) "alpine:3.21"
                                         "docker.io/alpine:3.21"
                                     You can use the defined images by specifying the following keywords in the image name:
                                         "alpine"    -> alpine:3.21
                                         "fedora"    -> fedora:41
                                         "rocky"     -> rockylinux:9
                                         "ubuntu"    -> ubuntu:22.04
                                         "debian"    -> debian:12
  
  [Options: start]
     --not_use_pckagecloud(-nopc)    Not use packages on packagecloud repository. (default: use packagecloud repository)
  
     --nodejs_version(-node) [ver]   Specify NodeJS version like as "18", "20", "22". (default: 22)
                                     In the case of ALPINE, it is automatically determined depending on the OS version.
  
     --repo_k2hr3_api(-repo_api)     Specify K2HR3 API repository url for cloning. (default: https://<github domain>/<org>/k2hr3_api.git)
     --repo_k2hr3_api(-repo_app)     Specify K2HR3 APP repository url for cloning. (default: https://<github domain>/<org>/k2hr3_app.git)
  
     --host_external(-eh) [host|ip]  Specify host("hostname" or "IP address") for external access when run this in container. (REQUIRED option for container)
     --npm_registory(-reg) [...]     Specify additional NPM registries in the following format:
                                         "<registory name>,<npm registory url>"
                                         ex) "registry,http://registry.npmjs.org/"
                                     To register multiple registries, specify this option-value pair multiple times.
     --keystone_url(-ks) [url]       Specify OpenStack Keystone URL. (default: https://localhost/)
  
  [NOTE]
     For ALPINE OS, the --nodejs_version (-node) option is ignored.
     This is because it depends on the version of the nodejs package present in the ALPINE
     package repository.
     In ALPINE 3.19, it is v18, in 3.20 it is v20, and in 3.21 it is v22.
  
  [Environments]
     You can change the log levels for CHMPX, K2HDKC processes, etc. by setting the following
     environment variables:
         CHMDBGMODE, CHMDBGFILE
         DKCDBGMODE, DKCDBGFILE
     Please refer to the help for each program for details.
```

An explanation of each option and command is given below:  

## devk2hr3.sh Commands
### start(str)
Start to create the **K2HR3 System**.

### stop(stp)
Stops(destroys) the **K2HR3 System** created by this tool.

### login(l)
Attaches(login) to the **K2HR3 System** container created by this tool.  
This allows you to operate each process in the container.  
The same can be achieved by manually executing `docker exec`, but by using this tool, the same environment variables(ex. PROXY environments) as when the **K2HR3 System** was created can be reflected.  

## devk2hr3.sh Options
### --help(-h)
Show `devk2hr3.sh` help.

### --yes(-y)
Answer interactive questions automatically with default answers.

### --workdir(-w)
This tool creates and extracts files related to the **K2HR3 System**.  
You must specify this option and the working directory in which to place these files and directories.  
The following sub-directories will be created under this working directory:  

| Sub-directory | Description                                               |
| ------------- | --------------------------------------------------------- |
| conf          | The configuration files for K2HDKC Server/Slave Nodes.    |
| data          | The data files(k2hash file) for K2HDKC Server Nodes.      |
| logs          | The log files for K2HDKC and CHMPX processes.             |
| pids          | The process ID files(PID) for K2HDKC and CHMPX processes. |
| k2hr3_api     | K2HR3 REST API(k2hr3 api) repository.                     |
| k2hr3_app     | K2HR3 Web Application(k2hr3 app) repository.              |

### --container(-i) [...]
Specify this option if you want to create the **K2HR3 System** in a container.  
If not specified, it will be create on the host.  
Please specify a `Docker image` for this option.(ex. `alpine:3.21`)  
Supported OS are `ubuntu`, `debian`, `fedora`, `rockylinux`, `alpine`.  

If the tag(version) is not specified, the following image will be used:  
| Value      | Used image and tag |
| ---------- | ------------------ |
| ubuntu     | ubuntu:22.04       |
| debian     | debian:12          |
| fedora     | fedora:41          |
| rockylinux | rockylinux:9       |
| alpine     | alpine:3.21        |

### --not_use_pckagecloud(-nopc)
The **K2HR3 System** created by this tool uses `AntPickax` product packages such as `k2hdkc` and `chmpx`.  
These packages are distributed from [packagecloud.io](https://packagecloud.io/antpickax/stable).  
If you specify this option, the [packagecloud.io](https://packagecloud.io/antpickax/stable) repository will not be configured.  
For example, if you are creating the **K2HR3 System** on a host and `k2hdkc`, `chmpx`, etc. are already installed, you can specify this.  
(NOTE: If you are creating in a container, `k2hdkc` and `chmpx` will be installed, so you will need to specify a repository.)  

### --nodejs_version(-node) [ver]
Specifies the `NodeJS` version for `K2HR3 REST API` and `K2HR3 Web Application`.  
The versions that can be specified are `v18`, `v20`, and `v22`, the default is `v22`.  

If the OS on which the **K2HR3 System** is created is `alpine`, the `NodeJS` version will be fixed depending on the `alpine` version.  
For `alpine`, the value specified by this option will be ignored.  

### --repo_k2hr3_api(-repo_api)
Specify the repository URL for `K2HR3 REST API`.  
The default is `https://github.com/yahoojapan/k2hr3_api.git`.  

### --repo_k2hr3_api(-repo_app)
Specify the repository URL for `K2HR3 Web Application`.  
The default is `https://github.com/yahoojapan/k2hr3_app.git`.  

### --host_external(-eh) [host|ip]
To access the **K2HR3 System** created in a container, you need the host name(FQDN) of the host.  
This tool will automatically detect this, but if this is inconvenient, you can specify it with this option.  

### --npm_registory(-reg) [...]
You can add a registry of `NodeJS` packages for `K2HR3 REST API` and `K2HR3 Web Application`.  
If you need packages that are not available in the [NPM registry](https://www.npmjs.com/), specify an additional registry.  
The parameters for this option are the `registry name` and its `URL` separated by a comma `,`, as follows: `<repository name>,<repojistory URL>`.  
This option can be specified for each additional registry. (Multiple specifications are possible)  

### --keystone_url(-ks) [url]
The authentication for the **K2HR3 System** will be authentication via `OpenStack Keystone`.  
So, please specify the `Keystone URL` of the `OpenStack` system.  

The default value is `https://localhost/`.  
_(If you leave this value, you will not be able to log in to the **K2HR3 System**.)_  

If you want to change this authentication, please prepare the `override_devk2hr3.conf` file by referring to the customization described below.  

## devk2hr3.sh Environment Varibales
### PROXY Environments
If you are using `devk2hr3.sh` in an environment that requires PROXY, please set the `HTTP_PROXY(http_proxy)`, `HTTPS_PROXY(https_proxy)`, and `NO_PROXY(no_proxy)` environment variables before using this tool.  

### Environments for debugging
You can specify environment variables to set the debug output for `K2HDKC` and `CHMPX` in the **K2HR3 System**.  
The following environment variables can be set when starting this tool:  

| Environment name | Describe                                 |
| ---------------- | ---------------------------------------- |
| DKCDBGMODE       | Debug level for `K2HDKC` processes       |
| DKCDBGFILE       | The log file path for `K2HDKC` processes |
| CHMDBGMODE       | Debug level for `CHMPX` processes        |
| CHMDBGFILE       | The log file path for `CHMPX` processes  |

## How to test/debug/check
For your reference, explain how to test, debug, and check the **K2HR3 System** you have created.  

First, if you have created it in a container, attach(login) to the container as follows:  
```
$ devk2hr3.sh --container <container image name: ex. alpine:3.21> login
```

### K2HR3 System Processes
An example of the **K2HR3 System** processes that are creted is shown below:  
```
479379 pts/3    Sl     0:04 chmpx -conf /home/k2hr3/conf/alpine_server_0.ini
479433 pts/3    Sl     0:03 k2hdkc -conf /home/k2hr3/conf/alpine_server_0.ini
479596 pts/3    Sl     0:04 chmpx -conf /home/k2hr3/conf/alpine_server_1.ini
479653 pts/3    Sl     0:03 k2hdkc -conf /home/k2hr3/conf/alpine_server_1.ini
479712 pts/3    Sl     0:04 chmpx -conf /home/k2hr3/conf/alpine_slave_0.ini
479812 pts/3    S      0:00 /bin/sh bin/run.sh -bg --production -fg
479866 pts/3    Sl     0:00 node bin/www
479889 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_api/bin/www
479890 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_api/bin/www
479891 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_api/bin/www
479902 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_api/bin/www
479953 pts/3    S      0:00 /bin/sh bin/run.sh -bg --production -fg
480007 pts/3    Sl     0:00 node bin/www
480018 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_app/bin/www
480019 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_app/bin/www
480020 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_app/bin/www
480021 pts/3    Sl     0:00 /usr/bin/node /home/k2hr3/k2hr3_app/bin/www
```
`K2HDKC` and `CHMPX` are started using the configuration files under the working directory specified.  
And `K2HR3 REST API` and `K2HR3 Web Application` are also started.  

This tool is an environment construction tool for checking, testing, and debugging `K2HR3 REST API` and `K2HR3 Web Application`, so `K2HDKC` and `CHMPX` use the binaries installed as packages.  

### How to debug
The `K2HR3 REST API` and `K2HR3 Web Application` repositories are created by `git clone` under the working directory.  
In these directories, you can change the source code, configuration files, etc.  
You can use the `npm` command in each repository directory.  

## devk2hr3.sh Customize Authentication
The authentication for the **K2HR3 System** created by this tool is `OpenStack Keystone`.  

If you want to change this, you can change the configuration (`production.json5`) under the `K2HR3 REST API` and `K2HR3 Web Application` directories.  
Change the configuration and restart each process to change the authentication.  

If you want to change the authentication in advance when creating a **K2HR3 System** with this tool, you can do so by preparing the `override_devk2hr3.conf` file.  

### override_devk2hr3.conf
The `override_devk2hr3.conf` customization file, you can set the authentication for the **K2HR3 System**.  
You can replace the `shell variables` and `functions` set in the `devk2hr3.sh` file.  

For customization, replace the prefix `addition_***` functions defined in the `devk2hr3.sh` file.  
For an explanation of these functions, see the `devk2hr3.sh` file.  

## License
This software is released under the MIT License, see the license file.

## AntPickax
K2HR3 DEVPACK in K2HR3 Utilities is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2025 Yahoo Japan Corporation.
