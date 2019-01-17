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
  New-AzureRmDeployment -Location westeurope -ResourceGroupNameIndividual aaa -Region westeurope -SubscriptionName Core-co -ApplicationId App-1 `
                        -CostCenter 24-1234 -Budget 222 -Contact felix@outlook.com `
                        -AadId ffea2e1f-0679-454f-8820-65a0186028b8 -BuiltInRoleType Reader `
                                     -RoleNameGuid 41111111-1111-1111-1111-111111111111 `
                        -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/SOL000-RgNew.json 


  # Create Resource Group
  New-AzureRmDeployment -Location westeurope -ResourceGroupNameIndividual test -Region westeurope -SubscriptionName Core-co -ApplicationId App-1 `
                        -CostCenter 24-1234 -Budget 222 -Contact felix@outlook.com `
                        -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/PAT0000-ResourceGroupNew.json 



  # Assign RBAC
  New-AzureRmDeployment -Location westeurope -ResourceGroupName weu-co-rsg-test-99 -AadId ffea2e1f-0679-454f-8820-65a0186028b8 -BuiltInRoleType Reader `
                        -RoleNameGuid 21111111-1111-1111-1111-111111111111 -Region westeurope `
                        -TemplateUri https://raw.githubusercontent.com/fbodmer/AzureGovernance/master/PAT0000-ResourceGroupNew.json

  New-AzureRmResourceGroupDeployment 


}