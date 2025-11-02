class CreateHospitalAffiliations < ActiveRecord::Migration[7.2]
  def change
    create_table :hospital_affiliations do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :hospital_name
      t.string :hospital_npi
      t.string :affiliation_type
      t.string :department
      t.text :privileges
      t.date :start_date
      t.date :end_date
      t.string :status

      t.timestamps
    end
    add_index :hospital_affiliations, :status
  end
end
