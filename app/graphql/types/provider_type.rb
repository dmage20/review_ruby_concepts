# frozen_string_literal: true

module Types
  class ProviderType < Types::BaseObject
    description "A healthcare provider (doctor, nurse practitioner, organization, etc.)"

    field :id, ID, null: false
    field :npi, String, null: false
    field :entity_type, Integer, null: false
    field :replacement_npi, String, null: true

    # Individual fields
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :middle_name, String, null: true
    field :name_prefix, String, null: true
    field :name_suffix, String, null: true
    field :credential, String, null: true
    field :gender, String, null: true

    # Organization fields
    field :organization_name, String, null: true
    field :organization_subpart, Boolean, null: true

    # Business info
    field :ein, String, null: true
    field :sole_proprietor, Boolean, null: true

    # Dates
    field :enumeration_date, GraphQL::Types::ISO8601Date, null: true
    field :last_update_date, GraphQL::Types::ISO8601Date, null: true
    field :deactivation_date, GraphQL::Types::ISO8601Date, null: true
    field :deactivation_reason, String, null: true
    field :reactivation_date, GraphQL::Types::ISO8601Date, null: true

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :addresses, [ Types::AddressType ], null: true
    field :taxonomies, [ Types::TaxonomyType ], null: true
    field :identifiers, [ Types::IdentifierType ], null: true
    field :insurance_plans, [ Types::InsurancePlanType ], null: true
    field :provider_networks, [ Types::ProviderNetworkType ], null: true
    field :quality_metrics, [ Types::ProviderQualityMetricType ], null: true
    field :hospital_affiliations, [ Types::HospitalAffiliationType ], null: true
    field :credentials, [ Types::ProviderCredentialType ], null: true
    field :practice_info, Types::ProviderPracticeInfoType, null: true
    field :languages, [ Types::ProviderLanguageType ], null: true
    field :specializations, [ Types::ProviderSpecializationType ], null: true

    # Computed fields
    field :full_name, String, null: true
    field :is_active, Boolean, null: false

    def full_name
      if object.entity_type == 1
        [ object.name_prefix, object.first_name, object.middle_name, object.last_name, object.name_suffix, object.credential ].compact.join(" ")
      else
        object.organization_name
      end
    end

    def is_active
      object.deactivation_date.nil?
    end
  end
end
