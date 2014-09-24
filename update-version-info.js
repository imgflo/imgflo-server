require('coffee-script/register');
var common = require('./src/common');
common.updateInstalledVersions(function(err, path) {
    if (err) {
        console.log('ERROR:', err);
    }    
    console.log('Wrote: ' + path);
});
