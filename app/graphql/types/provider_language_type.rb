# frozen_string_literal: true

module Types
  class ProviderLanguageType < Types::BaseObject
    description "Language spoken by provider"

    field :id, ID, null: false
    field :language_code, String, null: true
    field :language_name, String, null: true
    field :proficiency_level, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
