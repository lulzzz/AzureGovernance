###############################################################################################################################################################
# Creates a new Resource Group using an ARM Template 
#
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow XOL0012-ResourceGroupNew
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $Location = 'westeurope',
    [Parameter(Mandatory=$false)][String] $ResourceGroupNameIndividual = 'test',
    [Parameter(Mandatory=$false)][String] $Region = 'westeurope',
    [Parameter(Mandatory=$false)][String] $SubscriptionName = 'Core-co',
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'App-1',
    [Parameter(Mandatory=$false)][String] $CostCenter = '123-1234',
    [Parameter(Mandatory=$false)][String] $Budget = '111',
    [Parameter(Mandatory=$false)][String] $Contact = 'felix.bodmer@outlook.com'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  InlineScript
  {
    $Location = $Using:Location
    $ResourceGroupNameIndividual= $Using:ResourceGroupNameIndividual
    $Region = $Using:Region
    $SubscriptionName = $Using:SubscriptionName
    $ApplicationId = $Using:ApplicationId
    $CostCenter = $Using:CostCenter
    $Budget = $Using:Budget
    $Contact = $Using:Contact

    #############################################################################################################################################################
    #  
    # Parameters
    #
    #############################################################################################################################################################
    $RoleNameGuid = New-Guid
    $TenantId = ((Get-AzureRmContext).Tenant).Id
  
    # ffea2e1f-0679-454f-8820-65a0186028b8
    #############################################################################################################################################################
    #  
    # Deploy Template
    #
    #############################################################################################################################################################
    $Result = New-AzureRmDeployment -Location $Location -ResourceGroupNameIndividual $ResourceGroupNameIndividual -Region $Region -SubscriptionName $SubscriptionName `
                          -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact `
                          -AadId ffea2e1f-0679-454f-8820-65a0186028b8 -BuiltInRoleType Reader `
                          -RoleNameGuid $RoleNameGuid `
                          -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/XOL000-RgNew.json 
  }
}