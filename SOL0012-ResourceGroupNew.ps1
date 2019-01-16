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
workflow SOL0012-ResourceGroupNew
{
  [OutputType([object])] 	

  param
  (
    [object]$WebhookData 
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
  #TEC0005-AzureContextSet


  #############################################################################################################################################################
  #  
  # Parameters
  #
  #############################################################################################################################################################
  $Location = 'westeurope'
  $rgName = 'test'


  #############################################################################################################################################################
  #  
  # Deploy Template
  #
  #############################################################################################################################################################
  New-AzureRmDeployment -Location westeurope -ResourceGroupNameIndividual test -Region westeurope -SubscriptionName Core-co -ApplicationId App-1 -CostCenter 24-1234 -Budget 222 `
                        -Contact felix.bodmer@outlook.com -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/SOL0012-ResourceGroupNew.json 



  New-AzureRmDeployment -Location westeurope -principalId ffea2e1f-0679-454f-8820-65a0186028b8 -builtInRoleType Reader -roleNameGuid 11111111-1111-1111-1111-111111111111 -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/SOL0012-ResourceGroupNewPolicy.json 





}