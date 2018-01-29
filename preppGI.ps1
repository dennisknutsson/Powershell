<#
Filversion 0.2
Skript för att förbereda en golden image för uppdatering
2017-02-24 Lagt till så SCCM tjänsten startas och värdet för Appdeploy sätts till True
2017-12-14 Skrivit om allt för att skapa rapport
#>
$stopwatch = [System.Diagnostics.Stopwatch]::startNew()
#Sleep
#Start-Sleep -s 60
CLS
$computername=$env:COMPUTERNAME
#Kör bara om det är en GI
IF ($computername -like "VDI000*") {
Write-Output "Golden Image"

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
<#
$PathToReport = (split-path -parent $MyInvocation.MyCommand.Definition)
$scriptname = $MyInvocation.MyCommand | select -ExpandProperty Name
$scriptname = $scriptname.replace(".ps1"," ")
$scripttitle = $scriptname
$mailbody=@()
#>

$smtpTo = "Dennis <dennis.knutsson@vgregion.se>"
$smtpFrom = "Script from "+$env:computername+"<no.reply@vgregion.se>"
$smtpServer = "mailhost.vgregion.se"
$datetime = Get-Date -UFormat "%Y-%m-%d %T"
$PathToReport = (split-path -parent $MyInvocation.MyCommand.Definition)
$scriptname = $MyInvocation.MyCommand | select -ExpandProperty Name
$scriptname = $scriptname.replace(".ps1"," ")
$scripttitle = $scriptname
$mailbody  = @()


##Startar tjänster om dom finns
$services = @("CcmExec")
$services=$services|sort
FOREACH ($service in $services) {
    IF ((Get-Service -Name $service -ErrorAction SilentlyContinue)-ne $null) {
    IF (Get-Service -Name $service -ErrorAction SilentlyContinue) {IF ((Get-Service -Name $service).Status -eq "Stopped") {Start-Service -name $service}}
    $action="Start Service"
    $what=(Get-Service -Name $service -ErrorAction SilentlyContinue).DisplayName+" ("+(Get-Service -Name $service -ErrorAction SilentlyContinue).Name+")"
    $result=(Get-Service -Name $service -ErrorAction SilentlyContinue).status
    IF ($result -eq "Running") {$status="OK"} ELSE {$status="NOK"}
    $mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}
    }
}


#Startar möjligheten att distribuera via SCCM till VDI:er
Set-Itemproperty -Path HKLM:\SOFTWARE\VGR\CCM -name CCMAppDeploy -Value "True"
$action="Set Registry Value"
$what="HKLM:\SOFTWARE\VGR\CCM CCMAppDeploy"
$result=(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\VGR\CCM -name CCMAppDeploy)
IF ($result -eq "True") {$status="OK"} ELSE {$status="NOK"}
$mailbody += "" | Select-Object @{n="Action";e={$action}},@{n="What";e={$what}},@{n="Result";e={$result}},@{n="Status";e={$status}}


#Sleep
Start-Sleep -s 10

#Trigga CCM för snabbare installation av patchar.
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}" #Machine Policy Retrieval Cycle
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}" #Machine Policy Evaluation Cycle
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}" #Software Update Scan Cycle
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000114}" #Software Update Deployment Evaluation Cycle

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

$mailbody

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



$mailbody = $mailbody | 
    #Select Name,Value| 
    Select *| 
    #-PostContent "<p><h2>Release DHCP-lease and shutting down</h2></p><br>"
    ConvertTo-Html -Head $Header -PreContent "<p><h2>$scripttitle</h2></p><br> $todo" | 
    Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd

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
            Write-Host "Could not send Information retrying in 10 seconds..."
            Start-Sleep -Seconds 10
            $Retrycount = $Retrycount + 1

        }

    }

}

While ($Stoploop -eq $false)

Write-Host
Write-Host "Script finished..." -foregroundcolor Green

} ELSE {Write-Output "Not Golden Image"}





