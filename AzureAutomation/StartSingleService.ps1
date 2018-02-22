<#
This is example script which used for Azure Automation Runbook.
Create or add the script as a Runbook on Azure Portal or via PowerShell.
Test, Test, Test and ... guess what... Test again!:)
#>
[CmdletBinding()]
Param (
      
	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]		
        [string]$ServiceName,
	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
	[string]$ComputerName
		
)

Try {
    $ErrorActionPreference = "Stop"

    Write-Output ""
    Write-Verbose "[$(Get-Date)] Checking the status of the Service '$($ServiceName)' on the Computer '$($ComputerName)'"
    $Svc = Get-Service -Name $ServiceName -ComputerName $ComputerName 
    $SvcResult = $Svc | Select-Object Name, Status
    Write-Verbose "[$(Get-Date)] Output from the check is: $($SvcResult)"

        If ($Svc.Name -eq $ServiceName) {

            Write-Output "[$(Get-Date)] Starting the Service '$($ServiceName)'."
            Start-Service -InputObject $Svc
            Write-Output "[$(Get-Date)] The Service '$($ServiceName)' now in status '$((Get-Service -Name $ServiceName -ComputerName $ComputerName -EA SilentlyContinue).Status)'."

      }

    }

Catch {

     Write-Warning "[$(Get-Date)] There is an error during Runbook execution."
     Write-Warning "$($_.Exception.Message) The target Computer name is'$($ComputerName)'."
     Write-Output "Please, check if the names of the target Service and Computer are correct."

}
	
