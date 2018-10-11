###############################################################################################################################################################
# Creates a Resource Group (e.g. weu-0010-rsg-core-01) with Tags. The counter in the name is determined based on the existing Resource Groups.
# Assigns Contributor and Reader roles to the provided AD Security Groups. 
# 
# Output:         $ResourceGroupName
#
# Requirements:   See Import-Module in code below / AD Security Groups
#
# Template:       PAT0010-AzureResourceGroupNew -ResourceGroupNameIndividual $ResourceGroupNameIndividual `#                                               -SubscriptionCode $SubscriptionCode -IamContributorGroupName $IamContributorGroupName `#                                               -IamReaderGroupName $IamReaderGroupName -RegionName $RegionName -RegionCode $RegionCode `#                                               -ApplicationId $ApplicationId -CostCenter $CostCenter -Budget $Budget -Contact $Contact -Automation $Automation
#                                                     
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow PAT0010-AzureResourceGroupNew
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $ResourceGroupNameIndividual = 'felixtest',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = '0010',
    [Parameter(Mandatory=$false)][String] $IamContributorGroupName = 'AzureNetwork-Contributor',
    [Parameter(Mandatory=$false)][String] $IamReaderGroupName = 'Azure-Reader',
    [Parameter(Mandatory=$false)][String] $RegionName = 'West Europe',
    [Parameter(Mandatory=$false)][String] $RegionCode = 'weu',
    [Parameter(Mandatory=$false)][String] $ApplicationId = 'Application-001',                                                                                    # Tagging
    [Parameter(Mandatory=$false)][String] $CostCenter = 'A99.2345.34-f',                                                                                         # Tagging
    [Parameter(Mandatory=$false)][String] $Budget = '100',                                                                                                       # Tagging
    [Parameter(Mandatory=$false)][String] $Contact = 'contact@customer.com',                                                                                     # Tagging
    [Parameter(Mandatory=$false)][String] $Automation = 'v1.0'                                                                                                   # Tagging
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureAD, AzureRM.profile, AzureRM.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $ResourceGroupName = InlineScript
  {
    $ResourceGroupNameIndividual = $Using:ResourceGroupNameIndividual
    $SubscriptionCode = $Using:SubscriptionCode
    $IamContributorGroupName = $Using:IamContributorGroupName
    $IamReaderGroupName = $Using:IamReaderGroupName
    $RegionName = $Using:RegionName
    $RegionCode = $Using:RegionCode
    $ApplicationId = $Using:ApplicationId 
    $CostCenter = $Using:CostCenter 
    $Budget = $Using:Budget 
    $Contact = $Using:Contact 
    $Automation = $Using:Automation


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
    $TenantId = ((Get-AzureRmContext).Tenant).Id

    Write-Verbose -Message ('PAT0010-ResourceGroupNameIndividual: ' + ($ResourceGroupNameIndividual))
    Write-Verbose -Message ('PAT0010-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0010-IamContributorGroupName: ' + ($IamContributorGroupName))
    Write-Verbose -Message ('PAT0010-IamReaderGroupName: ' + ($IamReaderGroupName))
    Write-Verbose -Message ('PAT0010-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0010-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0010-ApplicationId: ' + ($ApplicationId))
    Write-Verbose -Message ('PAT0010-CostCenter: ' + ($CostCenter))
    Write-Verbose -Message ('PAT0010-Budget: ' + ($Budget))
    Write-Verbose -Message ('PAT0010-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0010-Automation: ' + ($Automation))
    Write-Verbose -Message ('PAT0010-TenantId: ' + ($TenantId))

   
    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0010-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Resource Group name
    #
    ###########################################################################################################################################################
    $ResourceGroupName = $RegionCode + '-' + $SubscriptionCode + '-' + 'rsg' + '-' + $ResourceGroupNameIndividual                                                # e.g. weu-0010-rsg-core
    $ResourceGroupExisting = Get-AzureRmResourceGroup `
    |                        Where-Object {$_.ResourceGroupName -like "$ResourceGroupName*"} `
    |                        Sort-Object Name -Descending | Select-Object -First $True

    if ($ResourceGroupExisting.Count -gt 0)                                                                                                                      # Skip if first RG with this name
    {
      Write-Verbose -Message ('PAT0010-ResourceGroupHighestCounter: ' + ($ResourceGroupExisting.ResourceGroupName))
      $Counter = 1 + ($ResourceGroupExisting.ResourceGroupName.SubString(($ResourceGroupExisting.ResourceGroupName).Length-2,2))                                 # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $ResourceGroupName = $ResourceGroupName + '-' + $Counter1                                                                                                  # Compile name    
    }
    else
    {
      $ResourceGroupName = $ResourceGroupName + '-' + '01'                                                                                                       # Compile name for first RG with this name
    }
    Write-Verbose -Message ('PAT0010-ResourceGroupName: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Check if Resource Group exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $RegionName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Verbose -Message ('PAT0010-ResourceGroupExisting: ' + ($ResourceGroupName))
      Return
    }
  
    try
    {
      $ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $RegionName -Verbose:$false
      Write-Verbose -Message ('PAT0010-ResourceGroupCreated: ' + ($ResourceGroupName))
    }
    catch
    {
      Write-Error -Message ('PAT0010-ResourceGroupNotCreated: ' + ($Error[0]))
      Return
    }
  

    ###########################################################################################################################################################
    #
    # Configure AD Group as Owner of the Resource Group - only required if different owner from first user
    #
    ###########################################################################################################################################################
    $Result = Connect-AzureAD -TenantId $TenantId -Credential $AzureAutomationCredential

    # Assign Contributor Group
    $IamContributorGroup = Get-AzureAdGroup -SearchString $IamContributorGroupName -ErrorAction SilentlyContinue
    if ($IamContributorGroup.Count -ne 1)
    {
      Write-Error -Message ('PAT0010-IamContributorGroupNotFound: ' + ($Error[0]))
    }
    else
    {
      Write-Verbose -Message ('PAT0010-IamContributorGroup: ' + ($IamContributorGroup)) 
      $RoleAssignment = New-AzureRmRoleAssignment -ObjectId $IamContributorGroup.ObjectId  -RoleDefinitionName Contributor -Scope $ResourceGroup.ResourceId
      Write-Verbose -Message ('PAT0010-IamContributorGroupAssigned: ' + ($RoleAssignment))       
    }

    # Assign Reader Group
    $IamReaderGroup = Get-AzureAdGroup -SearchString $IamReaderGroupName -ErrorAction SilentlyContinue
    if ($IamReaderGroup.Count -ne 1)
    {
      Write-Error -Message ('PAT0010-IamReaderGroupNotFound: ' + ($Error[0]))
    }
    else
    {
      Write-Verbose -Message ('PAT0010-IamReaderGroup: ' + ($IamReaderGroup)) 
      $RoleAssignment = New-AzureRmRoleAssignment -ObjectId $IamReaderGroup.ObjectId  -RoleDefinitionName Reader -Scope $ResourceGroup.ResourceId
      Write-Verbose -Message ('PAT0010-IamReaderGroupAssigned: ' + ($RoleAssignment))       
    }

  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}
    Write-Verbose -Message ('PAT0010-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags -Verbose:$false
    Write-Verbose -Message ('PAT0010-ResourceGroupTagged: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Return Resource Group name
    #
    ###########################################################################################################################################################
    Return $ResourceGroupName
  }
  Return $ResourceGroupName
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYxvF9S0FjIg2dT9VKX0rtRsE
# IkSgggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU7Uok3dp5w0vP
# qjjSYYi1Nk7g8A0wDQYJKoZIhvcNAQEBBQAEggEAyJJ/EfQ1SG2kfzWHAJ1yNXfd
# e1ewbUkwr2wXP3Httxe28R28AC7nCHZetTlVLkUb1JALj9zsFHS05N6b59xa3VeA
# gxeZV7uNJhzyO0l4hLONAOR1DNLlzrgnfH/M70hyPx/ioC6WeQn3GzowGvax3kZk
# PEhE10aRHLLZaieP/M/68aJkWZ+w0XvdP+456AE5H0dlTccXdDrE7oTsphQCJ2ps
# y0rwN0TzYDDHTuLSwylLpUCNOPxrxB3RoguvJoosHgAgx15Tie4/MxQaEnPPUdS5
# CdDYQS+NiYDHhLs7RbFOO29SMwD8vbTOKIBOmQtv4mSpxThOhJcFZxkLlo/irA==
# SIG # End signature block
