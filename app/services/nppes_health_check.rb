# Health check service for NPPES import validation
# Verifies data quality and referential integrity
#
# Usage:
#   result = NppesHealthCheck.verify_import_health
#   result[:status]  # => 'healthy' or 'unhealthy'
#   result[:checks]  # => Hash of check results

class NppesHealthCheck
  class << self
    # Verify overall import health
    def verify_import_health
      checks = {
        sufficient_providers: check_provider_count,
        sufficient_addresses: check_address_count,
        sufficient_taxonomies: check_taxonomy_count,
        primary_taxonomies_exist: check_primary_taxonomies,
        search_index_exists: check_search_index,
        no_orphaned_addresses: check_no_orphaned_addresses,
        no_orphaned_taxonomies: check_no_orphaned_taxonomies,
        no_duplicate_npis: check_no_duplicate_npis,
        no_multiple_primary_taxonomies: check_no_multiple_primary_taxonomies,
        states_seeded: check_states_seeded,
        taxonomies_seeded: check_taxonomies_seeded
      }

      all_pass = checks.values.all?

      {
        status: all_pass ? "healthy" : "unhealthy",
        checks: checks,
        summary: generate_summary(checks)
      }
    end

    # Detailed validation report
    def detailed_report
      puts "\n" + "="*70
      puts "NPPES DATA HEALTH REPORT"
      puts "="*70

      result = verify_import_health

      puts "\nStatus: #{result[:status].upcase}"

      puts "\nData Counts:"
      puts "  Providers:           #{Provider.count.to_s(:delimited)}"
      puts "  - Individuals:       #{Provider.entity_individual.count.to_s(:delimited)}"
      puts "  - Organizations:     #{Provider.entity_organization.count.to_s(:delimited)}"
      puts "  - Active:            #{Provider.where(deactivation_date: nil).count.to_s(:delimited)}"
      puts "  - Deactivated:       #{Provider.where.not(deactivation_date: nil).count.to_s(:delimited)}"
      puts ""
      puts "  Addresses:           #{Address.count.to_s(:delimited)}"
      puts "  - Location:          #{Address.where(address_purpose: 'LOCATION').count.to_s(:delimited)}"
      puts "  - Mailing:           #{Address.where(address_purpose: 'MAILING').count.to_s(:delimited)}"
      puts ""
      puts "  Provider Taxonomies: #{ProviderTaxonomy.count.to_s(:delimited)}"
      puts "  - Primary:           #{ProviderTaxonomy.where(is_primary: true).count.to_s(:delimited)}"
      puts ""
      puts "  Identifiers:         #{Identifier.count.to_s(:delimited)}"
      puts "  Authorized Officials: #{AuthorizedOfficial.count.to_s(:delimited)}"
      puts ""
      puts "  Cities:              #{City.count.to_s(:delimited)}"
      puts "  States:              #{State.count.to_s(:delimited)}"
      puts "  Taxonomies:          #{Taxonomy.count.to_s(:delimited)}"

      puts "\nHealth Checks:"
      result[:checks].each do |name, passed|
        status = passed ? "✓" : "✗"
        puts "  #{status} #{name.to_s.humanize}"
      end

      puts "\nSummary:"
      puts result[:summary]

      puts "="*70

      result
    end

    private

    # =====================================================================
    # HEALTH CHECK METHODS
    # =====================================================================

    def check_provider_count
      # Should have at least some providers (adjust threshold as needed)
      Provider.count >= 100
    end

    def check_address_count
      # Most providers should have at least one address
      Address.count >= (Provider.count * 0.8).to_i
    end

    def check_taxonomy_count
      # Most providers should have at least one taxonomy
      ProviderTaxonomy.count >= (Provider.count * 0.8).to_i
    end

    def check_primary_taxonomies
      # Most providers should have a primary taxonomy
      ProviderTaxonomy.where(is_primary: true).count >= (Provider.count * 0.7).to_i
    end

    def check_search_index
      # Verify search index exists
      result = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT COUNT(*) FROM pg_indexes
        WHERE indexname = 'index_providers_on_search_vector'
      SQL

      result.first["count"].to_i > 0
    end

    def check_no_orphaned_addresses
      # No addresses should point to non-existent providers
      orphaned = Address.where.not(provider_id: Provider.select(:id)).count
      orphaned == 0
    end

    def check_no_orphaned_taxonomies
      # No provider_taxonomies should point to non-existent providers
      orphaned = ProviderTaxonomy.where.not(provider_id: Provider.select(:id)).count
      orphaned == 0
    end

    def check_no_duplicate_npis
      # Each NPI should be unique
      duplicates = ActiveRecord::Base.connection.execute(<<~SQL).first["count"].to_i
        SELECT COUNT(*) FROM (
          SELECT npi
          FROM providers
          GROUP BY npi
          HAVING COUNT(*) > 1
        ) AS dupes
      SQL

      duplicates == 0
    end

    def check_no_multiple_primary_taxonomies
      # Each provider should have at most one primary taxonomy
      multiple = ActiveRecord::Base.connection.execute(<<~SQL).first["count"].to_i
        SELECT COUNT(*) FROM (
          SELECT provider_id
          FROM provider_taxonomies
          WHERE is_primary = true
          GROUP BY provider_id
          HAVING COUNT(*) > 1
        ) AS dupes
      SQL

      multiple == 0
    end

    def check_states_seeded
      # All U.S. states should be present (50 states + DC + territories = 56)
      State.count >= 56
    end

    def check_taxonomies_seeded
      # Common taxonomies should be seeded (at least 40)
      Taxonomy.count >= 40
    end

    # =====================================================================
    # SUMMARY GENERATION
    # =====================================================================

    def generate_summary(checks)
      passed = checks.values.count(true)
      failed = checks.values.count(false)
      total = checks.size

      if failed == 0
        "All #{total} health checks passed. Data quality is good."
      else
        "#{passed}/#{total} health checks passed. #{failed} check(s) failed. Review issues above."
      end
    end

    # =====================================================================
    # UTILITY METHODS
    # =====================================================================

    def self.count_providers_by_state
      ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT s.code, s.name, COUNT(DISTINCT p.id) as provider_count
        FROM states s
        LEFT JOIN addresses a ON a.state_id = s.id AND a.address_purpose = 'LOCATION'
        LEFT JOIN providers p ON p.id = a.provider_id
        GROUP BY s.code, s.name
        ORDER BY provider_count DESC
      SQL
    end

    def self.count_providers_by_taxonomy
      ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT t.code, t.specialization, COUNT(DISTINCT pt.provider_id) as provider_count
        FROM taxonomies t
        LEFT JOIN provider_taxonomies pt ON pt.taxonomy_id = t.id
        GROUP BY t.code, t.specialization
        ORDER BY provider_count DESC
        LIMIT 20
      SQL
    end

    def self.find_data_quality_issues
      issues = []

      # Providers without names
      no_name_count = Provider.where(
        "(first_name IS NULL OR first_name = '') AND (organization_name IS NULL OR organization_name = '')"
      ).count
      issues << "#{no_name_count} providers without names" if no_name_count > 0

      # Providers without addresses
      no_address_count = Provider.left_joins(:addresses)
                                   .where(addresses: { id: nil })
                                   .count
      issues << "#{no_address_count} providers without addresses" if no_address_count > 0

      # Providers without taxonomies
      no_taxonomy_count = Provider.left_joins(:provider_taxonomies)
                                     .where(provider_taxonomies: { id: nil })
                                     .count
      issues << "#{no_taxonomy_count} providers without taxonomies" if no_taxonomy_count > 0

      # Invalid NPIs (not 10 digits)
      invalid_npi_count = Provider.where("LENGTH(npi) != 10").count
      issues << "#{invalid_npi_count} providers with invalid NPI length" if invalid_npi_count > 0

      issues
    end
  end
end
