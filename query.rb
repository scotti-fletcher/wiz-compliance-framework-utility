UPDATE_SECURITY_FRAMEWORK_MUTATION = <<~GRAPHQL
  mutation UpdateSecurityFramework($input: UpdateSecurityFrameworkInput!) {
    updateSecurityFramework(input: $input) {
      framework {
        id
        enabled
        name
        description

        categories {
          id
          name
          description

          subCategories {
            id
            title
            description
          }
        }
      }
    }
  }
GRAPHQL

UPDATE_CLOUD_CONFIG_RULE_MUTATION = <<~GRAPHQL
  mutation UpdateCloudConfigurationRule(
    $ruleId: ID!
    $patch: UpdateCloudConfigurationRulePatch
    $override: UpdateCloudConfigurationRulePatch
  ) {
    updateCloudConfigurationRule(
      input: {
        id: $ruleId
        patch: $patch
        override: $override
      }
    ) {
      rule {
        id
        targetNativeTypes
        opaPolicy
        functionAsControl
        name
        description
        severity
        remediationInstructions
        enabled

        control {
          id
        }

        iacMatchers {
          id
          type
          regoCode
        }

        securitySubCategories {
          id
          title
          description
          category {
            id
            name
            description
            framework {
              id
              name
              enabled
            }
          }
        }

        scopeAccounts {
          id
          name
          cloudProvider
        }
      }
    }
  }
GRAPHQL


