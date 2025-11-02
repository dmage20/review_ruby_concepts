# Provider Data Platform for Insurance Brokers

A comprehensive healthcare provider database and API designed specifically for insurance brokers to access actionable provider data.

## Overview

This platform serves as a **data source** for insurance brokers, providing comprehensive, up-to-date information about healthcare providers across the United States. Insurance brokers can query this database to:

- Find providers by specialty, location, and credentials
- Identify which insurance plans/networks providers accept
- Access provider quality metrics and ratings
- View provider practice information and availability
- Check credentialing and licensing status
- Understand hospital affiliations and relationships

## Data Sources

### Primary: NPPES (National Plan and Provider Enumeration System)

The platform ingests data from three NPPES sources:

1. **CMS NPI Registry API** - Real-time provider data
   - Endpoint: `https://npiregistry.cms.hhs.gov/api/`
   - ~9 million healthcare providers
   - Updated daily
   
2. **NPPES CSV Files** - Bulk data imports
   - Full dataset: Monthly updates
   - Incremental updates: Weekly
   - 330+ data fields per provider

3. **NLM Clinical Tables API** - Fast autocomplete searches
   - Endpoint: `https://clinicaltables.nlm.nih.gov/api/npi_idv/v3/search`
   - Optimized for type-ahead searches

### Enhanced Data

Additional data layers for insurance broker use cases:

- Insurance plans and networks
- Provider-plan acceptance relationships
- Quality metrics from various sources
- Hospital affiliations
- Credentialing verification
- Practice information and availability
- Languages spoken
- Specializations and board certifications

## Database Schema

### Core Provider Data (NPPES)

**Providers Table**
- Healthcare providers (individual and organizational)
- NPI numbers, names, credentials
- Demographics, gender, entity type
- Enumeration and deactivation dates
- Full-text search capabilities

**Supporting NPPES Tables:**
- Addresses (practice locations and mailing)
- Taxonomies (specialties and provider types)
- Provider Taxonomies (many-to-many relationships)
- Identifiers (Medicare, Medicaid, DEA, etc.)
- Other Names (former names, aliases)
- Endpoints (EHR/FHIR endpoints)
- Authorized Officials (for organizations)
- States and Cities (normalized geography)

### Insurance Broker-Specific Tables

**Insurance Plans**
- Plan names, carriers, types
- Network types and coverage areas
- Effective and termination dates

**Provider-Insurance Plan Relationships**
- Which providers accept which plans
- Network tier levels
- Accepts new patients status
- Effective dates

**Provider Networks**
- Network names and types
- Carrier affiliations
- Coverage areas
- Network membership

**Provider Network Memberships**
- Provider-network relationships
- Member since dates
- Tier levels
- Status tracking

**Provider Quality Metrics**
- Quality scores and ratings
- Measurement dates and sources
- Various metric types

**Hospital Affiliations**
- Hospital relationships
- Affiliation types
- Department assignments
- Privileges granted

**Provider Credentials**
- Professional certifications
- License numbers and states
- Issue and expiration dates
- Verification status

**Provider Practice Information**
- Practice names
- Accepts new patients
- Patient age ranges
- Office hours
- Accessibility features
- Telehealth availability
- Appointment wait times

**Provider Languages**
- Languages spoken
- Proficiency levels

**Provider Specializations**
- Focus areas beyond basic taxonomy
- Years of experience
- Board certifications

## API Access

### GraphQL API (Recommended)

**Endpoint:** `POST /graphql`

**Development Interface:** `http://localhost:3000/graphiql`

#### Example Queries for Insurance Brokers

**Search providers by specialty and location:**
```graphql
query {
  providers(
    specialty: "Family Medicine"
    state: "CA"
    city: "Los Angeles"
    activeOnly: true
    limit: 20
  ) {
    id
    npi
    fullName
    credential
    addresses {
      address1
      cityName
      telephone
    }
    taxonomies {
      code
      specialization
    }
    insurancePlans {
      planName
      carrierName
      status
    }
    practiceInfo {
      acceptsNewPatients
      telehealthAvailable
      languagesSpoken
    }
    qualityMetrics {
      metricName
      rating
      score
    }
  }
}
```

**Find providers accepting specific insurance:**
```graphql
query {
  insurancePlan(id: "1") {
    planName
    carrierName
    providers {
      fullName
      npi
      credential
      addresses {
        cityName
        state
      }
      practiceInfo {
        acceptsNewPatients
      }
    }
  }
}
```

