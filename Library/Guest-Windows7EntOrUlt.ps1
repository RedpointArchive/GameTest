param([string] $GuestName, [string] $Target, [string] $CredentialsFile)

$ErrorActionPreference = "Stop"
$DidVMRestore = $False
trap
{
    Write-Error $_
    if (!$DidVMRestore) {
        try {
            Write-Output "Restoring VM from snapshot..."
            $VM = Get-VM -Name $GuestName
            Restore-VMSnapshot -VM $VM -Name $Target -Confirm:$False
        } catch {}
    }
    exit 1
}

if ($Target -eq "Baseline") {
    $Snapshot = "Baseline"
} else {
    $Snapshot = "ReadyToRun"
}

Set-Location $PSScriptRoot

Import-Module Hyper-V

$VM = Get-VM -Name $GuestName

taskkill /f /im mstsc.exe

Write-Output "Restoring VM from snapshot..."
Restore-VMSnapshot -VM $VM -Name $Snapshot -Confirm:$False
Write-Output "Starting VM..."
Start-VM -VM $VM -Confirm:$False

$HasCreatedRDPSession = $False
$RDPProcess = $Null
try {
    $LoginCredentials = New-Object System.Management.Automation.PSCredential("qa" , (ConvertTo-SecureString "qa" -AsPlainText -Force));

    Write-Output "Waiting for the network adapter to be assigned an IP address..."
    $IsConnected = $False
    $Stopwatch = [Diagnostics.StopWatch]::StartNew()
    $Timeout = New-TimeSpan -Minutes 5
    while (!$IsConnected -and $Stopwatch.elapsed -lt $Timeout) {
        $NetworkAdapter = Get-VMNetworkAdapter -IsLegacy $False -VM $VM
        if ($NetworkAdapter.MacAddress -eq $Null) {
            Write-Host "Network adapter does not have MAC address assigned, waiting..."
            Start-Sleep -Seconds 1
            continue;
        }

        if (((Get-VMNetworkAdapter -IsLegacy $False -VM $VM).IpAddresses).Length -eq 0) {
            Write-Host "Network adapter has no IP addresses, waiting..."
            Start-Sleep -Seconds 1
            continue;
        }

        $IpAddresses = ((Get-VMNetworkAdapter -IsLegacy $False -VM $VM).IpAddresses)
        $HasIpV4Address = $False
        $IpV4Address = $Null
        foreach ($IpAddress in $IpAddresses) {
            try {
                if (([ipaddress]$IpAddress).AddressFamily -eq "InterNetwork") {
                    $HasIpV4Address = $True
                    $IpV4Address = $IpAddress
                    break
                }
            } catch {
            }
        }

        if (!$HasIpV4Address) {
            Write-Host "Network adapter has no IPv4 address, waiting..."
            Start-Sleep -Seconds 1
            continue;
        }

        Write-Output "Attempting to connect via PowerShell ($IpV4Address)..."
        try {
            $Result = Invoke-Command -ComputerName $IpV4Address -Credential $LoginCredentials -ScriptBlock {
                Write-Output "Connected via PowerShell"
            }
            if ($Result -eq "Connected via PowerShell") {
                $IsConnected = $True
            } else {
                Write-Output "Output from PowerShell didn't match expected result, waiting..."
                Start-Sleep -Seconds 1
                continue;
            }
        } catch {
            Write-Output "Unable to connect to the machine over PowerShell, waiting..."
            Start-Sleep -Seconds 1
            continue;
        }
    }

    if (!$IsConnected) {
        Write-Output "Timed out while trying to get a connection to the VM."
        exit 1
    }

    if ($Target -eq "Baseline") {
        Write-Output "Baseline test passed: VM is connected and ready."
        exit 0
    }

    if ($Target -eq "ReadyToRun") {
        Write-Output "Checking that AutoIt3 is available..."
        try {
            $Result = Invoke-Command -ComputerName $IpV4Address -Credential $LoginCredentials -ScriptBlock {
                $ErrorActionPreference = "Stop"
                Import-Module "C:\Program Files (x86)\AutoIt3\AutoItX\AutoItX.psd1"
                Write-Output "AutoItX Imported"
            }
            if ($Result -eq "AutoItX Imported") {
                $IsConnected = $True
            } else {
                Write-Output "Unable to import AutoIt3 PowerShell scripts on remote host."
                exit 1
            }
        } catch {
            Write-Output "Unable to import AutoIt3 PowerShell scripts on remote host."
            exit 1
        }
        Write-Output "AutoIt3 is installed correctly."
        exit 0
    }

    Write-Output "Writing test file..."
    Set-Content -Path "Content-Win7\Test.ps1" -Value "exit 0" # TODO

    if (Test-Path $CredentialsFile) {
        Write-Output "Copying credentials file..."
        Copy-Item $CredentialsFile "Content-Win7\Credentials.ps1"
    }

    Write-Output "Copying content to virtual machine..."
    foreach ($file in (Get-ChildItem -Path Content-Win7)) {
        Write-Output ("Copying " + $file.Name + "...")
        Copy-VMFile -VM $VM -SourcePath $file.FullName -DestinationPath ("C:\Content-Win7\" + $file.Name) -FileSource Host -CreateFullPath
    }

    Write-Output "Enabling configuration for PSExec..."
    try {
        Invoke-Command -ComputerName $IpV4Address -Credential $LoginCredentials -ScriptBlock {
            try { net share admin$ } catch {}
            try { net share IPC$ } catch {}
            try { net share c$=C:\ } catch {}
            try { net stop server } catch {}
            try { net start server } catch {}
            try { netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes } catch {}
            try { netsh advfirewall set currentprofile state on } catch {}
        }
    } catch {}

    Write-Output "Mapping remote C:\ drive to PowerShell Y:\ drive..."
    New-PSDrive -Name Y -PSProvider filesystem -Root \\$IpV4Address\C$ -Credential $LoginCredentials

    Write-Output "Starting Remote Desktop to enable RemoteFX..."
    cmdkey /generic:$IpV4Address /user:QA /pass:qa
    $RDPProcess = Start-Process -FilePath C:\Windows\System32\mstsc.exe -ArgumentList @("/v:$Ipv4Address", "/admin", "/w:1024", "/h:768")
    $HasCreatedRDPSession = $True
    Start-Sleep -Seconds 5

    Write-Output "Running tests via PSExec..."
    $PSExecProcess = Start-Process -FilePath ..\PSExec\PSExec.exe -ArgumentList @(
        "-accepteula",
        "-nobanner",
        "\\$IpV4Address",
        "-u",
        "qa",
        "-p",
        "qa",
        "-i",
        "1",
        "-h",
        "C:\Windows\system32\windowspowershell\v1.0\powershell.exe",
        "-ExecutionPolicy",
        "Bypass",
        "C:\Content-Win7\Start.ps1"
    )

    if (Test-Path ..\Screenshots) {
        Remove-Item -Recurse -Force ..\Screenshots
    }
    if (!(Test-Path ..\Screenshots)) {
        mkdir ..\Screenshots
    }

    Write-Output "Monitoring PSExec and showing transcript data.."
    $Stopwatch = [Diagnostics.StopWatch]::StartNew()
    $Timeout = New-TimeSpan -Minutes 60
    $TranscriptPosition = 0
    do {
        if (!(Test-Path Y:\Output-Win7)) {
            Write-Output "No Output-Win7 directory, script hasn't started yet..."
            Start-Sleep -Seconds 1
            continue
        }

        foreach ($screenshot in (Get-Item Y:\Output-Win7).GetFiles("Screenshot*.png")) {
            if (!(Test-Path ("..\Screenshots\" + $screenshot.Name))) {
                Write-Output "Copying screenshot $($screenshot.Name)..."
                Copy-Item -Force ("Y:\Output-Win7\" + $screenshot.Name) ("..\Screenshots\" + $screenshot.Name)
                Copy-Item -Force ("Y:\Output-Win7\" + $screenshot.Name) ("..\Screenshots\ScreenshotLatest.png")
            }
        }

        if (Test-Path "Y:\Output-Win7\Transcript.log") {
            $Content = Get-Content -Raw "Y:\Output-Win7\Transcript.log"
            if ($TranscriptPosition -lt $Content.Length) {
                $Substr = $Content.Substring($TranscriptPosition)
                $TranscriptPosition += $Substr.Length
                [Console]::Out.Write($Substr)
            }

            if ($Content.Contains("Windows PowerShell Transcript End")) {
                break;
            }
        }

        Start-Sleep -Seconds 1
    } while ((!$PSExecProcess.HasExited -and $Stopwatch.elapsed -lt $Timeout))
     
    taskkill /f /im mstsc.exe
    $HasCreatedRDPSession = $False
    Write-Output "Test run complete with exit code $($PSExecProcess.ExitCode)."

    exit $PSExecProcess.ExitCode
} finally {
    $DidVMRestore = $True
    try {
        Write-Output "Restoring VM from snapshot..."
        $VM = Get-VM -Name $GuestName
        Restore-VMSnapshot -VM $VM -Name $Target -Confirm:$False
    } catch {}
    if ($HasCreatedRDPSession) {
        taskkill /f /im mstsc.exe
    }
}