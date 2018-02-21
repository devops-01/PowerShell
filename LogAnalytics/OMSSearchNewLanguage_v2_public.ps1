<#
<# Introduction to the script
****************************************************************************************** 
*
*                             [ Author ]
*
* Author: Alexey Baltikov
* Email: baltikov@gmail.com
* Version: 1.0
* Date: 04.10.2017
*
*
****************************************************************************************** 
*
*                            [ Overview ]   
*                                                                                      
* This Script is used to run query based on the New Azure Log Analytics query language.
* The script result is PSObjects array without blank fields.
*
* Fill the variables in the script body or convert them to parameters.
*
* To run this script there are few requirements:
* 1) Script relied on the 'LogAnalyticsQuery' PowerShell module available by the link
* https://dev.loganalytics.io/documentation/Tools/PowerShell-Cmdlets
* 2) Script based on the new query language.
* 3) Script based on PowerShell v3 (minimal version).
* 4) Prior running query, login to Azure in PowerShell session (Login-AzureRMAccount). 
* There is a function in the script for the Azure login purpose. If needed to use it, 
* , fill '$AzureUser' and '$AzurePassword' variables. Azure user account should have
* proper access control role assignment (for example, 'Log Analytics Reader').  
* If the variables will be blank, then script will run query without attempting to login.
* 5) Query can be assigned as a here string to the '$query' variable.      
*
****************************************************************************************** 
*
*                      [ Script usage example ]
*
* $searchResults = .\OMSSearchNewLanguage.ps1
* $searchResults
* 
****************************************************************************************** 
#>

#region Variables

# Starting point
Clear-Host

# Define a Log Analytics query as a here-string or as a string in one line
 $query = 'SharedFolderStatus_CL'
<#$query = @'
search * 
| top 10 by TimeGenerated 
'@
#>

# Log Analytics workspace ID            
$workspaceId = "OMS-JUMPSTART-RU"

# Azure subscription ID where Log Analytics workspace resides
$subscriptionId = "fa2c094f-203f-4295-980f-1fd80d72a495"

# Resource group where Log Analytics workspace resides
$resourceGroup = "OMS-JUMPSTART"

# Azure user to login via Azure RM
$AzureUser = 'LAQueryUser@omstraining.onmicrosoft.com'

# Azure user's password to login via Azure RM
$AzurePassword = 'Kapa6172_1'

# Results objects array
$Results = @()

#endregion Variables

#region Functions

# Function for Azure RM authentication (example)
function Login-AzureLASearch {

    param (

     $UserID,
     $Password

    )

    # Convert Azure user's password to secure string
    $Password = ConvertTo-SecureString -String "$Password" -AsPlainText -Force
    $Creds = New-Object -TypeName System.Management.Automation.PSCredential($UserID, $Password)

    # Actual Azure login
    $Login = Login-AzureRmAccount -Credential $Creds -ErrorAction Stop

}
#endregion Functions

#region 'LogAnalyticsQuery' module check
    
    try {

    # Check if module 'LogAnalyticsQuery' available
    $laModule = Get-Module -ListAvailable

        if ($laModule.Name -notcontains 'LogAnalyticsQuery'){

            throw "[$(Get-Date)] Seems Log Analytics module is not available."

        }
    }
    catch{

        Write-Output ""
        Write-Output $_.Exception.Message
        Write-Output ""
        exit

    }

#endregion 'LogAnalyticsQuery' module check

#region Azure Authentication

# Checking if 'AzureUser' and 'AzurePassword' variables are not empty, then login to Azure
if (!([string]::IsNullOrEmpty($AzureUser)) -and !([string]::IsNullOrEmpty($AzurePassword))) {

  try {

      Login-AzureLASearch -UserID $AzureUser -Password $AzurePassword

  }
  catch{

        Write-Output ""
        Write-Output "[$(Get-Date)] Seems there is a problem with Azure login."
        Write-Output "See the error description below"
        Write-Warning "Script will be stopped!"
        Write-Warning $_.Exception.Message
        Write-Output ""
        exit

    }
}
#endregion Azure Authentication

#region Running Query

# Running query

Try {
$OMSsearch = Invoke-LogAnalyticsQuery -WorkspaceName $workspaceId `
                                      -SubscriptionId $subscriptionId `
                                      -ResourceGroup $resourceGroup `
                                      -Query $query `
                                      -ErrorAction Stop
                                      
    $objects = $OMSsearch.Results

    # Removing empty fields
    Foreach ($obj in $objects)
    { 
      # Defining a hash table
      $hTable = @{}

      # Getting properties of each record in results set
      $Properties = $obj.psobject.Properties

      # Filtering for only fileds with values
      $objResults = $Properties | Select Name, Value | where {!([string]::IsNullOrEmpty($_.Value))}

      # Adding to the hash table fields with values
      foreach ($Property in $objResults){
   
       $hTable.Add($Property.Name, $Property.Value)

      }

      # Creating PSObject for each record with filled values
      $Object = New-Object -TypeName PSObject -Property $hTable

      # Put each record object to the final result objects array
      $Results += $Object 
    }

    # Returning the results as PSObjects array
    $Results

}
catch{

    Write-Output ""
    Write-Output "[$(Get-Date)] Seems there is a problem with Log Analytics query."
    Write-Output "See the error description below"
    Write-Warning "Script will be stopped!"
    Write-Warning $_.Exception.Message
    Write-Output ""
    exit
}

#endregion Running Query 


