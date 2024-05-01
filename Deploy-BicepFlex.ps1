[CmdletBinding()]
param (
    # Azure Location
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [ValidateScript({
            $Allowed = 'centralus', 'eastus', 'eastus2', 'northcentralus', 'southcentralus', 'westcentralus', 'westus', 'westus2', 'westus3'
            if ($_ -notin $Allowed) {
                Write-Output "##vso[task.logissue type=error;]Invalid value '$_' for template parameter 'Location'. Should be in $Allowed"
                Write-Output "##vso[task.complete result=Failed;]"
                throw
            }
            return $true
        })]
    [string]$Location,

    # Stage Name
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [ValidateScript({
            $Allowed = 'DV1', 'QA1', 'SG1', 'HF1', 'TN1', 'RPRD', 'SL1'
            if ($_ -notin $Allowed) {
                Write-Output "##vso[task.logissue type=error;]Invalid value '$_' for template parameter 'Environment'. Should be in $Allowed"
                Write-Output "##vso[task.complete result=Failed;]"
                throw
            }
            return $true
        })]
    [string]$Environment,

    # The Product Name to deploy
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [ValidateScript({
            if (!$_) {
                Write-Output "##vso[task.logissue type=error;]Missing template parameter 'Name'"
                Write-Output "##vso[task.complete result=Failed;]"
                throw
            }
            return $true
        })]
    [string]$Name,

    # CostCenter tag
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [ValidateScript({
            if (!$_) {
                Write-Output "##vso[task.logissue type=error;]Missing template parameter 'CostCenter'"
                Write-Output "##vso[task.complete result=Failed;]"
                throw
            }
            return $true
        })]
    [string]$CostCenter,

    # Support Owner (defaults to "DevOps")
    [ValidateScript({
            $Allowed = 'DevOps', 'Infrastructure'
            if ($_ -notin $Allowed) {
                Write-Output "##vso[task.logissue type=error;]Invalid value '$_' for template parameter 'SupportOwner'. Should be in $Allowed"
                Write-Output "##vso[task.complete result=Failed;]"
                throw
            }
            return $true
        })]
    [string]$SupportOwner = 'DevOps',

    # Deployment mode (defaults to 'Incremental', can be 'Complete')
    [ValidateSet('Incremental', 'Complete')]
    [string]$Mode = 'Incremental'
)

$DataCenterLookup = @{
    'centralus'      = 'azusc1'
    'eastus'         = 'azuse1'
    'eastus2'        = 'azuse2'
    'northcentralus' = 'azusnc'
    'southcentralus' = 'azussc'
    'westcentralus'  = 'azuswc'
    'westus'         = 'azusw1'
    'westus2'        = 'azusw2'
    'westus3'        = 'azusw3'
}
$Tags = @{
    Environment  = $Environment
    CostCenter   = $CostCenter
    SupportGroup = $SupportOwner
    BuildNumber  = $ENV:BUILD_BUILDNUMBER
    BuildURI     = $ENV:BUILD_BUILDURI
}
# This is AzureEnvironment object for BicepFlex
$AzureEnvironment = [PSCustomObject]@{
    Name             = $DataCenterLookup[$Location]
    Type             = $Environment
    Location         = $Location
    Owner            = $SupportOwner
    SubscriptionName = (Get-AzContext).Subscription.Name #BicepFlex just uses whatever Azure Service Connection is
}
if ($Mode -eq 'Complete') {
    # Complete mode is not working for most of our deployments.
    Write-Warning "Complete Deployments will not complete successfully if any of resources have Private Endpoints."
}
$BicepFlexArguments = @{
    LocalSourcePath  = $Pwd
    Name             = $Name
    AzureEnvironment = $AzureEnvironment
    Tags             = $Tags
    Mode             = $Mode
    Verbose          = $true
}
$Deployment = Deploy-BicepFlex @BicepFlexArguments
$Deployment | Out-String

# Convert deployment outputs to pipeline task variables
($Deployment.Outputs | ConvertTo-Json -Depth 99 | ConvertFrom-Json).PSObject.Properties.Foreach({
    $Name,$Value = $_.Name,$_.Value
    $Value = if ($Value.Type -in 'array','object') {
        "'"+($Value.Value | ConvertTo-Json -Depth 99 -Compress)+"'"
    } else { $Value.Value }
    Write-Host "Setting pipeline variable '$Name' to '$Value'"
    Write-Host "##vso[task.setvariable variable=$Name;isOutput=true]$Value"
})