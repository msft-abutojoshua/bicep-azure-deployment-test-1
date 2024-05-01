[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [int]$WaitSeconds
)

Start-Sleep -Seconds $WaitSeconds
