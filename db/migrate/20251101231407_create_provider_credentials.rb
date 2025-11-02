class CreateProviderCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_credentials do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :credential_type
      t.string :credential_number
      t.string :issuing_organization
      t.date :issue_date
      t.date :expiration_date
      t.string :status
      t.date :verification_date
      t.text :notes

      t.timestamps
    end
    add_index :provider_credentials, :status
  end
end
