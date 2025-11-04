class CreateAddresses < ActiveRecord::Migration[7.2]
  def change
    create_table :addresses do |t|
      t.references :provider, null: false, foreign_key: true

      # Address Type
      t.string :address_purpose, null: false, limit: 10
      t.string :address_type, limit: 3, default: 'DOM'

      # Address Fields
      t.string :address_1, limit: 300
      t.string :address_2, limit: 300
      t.references :city, foreign_key: true
      t.string :city_name, limit: 200
      t.references :state, foreign_key: true
      t.string :postal_code, limit: 20
      t.string :country_code, limit: 2, default: 'US'

      # Contact
      t.string :telephone, limit: 20
      t.string :fax, limit: 20

      t.timestamps
    end

    add_index :addresses, [ :provider_id, :address_purpose ]
    # Note: indexes on city_id and state_id are automatically created by t.references
    add_index :addresses, :address_purpose
    add_index :addresses, :postal_code

    # Composite index for location searches
    add_index :addresses, [ :state_id, :city_id, :address_purpose ],
      where: "address_purpose = 'LOCATION'",
      name: 'index_addresses_location_search'

    # Add check constraints
    execute <<-SQL
      ALTER TABLE addresses
      ADD CONSTRAINT check_address_purpose CHECK (address_purpose IN ('LOCATION', 'MAILING'))
    SQL

    execute <<-SQL
      ALTER TABLE addresses
      ADD CONSTRAINT check_address_type CHECK (address_type IN ('DOM', 'FGN'))
    SQL
  end
end
