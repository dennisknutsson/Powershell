<#
.Synopsis
   Disable Eject i virtual enviroment
.DESCRIPTION
   Long description
.EXAMPLE
   Run as SYSTEM account or it will fail.
.EXAMPLE
   Another example of how to use this cmdlet
#>
$stopwatch = [System.Diagnostics.Stopwatch]::startNew()
#Sleep
#Start-Sleep -s 60
CLS
#VMXNET3
$netpath=@(Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Enum\PCI -Recurse|ForEach-Object {Get-ItemProperty -Path $_.PsPath|where {$_.DeviceDesc -like "*vmxnet3*"}})
#$netpath.PSPath
Set-Itemproperty -Path $netpath.PSPath -name Capabilities -Value "2" -Type DWord

#LSI default 6
$diskpath=@(Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Enum\PCI -Recurse|ForEach-Object {Get-ItemProperty -Path $_.PsPath|where {$_.DeviceDesc -like "*LSI Adapter*"}})
#$diskpath.PSPath
Set-Itemproperty -Path $diskpath.PSPath -name Capabilities -Value "2" -Type DWord

#ACHI default 6
$diskpath2=@(Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Enum\PCIIDE\IDEChannel -Recurse|ForEach-Object {Get-ItemProperty -Path $_.PsPath|where {$_.DeviceDesc -like "*IDE-kanal*"}})
#$diskpath.PSPath
Set-Itemproperty -Path $diskpath2.PSPath -name Capabilities -Value "2" -Type DWord

#Standard AHCI Controller default 6
$diskpath3=@(Get-ChildItem -path HKLM:\SYSTEM\CurrentControlSet\Enum\PCIIDE\IDEChannel -Recurse|ForEach-Object {Get-ItemProperty -Path $_.PsPath|where {$_.DeviceDesc -like "*Standard AHCI*"}})
#$diskpath.PSPath
Set-Itemproperty -Path $diskpath3.PSPath -name Capabilities -Value "2" -Type DWord

$stopwatch.Stop()

$sec=(($stopwatch.Elapsed).Seconds).ToString()
$msec=(($stopwatch.Elapsed).Milliseconds).ToString()
$result=($sec+","+$msec)
$result


