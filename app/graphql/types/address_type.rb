# frozen_string_literal: true

module Types
  class AddressType < Types::BaseObject
    description "Provider address (location or mailing)"

    field :id, ID, null: false
    field :address_purpose, String, null: false
    field :address_type, String, null: true
    field :address_1, String, null: true
    field :address_2, String, null: true
    field :city_name, String, null: true
    field :postal_code, String, null: true
    field :country_code, String, null: true
    field :telephone, String, null: true
    field :fax, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
