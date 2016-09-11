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
applications = require '../src/applications'
common = require '../src/common'
utils = require './utils'

http = require 'http'
fs = require 'fs'
path = require 'path'
url = require 'url'

chai = require 'chai'
request = require 'request'

http.globalAgent.maxSockets = Infinity # for older node.js

config = utils.getTestConfig()
startServer = (config.api_host.indexOf 'localhost') == 0
itSkipRemote = if not startServer then it.skip else it
urlbase = config.api_host # compat

cacheurl = '/cache/' if config.cache_type.indexOf('local') != -1
cacheurl = 'amazonaws.com' if config.cache_type.indexOf('s3') != -1

graph_url = (graph, props, key, secret) ->
    return utils.formatRequest config.api_host, graph, props, key, secret

getBody = (res, callback) ->
    body = '';
    res.on 'data', (chunk) ->
        body += chunk.toString()
    res.on 'end', () ->
        return callback null, body

enableTestAuth = (server) ->
    server.authdb =
        'ooShei0queigeeke':
            admin: false
            secret: 'reeva9aijo1Ooj9w'
            enabled: true
            processing_quota: 1
        'niem4Hoodaku':
            admin: true
            secret: 'reiL1ohqu1do'
            enabled: true
            processing_quota: 1
        'zero-processing-quota':
            admin: false
            secret: 'zero0zero'
            processing_quota: 0
            enabled: true
        'not-enabled':
            admin: false
            secret: 'disabled4reasons'
            enabled: false
            processing_quota: 1

HTTP =
    get: http.get

    post: (u, cb) ->
        # convenience similar to node.js http.get
        options = url.parse u
        options.method = 'POST'
        req = http.request options, cb
        req.end()


