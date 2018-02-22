#Requires -Version 3.0
<#
****************************************************************************************** 
*
*                             [ Author ]
*
* Author: Alexey Baltikov
* Email: baltikov@gmail.com
* Version: 1.0
* Date: 09.08.2017
*
****************************************************************************************** 
*
*                            [ Overview ]   
*                                                                                      
* Name: File Share Availaility Monitoring (OMS Log Analytics Management Solution)             
*                                                                                             
* Description: This Script is used for gathering and sending data to the OMS Log Analytics    
* workspace.
*
*                             [ Setup ] 
*
* 1) Run the script by the Hourly (own choise) schedule on the SMA, Azure Automation or 
* where it is possible;
* 2) Give access to the shared folders to the executing nodes; script modification may be
* required;
* 3) Run script first time before deployment of the OMS solution.
*
******************************************************************************************
* 
*                            [ Parameters ]  
* 
* SharedFolders - one or more shared(SMB) folders paths;
* WorkspaceId - your workspace ID where data should be ingested;
* SharedKey - a primary or secondary key of the Workspace
*
*                          [ Usage examples ]
* 
* Run script with the list of the shared folders in the round brackets
* .\SharedFolderStatus.ps1 -SharedFolders ('\\Enterprise\Marketing','\\Enterprise\Marketing\ExchangeFolder') -WorkspaceId "289dbdff-dd68-4ef6-a006-57d9ab1103f1" -SharedKey "lde2VH4DGgy5HrFSdukdx29hxQG6jbDuJzw+Yvd67qZtuxc2YsIQ/mrU2Z7roCh97F6IiJQNEmEIk3My75jvQw=="
* 
* Run script with the CSV file import V1
* .\SharedFolderStatus.ps1 -SharedFolders (Import-Csv -LiteralPath 'C:\MonitoringScript\Shares.csv') -WorkspaceId "289dbdff-dd68-4ef6-a006-57d9ab1103f1" -SharedKey "lde2VH4DGgy5HrFSdukdx29hxQG6jbDuJzw+Yvd67qZtuxc2YsIQ/mrU2Z7roCh97F6IiJQNEmEIk3My75jvQw=="
*
* Run script with the CSV file import V2
* $FoldersFromCsv = Import-Csv -LiteralPath 'C:\MonitoringScript\Shares.csv' 
* .\SharedFolderStatus.ps1 -SharedFolders $FoldersFromCsv -WorkspaceId "289dbdff-dd68-4ef6-a006-57d9ab1103f1" -SharedKey "lde2VH4DGgy5HrFSdukdx29hxQG6jbDuJzw+Yvd67qZtuxc2YsIQ/mrU2Z7roCh97F6IiJQNEmEIk3My75jvQw=="
* 
* The CSV file format should be like described below from the file 'C:\MonitoringScript\Shares.csv':
* SharedFolder
* \\TestServer\Folder1
* \\TestServer\Folder2
* \\TestServer\Folder3
*
****************************************************************************************** 
*
*                      [ Script Console Output ]
*
* The script output will looks like shown below:
* 
* [08/09/2017 13:53:09] Assigning the Variables
* [08/09/2017 13:53:09] Getting the Shared Folders status
* 
* Testing availability of the folder \\Enterprise\Marketing
* Testing availability of the folder \\Enterprise\Marketing\ExchangeFolder
* Testing availability of the folder \\Enterprise\Fin\ExchangeFolder
*
* The record Type:
* SharedFolderStatus_CL
*
* Records will be send to the OMS workspace:
*
* SharedFolderStatusCode SharedFolderPath                      WatcherNodeName SharedFolderStatus
* ---------------------- ----------------                      --------------- ------------------
*                     1 \\Enterprise\Marketing                HW-02           Available
*                     1 \\Enterprise\Marketing\ExchangeFolder HW-02           Available
*                     1 \\Enterprise\Fin\ExchangeFolder       HW-02           Available
*
* [08/09/2017 13:53:16] Converting gathered data to the JSON object array
* [08/09/2017 13:53:16] Attempting to ingest gathered data to the OMS workspace with ID
* 289dbdff-dd68-4ef6-a006-57d9ab1103f1
*
* The operation result status code
* 200
*
* Script executed
*
****************************************************************************************** 
#>

