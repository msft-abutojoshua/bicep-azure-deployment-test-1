@description('Required. Name of the app service to be deployed')
param name string

// This can be either the azure location, or our internal datacenter name
@description('Optional. The location is used to select a "datacenter". Defaults to the resourceGroup location.')
param location string = resourceGroup().location

@description('Optional. Tags for the appService and storage. Defaults to the resourceGroup tags')
param tags object = resourceGroup().tags

@description('Required. ResourceId of app service plan for the app service app being deployed')
param appServicePlanNameResourceID string

@description('Required. ResourceId of the subnet the app service being deployed will join')
param virtualNetworkSubnetId string

@description('Optional. Version of the dotnet runtime to use. Defaults to 6.0')
param dotNetFrameworkVersion string = '6.0'

@description('Required. The dynatrace tenant/environment id')
@secure() // is secure so we can assign to it from the keyvault
param dynatraceTenant string

@description('Required. The dynatrace API Token')
@secure()
param dynatraceApiToken string

@description('Optional. Allow injecting additional app settings, will be merged with defaults')
param additionalAppSettings object = {}

@description('Optional. Drives whether OS specific components are deployed for a app service.')
param appServicePlanKind string = 'windows'

@description('Optional. Specify kind of appservice, example: functionapp')
@allowed([
  'app'
  'functionapp'
  'functionapp,linux'
])
param appServiceKind string = 'app'

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

@description('Generated. UTC timestamp for deployment script.')
param currentTime string = utcNow()

@description('Optional. Provide unique deployment name for the module references. Defaults to take(deploymentName().name, 25)')
@maxLength(25)
param deploymentName string = take(deployment().name, 25)

var applications = union(
  {
    '/': 'site\\wwwroot'
  }, virtualApplications
)

// convert hashtable to virtualApplications object
var virtualApps = [for app in items(applications): {
  virtualPath: app.key
  physicalPath: app.value
  preloadEnabled: false
}]

// convert an array of IDs into a userAssignedIdentities object
var _ids = [for id in userAssignedIdentityIds: '\'${id}\': {}']
var _idString = replace(replace(string(_ids), '"', ''), '\'', '"')
// Remove the array syntax [...]
// And wrap it in object syntax { }
var _identityJson = '{ ${replace(replace(_idString, '[', ''), ']', '')} }'
// And parse it into the userAssignedIdentities property
var identity = empty(userAssignedIdentityIds) ? {
  type: 'SystemAssigned'
} : {
  type: 'SystemAssigned,UserAssigned'
  userAssignedIdentities: json(_identityJson)
}
var numberOfWorkers = (bool(appServicePlanKind == 'windows')) ? -1 : 1

var defaultAppsettings = {
  DT_TENANT: dynatraceTenant
  DT_API_TOKEN: dynatraceApiToken
  DT_SSL_MODE: 'default'
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: appServiceKind
  identity: identity
  properties: {
    vnetRouteAllEnabled: enableVnetRouteAll
    enabled: true
    hostNameSslStates: [
      {
        name: '${name}.azurewebsites.net'
        hostType: 'Standard'
      }
      {
        name: '${name}.scm.azurewebsites.net'
        hostType: 'Repository'
      }
    ]
    serverFarmId: appServicePlanNameResourceID
    siteConfig: {
      healthCheckPath: healthCheckPath
      numberOfWorkers: numberOfWorkers
      acrUseManagedIdentityCreds: false
      alwaysOn: enableAlwaysOn
      http20Enabled: false
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      netFrameworkVersion: dotNetFrameworkVersion
      linuxFxVersion: linuxFxVersion
      virtualApplications: virtualApps
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    storageAccountRequired: false
    virtualNetworkSubnetId: virtualNetworkSubnetId
    keyVaultReferenceIdentity: 'SystemAssigned'
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: union(defaultAppsettings, additionalAppSettings)
  }
}

resource webAppSlot 'Microsoft.Web/sites/slots@2022-09-01' = [for deploymentSlot in additionalDeploymentSlots: {
  name: deploymentSlot
  parent: appService
  location: location
  kind: appServiceKind
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${name}.azurewebsites.net'
        hostType: 'Standard'
      }
      {
        name: '${name}.scm.azurewebsites.net'
        hostType: 'Repository'
      }
    ]
    serverFarmId: appServicePlanNameResourceID
    siteConfig: {
      numberOfWorkers: numberOfWorkers
      acrUseManagedIdentityCreds: false
      alwaysOn: enableAlwaysOn
      http20Enabled: false
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      netFrameworkVersion: dotNetFrameworkVersion
      linuxFxVersion: linuxFxVersion
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
  }
}]

resource appSettings 'Microsoft.Web/sites/slots/config@2022-09-01' = [for index in range(0, length(additionalDeploymentSlots)): {
  name: 'appsettings'
  parent: webAppSlot[index]
  properties: union(defaultAppsettings, additionalAppSettings)
}]

module uaiIdentity '../userAssignedIdentity/userAssignedIdentity.bicep' = {
  name: '${deploymentName}_dsWaitUai${take(uniqueString(name),5)}'
  params: {
    name: 'uai-${name}-waitdeployment'
    roleDefinition: 'Contributor'
    location: location
  }
}

module wait '../deploymentScript/deploymentScript.bicep' = {
  name: '${deploymentName}_deployWait${take(uniqueString(name),5)}'
  params: {
    location: location
    name: 'wait_${name}'
    azPowerShellVersion: '10.0'
    scriptContent: loadTextContent('wait.ps1')
    scriptArguments: '120'
    userAssignedIdentityResourceID: uaiIdentity.outputs.id
    forceUpdateTag: currentTime
  }
}

resource dynatrace 'Microsoft.Web/sites/siteextensions@2022-09-01' = if (!empty(dynatraceTenant)) {
  parent: appService
  name: 'Dynatrace'
  dependsOn: [
    wait
    appService::appSettings
    appSettings
  ]
}

@description('The Resource Id of the App Service')
output id string = appService.id

@description('The Name of the App Service')
output name string = appService.name

@description('Id of the managed identity for the App Service Website')
output principalId string = appService.identity.principalId
