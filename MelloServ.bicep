// uniqueString() only returns 13 characters, and sometimes we have to truncate it
// We MAY still have naming collisions, because nothing is guaranteed in life
// So we make it a parameter so that in those extreme cases, you can override it
@description('This parameter is normally auto-calculated and you should not pass it.')
var uniqueNameString = uniqueString(resourceGroup().id)

var componentName = 'MelloServInfrastructure'

// NOTE: Cannot use sharednames.output.environmentCode for all uses
var environmentCode = any(last(split(subscription().displayName, '-')))

var isLowerEnvironment = contains(['dv1','qa1'], sharedNames.outputs.environmentCode)
var servicingGroupId = '32abfe40-58c6-4606-a048-e5b620127d0b'
var paymentEngineGroupId = 'bda4ac20-40d4-44e5-9fc2-369dea81e2be'

// For subdeployments, prefix our name (which is hopefully unique)
// By convention, all subdeployments are named '${deploymentName}Filename'
var deploymentName = deployment().name

// In order to use the OUTPUT of naming to name things, everything has to be in a module
// That way the name is a parameter, and thus "resolveable at deployment start"
module names 'br/lookups:names:7.0' = {
  name: '${deploymentName}__names'
  params: {
    baseName: componentName
    uniqueNameString: uniqueNameString
  }
}

module sharedNames 'br/lookups:sharednames:1.2' = {
  name: '${deploymentName}_sharedNames'
  params: {
    uniqueNameString: uniqueNameString
  }
}

module aksCluster 'br/lookups:akscluster:1' = {
  name: '${deploymentName}__cluster'
}

module keyVault'br/resources:keyvault:6' = {
  name: '${deploymentName}_keyvault'
  params:{
    name: names.outputs.keyVaultName
    privateEndpointSubnetName:'${sharedNames.outputs.subnetPrefix}-Shared'
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
  }
}

module keyVaultRole 'br/resources:resourceroleassignment:1.0.2' = {
  name: '${deploymentName}__keyVaultRole'
  params: {
    principalIds: [sharedNames.outputs.adoDvoSpnId]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Administrator'
  }
}

module sharedServiceBusKVLoad 'br/resources:servicebuskvload:3.0.1' = {
  name: '${deploymentName}_sharedKeyVaultLoad'
  params: {
    keyVaultName: names.outputs.keyVaultName
    serviceBusName: 'sb-melloserv-shared-services-${names.outputs.environmentCode}-azusw2'
    serviceBusPolicyName: 'RootManageSharedAccessKey'
    serviceBusResourceGroup: 'rg-azusw2-dvo-${names.outputs.environmentCode}-melloserv-shared-services'
  }
}

// Load sedm Service Bus connection string
module sedmIdsServiceBusKVLoad 'br/resources:servicebuskvload:3.0.0' = {
  name: '${deploymentName}_sedmAsbKeyVaultLoad'
  params: {
    keyVaultName: names.outputs.keyVaultName    
    serviceBusName: 'sb-sedmintegration-azusw2-dvo-${sharedNames.outputs.environmentCode}'
    serviceBusPolicyName: 'RootManageSharedAccessKey'
    serviceBusResourceGroup: 'rg-sedm-azusw2-dvo-${sharedNames.outputs.environmentCode}'
  }
}

 
output keyVaultName string = names.outputs.keyVaultName

////////////////////////////////////////////////////// Function Apps //////////////////////////////////////////////////////

module functionAppInfo 'br/lookups:funcappplan:2.2.1' = {
  name: '${deploymentName}__functionappInfo'
  params: {
    environment: names.outputs.environmentCode
  }
}

////////////////// LD.MelloServ.BKFS.Integration.Function //////////////////

var bkfsIntegrationComponentName = 'MSBKFSIntegration'

module bkfsIntegrationNames 'br/lookups:names:7.0' = {
  name: '${deploymentName}__bkfsIntegrationNames'
  params: {
    baseName: bkfsIntegrationComponentName
    uniqueNameString: uniqueNameString
  }
}

module bkfsIntegrationfunctionApp 'br/resources:functionapp:6.2' = {
  name: 'bkfs'
  params: {
    name: bkfsIntegrationNames.outputs.functionAppName
    appServicePlanNameResourceID: functionAppInfo.outputs.appServiceResourceID
    virtualNetworkResourceID: functionAppInfo.outputs.virtualNetworkResourceID
    funcStorageAccountName: bkfsIntegrationNames.outputs.functionAppStorageAccount
    functionsExtensionVersion: '~4'
    functionsWorkerRuntime:'dotnet-isolated'
    enableVnetRouteAll: true
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    vNetName: sharedNames.outputs.sharedVNetName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
  }
}