commonGraphTests = (type, state) ->
    s = state
    method = type.toLowerCase()
    successCode = if method == 'post' then 202 else 301

    describe 'Requested height*width higher than limit', ->
        u = graph_url 'passthrough', { height: 30000, width: 1000, input: "files/grid-toastybob.jpg" }

        it 'should fail with a 422', (done) ->

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 422
                done()

    describe 'Requested height likely to make image higher than limit', ->
        u = graph_url 'passthrough', { height: 5100, input: "files/grid-toastybob.jpg" }

        it 'should fail with a 422', (done) ->

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 422
                done()

    describe 'Missing authentication', ->
        u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe 'Providing auth when not needed', ->
        p = { height: 11, width: 130, input: "files/grid-toastybob.jpg", ignored: type }
        u = graph_url 'passthrough', p, 'ooShei0queigeeke', 'mysecret?'

        it 'request should succeed with redirect to file', (done) ->
            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal successCode
                location = res.headers['location']
                chai.expect(location).to.contain cacheurl
                done()

    describe 'Incorrect secret', ->
        p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'ooShei0queigeeke', 'mysecret?'

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe 'Invalid apikey', ->
        p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'apikey?', 'mysecret?'

        it 'should fail with a 403', (done) ->
            @timeout 5000
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe '_nocache with non-admin key', ->
        p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg", _nocache: "true" }
        u = graph_url 'crop', p, 'ooShei0queigeeke', 'reeva9aijo1Ooj9w'

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe '_nocache without key', ->
        p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg", _nocache: "true" }
        u = graph_url 'crop', p

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe 'Disabled application making processing request', ->
        p = { height: 110, width: 133, y: 230, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'not-enabled', 'disabled4reasons'

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe 'Disabled application making cache request', ->
        p = { height: 110, width: 133, y: 230, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'not-enabled', 'disabled4reasons'

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

    describe 'Application with processing_quota=0 making cache request', ->
        p = { height: 110, width: 133, y: 230, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'zero-processing-quota', 'zero0zero'

        it 'should succeed with redirect to file', (done) ->
            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 301
                location = res.headers['location']
                chai.expect(location).to.contain cacheurl
                done()

    describe 'Application with processing_quota=0 making processing request', ->
        p = { height: 110, width: 134, input: "files/grid-toastybob.jpg" }
        u = graph_url 'crop', p, 'zero-processing-quota', 'zero0zero'

        it 'should fail with a 403', (done) ->
            enableTestAuth state.server

            HTTP[method] u, (res) ->
                chai.expect(res.statusCode).to.equal 403
                done()

describe 'Server', ->
    s = null
    state =
        server: null

    before (done) ->
        @timeout 8*1000
        utils.rmrf config.workdir
        if startServer
            state.server = s = new server.Server config
            l = new utils.LogHandler s
            s.listen config.api_host, config.api_port, done
        else
            done()
    after (done) ->
        s.close done if startServer

    describe.skip 'Get version info', ->
        info = null
        it 'returns valid data', (done) ->
            u = url.format {protocol:'http:',host: urlbase, pathname:'/version'}
            request u, (err, response, body) ->
                chai.expect(err).to.not.exist
                chai.expect(response.statusCode).to.equal 200
                info = JSON.parse body
                done()
        it 'gives NPM version', ->
            chai.expect(info.err).to.be.a 'undefined'
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
        graphSuffix = '.json.info'
        for g in fs.readdirSync './graphs'
            expected.push g.replace graphSuffix, '' if common.endsWith(g, graphSuffix)
        responseData = ""
        it 'HTTP request gives 200', (done) ->
            u = url.format {protocol:'http:',host: urlbase, pathname:'/graphs'}
            http.get u, (response) ->
                chai.expect(response.statusCode).to.equal 200
                response.on 'data', (chunk) ->
                    responseData += chunk.toString()
                response.on 'end', () ->
                    done()
        it 'should return all processing graphs', () ->
            d = JSON.parse responseData
            actual = Object.keys d.graphs
            chai.expect(actual).to.deep.equal expected

        it 'should not include internal msgflo graph', () ->
            g = fs.readFileSync './graphs/imgflo-server.fbp'
            chai.expect(g).to.exist
            d = JSON.parse responseData
            chai.expect(d.graphs).to.not.have.key 'imgflo-server'

    describe 'GET /graph', ->
        beforeEach () ->
            # Reset auth to disabled
            state.server.authdb = null

        commonGraphTests 'GET', state

        describe 'with invalid graph parameters', ->
            u = graph_url 'gradientmap', {skeke: 299, oooor:222, input: "files/grid-toastybob.jpg"}
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
        describe 'with unsupported image type', ->
            u = graph_url 'gradientmap.svg', { input: "files/happy-kitten.svg" }
            data = ""
            it 'should give HTTP 449', (done) ->
                http.get u, (response) ->
                    chai.expect(response.statusCode).to.equal 449
                    response.on 'data', (chunk) ->
                        data += chunk.toString()
                    response.on 'end', () ->
                        done()
            it 'should list supported types', ->
                d = JSON.parse data
                supported = d.supported.sort()
                expected = ['jpg', 'jpeg', 'png', 'mp4', null].sort()
                chai.expect(supported).to.eql expected

        describe 'with invalid file protocol', ->
            i = "chrome-search://thumb2/http://index.hu/?fb=https://www.google.com/webpagethumbnail?c=63&d=http://index.hu/&r=4&s=148:94&a=vb60dfqUo9CRCH8ZZ7UDCR6vS_0"
            u = graph_url 'gradientmap', { input: i }
            data = ""
            it 'should give HTTP 504', (done) ->
                http.get u, (response) ->
                    chai.expect(response.statusCode).to.equal 504
                    response.on 'data', (chunk) ->
                        data += chunk.toString()
                    response.on 'end', () ->
                        done()

        describe 'Get new image', ->
            u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
            res = null
            location = null
            contentType = null

            it 'should be created on demand', (done) ->
                @timeout 15000
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
                chai.expect(res.headers).to.contain.keys 'location'
                location = res.headers['location']
                chai.expect(location).to.contain cacheurl
            it 'redirect should end with .jpg', () ->
                chai.expect(location).to.contain '.jpg'
            it 'key should be deterministic', () ->
                basename = path.basename (url.parse location).pathname, '.jpg'
                chai.expect(basename).to.equal 'b5774b2bd2c5c94535432dec55a205a712bc5326'
            it 'redirect should point to created image', (done) ->
                http.get location, (response) ->
                    chai.expect(response.statusCode).to.equal 200
                    contentType = response.headers['content-type']
                    response.on 'data', (chunk) ->
                        fs.appendFile 'testout.png', chunk, ->
                            #
                    response.on 'end', ->
                        fs.exists 'testout.png', (exists) ->
                            chai.assert exists, 'testout.png does not exist'
                            done()
            it "content-type should be 'image/jpeg'", () ->
                chai.expect(contentType).to.equal 'image/jpeg'

        describe 'Get existing image', ->
            u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
            response = null
            location = null

            it 'should be in cache', (done) ->
                checkProcessed = (id) ->
                    chai.expect(id).to.not.contain 'error'
                    if id == 'graph-in-cache'
                        s.removeListener 'logevent', checkProcessed
                        done()
                s.on 'logevent', checkProcessed
                http.get u, (res) ->
                    response = res

            it 'should be a redirect', () ->
                chai.expect(response.statusCode).to.equal 301
                location = response.headers['location']
                chai.expect(location).to.contain cacheurl

            it 'should end with .jpg', () ->
                chai.expect(location).to.contain '.jpg'

        describe 'Correct authentication', ->
            location = null

            p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
            u = graph_url 'crop', p, 'ooShei0queigeeke', 'reeva9aijo1Ooj9w'

            it 'request should succeed with redirect to file', (done) ->
                enableTestAuth state.server

                http.get u, (res) ->
                    chai.expect(res.statusCode).to.equal 301
                    location = res.headers['location']
                    chai.expect(location).to.contain cacheurl
                    done()
            it 'file should be same as for non-authed request', () ->
                chai.expect(location).to.be.a 'string'
                basename = path.basename (url.parse location).pathname, '.jpg'
                chai.expect(basename).to.equal 'b5774b2bd2c5c94535432dec55a205a712bc5326'

        describe '_nocache with correct auth', ->
            p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg", _nocache: "true" }
            u = graph_url 'crop', p, 'niem4Hoodaku', 'reiL1ohqu1do'

            # TODO: verify that . Maybe set a header indicating when image was processed? or that it was a cache hit
            it 'should succeed with a redirect', (done) ->
                enableTestAuth state.server

                http.get u, (res) ->
                    chai.expect(res.statusCode).to.equal 301
                    location = res.headers['location']
                    chai.expect(location).to.contain cacheurl
                    done()

        describe 'appending &debug to', ->
            p = { height: 111, x: 130, input: "files/grid-toastybob.jpg" }
            u = graph_url 'crop', p, 'ooShei0queigeeke', 'reeva9aijo1Ooj9w'

            # TODO: verify that . Maybe set a header indicating when image was processed? or that it was a cache hit
            it 'should redirect to debug UI', (done) ->
                enableTestAuth state.server

                u += '&debug=1'
                http.get u, (res) ->
                    chai.expect(res.statusCode).to.equal 302
                    location = res.headers['location']
                    chai.expect(location).to.contain '/debug'
                    chai.expect(location).to.contain '/crop/'
                    chai.expect(location).to.contain 'height=111'
                    chai.expect(location).to.contain 'x=130'
                    chai.expect(location).to.contain 'input=files'
                    done()

        describe 'Input URL does not resolve', ->
            info = null
            p = { height: 110, width: 130, x: 200, y: 230, input: "files/__nonexisting_image___.jpg" }
            u = graph_url 'crop', p

            it 'should fail with a 504', (done) ->
                @timeout 5000

                http.get u, (res) ->
                    getBody res, (err, body) ->
                        try
                            info = JSON.parse body
                        catch e
                            chai.expect(e).to.not.exist
                        chai.expect(res.statusCode).to.equal 504
                        chai.expect(info.code).to.equal 504
                        done()

            it 'payload should have error and files', ->
                chai.expect(info).to.exist
                chai.expect(info).to.include.keys ['error', 'files', 'code']
                chai.expect(info.error).to.contain '__nonexisting_image___'
                chai.expect(info.error).to.contain '404'

    describe 'POST /graph', () ->
        beforeEach () ->
            # Reset auth to disabled
            state.server.authdb = null

        commonGraphTests 'POST', state

        describe 'Create new image', ->
            u = graph_url 'crop', { height: 44, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
            location = null

            it 'should return 202 accepted', (done) ->
                HTTP.post u, (response) ->
                    location = response.headers?['location']
                    chai.expect(response.statusCode).to.equal 202
                    chai.expect(response.headers).to.contain.keys 'location'
                    done()
            it 'should have location header', () ->
                chai.expect(location).to.contain cacheurl
            it 'location header should end with .jpg', () ->
                chai.expect(location).to.contain '.jpg'


            it.skip 'location URL should eventually return created image', (done) ->

        describe 'Get existing image', ->
            u = graph_url 'crop', { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
            location = null

            it 'should be a 301 redirect', (done) ->
                HTTP.post u, (response) ->
                    location = response.headers?['location']
                    chai.expect(response.statusCode).to.equal 301
                    chai.expect(location).to.contain cacheurl
                    done()
            it 'should end with .jpg', () ->
                chai.expect(location).to.contain '.jpg'

        describe 'with authentication', ->
            location = null

            describe 'get existing image', ->
                p = { height: 110, width: 130, x: 200, y: 230, input: "files/grid-toastybob.jpg" }
                u = graph_url 'crop', p, 'ooShei0queigeeke', 'reeva9aijo1Ooj9w'

                it 'request should succeed with redirect to file', (done) ->
                    enableTestAuth state.server

                    HTTP.post u, (res) ->
                        chai.expect(res.statusCode).to.equal 301
                        location = res.headers['location']
                        chai.expect(location).to.contain cacheurl
                        done()
                it 'file should be same as for non-authed / GET request', () ->
                    chai.expect(location).to.be.a 'string'
                    basename = path.basename (url.parse location).pathname, '.jpg'
                    chai.expect(basename).to.equal 'b5774b2bd2c5c94535432dec55a205a712bc5326'


describe 'Applications in database', ->
    state =
        server: null
    addedApp =
        key: "123123123123123"
        secret: "321321321321321"
        label: "Added via database"
        owner_email: "test@example.com"
        processing_quota: 0
        enabled: false

    before (done) ->
        applications.deleteAll(config)
        .then () -> return done()
        .catch(done)

    after (done) ->
        applications.deleteAll(config).catch(done)
        .then () ->
            if state.server
                state.server.close done
            else
                done()

    it 'adding an application should succeed', (done) ->
        applications.add config, addedApp
        .then () -> return done()
        .catch done

    it 'should be loaded into server on start', (done) ->
        @timeout 8*1000
        state.server = new server.Server config
        state.server.listen config.api_host, config.api_port, (err) ->
            return done err if err
            try
                auth = state.server.authdb
                chai.expect(auth, Object.keys(auth)).to.have.property addedApp.key
                chai.expect(auth[addedApp.key].secret).to.equal addedApp.secret
                chai.expect(auth[addedApp.key].processing_quota).to.equal addedApp.processing_quota
                chai.expect(auth[addedApp.key].enabled).to.equal addedApp.enabled
            catch e
                return done e
            return done()