[cmdletbinding()]
param(
   <#
   [parameter(Mandatory=$true)]
   $SharedFolders,
   [parameter(Mandatory=$true)]
   [guid]$WorkspaceId,
   [parameter(Mandatory=$true)]
   $SharedKey#>
)

#region Variables
Clear-Host
Write-Output ""
Write-Output "*****************************************************************************************"
Write-Output ""
Write-Output "[$(Get-Date)] Assigning the Variables"
$SharedFolders = '\\Enterprise\Marketing\Test','\\Enterprise\Fin\ExchangeFolder', '\\Enterprise\Retail\ExchangeFolder','\\Enterprise\Marketing\Docs','\\Enterprise\Fin\Incoming', '\\Enterprise\Retail\Outcoming'
#$SharedFolders = Import-Csv -LiteralPath 'C:\MonitoringScript\Shares.csv'
$CustomerId = "b80f515d-eeba-47e4-a2c7-1d90c53089f4"
$SharedKey = "lde2VH3DGmy5HrFSdukdx29hxQG6jbDuJzw+Yvz67qZtuxc2YsIQ/mjU2Z7roCh97FSIiJQNEmEIk3My75jvQw=="
#$CustomerId = "8532daad-b602-4553-b563-20ad8c199dca"
#$SharedKey = "AU23ZjPEvPpFEisyDdEzqhhpVGTVzUlE2pcY0IDmRMfhnX/tbK8Y1RDhgeet2YutEUa+9a6rfOxl0aEQx/Gdrw=="  

#Specify a field with the created time for the records
#$TimeStampField = "DateValue"

$WatcherNodeName = "HW-HQ-01", "HW-HQ-02"
$Table = @()
$Object = New-Object -TypeName PSObject  
$FolderStatus = "Available"
$FolderStatusCode = 1
$LogType = "SharedFolderStatus"


#endregion Variables

#region 'SharedFolders' variable check

if ($SharedFolders.SharedFolder){

 $SharedFolders = $SharedFolders.SharedFolder  

}

#endregion 'SharedFolders' variable check

#region Functions
# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-OMSData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
#       "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    Write-Output "The operation result status code" 
    return $response.StatusCode

}
#endregion Functions<##>

#region GettingData
# Get Shared Folders Status

Write-Output "[$(Get-Date)] Getting the Shared Folders status"
Write-Output ""


foreach($Folder in $SharedFolders)
{   
        
        Write-Output "Testing availability of the folder $($Folder)"
        $Result = Test-Path -Path $Folder
<#
        if ($Result -eq $false) {
           
           $FolderStatus = "Unavailable"
           $FolderStatusCode = 0
        }
#>
        foreach($WatcherNode in $WatcherNodeName) {
            $Object = New-Object PSObject -Property @{
                WatcherNodeName = $WatcherNode
                SharedFolderPath = $Folder
                SharedFolderStatus = $FolderStatus
                SharedFolderStatusCode = $FolderStatusCode
            }
            $Table += $Object
        }

    }
Write-Output ""
Write-Output "The record Type:"
Write-Output "$($LogType)_CL"
Write-Output ""
Write-Output "Records will be send to the OMS workspace:"
$Table

Start-Sleep -Seconds 5
Write-Output ""

Write-Output "[$(Get-Date)] Converting gathered data to the JSON object array"
Write-Output ""

$json = $Table | ConvertTo-Json
$json
#endregion GettingData

#region PostData
# Submit the data to the API endpoint
Write-Output ""
Write-Output "[$(Get-Date)] Attempting to ingest gathered data to the OMS workspace with ID"
Write-Output $CustomerId
Write-Output ""

Post-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
Write-Output ""

Write-Output "Script executed"
Write-Output ""
Write-Output "*****************************************************************************************"
Write-Output ""
#endregion PostData
