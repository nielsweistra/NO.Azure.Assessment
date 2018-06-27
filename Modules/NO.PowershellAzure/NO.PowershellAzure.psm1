[CmdletBinding()]
param(
    
)
Get-ChildItem -Path $PSScriptRoot -Recurse -File | Unblock-File

class AzureRestServiceManager {
    
    [guid] $SubscriptionId = "8b32203d-d655-41b1-84a7-2f119b31dc8a"    
    [guid] $TenantId = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00"
    [guid] $ClientId = "a72ae51b-31a2-4e9a-b1df-bca4778f01ab"
    [string] $ClientSecret
    [string] $Resource = "https://management.core.windows.net/"
    [string] $TokenRequestUri = "https://login.microsoftonline.com/$($this.TenantId)/oauth2/token"
    [PSCustomObject] $Response = $null
    [PSCustomObject] $Token = $null  
    
    AzureRestServiceManager () {
        
    }

    AzureRestServiceManager ($SubscriptionId, $ClientId, $ClientSecret) {
        $this.ClientSecret = $ClientSecret
        $this.SubscriptionId = $SubscriptionId
        $this.ClientId = $ClientId
        
        $body = "grant_type=client_credentials&client_id=$($ClientId)&client_secret=$($ClientSecret)&resource=$($this.Resource)"
        $this.Token = Invoke-RestMethod -Method Post -Uri $this.TokenRequestUri -Body $body -ContentType 'application/x-www-form-urlencoded'

        Write-Verbose "Print Token"
        Write-Verbose $this.Token
    }

    [void] Get ([uri]$ApiUri) {
        $Headers = @{}
        $Headers.Add("Authorization","$($this.Token.token_type) "+ " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Get -Uri $ApiUri -Headers $Headers
    }

    [void] Put ([uri]$ApiUri,[string]$body) {
        $contentType = "application/json"  
        $Headers = @{}
        $Headers.Add("Authorization","$($this.Token.token_type) "+ " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Put -Uri $ApiUri -Headers $Headers -Body $body -ContentType $contentType
    }
}

function New-Secret  {
    Param (
    [parameter(Mandatory=$true)]
    $VaultName,
    [parameter(Mandatory=$true)]
    $Name,
    [parameter(Mandatory=$true)]
    $SecretValue
    )

    if(-not(Get-AzureKeyVaultSecret -vaultName $VaultName -name $Name)) {

        $secret = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $Name -SecretValue $SecretValue
        Write-Verbose (get-AzureKeyVaultSecret -vaultName $VaultName -name $Name).SecretValueText

    }
    
}

function Get-Secret {
    Param (
    [parameter(Mandatory=$true)]
    $VaultName,
    [parameter(Mandatory=$true)]
    $Name
    )

    if(Get-AzureKeyVaultSecret -vaultName $VaultName -name $Name) {

        $SecretVaulue = (get-AzureKeyVaultSecret -vaultName $VaultName -name $Name).SecretValueText
        Write-Verbose $SecretVaulue
    }
    return $SecretVaulue | Out-Null
}

function New-ServicePrincipal {
    Param(
    [parameter(Mandatory=$true)]
    [string]$DisplayName,
    [parameter(Mandatory=$true)]
    [securestring]$Password,
    [parameter(Mandatory=$true)]
    [string]$HomePage,
    [parameter(Mandatory=$true)]
    [string]$IdentifierUris
    )

    $azureAdApplication = New-AzureRmADApplication -DisplayName $DisplayName -HomePage $HomePage -IdentifierUris $IdentifierUris -Password $Password
    $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId

    Start-Sleep -s 15

    Write-Host "Assign Contributor Role to $($azureAdApplication.ApplicationId)"
    New-AzureRmRoleAssignment -RoleDefinitionName "Contributor" -ApplicationId $azureAdApplication.ApplicationId

    Write-Host "Assign Api Management Service Contributor Role to $($azureAdApplication.ApplicationId)"
    New-AzureRmRoleAssignment -RoleDefinitionName "Api Management Service Contributor" -ApplicationId $azureAdApplication.ApplicationId

    Write-Host "Assign Resource Policy Contributor (Preview) Role to $($azureAdApplication.ApplicationId)"
    New-AzureRmRoleAssignment -RoleDefinitionName "Resource Policy Contributor (Preview)" -ApplicationId $azureAdApplication.ApplicationId
    
    Write-Host "Application/Client ID: $($azureAdApplication.ApplicationId)"
    Write-Host "Object ID: $($azureAdApplication.ObjectID)"

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    Write-Host "Client Secret: $($ClientSecret)"
    
    return $servicePrincipal
}

function New-KeyVault {
    Param(
    [parameter(Mandatory=$true)]
    [string]$VaultName,
    [parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    [parameter(Mandatory=$true)]
    [string]$Region,
    [parameter(Mandatory=$true)]
    [string]$Company,
    [parameter(Mandatory=$true)]
    [string]$Enviroment,
    [parameter(Mandatory=$true)]
    [psobject]$ServicePrincipal 
    )

    $ObjectID = $ServicePrincipal.Where({$_.Type -eq "ServicePrincipal"}).ID.ToString()
    
    New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company=$Company; Enviroment=$Enviroment} -Force
    if (-not(Get-AzureRmKeyVault -VaultName $VaultName)) {

        New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup -Location $Region -EnabledForTemplateDeployment -Verbose 
    }

    Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $ResourceGroup -VaultName $VaultName -ObjectId $ObjectID -PermissionsToSecrets get, set -Verbose

    return $VaultName | Out-Null
}
function Set-AzurePolicy ($PolicyName, $SubscriptionID, $ApplicationID, $ClientSecret, $ResourceGroup) {

    $json =@'
    {
        "properties": {
            "displayName": "Allowed resources",
            "description": "This policy restrict the use of resources",
            "metadata": {
            "assignedBy": "Niels W."
            },
            "policyDefinitionId": "/subscriptions/8b32203d-d655-41b1-84a7-2f119b31dc8a/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c",
            "parameters": {
                "listOfResourceTypesAllowed": {
                    "value": [
                        "Microsoft.Compute/virtualMachines",
                        "Microsoft.Network/publicIPAddresses",
                        "Microsoft.Network/networkInterfaces"
                    ]
                }
            }
        }
    }
'@
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    $Secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    $AzurePolicyManager = [AzureRestServiceManager]::new($SubscriptionID, $ApplicationID, $Secret)
    $AzurePolicyManager.Put("https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Authorization/policyAssignments/$($PolicyName)?api-version=2018-03-01",$json)
   
}