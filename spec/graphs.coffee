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

cache = if process.env.IMGFLO_TESTS_CACHE then process.env.IMGFLO_TESTS_CACHE else 'local'

requestUrl = (testcase) ->
    u = null
    if testcase._url
        u = 'http://'+ urlbase + testcase._url
    else
        graph = testcase._graph
        props = {}
        for key of testcase
            props[key] = testcase[key] if key != '_name' and key != '_graph'
        u = utils.formatRequest urlbase, graph, props
    return u

# End-to-end tests of image processing pipeline and included graphs
describe 'Graphs', ->
    s = null
    testcases = yaml.safeLoad fs.readFileSync 'spec/graphtests.yml', 'utf-8'
    l = null

    before (done) ->
        wd = './graphteststemp'
        utils.rmrf wd
        if startServer
            s = new server.Server wd, null, null, verbose, { type: cache }
            l = new utils.LogHandler s
            s.listen urlbase, port, done
        else
            done()
    after ->
        s.close() if startServer

    for testcase in testcases

        describe "#{testcase._name}", ->
            reqUrl = requestUrl testcase
            ext = utils.requestFileFormat reqUrl
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
                        chai.expect(err).to.be.a 'null'
                    req.pipe fs.createWriteStream output
                    req.on 'end', () ->
                        done()

                it 'results should be equal to reference', (done) ->
                    timeout = 4000
                    @timeout timeout
                    utils.compareImages output, reference, timeout*2, (error, stderr, stdout) ->
                        msg = "image comparison failed code=#{error?.code}\n#{stderr}\n#{stdout}"
                        chai.expect(error).to.be.a 'null', msg
                        done()

                itSkipRemote 'should not cause errors', ->
                    chai.expect(l.popErrors()).to.deep.equal []

