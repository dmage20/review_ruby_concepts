# frozen_string_literal: true

module Types
  class InsurancePlanType < Types::BaseObject
    description "An insurance plan/product"

    field :id, ID, null: false
    field :plan_name, String, null: true
    field :carrier_name, String, null: true
    field :plan_type, String, null: true
    field :network_type, String, null: true
    field :coverage_area, String, null: true
    field :status, String, null: true
    field :effective_date, GraphQL::Types::ISO8601Date, null: true
    field :termination_date, GraphQL::Types::ISO8601Date, null: true
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :providers, [ Types::ProviderType ], null: true
  end
end
