if (typeof process.env.NEW_RELIC_LICENSE_KEY !== 'undefined') { require('newrelic'); }
require('coffee-script/register')
require('./src/server.coffee').main()
