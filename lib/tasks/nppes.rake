# NPPES Data Import Tasks
#
# These tasks handle importing and updating NPPES provider data from CSV files
#
# Initial Import:
#   rails nppes:import[/path/to/npidata.csv]
#
# Weekly Update:
#   rails nppes:update[/path/to/weekly_update.csv]
#
# Rollback:
#   rails nppes:rollback
#
# Validate:
#   rails nppes:validate

namespace :nppes do
  desc "Import NPPES data from CSV file (full import with blue-green deployment)"
  task :import, [ :csv_path ] => :environment do |t, args|
    csv_path = args[:csv_path] || ENV["NPPES_CSV_PATH"]

    if csv_path.blank?
      puts "ERROR: CSV path required"
      puts "Usage: rails nppes:import[/path/to/npidata.csv]"
      puts "   or: NPPES_CSV_PATH=/path/to/npidata.csv rails nppes:import"
      exit 1
    end

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found: #{csv_path}"
      exit 1
    end

    puts "\n" + "="*70
    puts "NPPES DATA IMPORT"
    puts "="*70
    puts "CSV File: #{csv_path}"
    puts "File Size: #{(File.size(csv_path) / 1024.0 / 1024.0).round(2)} MB"
    puts "Started: #{Time.current}"
    puts "="*70

    # Record start time
    overall_start = Time.current

    begin
      # Step 1: Create staging table
      puts "\n[1/4] Creating staging table..."
      step_start = Time.current

      staging_sql = File.read(Rails.root.join("db", "staging_providers.sql"))
      ActiveRecord::Base.connection.execute(staging_sql)

      puts "  ✓ Staging table created in #{(Time.current - step_start).round(1)}s"

      # Step 2: Load CSV into staging table using PostgreSQL COPY
      puts "\n[1/4] Loading CSV into staging table..."
      step_start = Time.current

      # Use PostgreSQL COPY for fast bulk import
      conn = ActiveRecord::Base.connection.raw_connection

      # Read the CSV header to get column names
      header = File.open(csv_path, &:readline).chomp
      columns = header.split(",").map { |col| sanitize_column_name(col) }

      # Build COPY command
      copy_sql = <<~SQL
        COPY staging_providers (#{columns.join(', ')})
        FROM STDIN
        WITH (FORMAT CSV, HEADER true, DELIMITER ',', NULL '', ENCODING 'UTF8')
      SQL

      # Execute COPY
      conn.copy_data(copy_sql) do
        File.open(csv_path, "r") do |file|
          while line = file.gets
            conn.put_copy_data(line)
          end
        end
      end

      staging_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM staging_providers"
      ).first["count"].to_i

      step_duration = Time.current - step_start
      puts "  ✓ Loaded #{staging_count.to_s(:delimited)} records in #{step_duration.round(1)}s"
      puts "  ✓ Average: #{(staging_count / step_duration).round(0).to_s(:delimited)} records/second"

      # Step 2: Transform data
      NppesImporter.transform_staging_data

      # Step 3: Validate
      NppesImporter.validate_import

      # Step 4: Swap tables
      NppesImporter.swap_tables

      # Step 5: Cleanup
      puts "\n[5/5] Cleaning up..."
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS staging_providers")
      puts "  ✓ Staging table dropped"

      # Print summary
      NppesImporter.print_summary

      # Final timing
      total_duration = Time.current - overall_start
      puts "\n" + "="*70
      puts "✓ IMPORT COMPLETE"
      puts "="*70
      puts "Total Time: #{total_duration.round(1)}s (#{(total_duration / 60.0).round(1)} minutes)"
      puts "Completed: #{Time.current}"
      puts "="*70

    rescue => e
      puts "\n" + "="*70
      puts "✗ IMPORT FAILED"
      puts "="*70
      puts "Error: #{e.message}"
      puts e.backtrace.first(10).join("\n")
      puts "="*70
      puts "\nYou may want to run: rails nppes:rollback"
      exit 1
    end
  end

  desc "Apply weekly incremental update from CSV"
  task :update, [ :csv_path ] => :environment do |t, args|
    csv_path = args[:csv_path] || ENV["NPPES_UPDATE_CSV_PATH"]

    if csv_path.blank?
      puts "ERROR: CSV path required"
      puts "Usage: rails nppes:update[/path/to/weekly_update.csv]"
      puts "   or: NPPES_UPDATE_CSV_PATH=/path/to/weekly_update.csv rails nppes:update"
      exit 1
    end

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found: #{csv_path}"
      exit 1
    end

    puts "\n" + "="*70
    puts "NPPES INCREMENTAL UPDATE"
    puts "="*70
    puts "CSV File: #{csv_path}"
    puts "File Size: #{(File.size(csv_path) / 1024.0 / 1024.0).round(2)} MB"
    puts "Started: #{Time.current}"
    puts "="*70

    # Check if Sidekiq is available for background processing
    if defined?(Sidekiq)
      puts "\n✓ Queuing background job for incremental update..."
      NppesUpdateJob.perform_later(csv_path)
      puts "✓ Job queued. Monitor progress with Sidekiq dashboard."
      puts "\nNote: This is a background job. The application will remain available."
    else
      puts "\nWARNING: Sidekiq not available. Running synchronously..."
      puts "This may take 10-30 minutes. Consider installing Sidekiq for background processing."

      # Run synchronously
      NppesUpdateWorker.new.perform(csv_path)
    end
  end

  desc "Rollback to previous import (restores _old tables)"
  task rollback: :environment do
    puts "\n" + "="*70
    puts "NPPES IMPORT ROLLBACK"
    puts "="*70

    print "Are you sure you want to rollback? This will restore the previous dataset. (y/N): "
    confirmation = STDIN.gets.chomp

    unless confirmation.downcase == "y"
      puts "Rollback cancelled."
      exit 0
    end

    NppesImporter.rollback_import

    puts "\n✓ Rollback complete"
  end

  desc "Validate NPPES data quality"
  task validate: :environment do
    puts "\n" + "="*70
    puts "NPPES DATA VALIDATION"
    puts "="*70

    result = NppesHealthCheck.verify_import_health

    puts "\nStatus: #{result[:status].upcase}"
    puts "\nChecks:"
    result[:checks].each do |name, passed|
      status = passed ? "✓" : "✗"
      puts "  #{status} #{name.to_s.humanize}"
    end

    if result[:status] == "healthy"
      puts "\n✓ All checks passed"
      exit 0
    else
      puts "\n✗ Some checks failed"
      exit 1
    end
  end

  desc "Download latest NPPES file from CMS"
  task :download, [ :destination ] => :environment do |t, args|
    destination = args[:destination] || ENV["NPPES_DOWNLOAD_PATH"] || Rails.root.join("tmp", "nppes_data.zip")

    puts "\n" + "="*70
    puts "NPPES FILE DOWNLOAD"
    puts "="*70
    puts "NOTE: NPPES files are 6+ GB. This will take significant time."
    puts "Destination: #{destination}"
    puts "="*70

    require "open-uri"
    require "fileutils"

    # CMS download page URL (user needs to get actual file URL from the page)
    cms_url = "https://download.cms.gov/nppes/NPI_Files.html"

    puts "\nTo download the NPPES file:"
    puts "1. Visit: #{cms_url}"
    puts "2. Find the latest 'NPPES Data Dissemination' file"
    puts "3. Right-click and copy the download link"
    puts "4. Download manually or use wget/curl:"
    puts "\n   wget -O #{destination} [DOWNLOAD_URL]"
    puts "\n5. Then run: rails nppes:extract[#{destination}]"

    puts "\nOpening download page in browser..."
    system("open '#{cms_url}'") || system("xdg-open '#{cms_url}'")
  end

  desc "Extract NPPES ZIP file"
  task :extract, [ :zip_path, :destination ] => :environment do |t, args|
    zip_path = args[:zip_path] || ENV["NPPES_ZIP_PATH"]
    destination = args[:destination] || Rails.root.join("tmp", "nppes_extracted")

    if zip_path.blank?
      puts "ERROR: ZIP path required"
      puts "Usage: rails nppes:extract[/path/to/nppes.zip]"
      exit 1
    end

    unless File.exist?(zip_path)
      puts "ERROR: ZIP file not found: #{zip_path}"
      exit 1
    end

    puts "\n" + "="*70
    puts "EXTRACTING NPPES ZIP FILE"
    puts "="*70
    puts "Source: #{zip_path}"
    puts "Destination: #{destination}"
    puts "="*70

    FileUtils.mkdir_p(destination)

    puts "\nExtracting... (this may take several minutes)"
    success = system("unzip -o '#{zip_path}' -d '#{destination}'")

    if success
      puts "\n✓ Extraction complete"

      # Find the CSV file
      csv_files = Dir.glob(File.join(destination, "*.csv"))
      if csv_files.any?
        csv_file = csv_files.first
        puts "\n✓ CSV file found: #{csv_file}"
        puts "\nTo import, run:"
        puts "  rails nppes:import[#{csv_file}]"
      else
        puts "\n⚠ Warning: No CSV files found in extracted contents"
      end
    else
      puts "\n✗ Extraction failed"
      exit 1
    end
  end

  desc "Show NPPES import statistics"
  task stats: :environment do
    NppesImporter.print_summary
  end

  desc "Extract sample records from full NPPES file for testing"
  task :extract_sample, [ :source, :destination, :count ] => :environment do |t, args|
    source = args[:source] || ENV["NPPES_SOURCE_CSV"]
    destination = args[:destination] || Rails.root.join("tmp", "nppes_sample.csv").to_s
    count = (args[:count] || ENV["SAMPLE_COUNT"] || 10_000).to_i

    if source.blank?
      puts "ERROR: Source CSV path required"
      puts "Usage: rails nppes:extract_sample[/path/to/full.csv,/path/to/sample.csv,10000]"
      puts "   or: NPPES_SOURCE_CSV=/path/to/full.csv rails nppes:extract_sample"
      exit 1
    end

    script_path = Rails.root.join("lib", "scripts", "extract_sample_nppes.rb")
    system("ruby #{script_path} #{source} #{destination} #{count}")
  end

  # Helper method to sanitize CSV column names for PostgreSQL
  def sanitize_column_name(name)
    # Remove quotes, convert spaces to underscores, lowercase
    name = name.gsub(/^"|"$/, "")  # Remove surrounding quotes
    name = name.gsub(/\s+/, "_")   # Spaces to underscores
    name = name.gsub(/[().]/, "")  # Remove parentheses and periods
    name = name.downcase
    name = name.gsub(/\/_/, "_")   # Clean up double underscores
    name = name.gsub(/_+/, "_")    # Clean up multiple underscores
    name = name.gsub(/^_|_$/, "")  # Remove leading/trailing underscores

    # Map to our staging table column names
    column_mapping = {
      "npi" => "npi",
      "entity_type_code" => "entity_type_code",
      "replacement_npi" => "replacement_npi",
      "employer_identification_number_ein" => "ein",
      "provider_organization_name_legal_business_name" => "org_name",
      "provider_last_name_legal_name" => "last_name",
      "provider_first_name" => "first_name",
      "provider_middle_name" => "middle_name",
      "provider_name_prefix_text" => "name_prefix",
      "provider_name_suffix_text" => "name_suffix",
      "provider_credential_text" => "credential"
      # Add more mappings as needed...
    }

    column_mapping[name] || name
  end
end
