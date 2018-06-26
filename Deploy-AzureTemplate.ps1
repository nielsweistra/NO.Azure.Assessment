Using module ".\AzureRestServiceManager.psm1"
[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)]
    [string]$TenantID,
    [parameter(Mandatory=$true)]
    [string]$SubscriptionID,
    [parameter(Mandatory=$true)]
    [securestring]$AdminPassword,
    [parameter(Mandatory=$true)]
    [string]$ServicePrincipal,
    [parameter(Mandatory=$true)]
    [securestring]$ServicePrincipalPassword,
    [parameter(Mandatory=$false)]
    [string]$ResourceGroup = "NO_RG",
    [string]$Region = "WestEurope",
    [string]$ArmTemplate = ".\Templates\azuredeploy.json",
    [string]$ArmTemplateParameters = ".\Templates\azuredeploy.parameters.json",
    [string]$Company = "NO",
    [string]$Enviroment = "Test",
    [string]$DeployLabel
)

$DeployLabel = "$($Company)-$($Enviroment)-$($ResourceGroup)-$(Get-Date -Date (Get-Date -format "dd-MMM-yyyy HH:mm") -UFormat %s)"

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

$psCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal, $ServicePrincipalPassword)
Add-AzureRmAccount -Credential $psCred -ServicePrincipal -TenantId $TenantID

Select-AzureRmSubscription -SubscriptionId $SubscriptionID

New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company=$Company; Enviroment=$Enviroment} -Force
New-AzureRmResourceGroupDeployment -Name $DeployLabel -ResourceGroupName $ResourceGroup -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters -Company $Company -AdminPassword $AdminPassword -AsJob -Verbose -Force
Set-AzurePolicy -PolicyName "AllowedResources" -SubscriptionID $SubscriptionID -ApplicationID $ServicePrincipal -ClientSecret $ServicePrincipalPassword -ResourceGroup $ResourceGroup