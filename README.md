# OnBoard-NewAzurePermission PowerShell Script

## Overview

The `OnBoard-NewAzurePermission` PowerShell script automates the process of onboarding new Azure users by granting the necessary permissions based on their position within the company and the client they are assigned to. This script reads from a CSV file that defines the Azure resources, roles, and resource groups the user needs access to, and then assigns the appropriate roles within the specified Azure subscription.

## Features

- **Dynamic Role Assignment**: Grants Azure roles based on resource type, user position, and client.
- **Support for Multiple Azure Resources**: Including Virtual Machines, Storage Accounts, App Services, Key Vaults, SQL Databases, Cosmos DB, AKS, Log Analytics, and more.
- **Secure and Logged**: The process is securely executed with detailed logging for auditing purposes.
- **Customizable**: Easily extend the script to include additional resource types or specific permissions as needed.

## Prerequisites

- PowerShell 5.1 or later
- Azure PowerShell module (`Az` module)
- Appropriate permissions to assign roles within your Azure subscription

## Installation

1. Clone this repository to your local machine using the following command:
    ```bash
    git clone https://github.com/YourUsername/YourRepositoryName.git
    ```
2. Navigate to the directory containing the script:
    ```bash
    cd YourRepositoryName
    ```
3. Ensure that you have the required `Az` PowerShell module installed:
    ```powershell
    Install-Module -Name Az -AllowClobber -Force
    ```

## Usage

To onboard a new user, run the following command in PowerShell:

```powershell
OnBoard-NewAzurePermission -UserPrincipalName "jane.doe@company.com" -Position "Developer" -Client "ClientA" -SubscriptionId "00000000-0000-0000-0000-000000000000"

### This command will:

- Look for a CSV file named `ClientA-Developer-Permissions.csv`
- Grant the specified roles to the user `jane.doe@company.com` within the Azure subscription `00000000-0000-0000-0000-000000000000`.

### Example CSV Files

Here are some example CSV files that the script would consume:

#### `ClientA-Developer-Permissions.csv`
```csv
ResourceType,ResourceName,Role,ResourceGroupName
ResourceGroup,ResourceGroup1,Contributor,
VirtualMachine,VM1,Reader,ResourceGroup1
StorageAccount,StorageAccount1,Storage Blob Data Contributor,ResourceGroup1
AppService,MyAppService,Contributor,ResourceGroup1

