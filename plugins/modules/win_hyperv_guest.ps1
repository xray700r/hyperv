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

    
    try { $snapshotresult = $(Get-VMSnapshot -VMName $VM_name -ErrorAction SilentlyContinue) }
    catch { Write-Warning $PSItem.Exception.Message }

    if ($null -ne $snapshotresult) {

    
        Try {
            Get-VMSnapshot $VM_name | Remove-VMSavedState
        }
        Catch { Write-Warning $PSItem.Exception.Message }
    

    }

}

Function VM-Create($name,$memory,$hostserver,$generation,$network_switch,$vmpath,$diskpath) {
    #Check If the VM already exists
    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue }
    catch { Write-Warning $PSItem.Exception.Message }

    if ([string]::IsNullOrEmpty($CheckVM)) {
        $cmd = "New-VM -Name $name -BootDevice VHD"

        if (-not [string]::IsNullOrEmpty($memory)) {
            $cmd += " -MemoryStartupBytes $memory"
        }

        if (-not [string]::IsNullOrEmpty($hostserver)) {
            $cmd += " -ComputerName $hostserver"
        }

        if (-not [string]::IsNullOrEmpty($generation)) {
            $cmd += " -Generation $generation"
        }

        if (-not [string]::IsNullOrEmpty($network_switch)) {
            $cmd += " -SwitchName '$network_switch'"
        }

        if (-not [string]::IsNullOrEmpty($vmpath)) {
            $cmd += " -Path $vmpath"
        }
        
        if (-not [string]::IsNullOrEmpty($diskpath)) {
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

Function VM-Delete($name) {
    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue }
    catch { Write-Warning $PSItem.Exception.Message }

    if (-not [string]::IsNullOrEmpty($CheckVM)) {
        $cmd = "Remove-VM -Name $name -Force"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Function VM-Start($name) {
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

Function VM-Shutdown($name) {
    
    
    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" -or $_.State -eq "Running" } }
    catch { Write-Warning $PSItem.Exception.Message }
    if (-not [string]::IsNullOrEmpty($CheckVM)) {
        $cmd = "Stop-VM -Name $name"
        $results = invoke-expression $cmd
        $result.changed = $true
    }
    else {
        Fail-Json $result "The VM: $name; Doesn't exist please create the VM first"
    }
}

Function VM-NetConn($name){

    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" -or $_.State -eq "Running" } }
    catch { Write-Warning $PSItem.Exception.Message }
    
    
    if (-not [string]::IsNullOrEmpty($CheckVM)) {
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

Function VM-ModCPU($name,$cpu,$cpu_maximum,$cpu_reserve,$cpu_relative_wg) {
    
    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" } }
    catch { Write-Warning $PSItem.Exception.Message }
    if (-not [string]::IsNullOrEmpty($CheckVM)) {
        $cmd = "Set-VMProcessor $name"
        if ($cpu) {
            #If cpu number is not null

            if (-not [string]::IsNullOrEmpty($cpu)) {
                $cmd += " -Count $cpu"
            }
    
            if (-not [string]::IsNullOrEmpty($cpu_maximum)) {
                $cmd += " -Maximum $cpu_maximum"
            }
    
            if (-not [string]::IsNullOrEmpty($cpu_reserve)) {
                $cmd += " -Reserve $cpu_reserve"
            }
    
            if (-not [string]::IsNullOrEmpty($cpu_relative_wg)) {
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
Function VM-ModRAM($name,$ram,$ram_dynamic,$ram_minimum,$ram_maximum,$ram_priority,$ram_buffer) {
    
    try { $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" } }
    catch { Write-Warning $PSItem.Exception.Message }
    if (-not [string]::IsNullOrEmpty($CheckVM)) {
        $cmd = "Set-VMMemory $name"
        if (-not [string]::IsNullOrEmpty($ram)) {
            #If ram quantity is not null

            if (-not [string]::IsNullOrEmpty($ram)) {
                $cmd += " -StartupBytes $ram"
            }
    
            if ($true -eq $ram_dynamic) {
                $cmd += " -DynamicMemoryEnabled $ram_dynamic"            
    
                if (-not [string]::IsNullOrEmpty($ram_minimum)) {
                    $cmd += " -MinimumBytes $ram_minimum"
                }
    
                if (-not [string]::IsNullOrEmpty($ram_maximum)) {
                    $cmd += " -MaximumBytes $ram_maximum"
                }
                if (-not [string]::IsNullOrEmpty($ram_priority)) {
                    $cmd += " -Priority $ram_priority"
                }
                if (-not [string]::IsNullOrEmpty($ram_buffer)) {
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
        "present" { VM-Create $name $memory $hostserver $generation $network_switch $vmpath $diskpath}
        "absent" { VM-Delete $name}
        "started" { VM-Start $name}
        "stopped" { VM-Shutdown $name}
        "cpumod" { VM-ModCPU $name $cpu $cpu_maximum $cpu_reserve $cpu_relative_wg}
        "connected" { VM-NetConn $name}
        "memorymod" { VM-ModRAM $name $ram $ram_dynamic $ram_minimum $ram_maximum $ram_priority $ram_buffer}
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}
