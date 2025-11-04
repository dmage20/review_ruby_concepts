class Identifier < ApplicationRecord
  # Associations
  belongs_to :provider
  belongs_to :state, optional: true

  # Validations
  validates :identifier_type, presence: true
  validates :identifier_value, presence: true
  validates :identifier_value, uniqueness: {
    scope: [ :provider_id, :identifier_type ]
  }

  # Scopes
  scope :medicaid, -> { where(identifier_type: "MEDICAID") }
  scope :medicare, -> { where(identifier_type: "MEDICARE") }
  scope :dea, -> { where(identifier_type: "DEA") }
  scope :by_type, ->(type) { where(identifier_type: type) }
end
