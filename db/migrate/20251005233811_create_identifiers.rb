class CreateIdentifiers < ActiveRecord::Migration[7.2]
  def change
    create_table :identifiers do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :identifier_type, null: false, limit: 50
      t.string :identifier_value, null: false, limit: 100
      t.references :state, foreign_key: true
      t.string :issuer, limit: 200

      t.timestamps
    end

    add_index :identifiers, [ :provider_id, :identifier_type, :identifier_value ],
      unique: true,
      name: 'index_identifiers_unique'
    # Note: index on provider_id and state_id are automatically created by t.references
    add_index :identifiers, :identifier_type
    add_index :identifiers, :identifier_value
    add_index :identifiers, [ :identifier_type, :identifier_value ],
      name: 'index_identifiers_type_value'
  end
end
