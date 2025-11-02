class CreateProviderInsurancePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_insurance_plans do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :insurance_plan, null: false, foreign_key: true
      t.boolean :accepts_new_patients
      t.date :effective_date
      t.date :termination_date
      t.string :status
      t.string :network_tier
      t.text :notes

      t.timestamps
    end
  end
end
