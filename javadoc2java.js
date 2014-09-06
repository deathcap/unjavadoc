'use strict';

var fs = require('fs');

var fn = '../jd-bukkit/jd.bukkit.org/rb/apidocs/org/bukkit/Achievement.html';

console.log(fs.readFileSync(fn, 'utf8'));
