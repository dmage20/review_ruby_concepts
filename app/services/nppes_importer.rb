# Service class for transforming NPPES staging data into normalized tables
# Implements blue-green deployment pattern for zero-downtime imports
#
# Usage:
#   NppesImporter.transform_staging_data
#   NppesImporter.validate_import
#   NppesImporter.swap_tables
#   NppesImporter.print_summary

class NppesImporter
  class << self
    # Main entry point for data transformation
    def transform_staging_data
      puts "[2/4] Transforming data into normalized tables..."

      # Create new tables with _new suffix
      create_new_tables

      # Import data from staging to new tables
      import_providers
      import_addresses
      import_provider_taxonomies
      import_identifiers
      import_authorized_officials

      # Update search vectors and analyze tables
      update_search_vectors

      puts "  ✓ Data transformation complete"
    end

    # Validate imported data quality
    def validate_import
      puts "[3/4] Validating imported data..."

      validations = {
        "Providers" => "SELECT COUNT(*) FROM providers_new",
        "Addresses" => "SELECT COUNT(*) FROM addresses_new",
        "Taxonomies" => "SELECT COUNT(*) FROM provider_taxonomies_new",
        "Identifiers" => "SELECT COUNT(*) FROM identifiers_new",
        "Authorized Officials" => "SELECT COUNT(*) FROM authorized_officials_new"
      }

      validations.each do |name, query|
        count = execute_sql(query).first["count"].to_i
        puts "  ✓ #{name}: #{count.to_s(:delimited)} records"
      end

      # Check for orphaned records
      validate_referential_integrity
    end

    # Swap new tables with production tables (atomic operation)
    def swap_tables
      puts "[4/4] Swapping tables (minimal downtime)..."

      tables = %w[providers addresses provider_taxonomies identifiers authorized_officials]

      ActiveRecord::Base.transaction do
        tables.each do |table|
          # Check if old table exists (may not on first import)
          old_exists = execute_sql(<<~SQL).first["exists"]
            SELECT EXISTS (
              SELECT FROM information_schema.tables
              WHERE table_schema = 'public'
              AND table_name = '#{table}'
            );
          SQL

          if old_exists
            # Rename old table to _old
            execute_sql("ALTER TABLE #{table} RENAME TO #{table}_old")
          end

          # Rename new table to production name
          execute_sql("ALTER TABLE #{table}_new RENAME TO #{table}")
        end
      end

      puts "  ✓ Tables swapped successfully"

      # Drop old tables after brief delay (if they exist)
      sleep 2
      tables.each do |table|
        execute_sql("DROP TABLE IF EXISTS #{table}_old CASCADE")
      end

      puts "  ✓ Old tables cleaned up"
    end

    # Print import summary statistics
    def print_summary
      puts "\n" + "="*70
      puts "IMPORT SUMMARY"
      puts "="*70

      [
        [ "Providers", "SELECT COUNT(*) FROM providers" ],
        [ "Individual Providers", "SELECT COUNT(*) FROM providers WHERE entity_type = 1" ],
        [ "Organizations", "SELECT COUNT(*) FROM providers WHERE entity_type = 2" ],
        [ "Active Providers", "SELECT COUNT(*) FROM providers WHERE deactivation_date IS NULL" ],
        [ "Deactivated Providers", "SELECT COUNT(*) FROM providers WHERE deactivation_date IS NOT NULL" ],
        [ "", "" ],  # Blank line
        [ "Addresses", "SELECT COUNT(*) FROM addresses" ],
        [ "Location Addresses", "SELECT COUNT(*) FROM addresses WHERE address_purpose = 'LOCATION'" ],
        [ "Mailing Addresses", "SELECT COUNT(*) FROM addresses WHERE address_purpose = 'MAILING'" ],
        [ "", "" ],
        [ "Provider Taxonomies", "SELECT COUNT(*) FROM provider_taxonomies" ],
        [ "Primary Taxonomies", "SELECT COUNT(*) FROM provider_taxonomies WHERE is_primary = true" ],
        [ "", "" ],
        [ "Identifiers", "SELECT COUNT(*) FROM identifiers" ],
        [ "Authorized Officials", "SELECT COUNT(*) FROM authorized_officials" ]
      ].each do |label, query|
        if label.empty?
          puts ""
        else
          count = execute_sql(query).first["count"].to_i
          puts "#{label.ljust(30)}: #{count.to_s(:delimited).rjust(20)}"
        end
      end

      puts "="*70
    end

    # Rollback to old tables in case of issues
    def rollback_import
      puts "Rolling back import..."

      tables = %w[providers addresses provider_taxonomies identifiers authorized_officials]

      ActiveRecord::Base.transaction do
        tables.each do |table|
          # Drop failed new tables
          execute_sql("DROP TABLE IF EXISTS #{table}_new CASCADE")

          # Check if old table exists
          old_exists = execute_sql(<<~SQL).first["exists"]
            SELECT EXISTS (
              SELECT FROM information_schema.tables
              WHERE table_schema = 'public'
              AND table_name = '#{table}_old'
            );
          SQL

          if old_exists
            # Rename current table to _failed
            execute_sql("ALTER TABLE #{table} RENAME TO #{table}_failed")

            # Restore old table
            execute_sql("ALTER TABLE #{table}_old RENAME TO #{table}")

            puts "  ✓ Restored #{table} from backup"
          end
        end
      end

      puts "✓ Rollback complete"
    end

    private

    # =====================================================================
    # TABLE CREATION
    # =====================================================================

    def create_new_tables
      tables = %w[providers addresses provider_taxonomies identifiers authorized_officials]

      tables.each do |table|
        execute_sql("DROP TABLE IF EXISTS #{table}_new CASCADE")
        execute_sql("CREATE TABLE #{table}_new (LIKE #{table} INCLUDING ALL)")
      end

      puts "  ✓ Created new tables"
    end

    # =====================================================================
    # PROVIDERS IMPORT
    # =====================================================================

    def import_providers
      start_time = Time.current

      execute_sql(<<~SQL)
        INSERT INTO providers_new (
          npi, entity_type, first_name, last_name, middle_name,
          name_prefix, name_suffix, credential, gender,
          organization_name, sole_proprietor, org_subpart,
          enumeration_date, deactivation_date, deactivation_reason,
          reactivation_date, created_at, updated_at
        )
        SELECT
          npi,
          CAST(entity_type_code AS INTEGER),
          NULLIF(TRIM(first_name), ''),
          NULLIF(TRIM(last_name), ''),
          NULLIF(TRIM(middle_name), ''),
          NULLIF(TRIM(name_prefix), ''),
          NULLIF(TRIM(name_suffix), ''),
          NULLIF(TRIM(credential), ''),
          CASE
            WHEN TRIM(gender) = 'M' THEN 'M'
            WHEN TRIM(gender) = 'F' THEN 'F'
            WHEN TRIM(gender) = 'X' THEN 'X'
            ELSE NULL
          END,
          NULLIF(TRIM(org_name), ''),
          CASE WHEN TRIM(sole_proprietor) = 'Y' THEN true ELSE false END,
          CASE WHEN TRIM(org_subpart) = 'Y' THEN true ELSE false END,
          TO_DATE(NULLIF(TRIM(enumeration_date), ''), 'MM/DD/YYYY'),
          TO_DATE(NULLIF(TRIM(deactivation_date), ''), 'MM/DD/YYYY'),
          NULLIF(TRIM(deactivation_reason), ''),
          TO_DATE(NULLIF(TRIM(reactivation_date), ''), 'MM/DD/YYYY'),
          NOW(),
          NOW()
        FROM staging_providers
        WHERE npi IS NOT NULL
          AND TRIM(npi) != ''
        ON CONFLICT (npi) DO UPDATE SET
          entity_type = EXCLUDED.entity_type,
          first_name = EXCLUDED.first_name,
          last_name = EXCLUDED.last_name,
          middle_name = EXCLUDED.middle_name,
          name_prefix = EXCLUDED.name_prefix,
          name_suffix = EXCLUDED.name_suffix,
          credential = EXCLUDED.credential,
          gender = EXCLUDED.gender,
          organization_name = EXCLUDED.organization_name,
          sole_proprietor = EXCLUDED.sole_proprietor,
          org_subpart = EXCLUDED.org_subpart,
          enumeration_date = EXCLUDED.enumeration_date,
          deactivation_date = EXCLUDED.deactivation_date,
          deactivation_reason = EXCLUDED.deactivation_reason,
          reactivation_date = EXCLUDED.reactivation_date,
          updated_at = NOW();
      SQL

      count = execute_sql("SELECT COUNT(*) FROM providers_new").first["count"].to_i
      duration = Time.current - start_time

      puts "  ✓ Imported #{count.to_s(:delimited)} providers in #{duration.round(1)}s"
    end

    # =====================================================================
    # ADDRESSES IMPORT
    # =====================================================================

    def import_addresses
      start_time = Time.current

      # Import mailing addresses
      execute_sql(<<~SQL)
        INSERT INTO addresses_new (
          provider_id, address_purpose, address_1, address_2,
          city_name, postal_code, telephone, fax_number,
          city_id, state_id, created_at, updated_at
        )
        SELECT
          p.id,
          'MAILING',
          NULLIF(TRIM(s.mail_address_1), ''),
          NULLIF(TRIM(s.mail_address_2), ''),
          NULLIF(TRIM(s.mail_city), ''),
          NULLIF(TRIM(s.mail_postal_code), ''),
          NULLIF(TRIM(s.mail_phone), ''),
          NULLIF(TRIM(s.mail_fax), ''),
          (
            SELECT id FROM cities
            WHERE UPPER(cities.name) = UPPER(TRIM(s.mail_city))
              AND cities.state_id = (SELECT id FROM states WHERE states.code = TRIM(s.mail_state))
            LIMIT 1
          ),
          (SELECT id FROM states WHERE states.code = TRIM(s.mail_state)),
          NOW(),
          NOW()
        FROM staging_providers s
        INNER JOIN providers_new p ON p.npi = s.npi
        WHERE NULLIF(TRIM(s.mail_address_1), '') IS NOT NULL;
      SQL

      # Import practice location addresses
      execute_sql(<<~SQL)
        INSERT INTO addresses_new (
          provider_id, address_purpose, address_1, address_2,
          city_name, postal_code, telephone, fax_number,
          city_id, state_id, created_at, updated_at
        )
        SELECT
          p.id,
          'LOCATION',
          NULLIF(TRIM(s.practice_address_1), ''),
          NULLIF(TRIM(s.practice_address_2), ''),
          NULLIF(TRIM(s.practice_city), ''),
          NULLIF(TRIM(s.practice_postal_code), ''),
          NULLIF(TRIM(s.practice_phone), ''),
          NULLIF(TRIM(s.practice_fax), ''),
          (
            SELECT id FROM cities
            WHERE UPPER(cities.name) = UPPER(TRIM(s.practice_city))
              AND cities.state_id = (SELECT id FROM states WHERE states.code = TRIM(s.practice_state))
            LIMIT 1
          ),
          (SELECT id FROM states WHERE states.code = TRIM(s.practice_state)),
          NOW(),
          NOW()
        FROM staging_providers s
        INNER JOIN providers_new p ON p.npi = s.npi
        WHERE NULLIF(TRIM(s.practice_address_1), '') IS NOT NULL;
      SQL

      count = execute_sql("SELECT COUNT(*) FROM addresses_new").first["count"].to_i
      duration = Time.current - start_time

      puts "  ✓ Imported #{count.to_s(:delimited)} addresses in #{duration.round(1)}s"
    end

    # =====================================================================
    # PROVIDER TAXONOMIES IMPORT
    # =====================================================================

    def import_provider_taxonomies
      start_time = Time.current
      total_imported = 0

      # Unpack up to 15 taxonomy slots per provider
      15.times do |i|
        slot = i + 1

        result = execute_sql(<<~SQL)
          INSERT INTO provider_taxonomies_new (
            provider_id, taxonomy_id, license_number, license_state_id,
            is_primary, created_at, updated_at
          )
          SELECT
            p.id,
            t.id,
            NULLIF(TRIM(s.taxonomy_license_#{slot}), ''),
            (SELECT id FROM states WHERE states.code = TRIM(s.taxonomy_state_#{slot})),
            CASE WHEN TRIM(s.taxonomy_primary_#{slot}) = 'Y' THEN true ELSE false END,
            NOW(),
            NOW()
          FROM staging_providers s
          INNER JOIN providers_new p ON p.npi = s.npi
          INNER JOIN taxonomies t ON t.code = TRIM(s.taxonomy_code_#{slot})
          WHERE NULLIF(TRIM(s.taxonomy_code_#{slot}), '') IS NOT NULL
          RETURNING id;
        SQL

        imported = result.count
        total_imported += imported
      end

      duration = Time.current - start_time
      puts "  ✓ Imported #{total_imported.to_s(:delimited)} provider-taxonomy relationships in #{duration.round(1)}s"
    end

    # =====================================================================
    # IDENTIFIERS IMPORT
    # =====================================================================

    def import_identifiers
      start_time = Time.current
      total_imported = 0

      # Unpack up to 50 identifier slots per provider
      # Process in batches of 10 for better performance
      5.times do |batch|
        batch_start = batch * 10 + 1
        batch_end = (batch + 1) * 10

        (batch_start..batch_end).each do |slot|
          result = execute_sql(<<~SQL)
            INSERT INTO identifiers_new (
              provider_id, identifier_type_code, identifier_value,
              state_id, issuer, created_at, updated_at
            )
            SELECT
              p.id,
              NULLIF(TRIM(s.identifier_type_#{slot}), ''),
              NULLIF(TRIM(s.identifier_#{slot}), ''),
              (SELECT id FROM states WHERE states.code = TRIM(s.identifier_state_#{slot})),
              NULLIF(TRIM(s.identifier_issuer_#{slot}), ''),
              NOW(),
              NOW()
            FROM staging_providers s
            INNER JOIN providers_new p ON p.npi = s.npi
            WHERE NULLIF(TRIM(s.identifier_#{slot}), '') IS NOT NULL
            RETURNING id;
          SQL

          imported = result.count
          total_imported += imported
        end
      end

      duration = Time.current - start_time
      puts "  ✓ Imported #{total_imported.to_s(:delimited)} identifiers in #{duration.round(1)}s"
    end

    # =====================================================================
    # AUTHORIZED OFFICIALS IMPORT
    # =====================================================================

    def import_authorized_officials
      start_time = Time.current

      execute_sql(<<~SQL)
        INSERT INTO authorized_officials_new (
          provider_id, first_name, last_name, middle_name,
          title_or_position, telephone, name_prefix, name_suffix,
          credential, created_at, updated_at
        )
        SELECT
          p.id,
          NULLIF(TRIM(s.ao_first_name), ''),
          NULLIF(TRIM(s.ao_last_name), ''),
          NULLIF(TRIM(s.ao_middle_name), ''),
          NULLIF(TRIM(s.ao_title), ''),
          NULLIF(TRIM(s.ao_phone), ''),
          NULLIF(TRIM(s.ao_prefix), ''),
          NULLIF(TRIM(s.ao_suffix), ''),
          NULLIF(TRIM(s.ao_credential), ''),
          NOW(),
          NOW()
        FROM staging_providers s
        INNER JOIN providers_new p ON p.npi = s.npi
        WHERE s.entity_type_code = '2'  -- Organizations only
          AND NULLIF(TRIM(s.ao_last_name), '') IS NOT NULL;
      SQL

      count = execute_sql("SELECT COUNT(*) FROM authorized_officials_new").first["count"].to_i
      duration = Time.current - start_time

      puts "  ✓ Imported #{count.to_s(:delimited)} authorized officials in #{duration.round(1)}s"
    end

    # =====================================================================
    # SEARCH VECTORS & OPTIMIZATION
    # =====================================================================

    def update_search_vectors
      start_time = Time.current

      # Search vectors are auto-generated via GENERATED ALWAYS AS
      # But we need to analyze the table for query planner statistics
      execute_sql("ANALYZE providers_new")
      execute_sql("ANALYZE addresses_new")
      execute_sql("ANALYZE provider_taxonomies_new")
      execute_sql("ANALYZE identifiers_new")
      execute_sql("ANALYZE authorized_officials_new")

      duration = Time.current - start_time
      puts "  ✓ Updated search indexes and statistics in #{duration.round(1)}s"
    end

    # =====================================================================
    # VALIDATION
    # =====================================================================

    def validate_referential_integrity
      # Check for orphaned addresses
      orphaned_addresses = execute_sql(<<~SQL).first["count"].to_i
        SELECT COUNT(*) FROM addresses_new
        WHERE provider_id NOT IN (SELECT id FROM providers_new)
      SQL

      if orphaned_addresses > 0
        puts "  ⚠ Warning: #{orphaned_addresses.to_s(:delimited)} orphaned addresses found"
      else
        puts "  ✓ No orphaned addresses"
      end

      # Check for orphaned provider taxonomies
      orphaned_taxonomies = execute_sql(<<~SQL).first["count"].to_i
        SELECT COUNT(*) FROM provider_taxonomies_new
        WHERE provider_id NOT IN (SELECT id FROM providers_new)
      SQL

      if orphaned_taxonomies > 0
        puts "  ⚠ Warning: #{orphaned_taxonomies.to_s(:delimited)} orphaned provider taxonomies found"
      else
        puts "  ✓ No orphaned provider taxonomies"
      end

      # Check for providers with multiple primary taxonomies
      multiple_primary = execute_sql(<<~SQL).first["count"].to_i
        SELECT COUNT(*) FROM (
          SELECT provider_id
          FROM provider_taxonomies_new
          WHERE is_primary = true
          GROUP BY provider_id
          HAVING COUNT(*) > 1
        ) AS dupes
      SQL

      if multiple_primary > 0
        puts "  ⚠ Warning: #{multiple_primary.to_s(:delimited)} providers have multiple primary taxonomies"
      else
        puts "  ✓ No duplicate primary taxonomies"
      end
    end

    # =====================================================================
    # HELPER METHODS
    # =====================================================================

    def execute_sql(sql)
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
