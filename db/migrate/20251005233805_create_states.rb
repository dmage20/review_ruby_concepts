class CreateStates < ActiveRecord::Migration[7.2]
  def change
    create_table :states do |t|
      t.string :code, null: false, limit: 2
      t.string :name, null: false, limit: 100

      t.timestamps
    end

    add_index :states, :code, unique: true

    # Seed all U.S. states and territories
    reversible do |dir|
      dir.up do
        states_data = [
          [ 'AL', 'Alabama' ], [ 'AK', 'Alaska' ], [ 'AZ', 'Arizona' ], [ 'AR', 'Arkansas' ],
          [ 'CA', 'California' ], [ 'CO', 'Colorado' ], [ 'CT', 'Connecticut' ], [ 'DE', 'Delaware' ],
          [ 'FL', 'Florida' ], [ 'GA', 'Georgia' ], [ 'HI', 'Hawaii' ], [ 'ID', 'Idaho' ],
          [ 'IL', 'Illinois' ], [ 'IN', 'Indiana' ], [ 'IA', 'Iowa' ], [ 'KS', 'Kansas' ],
          [ 'KY', 'Kentucky' ], [ 'LA', 'Louisiana' ], [ 'ME', 'Maine' ], [ 'MD', 'Maryland' ],
          [ 'MA', 'Massachusetts' ], [ 'MI', 'Michigan' ], [ 'MN', 'Minnesota' ], [ 'MS', 'Mississippi' ],
          [ 'MO', 'Missouri' ], [ 'MT', 'Montana' ], [ 'NE', 'Nebraska' ], [ 'NV', 'Nevada' ],
          [ 'NH', 'New Hampshire' ], [ 'NJ', 'New Jersey' ], [ 'NM', 'New Mexico' ], [ 'NY', 'New York' ],
          [ 'NC', 'North Carolina' ], [ 'ND', 'North Dakota' ], [ 'OH', 'Ohio' ], [ 'OK', 'Oklahoma' ],
          [ 'OR', 'Oregon' ], [ 'PA', 'Pennsylvania' ], [ 'RI', 'Rhode Island' ], [ 'SC', 'South Carolina' ],
          [ 'SD', 'South Dakota' ], [ 'TN', 'Tennessee' ], [ 'TX', 'Texas' ], [ 'UT', 'Utah' ],
          [ 'VT', 'Vermont' ], [ 'VA', 'Virginia' ], [ 'WA', 'Washington' ], [ 'WV', 'West Virginia' ],
          [ 'WI', 'Wisconsin' ], [ 'WY', 'Wyoming' ],
          [ 'DC', 'District of Columbia' ],
          [ 'AS', 'American Samoa' ], [ 'GU', 'Guam' ], [ 'MP', 'Northern Mariana Islands' ],
          [ 'PR', 'Puerto Rico' ], [ 'VI', 'U.S. Virgin Islands' ]
        ]

        states_data.each do |code, name|
          execute <<-SQL
            INSERT INTO states (code, name, created_at, updated_at)
            VALUES ('#{code}', '#{name.gsub("'", "''")}', NOW(), NOW())
          SQL
        end
      end
    end
  end
end
