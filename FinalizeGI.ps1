# Filversion 2.0
#cd '\\vgregion.se\Ifr$\ScriptAndExec\Exec\VDI'
# 2017-12-07 Lagt till Sendmail plus kontroller av alla saker vi testar.
# 2017-12-04 Lagt till Kontroll av service innan ändring, Shutdown som sista aktion, Ta bort filer i c:\temp
# 2017-03-03 Lagt till rensning av Imprivata loggar
# 2017-03-03 Lagt till så SCCM tjänsten sätts till manuell
# 2017-03-16 Lagt till så att |VDI läggs till som anpassning för PrintScript
# 2017-03-20 Lagt till Underkategori som anpassning för att PrintScript skall köras utan fel
# 2017-03-20 Lagt till avstängning av Windows Update samt borttagning av WindowsUpdate.log
# 2017-03-22 Lagt till avstänging av VMware Horizon View agent samt borttagning av loggar
# 2017-08-15 Lagt till borttagning av maskincert under personliga certifikat
# 2017-11-14 Lagt till avidentifiering av NetClean
<#
CCMcache
Softwaredistribution

Kolla register värden får identity och VDI


#>


param (
    [string]$reportonly = "no",
    [string]$colour = "yes",
    [string]$localdebug = "no"
)
$stopwatch = [System.Diagnostics.Stopwatch]::startNew()
CLS
$computername=$env:COMPUTERNAME
#Kör bara om det är en GI (D003656 D003311)
IF ($computername -like "VDI000*") {Write-Output "Golden Image"}
IF ($computername -Notlike "VDI000*") {$reportonly = "yes"}
IF ($reportonly -ne "no") {Write-Output "Report Only"}

