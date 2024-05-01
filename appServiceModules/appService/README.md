# appService `[Resources/appService]`

Provides ability to deploy an Azure App Service, including preserving current App Settings applied outside of infrastructure deployment.

## Navigation

- [Versions](#versions)
- [Resource Types](#resource-types)
- [Parameters](#parameters)
- [Outputs](#outputs)
- [Examples](#examples)

## Versions

### 5.1.3

- Committed on 20231012
- Fix use of userAssignedIdentity output Id parameter (upstream breaking change)

### 5.1.2

- Bump version Azure PowerShell to v10, used by the wait deployment script.


### 5.1.1

- Add wait script to prevent Dynatrace Extension failures

### 5.1.0

- Bumping API version for resources
- Adding enableVnetRouteAll parameter, defaults to false

### 5.0.1

- Adjust logic to deploy dynatrace extension

### 5.0.0

> **NOTE** Requires your Key Vault is deployed with v6 of keyVault module (e.g., `br/resources:keyvault:6`)

- Convert Key Vault integration to RBAC

### 4.3.1

- Committed on 20230114
- add support for preserving AppSettings

### 4.3.0

- Committed on 20221130
- enabledAlwaysOn parameter added to support continuous WebJobs or WebJobs that are triggered using a CRON expression.

### 4.2.0

- Committed on 20221110
- virtual applications parameters is added

### 4.1.6

- Committed on 20221024
- sharedNames module update - sharedVNetName support for sb-azu-inf-pd-01 subscription

### 4.1.5

- Committed on 20221010
- Part of the bicep test readme verification example change.

### 4.1.4

- Removed minimumElasticInstanceCount and functionAppScaleLimit properties from site definition. See DOH-1077 for details.

### 4.1.3

- Committed on 20220926

### 4.1.2

- README generated on 20220722

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Authorization/roleAssignments` | [2020-08-01-preview](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Authorization/roleAssignments) |
| `Microsoft.Authorization/roleAssignments` | [2022-01-01-preview](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Authorization/roleAssignments) |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | [2018-11-30](https://docs.microsoft.com/en-us/azure/templates/Microsoft.ManagedIdentity/2018-11-30/userAssignedIdentities) |
| `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials` | [2023-01-31](https://docs.microsoft.com/en-us/azure/templates/Microsoft.ManagedIdentity/2023-01-31/userAssignedIdentities/federatedIdentityCredentials) |
| `Microsoft.Network/privateEndpoints` | [2021-02-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/2021-02-01/privateEndpoints) |
| `Microsoft.Network/privateEndpoints/privateDnsZoneGroups` | [2020-03-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/privateEndpoints/privateDnsZoneGroups) |
| `Microsoft.Resources/deploymentScripts` | [2020-10-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Resources/2020-10-01/deploymentScripts) |
| `Microsoft.Web/sites` | [2022-09-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Web/2022-09-01/sites) |
| `Microsoft.Web/sites/config` | [2022-09-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Web/sites) |
| `Microsoft.Web/sites/siteextensions` | [2022-09-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Web/2022-09-01/sites/siteextensions) |
| `Microsoft.Web/sites/slots` | [2022-09-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Web/2022-09-01/sites/slots) |
| `Microsoft.Web/sites/slots/config` | [2022-09-01](https://docs.microsoft.com/en-us/azure/templates/Microsoft.Web/sites) |

## Parameters

**Required parameters**
| Parameter Name | Type | Description |
| :-- | :-- | :-- |
| `appServicePlanName` | string | Resource Name of the app service plan where the app service will be deployed |
| `appServicePlanResourceGroup` | string | Resource Group Name of the app service plan where the app service will be deployed |
| `baseInfrastructureResourceGroupName` | string | Name of resource group which holds common deployment resources (keyvault, virtual network, etc) |
| `name` | string | Name of the app service to be deployed |
| `privateEndpointSubnetName` | string | Subnet name for the private endpoint link being deployed |
| `sharedDeploymentKeyVaultName` | string | Shared Deployment KeyVault: for Dynatrace config secrets |
| `sharedResourceGroupName` | string | The Shared ResourceGroup: where the shared KeyVault is |
| `vnetIntegrationSubnetName` | string | Subnet name inside of vNetName the app service will join |
| `vNetName` | string | Name of the vNet the app service will join |

**Optional parameters**
| Parameter Name | Type | Default Value | Description |
| :-- | :-- | :-- | :-- |
| `additionalAppSettings` | object | `{object}` | Allows adding App Settings. Will be merged with defaults |
| `additionalDeploymentSlots` | array | `[]` | Specify additional deployment slots to be added to app service |
| `deploymentName` | string | `[take(deployment().name, 42)]` | Provide unique deployment name for the module references. Defaults to take(deploymentName().name, 42) |
| `dotNetFrameworkVersion` | string | `'6.0'` | Version of the dotnet runtime to use. Default is 6.0 |
| `enableAlwaysOn` | bool | `False` | Enable Always On for the App Service. Always On is required for continuous WebJobs or for WebJobs that are triggered using a CRON expression. Defaults to false |
| `enableVnetRouteAll` | bool | `False` | Enable vnetRouteAllEnabled option of the Function App VNET integration. Default: false |
| `healthCheckPath` | string | `''` | Endpoint health check to ensure the app is running, typically by ld convention /version |
| `keyVaultName` | string | `''` | Name of a KeyVault to grant the app service access to. Default is none |
| `linuxFxVersion` | string | `''` | Specify linux FX version. Fox example: DOTNET|6.0 |
| `location` | string | `[resourceGroup().location]` | The azure location for the app service. Default is the resourceGroup location. |
| `tags` | object | `[resourceGroup().tags]` | Tags to apply to the app service. Default copies the tags from the resource group. |
| `userAssignedIdentityIds` | array | `[]` | User Assigned identities this service can authenticate as. You always have the SystemAssigned identity! |
| `virtualApplications` | object | `{object}` | Hashtable of {virtual path:physical path}<p>For example:<p>{<p>  '/event_wj':'site\\wwwroot\\App_Data\\jobs\\continuous\\event-sample'<p>} |

**Generated parameters**
| Parameter Name | Type | Default Value | Description |
| :-- | :-- | :-- | :-- |
| `currentTime` | string | `[utcNow()]` | Used to force Azure to run Deployment script every time. |


### Parameter Usage: `<ParameterPlaceholder>`

// TODO: Fill in Parameter usage

## Outputs

| Output Name | Type | Description |
| :-- | :-- | :-- |
| `id` | string | App Service Resource ID |
| `name` | string | App Service Name |
| `principalId` | string | App Service Principal ID |
| `vNetIntegration` | string | Subnet of the App Service |

## Examples

```bicep
module appService 'br/resources:appservice:5.1.3' = {
  name: '${deploymentName}_appser'
  params: {
    deploymentName: deploymentName
    location: location
    name: names.outputs.webAppName
    appServicePlanName: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanName
    appServicePlanResourceGroup: sharedNames.outputs.sharedAppServicePlans.Medium1.servicePlanResourceGroupName
    sharedDeploymentKeyVaultName: sharedNames.outputs.sharedDeploymentKeyVaultName
    sharedResourceGroupName: sharedNames.outputs.sharedResourceGroupName
    baseInfrastructureResourceGroupName: sharedNames.outputs.baseInfrastructureResourceGroupName
    vNetName: sharedNames.outputs.sharedVNetName
    vnetIntegrationSubnetName: sharedNames.outputs.sharedAppServiceSubnetName
    privateEndpointSubnetName: '${sharedNames.outputs.subnetPrefix}-Shared'
  }
}
```

Last DocuBot edit: 202209261140
