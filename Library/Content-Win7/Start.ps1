$ErrorActionPreference = "Stop"
trap
{
    Write-Error $_
    Stop-Transcript
    exit 1
}

if (!(Test-Path "C:\Output-Win7")) {
    mkdir "C:\Output-Win7"
}
Start-Transcript -Path "C:\Output-Win7\Transcript.log"

Import-Module "C:\Program Files (x86)\AutoIt3\AutoItX\AutoItX.psd1"
Write-Output "AutoItX Imported"

$_PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Set-Location $_PSScriptRoot

if (Test-Path Credentials.ps1) {
    . .\Credentials.ps1
}

if ([string]::IsNullOrEmpty($SteamUsername) -or [string]::IsNullOrEmpty($SteamPassword)) {
    Write-Error "Unable to continue - no SteamUsername or SteamPassword set.  Configure a CredentialsFile and pass to GameTest."
    exit 1
}

[Reflection.Assembly]::LoadWithPartialName("System.Drawing")
function Take-Screenshot($Path) {
    $bounds = [Drawing.Rectangle]::FromLTRB(0, 0, 1024, 768)
    $bmp = New-Object Drawing.Bitmap $bounds.width, $bounds.height
    $graphics = [Drawing.Graphics]::FromImage($bmp)

    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

    $bmp.Save($Path)

    $graphics.Dispose()
    $bmp.Dispose()
}

Take-Screenshot -Path "C:\Output-Win7\Screenshot01.png"

Write-Output "Launching Steam..."
Invoke-AU3Run -Program "C:\Program Files (x86)\Steam\Steam.exe"

# Handle the "Create Account or Login" screen
Wait-AU3Win -Title "Steam"
Start-Sleep -Seconds 1
Move-AU3Win -X 0 -Y 0 -Title "Steam"
Start-Sleep -Seconds 2
Invoke-AU3MouseClick -X 5 -Y 5
Take-Screenshot -Path "C:\Output-Win7\Screenshot02.png"
Start-Sleep -Seconds 1
Invoke-AU3MouseClick -X 211 -Y 335

# Handle the login screen
Wait-AU3Win -Title "Steam Login"
Start-Sleep -Seconds 1
Move-AU3Win -X 0 -Y 0 -Title "Steam Login"
Start-Sleep -Seconds 1
Invoke-AU3MouseClick -X 5 -Y 5
Take-Screenshot -Path "C:\Output-Win7\Screenshot03.png"
Start-Sleep -Seconds 1
Invoke-AU3MouseClick -X 130 -Y 95
Start-Sleep -Seconds 1
Send-AU3Key -Key $SteamUsername
Start-Sleep -Seconds 1
Take-Screenshot -Path "C:\Output-Win7\Screenshot04.png"
Invoke-AU3MouseClick -X 130 -Y 134
Start-Sleep -Seconds 1
Send-AU3Key -Key $SteamPassword
Start-Sleep -Seconds 1
Take-Screenshot -Path "C:\Output-Win7\Screenshot05.png"
Invoke-AU3MouseClick -X 123 -Y 162 # Tick Remember Me
Start-Sleep -Seconds 1
Take-Screenshot -Path "C:\Output-Win7\Screenshot06.png"
Invoke-AU3MouseClick -X 144 -Y 193 # and click Login!

Take-Screenshot -Path "C:\Output-Win7\Screenshot07.png"

Write-Output "Waiting a little bit before relaunching Steam to get UI to appear..."
Start-Sleep -Seconds 10

# This will cause the main window to appear.
Invoke-AU3Run -Program "C:\Program Files (x86)\Steam\Steam.exe"

exit 0