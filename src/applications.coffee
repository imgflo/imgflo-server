
common = require './common'

Knex = require 'knex'
url = require 'url'

getDatabaseConnection = (config) ->

    # Parse DB URL
    dbConfig = url.parse config.database_url
    connection =
      charset: 'utf8'

    # Normalize config
    switch dbConfig.protocol
      when 'postgres:'
        provider = 'pg'
        [user, pass] = dbConfig.auth.split ':'
        connection.host = dbConfig.hostname
        connection.user = user
        connection.password = pass
        connection.database = dbConfig.path.substr 1
        connection.port = dbConfig.port
        connection.ssl = true if not process.env.POSTGRES_NOSSL
      when 'sqlite:'
        provider = 'sqlite3'
        connection.filename = dbConfig.path

    options =
        client: provider
        connection: connection
        pool:
          min: 2
          max: 5
        # debug: true
    return Knex options

exports.deleteAll = (config, options = {}) ->
    db = getDatabaseConnection config
    db('applications').del()

exports.add = add = (config, data) ->
    db = getDatabaseConnection config

    data.enabled = true if not data.enabled?
    data.processing_quota = 1 if not data.processing_quota?
    data.created_at = new Date()
    data.updated_at = new Date()

    Promise.resolve (data)
    .then () ->
        throw new Error "Application key too short" if not data.key?.length > 12
        throw new Error "Application secret too short" if not data.secret?.length > 12
        throw new Error "Application owner_email missing" if not (data.owner_email?.indexOf('@') > 0)
        throw new Error "Application description missing" if not data.label?.length
        return null
    .then () ->
        return db('applications').insert(data)

exports.list = (config, options) ->
    db = getDatabaseConnection config

    db('applications').select('*')
    .then (apps) ->
        for a in apps
            a.secret = undefined if not options.showSecrets
        return apps

randomValueHex = (len) ->
    crypto = require 'crypto'
    return crypto.randomBytes(Math.ceil(len/2))
        .toString('hex')
        .slice(0,len);

exports.main = () ->
    [_node, _script, email, description] = process.argv

    length = 15
    app =
        key: randomValueHex length
        secret: randomValueHex length
        owner_email: email
        label: description
    overrides = {}

    config = common.getProductionConfig overrides
    add config, app
    .then () ->
        console.log "Added application\n#{JSON.stringify(app, null, 2)}"
        process.exit 0
    .catch (err) ->
        console.error "Could not add application: #{err}"
        process.exit 2
