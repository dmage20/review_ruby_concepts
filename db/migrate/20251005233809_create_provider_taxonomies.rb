class CreateProviderTaxonomies < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_taxonomies do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :taxonomy, null: false, foreign_key: true
      t.string :license_number, limit: 100
      t.references :license_state, foreign_key: { to_table: :states }
      t.boolean :is_primary, default: false

      t.timestamps
    end

    add_index :provider_taxonomies, [ :provider_id, :taxonomy_id ], unique: true
    # Note: index on taxonomy_id is automatically created by t.references
    add_index :provider_taxonomies, [ :provider_id, :is_primary ], where: "is_primary = true"
    # Note: index on license_state_id is automatically created by t.references

    # Add unique constraint: only one primary taxonomy per provider
    execute <<-SQL
      CREATE UNIQUE INDEX index_provider_taxonomies_one_primary
      ON provider_taxonomies (provider_id)
      WHERE is_primary = true
    SQL
  end
end
