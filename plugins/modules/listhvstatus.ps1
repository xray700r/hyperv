#!powershell

# Example use: ./listhvstatus.ps1

Function GenerateFolder($path) {
    
    If (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path
    }
}


function ListHVStatus() {

param ([Parameter(Mandatory = $False, Position = 1)]
    [string[]] $savepath
)

if ( [string]::IsNullOrEmpty( $savepath ) ) {

    $currentscript = $(Get-Location)

    $savepath = "$currentscript\HVstatus"

    GenerateFolder $savepath

}
$hostid = $($(hostname) -replace '-','').ToLower()
$fpath="$savepath\$hostid"+"_vmstatus.yml"


$startyml="---"

$VMslistStarted = @(Get-VM | Where-Object {$_.State -eq "Running"} | Select-Object -ExpandProperty Name)
$vmstarted="vmstarted: ["
foreach ( $vmname in $VMslistStarted ){ $vmstarted+="'"+$vmname+"',"}
$vmstarted=$vmstarted.TrimEnd(",");
$vmstarted+="]"
Write-Host $vmstarted


Out-File -FilePath $fpath -InputObject $startyml -Encoding ASCII

if (Test-Path -Path $fpath -IsValid) {
Out-File -FilePath $fpath -InputObject $vmstarted -Encoding ASCII -Append
}

$VMslistStopped = @(Get-VM | Where-Object {$_.State -eq "Off"} | Select-Object -ExpandProperty Name)
$vmsstopped="vmstopped: ["
foreach ( $vmname in $VMslistStopped ){ $vmsstopped+="'"+$vmname+"',"}
$vmsstopped=$vmsstopped.TrimEnd(",");
$vmsstopped+="]"

if (Test-Path -Path $fpath -IsValid) {
Out-File -FilePath $fpath -InputObject $vmsstopped -Encoding ASCII -Append
}

}

ListHVStatus