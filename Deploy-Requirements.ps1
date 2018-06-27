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

    Write-Host "Creating Service Principal $($ServicePrincipalName) for the deployment of the ARM template, making calls to the REST Api and Managing Azure Policies."
    $ServicePrincipal = New-ServicePrincipal -Password $Password -DisplayName $ServicePrincipalName -HomePage "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))" -IdentifierUris "http://$(-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))"
    
    Write-Host "Creating Azure Key Vault $($VaultName) in $($ResourceGroup) and authorize the Service Principal $($ServicePrincipalName) to get and set secrets"
    New-KeyVault -VaultName $VaultName -ResourceGroup $ResourceGroup -Region $Region -Company $Company -Enviroment $Enviroment -ServicePrincipal $ServicePrincipal

    Write-Host "Save the ClientSecret to the Azure Key Vault created in the previous step" 
    New-Secret -VaultName $VaultName -Name $ServicePrincipalName -SecretValue $Password
    Get-Secret -VaultName $VaultName -Name $ServicePrincipalName