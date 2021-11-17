<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 13.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
  iDRAC cmdlet using Redfish API with OEM extension to export or import server configuration profile to network share
.DESCRIPTION
   iDRAC cmdlet using Redfish API with OEM extension to export or import server configuration profile or SCP. It will call either ExportSystemConfiguration or ImportSystemConfiguration method. For more details on SCP feature, refer to document "https://downloads.dell.com/Manuals/Common/dellemc-server-config-profile-refguide.pdf"
   - idrac_ip (iDRAC IP)
   - idrac_username (iDRAC user name) 
   - idrac_password (iDRAC user name password) 
   - x_auth_token: Pass in iDRAC X-Auth token session to execute cmdlet instead of username / password (recommended)
   - Method (Supported values: Export or Import)
   - network_share_IPAddress (Supported value: IP address of your network share) 
   - ShareName (Supported value: Name of your network share) 
   - ShareType (Supported values: NFS, CIFS, HTTP and HTTPS) 
   - FileName (Supported value: Pass in a name of the exported or imported file) 
   - Username (Supported value: Name of your username that has access to CIFS share) REQUIRED only for CIFS
   - Password (Supported value: Name of your user password that has access to CIFS share) REQUIRED only for CIFS
   - Target (Supported values: ALL, RAID, BIOS, IDRAC, NIC, FC, LifecycleController, System, EventFilters. You are allowed to pass in multiple target values, make sure to use comma separator and surround the complete string with double quotes.)
   - ExportFormat (supported values: XML or JSON) REQUIRED for Export only
   - ExportUse (Supported values: Default, Clone and Replace) OPTIONAL for export only. If not passed in, value will be "Default" used.
   - ShutdownType (Supported values: Graceful, Forced and NoReboot) OPTIONAL, only valid for import, if you don't pass in this parameter, default value will be"Graceful"
   - IncludeInExport: Supported values: Default, IncludeReadOnly, IncludePasswordHashValue, 'IncludeReadOnly,IncludePasswordHashValues' and IncludeCustomTelemetry. Note: If argument not used, value of default will be used.
   - IgnoreCertWarning: Supported values: Enabled and Disabled. This argument is only required if using HTTPS for ShareType. 
  
  NOTE: For parameter values with static strng values, make sure you pass in the exact text since these are case senstive values. Example: For ExportUse, pass in a value of "Clone".
  Passing in a value of "clone" will fail.

.EXAMPLE
   Set-ExportImportServerConfigurationProfileNetworkShareREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -Method export -IPAddress 192.168.0.130 -ShareType NFS -ShareName /nfs -FileName export_R640.xml -Target ALL -ExportFormat XML
This example will perform default export for all devices to a NFS share, SCP file will be in XML format.
.EXAMPLE
   Set-ExportImportServerConfigurationProfileNetworkShareREDFISH -idrac_ip 192.168.0.120 -Method export -IPAddress 192.168.0.130 -ShareType NFS -ShareName /nfs -FileName export_R640.xml -Target BIOS -ExportFormat JSON
This example will first prompt to enter iDRAC credentials using Get-Credential, then export only BIOS attributes in JSON format file to NFS share.
.EXAMPLE
   Set-ExportImportServerConfigurationProfileNetworkShareREDFISH -idrac_ip 192.168.0.120 -Method export -IPAddress 192.168.0.130 -x_auth_token 7bd9bb9a8727ec366a9cef5bc83b2708 -ShareType NFS -ShareName /nfs -FileName export_R640.xml -Target IDRAC -ExportFormat JSON
This example will export only IDRAC attributes in JSON format file to NFS share using X-auth token session. 
.EXAMPLE
   Set-ExportImportServerConfigurationProfileNetworkShareREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -Method export -IPAddress 192.168.0.130 -ShareType HTTP -ShareName http_share -FileName export_R640.xml -Target RAID -ExportFormat XML -ExportUse Clone 
This example will peform clone SCP export for RAID attributes only to HTTP share in XML format.
.EXAMPLE
   Set-ExportImportServerConfigurationProfileNetworkShareREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -Method import -IPAddress 192.168.0.130 -ShareType CIFS -ShareName cifs_share -Username administrator - Password password -Target ALL -FileName export_R640.xml -ShutdownType Forced
This example will import SCP file from CIFS share for all devices using forced server shutdown.
#>