**Get provider details by NPI:**
```graphql
query {
  provider(npi: "1234567890") {
    fullName
    credential
    gender
    enumerationDate
    isActive
    addresses {
      addressPurpose
      address1
      cityName
      telephone
    }
    taxonomies {
      classification
      specialization
      description
    }
    hospitalAffiliations {
      hospitalName
      affiliationType
      department
    }
    credentials {
      credentialType
      credentialNumber
      expirationDate
      status
    }
    insurancePlans {
      planName
      carrierName
      networkTier
    }
    qualityMetrics {
      metricName
      rating
      measurementDate
    }
  }
}
```

**Find providers in a network:**
```graphql
query {
  providerNetwork(id: "1") {
    networkName
    carrierName
    coverageArea
    providers {
      fullName
      npi
      credential
      addresses {
        cityName
        state
      }
    }
  }
}
```

**Search by taxonomy/specialty:**
```graphql
query {
  taxonomies(classification: "Physician") {
    code
    classification
    specialization
    description
  }
}
```

### Direct PostgreSQL Access

For complex analytics, reporting, and bulk operations.

**Connection Details:**
```
Host: localhost
Port: 5432
Database: provider_directory_development
User: (configured)
Password: (configured)
```

#### Example SQL Queries for Brokers

**Providers accepting a specific insurance plan in an area:**
```sql
SELECT 
  p.npi,
  p.first_name,
  p.last_name,
  p.credential,
  a.city_name,
  a.state_id,
  ip.plan_name,
  pip.network_tier,
  pip.accepts_new_patients
FROM providers p
JOIN addresses a ON a.provider_id = p.id AND a.address_purpose = 'LOCATION'
JOIN provider_insurance_plans pip ON pip.provider_id = p.id
JOIN insurance_plans ip ON ip.id = pip.insurance_plan_id
WHERE ip.carrier_name = 'Blue Cross'
  AND a.city_name = 'Boston'
  AND p.deactivation_date IS NULL
  AND pip.status = 'active'
ORDER BY p.last_name, p.first_name;
```

**Provider quality metrics by specialty:**
```sql
SELECT 
  t.specialization,
  COUNT(DISTINCT p.id) as provider_count,
  AVG(pqm.score) as avg_quality_score,
  COUNT(pqm.id) as total_metrics
FROM providers p
JOIN provider_taxonomies pt ON pt.provider_id = p.id AND pt.is_primary = true
JOIN taxonomies t ON t.id = pt.taxonomy_id
LEFT JOIN provider_quality_metrics pqm ON pqm.provider_id = p.id
WHERE p.deactivation_date IS NULL
GROUP BY t.specialization
HAVING COUNT(DISTINCT p.id) > 10
ORDER BY avg_quality_score DESC NULLS LAST;
```

**Network coverage analysis:**
```sql
SELECT 
  pn.network_name,
  pn.carrier_name,
  s.name as state,
  COUNT(DISTINCT pnm.provider_id) as provider_count,
  COUNT(DISTINCT t.specialization) as specialty_count
FROM provider_networks pn
JOIN provider_network_memberships pnm ON pnm.provider_network_id = pn.id
JOIN providers p ON p.id = pnm.provider_id
JOIN addresses a ON a.provider_id = p.id AND a.address_purpose = 'LOCATION'
JOIN states s ON s.id = a.state_id
LEFT JOIN provider_taxonomies pt ON pt.provider_id = p.id
LEFT JOIN taxonomies t ON t.id = pt.taxonomy_id
WHERE pnm.status = 'active'
  AND p.deactivation_date IS NULL
GROUP BY pn.network_name, pn.carrier_name, s.name
ORDER BY provider_count DESC;
```

**Providers with hospital affiliations:**
```sql
SELECT 
  p.npi,
  p.first_name || ' ' || p.last_name as provider_name,
  p.credential,
  ha.hospital_name,
  ha.affiliation_type,
  ha.department,
  a.city_name
FROM providers p
JOIN hospital_affiliations ha ON ha.provider_id = p.id
JOIN addresses a ON a.provider_id = p.id AND a.address_purpose = 'LOCATION'
WHERE ha.status = 'active'
  AND p.deactivation_date IS NULL
ORDER BY ha.hospital_name, p.last_name;
```

