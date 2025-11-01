# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # Provider queries
    field :providers, [Types::ProviderType], null: false, description: "Search all providers" do
      argument :name, String, required: false
      argument :specialty, String, required: false
      argument :state, String, required: false
      argument :city, String, required: false
      argument :npi, String, required: false
      argument :active_only, Boolean, required: false, default_value: true
      argument :limit, Integer, required: false, default_value: 50
    end

    field :provider, Types::ProviderType, null: true, description: "Fetch a single provider by ID or NPI" do
      argument :id, ID, required: false
      argument :npi, String, required: false
    end

    def providers(name: nil, specialty: nil, state: nil, city: nil, npi: nil, active_only: true, limit: 50)
      scope = Provider.all
      scope = scope.where(deactivation_date: nil) if active_only
      scope = scope.where("first_name ILIKE ? OR last_name ILIKE ? OR organization_name ILIKE ?", "%#{name}%", "%#{name}%", "%#{name}%") if name
      scope = scope.where(npi: npi) if npi
      # Add more filters as needed
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
    field :insurance_plans, [Types::InsurancePlanType], null: false, description: "Fetch all insurance plans"
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
    field :insurance_carriers, [Types::InsuranceCarrierType], null: false, description: "Fetch all insurance carriers"
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
    field :provider_networks, [Types::ProviderNetworkType], null: false, description: "Fetch all provider networks"
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
    field :taxonomies, [Types::TaxonomyType], null: false, description: "Fetch all taxonomies/specialties" do
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
