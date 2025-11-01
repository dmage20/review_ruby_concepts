class CreateProviderNetworks < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_networks do |t|
      t.string :network_name
      t.string :network_type
      t.string :carrier_name
      t.string :coverage_area
      t.string :status
      t.text :description

      t.timestamps
    end
    add_index :provider_networks, :status
  end
end
