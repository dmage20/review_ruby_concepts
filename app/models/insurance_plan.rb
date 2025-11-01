class InsurancePlan < ApplicationRecord
  # Associations
  has_many :provider_insurance_plans, dependent: :destroy
  has_many :providers, through: :provider_insurance_plans
end
