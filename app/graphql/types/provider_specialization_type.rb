# frozen_string_literal: true

module Types
  class ProviderSpecializationType < Types::BaseObject
    description "Specialization/focus area for a provider"

    field :id, ID, null: false
    field :specialization_name, String, null: true
    field :focus_area, String, null: true
    field :years_experience, Integer, null: true
    field :board_certified, Boolean, null: true
    field :certification_body, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
