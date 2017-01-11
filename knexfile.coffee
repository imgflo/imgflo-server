common = require './src/common'
url = require 'url'

config = common.getProductionConfig()

dbConfig = url.parse config.database_url
[user, pass] = dbConfig.auth.split ':'
switch dbConfig.protocol
  when 'postgres:'
    cfg =
      client: 'postgresql'
      connection:
        host: dbConfig.hostname
        port: dbConfig.port
        database: dbConfig.path.substr 1
        user:     user
        password: pass
      pool:
        min: 2
        max: 10
      migrations:
        tableName: 'knex_migrations'
  when 'sqlite:'
    cfg =
      client: 'sqlite3'
      connection:
        filename: dbConfig.path
      migrations:
        tableName: 'knex_migrations'

module.exports =
  development: cfg
  staging: cfg
  production: cfg

