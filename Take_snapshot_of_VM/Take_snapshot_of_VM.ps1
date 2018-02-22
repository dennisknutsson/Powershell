#***************************************************************************
#
# Add NFS Storage to All Hosts of a chosen cluster.
# Author: Dennis Knutsson
# Date: 2013-10-25
#
#***************************************************************************
CLS
if($global:DefaultVIServers.Count -lt 1)
{
	echo "We need to connect first"
	#To connect using predefined username-password
	#Connect-VIServer $login_host -User $login_user -Password $login_pwd -AllLinked:$true

	#To connect using PowerCLI credential store
	#Connect-VIServer $login_host -AllLinked:$true

    # vCenter Credentials
    $cred= get-credential -Message "Enter your login to vCenter:"

    $vCenter = "<change_me>"
    [void](Connect-VIServer $vCenter -Credential $cred )
    #Connect-VIServer $vCenter | Out-Null
    Clear-Host
    
}
else
{
    Clear-Host
	echo "Already connected"
}

Write-Host

$GoldenImageNameStart = "VDI0000"

$vms = @(Get-VM |Where-Object {$_.name.StartsWith($GoldenImageNameStart)}| Sort Name)
#$vms = @(Get-VM |Where {$_.Name -like "VDI000*"}| Sort Name)
if($vms.count -gt 1){

     for($vmCount=0;$vmCount -lt $vms.count; $vmCount++){
             $optionvalue = $vmCount + 1
                     Write-Host $optionvalue "=" $vms[$vmCount].Name
                     
     }
     Write-Host
     $input = Read-Host "Vilken VM?"
     $selectedvm = $vms[$input-1]
}
else{
    $selectedvm = $vms[0]
    
}

$vmName = $selectedvm.Name
IF (((Get-VM -Name $vmName).PowerState) -eq "PoweredOff") {
    $date = Get-Date -UFormat "%Y%m%d"
    $time = Get-Date -UFormat "%H%M"
    $snapshotname = $selectedvm.Name+"_"+$date+"_"+$time
    Write-Host "Snapshotnamn blir:" $snapshotname
    #$snapdesc="test"
    $snapdesc = Read-Host -Prompt 'Beskriv vad du gjort'
    #Write-Host $snapshotname $snapdesc 
    New-Snapshot -VM $vmName -Name $snapshotname -Description $snapdesc
} ELSE {Write-Host $vmName "Not Powered off, Please power off to avoid errors"}

Write-Host
Disconnect-VIServer -Force
Write-Host "Script finished..." -foregroundcolor Green
