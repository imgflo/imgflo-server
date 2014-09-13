#     imgflo - Flowhub.io Image-processing runtime
#     (c) 2014 The Grid
#     imgflo may be freely distributed under the MIT license

server = require '../src/server'
utils = require './utils'
chai = require 'chai'
yaml = require 'js-yaml'
request = require 'request'

http = require 'http'
fs = require 'fs'
path = require 'path'
url = require 'url'
child = require 'child_process'

urlbase = process.env.IMGFLO_TESTS_TARGET
urlbase = 'localhost:8888' if not urlbase
port = (urlbase.split ':')[1]
verbose = process.env.IMGFLO_TESTS_VERBOSE?
startServer = (urlbase.indexOf 'localhost') == 0
itSkipRemote = if not startServer then it.skip else it

compareImages = (actual, expected, callback) ->
    cmd = "./install/env.sh ./install/bin/gegl-imgcmp #{actual} #{expected}"
    options =
        timeout: 2000
    child.exec cmd, options, (error, stdout, stderr) ->
        return callback error, stderr, stdout

requestUrl = (testcase) ->
    u = null
    if testcase._url
        u = 'http://'+ urlbase + testcase._url
    else
        graph = testcase._graph
        props = {}
        for key of testcase
            props[key] = testcase[key] if key != '_name' and key != '_graph'
        u = url.format { protocol: 'http:', host: urlbase, pathname: '/graph/'+graph, query: props}
    return u

requestFileFormat = (u) ->
    parsed = url.parse u
    graph = parsed.pathname.replace '/graph/', ''
    ext = (path.extname graph).replace '.', ''
    return ext || 'png'

# End-to-end tests of image processing pipeline and included graphs
describe 'Graphs', ->
    s = null
    testcases = yaml.safeLoad fs.readFileSync 'spec/graphtests.yml', 'utf-8'
    l = null

    before ->
        wd = './graphteststemp'
        if fs.existsSync wd
            for f in fs.readdirSync wd
                fs.unlinkSync path.join wd, f
        if startServer
            s = new server.Server wd, null, null, verbose
            l = new utils.LogHandler s
            s.listen port
    after ->
        s.close() if startServer

    for testcase in testcases

        describe "#{testcase._name}", ->
            reqUrl = requestUrl testcase
            ext = requestFileFormat reqUrl
            datadir = 'spec/data/'
            reference = path.join datadir, "#{testcase._name}.reference.#{ext}"
            output = path.join datadir, "#{testcase._name}.out.#{ext}"
            fs.unlinkSync output if fs.existsSync output

            it 'should have a reference result', (done) ->
                fs.exists reference, (exists) ->
                    chai.assert exists, 'Not found: '+reference
                    done()

            describe "GET #{reqUrl}", ->
                it 'should output a file', (done) ->
                    @timeout 8000
                    req = request reqUrl, (err, response) ->
                        done()
                    req.pipe fs.createWriteStream output

                it 'results should be equal to reference', (done) ->
                    @timeout 4000
                    compareImages output, reference, (error, stderr, stdout) ->
                        msg = "image comparison failed\n#{stderr}\n#{stdout}"
                        chai.assert not error?, msg
                        done()

                itSkipRemote 'should not cause errors', ->
                    chai.expect(l.popErrors()).to.deep.equal []

