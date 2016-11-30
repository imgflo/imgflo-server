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


# API

imgflo-server provides a HTTP API for processing images.
The entire processing request is described using an URL, and the processing can be triggered by a HTTP GET.
This means no special integration is needed in order to use an image processed by imgflo-server in an application.

## Process image and get results

Request

    GET /graphs/mygraph?input=http://example.com/input-image.png&attr1=value1&....

Response

    HTTP 301
    Location: https://s3.aws.com/bucket/er132123sder12.png

If the image has been processed before, it will come straight from cache (fast).

## Process image without waiting for result

Request

    POST /graphs/mygraph?input=http://example.com/input-image.png&attr1=value1&....

Response

    HTTP 301
    Location: https://s3.aws.com/bucket/er132123sder12.png

Since the image is not processed by the time the response arrives,
accessing the `Location` immediately will likely fail (with a 404 or 403).
If the image processing failed, it may fail forever.
Use a `GET` with the same imgflo URL to get the error.

## Get available image processing graphs

The `inports` describe which parameters are available for each graph.

Request

    GET /graphs

Response

    HTTP 200 application/json
```json
{
  "graphs": {
    "customgrey": {
      "inports": {
        "input": {
        },
        "height": {
          "metadata": {
            "description": "Requested output height",
            "type": "int",
            "maximum": 2000,
            "minimum": 0
          }
        },
        "width": {
          "metadata": {
            "description": "Requested output width",
            "type": "int",
            "maximum": 2000,
            "minimum": 0
          }
        }
      },
      "outports": {
        "output": {
        }
      }
    }
}
```

## Authentication

To prevent people from using your deployment to process their images, there exists a version of the
processing URLs which has an encrypted token in it.



## Errors

* 504: Unable to fetch the specified `input` URL 
* ...

# API client libraries

These make it easier to use the API, by providing

## JavaScript / node.js / browser
--------------------

1. Forming valid imgflo urls: [imgflo-url](https://www.npmjs.org/package/imgflo-url)
2. Creating responsive images using media-query: [rig](https://www.npmjs.org/package/rig-up)

## Java / Android

[imgflo-url-java](https://github.com/the-grid/imgflo-url-java)

## Swift / iOSs

[ImgFlo.swift](https://github.com/the-grid/ImgFlo.swift)


# Testing UI

imgflo-server ships with a simple testing UI served at `/`.
It can be used to see the available graphs, and make test requests and see the results.

`TODO: add picture`

## Use for debugging a request

Given a regular imgflo URL, you can add `&debug=1` at the end to open it in the UI.
It will extract the parameters, including removing the urlencoding on the `input` URL.


Creating new image processing graphs
=====================
imgflo-server can easily be extended with new image processing pipelines,
either using a text-based DSL or Flowhub node-based visual IDE.

See [Adding Graphs](./doc/adding-graphs.md)

# System architecture

For an in-depth look at how the system is implemented, see [system architecture](./doc/system-architecture.md)

Hosted public instance
======================

Currently our [deployed instance](https://imgflo.herokuapp.com) is only for [The Grid](http://thegrid.io).
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
Note: imgflo-server is only tested on GNU/Linux systems.
imgflo (the runtime) has experimental support for OSX.
However, all underlying dependencies (node.js, RabbitMQ, GEGL etc) are commonly used also on other platforms, like Windows. 

_Root is not needed_ for any of the build.

Pre-requisites
---------------
imgflo requires git master of GEGL and BABL, as well as a custom version of libsoup.
It is recommended to let make setup this for you, but you can use existing checkouts
by customizing PREFIX.
You only need to install the dependencies once, or when they have changed.

    git submodule update --init --recursive
    make dependencies

Install node.js dependencies

    npm install

Build
-------
Now you can build & install imgflo-server itself

    make install

To verify that things are working, run the test suite

    make check


Running server
----------------

    node index.js

You should see your server running at http://localhost:8080


