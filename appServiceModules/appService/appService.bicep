@description('Required. Name of the app service to be deployed')
param name string

@description('Optional. Tags to apply to the app service. Default copies the tags from the resource group.')
param tags object = resourceGroup().tags

@description('Required. Resource Name of the app service plan where the app service will be deployed')
param appServicePlanName string

@description('Required. Resource Group Name of the app service plan where the app service will be deployed')
param appServicePlanResourceGroup string

@description('Optional. Version of the dotnet runtime to use. Default is 6.0')
param dotNetFrameworkVersion string = '6.0'

@description('Optional. Name of a KeyVault to grant the app service access to. Default is none')
param keyVaultName string = ''

//Private Link Info
@description('Required. Name of resource group which holds common deployment resources (keyvault, virtual network, etc)')
param baseInfrastructureResourceGroupName string

@description('Required. Name of the vNet the app service will join')
param vNetName string

@description('Required. Subnet name for the private endpoint link being deployed')
param privateEndpointSubnetName string

@description('Required. Subnet name inside of vNetName the app service will join')
param vnetIntegrationSubnetName string

@description('Required. The Shared ResourceGroup: where the shared KeyVault is')
param sharedResourceGroupName string

@description('Required. Shared Deployment KeyVault: for Dynatrace config secrets')
param sharedDeploymentKeyVaultName string

@description('Optional. Allows adding App Settings. Will be merged with defaults')
param additionalAppSettings object = {}

@description('Optional. The azure location for the app service. Default is the resourceGroup location.')
param location string = resourceGroup().location

@description('Optional. Specify additional deployment slots to be added to app service')
param additionalDeploymentSlots array = []

@description('Optional. Specify linux FX version. Fox example: DOTNET|6.0')
param linuxFxVersion string = ''

@description('Optional. User Assigned identities this service can authenticate as. You always have the SystemAssigned identity!')
param userAssignedIdentityIds array = []

@description('Optional. Endpoint health check to ensure the app is running, typically by ld convention /version')
param healthCheckPath string = ''

@description('''Optional. Hashtable of {virtual path:physical path}
For example:
{
  '/event_wj':'site\\wwwroot\\App_Data\\jobs\\continuous\\event-sample'
}''')
param virtualApplications object = {}

@description('Optional. Enable Always On for the App Service. Always On is required for continuous WebJobs or for WebJobs that are triggered using a CRON expression. Defaults to false')
param enableAlwaysOn bool = false

@description('Optional. Enable vnetRouteAllEnabled option of the Function App VNET integration. Default: false')
param enableVnetRouteAll bool = false

@description('Optional. Provide unique deployment name for the module references. Defaults to take(deploymentName().name, 42)')
@maxLength(42)
param deploymentName string = take(deployment().name, 42)

@description('Generated. Used to force Azure to run Deployment script every time.')
param currentTime string = utcNow()

resource deploymentKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: sharedDeploymentKeyVaultName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: appServicePlanName
  scope: resourceGroup(appServicePlanResourceGroup)
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vNetName
  scope: resourceGroup(baseInfrastructureResourceGroupName)
  resource subnet 'subnets' existing = {
    name: vnetIntegrationSubnetName
  }
}

// Deployment Script to preserve current app settings if they exist
module uaiDeployScript '../userAssignedIdentity/userAssignedIdentity.bicep' = {
  name: '${deploymentName}_uaiDeployScript${take(uniqueString(location, deploymentName), 4)}'
  params: {
    name: 'uai-${name}-deployscript'
    location: location
    // Website Contributor role (no access to web site, only manager)
    roleDefinition: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772')
  }
}

module appServiceDeployScript '../deploymentScript/deploymentScript.bicep' = {
  name: '${deploymentName}_dsSaveSettings${take(uniqueString(location, deploymentName), 5)}'
  params: {
    name: '${name}_keepAppSettings'
    location: location
    azPowerShellVersion: '10.0'
    scriptContent: loadTextContent('deploymentScript.ps1')
    userAssignedIdentityResourceID: uaiDeployScript.outputs.id
    scriptArguments: '-AppServiceName ${name} -ResourceGroupName ${resourceGroup().name}'
    forceUpdateTag: currentTime
    retentionInterval: 'PT5H'
  }
}

// Nested the website because we need to pass it some secrets from the key vault
module appServiceWebsite 'appService.website.bicep' = {
  name: '${deploymentName}_website'
  params: {
    additionalAppSettings: union(appServiceDeployScript.outputs.deployScriptProperties.outputs.appSettings,additionalAppSettings)
    name: name
    location: location
    tags: tags
    enableVnetRouteAll: enableVnetRouteAll
    appServicePlanNameResourceID: appServicePlan.id
    virtualNetworkSubnetId: vnet::subnet.id
    dotNetFrameworkVersion: dotNetFrameworkVersion
    dynatraceApiToken: deploymentKeyVault.getSecret('DynatraceApiToken')
    dynatraceTenant: deploymentKeyVault.getSecret('DynatraceTenant')
    appServicePlanKind: appServicePlan.kind
    additionalDeploymentSlots: additionalDeploymentSlots
    linuxFxVersion: linuxFxVersion
    userAssignedIdentityIds: userAssignedIdentityIds
    healthCheckPath: healthCheckPath
    virtualApplications: virtualApplications
    enableAlwaysOn: enableAlwaysOn
  }
}

module privateEndpointLink '../privateEndpointLink/privateEndpointLink.bicep' = {
  name: '${deploymentName}_pe'
  params: {
    location: location
    baseInfrastructureResourceGroupName: baseInfrastructureResourceGroupName
    groupId: 'sites'
    privateEndpointName: 'pe-${name}'
    privateLinkServiceId: appServiceWebsite.outputs.id
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    subnetName: privateEndpointSubnetName
    vNetName: vNetName
    tags: tags
  }
}

module slotPrivateEndpoints '../privateEndpointLink/privateEndpointLink.bicep' = [for slot in additionalDeploymentSlots: {
  name: '${deploymentName}_spe${slot}'
  params: {
    location: location
    baseInfrastructureResourceGroupName: baseInfrastructureResourceGroupName
    groupId: 'sites-${slot}'
    privateEndpointName: 'pe-${name}-${slot}'
    privateLinkServiceId: appServiceWebsite.outputs.id
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    subnetName: privateEndpointSubnetName
    vNetName: vNetName
    tags: tags
  }
}]

module kvGrantSecretsUser '../resourceRoleAssignment/resourceRoleAssignment.bicep' = if (!empty(keyVaultName)) {
  name: '${deploymentName}_kvSecretUser'
  params: {
    principalIds: [
      appServiceWebsite.outputs.principalId
    ]
    resourceId: resourceId('Microsoft.KeyVault/vaults',keyVaultName)
    roleName: 'Key Vault Secrets User'
  }
}

@description('App Service Resource ID')
output id string = appServiceWebsite.outputs.id

@description('App Service Name')
output name string = appServiceWebsite.outputs.name

@description('Subnet of the App Service')
output vNetIntegration string = vnetIntegrationSubnetName

@description('App Service Principal ID')
output principalId string = appServiceWebsite.outputs.principalId
