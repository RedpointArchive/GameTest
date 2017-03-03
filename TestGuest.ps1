param([string] $GuestType, [string] $GuestName)

$ErrorActionPreference = "Stop"
trap
{
    Write-Error $_
    exit 1
}

Set-Location $PSScriptRoot

if ($GuestType -eq "Windows7EntOrUlt") {
    .\Library\Guest-Windows7EntOrUlt.ps1 -GuestName $GuestName -Target "Baseline"
} else {
    throw "Unsupported guest type.  Supported guest types are: 'Windows7EntOrUlt'."
}