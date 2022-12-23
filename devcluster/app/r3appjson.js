// -*-Javascript-*-
/*
 * K2HR3 Utils
 *
 * Copyright 2019 Yahoo Japan Corporation.
 *
 * K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers
 * common management information for the cloud.
 * K2HR3 can dynamically manage information as "who", "what", "operate".
 * These are stored as roles, resources, policies in K2hdkc, and the
 * client system can dynamically read and modify these information.
 *
 * For the full copyright and license information, please view
 * the license file that was distributed with this source code.
 *
 * AUTHOR:   Hirotaka Wakabayashi
 * CREATE:   Tue Nov 12 2019
 * REVISION:
 */

//
// This program generates a local.json of k2hr3-app from a k2hr3-utils setup.ini
//
'use strict';

const fs = require('fs');
const ACCESSLOGNAME = 'accesslogname';
const APIHOST = 'apihost';
const APIPORT = 'apiport';
const APISCHEME = 'apischeme';
const APPMENU = 'appmenu';
const CA = 'ca';
const CERT = 'cert';
const CONSOLELOGNAME = 'consolelogname';
const EXTROUTER = 'extrouter';
const LOGDIR = 'logdir';
const LOGROTATEOPT_COMPRESS = 'logrotateopt_compress';
const LOGROTATEOPT_INITIALROTATION = 'logrotateopt_initialRotation';
const LOGROTATEOPT_INTERVAL = 'logrotateopt_interval';
const MULTIPROC = 'multiproc';
const PORT = 'port';
const PRIVATEKEY = 'privatekey';
const REJECTUNAUTHORIZED = 'rejectUnauthorized';
const RUNUSER = 'runuser';
const SCHEME = 'scheme';
const VALIDATOR = 'validator';

//
// R3appJson
// a class to represent k2hr3-app parameters
//
class R3appJson {
	constructor() {
		// properties of this object
		this.debug = false;
		this.configured = false;

		// k2hr3-app parameters
		this.data = {
			scheme:				'http',						// This nodejs server scheme
			port:				80,							// This nodejs server port
			multiproc:			true,						// Run multi processes mode
			runuser:			'',							// User for process owner
			privatekey:			'',							// Private key path for https
			cert:				'',							// Certification file path for https
			ca:					'',							// CA path for https
			logdir:				null,						// Path for logging directory
			fixedlogdir:		null,						// Fixed log directory
			accesslogname:		'access.log',				// Access log name
			accesslogform:		'combined',					// Access log format by morgan
			consolelogname:		null,						// Console(Error) log name
			logrotateopt: 		{							// rotating-file-stream option object
				compress:			'gzip',					// gzip		: compression method of rotated files.
				interval:			'6h',					// 6 hour	: the time interval to rotate the file.
				initialRotation:	true,					// true		: initial rotation based on not-rotated file timestamp.
				path:				null					// null		: the base path for files.(* this value is replace by 'logdir')
				/*
				 * [NOTE] following option is not specified now.
				 *
				 rotationTime:		true,					// true		: makes rotated file name with time of rotation.
				 highWaterMark:		null,					// null		: proxied to new stream.
				 history:			null,					// null		: the history filename.
				 immutable:			null,					// null		: never mutates file names.
				 maxFiles:			null,					// null		: the maximum number of rotated files to keep.
				 maxSize:			null,					// null		: the maximum size of rotated files to keep.
				 mode:				null,					// null		: proxied to fs.createWriteStream
				 rotate:			null,					// null		: enables the classical UNIX logrotate behaviour.
				 size:				null					// null		: the file size to rotate the file.
				*/
			},
			apihost:			'localhost',				// API host
			apischeme:			'http',						// API scheme
			apiport:			3001,						// API port

			userdata:			'',							// User Data Script for OpenStack
			secretyaml:			'',							// Secret Yaml for kubernetes
			sidecaryaml:		'',							// Sidecar Yaml for kubernetes
			appmenu:			null,						// The menu array for application
			validator:			'userValidateDebug',		// Validator object module
			validobj:			null,						// Generated(required) validator object module
			rejectUnauthorized:	true,						// reject mode
			lang:				'en',						// Language for javascript application
		};
	}

	//
	// methods
	//
	configureAccessLogName(r3appkey, val) {
		if (r3appkey.localeCompare(ACCESSLOGNAME) == 0) {
			this.data.accesslogname = val;
		}
	}

	configureApiHost(r3appkey, val) {
		if (r3appkey.localeCompare(APIHOST) == 0) {
			this.data.apihost = val;
		}
	}

	configureApiPort(r3appkey, val) {
		if (r3appkey.localeCompare(APIPORT) == 0) {
			this.data.apiport = val;
		}
	}

	configureApiScheme(r3appkey, val) {
		if (r3appkey.localeCompare(APISCHEME) == 0) {
			this.data.apischeme = val;
		}
	}

	configureAppMenu(r3appkey, val) {
		if (r3appkey.localeCompare(APPMENU) == 0) {
			this.data.appmenu = [];
			let menus = [];
			let spos = 0; // startPos
			let pos = 0;
			do {
				pos = val.indexOf(',', spos);
				if (this.debug) {
					console.log('pos=' + pos);
				}
				if (pos !== -1) { // found a comma
					menus.push(val.substring(spos, pos));
				} else {
					menus.push(val.substr(spos));
				}
				spos = pos + 1;
			} while(pos !== -1);
	
			for(let menu of menus) {
				let pos = menu.indexOf('=', 0);
				if (pos !== -1) { // found a equal
					let name = menu.substring(0, pos);
					let url = menu.substring(pos + 1);
					let obj = {}
					obj.name = name;
					obj.url = url;
					console.log(obj);
					this.data.appmenu.push(obj);
				}
			}
		}
	}

