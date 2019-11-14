// -*-Javascript-*-
/*
 * K2HR3 Utils
 *
 * Copyright 2019 Yahoo! Japan Corporation.
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
// This program generates a local.json of k2hr3-api from a k2hr3-utils setup.ini
//
'use strict';

const fs = require('fs');
const ACCESSLOGNAME = 'accesslogname';
const ALLOWCREDAUTH =  'allowcredauth';
const CA = 'ca';
const CERT = 'cert';
const CHKIPCONFIG_TYPE = 'chkipconfig_type';
const CONFIRMTENANT = 'confirmtenant';
const CONSOLELOGNAME = 'consolelogname';
const CORSIPS = 'corsips';
const K2HDKC_CONFIG = 'k2hdkc_config';
const K2HDKC_PORT = 'k2hdkc_port';
const K2HR3ADMIN_DELHOSTROLE = 'k2hr3admin_delhostrole';
const K2HR3ADMIN_TENANT = 'k2hr3admin_tenant';
const KEYSTONE_EPLIST = 'keystone_eplist';
const KEYSTONE_EPFILE = 'keystone_epfile';
const KEYSTONE_EPTYPE = 'keystone_eptype';
const KEYSTONE_TYPE = 'keystone_type';
const LOGDIR = 'logdir';
const LOGROTATEOPT_COMPRESS = 'logrotateopt_compress';
const LOGROTATEOPT_INITIALROTATION = 'logrotateopt_initialRotation';
const LOGROTATEOPT_INTERVAL = 'logrotateopt_interval';
const MULTIPROC = 'multiproc';
const PORT = 'port';
const PRIVATEKEY = 'privatekey';
const RUNUSER = 'runuser';
const SCHEME = 'scheme';
const USERDATA_ALGORITHM = 'userdata_algorithm';
const USERDATA_BASEURI = 'userdata_baseuri';
const USERDATA_CC_TEMPL = 'userdata_cc_templ';
const USERDATA_ERRSCRIPT_TEMPL = 'userdata_errscript_templ';
const USERDATA_SCRIPT_TEMPL = 'userdata_script_templ';
const WATCHERLOGNAME = 'watcherlogname';
const WCONSOLELOGNAME = 'watcherlogname';
const CHKIPCONFIGTYPE = {
    CHECKER_TYPE_LISTENER:'Listener',
    CHECKER_TYPE_FUNCTION:'Function',
    CHECKER_TYPE_BASIC_OR:'BasicOr',
    CHECKER_TYPE_BASIC_AND:'BasicAnd',
    CHECKER_TYPE_NOCHECK:'NoCheck'
};

//
// R3apiJson
// a class to represent k2hr3-api parameters
//
class R3apiJson {
    constructor() {
	// properties of this object
	this.debug = false;
	this.configured = false;

	// k2hr3-api parameters
	this.data	= {
	    keystone: {														// User authentication type
		type:			'openstackapiv3',							// module name in lib for openstack keystone access
		eptype:			'list',										// type of openstack keystone endpoint
		epfile:			null,
		eplist: {
		    myregion:	'https://dummy.keystone.openstack/'
		}
	    },

	    k2hdkc: {														// Slave configuration to K2HDKC cluster
		config:			'/etc/k2hdkc/slave.ini',					// Configuration file path for k2hdkc(chmpx) slave
		port:			'8031'										// Control port number for k2hdkc(chmpx) slave
	    },

	    corsips:			[											// CORS IP Addresses
		'::ffff:127.0.0.1',
		'127.0.0.1'
	    ],

	    scheme:				'http',										// Scheme
	    port:				80,											// Port
	    multiproc:			true,										// Multi processing
	    runuser:			'',											// Username for process owner
	    privatekey:			'',											// Privatekey file path
	    cert:				'',											// Certification file path
	    ca:					'',											// CA

	    logdir:				null,										// Path for logging directory
	    fixedlogdir:		null,										// Fixed log directory
	    accesslogname:		'access.log',								// Access log name
	    accesslogform:		'combined',									// Access log format by morgan
	    consolelogname:		null,										// Console(Error)/Debug log name
	    watcherlogname:		'watcher.log',								// Watcher log name
	    watchertimeform:	'yyyy/mm/dd HH:MM:ss',						// Watcher log time format by dateformat
	    wconsolelogname:	null,										// Console(Error)/Debug log name by watcher
	    logrotateopt: 		{											// rotating-file-stream option object
		compress:			'gzip',									// gzip		: compression method of rotated files.
		interval:			'6h',									// 6 hour	: the time interval to rotate the file.
		initialRotation:	true,									// true		: initial rotation based on not-rotated file timestamp.
		path:				null									// null		: the base path for files.(* this value is replace by 'logdir')
		/*
		 *  [NOTE] following option is not specified now.
		 *
		 rotationTime:		true,									// true		: makes rotated file name with time of rotation.
		 highWaterMark:		null,									// null		: proxy to new stream.
		 history:			null,									// null		: the history filename.
		 immutable:			null,									// null		: never mutates file names.
		 maxFiles:			null,									// null		: the maximum number of rotated files to keep.
		 maxSize:			null,									// null		: the maximum size of rotated files to keep.
		 mode:				null,									// null		: proxy to fs.createWriteStream
		 rotate:				null,									// null		: enables the classical UNIX logrotate behaviour.
		 size:				null									// null		: the file size to rotate the file.
		*/
	    },

	    userdata:			{											// Userdata for Openstack
		baseuri:			'https://localhost',					// URI
		cc_templ:			'config/k2hr3-cloud-config.txt.templ',	// Template for Cloud Config part
		script_templ:		'config/k2hr3-init.sh.templ',			// Template for Shell part
		errscript_templ:	'config/k2hr3-init-error.sh.templ',		// Template for common shell if error
		algorithm:			'aes-256-cbc',							// Encrypt type
		passphrase:			'k2hr3_regpass'							// Default passphrase
	    },

	    k2hr3admin:			{											// K2HR3 Admin information for example is removing IPn Addresses
		tenant:				'admintenant',							// Admin tenant name
		delhostrole:		'delhostrole'							// Admin Role name
	    },

	    confirmtenant:		false,										// Whichever confirm tenant when adding service member

	    chkipconfig:		{											// IP Addresses checker(watcher) type
		type:				CHKIPCONFIGTYPE.CHECKER_TYPE_LISTENER,	// Listener / Function / Basic{Or|And} / NoCheck
		funcmod:			null,									// Module name(path) for Function type
		pendingsec:			864000,									// Limit for removing IP which is not alive         : 10 * 24 * 60 * 60   = 10 days
		intervalms:			4320000,								// Interval ms for checking IP address              : 12 * 60 * 60 * 1000 = 12 hour
		parallelcnt:		32,										// Parallel processing count
		command4:			'ping',									// Basic IP address check use this command for IPv4 : ping command
		command6:			'ping6',								// Basic IP address check use this command for IPv6
		params:				'-c 1',									// Common ping command parameters
		timeoutparam:		'-W',									// Timeout parameter name for ping command
		timeoutms:			5000									// Timeout millisecond for each checking            : 5000ms
	    },
	    allowcredauth:		true,										// allow CORS access for authorization by credential

	    expiration:				{										// Expiration for Tokens
		roletoken:			86400,									// Expire time(sec) for RoleToken                   : 24 * 60 * 60   = 1 day
		regroletoken:		315360000								// Expire time(sec) for register host               : 10 * 356 * 24 * 60 * 60   = 10 years(no expire)
	    }
	};
    }

    //
    // methods
    //

    configureAccessLogName(r3apikey, val) {
	if (r3apikey.localeCompare(ACCESSLOGNAME) == 0) {
	    this.data.accesslogname = val;
	}
    }

    configureAllowCredAuth(r3apikey, val) {
	if (r3apikey.localeCompare(ALLOWCREDAUTH) == 0) {
	    if( val.localeCompare("true") ) {
	        this.data.allowcredauth = true;
	    } else {
	        this.data.allowcredauth = false;
	    }
	}
    }

    configureCA(r3apikey, val) {
	if (r3apikey.localeCompare(CA) == 0) {
	    this.data.ca = val;
	}
    }

    configureCERT(r3apikey, val) {
	if (r3apikey.localeCompare(CERT) == 0) {
	    this.data.cert = val;
	}
    }

    configureChkConfigType(r3apikey, val) {
	if (r3apikey.localeCompare(CHKIPCONFIG_TYPE) == 0) {
	    this.data.chkipconfig_type = val;
	}
    }

    configureConfirmTenant(r3apikey, val) {
	if (r3apikey.localeCompare(CONFIRMTENANT) == 0) {
	    if( val.localeCompare("true") ) {
	        this.data.confirmtenant = true;
	    } else {
	        this.data.confirmtenant = false;
	    }
	}
    }

    configureConsoleLogName(r3apikey, val) {
	if (r3apikey.localeCompare(CONSOLELOGNAME) == 0) {
	    this.data.consolelogname = val;
	}
    }

    configureCorsIps(r3apikey, val) {
	if (r3apikey.localeCompare(CORSIPS) == 0) {
	    // NOTE: CORSIPS data is in a csv data like "a=b,c=d"
	    let iparray = [];
	    let spos = 0; // startPos
	    let pos = 0;
	    do {
		pos = val.indexOf(',', spos);
		if (this.debug) {
		    console.log('pos=' + pos);
		}
		if (pos !== -1) { // found a comma
		    iparray.push(val.substring(spos, pos));
		} else {
		    iparray.push(val.substr(spos));
		}
		spos = pos + 1;
	    } while(pos !== -1);
	    this.data.corsips = iparray;
	}
    }

    configureK2hdkcConfig(r3apikey, val) {
	if (r3apikey.localeCompare(K2HDKC_CONFIG) == 0) {
	    this.data.k2hdkc.config = val;
	}
    }

    configureK2hdkcPort(r3apikey, val) {
	if (r3apikey.localeCompare(K2HDKC_PORT) == 0) {
	    this.data.k2hdkc.port = val;
	}
    }

    configureK2hr3AdminDelhostRole(r3apikey, val) {
	if (r3apikey.localeCompare(K2HR3ADMIN_DELHOSTROLE) == 0) {
	    this.data.k2hr3admin.delhostrole = val;
	}
    }

    configurek2hr3AdminTenant(r3apikey, val) {
	if (r3apikey.localeCompare(K2HR3ADMIN_TENANT) == 0) {
	    this.data.k2hr3admin.tenant = val;
	}
    }

    configureKeystoneEpfile(r3apikey, val) {
	if (r3apikey.localeCompare(KEYSTONE_EPFILE) == 0) {
	    this.data.keystone.epfile = val;
	}
    }

    configureKeystoneEplist(r3apikey, val) {
	if (r3apikey.localeCompare(KEYSTONE_EPLIST) == 0) {
	    this.data.keystone.eplist = val;
	}
    }

    configureKeystoneEptype(r3apikey, val) {
	if (r3apikey.localeCompare(KEYSTONE_EPTYPE) == 0) {
	    this.data.keystone.eptype = val;
	}
    }

    configureKeystonType(r3apikey, val) {
	if (r3apikey.localeCompare(KEYSTONE_TYPE) == 0) {
	    this.data.keystone.type = val;
	}
    }

    configureLogdir(r3apikey, val) {
	if (r3apikey.localeCompare(LOGDIR) == 0) {
	    this.data.logdir = val;
	}
    }

    configureLogrotateOptCompress(r3apikey, val) {
	if (r3apikey.localeCompare(LOGROTATEOPT_COMPRESS) == 0) {
	    this.data.logrotateopt.compress = val;
	}
    }

    configureLogrotateOptInitialRotation(r3apikey, val) {
	if (r3apikey.localeCompare(LOGROTATEOPT_INITIALROTATION) == 0) {
	    if( val.localeCompare("true") ) {
	        this.data.logrotateopt.initialRotation = true;
	    } else {
	        this.data.logrotateopt.initialRotation = false;
	    }
	}
    }

    configureLogrotateOptInternal(r3apikey, val) {
	if (r3apikey.localeCompare(LOGROTATEOPT_INTERVAL) == 0) {
	    this.data.logrotateopt.interval = val;
	}
    }

    configureMultiproc(r3apikey, val) {
	if (r3apikey.localeCompare(MULTIPROC) == 0) {
	    if( val.localeCompare("true") ) {
	        this.data.multiproc = true;
	    } else {
	        this.data.multiproc = false;
	    }
	}
    }

    configurePort(r3apikey, val){
	if (r3apikey.localeCompare(PORT) == 0) {
	    this.data.port = val;
	}
    }

    configurePrivatekey(r3apikey, val) {
	if (r3apikey.localeCompare(PRIVATEKEY) == 0) {
	    this.data.privatekey = val;
	}
    }

    configureRunuser(r3apikey, val) {
	if (r3apikey.localeCompare(RUNUSER) == 0) {
	    this.data.runuser = val;
	}
    }

    configureScheme(r3apikey, val) {
	if (r3apikey.localeCompare(SCHEME) == 0) {
	    this.data.scheme = val;
	}
    }

    configureUserdataAlgorithm(r3apikey, val) {
	if (r3apikey.localeCompare(USERDATA_ALGORITHM) == 0) {
	    this.data.userdata.algorithm = val;
	}
    }

    configureUserdataBaseUri(r3apikey, val) {
	if (r3apikey.localeCompare(USERDATA_BASEURI) == 0) {
	    this.data.userdata.baseuri = val;
	}
    }

    configureUserdataCcTempl(r3apikey, val) {
	if (r3apikey.localeCompare(USERDATA_CC_TEMPL) == 0) {
	    this.data.userdata.cc_templ = val;
	}
    }

    configureUserdataErrScriptTempl(r3apikey, val) {
	if (r3apikey.localeCompare(USERDATA_ERRSCRIPT_TEMPL) == 0) {
	    this.data.userdata.errscript_templ = val;
	}
    }

    configureUserdataScriptTempl(r3apikey, val) {
	if (r3apikey.localeCompare(USERDATA_SCRIPT_TEMPL) == 0) {
	    this.data.userdata.script_templ = val;
	}
    }

    configureWatcherLogname(r3apikey, val) {
	if (r3apikey.localeCompare(WATCHERLOGNAME) == 0) {
	    this.data.watcherlogname = val;
	}
    }

    configureWconsoleLogname(r3apikey, val) {
	if (r3apikey.localeCompare(WCONSOLELOGNAME) == 0) {
	    this.data.wconsolelogname = val;
	}
    }

    // configure
    // This method binds ini items with json items and it also changes ini item data format to json data format.
    //
    // Params::
    //  $1 data item name, which name starts with "k2hr3_api_"
    //  $2 value of the item
    //
    // Returns::
    //  true on success
    //
    configure(key, val) {
	let p = key.startsWith('k2hr3_api_');
	if (!p) {
	    console.log('key is not for k2hr3_api');
	    return false;
	}
	let r3apikey = key.slice(9+1); // strlen(k2hr3_api_) + 1
	this.configureAccessLogName(r3apikey, val);
	this.configureAllowCredAuth(r3apikey, val);
	this.configureCA(r3apikey, val);
	this.configureCERT(r3apikey, val);
	this.configureChkConfigType(r3apikey, val);
	this.configureConfirmTenant(r3apikey, val);
	this.configureConsoleLogName(r3apikey, val);
	this.configureCorsIps(r3apikey, val);
	this.configureK2hdkcConfig(r3apikey, val);
	this.configureK2hdkcPort(r3apikey, val);
	this.configureK2hr3AdminDelhostRole(r3apikey, val);
	this.configurek2hr3AdminTenant(r3apikey, val);
	this.configureKeystoneEpfile(r3apikey, val);
	this.configureKeystoneEplist(r3apikey, val);
	this.configureKeystoneEptype(r3apikey, val);
	this.configureKeystonType(r3apikey, val);
	this.configureLogdir(r3apikey, val);
	this.configureLogrotateOptCompress(r3apikey, val);
	this.configureLogrotateOptInitialRotation(r3apikey, val);
	this.configureLogrotateOptInternal(r3apikey, val);
	this.configureMultiproc(r3apikey, val);
	this.configurePort(r3apikey, val);
	this.configurePrivatekey(r3apikey, val);
	this.configureRunuser(r3apikey, val);
	this.configureScheme(r3apikey, val);
	this.configureUserdataAlgorithm(r3apikey, val);
	this.configureUserdataBaseUri(r3apikey, val);
	this.configureUserdataCcTempl(r3apikey, val);
	this.configureUserdataErrScriptTempl(r3apikey, val);
	this.configureUserdataScriptTempl(r3apikey, val);
	this.configureWatcherLogname(r3apikey, val);
	this.configureWconsoleLogname(r3apikey, val);
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
    R3apiJson
}
