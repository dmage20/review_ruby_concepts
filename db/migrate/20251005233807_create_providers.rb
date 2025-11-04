class CreateProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :providers do |t|
      # NPI Information
      t.string :npi, null: false, limit: 10
      t.integer :entity_type, null: false, limit: 2
      t.string :replacement_npi, limit: 10

      # Individual Provider Fields (entity_type = 1)
      t.string :first_name, limit: 150
      t.string :last_name, limit: 150
      t.string :middle_name, limit: 150
      t.string :name_prefix, limit: 10
      t.string :name_suffix, limit: 10
      t.string :credential, limit: 100
      t.string :gender, limit: 1

      # Organization Provider Fields (entity_type = 2)
      t.string :organization_name, limit: 300
      t.boolean :organization_subpart, default: false

      # Business Information
      t.string :ein, limit: 9
      t.boolean :sole_proprietor, default: false

      # Status & Dates
      t.date :enumeration_date
      t.date :last_update_date
      t.date :deactivation_date
      t.string :deactivation_reason, limit: 100
      t.date :reactivation_date

      t.timestamps
    end

    # Add unique index on NPI
    add_index :providers, :npi, unique: true

    # Add indexes for common queries
    add_index :providers, :entity_type
    add_index :providers, :last_name, where: "entity_type = 1"
    add_index :providers, :organization_name, where: "entity_type = 2"
    add_index :providers, :credential
    add_index :providers, :deactivation_date

    # Add check constraints
    execute <<-SQL
      ALTER TABLE providers
      ADD CONSTRAINT check_entity_type CHECK (entity_type IN (1, 2))
    SQL

    execute <<-SQL
      ALTER TABLE providers
      ADD CONSTRAINT check_gender CHECK (gender IN ('M', 'F', 'X') OR gender IS NULL)
    SQL

    # Add generated tsvector column for full-text search
    # This will automatically update when name fields change
    execute <<-SQL
      ALTER TABLE providers
      ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', COALESCE(first_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(last_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(organization_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(credential, '')), 'B')
      ) STORED
    SQL

    # Add GIN index for full-text search
    add_index :providers, :search_vector, using: :gin

    # Add partial index for active providers
    add_index :providers, [ :last_name, :first_name ],
      where: "deactivation_date IS NULL AND entity_type = 1",
      name: 'index_providers_active_individuals'

    # Add composite index for common search patterns
    add_index :providers, [ :last_name, :first_name, :credential ],
      where: "entity_type = 1 AND deactivation_date IS NULL",
      name: 'index_providers_name_credential'
  end
end
