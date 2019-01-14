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
  New-AzureRmDeployment -Location westeurope -ResourceGroupNameIndividual test -Regions westeurope -SubscriptionName Core-co -ApplicationId App-1 -CostCenter 24-1234 -Budget 222 `
                        -Contact felix.bodmer@outlook.com -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/SOL0012-ResourceGroupNew.json 








}