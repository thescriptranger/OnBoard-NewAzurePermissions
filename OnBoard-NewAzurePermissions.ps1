Function OnBoard-NewAzurePermission {
    <#
    .SYNOPSIS
        Automates the onboarding process for new Azure users by granting necessary permissions based on their position and client assignment.

    .DESCRIPTION
        This function is designed to streamline the process of granting Azure permissions to new employees. 
        Based on the employee's position and the client they are assigned to, the function reads from a specific CSV file that contains the required 
        Azure resources, roles, and optionally, resource groups that the employee needs access to. The function then assigns the specified roles 
        to the employee for the appropriate Azure resources within a given subscription.

        The function is versatile and covers a wide range of Azure resources including Virtual Machines, Storage Accounts, App Services, Key Vaults, 
        Azure SQL Databases, Cosmos DB, AKS, Log Analytics, and more. The role assignments are performed securely and logged for auditing purposes.

    .PARAMETER UserPrincipalName
        The User Principal Name (UPN) of the employee. This is typically their email address and is used to identify the user in Azure Active Directory.

    .PARAMETER Position
        The position or role of the employee within the company (e.g., Developer, Administrator, DevOps). This parameter is used to determine which 
        CSV file to read for the appropriate permissions.

    .PARAMETER Client
        The client the employee will be working for. This parameter, combined with the Position parameter, determines the correct CSV file that 
        specifies the Azure resources and roles to be assigned.

    .PARAMETER SubscriptionId
        The Azure subscription ID where the resources are located. The function will scope the role assignments to this subscription.

    .EXAMPLE
        OnBoard-NewAzurePermission -UserPrincipalName "jane.doe@company.com" -Position "Developer" -Client "ClientA" -SubscriptionId "00000000-0000-0000-0000-000000000000"
        
        This example onboards a new developer, Jane Doe, who will be working for ClientA. The function looks for a CSV file named 
        "ClientA-Developer-Permissions.csv" and grants Jane the necessary Azure permissions for resources specified in that file under the given 
        subscription.

    .EXAMPLE
        OnBoard-NewAzurePermission -UserPrincipalName "john.smith@company.com" -Position "DevOps" -Client "ClientB" -SubscriptionId "11111111-1111-1111-1111-111111111111"
        
        This example onboards John Smith as a DevOps engineer for ClientB. The function assigns roles to John for various Azure resources 
        as specified in the "ClientB-DevOps-Permissions.csv" file within the provided subscription.

    .EXAMPLE
        OnBoard-NewAzurePermission -UserPrincipalName "alice.jones@company.com" -Position "Administrator" -Client "ClientC" -SubscriptionId "22222222-2222-2222-2222-222222222222"
        
        This example onboards Alice Jones as an Administrator for ClientC. The function grants her the necessary permissions for managing 
        resources within the Azure subscription as specified in the "ClientC-Administrator-Permissions.csv" file.

    .NOTES
        Name: OnBoard-NewAzurePermission
        Author: Script Ranger
        Version: 1.0
        DateCreated: 2024.08.26
     
    .LINK
        https://github.com/thescriptranger/OnBoard-NewAzurePermissions
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string] $UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [string] $Position,

        [Parameter(Mandatory = $true)]
        [string] $Client,

        [Parameter(Mandatory = $true)]
        [string] $SubscriptionId
    )

    BEGIN {
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

        $myRootPath = $PSScriptRoot
        $myFunctionName = $MyInvocation.MyCommand.Name

        Push-Location $myRootPath

        $logFile = Join-Path -Path "$myRootPath\_log" -ChildPath "$((Get-Date).ToString('yyyy.MM.dd.HHmmss')).$myFunctionName.log"
        # Change or Remove output file as needed
        $outputFile = Join-Path -Path "$myRootPath\_output" -ChildPath "$((Get-Date).ToString('yyyy.MM.dd.HHmmss')).$myFunctionName.csv"
        $configFile = "$myFunctionName.xml"

        Start-Transcript -Path $logFile

        if (Test-Path $configFile) {
            [xml]$settings = Get-Content $configFile
            # Process configuration settings if needed
            $environment = $settings.configuration.variables.Environment
        }

        # Load child function scripts.  This will bring all variables and objects into the same scope.
        Get-ChildItem -Path "$myRootPath\_function" -Filter "*.ps1" -Recurse -Verbose | ForEach-Object { . $_ }

        # Import the Az module if not already loaded
        if (-not (Get-Module -ListAvailable -Name Az)) {
            Import-Module Az
        }
    }

    PROCESS {
        # Function to grant access to a resource
        function Grant-AccessToResource {
            param (
                [Parameter(Mandatory=$true)]
                [string]$ResourceType,

                [Parameter(Mandatory=$true)]
                [string]$ResourceName,

                [Parameter(Mandatory=$true)]
                [string]$Role,

                [Parameter(Mandatory=$true)]
                [string]$UserPrincipalName,

                [Parameter(Mandatory=$true)]
                [string]$SubscriptionId,

                [Parameter(Mandatory=$true)]
                [string]$ResourceGroupName = $null
            )

            # Get the user
            $user = Get-AzADUser -UserPrincipalName $UserPrincipalName

            if ($null -eq $user) {
                Write-Error "User '$UserPrincipalName' not found."
                return
            }

            # Assign the role based on resource type
            switch ($ResourceType) {
                "ResourceGroup" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -ResourceGroupName $ResourceName
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on resource group '$ResourceName'."
                }
                "StorageAccount" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on storage account '$ResourceName'."
                }
                "VirtualMachine" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on virtual machine '$ResourceName'."
                }
                "AppService" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on app service '$ResourceName'."
                }
                "AzureFunction" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$ResourceName/functions"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Azure function '$ResourceName'."
                }
                "KeyVault" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on key vault '$ResourceName'."
                }
                "AzureSQLDatabase" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Azure SQL Database '$ResourceName'."
                }
                "CosmosDB" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DocumentDB/databaseAccounts/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Cosmos DB account '$ResourceName'."
                }
                "AKS" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on AKS cluster '$ResourceName'."
                }
                "LogAnalytics" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Log Analytics workspace '$ResourceName'."
                }
                "APIManagement" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on API Management service '$ResourceName'."
                }
                "ServiceBus" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ServiceBus/namespaces/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Service Bus namespace '$ResourceName'."
                }
                "AzureSynapseAnalytics" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Synapse/workspaces/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Synapse Analytics workspace '$ResourceName'."
                }
                "DataFactory" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Data Factory '$ResourceName'."
                }
                "AzureBastion" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/bastionHosts/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Azure Bastion host '$ResourceName'."
                }
                "ContainerRegistry" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Container Registry '$ResourceName'."
                }
                "Network" {
                    New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$ResourceName"
                    Write-Output "Granted '$Role' role to '$UserPrincipalName' on Virtual Network '$ResourceName'."
                }
                default {
                    Write-Error "Unknown resource type: $ResourceType"
                }
            }
        }

        # Determine the correct CSV file based on position and client
        $csvFilePath = Join-Path -Path "$myRootPath\Permissions" -ChildPath "$Client-$Position-Permissions.csv"

        if (-Not (Test-Path $csvFilePath)) {
            Write-Error "CSV file for '$Client - $Position' not found at path '$csvFilePath'."
            return
        }

        # Import CSV file
        $employeeData = Import-Csv -Path $csvFilePath

        foreach ($row in $employeeData) {
            $ResourceType = $row.ResourceType
            $ResourceName = $row.ResourceName
            $Role = $row.Role
            $ResourceGroupName = $row.ResourceGroupName

            Grant-AccessToResource -ResourceType $ResourceType -ResourceName $ResourceName -Role $Role -UserPrincipalName $UserPrincipalName -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
        }
    }

    END {
        $stopWatch.Stop()
        Write-Output "$myFunctionName Completed"
        Write-Output $stopWatch.Elapsed
        Stop-Transcript
        Pop-Location
    }
}
