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

$psCred = New-Object System.Management.Automation.PSCredential($ServicePrincipal, $ServicePrincipalPassword)
Add-AzureRmAccount -Credential $psCred -ServicePrincipal -TenantId $TenantID

Select-AzureRmSubscription -SubscriptionId $SubscriptionID

New-AzureRmResourceGroup -Name $ResourceGroup -Location $Region -Tag @{Company=$Company; Enviroment=$Enviroment} -Force
New-AzureRmResourceGroupDeployment -Name $DeployLabel -ResourceGroupName $ResourceGroup -TemplateFile $ArmTemplate -TemplateParameterFile $ArmTemplateParameters -Company $Company -AdminPassword $AdminPassword -Verbose -Force