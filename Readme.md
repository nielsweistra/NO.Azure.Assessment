# NO.Azure.Assessment

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnielsweistra%2FNO.Azure.Assessment%2Fmaster%2FTemplates%2Fazuredeploy.json)

### Installation

```ps
 Invoke-deploy.ps1 `
 -TenantID "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00" `
 -SubscriptionID "8b32203d-d655-41b1-84a7-2f119b31dc8a" `
 -Region "WestEurope" `
 -VaultRG "Org_Vault_RG" `
 -VaultName "OrgVault" `
 -RG "Org_RG" `
 -Company "Org" `
 -Enviroment "Test" `
 -ServicePrincipalName "OrgSP" `
```

### What this script does
  - Create a Service Principal used for deploying the Azure Resource Manager Template
  - Assign Roles to the Service Principal
  - Create Resourcegroup for deploying the Azure Key Vault
  - Deploy Azure Key Vault
  - Save ClientSecret in Azure Key Vault
  - Generate AdminPassword and save it to Azure Key Vault
  - Deploy Azure Resource Manager Template  