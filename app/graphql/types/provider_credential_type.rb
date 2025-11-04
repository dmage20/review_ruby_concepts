# frozen_string_literal: true

module Types
  class ProviderCredentialType < Types::BaseObject
    description "Professional credential for a provider"

    field :id, ID, null: false
    field :credential_type, String, null: true
    field :credential_number, String, null: true
    field :issuing_organization, String, null: true
    field :issue_date, GraphQL::Types::ISO8601Date, null: true
    field :expiration_date, GraphQL::Types::ISO8601Date, null: true
    field :status, String, null: true
    field :verification_date, GraphQL::Types::ISO8601Date, null: true
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
