var webpack = require('webpack');
var path = require('path');
var fs = require('fs');

module.exports = {
  module: {
	  loaders: [
		  { test: /\.coffee$/, loader: "coffee" },
      { test: /\.json$/, loader: "json" }
	  ]
  },
  resolve: {
	  extensions: ["", ".web.coffee", ".web.js", ".coffee", ".js"]
  },
  entry: './worker.webpack.js',
  target: 'node',
  output: {
    path: path.join(__dirname, 'build'),
    filename: 'worker.js'
  },
  externals: {
    'websocket': 'commonjs websocket', // has native deps, looks them up dynamically
    'coffee-script': 'commonjs coffee-script', // should not be needed at all?
    'mqtt': 'commonjs mqtt', // has some file with #! in it
    'hiredis': 'commonjs hiredis', // needed by redis, could not be found
    'vertx': 'commonjs vertx', // needed by amqplib, could not be found
    'request': 'commonjs request', // failed with some amd define error at runtime
  },
  plugins: [
    new webpack.IgnorePlugin(/\.(css|less)$/),
    new webpack.IgnorePlugin(/\/coffee-script\//),
    new webpack.BannerPlugin('require("source-map-support").install();',
                             { raw: true, entryOnly: false })
  ],
  devtool: 'sourcemap'
}
