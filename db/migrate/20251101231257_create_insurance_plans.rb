class CreateInsurancePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :insurance_plans do |t|
      t.string :plan_name
      t.string :carrier_name
      t.string :plan_type
      t.string :network_type
      t.string :coverage_area
      t.string :status
      t.date :effective_date
      t.date :termination_date
      t.text :notes

      t.timestamps
    end
    add_index :insurance_plans, :status
  end
end
