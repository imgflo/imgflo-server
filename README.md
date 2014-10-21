[![Build Status](https://travis-ci.org/jonnor/imgflo.svg?branch=master)](https://travis-ci.org/jonnor/imgflo)

imgflo-server
==========
imgflo-server is an image-processing server with HTTP built using the
[imgflo](http://github.com/jonnor/imgflo) dataflow runtime.

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Changelog
----------
See [./CHANGES.md](./CHANGES.md)

License
--------
MIT

Note: GEGL itself is under LGPLv3.


About
-------
The imgflo server provides a HTTP API for processing images: 

    GET /graphs/mygraph?input=http://example.com/input-image.png&attr1=value1&....

When the server gets the request, it will:

1. Download the specified 'input' image over HTTP(s)
2. Find and load the graph 'mygraph'
3. Set attribute,value pairs as IIPs to the exported ports of the graph
4. Processes the graph using a runtime*
5. Stores the output image to disk
6. Serve the output image over HTTP

Note: In step 4, currently a new runtime is spawned for each request, and communication done through stdin.
In the future, the runtime will be a long-running worker, and communication done using the FBP runtime protocol.

In addition to supporting the native imgflo runtime, the server can also execute graphs
built with NoFlo and noflo-canvas. See [creating new graphs for server](#creating-new-graphs-for-server).


API usage
======================

JavaScript helpers
--------------------

1. Forming valid imgflo urls: [imgflo-url](https://www.npmjs.org/package/imgflo-url)
2. Creating responsive images using media-query: [rig](https://www.npmjs.org/package/rig-up)


Deploying to Heroku
==========================

Server
--------
Register/log-in with [Heroku](http://heroku.com), and create a new app. First one is free.

Specify the multi buildpack with build-env support, either at app creation time, in Heroku webui or using

    heroku config:set BUILDPACK_URL=https://github.com/mojodna/heroku-buildpack-multi.git#build-env

In your git checkout of imgflo, add your Heroku app as a remote.

    git remote add heroku git@heroku.com:YOURAPP.git

Deploy, will take ~1 minute

    git push heroku

You should now see the imgflo server running at http://YOURAPP.herokuapps.com


Developing and running locally
==========================
Note: imgflo has only been tested on GNU/Linux systems.
_Root is not needed_ for any of the build.

Pre-requisites
---------------
imgflo requires git master of GEGL and BABL, as well as a custom version of libsoup.
It is recommended to let make setup this for you, but you can use existing checkouts
by customizing PREFIX.
You only need to install the dependencies once, or when they have changed.

    git submodule update --init
    make dependencies

_If_ you are on an older distribution, you may also need a newer glib version

    # make glib # only for older distros, where GEGL fails to build due to too old glib

Install node.js dependencies

    npm install

Build
-------
Now you can build & install imgflo itself

    make install

To verify that things are working, run the test suite

    make check


Running server
----------------

    node index.js

You should see your server running at http://localhost:8080


Creating new graphs for server
=============================

We recommend creating graphs visually using [Flowhub](http://app.flowhub.io).
If you use the git integration in Flowhub and use your imgflo fork as the project,
new graphs will automatically be put in the right place.

If you manually export from Flowhub, put the .json in the 'graphs' directory.

You can however also use hand-write the graph using the .fbp DSL,
and convert it to JSON using the [fbp](http://github.com/noflo/fbp) command-line tool.
Or, you could generate the .json file programatically.

imgflo runtime
--------------

By convention a graph should export
* One inport named 'input', which receives the input buffer
* One outport named 'output', which provides the output buffer
All other exported inports will be accessible as attributes which can be set.

The 'properties.environment.type' JSON key should be set to "imgflo".
Flowhub does this automatically.

noflo-nodejs w/noflo-canvas
----------------------------

By convention a graph should export
* One inport named 'canvas', which receives the canvas to draw on
* One outport named 'output', which provides the canvas after drawing
All other exported inports will be accessible as attributes which can be set.

imgflo will automatically expose 'height' and 'width' attributes, and will
set the size of the canvas element to this. Graphs may access this information
from the canvas element using objects/ExtractProperty.

The 'properties.environment.type' JSON key should be set to "noflo-browser" or "noflo-nodejs".
Flowhub does this automatically.
Note: The graph will be executed on node.js, so the graph must not require any API specific to the browser.
