# GraphQL Query Examples

This document shows all the GraphQL queries that are **fully implemented and working** in the Provider Data Platform.

## Provider Search Queries

### 1. Find Pediatric Doctors in Los Angeles accepting Blue Cross Blue Shield

```graphql
query {
  providers(
    specialty: "Pediatrics"
    city: "Los Angeles"
    state: "CA"
    insuranceCarrier: "Blue Cross Blue Shield"
    activeOnly: true
    limit: 20
  ) {
    id
    npi
    fullName
    credential
    isActive
    addresses {
      addressPurpose
      address1
      cityName
      telephone
    }
    taxonomies {
      code
      specialization
      classification
    }
    insurancePlans {
      planName
      carrierName
      networkType
      status
    }
    practiceInfo {
      acceptsNewPatients
      telehealthAvailable
      officeHours
      languagesSpoken
    }
  }
}
```

### 2. Search by Provider Name

```graphql
query {
  providers(
    name: "Smith"
    state: "CA"
    activeOnly: true
    limit: 50
  ) {
    fullName
    npi
    credential
    addresses {
      cityName
      telephone
    }
  }
}
```

### 3. Find Providers by Specialty Only

```graphql
query {
  providers(
    specialty: "Family Medicine"
    activeOnly: true
    limit: 100
  ) {
    fullName
    npi
    credential
    taxonomies {
      specialization
      classification
    }
    addresses {
      cityName
      state
    }
  }
}
```

### 4. Find All Providers in a State

```graphql
query {
  providers(
    state: "NY"
    activeOnly: true
    limit: 50
  ) {
    fullName
    npi
    credential
    addresses {
      cityName
      address1
      postalCode
      telephone
    }
  }
}
```

### 5. Find Providers Accepting Specific Insurance

```graphql
query {
  providers(
    insuranceCarrier: "Aetna"
    state: "TX"
    activeOnly: true
    limit: 25
  ) {
    fullName
    npi
    insurancePlans {
      planName
      carrierName
      planType
      networkType
    }
    addresses {
      cityName
      telephone
    }
  }
}
```

### 6. Look Up Provider by NPI

```graphql
query {
  provider(npi: "1234567890") {
    fullName
    npi
    credential
    gender
    enumerationDate
    isActive
    addresses {
      addressPurpose
      address1
      address2
      cityName
      postalCode
      telephone
      fax
    }
    taxonomies {
      code
      classification
      specialization
      description
    }
    identifiers {
      identifierType
      identifierValue
      issuer
    }
    insurancePlans {
      planName
      carrierName
      planType
      networkType
      status
    }
    providerNetworks {
      networkName
      carrierName
      networkType
      coverageArea
    }
    qualityMetrics {
      metricName
      metricType
      score
      rating
      measurementDate
      source
    }
    hospitalAffiliations {
      hospitalName
      hospitalNpi
      affiliationType
      department
      status
    }
    credentials {
      credentialType
      credentialNumber
      issuingOrganization
      issueDate
      expirationDate
      status
    }
    practiceInfo {
      practiceName
      acceptsNewPatients
      patientAgeRange
      languagesSpoken
      officeHours
      telehealthAvailable
      appointmentWaitTime
    }
    languages {
      languageName
      proficiencyLevel
    }
    specializations {
      specializationName
      focusArea
      yearsExperience
      boardCertified
      certificationBody
    }
  }
}
```

### 7. Complex Multi-Filter Query

```graphql
query {
  providers(
    name: "Johnson"
    specialty: "Internal Medicine"
    city: "Boston"
    state: "MA"
    insuranceCarrier: "Medicare"
    activeOnly: true
    limit: 10
  ) {
    fullName
    npi
    credential
    addresses {
      address1
      cityName
      telephone
    }
    taxonomies {
      specialization
    }
    insurancePlans {
      planName
      carrierName
    }
    qualityMetrics {
      metricName
      rating
    }
  }
}
```

## Insurance Plan Queries

### 8. Get All Insurance Plans

```graphql
query {
  insurancePlans {
    id
    planName
    carrierName
    planType
    networkType
    coverageArea
    status
    effectiveDate
    terminationDate
  }
}
```

### 9. Get Specific Insurance Plan with Providers

```graphql
query {
  insurancePlan(id: "1") {
    planName
    carrierName
    planType
    networkType
    coverageArea
    providers {
      fullName
      npi
      credential
      addresses {
        cityName
        state
        telephone
      }
      practiceInfo {
        acceptsNewPatients
      }
    }
  }
}
```

## Provider Network Queries

