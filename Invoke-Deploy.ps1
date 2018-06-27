Using module ".\Modules\NO.PowershellAzure\NO.PowershellAzure.psm1"
[CmdletBinding()]

$ServicePrincipal = "a72ae51b-31a2-4e9a-b1df-bca4778f01ab"
$TenantID = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00"
$SubscriptionID = "8b32203d-d655-41b1-84a7-2f119b31dc8a"
$VaultRG = "Org_Vault_RG"
$VaultName = "OrgVault"
$RG = "Org_RG"
$Company = "Org"
$Region = "WestEurope"
$Enviroment = "Test"
$ServicePrincipalName = "$($Company)SP$(Get-Date -Date (Get-Date -format "dd-MMM-yyyy HH:mm") -UFormat %s)"
$ServicePrincipalPassword = $null
$RandomPassword = -join(0..64|%{[char][int]((65..90) + (97..122)  | Get-Random)})

$VMpassword = ConvertTo-SecureString $RandomPassword -AsPlainText -Force

.\Deploy-Requirements.ps1 -TenantID $TenantID -SubscriptionID $SubscriptionID -ResourceGroup $VaultRG -Company $Company -Enviroment $Enviroment -ServicePrincipalName $ServicePrincipalName -VaultName $VaultName -Region $Region

Write-Host -Message "Retrieve secret from Vault"
$ServicePrincipalPassword = Get-Secret -VaultName $VaultName -Name $ServicePrincipalName

If ($ServicePrincipalPassword) {
    $spCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal, $ServicePrincipalPassword)
}
else {
    $spCred = Get-Credential -Message "Enter your password" -UserName $ServicePrincipal
}

$yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "help"
$no = new-Object System.Management.Automation.Host.ChoiceDescription "&No", "help"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$answer = $host.ui.PromptForChoice("Deploy Azure Template", "Are you sure?", $choices, 0)

switch ($answer) {
    0 {
        .\Deploy-AzureTemplate.ps1 -TenantID $TenantID -SubscriptionID $SubscriptionID -ResourceGroup $RG -ServicePrincipal $spCred.UserName -ServicePrincipalPassword $spCred.Password -AdminPassword $VMPassword -Company $Comapny -Enviroment $Enviroment
        
    }
    1 {
        "Exiting..."; break
    }
}

Write-Host "The password that is used for setting the AdminPassword is saved as a secret the Azure Key Vault"
Read-Host -Prompt "Press any key to cleanup this demo or CTRL+C to quit" 

Remove-AzureRmResourceGroup -Name $VaultRG -Force -AsJob
Remove-AzureRmResourceGroup -Name $RG -Force -AsJob

Write-Host "Jobs are running for cleaning up this demo. Thanks for using this demo!"