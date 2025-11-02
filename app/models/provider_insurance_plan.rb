class ProviderInsurancePlan < ApplicationRecord
  belongs_to :provider
  belongs_to :insurance_plan
end
