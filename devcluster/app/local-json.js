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
// This program generates a local.json of k2hr3-app from a k2hr3-utils setup.ini
//
'use strict';

const path = require('path');
const srcdir = path.resolve(__dirname);
const process = require('process');

if ( process.argv.length != 4) {
	let err = "Usage: node " + process.argv[1] + " <path to setup.ini> <path to local.json>";
	console.error(err);
	throw new Error(err);
}

const input = process.argv[2];
const output = process.argv[3];
try {
	let rci = require(path.join(srcdir, 'r3clusterini.js'));
	let raj = require(path.join(srcdir, 'r3appjson.js'));
	let cluster = new rci.R3clusterIni(input, 'k2hr3_app');
	let r3app = new raj.R3appJson();
	for (const val of cluster) {
		r3app.configure(val[0], val[1]); // key, value
	}
	r3app.dumpTo(output);
} catch (err) {
	console.error(err.name + ' ' + err.message);
}

/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: noexpandtab sw=4 ts=4 fdm=marker
 * vim<600: noexpandtab sw=4 ts=4
 */
