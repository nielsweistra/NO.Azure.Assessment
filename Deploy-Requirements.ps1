Using module ".\Modules\NO.PowershellAzure\NO.PowershellAzure.psm1"
[CmdletBinding()]
Param(
    [string]$TenantID = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00",
    [string]$SubscriptionID = "8b32203d-d655-41b1-84a7-2f119b31dc8a",
    [string]$ResourceGroup = "NO_Vault_RG",
    [string]$VaultName = "NOVault",
    [string]$Region = "WestEurope",
    [string]$Company = "NO",
    [string]$Enviroment = "Test",
    [string]$ServicePrincipalName = "$($Company)_SP_$([GUID]::NewGuid())"
)

function Main {

    $RandomPassword = ([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | Sort-Object {Get-Random})[0..32] -join ''
    $Password = ConvertTo-SecureString $RandomPassword -AsPlainText -Force

    $creds = Get-Credential
    Login-AzureRmAccount -TenantId $TenantID -Credential $creds
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    
    $ServicePrincipal = New-ServicePrincipal -Password $Password -DisplayName $ServicePrincipalName -HomePage "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))" -IdentifierUris "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))"
    
    New-KeyVault -VaultName $VaultName -ResourceGroup $ResourceGroup -Region $Region -Company $Company -Enviroment $Enviroment -ServicePrincipalName $ServicePrincipal.DisplayName[0]
    New-Secret -VaultName $VaultName -Name $ServicePrincipalName -SecretValue $RandomPassword
    Get-Secret -VaultName $VaultName -Name $ServicePrincipalName -SecretValue $RandomPassword
    
}

Main