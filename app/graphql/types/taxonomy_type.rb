# frozen_string_literal: true

module Types
  class TaxonomyType < Types::BaseObject
    description "Healthcare provider taxonomy/specialty"

    field :id, ID, null: false
    field :code, String, null: false
    field :classification, String, null: true
    field :specialization, String, null: true
    field :description, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
