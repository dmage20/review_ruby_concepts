class ProviderNetwork < ApplicationRecord
  # Associations
  has_many :provider_network_memberships, dependent: :destroy
  has_many :providers, through: :provider_network_memberships
end