module bkfsIntKeyVaultRole 'br/resources:resourceroleassignment:1.0.2' = {
  name: '${deploymentName}__bkfsIntKeyVaultRole'
  params: {
    principalIds: [bkfsIntegrationfunctionApp.outputs.principalId]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Secrets User'
  }
}

////////////////// PortalInboxMessageHandlerFunction //////////////////

var portalInboxMessageHandlerFunctionComponentName = 'MSPortalInbox'

module portalInboxMessageHandlerFunctionNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}_pimhNames'
  params: {
    baseName: portalInboxMessageHandlerFunctionComponentName
    uniqueNameString: uniqueNameString
  }
}

module portalInboxMessageHandlerFunctionfunctionApp 'br/resources:functionapp:6.2' = {
  name: 'pimh'
  params: {
    name: portalInboxMessageHandlerFunctionNames.outputs.functionAppName
    appServicePlanNameResourceID: functionAppInfo.outputs.appServiceResourceID
    virtualNetworkResourceID: functionAppInfo.outputs.virtualNetworkResourceID
    funcStorageAccountName: portalInboxMessageHandlerFunctionNames.outputs.functionAppStorageAccount
    functionsExtensionVersion: '~3'
    functionsWorkerRuntime:'dotnet'
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    vNetName: sharedNames.outputs.sharedVNetName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
  }
}

module portalInboxKeyVaultRole 'br/resources:resourceroleassignment:1.0.2' = {
  name: '${deploymentName}__portalInboxKeyVaultRole'
  params: {
    principalIds: [portalInboxMessageHandlerFunctionfunctionApp.outputs.principalId]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Secrets User'
  }
}

////////////////////////////////////////////////////// App Services //////////////////////////////////////////////////////

////////////////// ServicingLINCPortal.Escrow //////////////////

var lincEscrowComponentName = 'ServicingLINCPortalEscrow'

module lincEscrowNames 'br/lookups:names:7.0' = {
  name: '${deploymentName}__LENames'
  params: {
    baseName: lincEscrowComponentName
    uniqueNameString: uniqueNameString
  }
}

module appService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LEAppService'
  params: {
    name: lincEscrowNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    healthCheckPath: 'api/v1/ServicingLINCPortalLoans/HealthCheck'
  }
}

////////////////// ServicingLINCPortal.Search //////////////////

var lincSearchComponentName = 'ServicingLINCPortalSearch'

module lincSearchNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LSNames'
  params: {
    baseName: lincSearchComponentName
    uniqueNameString: uniqueNameString
  }
}

module lsAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LSAppService'
  params: {
    name: lincSearchNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    healthCheckPath: 'api/v1/ServicingLINCPortalIntegration/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.Borrowers //////////////////

var lincBorrowersComponentName = 'ServicingLINCPortalBorrowers'

module lincBorrowersNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LBNames'
  params: {
    baseName: lincBorrowersComponentName
    uniqueNameString: uniqueNameString
  }
}

module lbAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LBAppService'
  params: {
    name: lincBorrowersNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortal/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.Loans //////////////////

var lincLoansComponentName = 'ServicingLINCPortalLoans'

module lincLoansNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LLoansNames'
  params: {
    baseName: lincLoansComponentName
    uniqueNameString: uniqueNameString
  }
}

module llAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LLoansAppService'
  params: {
    name: lincLoansNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    healthCheckPath: 'api/v1/ServicingLINCPortal/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.Notes //////////////////

var lincNotesComponentName = 'ServicingLINCPortalNotes'

module lincNotesNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LNotesNames'
  params: {
    baseName: lincNotesComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincNotesAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LNotesAppService'
  params: {
    name: lincNotesNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortalIntegration/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.Notifications //////////////////

var lincNotificationsComponentName = 'ServicingLINCPortalNotifications'

module lincNotificationsNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LNotificationsNames'
  params: {
    baseName: lincNotificationsComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincNotificationsAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LNotificationsAppService'
  params: {
    name: lincNotificationsNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortalIntegration/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.Tasks //////////////////

var lincTasksComponentName = 'ServicingLINCPortalTasks'

module lincTasksNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LTasksNames'
  params: {
    baseName: lincTasksComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincTasksAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LTasksAppService'
  params: {
    name: lincTasksNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortal/HealthCheck'
  }
}


////////////////// ServicingLINCPortal.ThirdParty //////////////////

var lincThirdPartyComponentName = 'ServicingLINCPortalThirdParty'

module lincThirdPartyNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LThirdPartyNames'
  params: {
    baseName: lincThirdPartyComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincThirdPartyAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LThirdPartyAppService'
  params: {
    name: lincThirdPartyNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortalIntegration/HealthCheck'
  }
}

////////////////// ServicingLINCPortal.Audit //////////////////

var lincAuditComponentName = 'ServicingLINCPortalAudit'

module lincAuditNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LAuditNames'
  params: {
    baseName: lincAuditComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincAuditAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LAuditAppService'
  params: {
    name: lincAuditNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    healthCheckPath: 'api/v1/ServicingLINCPortal/HealthCheck'
  }
}

////////////////// ServicingLINCPortal.Payments //////////////////

var lincPaymentsComponentName = 'ServicingLINCPortalPayments'

module lincPaymentsNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__LPaymentsNames'
  params: {
    baseName: lincPaymentsComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincPaymentsAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LPaymentsAppService'
  params: {
    name: lincPaymentsNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    healthCheckPath: 'api/v1/ServicingLINCPortalIntegration/HealthCheck'
  }
}
    
////////////////// ServicingLINCPortal.BKFSIntegration //////////////////

var lincBkfsIntComponentName = 'ServicingLINCPortalBKFSIntegration'

module lincBkfsIntNames 'br/lookups:names:7.0' = {
  name: '${deploymentName}__LBkfsNames'
  params: {
    baseName: lincBkfsIntComponentName
    uniqueNameString: uniqueNameString
  }
}

module lincBkfsIntAppService 'br/resources:appservice:5.1' = {
  name: '${deploymentName}__LBkfsAppService'
  params: {
    name: lincBkfsIntNames.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
    keyVaultName: names.outputs.keyVaultName
    enableVnetRouteAll: true
    healthCheckPath: 'api/v1/ServicingLINCPortalIntergration/HealthCheck'
  }
}

////////////////// AKS //////////////////

// Grant key vault read access to AKS
module aksGrantRbac 'br/resources:resourceroleassignment:1' = {
  name: '${deploymentName}_aksKvRbac'
  params: {
    principalIds: [
        aksCluster.outputs.kubeletIdentityObjectId
    ]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Secrets User'
  }
}

////////////////// Service Bus //////////////////

var melloServComponentName = 'melloserv'

module melloServNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__msNames'
  params: {
    baseName: melloServComponentName
  }
}

module serviceBus 'br/resources:servicebus:4.1.1' = {
  name: '${deploymentName}__melloServServiceBus'
  params: {
    name: melloServNames.outputs.serviceBusName
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Azure Service Bus Data Owner'
        principalIds: union([uaIdentity.outputs.userAssignedIdentityPrincipalId], isLowerEnvironment ? [servicingGroupId] : [])
      }
      {
        roleDefinitionIdOrName: 'Azure Service Bus Data Sender'
        principalIds: union([peLoanValiOrchFunctionApp.identity.principalId, sharedNames.outputs.adoDvoSpnId], isLowerEnvironment ? [paymentEngineGroupId] : [])
      }      
    ]
  }
}

////////////////// Notifications Consumer (AKS) //////////////////

// UAI for payment notification consumer
module uaIdentity 'br/resources:userassignedidentity:2.1.0' = {
  name: '${deploymentName}__UAI'
  params: {
    name: names.outputs.userAssignedIdentityName
    azureADTokenExchangeFederatedIdentityCredentials: {
      '${aksCluster.outputs.oidcIssuerUrl}': 'system:serviceaccount:melloserv:notifications-consumer-service-account'
    }
  }
}

// PaymentEngine function lookup for giving SB Sender role
resource peLoanValiOrchFunctionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: 'func-peloanvaliorch-azusw2-dvo-${environmentCode}'
  scope: resourceGroup('rg-PaymentEngine-azusw2-dvo-${toUpper(environmentCode)}')
}

////////////////// Agent Portal Domain (AKS) //////////////////

var agentPortalBaseName = 'agentportaldomain'
module agentPortalNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__apdNames'
  params: {
    baseName: agentPortalBaseName
  }
}

module agentPortalDomainUaIdentity 'br/resources:userassignedidentity:2.1.0' = {
  name: '${deploymentName}__apdUAI'
  params: {
    name: agentPortalNames.outputs.userAssignedIdentityName
    azureADTokenExchangeFederatedIdentityCredentials: {
      '${aksCluster.outputs.oidcIssuerUrl}': 'system:serviceaccount:melloserv:agentportaldomain-workload-identity'
    }
  }
}

////////////////// Servis Bot (AKS) //////////////////

var servisBotApiBaseName = 'servisbotapi'
module servisBotApiNames 'br/lookups:names:7.0.9' = {
  name: '${deploymentName}__sbaNames'
  params: {
    baseName: servisBotApiBaseName
  }
}


module servisBotApiUaIdentity 'br/resources:userassignedidentity:2.1.0' = {
  name: '${deploymentName}__sbaUAI'
  params: {
    name: servisBotApiNames.outputs.userAssignedIdentityName
    azureADTokenExchangeFederatedIdentityCredentials: {
      '${aksCluster.outputs.oidcIssuerUrl}': 'system:serviceaccount:melloserv:servisbotapi-workload-identity'
    }
  }
}
