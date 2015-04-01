#     imgflo - Flowhub.io Image-processing runtime
#     (c) 2014 The Grid
#     imgflo may be freely distributed under the MIT license

server = require '../src/server'
common = require '../src/common'
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

cachetype = if process.env.IMGFLO_TESTS_CACHE then process.env.IMGFLO_TESTS_CACHE else 'local'

requestUrl = (testcase) ->
    u = null
    if testcase._url
        u = 'http://'+ urlbase + testcase._url
    else
        graph = testcase._graph
        props = {}
        for key of testcase
            props[key] = testcase[key] if (key.indexOf '_') != 0
        u = utils.formatRequest urlbase, graph, props
    return u

# End-to-end tests of image processing pipeline and included graphs
describe 'Graphs', ->
    s = null
    testcases = yaml.safeLoad fs.readFileSync 'spec/graphtests.yml', 'utf-8'
    l = null

    before (done) ->
        wd = './testtemp'
        utils.rmrf wd
        if startServer
            cache =
                type: cachetype
                baseurl: urlbase
            s = new server.Server wd, null, null, verbose, cache
            l = new utils.LogHandler s
            s.listen urlbase, port, done
        else
            done()
    after (done) ->
        s.close done if startServer

    testcases.forEach (testcase) ->
        describeOrSkip = if testcase._skip? and testcase._skip then describe.skip else describe

        describeOrSkip "#{testcase._name}", ->
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
                    response = null
                    req = request reqUrl, (err, res) ->
                        chai.expect(err).to.be.a 'null'
                    req.pipe fs.createWriteStream output
                    req.on 'response', (res) ->
                        response = res
                    req.on 'end', () ->
                        chai.expect(response.statusCode).to.equal 200
                        done()

                it 'results should be equal to reference', (done) ->
                    timeout = 8000
                    @timeout timeout
                    options = { timeout: timeout*2 }

                    options.tolerance = testcase._tolerance if testcase._tolerance
                    utils.compareImages output, reference, options, (error, stderr, stdout) ->
                        msg = "image comparison failed code=#{error?.code}\n#{stderr}\n#{stdout}"
                        chai.expect(error).to.be.a 'null', msg
                        done()

                itSkipRemote 'should not cause errors', ->
                    chai.expect(l.popErrors()).to.deep.equal []

