Using module ".\Modules\NO.PowershellAzure\NO.PowershellAzure.psm1"
[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)] [string]$TenantID,
    [parameter(Mandatory=$true)] [string]$SubscriptionID,
    [parameter(Mandatory=$false)] [securestring]$AdminPassword,
    [parameter(Mandatory=$true)] [string]$ServicePrincipal,
    [parameter(Mandatory=$true)] [securestring]$ServicePrincipalPassword,
    [parameter(Mandatory=$false)] [string]$ResourceGroup = "NO_RG",
    [parameter(Mandatory=$false)] [string]$Region = "WestEurope", 
    [parameter(Mandatory=$false)] [string]$ArmTemplate = ".\Templates\azuredeploy.json",
    [parameter(Mandatory=$false)] [string]$ArmTemplateParameters = ".\Templates\azuredeploy.parameters.json",
    [parameter(Mandatory=$false)] [string]$Company = "NO",
    [parameter(Mandatory=$false)] [string]$Enviroment = "Test",
    [parameter(Mandatory=$false)] [string]$DeployLabel
)

$DeployLabel = "$($Company)-$($Enviroment)-$($ResourceGroup)-$(Get-Date -Date (Get-Date -format "dd-MMM-yyyy HH:mm") -UFormat %s)"

$spCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal, $ServicePrincipalPassword)
Add-AzureRmAccount -Credential $spCred -ServicePrincipal -TenantId $TenantID

Select-AzureRmSubscription -SubscriptionId $SubscriptionID

New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company=$Company; Enviroment=$Enviroment} -Force
New-AzureRmResourceGroupDeployment -Name $DeployLabel -ResourceGroupName $ResourceGroup -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters -Company $Company -AdminPassword $AdminPassword -AsJob -Verbose -Force
Set-AzurePolicy -PolicyName "AllowedResources" -SubscriptionID $SubscriptionID -ApplicationID $ServicePrincipal -ClientSecret $ServicePrincipalPassword -ResourceGroup $ResourceGroup