###############################################################################################################################################################
# Regenerates key1 of a Storage Account and then updates the secret in Azure Key Vault. If the secret is not available in the Azure Key Vault, it will 
# be created.
# 
# Output:         None
#
# Requirements:   See Import-Module in code below
#
# Template:       TEC0013-KeyRotation -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -KeyVaultName $KeyVaultName
#   
# Change log:
# 1.0             Initial version  
#
###############################################################################################################################################################
workflow TEC0013-KeyRotation
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'aaa-co-rsg-core-01',
    [Parameter(Mandatory=$false)][String] $StorageAccountName = 'felweucocore01s',
    [Parameter(Mandatory=$false)][String] $KeyVaultName = 'weu-co-key-felvault-01'
  )


  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.KeyVault, Az.Storage
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  InlineScript 
  { 
    $ResourceGroupName = $Using:ResourceGroupName
    $StorageAccountName = $Using:StorageAccountName
    $KeyVaultName = $Using:KeyVaultName
    
    # Regenerate key on Storage Account
    $Result = New-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -KeyName key1
    Write-Verbose -Message ('TEC0013-StorageAccountKeyRegenerated')

    # Get newly generated key
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Value[0]
    Write-Verbose -Message ('TEC0013-NewStorageAccountKey: ' + $StorageAccountKey)

    # Update secret in Key Vault
    $Result = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $StorageAccountName `
                                      -SecretValue (ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force) -ContentType 'Storage Account Key'
    Write-Verbose -Message ('TEC0013-KeyVaultSecretUpated: ' + ($Result | Out-String))
  }
}
