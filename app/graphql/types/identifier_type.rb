# frozen_string_literal: true

module Types
  class IdentifierType < Types::BaseObject
    description "Provider identifier (Medicare, Medicaid, DEA, etc.)"

    field :id, ID, null: false
    field :identifier_type, String, null: false
    field :identifier_value, String, null: false
    field :issuer, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
