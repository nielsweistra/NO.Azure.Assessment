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
        $Headers.Add("Authorization", "$($this.Token.token_type) " + " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Get -Uri $ApiUri -Headers $Headers
    }

    [void] Put ([uri]$ApiUri, [string]$body) {
        $contentType = "application/json"  
        $Headers = @{}
        $Headers.Add("Authorization", "$($this.Token.token_type) " + " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Put -Uri $ApiUri -Headers $Headers -Body $body -ContentType $contentType
    }
}

Function New-RandomKey() {

    $key = New-Object byte[](32)
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($key)

    return [System.Convert]::ToBase64String($key)
}

function New-AdminPassword ($Length) {
    If (-not($Length)) {
        $Length = 16
    }
    $Password = ConvertTo-SecureString $(([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..16 | Sort-Object {Get-Random})[0..$Length] -join '') -AsPlainText -Force 
 
    return $Password
}

function New-Secret {
    Param (
        [parameter(Mandatory = $true)] [string] $VaultName,
        [parameter(Mandatory = $true)] [string] $Name,
        [parameter(Mandatory = $true)] [securestring] $SecretValue
    )

    if (-not(Get-AzureKeyVaultSecret -vaultName $VaultName -name $Name)) {

        $Secret = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $Name -SecretValue $SecretValue
        Write-Verbose (get-AzureKeyVaultSecret -vaultName $VaultName -name $Name).SecretValueText

    }
    return $Secret
}

function Get-Secret {
    Param (
        [parameter(Mandatory = $true)] $VaultName,
        [parameter(Mandatory = $true)] $Name
    )

    if (Get-AzureKeyVaultSecret -vaultName $VaultName -name $Name) {

        $SecretValue = (get-AzureKeyVaultSecret -vaultName $VaultName -name $Name).SecretValueText
        Write-Verbose $SecretValue
    }
    return $SecretValue
}

function New-AzureKeyVault {
    Param(
        [parameter(Mandatory = $true)] [string]$TenantID,
        [parameter(Mandatory = $true)] [string]$SubscriptionID,
        [parameter(Mandatory = $true)] [string]$ResourceGroup,
        [parameter(Mandatory = $true)] [string]$VaultName,
        [parameter(Mandatory = $true)] [string]$Region,
        [parameter(Mandatory = $true)] [string]$Company,
        [parameter(Mandatory = $true)] [string]$Enviroment,
        [parameter(Mandatory = $true)] [string]$ServicePrincipalName
    )

    $ClientSecret = ConvertTo-SecureString $( -join (0..64| ForEach-Object {[char][int]((65..90) + (97..122)  | Get-Random)})) -AsPlainText -Force
    $AdminPassword = New-AdminPassword -Length 12

    $creds = Get-Credential -Message "Login with a Microsoft or Work account"
    Login-AzureRmAccount -TenantId $TenantID -Credential $creds
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID

    Write-Host "Creating Service Principal $($ServicePrincipalName) for the deployment of the ARM template, making calls to the REST Api and Managing Azure Policies."
    $ServicePrincipal = New-ServicePrincipal -Password $ClientSecret -DisplayName $ServicePrincipalName -HomePage "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))" -IdentifierUris "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}))"
    
    Write-Host "Creating Azure Key Vault $($VaultName) in $($ResourceGroup) and authorize the Service Principal $($ServicePrincipalName) to get and set secrets"
    New-KeyVault -VaultName $VaultName -ResourceGroup $ResourceGroup -Region $Region -Company $Company -Enviroment $Enviroment -ServicePrincipal $ServicePrincipal

    Write-Host "Saving ClientSecret to the Azure Key Vault" 
    New-Secret -VaultName $VaultName -Name $ServicePrincipalName -SecretValue $ClientSecret | out-Null

    Write-Host "Saving AdminPassword to the Azure Key Vault"
    New-Secret -VaultName $VaultName -Name "LocalAdmin" -SecretValue $AdminPassword | Out-Null
    
}

function Start-AzureARMDeployment {
    Param(
        [parameter(Mandatory = $true)] [string]$TenantID,
        [parameter(Mandatory = $true)] [string]$SubscriptionID,
        [parameter(Mandatory = $false)] [securestring]$AdminPassword,
        [parameter(Mandatory = $true)] [string]$ServicePrincipal,
        [parameter(Mandatory = $true)] [securestring]$ServicePrincipalPassword,
        [parameter(Mandatory = $false)] [string]$ResourceGroup = "NO_RG",
        [parameter(Mandatory = $false)] [string]$Region = "WestEurope", 
        [parameter(Mandatory = $false)] [string]$ArmTemplate = ".\Templates\azuredeploy.json",
        [parameter(Mandatory = $false)] [string]$ArmTemplateParameters = ".\Templates\azuredeploy.parameters.json",
        [parameter(Mandatory = $false)] [string]$Company = "NO",
        [parameter(Mandatory = $false)] [string]$Enviroment = "Test",
        [parameter(Mandatory = $false)] [string]$DeployLabel
    )

    $DeployLabel = "$($ResourceGroup)_$($Enviroment)_$(Get-Date -Date (Get-Date -format "dd-MMM-yyyy HH:mm") -UFormat %s)"

    $spCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal, $ServicePrincipalPassword)
    Add-AzureRmAccount -Credential $spCred -ServicePrincipal -TenantId $TenantID

    Select-AzureRmSubscription -SubscriptionId $SubscriptionID

    New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company = $Company; Enviroment = $Enviroment} -Force
    New-AzureRmResourceGroupDeployment -Name $DeployLabel -ResourceGroupName $ResourceGroup -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters -Company $Company -AdminPassword $AdminPassword -AsJob -Verbose -Force
    Set-AzurePolicyResourceGroup -PolicyName "Allowed Resources in ResourceGroup" -SubscriptionID $SubscriptionID -ApplicationID $ServicePrincipal -ClientSecret $ServicePrincipalPassword -ResourceGroup $ResourceGroup
    Set-AzurePolicySubscription -PolicyName "AllowedResources in Subscription" -SubscriptionID $SubscriptionID -ApplicationID $ServicePrincipal -ClientSecret $ServicePrincipalPassword
    
}
function New-ServicePrincipal {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] [string]$DisplayName,
        [parameter(Mandatory = $true)] [securestring]$Password,
        [parameter(Mandatory = $true)] [string]$HomePage,
        [parameter(Mandatory = $true)] [string]$IdentifierUris
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
        [parameter(Mandatory = $true)] [string]$VaultName,
        [parameter(Mandatory = $true)] [string]$ResourceGroup,
        [parameter(Mandatory = $true)] [string]$Region,
        [parameter(Mandatory = $true)] [string]$Company,
        [parameter(Mandatory = $true)] [string]$Enviroment,
        [parameter(Mandatory = $true)] [psobject]$ServicePrincipal 
    )

    $ObjectID = $ServicePrincipal.Where( {$_.Type -eq "ServicePrincipal"}).ID.ToString()
    
    New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company = $Company; Enviroment = $Enviroment} -Force
    if (-not(Get-AzureRmKeyVault -VaultName $VaultName)) {

        $KeyVault = New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup -Location $Region -EnabledForTemplateDeployment -Verbose 
    }

    Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $ResourceGroup -VaultName $VaultName -ObjectId $ObjectID -PermissionsToSecrets get, set -Verbose

    return $KeyVault
}

function Set-AzurePolicyResourceGroup ($PolicyName, $SubscriptionID, $ApplicationID, $ClientSecret, $ResourceGroup) {
    [CmdletBinding()]

    $json = @'
    {
        "properties": {
            "displayName": "Allowed resources ResourceGroup",
            "description": "This policy restrict the use of resources within the ResourceGroup",
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
    $AzurePolicyManager.Put("https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Authorization/policyAssignments/$($PolicyName)?api-version=2018-03-01", $json)
   
}

function Set-AzurePolicySubScription ($PolicyName, $SubscriptionID, $ApplicationID, $ClientSecret) {
    [CmdletBinding()]

    $json = @'
    {
        "properties": {
            "displayName": "Allowed resources Subscription",
            "description": "This policy restrict the use of resources within the Subscription",
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
    $AzurePolicyManager.Put("https://management.azure.com/subscriptions/$($SubscriptionID)/providers/Microsoft.Authorization/policyAssignments/$($PolicyName)?api-version=2018-03-01", $json)
   
}