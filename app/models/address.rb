class Address < ApplicationRecord
  # Associations
  belongs_to :provider
  belongs_to :city, optional: true
  belongs_to :state, optional: true

  # Validations
  validates :address_purpose, presence: true, inclusion: { in: %w[LOCATION MAILING] }
  validates :address_type, inclusion: { in: %w[DOM FGN] }

  # Scopes
  scope :locations, -> { where(address_purpose: "LOCATION") }
  scope :mailing, -> { where(address_purpose: "MAILING") }
  scope :domestic, -> { where(address_type: "DOM") }
  scope :foreign, -> { where(address_type: "FGN") }
  scope :in_state, ->(state_code) {
    joins(:state).where(states: { code: state_code })
  }

  def full_address
    [ address_1, address_2, city_name, state&.code, postal_code ]
      .compact.join(", ")
  end

  def location?
    address_purpose == "LOCATION"
  end

  def mailing?
    address_purpose == "MAILING"
  end
end
