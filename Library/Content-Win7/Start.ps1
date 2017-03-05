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

if ([string]::IsNullOrEmpty($SteamAppId)) {
    Write-Error "Unable to continue - no SteamAppId set.  Configure a CredentialsFile and pass to GameTest."
    exit 1
}

if ([string]::IsNullOrEmpty($SteamTargetPath)) {
    Write-Error "Unable to continue - no SteamTargetPath set.  Configure a CredentialsFile and pass to GameTest."
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

Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "Launching Steam..."
Invoke-AU3Run -Program "C:\Program Files (x86)\Steam\Steam.exe"

# Handle the "Create Account or Login" screen
Write-Output "Waiting for Steam create/login window to open..."
Wait-AU3Win -Title "Steam"
Start-Sleep -Seconds 1
Write-Output "Moving Steam create/login window to top-left of screen..."
Move-AU3Win -X 0 -Y 0 -Title "Steam"
Start-Sleep -Seconds 2
Write-Output "Bringing Steam create/login window to focus..."
Invoke-AU3MouseClick -X 5 -Y 5
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Start-Sleep -Seconds 1
Write-Output "Clicking 'Login with an existing account'..."
Invoke-AU3MouseClick -X 211 -Y 335

# Handle the login screen
Write-Output "Waiting for Steam login window to open..."
Wait-AU3Win -Title "Steam Login"
Start-Sleep -Seconds 1
Write-Output "Moving Steam login window to top-left of screen..."
Move-AU3Win -X 0 -Y 0 -Title "Steam Login"
Start-Sleep -Seconds 1
Write-Output "Bringing Steam login window to focus..."
Invoke-AU3MouseClick -X 5 -Y 5
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Start-Sleep -Seconds 1
Write-Output "Clicking on username field..."
Invoke-AU3MouseClick -X 130 -Y 95
Start-Sleep -Seconds 1
Write-Output "Typing in username..."
Send-AU3Key -Key $SteamUsername
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Clicking on password field..."
Invoke-AU3MouseClick -X 130 -Y 134
Start-Sleep -Seconds 1
Write-Output "Typing in password..."
Send-AU3Key -Key $SteamPassword
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Checking 'Remember Me'..."
Invoke-AU3MouseClick -X 123 -Y 162 # Tick Remember Me
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Clicking 'Login'..."
Invoke-AU3MouseClick -X 144 -Y 193 # and click Login!

Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "Waiting a little bit before relaunching Steam to get UI to appear..."
for ($i = 0; $i -lt 30; $i += 5) {
    Start-Sleep -Seconds 5
    Write-Output "Taking a screenshot..."
    Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
}

# This will cause the main window to appear.
Invoke-AU3Run -Program "C:\Program Files (x86)\Steam\Steam.exe"

Write-Output "Waiting for Steam main window to open..."
Wait-AU3Win -Title "Steam"
Start-Sleep -Seconds 1
Write-Output "Maximizing Steam window..."
Set-AU3WinState -Title "Steam" -Flags 3 # 3 = maximized
Start-Sleep -Seconds 1
Write-Output "Focusing on Steam window..."
Show-AU3WinActivate -Title "Steam"
Start-Sleep -Seconds 1

<#
Write-Output "Closing any Steam Guard prompt..."
Invoke-AU3MouseClick -X 999 -Y 114
Start-Sleep -Seconds 2

Write-Output "Searching for $SteamAppName..."
Invoke-AU3MouseClick -X 43 -Y 86
Start-Sleep -Seconds 1
Send-AU3Key -Key $SteamAppName
Start-Sleep -Seconds 1

Write-Output "Clicking on app..."
Invoke-AU3MouseClick -X 24 -Y 115 -Button Right
Start-Sleep -Seconds 1

Write-Output "Clicking on Properties..."
Invoke-AU3MouseClick -X 43 -Y 374
Start-Sleep -Seconds 1

Write-Output "Waiting for Properties window to appear..."
Wait-AU3Win -Title "$SteamAppName - Properties"
Start-Sleep -Seconds 1
Write-Output "Moving properties window to top-left of screen..."
Move-AU3Win -X 0 -Y 0 -Title "$SteamAppName - Properties"
Start-Sleep -Seconds 1

Write-Output "Clicking on Betas tab..."
Invoke-AU3MouseClick -X 318 -Y 40
Start-Sleep -Seconds 1

Write-Output "Entering beta access code..."
Invoke-AU3MouseClick -X 45 -Y 178
Start-Sleep -Seconds 1

################################

#>

Write-Output "Requesting installation of app $SteamAppId"
Start-Process steam://install/$SteamAppId

Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "Waiting for installation window to appear..."
Wait-AU3Win -Title "Install"
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Focusing on installation window..."
Show-AU3WinActivate -Title "Install"
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Moving installation window to top-left of screen..."
Move-AU3Win -X 0 -Y 0 -Title "Install"
Start-Sleep -Seconds 1
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
Write-Output "Clicking Next..."
Invoke-AU3MouseClick -X 317 -Y 374
Start-Sleep -Seconds 2
Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "Steam will now install the app.  Once the app has installed, we'll close the installation window and request Steam run the app."

while (!(Test-Path $SteamTargetPath)) {
    [Console]::Write(".")
    Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
    Start-Sleep -Seconds 10
}

Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "The target file now exists."
Write-Output "Closing installation window..."
Invoke-AU3MouseClick -X 417 -Y 374
Start-Sleep -Seconds 2

Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

<#
Write-Output "Exiting Steam so we can switch to any necessary app channel..."
& "C:\Program Files (x86)\Steam\Steam.exe" -shutdown

Write-Output "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Write-Output "Updating user config to opt into '$SteamAppChannel' channel..."
$lines = (Get-Content "C:\Program Files (x86)\Steam\steamapps\appmanifest_$SteamAppId.acf")
$new_lines = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
    $new_lines += $lines[$i];
    if ($lines[$i].Contains("language")) {
        $new_lines += "`t`t`"betakey`"`t`"$SteamAppChannel`""
    }
}
Set-Content -Path "C:\Program Files (x86)\Steam\steamapps\appmanifest_$SteamAppId.acf" -Value $new_lines
#>

Write-Output "Requesting Steam start app $SteamAppId"
Start-Process steam://run/$SteamAppId

Write-Output "Taking a screenshot..."
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

Write-Output "Your application now has 15 minutes to start (allowing for redist installs) and write a file to $SteamAlivePath."
Write-Output "If nothing appears within that time, we'll assume the app did not start correctly on the target platform."

$Stopwatch = [Diagnostics.StopWatch]::StartNew()
$Timeout = New-TimeSpan -Minutes 15
while (!(Test-Path $SteamAlivePath) -and $Stopwatch.elapsed -lt $Timeout) {
    [Console]::Write(".")
    Start-Sleep -Seconds 30
}

Write-Output "Waiting 10 seconds and then taking a screenshot."
Start-Sleep -Seconds 10
Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"

if (!(Test-Path $SteamAlivePath)) {
    Write-Output "$SteamAlivePath didn't appear within 5 minutes.  Assuming app start failure!"
    Write-Output "Taking a screenshot..."
    Take-Screenshot -Path "C:\Output-Win7\ScreenshotLatest.png"
    exit 1
}

Write-Output "App is running, starting test script..."
if (Test-Path C:\Content-Win7\Test.ps1) {
    C:\Content-Win7\Test.ps1
    if ($LastExitCode -ne 0) {
        Write-Output "Test script reported failure!"
        exit 1
    }
}

Write-Output "Test script reported failure!"

exit 0