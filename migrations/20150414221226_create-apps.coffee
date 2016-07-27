
# Create
exports.up = (knex, Promise) ->
  # App registry
  knex.schema.hasTable('applications').then (exists) ->
    return if exists
    knex.schema.createTable 'applications', (t) ->
      # API key
      t.string('key').primary()
      # API secret
      t.string('secret').notNullable()

      # Description of this app
      t.string('label').notNullable()
      # Contact info to owner
      t.string('owner_email').notNullable()

      # Megapixels / month?
      t.integer('processing_quota').notNullable()
      # Enabled
      t.boolean('enabled').notNullable()

      # Created, updated
      t.timestamps()

# Drop initial tables
exports.down = (knex, Promise) ->
  knex.schema.dropTableIfExists 'application'

