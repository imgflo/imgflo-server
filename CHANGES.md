imgflo-server 0.3.0
==================
Released: January 23nd, 2015

See-also [imgflo-runtime release notes](https://github.com/jonnor/imgflo)

Changes
--------

Fix Heroku button deploy not working due to git submodule.

Add support for custom GEGL/imgflo operations.
Ops dropped into components/* will be built & installed.

Local cache is now default, use `IMGFLO_CACHE=s3` to use Amazon S3.

Fixed very large output files sizes for PNGs.
Was using 16 bits-per-channel and very low compression. Output now 5-10 times smaller.

Added support for noflo-canvas graphs to act as filters on input images,
not just purely generative. The `canvas` input port will now contain the
input, if any.

Add support for scaling by passing only one dimension (height/width).
The image will then be scaled by preserving input aspect-ratio.
Explicitly passing a value of -1 can also be used to mean "not specified".

Added a set of image filters inspired by those used by Instagram:
Lord Kelvin, Brannan, Nashville, Hefe, XProII and 1977.

The demo webapp will now remember API key/secret using LocalStorage, if entered.

imgflo-server 0.2.0
==================
Released: October 28th, 2014

imgflo-server has now been stress-tested and improved to be good enough for a typical website,
meaning one which does not change/add images more than a couple times a day.
It is now used in production at [thegrid.io](http://thegrid.io), serving 10k++ visits/day.

runtime
--------
Moved to separate git repository [jonnor/imgflo](https://github.com/jonnor/imgflo)

clients
-------
New JavaScript helper libraries by [Paul Young](https://github.com/paulyoung) are now available:

[imgflo-url](https://www.npmjs.org/package/imgflo-url) and [rig](https://www.npmjs.org/package/rig-up)

server
-------

Added support for more IIP types in HTTP API,
including enums, booleans and CSS-compliant colors on format `#RGB[A] and #RRGGBB[AA]`

Added support for processing images through graphs made with [NoFlo](http://noflojs.org)
with [noflo-canvas](http://github.com/noflo/noflo-canvas) and [noflo-image](http://github.com/noflo/noflo-image).
See the README for details on adding new graphs for the different runtimes.

Added support for optionally specifying desired output image format,
using `/graph/mine.png|jpg` instead of `/graph/mine`.
Default image format has changed from PNG to JPEG.

All `GET /graph` requests now support `height` and `width` query parameters,
which will rescale the image to requested size.
NB: Specifying *only height/width not supported*.

Added support for authenticated requests using API key + secret.
Use envvars `IMGFLO_API_KEY=some-key` and `IMGFLO_API_SECRET=some-secret` to enable.
The full syntax of API requests is now:

    GET /graph[/$APIKEY][/$TOKEN]/$GRAPHNAME[.png]?[key1=val,key2=val]

Where $APIKEY is the configured IMGFLO_API_KEY for the server, and
$TOKEN is the md5sum of `$SECRET$GRAPHNAME[.png]?$key1=val,key2=val`

`GET /graph` requests will now return a `301 REDIRECT` to the processed result,
which may be already computed and cached.

An Amazon S3 bucket can be used as as cache instead of caching on same host.
Use envvar `IMGFLO_CACHE=s3` to enable, and
`AMAZON_API_ID`, `AMAZON_API_TOKEN`, `AMAZON_API_BUCKET`, `AMAZON_API_REGION` to configure.

HTTPS is now supported and, used by default with Heroku and Amazon S3 cache.

Graphs are now stored in /graphs directory instead of /examples, which means that
the project can be imported directly into Flowhub and one can push new graphs from there.

Default GEGL build now includes the 'workshop' operations.

New graphs included:

* gaussianblur
* passthrough
* delaunay_triangles

`gradientmap` now supports 5 stops instead of 1.


imgflo 0.1.0
=============
Released: April 30th, 2014

imgflo now consists of two complimentary parts:
a [Flowhub](http://flowhub.io)-compatible runtime for interactively building image processing graphs,
and an image processing server for image processing on the web.

The runtime combined with the Flowhub IDE allows to visually create image
processing pipelines in a node-based manner, similar to tools like the Blender node compositor.
Live image output is displayed in the preview area in Flowhub, and will
update automatically when changing the graph.

The server provides a HTTP API for processing an input image with an imgflo graph.
    GET /graph/mygraph?input=urlencode(http://example.com/input-image.jpeg)&param1=foo&param2=bar

The input and processed image result will be cached on disk.
On later requests to the same URL, the image will be served from cache.

The server can be deployed to Heroku with zero setup, just push the git repository to an Heroku app.

The operations used in imgflo are provided by GEGL, and new operations can be added using the C API.
A (somewhat outdated) list of operations can be seen here: http://gegl.org/operations.html

Blogpost: http://www.jonnor.com/2014/04/imgflo-0-1-an-image-processing-server-and-flowhub-runtime

imgflo 0.0.1
=============
Released: April 8th, 2014

Can execute a simple graphics pipeline with GEGL operations defined as FBP .json.