<#
{00000000-0000-0000-0000-000000000001} Hardware Inventory
{00000000-0000-0000-0000-000000000002} Software Inventory 
{00000000-0000-0000-0000-000000000003} Discovery Inventory 
{00000000-0000-0000-0000-000000000010} File Collection 
{00000000-0000-0000-0000-000000000011} IDMIF Collection 
{00000000-0000-0000-0000-000000000012} Client Machine Authentication 
{00000000-0000-0000-0000-000000000021} Request Machine Assignments 
{00000000-0000-0000-0000-000000000022} Evaluate Machine Policies 
{00000000-0000-0000-0000-000000000023} Refresh Default MP Task 
{00000000-0000-0000-0000-000000000024} LS (Location Service) Refresh Locations Task 
{00000000-0000-0000-0000-000000000025} LS (Location Service) Timeout Refresh Task 
{00000000-0000-0000-0000-000000000026} Policy Agent Request Assignment (User) 
{00000000-0000-0000-0000-000000000027} Policy Agent Evaluate Assignment (User) 
{00000000-0000-0000-0000-000000000031} Software Metering Generating Usage Report 
{00000000-0000-0000-0000-000000000032} Source Update Message
{00000000-0000-0000-0000-000000000037} Clearing proxy settings cache 
{00000000-0000-0000-0000-000000000040} Machine Policy Agent Cleanup 
{00000000-0000-0000-0000-000000000041} User Policy Agent Cleanup
{00000000-0000-0000-0000-000000000042} Policy Agent Validate Machine Policy / Assignment 
{00000000-0000-0000-0000-000000000043} Policy Agent Validate User Policy / Assignment 
{00000000-0000-0000-0000-000000000051} Retrying/Refreshing certificates in AD on MP 
{00000000-0000-0000-0000-000000000061} Peer DP Status reporting 
{00000000-0000-0000-0000-000000000062} Peer DP Pending package check schedule 
{00000000-0000-0000-0000-000000000063} SUM Updates install schedule 
{00000000-0000-0000-0000-000000000071} NAP action 
{00000000-0000-0000-0000-000000000101} Hardware Inventory Collection Cycle 
{00000000-0000-0000-0000-000000000102} Software Inventory Collection Cycle 
{00000000-0000-0000-0000-000000000103} Discovery Data Collection Cycle 
{00000000-0000-0000-0000-000000000104} File Collection Cycle 
{00000000-0000-0000-0000-000000000105} IDMIF Collection Cycle 
{00000000-0000-0000-0000-000000000106} Software Metering Usage Report Cycle 
{00000000-0000-0000-0000-000000000107} Windows Installer Source List Update Cycle 
{00000000-0000-0000-0000-000000000108} Software Updates Assignments Evaluation Cycle 
{00000000-0000-0000-0000-000000000109} Branch Distribution Point Maintenance Task 
{00000000-0000-0000-0000-000000000110} DCM policy 
{00000000-0000-0000-0000-000000000111} Send Unsent State Message 
{00000000-0000-0000-0000-000000000112} State System policy cache cleanout 
{00000000-0000-0000-0000-000000000113} Scan by Update Source 
{00000000-0000-0000-0000-000000000114} Update Store Policy 
{00000000-0000-0000-0000-000000000115} State system policy bulk send high
{00000000-0000-0000-0000-000000000116} State system policy bulk send low 
{00000000-0000-0000-0000-000000000120} AMT Status Check Policy 
{00000000-0000-0000-0000-000000000121} Application manager policy action 
{00000000-0000-0000-0000-000000000122} Application manager user policy action
{00000000-0000-0000-0000-000000000123} Application manager global evaluation action 
{00000000-0000-0000-0000-000000000131} Power management start summarizer
{00000000-0000-0000-0000-000000000221} Endpoint deployment reevaluate 
{00000000-0000-0000-0000-000000000222} Endpoint AM policy reevaluate 
{00000000-0000-0000-0000-000000000223} External event detection
#>