# frozen_string_literal: true

module Types
  class ProviderQualityMetricType < Types::BaseObject
    description "Quality metrics for a provider"

    field :id, ID, null: false
    field :metric_type, String, null: true
    field :metric_name, String, null: true
    field :score, Float, null: true
    field :rating, String, null: true
    field :measurement_date, GraphQL::Types::ISO8601Date, null: true
    field :source, String, null: true
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
