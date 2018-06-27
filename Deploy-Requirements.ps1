Using module ".\Modules\NO.PowershellAzure\NO.PowershellAzure.psm1"
[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)]
    [string]$TenantID,
    [parameter(Mandatory=$true)]
    [string]$SubscriptionID,
    [parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    [parameter(Mandatory=$true)]
    [string]$VaultName,
    [parameter(Mandatory=$true)]
    [string]$Region,
    [parameter(Mandatory=$true)]
    [string]$Company,
    [parameter(Mandatory=$true)]
    [string]$Enviroment,
    [parameter(Mandatory=$true)]
    [string]$ServicePrincipalName
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