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
