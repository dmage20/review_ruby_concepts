class CreateProviderNetworkMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_network_memberships do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :provider_network, null: false, foreign_key: true
      t.date :member_since
      t.date :termination_date
      t.string :status
      t.string :tier_level
      t.boolean :accepts_new_patients

      t.timestamps
    end
    add_index :provider_network_memberships, :status
  end
end