UPDATE_HOST_CONFIG_RULE_MUTATION = <<~GRAPHQL
  mutation UpdateHostConfigurationRuleEnabled($id: ID!, $enabled: Boolean) {
    updateHostConfigurationRule(
      input: {
        id: $id
        patch: { enabled: $enabled }
      }
    ) {
      rule {
        ...HostConfigurationRuleDetailsFragment
      }
    }
  }

  fragment HostConfigurationRuleDetailsFragment on HostConfigurationRule {
    id
    externalId
    name
    description
    enabled
    builtin
    shortName
    hasMissingPrerequisite
    prerequisite

    matchers {
      ...HostConfigurationRuleMatchersFragment
    }

    targetOperatingSystems {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    targetWorkloadTypes

    targetTechnologies {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    excludedTechnologies {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    tags {
      key
      value
    }

    severity

    securitySubCategories {
      ...SecuritySubCategoriesDetails
    }

    remediationInstructions

    analytics {
      errorCount
      failCount
      notAssessedCount
      passCount
      totalCount
    }

    projects {
      id
      name
    }
  }

  fragment HostConfigurationRuleMatchersFragment on HostConfigurationRuleMatchers {
    workloadScanner {
      enabled
      description
      ovalDefinition
    }

    dynamicScanner {
      enabled
      description
      nucleiTemplate
    }
  }

  fragment SecuritySubCategoriesDetails on SecuritySubCategory {
    id
    title
    description
    resolutionRecommendation

    category {
      id
      name
      framework {
        id
        name
        enabled
      }
    }
  }
GRAPHQL


TOGGLE_CONTROL_MUTATION = <<~GRAPHQL
  mutation ToggleControl($controlId: ID!, $patch: UpdateControlPatch!) {
    updateControl(input: { id: $controlId, patch: $patch }) {
      control {
        id
        enabled
        enabledForLBI
        enabledForMBI
        enabledForHBI
        enabledForUnattributed
      }
    }
  }
GRAPHQL

MANAGE_CONTROLS_QUERY = <<~GRAPHQL
  query ManageControlsTable(
    $first: Int = 500,
    $after: String,
    $filterBy: ControlFilters,
    $orderBy: ControlOrder,
    $issueAnalyticsSelection: ControlIssueAnalyticsSelection
  ) {
    controls(
      filterBy: $filterBy,
      first: $first,
      after: $after,
      orderBy: $orderBy
    ) {
      nodes {
        id
        name
        description
        type
        severity
        query
        enabled
        lastRunAt
        lastSuccessfulRunAt
        lastRunError
        supportsNRT
        originalControlOverridden
        resolutionRecommendation
        scopeQuery
        validatedAsExploitable
        serviceTickets { ...ControlServiceTicket }
        scopeProject { id name }
        sourceCloudConfigurationRule { id name }
        risks
        threats
        securitySubCategories {
          id
          title
          description
          category {
            id
            name
            framework { id name enabled }
          }
        }
        enabledForLBI
        enabledForMBI
        enabledForHBI
        enabledForUnattributed
        createdBy { id name email }
        issueAnalytics(selection: $issueAnalyticsSelection) {
          issueCount
        }
        tagsV2 { key value }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
      totalCount
    }
  }

  fragment ControlServiceTicket on ServiceTicket {
    id
    externalId
    name
    url
    project { id name }
    integration {
      id
      type
      name
      typeConfiguration {
        type
        iconUrl
      }
    }
  }
GRAPHQL


CREATE_CONTROL_MUTATION = <<~GRAPHQL
  mutation CreateControl($input: CreateControlInput!) {
    createControl(input: $input) {
      control {
        id
        name
        description
        securitySubCategories { id title }
        resolutionRecommendation
      }
    }
  }
GRAPHQL

CREATE_SECURITY_FRAMEWORK_MUTATION = <<~GRAPHQL
  mutation CreateSecurityFramework($input: CreateSecurityFrameworkInput!) {
    createSecurityFramework(input: $input) {
      framework {
        id
        enabled
      }
    }
  }
GRAPHQL


LOAD_SECURITY_FRAMEWORK_QUERY = <<~GRAPHQL
  query LoadSecurityFrameworkForEditing($id: ID!) {
    securityFramework(id: $id) {
      ...SecurityFrameworkFragment

      categories {
        subCategories {
          tags {
            key
            value
          }

          controls(first: 2000) {
            nodes {
              id
              sourceCloudConfigurationRule {
                id
              }
            }
          }

          cloudConfigurationRules(first: 2000) {
            nodes {
              id
            }
          }

          hostConfigurationRules(first: 2000) {
            nodes {
              id
            }
          }
        }
      }
    }
  }

  fragment SecurityFrameworkFragment on SecurityFramework {
    id
    name
    description
    builtin
    enabled

    parentFramework {
      id
      name
    }

    project {
      id
      name
      slug
      isFolder
    }

    cloudConfigurationRules(first: 2000) {
      totalCount
      nodes {
        id
      }
    }

    hostConfigurationRules(first: 2000) {
      totalCount
      nodes {
        id
      }
    }

    controls(first: 2000, filterBy: { type: [SECURITY_GRAPH] }) {
      totalCount
      enabledCount
      nodes {
        id
      }
    }

    categories {
      id
      name
      description

      parent {
        id
        name
      }

      subCategories {
        id
        title
        description

        parent {
          id
          title
        }
      }
    }
  }
GRAPHQL


HOST_CONFIGURATION_QUERY = <<~GRAPHQL
  query HostConfigurationRulesPage(
    $filterBy: HostConfigurationRuleFilters
    $first: Int
    $after: String
    $orderBy: HostConfigurationRuleOrder
  ) {
    hostConfigurationRules(
      filterBy: $filterBy
      first: $first
      after: $after
      orderBy: $orderBy
    ) {
      nodes {
        ...HostConfigurationRuleDetailsFragment
      }
      pageInfo {
        endCursor
        hasNextPage
      }
      totalCount
    }
  }

  fragment HostConfigurationRuleDetailsFragment on HostConfigurationRule {
    id
    externalId
    name
    description
    enabled
    builtin
    shortName
    hasMissingPrerequisite
    prerequisite

    matchers {
      ...HostConfigurationRuleMatchersFragment
    }

    targetOperatingSystems {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    targetWorkloadTypes

    targetTechnologies {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    excludedTechnologies {
      id
      version
      displayName
      technology {
        id
        name
        icon
        description
      }
    }

    tags {
      key
      value
    }

    severity

    securitySubCategories {
      ...SecuritySubCategoriesDetails
    }

    remediationInstructions

    analytics {
      errorCount
      failCount
      notAssessedCount
      passCount
      totalCount
    }

    projects {
      id
      name
    }
  }

  fragment HostConfigurationRuleMatchersFragment on HostConfigurationRuleMatchers {
    workloadScanner {
      enabled
      description
      ovalDefinition
    }

    dynamicScanner {
      enabled
      description
      nucleiTemplate
    }
  }

  fragment SecuritySubCategoriesDetails on SecuritySubCategory {
    id
    title
    description
    resolutionRecommendation

    category {
      id
      name
      framework {
        id
        name
        enabled
      }
    }
  }
GRAPHQL


CLOUD_CONFIG_QUERY = <<~GRAPHQL
  query CloudConfigurationSettingsTable(
    $first: Int,
    $after: String,
    $filterBy: CloudConfigurationRuleFilters,
    $orderBy: CloudConfigurationRuleOrder,
    $projectId: [String!]
  ) {
    cloudConfigurationRules(
      first: $first
      after: $after
      filterBy: $filterBy
      orderBy: $orderBy
    ) {
      analyticsUpdatedAt
      nodes {
        id
        shortId
        name
        description
        enabled
        severity
        serviceType
        cloudProvider
        subjectEntityType
        functionAsControl
        opaPolicy
        builtin
        targetNativeTypes
        remediationInstructions
        hasAutoRemediation
        supportsNRT
        createdAt
        updatedAt
        originalConfigurationRuleOverridden
        control { id }
        iacMatchers {
          id
          type
          regoCode
          parameters {
            ... on CloudConfigurationRuleAdmissionControllerMatcherParameters {
              operation
            }
          }
        }
        matcherTypes
        risks
        threats
        securitySubCategories {
          id
          title
          description
          category {
            id
            name
            description
            framework {
              id
              name
              enabled
            }
          }
        }
        analytics(selection: { projectId: $projectId }) {
          passCount
          failCount
        }
        iacAnalytics(selection: { projectId: $projectId }) {
          analytics {
            platform
            totalFindingsCount
          }
        }
        scopeAccounts { id name cloudProvider }
        scopeProject { id name slug isFolder }
        tags { key value }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
GRAPHQL