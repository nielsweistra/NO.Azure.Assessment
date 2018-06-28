Using module ".\Modules\NO.PowershellAzure\NO.PowershellAzure.psm1"
[CmdletBinding()]
Param (
    [parameter(Mandatory=$false)] $TenantID = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00",
    [parameter(Mandatory=$false)] $SubscriptionID = "8b32203d-d655-41b1-84a7-2f119b31dc8a",
    [parameter(Mandatory=$false)] $VaultRG = "Org_Vault_RG",
    [parameter(Mandatory=$false)] $VaultName = "OrgVault",
    [parameter(Mandatory=$false)] $RG = "Org_RG",
    [parameter(Mandatory=$false)] $Company = "Org",
    [parameter(Mandatory=$false)] $Region = "WestEurope",
    [parameter(Mandatory=$false)] $Enviroment = "Test",
    [parameter(Mandatory=$false)] $ServicePrincipalName = "$($Company)SP$(Get-Date -Date (Get-Date -format "dd-MMM-yyyy HH:mm") -UFormat %s)"
)

Write-Host "Start deploying Azure Key Fault" -ForegroundColor Green
Install-Requirements -TenantID $TenantID -SubscriptionID $SubscriptionID -ResourceGroup $VaultRG -Company $Company -Enviroment $Enviroment -ServicePrincipalName $ServicePrincipalName -VaultName $VaultName -Region $Region

$ServicePrincipal = Get-AzureRmADServicePrincipal -DisplayName $ServicePrincipalName
$ClientSecret = ConvertTo-SecureString (Get-Secret -VaultName $VaultName -Name $ServicePrincipalName) -AsPlainText -Force

If ($ClientSecret -and $ServicePrincipal) {
    $spCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal.ApplicationId, $ClientSecret)
}
else {
    $spCred = Get-Credential -Message "Login with your Service Principal credentials"
}

$yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "help"
$no = new-Object System.Management.Automation.Host.ChoiceDescription "&No", "help"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$answer = $host.ui.PromptForChoice("Deploy Azure Template", "Are you sure?", $choices, 0)

switch ($answer) {
    0 {
        Write-Host "Get ClientSecret from Vault"
        $AdminPassword = ConvertTo-SecureString (Get-Secret -VaultName $VaultName -Name "LocalAdmin") -AsPlainText -Force
        Start-AzureARMDeployment -TenantID $TenantID -SubscriptionID $SubscriptionID -ResourceGroup $RG -ServicePrincipal $spCred.UserName -ServicePrincipalPassword $spCred.Password -AdminPassword $AdminPassword -Company $Company -Enviroment $Enviroment
        
    }
    1 {
        "Exiting..."; break
    }
}

Write-Host "The password that is used for setting the AdminPassword is saved as a secret in Azure Key Vault"
Read-Host -Prompt "Press any key to cleanup this demo or CTRL+C to quit" 

Remove-AzureRmResourceGroup -Name $VaultRG -Force -AsJob
Remove-AzureRmResourceGroup -Name $RG -Force -AsJob

Write-Host "Jobs are running for cleaning up this demo. Thanks for using this demo!"