	configureCA(r3appkey, val) {
		if (r3appkey.localeCompare(CA) == 0) {
			this.data.ca = val;
		}
	}

	configureCert(r3appkey, val) {
		if (r3appkey.localeCompare(CERT) == 0) {
			this.data.cert = val;
		}
	}

	configureConsoleLogName(r3appkey, val) {
		if (r3appkey.localeCompare(CONSOLELOGNAME) == 0) {
			this.data.consolelogname = val;
		}
	}

	configureExtrouter(r3appkey, val) {
		if (r3appkey.localeCompare(EXTROUTER) == 0) {
			this.data.extrouter = val;
		}
	}

	configureLogDir(r3appkey, val) {
		if (r3appkey.localeCompare(LOGDIR) == 0) {
			this.data.logdir = val;
		}
	}

	configureLogrotateOptCompress(r3appkey, val) {
		if (r3appkey.localeCompare(LOGROTATEOPT_COMPRESS) == 0) {
			this.data.logrotateopt.compress = val;
		}
	}

	configureLogrotateOptInitialRotation(r3appkey, val) {
		if (r3appkey.localeCompare(LOGROTATEOPT_INITIALROTATION) == 0) {
			if( val.localeCompare("true") == 0 ) {
				this.data.logrotateopt.initialRotation = true;
			} else {
				this.data.logrotateopt.initialRotation = false;
			}
		}
	}

	configureLogrotateOptInterval(r3appkey, val) {
		if (r3appkey.localeCompare(LOGROTATEOPT_INTERVAL) == 0) {
			this.data.logrotateopt.interval = val;
		}
	}

	configureMultiProc(r3appkey, val) {
		if (r3appkey.localeCompare(MULTIPROC) == 0) {
			if( val.localeCompare("true") == 0 ) {
				this.data.multiproc = true;
			} else {
				this.data.multiproc = false;
			}
		}
	}

	configurePort(r3appkey, val) {
		if (r3appkey.localeCompare(PORT) == 0) {
			this.data.port = val;
		}
	}

	configurePrivateKey(r3appkey, val) {
		if (r3appkey.localeCompare(PRIVATEKEY) == 0) {
			this.data.privatekey = val;
		}
	}

	configureRejectUnAuthorized(r3appkey, val) {
		if (r3appkey.localeCompare(REJECTUNAUTHORIZED) == 0) {
			if( val.localeCompare("true") == 0 ) {
				this.data.rejectUnauthorized = true;
			} else {
				this.data.rejectUnauthorized = false;
			}
		}
	}

	configureRunUser(r3appkey, val) {
		if (r3appkey.localeCompare(RUNUSER) == 0) {
			this.data.runuser = val;
		}
	}

	configureScheme(r3appkey, val) {
		if (r3appkey.localeCompare(SCHEME) == 0) {
			this.data.scheme = val;
		}
	}

	configureValidator(r3appkey, val) {
		if (r3appkey.localeCompare(VALIDATOR) == 0) {
			this.data.validator = val;
		}
	}

	// configure
	// This method binds ini items with json items and it also changes ini item data format to json data format.
	//
	// Params::
	//  $1 data item name, which name starts with "k2hr3_app_"
	//  $2 value of the item
	//
	// Returns::
	//  true on success
	//
	configure(key, val) {
		let p = key.startsWith('k2hr3_app_');
		if (!p) {
			console.log('key is not for k2hr3_app');
			return false;
		}
		let r3appkey = key.slice(9+1); // strlen(k2hr3_app_) + 1
		this.configureAccessLogName(r3appkey, val);
		this.configureApiHost(r3appkey, val);
		this.configureApiPort(r3appkey, val);
		this.configureApiScheme(r3appkey, val);
		this.configureAppMenu(r3appkey, val);
		this.configureCA(r3appkey, val);
		this.configureCert(r3appkey, val);
		this.configureConsoleLogName(r3appkey, val);
		this.configureExtrouter(r3appkey, val);
		this.configureLogDir(r3appkey, val);
		this.configureLogrotateOptCompress(r3appkey, val);
		this.configureLogrotateOptInitialRotation(r3appkey, val);
		this.configureLogrotateOptInterval(r3appkey, val);
		this.configureMultiProc(r3appkey, val);
		this.configurePort(r3appkey, val);
		this.configurePrivateKey(r3appkey, val);
		this.configureRejectUnAuthorized(r3appkey, val);
		this.configureRunUser(r3appkey, val);
		this.configureScheme(r3appkey, val);
		this.configureValidator(r3appkey, val);
		this.configured = true;
	}

	// dump
	// This method writes k2hr3-api data to a json file.
	//
	// Params::
	//  $1 path of a json file
	//
	// Returns::
	//  true on success
	//
	dumpTo(path) {
		if (!this.configured) {
			console.error("have not configured yet.");
			return false;
		}
		var jsondata = JSON.stringify(this, null, '  ');
		if (jsondata) {
			fs.writeFileSync(path, jsondata);
		}
		return true;
	}

	// toJSON
	// This method is called back from JSON.stringify
	//
	// Returns::
	//  a json object of k2hr3-api data
	//
	toJSON() {
		return this.data;
	}
}

module.exports = {
	R3appJson
}

/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: noexpandtab sw=4 ts=4 fdm=marker
 * vim<600: noexpandtab sw=4 ts=4
 */
