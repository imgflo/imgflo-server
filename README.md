[![Build Status](https://travis-ci.org/imgflo/imgflo-server.svg?branch=master)](https://travis-ci.org/imgflo/imgflo-server)

imgflo-server
==========
imgflo-server is an image-processing server with HTTP built using the
[imgflo](http://github.com/imgflo/imgflo) dataflow runtime.

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Changelog
----------
See [./CHANGES.md](./CHANGES.md)

License
--------
[MIT](https://opensource.org/licenses/MIT)

Note: GEGL itself is under LGPLv3.


About
-------
The imgflo server provides a HTTP API for processing images: 

    GET /graphs/mygraph?input=http://example.com/input-image.png&attr1=value1&....

When the server gets the request, it will:

1. Download the specified `input` image over HTTP(s)
2. Find and load the graph `mygraph`
3. Set attribute,value pairs as IIPs to the exported ports of the graph
4. Processes the graph using a runtime`*`
5. Stores the output image to disk
6. Serve the output image over HTTP

Note: In step 4, currently a new runtime is spawned for each request, and communication done through stdin.
In the future, the runtime will be a long-running worker, and communication done using the FBP runtime protocol.

`*`In addition to supporting the native imgflo runtime,
the server can also execute graphs built with NoFlo w/ noflo-canvas.


API usage
======================

## JavaScript / node.js / browser
--------------------

1. Forming valid imgflo urls: [imgflo-url](https://www.npmjs.org/package/imgflo-url)
2. Creating responsive images using media-query: [rig](https://www.npmjs.org/package/rig-up)

## Java / Android

[imgflo-url-java](https://github.com/the-grid/imgflo-url-java)

## Swift / iOSs

[ImgFlo.swift](https://github.com/the-grid/ImgFlo.swift)


Creating new image processing graphs
=====================
imgflo-server can easily be extended with new image processing pipelines,
either using a text-based DSL or Flowhub node-based visual IDE.

See [Adding Graphs](./doc/adding-graphs.md)

Hosted public instance
======================

Currently our [deployed instance](http://imgflo.herokuapp.com) is only for [The Grid](http://thegrid.io).
If you are interested in access to hosted version, send us an email: [support@thegrid.io](mailto://support@thegrid.io)


Deploying to Heroku
==========================

Server
--------
Register/log-in with [Heroku](http://heroku.com), and create a new app. First one is free.

After creating the app, login at Heroku:

    heroku login

Clone `imgflo-server`:

    git clone https://github.com/imgflo/imgflo-server.git
    cd imgflo-server

Add YOURAPP as remote:

    heroku git:remote -a YOURAPP

Specify the multi buildpack with build-env support, either at app creation time, in Heroku webui or using

    heroku config:set BUILDPACK_URL=https://github.com/mojodna/heroku-buildpack-multi.git#build-env

Configure some environment variables (hostname, port and local image cache):

    heroku config:set HOSTNAME=YOURAPP.herokuapp.com
    heroku config:set PORT=80

Deploy, will take ~1 minute

    git push heroku master

You should now see the imgflo server running at http://YOURAPP.herokuapp.com

If everything is OK you should be
able to see a generative image at http://YOURAPP.herokuapp.com/graph/delaunay_triangles?seed=foobar&height=800&width=600

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



