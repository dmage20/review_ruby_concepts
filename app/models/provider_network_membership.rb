class ProviderNetworkMembership < ApplicationRecord
  belongs_to :provider
  belongs_to :provider_network
end
