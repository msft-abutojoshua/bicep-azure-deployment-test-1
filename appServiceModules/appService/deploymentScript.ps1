[CmdletBinding()]
param(
    # App Service name
    [string]$AppServiceName,

    # Resource Group name
    [string]$ResourceGroupName
)
try {
    $appSettings = (Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName).SiteConfig.AppSettings
    if ($appSettings) {
        $DeploymentScriptOutputs['AppSettings'] = [System.Linq.Enumerable]::ToDictionary(
            [PSObject[]]($appSettings),
            [Func[PSObject,String]] { $args[0].Name },
            [Func[PSObject,String]] { $args[0].Value })
    } else {
        $DeploymentScriptOutputs['AppSettings'] = @{}
    }
} catch {
    Write-Warning "Unable to retrieve App Service settings: $($_)"
}
