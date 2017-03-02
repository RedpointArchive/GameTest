param([string] $GuestName, [string] $Target, [string] $CredentialsFile)

$ErrorActionPreference = "Stop"
$DidVMRestore = $False
trap
{
    Write-Error $_
    if (!$DidVMRestore) {
        try {
            Write-Output "Restoring VM from snapshot..."
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

Write-Output "Restoring VM from snapshot..."
Restore-VMSnapshot -VM $VM -Name $Snapshot -Confirm:$False
Write-Output "Starting VM..."
Start-VM -VM $VM -Confirm:$False

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

        if (((Get-VMNetworkAdapter -IsLegacy $False -VM $VM).Status) -ne "Ok") {
            Write-Host "Network adapter is not in Ok status, waiting..."
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
    Invoke-Command -ComputerName $IpV4Address -Credential $LoginCredentials -ScriptBlock {
        net share admin$
        net share IPC$
        net share c$=C:\
        net stop server
        net start server
        netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
        netsh advfirewall set currentprofile state on
    }

    Write-Output "Running tests via PSExec..."
    ..\PSExec\PSExec.exe -accepteula -nobanner \\$IpV4Address -u qa -p qa -i -h "C:\Windows\system32\windowspowershell\v1.0\powershell.exe" -ExecutionPolicy Bypass "C:\Content-Win7\Start.ps1"
    exit $LastExitCode
} finally {
    $DidVMRestore = $True
    try {
        Write-Output "Restoring VM from snapshot..."
        Restore-VMSnapshot -VM $VM -Name $Target -Confirm:$False
    } catch {}
}