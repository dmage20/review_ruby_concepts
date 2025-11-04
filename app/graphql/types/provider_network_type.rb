# frozen_string_literal: true

module Types
  class ProviderNetworkType < Types::BaseObject
    description "A provider network"

    field :id, ID, null: false
    field :network_name, String, null: true
    field :network_type, String, null: true
    field :carrier_name, String, null: true
    field :coverage_area, String, null: true
    field :status, String, null: true
    field :description, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :providers, [ Types::ProviderType ], null: true
  end
end
