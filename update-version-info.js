require('coffee-script/register');
var common = require('./src/common');
common.updateInstalledVersions(function(err, path) {
    if (err) {
        throw err;
    }    
    console.log('Wrote: ' + path);
});
