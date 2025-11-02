class CreateProviderLanguages < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_languages do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :language_code
      t.string :language_name
      t.string :proficiency_level

      t.timestamps
    end
  end
end
