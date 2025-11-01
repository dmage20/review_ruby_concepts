class CreateProviderSpecializations < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_specializations do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :specialization_name
      t.string :focus_area
      t.integer :years_experience
      t.boolean :board_certified
      t.string :certification_body

      t.timestamps
    end
  end
end
