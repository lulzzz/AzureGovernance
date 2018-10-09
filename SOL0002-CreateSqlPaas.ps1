###############################################################################################################################################################
# Creates a new server based on the input parameters.
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   ???
#
# Template:       None
#   
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow SOL0002-CreateSqlPaas
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'test',
    [Parameter(Mandatory=$false)][String] $vaults_ams_te_bkp_dbpulse_01_name = 'ams-te-bkp-dbpulse-01',
    [Parameter(Mandatory=$false)][String] $servers_wus_te_sdb_pulse_01_name = 'wus-te-sdb-pulse-01',
    [Parameter(Mandatory=$false)][String] $databases_master_name = 'wus-te-sdb-pulse-01/master',
    [Parameter(Mandatory=$false)][String] $databases_wus_te_sdb_pulse01_db1_name = 'wus-te-sdb-pulse-01/wus-te-sdb-pulse01-db1',
    [Parameter(Mandatory=$false)][String] $databases_wus_te_sdb_pulse01_dwh1_name = 'wus-te-sdb-pulse-01/wus-te-sdb-pulse01-dwh1',
    [Parameter(Mandatory=$false)][String] $firewallRules_AllowAllWindowsAzureIps_name = 'wus-te-sdb-pulse-01/AllowAllWindowsAzureIps',
    [Parameter(Mandatory=$false)][String] $firewallRules_FelixHomeOffice_name = 'wus-te-sdb-pulse-01/FelixHomeOffice'
  )

  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext

  ##################################################################################################################################################################################
  #
  # Variables
  #
  ##################################################################################################################################################################################
  $Parameters = @{
                    vaults_ams_te_bkp_dbpulse_01_name = $vaults_ams_te_bkp_dbpulse_01_name
                    servers_wus_te_sdb_pulse_01_name = $servers_wus_te_sdb_pulse_01_name
                    databases_master_name = $databases_master_name
                    databases_wus_te_sdb_pulse01_db1_name = $databases_wus_te_sdb_pulse01_db1_name
                    databases_wus_te_sdb_pulse01_dwh1_name = $databases_wus_te_sdb_pulse01_dwh1_name
                    firewallRules_AllowAllWindowsAzureIps_name = $firewallRules_AllowAllWindowsAzureIps_name
                    firewallRules_FelixHomeOffice_name = $firewallRules_FelixHomeOffice_name
                  }


  #Create or check for existing resource group
  $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
  if(!$ResourceGroup)
  {
      New-AzureRmResourceGroup -Name $ResourceGroupName -Location WestUs
      Write-Verbose -Message ('SOL0002:ResourceGroupCreated: ' + $ResourceGroupName)
  }
  else
  {
      Write-Verbose -Message ('SOL0002:UsingExistingResourceGroup: ' + $ResourceGroupName)
  }

  New-AzureRmResourceGroupDeployment -TemplateParameterObject $Parameters -ResourceGroupName $ResourceGroupName `                                     -TemplateFile C:\JsonTemplates\wus-te-rg-pulse-01.json 
}