## Use Cases for Insurance Brokers

### 1. Provider Network Development
- Identify providers to recruit for new networks
- Analyze geographic coverage gaps
- Find specialists in specific areas
- Build comprehensive provider directories

### 2. Plan Design & Pricing
- Assess provider availability by specialty and region
- Evaluate network adequacy
- Compare provider quality metrics across plans
- Analyze credentialing status

### 3. Client Service
- Help clients find in-network providers
- Locate providers accepting specific plans
- Find providers with specific languages/accessibility
- Check provider quality ratings

### 4. Compliance & Verification
- Verify provider NPI numbers
- Check provider active status
- Validate credentialing and licenses
- Monitor provider deactivations

### 5. Market Analysis
- Provider density by geography
- Specialty distribution analysis
- Network competitiveness assessment
- Quality metric benchmarking

### 6. Agent Tools
- Provider search for client needs
- Network comparison tools
- Provider quality scorecards
- Geographic coverage maps

## Data Updates & Maintenance

### NPPES Data Updates
- **Daily**: Real-time API access for current data
- **Weekly**: Incremental CSV file imports
- **Monthly**: Full dataset refresh

### Enhanced Data Updates
- Insurance plan data: Quarterly or as provided
- Quality metrics: As published by sources
- Credentialing data: Real-time verification
- Practice information: Periodic verification

## Setup & Installation

### Prerequisites
- Ruby 3.2.3+
- Rails 7.2.2+
- PostgreSQL 14+
- 10GB+ disk space for full NPPES dataset

### Installation Steps

```bash
# Clone repository
git clone <repository-url>
cd review_ruby_concepts

# Install dependencies
bundle install

# Setup database
bin/rails db:create
bin/rails db:migrate

# Import NPPES data (optional - see NPPES documentation)
bin/rails nppes:import

# Start server
bin/rails server
```

### Access APIs
- GraphQL Endpoint: `POST http://localhost:3000/graphql`
- GraphiQL Interface: `http://localhost:3000/graphiql`
- PostgreSQL: `localhost:5432`

## Security & Access Control

### For Production Deployment

1. **API Authentication**
   - Implement OAuth 2.0 or API keys
   - Rate limiting per client
   - Usage tracking and quotas

2. **Database Security**
   - Read-only database roles for broker access
   - Connection pooling and timeouts
   - SSL/TLS for all connections
   - IP whitelisting

3. **Data Privacy**
   - NPPES data is public domain (FOIA)
   - All data is publicly available from CMS
   - No PHI (Protected Health Information)
   - Comply with data use agreements

## Pricing Model (Suggested)

As a data platform for insurance brokers:

1. **API Access Tiers**
   - Basic: X requests/month
   - Professional: Y requests/month
   - Enterprise: Unlimited + dedicated support

2. **Direct Database Access**
   - Read-only connection credentials
   - Query performance guarantees
   - Dedicated instances for large clients

3. **Data Enhancements**
   - Quality metrics: Premium add-on
   - Real-time updates: Premium add-on
   - Custom data integrations: Enterprise

## Support & Documentation

- **API Documentation**: See this file and GraphiQL interface
- **NPPES Data Reference**: See NPPES.md
- **Database Schema**: See DATABASE_SCHEMA.md
- **Setup Guide**: See DATABASE_SETUP.md

## Technology Stack

- **Backend**: Ruby on Rails 7.2.2
- **Database**: PostgreSQL 14+ with full-text search
- **API**: GraphQL via graphql-ruby
- **Data Source**: NPPES (CMS) - Public Domain
- **Updates**: Automated import jobs

## Roadmap

- [ ] Real-time NPPES API sync
- [ ] Additional quality metric sources (HEDIS, NCQA)
- [ ] Provider reviews and ratings integration
- [ ] Telehealth capability tracking
- [ ] Mobile-optimized API
- [ ] Webhook notifications for provider changes
- [ ] Advanced analytics dashboards
- [ ] Export tools for broker CRM systems

## License & Usage

NPPES data is public domain under the Freedom of Information Act (FOIA). This platform aggregates and enhances public healthcare provider data for use by insurance brokers and related businesses.

**Attribution**: Data sourced from the National Plan and Provider Enumeration System (NPPES), maintained by the Centers for Medicare & Medicaid Services (CMS).
