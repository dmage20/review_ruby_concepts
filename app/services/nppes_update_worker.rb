# Worker class for processing NPPES incremental updates
# This can be called synchronously or via background job
#
# Usage:
#   worker = NppesUpdateWorker.new
#   worker.perform('/path/to/weekly_update.csv')

require "csv"

class NppesUpdateWorker
  attr_reader :updated_count, :created_count, :error_count

  def initialize
    @updated_count = 0
    @created_count = 0
    @error_count = 0
  end

  def perform(csv_path)
    unless File.exist?(csv_path)
      raise "CSV file not found: #{csv_path}"
    end

    start_time = Time.current

    puts "\nProcessing incremental updates..."
    puts "This may take 10-30 minutes depending on file size."

    CSV.foreach(csv_path, headers: true).with_index do |row, index|
      begin
        process_provider_row(row)
      rescue => e
        @error_count += 1
        Rails.logger.error("Error processing NPI #{row['NPI']}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end

      # Progress update every 10,000 records
      if (index + 1) % 10_000 == 0
        elapsed = Time.current - start_time
        rate = (index + 1) / elapsed
        estimated_remaining = ((CSV.read(csv_path, headers: true).count - index) / rate / 60.0).round(1) rescue "?"

        puts "  Progress: #{(index + 1).to_s(:delimited)} records processed"
        puts "    Created: #{@created_count.to_s(:delimited)}, Updated: #{@updated_count.to_s(:delimited)}, Errors: #{@error_count.to_s(:delimited)}"
        puts "    Rate: #{rate.round(0).to_s(:delimited)} records/sec"
        puts "    Estimated time remaining: #{estimated_remaining} minutes" if estimated_remaining != "?"
      end
    end

    duration = Time.current - start_time

    puts "\n" + "-"*70
    puts "UPDATE SUMMARY"
    puts "-"*70
    puts "Duration: #{duration.round(1)}s (#{(duration / 60.0).round(1)} minutes)"
    puts "Created: #{@created_count.to_s(:delimited)} providers"
    puts "Updated: #{@updated_count.to_s(:delimited)} providers"
    puts "Errors: #{@error_count.to_s(:delimited)} errors"
    puts "-"*70
  end

  private

  def process_provider_row(row)
    npi = row["NPI"]

    Provider.transaction do
      provider = Provider.find_or_initialize_by(npi: npi)
      is_new = provider.new_record?

      # Update provider attributes
      provider.assign_attributes(
        entity_type: row["Entity Type Code"].to_i,
        first_name: row["Provider First Name"],
        last_name: row["Provider Last Name (Legal Name)"],
        middle_name: row["Provider Middle Name"],
        name_prefix: row["Provider Name Prefix Text"],
        name_suffix: row["Provider Name Suffix Text"],
        credential: row["Provider Credential Text"],
        gender: parse_gender(row["Provider Gender Code"]),
        organization_name: row["Provider Organization Name (Legal Business Name)"],
        sole_proprietor: row["Is Sole Proprietor"] == "Y",
        org_subpart: row["Is Organization Subpart"] == "Y",
        enumeration_date: parse_date(row["Provider Enumeration Date"]),
        deactivation_date: parse_date(row["NPI Deactivation Date"]),
        deactivation_reason: row["NPI Deactivation Reason Code"],
        reactivation_date: parse_date(row["NPI Reactivation Date"])
      )

      provider.save!

      # Sync addresses
      sync_addresses(provider, row)

      # Sync taxonomies
      sync_taxonomies(provider, row)

      # Sync identifiers (only if needed - can skip for performance)
      # sync_identifiers(provider, row)

      # Sync authorized official (if organization)
      sync_authorized_official(provider, row) if provider.entity_organization?

      if is_new
        @created_count += 1
      else
        @updated_count += 1
      end
    end
  end

  def sync_addresses(provider, row)
    # Remove existing addresses and recreate
    # (simpler than trying to match and update)
    provider.addresses.destroy_all

    # Mailing address
    if row["Provider First Line Business Mailing Address"].present?
      state = State.find_by(code: row["Provider Business Mailing Address State Name"])
      city = find_or_create_city(
        row["Provider Business Mailing Address City Name"],
        row["Provider Business Mailing Address State Name"]
      )

      provider.addresses.create!(
        address_purpose: "MAILING",
        address_1: row["Provider First Line Business Mailing Address"],
        address_2: row["Provider Second Line Business Mailing Address"],
        city_name: row["Provider Business Mailing Address City Name"],
        postal_code: row["Provider Business Mailing Address Postal Code"],
        telephone: row["Provider Business Mailing Address Telephone Number"],
        fax_number: row["Provider Business Mailing Address Fax Number"],
        state: state,
        city: city
      )
    end

    # Practice location address
    if row["Provider First Line Business Practice Location Address"].present?
      state = State.find_by(code: row["Provider Business Practice Location Address State Name"])
      city = find_or_create_city(
        row["Provider Business Practice Location Address City Name"],
        row["Provider Business Practice Location Address State Name"]
      )

      provider.addresses.create!(
        address_purpose: "LOCATION",
        address_1: row["Provider First Line Business Practice Location Address"],
        address_2: row["Provider Second Line Business Practice Location Address"],
        city_name: row["Provider Business Practice Location Address City Name"],
        postal_code: row["Provider Business Practice Location Address Postal Code"],
        telephone: row["Provider Business Practice Location Address Telephone Number"],
        fax_number: row["Provider Business Practice Location Address Fax Number"],
        state: state,
        city: city
      )
    end
  end

  def sync_taxonomies(provider, row)
    provider.provider_taxonomies.destroy_all

    15.times do |i|
      slot = i + 1
      code = row["Healthcare Provider Taxonomy Code_#{slot}"]

      next if code.blank?

      taxonomy = Taxonomy.find_by(code: code)
      next unless taxonomy

      provider.provider_taxonomies.create!(
        taxonomy: taxonomy,
        license_number: row["Provider License Number_#{slot}"],
        license_state: State.find_by(code: row["Provider License Number State Code_#{slot}"]),
        is_primary: row["Healthcare Provider Primary Taxonomy Switch_#{slot}"] == "Y"
      )
    end
  end

  def sync_identifiers(provider, row)
    provider.identifiers.destroy_all

    50.times do |i|
      slot = i + 1
      identifier_value = row["Other Provider Identifier_#{slot}"]

      next if identifier_value.blank?

      provider.identifiers.create!(
        identifier_type_code: row["Other Provider Identifier Type Code_#{slot}"],
        identifier_value: identifier_value,
        state: State.find_by(code: row["Other Provider Identifier State_#{slot}"]),
        issuer: row["Other Provider Identifier Issuer_#{slot}"]
      )
    end
  end

  def sync_authorized_official(provider, row)
    return if row["Authorized Official Last Name"].blank?

    provider.authorized_official&.destroy

    provider.create_authorized_official!(
      first_name: row["Authorized Official First Name"],
      last_name: row["Authorized Official Last Name"],
      middle_name: row["Authorized Official Middle Name"],
      title_or_position: row["Authorized Official Title or Position"],
      telephone: row["Authorized Official Telephone Number"],
      name_prefix: row["Authorized Official Name Prefix Text"],
      name_suffix: row["Authorized Official Name Suffix Text"],
      credential: row["Authorized Official Credential Text"]
    )
  end

  def find_or_create_city(city_name, state_code)
    return nil if city_name.blank? || state_code.blank?

    state = State.find_by(code: state_code)
    return nil unless state

    City.find_or_create_by!(name: city_name, state: state)
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.strptime(date_string, "%m/%d/%Y")
  rescue ArgumentError
    nil
  end

  def parse_gender(gender_string)
    case gender_string&.strip&.upcase
    when "M" then "M"
    when "F" then "F"
    when "X" then "X"
    else nil
    end
  end
end
