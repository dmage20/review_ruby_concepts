class CreateProviderQualityMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_quality_metrics do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :metric_type
      t.string :metric_name
      t.decimal :score
      t.string :rating
      t.date :measurement_date
      t.string :source
      t.text :notes

      t.timestamps
    end
  end
end
