#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

# TODO: add more tests
# processing new (200 or 301 to image/ ? )
#   works - with remote HTTP URL
#   w - remote HTTP with .PNG
#   w - remote HTTP with .JPG
#   w - remote HTTP without extension, content type image/png
#   w - remote HTTP without extension, .. image/jpeg
#   w - HTTP url with redirect
#
#   ? - content-type different from extension
#
#   maybe; w - content type application/x-octet-stream, but valid JPG/PNG
#
#   error - unsupported content type (449)
#   e - input parameter missing
#   e - url gives 404 (404)
#   e - url does not load for other reasons (504)
#   e - invalid parameter value (422?)
#      -- too big/small numbers
#   e - valid ext,content-type, but invalid image
#
#   w - get cached / previously processed image (301)
#       .. test all the processing cases
#
# stress
# works - multiple requests at same time
#
# error - too many requests (429?)
# e - too big file download, bytes: (413)
# e - too large image, width/height (413)
#
# adverse conditions
# e - compression explosion exploits
# e - code-in-metadata-chunks
# e - input url points to localhost (local to server)
# e - infinetely/circular redirects
# e - chained/recursive processing requests
#
# introspection
#  w - list available graphs, and their properties

server = require '../src/server'
utils = require './utils'
http = require 'http'
fs = require 'fs'
path = require 'path'
url = require 'url'

chai = require 'chai'
request = require 'request'

urlbase = process.env.IMGFLO_TESTS_TARGET
urlbase = 'localhost:8889' if not urlbase
port = (urlbase.split ':')[1]
verbose = process.env.IMGFLO_TESTS_VERBOSE?
startServer = (urlbase.indexOf 'localhost') == 0
itSkipRemote = if not startServer then it.skip else it

graph_url = (graph, props) ->
    return utils.formatRequest urlbase, graph, props

describe 'Server', ->
    s = null

    before (done) ->
        wd = './testtemp'
        if fs.existsSync wd
            for f in fs.readdirSync wd
                fs.unlinkSync path.join wd, f
        if startServer
            s = new server.Server wd, null, null, verbose
            l = new utils.LogHandler s
            s.listen port, () ->
                done()

    after ->
        s.close() if startServer

    describe 'Get version info', ->
        info = null
        it 'returns valid data', (done) ->
            u = url.format {protocol:'http:',host: urlbase, pathname:'/version'}
            request u, (err, response, body) ->
                chai.expect(err).to.not.exist
                info = JSON.parse body
                done()
        it 'gives NPM version', ->
            chai.expect(info.npm).to.equal '0.0.3'
        it 'gives server version', ->
            chai.expect(info.server).to.be.a 'string'
        it 'gives runtime version', ->
            chai.expect(info.runtime).to.be.a 'string'
        it.skip 'gives GEGL version', ->
            chai.expect(info.gegl).to.be.a 'string'
        it.skip 'gives BABL version', ->
            chai.expect(info.babl).to.be.a 'string'

    describe 'List graphs', ->
        expected = []
        for g in fs.readdirSync './graphs'
            expected.push g.replace '.json', '' if (g.indexOf '.json') != -1
        responseData = ""
        it 'HTTP request', (done) ->
            u = url.format {protocol:'http:',host: urlbase, pathname:'/demo'}
            http.get u, (response) ->
                chai.expect(response.statusCode).to.equal 200
                response.on 'data', (chunk) ->
                    responseData += chunk.toString()
                response.on 'end', () ->
                    done()
        it 'should return all graphs', () ->
            d = JSON.parse responseData
            actual = Object.keys d.graphs
            chai.expect(actual).to.deep.equal expected

    describe 'Graph request', ->
        describe 'with invalid graph parameters', ->
            u = graph_url 'gradientmap', {skeke: 299, oooor:222, input: "demo/grid-toastybob.jpg"}
            data = ""
            it 'should give HTTP 449', (done) ->
                http.get u, (response) ->
                    chai.expect(response.statusCode).to.equal 449
                    response.on 'data', (chunk) ->
                        data += chunk.toString()
                    response.on 'end', () ->
                        done()
            it 'should list valid parameters', ->
                d = JSON.parse data
                e = ['input', 'color1', 'color2', "color3", "color4", "color5",
                    "stop1", "stop2", "stop3", "stop4", "stop5", "srgb", "opacity"]
                chai.expect(Object.keys(d.inports)).to.deep.equal

    describe 'Get image', ->
        u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "demo/grid-toastybob.jpg" }
        res = null
        location = null

        it 'should be created on demand', (done) ->
            @timeout 4000
            checkProcessed = (id) ->
                chai.expect(id).to.not.contain 'error'
                if id == 'serve-processed-file'
                    s.removeListener 'logevent', checkProcessed
                    done()
            s.on 'logevent', checkProcessed # NOTE: Grey-box
            http.get u, (response) ->
                res = response

        it 'should redirect to cached file', () ->
            chai.expect(res.statusCode).to.equal 301
            location = res.headers['location']
            chai.expect(location).to.contain '/cache/' # TODO: make stricter
        it 'redirect should point to created image', (done) ->
            http.get location, (response) ->
                chai.expect(response.statusCode).to.equal 200
                response.on 'data', (chunk) ->
                    fs.appendFile 'testout.png', chunk, ->
                        #
                response.on 'end', ->
                    fs.exists 'testout.png', (exists) ->
                        chai.assert exists, 'testout.png does not exist'
                        done()

    describe 'Get existing image', ->
        u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "demo/grid-toastybob.jpg" }

        it 'existing graph should be cached and redirected', (done) ->
            http.get u, (response) ->
                chai.expect(response.statusCode).to.equal 301
                response.on 'end', ->
                    # console.log response.headers
                    done()
