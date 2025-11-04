# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # Provider queries
    field :providers, [ Types::ProviderType ], null: false, description: "Search all providers" do
      argument :name, String, required: false, description: "Search by provider name (first, last, or organization)"
      argument :specialty, String, required: false, description: "Filter by specialty/taxonomy (e.g., 'Pediatrics', 'Family Medicine')"
      argument :state, String, required: false, description: "Filter by state code (e.g., 'CA', 'NY')"
      argument :city, String, required: false, description: "Filter by city name (e.g., 'Los Angeles')"
      argument :npi, String, required: false, description: "Search by exact NPI number"
      argument :insurance_carrier, String, required: false, description: "Filter by insurance carrier (e.g., 'Blue Cross Blue Shield')"
      argument :active_only, Boolean, required: false, default_value: true, description: "Only return active providers"
      argument :limit, Integer, required: false, default_value: 50, description: "Maximum number of results"
    end

    field :provider, Types::ProviderType, null: true, description: "Fetch a single provider by ID or NPI" do
      argument :id, ID, required: false
      argument :npi, String, required: false
    end

    def providers(name: nil, specialty: nil, state: nil, city: nil, npi: nil, insurance_carrier: nil, active_only: true, limit: 50)
      scope = Provider.distinct

      # Active providers only
      scope = scope.where(deactivation_date: nil) if active_only

      # Filter by name (first, last, or organization)
      if name.present?
        scope = scope.where(
          "first_name ILIKE ? OR last_name ILIKE ? OR organization_name ILIKE ?",
          "%#{name}%", "%#{name}%", "%#{name}%"
        )
      end

      # Filter by exact NPI
      scope = scope.where(npi: npi) if npi.present?

      # Filter by specialty/taxonomy
      if specialty.present?
        scope = scope.joins(:taxonomies)
          .where("taxonomies.specialization ILIKE ? OR taxonomies.classification ILIKE ? OR taxonomies.description ILIKE ?",
                 "%#{specialty}%", "%#{specialty}%", "%#{specialty}%")
      end

      # Filter by state (via practice location address)
      if state.present?
        scope = scope.joins(:addresses)
          .joins("INNER JOIN states ON states.id = addresses.state_id")
          .where("addresses.address_purpose = 'LOCATION'")
          .where("states.code = ?", state.upcase)
      end

      # Filter by city (via practice location address)
      if city.present?
        # Join to addresses if not already joined (state filter already joins)
        scope = scope.joins(:addresses) unless state.present?
        scope = scope.where("addresses.address_purpose = 'LOCATION'")
          .where("addresses.city_name ILIKE ?", "%#{city}%")
      end

      # Filter by insurance carrier
      if insurance_carrier.present?
        scope = scope.joins(:insurance_plans)
          .where("insurance_plans.carrier_name ILIKE ?", "%#{insurance_carrier}%")
      end

      scope.limit(limit)
    end

    def provider(id: nil, npi: nil)
      if id
        Provider.find_by(id: id)
      elsif npi
        Provider.find_by(npi: npi)
      end
    end

    # Insurance Plan queries
    field :insurance_plans, [ Types::InsurancePlanType ], null: false, description: "Fetch all insurance plans"
    field :insurance_plan, Types::InsurancePlanType, null: true, description: "Fetch a single insurance plan" do
      argument :id, ID, required: true
    end

    def insurance_plans
      InsurancePlan.all
    end

    def insurance_plan(id:)
      InsurancePlan.find_by(id: id)
    end

    # Insurance Carrier queries
    field :insurance_carriers, [ Types::InsuranceCarrierType ], null: false, description: "Fetch all insurance carriers"
    field :insurance_carrier, Types::InsuranceCarrierType, null: true, description: "Fetch a single insurance carrier" do
      argument :id, ID, required: true
    end

    def insurance_carriers
      InsuranceCarrier.all
    end

    def insurance_carrier(id:)
      InsuranceCarrier.find_by(id: id)
    end

    # Provider Network queries
    field :provider_networks, [ Types::ProviderNetworkType ], null: false, description: "Fetch all provider networks"
    field :provider_network, Types::ProviderNetworkType, null: true, description: "Fetch a single provider network" do
      argument :id, ID, required: true
    end

    def provider_networks
      ProviderNetwork.all
    end

    def provider_network(id:)
      ProviderNetwork.find_by(id: id)
    end

    # Taxonomy queries
    field :taxonomies, [ Types::TaxonomyType ], null: false, description: "Fetch all taxonomies/specialties" do
      argument :classification, String, required: false
      argument :limit, Integer, required: false, default_value: 100
    end

    field :taxonomy, Types::TaxonomyType, null: true, description: "Fetch a single taxonomy" do
      argument :id, ID, required: false
      argument :code, String, required: false
    end

    def taxonomies(classification: nil, limit: 100)
      scope = Taxonomy.all
      scope = scope.where("classification ILIKE ?", "%#{classification}%") if classification
      scope.limit(limit)
    end

    def taxonomy(id: nil, code: nil)
      if id
        Taxonomy.find_by(id: id)
      elsif code
        Taxonomy.find_by(code: code)
      end
    end
  end
end
