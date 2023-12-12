targetScope = 'subscription'

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
param roleDefinitionId string = ''
param principalId string = ''

var name_roleAssignmentName = guid('${subscription().id}${principalId}Role assignment in subscription scope')

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@${apiVersionForRoleDefinitions}' existing = {
  name: roleDefinitionId
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = {
  name: name_roleAssignmentName
  properties: {
    description: 'Assign subscription scope role to User Assigned Managed Identity '
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
