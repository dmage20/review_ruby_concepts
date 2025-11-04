class Taxonomy < ApplicationRecord
  # Associations
  has_many :provider_taxonomies, dependent: :restrict_with_error
  has_many :providers, through: :provider_taxonomies

  # Validations
  validates :code, presence: true, uniqueness: true, length: { is: 10 }

  # Scopes
  scope :physicians, -> { where("classification ILIKE ?", "%physician%") }
  scope :nurses, -> { where("classification ILIKE ?", "%nurs%") }
  scope :by_classification, ->(classification) {
    where("classification ILIKE ?", "%#{classification}%")
  }

  def display_name
    [ classification, specialization ].compact.join(" - ")
  end
end
