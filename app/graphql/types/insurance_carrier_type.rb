# frozen_string_literal: true

module Types
  class InsuranceCarrierType < Types::BaseObject
    description "An insurance company/carrier"

    field :id, ID, null: false
    field :name, String, null: true
    field :code, String, null: true
    field :carrier_type, String, null: true
    field :contact_email, String, null: true
    field :contact_phone, String, null: true
    field :website, String, null: true
    field :address_line1, String, null: true
    field :address_line2, String, null: true
    field :city, String, null: true
    field :state, String, null: true
    field :postal_code, String, null: true
    field :country, String, null: true
    field :rating, String, null: true
    field :status, String, null: true
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
