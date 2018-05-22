[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
$ofd = New-Object System.Windows.Forms.OpenFileDialog 
$ofd.InitialDirectory = "c:\" 
$ofd.ShowHelp=$true 
if($ofd.ShowDialog() -eq "OK") { $ofd.FileName } 
 
$colComputers = get-content $ofd.Filename 
 
$sname = read-host "Enter Service Name" 
 
foreach($strComputer in $colcomputers) 
{ 
$sa=(get-wmiobject -class win32_service -filter "name='$sname'" -computername $strComputer) 
write-host "$strComputer $sname Service Startup Type is" $svc.startmode "and is" $svc.state 
} 
 
$action = read-host "Specify a Startup Type [Auto|Manual|Disable]" 
 
foreach($strComputer in $colcomputers) 
{ 
$s = get-service $sname -computername $strComputer 
 
switch ($action) { 
"auto" {Set-service -inputobject $s -startuptype automatic} 
"manual" {Set-service -inputobject $s -startuptype manual} 
"disable" {Set-service -inputobject $s -startuptype disabled} 
} 
clear-host 
$svc = (get-wmiobject -class win32_service -filter "name='$sname'" -computername $strComputer) 
Write-Host "$strComputer $sname Service Startup Type is" $svc.startmode "and is" $svc.state 
} 