Function Set-AlternatingRows {
    [CmdletBinding()]
         Param(
             [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
             [object[]]$HTMLDocument,
      
             [Parameter(Mandatory=$True)]
             [string]$CSSEvenClass,
      
             [Parameter(Mandatory=$True)]
             [string]$CSSOddClass
         )
     Begin {
         $ClassName = $CSSEvenClass
     }
     Process {
         [string]$Line = $HTMLDocument
         $Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
         If ($ClassName -eq $CSSEvenClass)
         {    $ClassName = $CSSOddClass
         }
         Else
         {    $ClassName = $CSSEvenClass
         }
         $Line = $Line.Replace("<table>","<table width=""100%"">")
         Return $Line
     }
}

#Declare variables
# Set debug preference
# $DebugPreference = "Continue"
$DebugPreference = "SilentlyContinue"
$smtpTo = "Dennis <dennis.knutsson@vgregion.se>"
$smtpFrom = "Script from "+$env:computername+"<no.reply@vgregion.se>"
$smtpServer = "mailhost.vgregion.se"
$datetime = Get-Date -UFormat "%Y-%m-%d %T"
$PathToReport = (split-path -parent $MyInvocation.MyCommand.Definition)
$scriptname = $MyInvocation.MyCommand | select -ExpandProperty Name
$scriptname = $scriptname.replace(".ps1"," ")
$scripttitle = $scriptname
$mailbody  = @()
$todo=@("TODO=","Screen-Resolution")

$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
.odd  { background-color:#ffffff; }
.even { background-color:#dddddd; }
</style>
<title>
Report
</title>
"@

#. C:\Windows\VGR\Set-ScreenResolution.ps1

<#Todo
Remove or minimize System Restore points.
Turn off system protection on C:\.
Open Windows Media Player and use the default settings.
Adjust performance settings for best performance.
Uninstall Tablet PC Components, unless this feature is needed.

Use the File System Utility (fsutil) command to disable the setting that keeps track of the last time a file was accessed.
For example: fsutil behavior set disablelastaccess 1

Start the Registry Editor (regedit.exe) and change the TimeOutValue REG_DWORD in HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Disk to 0x000000be(190).
Turn off the Windows Customer Experience Improvement Program and disable related tasks from the Task Scheduler.


<keyName>hku\temp\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects</keyName><valueName>VisualFXSetting</valueName><type>REG_DWORD</type><data>3</data>
<keyName>HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects</keyName><valueName>VisualFXSetting</valueName><type>REG_DWORD</type><data>3</data>
<keyName>HKCU\Control Panel\Desktop</keyName><valueName>SCRNSAVE.EXE</valueName>
#>

#Vilket operativ system
$action="WMI"
$what="Name"
$result=(Get-WmiObject -Class Win32_OperatingSystem).caption
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Vilken version
$action="WMI"
$what="Version"
$result=(Get-WmiObject -Class Win32_OperatingSystem).Version
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Vilken arkitektur
$action="WMI"
$what="OSArchitecture"
$result=(Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Disk
$action="WMI"
$what="Disk Capacity C:\"
$result=Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'"|Select PSComputername,DeviceID,@{Name="SizeGB";Expression={$_.Size/1GB -as [int]}}
$result=($result.SizeGB).tostring()
$result=$result+" GB"
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Disk
$action="WMI"
$what="Disk Free C:\"
$result=Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'"|Select PSComputername,DeviceID,@{Name="FreeGB";Expression={[math]::Round($_.Freespace/1GB)}}
#$result=Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'"|Select PSComputername,DeviceID,@{Name="FreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}}
$result=($result.FreeGB).tostring()
$result=$result+" GB"
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Sätter energi schema
$result=$null
IF ($reportonly -eq "no"){
powercfg /SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
}
$action="WMI"
$what="Powerscheme"
$result=(gwmi -NS root\cimv2\power -Class win32_PowerPlan -Filter "IsActive = 'true'").elementname
#$status="NA*"
IF ($result -like "Hög*") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Stänger av Hibernation
$result=$null
IF ($reportonly -eq "no"){
    POWERCFG -H OFF
}
#Stänger av timeout för systemet
IF ($reportonly -eq "no"){
    POWERCFG /CHANGE -monitor-timeout-ac 0
    POWERCFG /CHANGE -disk-timeout-ac 0
    POWERCFG /CHANGE -standby-timeout-ac 0
    POWERCFG /CHANGE -hibernate-timeout-ac 0
}

$powerplan=get-wmiobject -namespace "root\cimv2\power" -class Win32_powerplan | where {$_.IsActive}
$powerSettings = $powerplan.GetRelated("win32_powersettingdataindex") | foreach {
 $powersettingindex = $_;
 $powersettingindex.GetRelated("Win32_powersetting") | select @{Label="Power Setting";Expression={$_.instanceid}},
 @{Label="ACDC";Expression={$powersettingindex.instanceid.split("\")[2]}},
 @{Label="Summary";Expression={$_.ElementName}},
 @{Label="Description";Expression={$_.description}},
 @{Label="Value";Expression={$powersettingindex.settingindexvalue}}
 }
 #$powerSettings|where {$_.ACDC -eq "AC"}|FT ACDC,Summary,Value -AutoSize
 $powerSettings=$powerSettings|where {$_.ACDC -eq "AC"}
 #$powerSettings=$powerSettings|where {$_.Summary -like "Stäng*" -or $_.Summary -like "kräv*" -or $_.Summary -like "*Strömspar*" -or $_.Summary -like "Timeout för ström*" -or $_.Summary -like "Viloläge*"}
 #$powerSettings=$powerSettings|where {$_.Summary -eq "Energisparläge" -or $_.Summary -like "kräv*" -or $_.Summary -eq "Strömsparläge efter" -or $_.Summary -eq "Viloläge efter" -or $_.Summary -eq "Stäng av skärmen efter" -or $_.Summary -eq "Stäng av hårddisken efter"}|sort Summary
 $powerSettings=$powerSettings|where {$_.Summary -eq "Energisparläge" -or $_.Summary -eq "Strömsparläge efter" -or $_.Summary -eq "Viloläge efter" -or $_.Summary -eq "Stäng av skärmen efter" -or $_.Summary -eq "Stäng av hårddisken efter"}|sort Summary
 
 #$powerSettings=$powerSettings|where {$_.Value -eq "0"}

FOREACH ($powerSetting in $powerSettings) {
    $action="WMI"
    $what=$powerSetting.Summary
    $result=$powerSetting.Value
    IF ($result -eq "0") {$status="OK"} ELSE {$status="NOK"}
    #$status="NA"
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
}






<#
$action="CMD"
$what="Current AC Power Setting"
$Screentimeout=@(powercfg /query SCHEME_MIN SUB_VIDEO VIDEOIDLE)
FOREACH ($string in $Screentimeout) {
    IF ($string -like "*Current AC*") {
    $null,$result=$string.Split(':')
    }
}
IF ($result -like " 0x00000000") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
#>
#POWERCFG /query 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e|Find /I "Index"
#powercfg /query SCHEME_MIN SUB_VIDEO VIDEOIDLE
#powercfg -change -monitor-timeout-ac 0
#powercfg -change -monitor-timeout-dc 0
#powercfg -change -disk-timeout-ac 0
#powercfg -change -disk-timeout-dc 0
#powercfg -change -standby-timeout-ac 0
#powercfg -change -standby-timeout-dc 0
#powercfg -change -hibernate-timeout-ac 0
#powercfg -change -hibernate-timeout-dc 0


#Sätter Växlingsfilen till fysiskt minne X1,5 
$result=$null
$mem=(Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
$mem *="1.5"
$mem =[math]::truncate($mem / 1MB)
IF ($reportonly -eq "no"){
$computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges;
$computersys.AutomaticManagedPagefile = $False;
$computersys.Put();
$pagefile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name like '%pagefile.sys'";
$pagefile.InitialSize = $mem;
$pagefile.MaximumSize = $mem;
$pagefile.Put();
}
$action="WMI"
$what="Pagefile"
$result=(Get-WmiObject -Class Win32_PageFileSetting).MaximumSize
IF ($result -eq $mem) {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Stoppar tjänster om dom finns
$result=$null
$services = @("SnowInventoryClient","SSOManHost","svcncpa","CcmExec","wuauserv","WSNM","VMBlast","vmlm","ftnlses3hv","TPAutoConnSvc","Spooler","TPVCGateway","dot3svc","Netman","TrkWks","tsdrvdisvc","v4v_agent")
$services=$services|sort
FOREACH ($service in $services) {
        IF ((Get-Service -Name $service -ErrorAction SilentlyContinue)-ne $null) {
            IF (Get-Service -Name $service -ErrorAction SilentlyContinue) {
                IF ((Get-Service -Name $service).Status -eq "running") {
                    IF ($reportonly -eq "no"){
                        Stop-Service -name $service -Force
                    }
                }
            }
    $action="Stop Service"
    #$what=$service
    $what=(Get-Service -Name $service -ErrorAction SilentlyContinue).DisplayName+" ("+(Get-Service -Name $service -ErrorAction SilentlyContinue).Name+")"
    $result=(Get-Service -Name $service -ErrorAction SilentlyContinue).status
    #$result|Out-GridView -PassThru
    IF ($result -eq "Stopped") {$status="OK"} ELSE {$status="NOK"}
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
    #Write-Output $what $result
    }
}

##Sätter uppstartsläge för tjänster till manuell
$services = @("CcmExec")
$services=$services|sort
FOREACH ($service in $services) {
    $result=$null
    IF ((Get-Service -Name $service -ErrorAction SilentlyContinue)-ne $null) {
    IF ((Get-Service -Name $service).StartType -ne "Manual") {IF ($reportonly -eq "no"){
        Set-Service -Name $service -StartupType "Manual"}
    }
    $action="Set Service Startup Type"
    $what=(Get-Service -Name $service -ErrorAction SilentlyContinue).DisplayName+" ("+(Get-Service -Name $service -ErrorAction SilentlyContinue).Name+")"
    $result=@(Get-Service -Name $service).StartType
    IF ($result -eq "Manual") {$status="OK"} ELSE {$status="NOK"}
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
    }
}

##Sätter uppstartsläge för tjänster till Automatic
$services = @("Themes","wuauserv","WSearch","bits")
$services=$services|sort
FOREACH ($service in $services) {
    $result=$null
    IF ((Get-Service -Name $service -ErrorAction SilentlyContinue)-ne $null) {
        IF ((Get-Service -Name $service).StartType -ne "Automatic") {
        IF ($reportonly -eq "no"){
            Set-Service -Name $service -StartupType "Automatic"}
    }
    $action="Set Service Startup Type"
    $what=(Get-Service -Name $service -ErrorAction SilentlyContinue).DisplayName+" ("+(Get-Service -Name $service -ErrorAction SilentlyContinue).Name+")"
    $result=@(Get-Service -Name $service).StartType
    IF ($result -eq "Automatic") {$status="OK"} ELSE {$status="NOK"}
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
    }
}

##Tar bort schemalagt jobb för CCM
$Schedule= New-Object -ComObject Schedule.Service
$Schedule.Connect($env:COMPUTERNAME)
$Taskfolder=$Schedule.GetFolder("Microsoft\Configuration Manager")
$Task= $Taskfolder.GetTasks(0)
foreach($T in $Task){
    $result=$null
    $T.Name
    IF ($reportonly -eq "no"){
        $Taskfolder.DeleteTask($T.Name,0)
    }
}
$action="Remove Scheduled Task"
$what="Microsoft\Configuration Manager"
$Schedule= New-Object -ComObject Schedule.Service
$Schedule.Connect($env:COMPUTERNAME)
$Taskfolder=$Schedule.GetFolder("Microsoft\Configuration Manager")
$Task= $Taskfolder.GetTasks(0)
IF ($Task -ne "") {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort SMSCFG.ini för CCM
$result=$null
$filetoremove="C:\Windows\SMSCFG.INI"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Force}
}
$action="Remove File"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort WindowsUpdate.log för Windows Update
$result=$null
$filetoremove="C:\Windows\WindowsUpdate.log"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Force}
}
$action="Remove File"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Tar bort filer för att avindentifiera NetClean
$result=$null
$filetoremove="C:\ProgramData\NetClean Technologies\NetClean ProActive for Windows\Data\agentSettings.dat"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Force}
}
$action="Remove File"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

$result=$null
$filetoremove="C:\ProgramData\NetClean Technologies\NetClean ProActive for Windows\Data\ncr.dat"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Force}
}
$action="Remove File"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort clientspecifikdata för SNOW
$result=$null
$filetoremove="C:\Program Files\inventoryclient\Data\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort clientspecifikdata för VMware Horizon View Finns ej
$result=$null
$filetoremove="C:\ProgramData\VMware\logs\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Stoppar processer som håller filer som skall rensas
$processes = @("LogonUI","VMwareViewClipboard","wssm","VMwareView-RdeServer","Dism")
$processes=$processes|sort
FOREACH ($process in $processes) {
    IF ($reportonly -eq "no"){
    Stop-Process -processname $process -Force -ErrorAction SilentlyContinue
    }
}

#conhost
$result=$null
IF ($reportonly -eq "no"){
    Write-Output "sleep 10s"
    Start-Sleep -s 10
}
##Tar bort VMware Horizon agentens logfiler.
$filetoremove="C:\ProgramData\VMware\VDM\logs\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort clientspecifikdata för VMware Blast Finns ej?
$result=$null
$filetoremove="C:\ProgramData\VMware\VMware Blast\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort loggar för VMware Logon Monitor 
$result=$null
$filetoremove="C:\ProgramData\VMware\VMware Logon Monitor\Logs\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort loggar för VMware Optimisation tool
$result=$null
$filetoremove="C:\ProgramData\VMware\OSOT\Log\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Tar bort loggar för VMware vRealize Operations for Horizon
$result=$null
$filetoremove="C:\ProgramData\VMware\vRealize Operations for Horizon\Desktop Agent\logs\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Tar bort loggar för Imprivata (finns ej ännu)
$result=$null
$filetoremove="C:\ProgramData\SSOProvider\Logs\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Tar bort filer i c:\temp
$result=$null
$filetoremove="C:\Temp\*"
IF ($reportonly -eq "no"){
    IF (Test-Path $filetoremove) {Remove-Item $filetoremove -Recurse -Force}
}
$action="Remove Dir"
$what=$filetoremove
IF (Test-Path $filetoremove) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Tar bort InventoryActionID för CCM
$result=$null
IF ($reportonly -eq "no"){
    Get-WmiObject -Namespace "root\ccm\invagt" -Class InventoryActionStatus -Filter "InventoryActionID='{00000000-0000-0000-0000-000000000001}'"| Remove-WmiObject
}
$action="Remove InventoryActionID"
$what="{00000000-0000-0000-0000-000000000001}"
$test=Get-WmiObject -Namespace "root\ccm\invagt" -Class InventoryActionStatus -Filter "InventoryActionID='{00000000-0000-0000-0000-000000000001}'"
IF (!($test.LastMajorReportVersion -eq $null)) {Write-Output "Not Cleaned"}ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#rensar eventloggarna för Application,system och security
$result=$null
IF ($reportonly -eq "no"){
    Clear-EventLog -LogName Application -Confirm:$false
}
$action="Clean Eventlog"
$what="Application"
IF (((Get-EventLog Application -ErrorAction SilentlyContinue).count) -le 1) {$result="Cleaned"} ELSE {$result="Not Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

$result=$null
IF ($reportonly -eq "no"){
    Clear-EventLog -LogName Security -Confirm:$false
}
$action="Clean Eventlog"
$what="Security"
IF (((Get-EventLog Security -ErrorAction SilentlyContinue).count) -le 1) {$result="Cleaned"} ELSE {$result="Not Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

$result=$null
IF ($reportonly -eq "no"){
    Clear-EventLog -LogName System -Confirm:$false
}
$action="Clean Eventlog"
$what="System"
IF (((Get-EventLog System -ErrorAction SilentlyContinue).count) -le 1) {$result="Cleaned"} ELSE {$result="Not Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

$result=$null
IF ($reportonly -eq "no"){
    Clear-EventLog -LogName 'ThinPrint Diagnostics' -Confirm:$false
}
$action="Clean Eventlog"
$what="ThinPrint Diagnostics"
IF (((Get-EventLog 'ThinPrint Diagnostics' -ErrorAction SilentlyContinue).count) -le 1) {$result="Cleaned"} ELSE {$result="Not Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

$result=$null
IF ($reportonly -eq "no"){
    Clear-EventLog -LogName 'Windows PowerShell' -Confirm:$false
}
$action="Clean Eventlog"
$what="Windows PowerShell "
IF (((Get-EventLog 'Windows PowerShell' -ErrorAction SilentlyContinue).count) -le 1) {$result="Cleaned"} ELSE {$result="Not Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Ta bort maskincertifikat
$result=$null
IF ($reportonly -eq "no"){
    Remove-Item -Path HKLM:\Software\Microsoft\SystemCertificates\MY\Certificates\* -Force
}
$action="Remove Registry Key"
$what="HKLM:\Software\Microsoft\SystemCertificates\MY\Certificates\*"
IF ((Get-ChildItem "HKLM:\Software\Microsoft\SystemCertificates\MY\Certificates" | ForEach-Object {Get-ItemProperty $_.pspath}) -ne $null) {$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

##Ta bort certifikat för CCM
IF ($reportonly -eq "no"){
    Remove-Item -Path HKLM:\Software\Microsoft\SystemCertificates\SMS\Certificates\* -Force 
}
$action="Remove Registry Key"
$what="HKLM:\Software\Microsoft\SystemCertificates\SMS\Certificates\*"
IF ((Get-ChildItem "HKLM:\Software\Microsoft\SystemCertificates\SMS\Certificates" | ForEach-Object {Get-ItemProperty $_.pspath}) -ne $null) {$result=$null,$result="Not Cleaned"} ELSE {$result="Cleaned"}
IF ($result -eq "Cleaned") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Skapar VGR\IDENTITY
$result=$null
IF ($reportonly -eq "no"){
    IF (!(Test-Path HKLM:\SOFTWARE\VGR\IDENTITY)) {
    Write-Output "Creating HKLM:\SOFTWARE\VGR\IDENTITY"
    New-Item -Path HKLM:\SOFTWARE\VGR\IDENTITY
    }
} ELSE {Write-Host "HKLM:\SOFTWARE\VGR\IDENTITY Exist"}

$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\IDENTITY"
$result=(Test-Path HKLM:\SOFTWARE\VGR\IDENTITY -ErrorAction SilentlyContinue)
IF ($result -eq "False") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
#}

#Skapar VGR\VDI
$result=$null
IF ($reportonly -eq "no"){
    IF (!(Test-Path HKLM:\SOFTWARE\VGR\VDI)) {
    Write-Output "Creating HKLM:\SOFTWARE\VGR\VDI"
    New-Item -Path HKLM:\SOFTWARE\VGR\VDI
    }
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\VDI"
$result=(Test-Path HKLM:\SOFTWARE\VGR\VDI -ErrorAction SilentlyContinue)
IF ($result -eq "True") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#IPv6
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters -name DisabledComponents -Value "255"
}
$action="Set Registry Value"
$what="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters DisabledComponents"
$result=(Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters -Name DisabledComponents)
IF ($result -eq "255") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Disabledcoponents
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name DisableLockWorkstation -Value "1" -Type DWord
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System DisableLockWorkstation"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name DisableLockWorkstation)
IF ($result -eq "1") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Thinprint
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\Software\ThinPrint -name Lang -Value "sve" -Type String
}
$action="Set Registry Value"
$what="HKLM:\Software\ThinPrint Lang"
$result=(Get-ItemPropertyValue -Path HKLM:\Software\ThinPrint -name Lang)
IF ($result -eq "sve") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Stoppar möjligheten att distribuera via SCCM till VDI:er
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\CCM -name CCMAppDeploy -Value "False"
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\CCM CCMAppDeploy"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\CCM -name CCMAppDeploy)
IF ($result -eq "False") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Sätter anpassning till |VDI för att PrintScript skall förstå att det är VDI
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\IDENTITY -name Anpassningar -Value "|VDI"
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\IDENTITY Anpassningar"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\IDENTITY -name Anpassningar)
IF ($result -eq "|VDI") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Sätter underkategori till VDI för att PrintScript skall förstå att det är VDI
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\IDENTITY -name Underkategori -Value "VDI"
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\IDENTITY Underkategori"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\IDENTITY -name Underkategori)
IF ($result -eq "VDI") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Golden Image Timestamp
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\VDI -name ImageTimeStamp -Value $datetime
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\VDI ImageTimeStamp"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\VDI -name ImageTimeStamp)
IF ($result -ne $null) {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Golden Image Version
$result=$null
$version=""
[int]$version=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\VDI -Name ImageVersion -ErrorAction SilentlyContinue)
IF ($version -ne "") {$version++} ELSE {[int]$version="1"}
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\VDI -name ImageVersion -Value $version -Type DWord
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\VDI ImageVersion"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\VDI -name ImageVersion)
IF ($result -ne $null) {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Golden Image ImageName
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\VDI -name ImageName -Value $env:computername
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\VDI ImageName"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\VDI -name ImageName)
IF ($result -eq $env:computername) {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#UAC
$result=$null
IF ($reportonly -eq "no"){
    Set-Itemproperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA -Value "1" -Type DWord
}
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system EnableLUA"
$result=(Get-ItemPropertyvalue -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system -name EnableLUA)
IF ($result -eq "1") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Lista installerade appar
$installed_apps=Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |Sort-object DisplayName|Where {$_.DisplayName -ne $null}
#$installed_apps|Out-GridView
FOREACH ($app in $installed_apps) {
    $result=$null
    $action="Installed Application"
    $what=$app.DisplayName
    $result=$app.DisplayVersion
    $status="NA"
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
}

#user
$action="Env"
$what="Running user"
$result=$env:USERNAME
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Scriptpath
$action="Env"
$what="Scriptpath"
$result=$PathToReport
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Scriptpath
$action="Env"
$what="Scriptname"
$result=$scriptname
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Computer
$action="Env"
$what="Computername"
$result=$env:COMPUTERNAME
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Computer
$action="Env"
$what="Path include UNC with \\"
$result=$env:PATH
IF ($result.contains("\\")) {$result} ELSE {$result="Clean"}
IF ($result.contains("\\")) {$status="NOK"} ELSE {$status="OK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Lastboot
$action="Env"
$what="Last boot"
$os = Get-WmiObject win32_operatingsystem -ErrorAction SilentlyContinue
$result=$os.ConvertToDateTime($os.LastBootUpTime)
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#WindowsUpdateStatus
$result=$null
$WindowsUpdateStatus = (Get-HotFix -ComputerName $env:COMPUTERNAME | Where-Object {$_.InstalledOn -ne $null} | Sort-Object InstalledOn)[-1]
$action="Latest hotfix installed"
$what="($($WindowsUpdateStatus.HotFixID), $($WindowsUpdateStatus.Description))"
#$result="$(($WindowsUpdateStatus.InstalledOn).Year)-$(($WindowsUpdateStatus.InstalledOn).Month)-$(($WindowsUpdateStatus.InstalledOn).Day)"
$result=$WindowsUpdateStatus.InstalledOn

IF (( $WindowsUpdateStatus.InstalledOn) -ge ((get-date).AddDays(-30) )) {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#Run Disk Defragmenter
#%windir%\system32\defrag.exe -c

#Run Disk Cleanup
#add registry entrys
#win10

$regkeys = @("Active Setup Temp Folders","BranchCache","Downloaded Program Files","Internet Cache Files","Old ChkDsk Files","Previous Installations","Recycle Bin","RetailDemo Offline Content","Service Pack Cleanup","Setup Log Files","System error memory dump files","System error minidump files","Temporary Files","Temporary Setup Files","Thumbnail Cache","Update Cleanup","Upgrade Discarded Files","User file versions","Windows Defender","Windows Error Reporting Archive Files","Windows Error Reporting Queue Files","Windows Error Reporting System Archive Files","Windows Error Reporting System Queue Files","Windows Error Reporting Temp Files","Windows ESD installation files","Windows Upgrade Log Files","Memory Dump Files","Offline Pages Files")
$regkeys=$regkeys|sort
FOREACH ($regkey in $regkeys) {

IF (Test-Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$regkey) {#Write-Output $regkey "Exist"
    IF ($reportonly -eq "no"){
        Set-Itemproperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$regkey -name StateFlags0001 -Value "2" -Type DWord
    }
    }
}
#kommando för att köra diskcleanup saknas

#Profile rensning
#Bör testas och komma övernens hur vi skall rensa profiler.
#Get-WmiObject -Class Win32_UserProfile | where {$_.LocalPath.split('')[-1] -eq '<profilename_changeme>'} | foreach {$_.Delete()}

#Adobe Flash Player 
#Adobe Reader DC 
#Adobe Shockwave Player 11 
#Feedreader 
#MiM 
#Net iD Client GPO 
#NetClean 
#Snow Inventory Client for Windows VDI  

$stopwatch.Stop()

#Time
$result=$null
$action="Execution"
$what="Time"
$sec=(($stopwatch.Elapsed).Seconds).ToString()
$msec=(($stopwatch.Elapsed).Milliseconds).ToString()
$result=($sec+","+$msec)
$status="NA"
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}

#######################################################################################
$mailbody = $mailbody | 
    #Select Name,Value| 
    Select *| 
    ConvertTo-Html -Head $Header -PreContent "<p><h2>$scripttitle</h2></p><br> $todo" -PostContent "<p><h2>Release DHCP-lease and shutting down</h2></p><br>"| 
    Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd

IF ($colour -eq "yes"){
$mailbody = $mailbody.Replace("<td>NOK</td></tr>","<td bgcolor=""#FF0000"">NOK</td></tr>")
$mailbody = $mailbody.Replace("<td>OK</td></tr>","<td bgcolor=""#00FF00"">OK</td></tr>")
}
$mailbody | Out-File $PathToReport"\"$scripttitle".html"

Write-host "Sending mail to" $smtpTo 

$Stoploop = $false
[int]$Retrycount = "1"

do {

    try {
        Send-MailMessage -To $smtpTo -From $smtpFrom -Subject "$scripttitle $datetime" -Body ($mailbody | Out-String) -BodyAsHtml -SmtpServer $smtpServer -ErrorAction Stop;
        # -port $SMTPPort -UseSsl -Credential $mycreds
        Write-Host "Mail sent using $SMTPServer"
        $Stoploop = $true
        }

    catch {

        if ($Retrycount -gt 3){
            Write-Host "Could not send Information after 3 retrys."
            $Stoploop = $true
        }

        else {
            Write-Host "Could not send Information retrying in 15 seconds..."
            Start-Sleep -Seconds 15
            $Retrycount = $Retrycount + 1

        }

    }

}

While ($Stoploop -eq $false)

Write-Host
Write-Host "Script finished..." -foregroundcolor Green

#Släpper inte DHCP och stänger inte av
IF ($localdebug -eq "no"){
#Släpper DHCP-lease
IF ($reportonly -eq "no"){
    $ethernet = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where {
        $_.IpEnabled -eq $true -and $_.DhcpEnabled -eq $true
    }
    foreach ($lan in $ethernet){
        Write-Host "Släpper DHCP-lease för "$lan.IPAddress
        $lan.ReleaseDHCPLease() | Out-Null
    }
}

<#
#>
#Stänger av maskinen
#shutdown
IF ($reportonly -eq "no"){
    Stop-Computer -Force
}
#} ELSE {Write-Output "Not Golden Image"}


#List services
}