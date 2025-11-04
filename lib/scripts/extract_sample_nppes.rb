#!/usr/bin/env ruby

# Sample NPPES CSV Extraction Script
#
# This script extracts a subset of records from the full NPPES CSV file
# for testing purposes. This allows you to test the import process without
# downloading and processing the entire 6+ GB file.
#
# Usage:
#   ruby lib/scripts/extract_sample_nppes.rb /path/to/full_nppes.csv /path/to/sample.csv 10000
#
# Arguments:
#   1. Source CSV file (full NPPES file)
#   2. Destination CSV file (sample output)
#   3. Number of records to extract (default: 10000)

require "csv"
require "fileutils"

# Helper method to format numbers with thousand separators
def format_number(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

# Parse command line arguments
if ARGV.length < 2
  puts "ERROR: Missing required arguments"
  puts "\nUsage:"
  puts "  ruby #{__FILE__} <source_csv> <destination_csv> [record_count]"
  puts "\nExample:"
  puts "  ruby #{__FILE__} /tmp/npidata.csv /tmp/sample_10k.csv 10000"
  exit 1
end

source_path = ARGV[0]
dest_path = ARGV[1]
record_count = (ARGV[2] || 10_000).to_i

# Validate source file exists
unless File.exist?(source_path)
  puts "ERROR: Source file not found: #{source_path}"
  exit 1
end

# Create destination directory if needed
FileUtils.mkdir_p(File.dirname(dest_path))

puts "\n" + "="*70
puts "NPPES SAMPLE EXTRACTION"
puts "="*70
puts "Source:      #{source_path}"
puts "Destination: #{dest_path}"
puts "Records:     #{format_number(record_count)}"
puts "="*70

start_time = Time.now
records_written = 0

# Strategy for sampling:
# 1. Always include the header
# 2. Extract diverse entity types (individuals and organizations)
# 3. Try to get variety in taxonomies and states

puts "\nExtracting records..."

individual_count = 0
organization_count = 0
individual_target = (record_count * 0.8).to_i  # 80% individuals
organization_target = record_count - individual_target  # 20% organizations

CSV.open(dest_path, "w") do |csv_out|
  CSV.foreach(source_path, headers: true).with_index do |row, index|
    # Write header
    if index == 0
      csv_out << row.headers
    end

    # Check entity type
    entity_type = row["Entity Type Code"]

    if entity_type == "1" && individual_count < individual_target
      csv_out << row
      individual_count += 1
      records_written += 1
    elsif entity_type == "2" && organization_count < organization_target
      csv_out << row
      organization_count += 1
      records_written += 1
    end

    # Progress indicator
    if (index + 1) % 100_000 == 0
      puts "  Scanned #{format_number(index + 1)} records, extracted #{format_number(records_written)}"
    end

    # Stop when we have enough records
    break if records_written >= record_count
  end
end

duration = Time.now - start_time
file_size_mb = (File.size(dest_path) / 1024.0 / 1024.0).round(2)

puts "\n" + "="*70
puts "✓ EXTRACTION COMPLETE"
puts "="*70
puts "Records written:     #{format_number(records_written)}"
puts "  - Individuals:     #{format_number(individual_count)}"
puts "  - Organizations:   #{format_number(organization_count)}"
puts "Output file size:    #{file_size_mb} MB"
puts "Duration:            #{duration.round(1)}s"
puts "="*70
puts "\nYou can now import this sample file:"
puts "  rails nppes:import[#{dest_path}]"
puts "="*70
