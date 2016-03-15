var webpack = require('webpack');
var path = require('path');
var fs = require('fs');

var nodeModules = {};
fs.readdirSync('node_modules')
  .filter(function(x) {
    return ['.bin'].indexOf(x) === -1;
  })
  .forEach(function(mod) {
    nodeModules[mod] = 'commonjs ' + mod;
  });

module.exports = {
  module: {
	  loaders: [
		  { test: /\.coffee$/, loader: "coffee" }
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
  externals: nodeModules,
  plugins: [
    new webpack.IgnorePlugin(/\.(css|less)$/),
    new webpack.BannerPlugin('require("source-map-support").install();',
                             { raw: true, entryOnly: false })
  ],
  devtool: 'sourcemap'
}
