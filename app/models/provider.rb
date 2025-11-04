class Provider < ApplicationRecord
  # Enums
  enum :entity_type, { individual: 1, organization: 2 }, prefix: :entity
  enum :gender, { male: "M", female: "F", other: "X" }, prefix: true, default: nil

  # Associations
  has_many :addresses, dependent: :destroy
  has_many :provider_taxonomies, dependent: :destroy
  has_many :taxonomies, through: :provider_taxonomies
  has_many :identifiers, dependent: :destroy
  has_many :other_names, dependent: :destroy
  has_many :endpoints, dependent: :destroy
  has_one :authorized_official, dependent: :destroy

  # Insurance & Network associations
  has_many :provider_insurance_plans, dependent: :destroy
  has_many :insurance_plans, through: :provider_insurance_plans
  has_many :provider_network_memberships, dependent: :destroy
  has_many :provider_networks, through: :provider_network_memberships
  has_many :provider_quality_metrics, dependent: :destroy
  has_many :hospital_affiliations, dependent: :destroy
  has_many :provider_credentials, dependent: :destroy
  has_many :provider_languages, dependent: :destroy
  has_many :provider_specializations, dependent: :destroy
  has_one :provider_practice_info, dependent: :destroy

  # Delegations
  has_many :cities, through: :addresses
  has_many :states, through: :addresses

  # Validations
  validates :npi, presence: true, uniqueness: true, length: { is: 10 }
  validates :entity_type, presence: true
  validates :first_name, :last_name, presence: true, if: :entity_individual?
  validates :organization_name, presence: true, if: :entity_organization?

  # Scopes
  scope :active, -> { where(deactivation_date: nil) }
  scope :deactivated, -> { where.not(deactivation_date: nil) }
  scope :individuals, -> { where(entity_type: 1) }
  scope :organizations, -> { where(entity_type: 2) }
  scope :with_credential, ->(credential) { where(credential: credential) }

  # Full-text search scope using PostgreSQL tsvector
  scope :search_by_name, ->(query) {
    where("search_vector @@ plainto_tsquery('english', ?)", query)
      .order(
        sanitize_sql_for_order([
          "ts_rank(search_vector, plainto_tsquery('english', ?)) DESC",
          query
        ])
      )
  }

  scope :in_state, ->(state_code) {
    joins(addresses: :state)
      .where(addresses: { address_purpose: "LOCATION" })
      .where(states: { code: state_code })
      .distinct
  }

  scope :in_city, ->(city_name, state_code) {
    joins(addresses: [ :city, :state ])
      .where(addresses: { address_purpose: "LOCATION" })
      .where(cities: { name: city_name })
      .where(states: { code: state_code })
      .distinct
  }

  scope :with_taxonomy, ->(taxonomy_code) {
    joins(:taxonomies).where(taxonomies: { code: taxonomy_code }).distinct
  }

  # Instance methods
  def full_name
    if entity_individual?
      [ name_prefix, first_name, middle_name, last_name, name_suffix, credential ]
        .compact.join(" ")
    else
      organization_name
    end
  end

  def primary_taxonomy
    provider_taxonomies.find_by(is_primary: true)&.taxonomy
  end

  def primary_location
    addresses.find_by(address_purpose: "LOCATION")
  end

  def mailing_address
    addresses.find_by(address_purpose: "MAILING")
  end

  def active?
    deactivation_date.nil?
  end

  def individual?
    entity_type == 1
  end

  def organization?
    entity_type == 2
  end
end
