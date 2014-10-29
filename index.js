require('coffee-script/register')
if (typeof process.env.NEWRELIC_LICENSE_KEY !== 'undefined') {
    require('newrelic');
}
require('./src/server.coffee').main()
