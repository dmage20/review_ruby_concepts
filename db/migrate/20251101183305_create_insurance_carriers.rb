class CreateInsuranceCarriers < ActiveRecord::Migration[7.2]
  def change
    create_table :insurance_carriers do |t|
      t.string :name
      t.string :code
      t.string :carrier_type
      t.string :contact_email
      t.string :contact_phone
      t.string :website
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country
      t.string :rating
      t.string :status
      t.text :notes

      t.timestamps
    end
    add_index :insurance_carriers, :code
    add_index :insurance_carriers, :status
  end
end
