class AuthorizedOfficial < ApplicationRecord
  belongs_to :provider

  validates :first_name, :last_name, presence: true
  validates :provider_id, uniqueness: true

  def full_name
    [ name_prefix, first_name, middle_name, last_name, name_suffix, credential ]
      .compact.join(" ")
  end
end
