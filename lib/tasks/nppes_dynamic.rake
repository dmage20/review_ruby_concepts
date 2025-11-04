# NPPES Dynamic Import (for testing with real NPPES files)
# This version creates staging table dynamically from CSV headers

namespace :nppes do
  desc "Import NPPES data with dynamic staging table (for testing)"
  task :import_dynamic, [ :csv_path ] => :environment do |t, args|
    csv_path = args[:csv_path] || ENV["NPPES_CSV_PATH"]

    if csv_path.blank?
      puts "ERROR: CSV path required"
      puts "Usage: rails nppes:import_dynamic[/path/to/npidata.csv]"
      exit 1
    end

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found: #{csv_path}"
      exit 1
    end

    puts "\n" + "="*70
    puts "NPPES DYNAMIC IMPORT (Testing Mode)"
    puts "="*70
    puts "CSV File: #{csv_path}"
    puts "File Size: #{(File.size(csv_path) / 1024.0 / 1024.0).round(2)} MB"
    puts "Started: #{Time.current}"
    puts "="*70

    overall_start = Time.current

    begin
      # Step 1: Read CSV headers
      puts "\n[1/5] Reading CSV headers..."
      header_line = File.open(csv_path, &:readline).chomp
      csv_columns = header_line.split(",")

      puts "  ✓ Found #{csv_columns.length} columns"

      # Step 2: Create dynamic staging table
      puts "\n[2/5] Creating dynamic staging table..."
      create_dynamic_staging_table(csv_columns)

      # Step 3: Load CSV using COPY
      puts "\n[3/5] Loading CSV into staging table..."
      load_csv_with_copy(csv_path, csv_columns)

      # Step 4: Transform to normalized tables
      puts "\n[4/5] Transforming to normalized tables..."
      transform_dynamic_staging_data

      # Step 5: Validate
      puts "\n[5/5] Validating import..."
      validate_dynamic_import

      # Cleanup
      puts "\nCleaning up..."
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS staging_providers_dynamic")
      puts "  ✓ Staging table dropped"

      total_duration = Time.current - overall_start
      puts "\n" + "="*70
      puts "✓ IMPORT COMPLETE"
      puts "="*70
      puts "Total Time: #{total_duration.round(1)}s (#{(total_duration / 60.0).round(1)} minutes)"
      puts "="*70

      # Print summary
      print_import_summary

    rescue => e
      puts "\n" + "="*70
      puts "✗ IMPORT FAILED"
      puts "="*70
      puts "Error: #{e.message}"
      puts e.backtrace.first(10).join("\n")
      puts "="*70
      exit 1
    end
  end

  def create_dynamic_staging_table(csv_columns)
    # Sanitize column names for PostgreSQL
    sanitized_columns = csv_columns.map { |col| sanitize_nppes_column(col) }

    # Drop existing table
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS staging_providers_dynamic CASCADE")

    # Create table with all columns as TEXT (simplest approach)
    column_definitions = sanitized_columns.map { |col| "#{col} TEXT" }.join(",\n  ")

    create_sql = <<~SQL
      CREATE TABLE staging_providers_dynamic (
        #{column_definitions}
      );
    SQL

    ActiveRecord::Base.connection.execute(create_sql)

    puts "  ✓ Created staging table with #{sanitized_columns.length} columns"
  end

  def load_csv_with_copy(csv_path, csv_columns)
    start_time = Time.current

    sanitized_columns = csv_columns.map { |col| sanitize_nppes_column(col) }

    conn = ActiveRecord::Base.connection.raw_connection

    copy_sql = <<~SQL
      COPY staging_providers_dynamic (#{sanitized_columns.join(', ')})
      FROM STDIN
      WITH (FORMAT CSV, HEADER true, DELIMITER ',', NULL '', ENCODING 'UTF8', QUOTE '"')
    SQL

    conn.copy_data(copy_sql) do
      File.open(csv_path, "r") do |file|
        while line = file.gets
          conn.put_copy_data(line)
        end
      end
    end

    count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) FROM staging_providers_dynamic"
    ).first["count"].to_i

    duration = Time.current - start_time
    puts "  ✓ Loaded #{number_with_delimiter(count)} records in #{duration.round(1)}s"
    puts "  ✓ Average: #{number_with_delimiter((count / duration).round(0))} records/second"
  end

  def transform_dynamic_staging_data
    start_time = Time.current

    # Map from dynamic staging table to our normalized schema
    execute_sql(<<~SQL)
      INSERT INTO providers (
        npi, entity_type, first_name, last_name, middle_name,
        name_prefix, name_suffix, credential, gender,
        organization_name, sole_proprietor, organization_subpart,
        enumeration_date, deactivation_date, deactivation_reason,
        reactivation_date, created_at, updated_at
      )
      SELECT
        npi,
        CAST(entity_type_code AS INTEGER),
        NULLIF(TRIM(provider_first_name), ''),
        NULLIF(TRIM(provider_last_name_legal_name), ''),
        NULLIF(TRIM(provider_middle_name), ''),
        NULLIF(TRIM(provider_name_prefix_text), ''),
        NULLIF(TRIM(provider_name_suffix_text), ''),
        NULLIF(TRIM(provider_credential_text), ''),
        CASE
          WHEN TRIM(provider_sex_code) = 'M' THEN 'M'
          WHEN TRIM(provider_sex_code) = 'F' THEN 'F'
          WHEN TRIM(provider_sex_code) = 'X' THEN 'X'
          ELSE NULL
        END,
        NULLIF(TRIM(provider_organization_name_legal_business_name), ''),
        CASE WHEN TRIM(is_sole_proprietor) = 'Y' THEN true ELSE false END,
        CASE WHEN TRIM(is_organization_subpart) = 'Y' THEN true ELSE false END,
        TO_DATE(NULLIF(TRIM(provider_enumeration_date), ''), 'MM/DD/YYYY'),
        TO_DATE(NULLIF(TRIM(npi_deactivation_date), ''), 'MM/DD/YYYY'),
        NULLIF(TRIM(npi_deactivation_reason_code), ''),
        TO_DATE(NULLIF(TRIM(npi_reactivation_date), ''), 'MM/DD/YYYY'),
        NOW(),
        NOW()
      FROM staging_providers_dynamic
      WHERE npi IS NOT NULL
        AND TRIM(npi) != ''
      ON CONFLICT (npi) DO UPDATE SET
        entity_type = EXCLUDED.entity_type,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        updated_at = NOW();
    SQL

    provider_count = Provider.count
    duration = Time.current - start_time

    puts "  ✓ Imported #{number_with_delimiter(provider_count)} providers in #{duration.round(1)}s"
  end

  def validate_dynamic_import
    puts "  ✓ Providers: #{number_with_delimiter(Provider.count)}"
    puts "  ✓ Validation complete"
  end

  def print_import_summary
    puts "\n" + "="*70
    puts "IMPORT SUMMARY"
    puts "="*70
    puts "Providers: #{number_with_delimiter(Provider.count)}"
    puts "  - Individuals: #{number_with_delimiter(Provider.entity_individual.count)}"
    puts "  - Organizations: #{number_with_delimiter(Provider.entity_organization.count)}"
    puts "="*70
  end

  def sanitize_nppes_column(name)
    # Remove quotes
    name = name.gsub(/^"|"$/, "")
    # Convert to lowercase
    name = name.downcase
    # Replace spaces with underscores
    name = name.gsub(/\s+/, "_")
    # Remove parentheses and periods
    name = name.gsub(/[().]/, "")
    # Remove special characters except underscores
    name = name.gsub(/[^a-z0-9_]/, "_")
    # Clean up multiple underscores
    name = name.gsub(/_+/, "_")
    # Remove leading/trailing underscores
    name = name.gsub(/^_|_$/, "")
    name
  end

  def execute_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
