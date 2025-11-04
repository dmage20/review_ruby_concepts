# frozen_string_literal: true

module Types
  class ProviderPracticeInfoType < Types::BaseObject
    description "Practice information for a provider"

    field :id, ID, null: false
    field :practice_name, String, null: true
    field :accepts_new_patients, Boolean, null: true
    field :patient_age_range, String, null: true
    field :languages_spoken, String, null: true
    field :office_hours, String, null: true
    field :accessibility_features, String, null: true
    field :telehealth_available, Boolean, null: true
    field :appointment_wait_time, String, null: true
    field :last_verified, GraphQL::Types::ISO8601Date, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :provider, Types::ProviderType, null: true
  end
end
