var webpack = require('webpack');
var path = require('path');
var fs = require('fs');

module.exports = {
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee-loader" },
      { test: /\.json$/, loader: "json-loader" }
    ]
  },
  resolve: {
    extensions: ["", ".web.coffee", ".web.js", ".coffee", ".js"]
  },
  entry: './worker.webpack.js',
  target: 'node',
  node: {
    __dirname: true,
  },
  output: {
    path: path.join(__dirname, 'build'),
    filename: 'worker.js'
  },
  externals: {
    'tv4': 'commonjs tv4', // needed by fbp, could not be found
    'websocket': 'commonjs websocket', // has native deps, looks them up dynamically
    'hiredis': 'commonjs hiredis', // needed by redis, could not be found
    'vertx': 'commonjs vertx', // needed by amqplib, could not be found
    'request': 'commonjs request', // failed with some amd define error at runtime
    'newrelic': 'commonjs newrelic', // needed by redis, could not be found
  },
  plugins: [
    new webpack.IgnorePlugin(/\.(css|less)$/),
    new webpack.IgnorePlugin(/\/coffee-script\//),
    new webpack.BannerPlugin('require("source-map-support").install();',
                             { raw: true, entryOnly: false })
  ],
  devtool: 'sourcemap'
}
