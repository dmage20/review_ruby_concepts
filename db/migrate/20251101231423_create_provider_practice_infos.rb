class CreateProviderPracticeInfos < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_practice_infos do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :practice_name
      t.boolean :accepts_new_patients
      t.string :patient_age_range
      t.text :languages_spoken
      t.text :office_hours
      t.text :accessibility_features
      t.boolean :telehealth_available
      t.string :appointment_wait_time
      t.date :last_verified

      t.timestamps
    end
  end
end
