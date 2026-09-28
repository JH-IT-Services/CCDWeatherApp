param location string = resourceGroup().location
param environmentName string

resource managedEnvironment 'Microsoft.App/managedEnvironments@2026-07-01' = {
  name: environmentName
  location: location
  tags: resourceGroup().tags
  properties: {
    environmentMode: 'WorkloadProfiles'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

output id string = managedEnvironment.id
output name string = managedEnvironment.name
