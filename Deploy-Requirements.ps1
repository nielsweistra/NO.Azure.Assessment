[CmdletBinding()]
Param(
    [string]$TenantID = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00",
    [string]$SubscriptionID = "8b32203d-d655-41b1-84a7-2f119b31dc8a",
    [string]$ResourceGroup = "NO_Vault_RG",
    [string]$Region = "WestEurope",
    [string]$Company = "NO",
    [string]$Enviroment = "Test"
)
function New-KeyVault {
    Param(
    [string]$ResourceGroup,
    [string]$Region,
    [string]$Company,
    [string]$Enviroment,
    [string]$ServicePrincipalName 
    )

    $RandomPassword = ConvertTo-SecureString (([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | Sort-Object {Get-Random})[0..16] -join '') -AsPlainText -Force
    $VaultName = "$($Company)Vault"

    New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company=$Company; Enviroment=$Enviroment} -Force
    if (-not(Get-AzureRmKeyVault -VaultName $VaultName)) {

        New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup -Location $Region -EnabledForTemplateDeployment -Verbose
        Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $ResourceGroup -VaultName $VaultName  -PermissionsToSecrets get, set -Verbose

        if(-not(Get-AzureKeyVaultSecret -vaultName $VaultName -name "LocalAdmin")) {
            $secret = Set-AzureKeyVaultSecret -VaultName $VaultName -Name "LocalAdmin" -SecretValue $RandomPassword
            Write-Host (get-azurekeyvaultsecret -vaultName $VaultName -name "LocalAdmin").SecretValueText
            Start-Sleep -Seconds 10
        }
    }
}

function New-ServicePrincipal{
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

    Start-Sleep -s 10

    New-AzureRmRoleAssignment -RoleDefinitionName "Contributor" -ApplicationId $azureAdApplication.ApplicationId
    New-AzureRmRoleAssignment -RoleDefinitionName "Api Management Service Contributor" -ApplicationId $azureAdApplication.ApplicationId
    New-AzureRmRoleAssignment -RoleDefinitionName "Resource Policy Contributor (Preview)" -ApplicationId $azureAdApplication.ApplicationId
    

    Write-Host "Client ID: $($azureAdApplication.ApplicationId)"
    Write-Host "Object ID: $($azureAdApplication.ObjectID)"

    if(-not([string]::IsNullOrEmpty($RandomPassword))){
        Write-Host "Random password created: $($Password)"
    }
    
    return $azureAdApplication
}

function Main {

    $RandomPassword = ([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | Sort-Object {Get-Random})[0..32] -join ''
    $Password = ConvertTo-SecureString $RandomPassword -AsPlainText -Force

    $creds = Get-Credential
    Login-AzureRmAccount -TenantId $TenantID -Credential $creds
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    
    
    $KeyVaultSP = New-ServicePrincipal -Password $Password -DisplayName "$($Company)_SP_$([GUID]::NewGuid())" -HomePage "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))" -IdentifierUris "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))"
    New-KeyVault -ResourceGroup $ResourceGroup -Region $Region -Company $Company -Enviroment $Enviroment -ServicePrincipalName $KeyVaultSP.DisplayName[0]

    Assign-AzurePolicy
}

Main