### 10. Get All Provider Networks

```graphql
query {
  providerNetworks {
    id
    networkName
    carrierName
    networkType
    coverageArea
    status
    description
  }
}
```

### 11. Get Specific Network with All Providers

```graphql
query {
  providerNetwork(id: "1") {
    networkName
    carrierName
    networkType
    coverageArea
    providers {
      fullName
      npi
      credential
      addresses {
        cityName
        state
      }
      taxonomies {
        specialization
      }
    }
  }
}
```

## Taxonomy/Specialty Queries

### 12. Search Taxonomies by Classification

```graphql
query {
  taxonomies(classification: "Physician", limit: 100) {
    id
    code
    classification
    specialization
    description
  }
}
```

### 13. Get Specific Taxonomy by Code

```graphql
query {
  taxonomy(code: "207Q00000X") {
    code
    classification
    specialization
    description
  }
}
```

### 14. Browse All Specialties

```graphql
query {
  taxonomies(limit: 200) {
    code
    classification
    specialization
  }
}
```

## Query Arguments Reference

### `providers` Query Arguments

| Argument | Type | Required | Description | Example |
|----------|------|----------|-------------|---------|
| `name` | String | No | Search by provider name (first, last, or organization) | `"Smith"` |
| `specialty` | String | No | Filter by specialty/taxonomy | `"Pediatrics"` |
| `state` | String | No | Filter by state code | `"CA"` |
| `city` | String | No | Filter by city name | `"Los Angeles"` |
| `npi` | String | No | Search by exact NPI number | `"1234567890"` |
| `insuranceCarrier` | String | No | Filter by insurance carrier | `"Blue Cross"` |
| `activeOnly` | Boolean | No | Only return active providers | `true` (default) |
| `limit` | Integer | No | Maximum number of results | `50` (default) |

**Notes:**
- All text filters use case-insensitive partial matching (ILIKE)
- State codes must be 2-letter codes (e.g., "CA", "NY", "TX")
- Multiple filters are combined with AND logic
- Use `.distinct` to avoid duplicate results when filtering

## Response Fields

### Provider Type Fields

All provider queries return these fields:

```graphql
type Provider {
  # Basic Info
  id: ID!
  npi: String!
  entityType: Int!
  firstName: String
  lastName: String
  middleName: String
  namePrefix: String
  nameSuffix: String
  credential: String
  gender: String
  organizationName: String
  
  # Computed Fields
  fullName: String
  isActive: Boolean!
  
  # Dates
  enumerationDate: ISO8601Date
  lastUpdateDate: ISO8601Date
  deactivationDate: ISO8601Date
  reactivationDate: ISO8601Date
  
  # Associations (nested queries)
  addresses: [Address]
  taxonomies: [Taxonomy]
  identifiers: [Identifier]
  insurancePlans: [InsurancePlan]
  providerNetworks: [ProviderNetwork]
  qualityMetrics: [ProviderQualityMetric]
  hospitalAffiliations: [HospitalAffiliation]
  credentials: [ProviderCredential]
  practiceInfo: ProviderPracticeInfo
  languages: [ProviderLanguage]
  specializations: [ProviderSpecialization]
}
```

## Performance Tips

1. **Use limits** - Always specify a reasonable limit (default is 50)
2. **Request only needed fields** - Don't query nested associations unless you need them
3. **Use specific filters** - More filters = faster queries
4. **Avoid very broad searches** - `name: "a"` will be slow
5. **Use NPI for exact lookups** - Fastest way to get a single provider

## Examples of Slow vs Fast Queries

### ❌ Slow Query (too broad)
```graphql
query {
  providers(name: "a", limit: 1000) {
    fullName
    addresses { ... }
    taxonomies { ... }
    insurancePlans { ... }
    qualityMetrics { ... }
  }
}
```

### ✅ Fast Query (specific filters)
```graphql
query {
  providers(
    specialty: "Cardiology"
    city: "Chicago"
    state: "IL"
    limit: 25
  ) {
    fullName
    npi
    addresses {
      telephone
    }
  }
}
```

## Testing Queries

Access the GraphiQL interface to test these queries:

```
http://localhost:3000/graphiql
```

GraphiQL provides:
- Auto-completion
- Query validation
- Schema documentation
- Query history

## Next Steps

After getting familiar with these queries, you may want to:
1. Use Direct SQL for complex analytics
2. Build custom mutations for data updates
3. Add authentication for production use
4. Implement rate limiting
5. Set up API monitoring

See `PROVIDER_DATA_PLATFORM.md` for SQL query examples and platform architecture.
