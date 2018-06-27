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

    $RandomPassword = -join(0..64|%{[char][int]((65..90) + (97..122)  | Get-Random)})
    $Password = ConvertTo-SecureString $RandomPassword -AsPlainText -Force

    $creds = Get-Credential
    Login-AzureRmAccount -TenantId $TenantID -Credential $creds
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    $ServicePrincipal = New-ServicePrincipal -Password $Password -DisplayName $ServicePrincipalName -HomePage "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))" -IdentifierUris "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))"
    
    New-KeyVault -VaultName $VaultName -ResourceGroup $ResourceGroup -Region $Region -Company $Company -Enviroment $Enviroment -ServicePrincipal $ServicePrincipal
    New-Secret -VaultName $VaultName -Name $ServicePrincipalName -SecretValue $Password
    Get-Secret -VaultName $VaultName -Name $ServicePrincipalName