class OtherName < ApplicationRecord
  belongs_to :provider

  validates :name_type, presence: true

  def full_name
    if first_name.present?
      [ name_prefix, first_name, middle_name, last_name, name_suffix, credential ]
        .compact.join(" ")
    else
      organization_name
    end
  end
end
