###############################################################################################################################################################
# Regenerates key1 of a Storage Account and then updates the secret in Azure Key Vault. 
# 
# Error Handling: There is no error handling available in this pattern. Errors related to the execution of the cmdlet are listed in the runbooks log. 
# 
# Output:         None
#
# Requirements:   AzureRM.KeyVault, AzureRM.Storage
#
# Template:       TEC0006-KeyRotation -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -KeyVaultName $KeyVaultName
#   
# Change log:
# 1.0             Initial version  
#
###############################################################################################################################################################
workflow TEC0006-KeyRotation
{
  [OutputType([object])] 	

  param
	(
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-0005-rsg-refcore-01',
    [Parameter(Mandatory=$false)][String] $StorageAccountName = 'rocweu0005core01s',
    [Parameter(Mandatory=$false)][String] $KeyVaultName = 'weu-0005-key-keyvault-01'
  )

  $VerbosePreference ='Continue'
  TEC0005-SetAzureContext

  inlinescript 
  { 
    $ResourceGroupName = $Using:ResourceGroupName
    $StorageAccountName = $Using:StorageAccountName
    $KeyVaultName = $Using:KeyVaultName
    
    # Regenerate key on Storage Account
    $Result = New-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storageAccountName -KeyName key1
    Write-Verbose -Message ('TEC0006-StorageAccountKeyRegenerated')

    # Get newly generated key
    $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Value[0]
    Write-Verbose -Message ('TEC0006-NewStorageAccountKey: ' + $StorageAccountKey)

    # Update secret in Key Vault
    $Result = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $StorageAccountName `
                                      -SecretValue (ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force) -ContentType 'Storage Account Key'
    Write-Verbose -Message ('TEC0006-KeyVaultSecretUpated: ' + ($Result | Out-String))
  }
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUU3Fk62SekLEXy0LqH6Bw2evH
# vN6gggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
# AQUFADApMScwJQYDVQQDDB5yb2NoZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20w
# HhcNMTgwNzMxMDYyODI1WhcNMTkwNzMxMDY0ODI1WjApMScwJQYDVQQDDB5yb2No
# ZWdyb3VwdGVzdC5vbm1pY3Jvc29mdC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDM1mh7YGuat1ZZq9rPnnbpP2U88qpR82M75699r1TG3Ch+v6rH
# AgDMT5d3nwiyANo968M0k3w4/B8NrG+8pe8yWM7jsKv+a8VQSgig/OiRxMmP6wOO
# qVMq52uvbPCH+Ol1uJGhgUNytZDjKxkdYW/fnd8Rnnb6GWTzFWeHsm8ugk3Uiieh
# yCL66BPzmwtNX6r4Xg+NIn5U6YNBa5+jO8v67C7YdGEBkGcyDAugSfPF1qFBRpXx
# 0gTEZd5n51TkgI1CwUL4um0Wm/ntsuEdunEypgdIhtKZu8PebHsUQpZOcOg/tPu2
# y7k+gu0PT4Mg6XiG4dMdlrgpaf/yxA9dChrpAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUUFHukpelHlbkJGU5
# +MQ1XiqrD4wwDQYJKoZIhvcNAQEFBQADggEBAERlwzGl9ufvTi1YM5cCS+s+LFvL
# 9VUkBuRKmzHaH3EqpzzRWT7apISK85PbNgP09poSVwUQZ66gV+4CcTU2EDLh86k1
# noysDZushpCVSXTStBMVtgWAz2tA96ime++3QLI0k8+bod/F65eRBedPUS5LCEbf
# bmVQAtwMRXDWdjUH3jSs2F1Pep5mcQfsZZ8uCj5P6a+dMKxLVkYmg9MoXXJqNnZM
# ANVzt5NI/ErXYOFIbPq80o/EjkfEzesB4pnDH8RdvvFHljUetFgUw0t01ZQ21/iU
# QvxWOAfVkUaLOIh0rUJNh8Xfz0vmAgWtmtRXepicK9iqSrbule5EWdMmQPwxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHnJvY2hlZ3JvdXB0ZXN0Lm9ubWljcm9zb2Z0
# LmNvbQIQVIJucZNUEZlNFZMEf+jSajAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU1RSfND+OAMOO
# CaZSwqNZTKF7W5owDQYJKoZIhvcNAQEBBQAEggEAIghND7ptQYKDrq4+GpHgGHuU
# XCbZCZEyuxP0Fi8icKc6+SqrQYfoRbJkaLxwZ9cAqR+p09W0JinE+QDeUPA6aXkS
# kTNoGEso02y/sIeNjC58OPGtflToEdMO4n/VLc0vlezR1BDizXtKlsSR9I6z1MNP
# Splqc7glzqS0cPtE70gojB37CyCZtaoaE/3cNBy2NdqHykI6S+l2CcULLJZqN+Ws
# XFY7dOcHvQLdOLE8G2KCrtNHPyVijZXyGpoFt+XauYHlNQpQDLU6V5UEW3lYvoup
# tahvaCtlJYQGXi3QtKysT2KBiptS0aPCbeBSHkpNeskIKigz8Se4GggCWK1tNQ==
# SIG # End signature block
