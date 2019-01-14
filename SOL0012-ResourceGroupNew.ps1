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
  New-AzureRmDeployment -Location $Location -rgLocation $Location -rgName $rgName `
                        -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/SOL0012-ResourceGroupNew.json
}