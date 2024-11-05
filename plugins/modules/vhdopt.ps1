#!powershell


$Host.PrivateData.VerboseForegroundColor = 'Cyan'

function VMOPTresult($VMname) {

    $OPTresult = $False
    
    Try {
        $VMsize = $(Measure-VM $VMname -ErrorAction SilentlyContinue | Select-Object -ExpandProperty TotalDisk)
        
        if ([string]::IsNullOrWhiteSpace($VMsize) -or [string]::IsNullOrEmpty($VMsize)) { Write-Warning "No VM Disk Size data OR not existing VM!" }
        else { $VMsize = ( % { [Math]::Round(($VMsize / 1KB), 2) } ) -as [double] }
        
        if ([double]$VMsize -eq 0) {

            Write-Warning "Maximum size provisioned for VM: $VMname isn't defined correctly or it is zero!"

        }
        else {

            Write-Verbose "Maximum size provisioned for VM is: $VMsize"  -Verbose 
        }

    }
    Catch {
    
        Write-Error $PSItem.Exception.Message
    }
    Finally {
        Write-Verbose "Completed Size check for: $VMname"  -Verbose
    }


    if ([double]$VMsize -gt ([double]$(VMVHDsize($VMname)) * 1.1)) {
        $OPTresult = $False
    }
    else {
        $OPTresult = $True
    }

    return $OPTresult

}

function VMVHDsize($VMname) {
    $VHDsizes = @(Get-VM -VMName $VMname | Select-Object VMId | Get-VHD | select-object -ExpandProperty filesize)

    [double]$TotalVHDsize = '0';
    foreach ( $disksize in $VHDsizes ) { $TotalVHDsize += [double]$disksize }
    $TotalVHDsize = ( % { [Math]::Round(($TotalVHDsize / 1GB), 2) } ) -as [double]

    return $TotalVHDsize

}

function OptimizeVHDx {
    param([string] $VMTarget)

    Write-Warning "VM optimization started!"

    $VHDpath = $(Get-VM -VMName $VMTarget | Select-Object VMId | Get-VHD | Select-Object -ExpandProperty Path)

    foreach ($vhdpath in $VHDpath) {
        Mount-VHD -Path $VHDpath -ReadOnly

        Try {
            Optimize-VHD -Path $VHDpath -Mode Full
        }
        Catch {
    
            Write-Error $PSItem.Exception.Message
        }
        Finally {
        
            if ([string]::IsNullOrWhiteSpace($PSItem.Exception.Message) -or [string]::IsNullOrEmpty($PSItem.Exception.Message)) { Write-Warning "Not possible optimization for: $VMTarget ; It is ither a Linux or Unknown type filesystem!" }
            else { Write-Warning "Optimization successful for: $VMTarget!" }

        }




        Start-Sleep -s 5
        Dismount-VHD $VHDpath
    }

    Write-Warning "VM optimization finished!"


}

function ManageOptimization {
    param([string] $name)
    
    $CheckVMstopped = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" }
    

    $CheckVMstarted = Get-VM -name $name -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Running" }

    if ($CheckVMstopped) {
        Write-Verbose "Actual size used on filesystem for VM is: $(VMVHDsize($name)) GB"  -Verbose
    
    
        if ($(VMOPTresult($name))) {

            Write-Warning "This VM needs optimization or more HDD space! It's at the last 10% of provisioned space left"

            OptimizeVHDx($name);

        }
    

    }
    elseif ($CheckVMstarted) {
        Write-Warning "This VM is started and can't be optimized right now!"
        
    }
    else { Write-Warning "This VM has a status different than started or stopped; can't optimize right now!" }

}


$VMlist = $(Get-VM -name "*" -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Off" } | select-object -ExpandProperty Name)

foreach ($VMobject in $VMlist) {

    Write-Output "Started Optimization process for: $VMobject"

    ManageOptimization($VMobject);

    Write-Output "Finished Optimization process for: $VMobject"

    Write-Output "**********************************************"

}