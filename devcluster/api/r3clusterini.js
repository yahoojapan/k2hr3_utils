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
// This program generates a local.json of k2hr3-api from a k2hr3-utils setup.ini
//
'use strict';

const fs = require('fs');
const path = require('path');
const srcdir = path.resolve(__dirname);

//
// R3clusterIni
// represents cluster ini file
//
class R3clusterIni {
	//
	// Params::
	//  $1 a path to k2hr3_utils ini file
	//  $2 k2hr3_api or k2hr3_app)
	//
	// Returns::
	//  a R3clusterIni object on success
	//  throws exception on failure
	//
	constructor(ini, component) {
		// properties
		this.index = 0; // position of data processing
		this.debug = false;
		this.component = component || ''; // k2hr3-api or k2hr3-app

		// cluster parameters
		this.ini = ini || 'setup.ini';
		this.keys = [];
		this.vals = [];

		// parses a ini file and puts them to the key and value array members
		try {
			let buf = fs.readFileSync(this.ini, "utf8");

			// 1. split data by a line feed
			let p = buf.indexOf('\n');
			do {
				if (p !== -1) {
					const line = buf.slice(0, p);
					if (this.debug) {
						console.log('line=' + line);
					}

					let pos = line.indexOf('=');
					if (pos !== -1) {
						let key = line.substring(0, pos);
						if (typeof key === 'string' && key.length !== 0) {
							let val = line.substring(pos + 1);
							if (this.debug) {
								console.log('key=' + key + ' val=' + val);
							}

							// 2. picks up data of the component only
							if (key.startsWith(component)) {
								this.keys.push(key);
								this.vals.push(val);
							}
							if (key.localeCompare("env") == 0) {
								this.env = val;
							}
						}
					}
					buf = buf.slice(p + 1);
				}
				p = buf.indexOf('\n');
			} while(p !== -1);
		} catch (err) {
			console.error(err.name + ' ' + err.message);
			throw err;
		}

		// defines data.somedata if r3clusterini_k2hr3_api_ext.js exists.
		try {
			let extfile = path.join(srcdir, 'r3clusterini_k2hr3_api_ext.js');
			fs.accessSync(extfile, fs.constants.R_OK);

			// 1. filename
			// r3clusterini_k2hr3_api_ext.js

			// 2. class name
			// R3initExtraData

			// 3. methods
			// getData
			const extData = require(extfile);
			let instance = new extData.R3iniExtraData();
			console.log(this.env);
			console.log('instance.setEnv(this.env)');
			instance.setEnv(this.env);
			this.keys.push(instance.getKey());
			this.vals.push(instance.getData());
		} catch (err) {
			console.log('no access to r3clusterini_k2hr3_api_ext.js, just skipping it;)');
		}
	}

	//
	// methods
	//
	// next method
	// iterates the key and value array
	// https://developer.mozilla.org/ja/docs/Web/JavaScript/Reference/Iteration_protocols
	//
	// Returns::
	//  a pair of a key and a value
	//
	[Symbol.iterator]() {
		return {
			next: () => {
				if (this.index < this.keys.length) {
					let pos = this.index++;
					return {value: [this.keys[pos], this.vals[pos]], done: false};
				} else {
					this.index = 0;
					return {done: true};
				}
			}
		}
	}
}

// for debug
// var cluster = new R3clusterIni(path.join(srcdir, 'setup_api_centos.ini'), 'k2hr3_api');
// for (const val of cluster) {
//	 console.log(val);
// }

module.exports = {
	R3clusterIni
}

/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: noexpandtab sw=4 ts=4 fdm=marker
 * vim<600: noexpandtab sw=4 ts=4
 */
