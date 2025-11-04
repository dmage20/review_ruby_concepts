# frozen_string_literal: true

module Types
  class HospitalAffiliationType < Types::BaseObject
    description "Hospital affiliation for a provider"

    field :id, ID, null: false
    field :hospital_name, String, null: true
    field :hospital_npi, String, null: true
    field :affiliation_type, String, null: true
    field :department, String, null: true
    field :privileges, String, null: true
    field :start_date, GraphQL::Types::ISO8601Date, null: true
    field :end_date, GraphQL::Types::ISO8601Date, null: true
    field :status, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