function Set-ExportImportServerConfigurationProfileNetworkShareREDFISH {

param(
    [Parameter(Mandatory=$True)]
    $idrac_ip,
    [Parameter(Mandatory=$False)]
    $idrac_username,
    [Parameter(Mandatory=$False)]
    $idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$x_auth_token,
    [Parameter(Mandatory=$True)]
    [string]$Method,
    [Parameter(Mandatory=$True)]
    [string]$Target,
    [Parameter(Mandatory=$True)]
    [string]$ShareType,
    [Parameter(Mandatory=$True)]
    [string]$ShareName,
    [Parameter(Mandatory=$True)]
    [string]$network_share_IPAddress,
    [Parameter(Mandatory=$True)]
    [string]$FileName,
    [Parameter(Mandatory=$False)]
    [string]$cifs_username,
    [Parameter(Mandatory=$False)]
    [string]$cifs_password,
    [Parameter(Mandatory=$False)]
    [string]$ExportUse,
    [Parameter(Mandatory=$False)]
    [string]$ExportFormat,
    [Parameter(Mandatory=$False)]
    [string]$IncludeInExport,
    [Parameter(Mandatory=$False)]
    [string]$ShutdownType,
    [Parameter(Mandatory=$False)]
    [string]$IgnoreCertWarning
    )

# Function to igonre SSL certs

function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

$global:get_powershell_version = $null

function get_powershell_version 
{
$get_host_info = Get-Host
$major_number = $get_host_info.Version.Major
$global:get_powershell_version = $major_number
}

get_powershell_version 

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
if ($idrac_username -and $idrac_password)
{
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
}
elseif ($x_auth_token)
{
$global:x_auth_token = $x_auth_token
}
else
{
$get_creds = Get-Credential
$credential = New-Object System.Management.Automation.PSCredential($get_creds.UserName, $get_creds.Password)
}

$uri = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"

if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1"

if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }
}

	    if ($result.StatusCode -ne 200)
	    {
        "`n- FAIL, GET request failed, status code {0} returned" -f $result.StatusCode
	    return
	    }
    $get_result=$result.Content | ConvertFrom-Json
    $server_generation = $get_result.Model.Split(" ")[0]
    $fw_version = $get_result.FirmwareVersion.Split(".")[0]+$get_result.FirmwareVersion.Split(".")[1]
    $fw_version = [int]$fw_version

$method=(Get-Culture).textinfo.totitlecase($method.tolower())

$share_info = @{"ShareParameters"=@{}}

if ($ExportFormat)
{
$share_info["ExportFormat"]=$ExportFormat
}
if ($ExportUse)
{
$share_info["ExportUse"]=$ExportUse
}
if ($IncludeInExport)
{
$share_info["IncludeInExport"]=$IncludeInExport
}
if ($ShutdownType)
{
$share_info["ShutdownType"]=$ShutdownType
}
if ($Target)
{
$share_info["ShareParameters"]["Target"]=$Target
}
if ($ShareType)
{
$share_info["ShareParameters"]["ShareType"]=$ShareType
}
if ($network_share_IPAddress)
{
$share_info["ShareParameters"]["IPAddress"]=$network_share_IPAddress
}
if ($ShareName)
{
$share_info["ShareParameters"]["ShareName"]=$ShareName
}
if ($FileName)
{
$share_info["ShareParameters"]["FileName"]=$FileName
}
if ($IgnorecertWarning)
{
$share_info["ShareParameters"]["IgnoreCertificateWarning"]=$IgnoreCertWarning
}
if ($cifs_password)
{
$share_info["ShareParameters"]["Password"]=$cifs_password
}
if ($cifs_username)
{
if ($cifs_username -and $fw_version -gt 316 -and $server_generation -eq "14G" -or $server_generation -eq "15G" -or $server_generation -eq "16G" -or $server_generation -eq "17G")
{
$share_info["ShareParameters"]["Username"]=$cifs_username
}
elseif ($cifs_username -and $fw_version -gt 264 -and $server_generation -eq "13G" -or $server_generation -eq "12G")
{
$share_info["ShareParameters"]["Username"]=$cifs_username
}
else
{
$share_info["ShareParameters"]["UserName"]=$cifs_username
}
}

Write-Host "`n- INFO, parameter details for $Method operation"
$share_info 
Write-Host "`nShareParameters details:`n"
$share_info.ShareParameters

$JsonBody = $share_info | ConvertTo-Json -Compress

$full_method_name="EID_674_Manager."+$Method +"SystemConfiguration"

$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Oem/$full_method_name"

