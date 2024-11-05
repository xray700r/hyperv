#!powershell
# WANT_JSON
# POWERSHELL_COMMON

$params = Parse-Args $args;
$result = @{};
#$results = @{};
Set-Attr $result "changed" $false;

$name = Get-Attr -obj $params -name name -failifempty $true -emptyattributefailmessage "missing required argument: name"
$memory = Get-Attr -obj $params -name memory -default '512MB'
$hostserver = Get-Attr -obj $params -name hostserver
$generation = Get-Attr -obj $params -name generation -default 2
$network_switch = Get-Attr -obj $params -name network_switch -default $null
$vmpath = Get-Attr -obj $params -name vmpath -default $null
$diskpath = Get-Attr -obj $params -name diskpath -default $null
$showlog = Get-Attr -obj $params -name showlog -default "false" | ConvertTo-Bool
$state = Get-Attr -obj $params -name state -default "present"
$cpu = Get-Attr -obj $params -name cpu -default '1'
$cpu_reserve = Get-Attr -obj $params -name cpu_reserve -default '0'
$cpu_maximum = Get-Attr -obj $params -name cpu_maximum -default '100'
$cpu_relative_wg = Get-Attr -obj $params -name cpu_relative_wg -default '100'
$ram = Get-Attr -obj $params -name ram -default '1'
$ram_dynam = Get-Attr -obj $params -name ram_dynamic -default 'False'
$ram_dynamic = [System.Convert]::ToBoolean($ram_dynam)
$ram_minimum = Get-Attr -obj $params -name ram_minimum -default '1'
$ram_maximum = Get-Attr -obj $params -name ram_maximum -default '8'
$ram_priority = Get-Attr -obj $params -name ram_priority -default '80'
$ram_buffer = Get-Attr -obj $params -name ram_buffer -default '25'

if ("present", "absent", "started", "stopped", "provisioned", "connected", "memorymod" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent, started, stopped, provisioned or connected"
}

function VMRamAvailable($VMname) {

    $CompObject = Get-WmiObject -Class WIN32_OperatingSystem
    
    $FreeMemory = ( % { [Math]::Round(($CompObject.FreePhysicalMemory / 1KB), 2) }) -as [double]
    $RAMresult = $False
    
    Try {
        $VMMemory = $(Get-VMMemory $VMname -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Startup)
        
        if ([string]::IsNullOrWhiteSpace($VMMemory) -or [string]::IsNullOrEmpty($VMMemory)) { Write-Warning "No VM Memory data OR not existing VM!" }
        else { $VMMemory = ( % { [Math]::Round(($VMMemory / 1MB), 2) } ) -as [double] }
    
    }
    Catch {
    
        Write-Error $PSItem.Exception.Message
    }
    Finally {
        Write-Warning "Completed RAM check for: $VMname"
    }
    
    if ([double]$VMMemory -gt ([double]$FreeMemory - 2048)) {
        $RAMresult = $False
        Write-Warning "No RAM available for this VM!" 
    }
    else {
        $RAMresult = $True
    }

    return $RAMresult

}

function VMRemoveSaved($VM_name) {

    
    $snapshotresult = $(Get-VMSnapshot -VMName $VM_name -ErrorAction SilentlyContinue)

    if ($null -ne $snapshotresult) {

    
        Try {
            Get-VMSnapshot $VM_name | Remove-VMSavedState
        }
        Catch { Write-Warning $PSItem.Exception.Message }
    

    }

}

Function VM-Create {
    #Check If the VM already exists
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if (!$CheckVM) {
        $cmd = "New-VM -Name $name -BootDevice VHD"

        if ($memory) {
            $cmd += " -MemoryStartupBytes $memory"
        }

        if ($hostserver) {
            $cmd += " -ComputerName $hostserver"
        }

        if ($generation) {
            $cmd += " -Generation $generation"
        }

        if ($network_switch) {
            $cmd += " -SwitchName '$network_switch'"
        }

        if ($vmpath) {
            $cmd += " -Path $vmpath"
        }
        
        if ($diskpath) {
            #If VHD already exists then attach it, if not create it
            if (Test-Path $diskpath) {
                $cmd += " -VHDPath '$diskpath'"
            }
            else {
                $cmd += " -NewVHDPath '$diskpath'"
            }
        }
        

        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Function VM-Delete {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if ($CheckVM) {
        $cmd = "Remove-VM -Name $name -Force"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Function VM-Start {
    $CheckVMstarted = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Running" }
    $CheckVMstopped = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" }
    $CheckVMsaved = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Saved" }

    if ($CheckVMstarted) { "Status is already running for VM: $name" }
    elseif ($CheckVMstopped -and (VMRamAvailable($name))) {
        $cmd = "Start-VM -Name $name"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    elseif ($CheckVMsaved -and (VMRamAvailable($name))) {
 
        VMRemoveSaved $name
        $cmd = "Start-VM -Name $name"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        Fail-Json $result "The VM: $name; Doesn't exist, it is not in a START/STOP state OR RAM not available for it to start! Please check details in you VMM HyperV!"
    }
}

Function VM-Shutdown {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" -or $_.State -eq "Running" }

    if ($CheckVM) {
        $cmd = "Stop-VM -Name $name"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        Fail-Json $result "The VM: $name; Doesn't exist please create the VM first"
    }
}

Function VM-NetConn {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" -or $_.State -eq "Running" }
    
    if ($CheckVM) {
        $cmd = "Get-VM $name | Get-VMNetworkAdapter | select -ExpandProperty MacAddress"
        $results = invoke-expression $cmd
        if ($results -eq "000000000000") {
            $result.changed = $false 
        }
        else { $result.changed = $true }

    }
    else {
        $result.changed = "vmnotexisting"
    }
}

Function VM-ModCPU {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" }

    if ($CheckVM) {
        $cmd = "Set-VMProcessor $name"
        if ($cpu) {
            #If cpu number is not null

            if ($cpu) {
                $cmd += " -Count $cpu"
            }
    
            if ($cpu_maximum) {
                $cmd += " -Maximum $cpu_maximum"
            }
    
            if ($cpu_reserve) {
                $cmd += " -Reserve $cpu_reserve"
            }
    
            if ($cpu_relative_wg) {
                $cmd += " -RelativeWeight $cpu_relative_wg"
            }
            

            $results = invoke-expression $cmd
            $result.changed = $true
        }
        else {
            Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
        }
    }

}
Function VM-ModRAM {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" }
    
    if ($CheckVM) {
        $cmd = "Set-VMMemory $name"
        if ($ram) {
            #If cpu number is not null

            if ($ram) {
                $cmd += " -StartupBytes $ram"
            }
    
            if ($true -eq $ram_dynamic) {
                $cmd += " -DynamicMemoryEnabled $ram_dynamic"            
    
                if ($ram_minimum) {
                    $cmd += " -MinimumBytes $ram_minimum"
                }
    
                if ($ram_maximum) {
                    $cmd += " -MaximumBytes $ram_maximum"
                }
                if ($ram_priority) {
                    $cmd += " -Priority $ram_priority"
                }
                if ($ram_buffer) {
                    $cmd += " -Buffer $ram_buffer"
                }
            }

            $results = invoke-expression $cmd
            $result.changed = $true
        }
        else {
            Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
        }
    }

}

Try {
    switch ($state) {
        "present" { VM-Create }
        "absent" { VM-Delete }
        "started" { VM-Start }
        "stopped" { VM-Shutdown }
        "provisioned" { VM-ModCPU }
        "connected" { VM-NetConn }
        "memorymod" { VM-ModRAM }
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}