# POST action to import or export server configuration profile file
if ($x_auth_token)
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Post -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}


else
{
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -UseBasicParsing SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    } 
}

$get_job_id_location = $result1.Headers.Location
if ($get_job_id_location.Count -gt 0 -eq $true)
{
}
else
{
[String]::Format("`n- FAIL, unable to locate job ID in Headers output. Check to make sure you passed in correct Target value")
return
}

if ($result1.StatusCode -eq 202)
{
    Write-Host
    [String]::Format("- PASS, statuscode {0} returned to successfully create {2} job ID {1}",$result1.StatusCode,$get_job_id_location.Split("/")[-1], $Method)
    Write-Host
    Start-Sleep 5
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    $result1.Headers
    return
}

$raw_content_output=$result1.RawContent | ConvertTo-Json -Compress
try
{
$job_id_search=[regex]::Match($raw_content_output, "JID_.+?r").captures.groups[0].value
$job_id=$job_id_search.Replace("\r","")
}
catch
{
[String]::Format("- FAIL, unable to locate job ID in JSON output. Check to make sure you passed in correct Target value")
return
}

$overall_job_output=""

$get_time_old=Get-Date -DisplayHint Time
$start_time = Get-Date
$end_time = $start_time.AddMinutes(30)

if ( $ShutdownType -eq "NoReboot")
{
while ($overall_job_output.Message -ne "No reboot Server Configuration Profile Import job scheduled, Waiting for System Reboot to complete the operation.")
{
$uri ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
$overall_job_output=$result.Content | ConvertFrom-Json
if ($overall_job_output.JobState -eq "Failed") {
Write-Host
[String]::Format("- FAIL, final job status is: '{0}'",$overall_job_output.JobState)
return
}
else {
[String]::Format("- INFO, current job status is: {0}",$overall_job_output.Message)
}
}
Write-Host "`n- INFO, NoReboot passed in for ShutdownType, no configuration changes will be applied until next server reboot`n"
return
}



while ($overall_job_output.JobState -ne "Completed")
{
$loop_time = Get-Date
$uri ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
$overall_job_output=$result.Content | ConvertFrom-Json
if ($overall_job_output.JobState -eq "Failed") {
Write-Host
[String]::Format("- FAIL, final job status is: '{0}'",$overall_job_output.JobState)

if ($overall_job_output.Message -eq "The system could not be shut down within the specified time.")
{
[String]::Format("- FAIL, 10 minute default shutdown timeout reached, final job message is: {0}",$overall_job_output.Message)
return
}
else 
{
[String]::Format("- FAIL, final job message is: {0}",$overall_job_output.Message)
return
}
}
elseif ($loop_time -gt $end_time)
{
Write-Host "- FAIL, timeout of 30 minutes has been reached before marking the job completed"
return
}
elseif ($overall_job_output.Message -eq "Import of Server Configuration Profile operation completed with errors.") {
Write-Host
[String]::Format("- INFO, final job status is: {0}",$overall_job_output.Message)
$uri ="https://$idrac_ip/redfish/v1/TaskService/Tasks/$job_id"
if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
Write-Host "`n- Detailed final job status and configuration results for import job ID '$job_id' -`n"

$get_final_results = [string]$result.Content 
$get_final_results.Split(",")
return
}
elseif ($overall_job_output.JobState -eq "Completed") {
break
}
else {
[String]::Format("- INFO, {1} job ID not marked completed, current job status: {0}",$overall_job_output.Message, $Method)
Start-Sleep 10
}
}
Write-Host
[String]::Format("- PASS, {0} job ID marked as completed!",$job_id)
$final_message = $overall_job_output.Message
if ($final_message.Contains("No changes were applied"))
{
[String]::Format("`n- Final job status is: {0}",$overall_job_output.Message)
return
}

$get_current_time=Get-Date -DisplayHint Time
$final_time=$get_current_time-$get_time_old
$final_completion_time=$final_time | select Minutes,Seconds 
Write-Host "  Job completed in $final_completion_time"

$uri ="https://$idrac_ip/redfish/v1/TaskService/Tasks/$job_id"
if ($x_auth_token)
{
 try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
    }
    }
    catch
    {
    $RespErr
    return
    }
}

else
{
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    $RespErr
    return
    }
}
Write-Host "`n- Detailed final job status and configuration results for import job ID '$job_id' -`n"

$get_final_results = [string]$result.Content 
$get_final_results.Split(",")
break

}


