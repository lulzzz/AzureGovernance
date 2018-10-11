﻿###############################################################################################################################################################
# Creates a Log Analytics Workspace (e.g. swiweu0010core01) in an existing Resource Group. Tags the created Workspace. 
# Since Log Analytics is not available in all Regions there is a naming violations in certain regions. The name reflects in what region the Log Analytics
# Workspace should be deployed, not where it actually is deployed. 
# 
# Output:         $WorkspaceName
#
# Requirements:   See Import-Module in code below / Resource Group
#
# Template:       PAT0300-MonitoringWorkspaceNew -WorkspaceNameIndividual $WorkspaceNameIndividual -ResourceGroupName $ResourceGroupName `
#                                                -Automation $Automation
#                                                     
# Change log:
# 1.0             Initial version
#
###############################################################################################################################################################
workflow PAT0300-MonitoringWorkspaceNew
{
  [OutputType([string])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $WorkspaceNameIndividual = 'core',
    [Parameter(Mandatory=$false)][String] $ResourceGroupName = 'weu-co-rsg-core-01',
    [Parameter(Mandatory=$false)][String] $SubscriptionCode = 'de',
    [Parameter(Mandatory=$false)][String] $RegionName = 'North Europe',
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
    $Result = Import-Module AzureRM.OperationalInsights, AzureRM.profile
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  $WorkspaceName = InlineScript
  {
    $WorkspaceNameIndividual = $Using:WorkspaceNameIndividual
    $ResourceGroupName = $Using:ResourceGroupName
    $SubscriptionCode = $Using:SubscriptionCode
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

    # Log Analytics is available in certain Azure Regions only
    $RegionNameTechnical = switch ($RegionName) 
    {   
      'West Europe' {'West Europe'} 
      'North Europe' {'West Europe'}
      'West US' {'East US'}
      'East US' {'East US'}
      'Southeast Asia' {'Southeast Asia'}
      'East Asia' {'Southeast Asia'}
    }
     
    Write-Verbose -Message ('PAT0300-WorkspaceNameIndividual: ' + ($WorkspaceNameIndividual))
    Write-Verbose -Message ('PAT0300-ResourceGroupName: ' + ($ResourceGroupName))
    Write-Verbose -Message ('PAT0300-SubscriptionCode: ' + ($SubscriptionCode))
    Write-Verbose -Message ('PAT0300-RegionName: ' + ($RegionName))
    Write-Verbose -Message ('PAT0300-RegionCode: ' + ($RegionCode))
    Write-Verbose -Message ('PAT0300-RegionNameTechnical: ' + ($RegionNameTechnical))
    Write-Verbose -Message ('PAT0300-ApplicationId : ' + ($ApplicationId ))
    Write-Verbose -Message ('PAT0300-CostCenter : ' + ($CostCenter))
    Write-Verbose -Message ('PAT0300-Budget : ' + ($Budget))
    Write-Verbose -Message ('PAT0300-Contact: ' + ($Contact))
    Write-Verbose -Message ('PAT0300-Automation: ' + ($Automation))


    ###########################################################################################################################################################
    #
    # Change to Target Subscription
    #
    ###########################################################################################################################################################
    $Subscription = Get-AzureRmSubscription | Where-Object {$_.Name -match $SubscriptionCode} 
    $Result = Disconnect-AzureRmAccount
    $AzureContext = Connect-AzureRmAccount -Credential $AzureAutomationCredential -Subscription $Subscription.Name -Force
    Write-Verbose -Message ('PAT0300-AzureContextChanged: ' + ($AzureContext | Out-String))


    ###########################################################################################################################################################
    #
    # Configure Workspace name
    #
    ###########################################################################################################################################################
    $WorkspaceName = ('swi' + $RegionCode + $SubscriptionCode + $WorkspaceNameIndividual)                                                                        # e.g. swiweu0010core01
    $WorkspaceExisting = Get-AzureRmOperationalInsightsWorkspace `
    |                        Where-Object {$_.Name -like "$WorkspaceName*"} `
    |                        Sort-Object Name -Descending | Select-Object -First $True

    if ($WorkspaceExisting.Count -gt 0)                                                                                                                          # Skip if first RG with this name
    {
      Write-Verbose -Message ('PAT0300-WorkspaceHighestCounter: ' + $WorkspaceExisting.Name)
      $Counter = 1 + ($WorkspaceExisting.Name.SubString(($WorkspaceExisting.Name).Length-2,2))                                                                   # Get the last two digits of the name and add one
      $Counter1 = $Counter.ToString('00')                                                                                                                        # Convert to string to get leading '0'
      $WorkspaceName = $WorkspaceName + $Counter1                                                                                                                # Compile name    
    }
    else
    {
      $WorkspaceName = $WorkspaceName + '01'                                                                                                                     # Compile name for first RG with this name
    }
    Write-Verbose -Message ('PAT0300-WorkspaceName: ' + $WorkspaceName) 


    ###########################################################################################################################################################
    #
    # Check if Workspace exists and create if not
    #
    ###########################################################################################################################################################
    $Result = Get-AzureRmOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($Result.Length -gt 0)
    {
      Write-Error -Message ('PAT0300-WorkspaceExisting: ' + $WorkspaceName)
      Return
    }
  
    try
    {
      $LogAnalyticsWorkspace = New-AzureRmOperationalInsightsWorkspace -Location $RegionNameTechnical `
                                                                       -Name $WorkspaceName `
                                                                       -ResourceGroupName $ResourceGroupName `
                                                                       -Sku pernode `
                                                                       -ErrorAction Stop                                                                         # pernode is actually 'Per GB'
      Write-Verbose -Message ('PAT0300-LogAnalyticsWorkspaceCreated: ' + ($LogAnalyticsWorkspace | Out-String))
    }
    catch
    {
      Write-Error -Message ('PAT0300-LogAnalyticsWorkspaceNotCreated: ' + $Error[0]) 
      Return
    }

  
    ###########################################################################################################################################################
    #
    # Write tags
    #
    ###########################################################################################################################################################
    $Tags = @{ApplicationId  = $ApplicationId; CostCenter = $CostCenter; Budget = $Budget; Contact = $Contact; Automation = $Automation}

    Write-Verbose -Message ('PAT0300-TagsToWrite: ' + ($Tags | Out-String))

    $Result = Set-AzureRmOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName  -Tag $Tags
    Write-Verbose -Message ('PAT0300-ResourceGroupTagged: ' + ($ResourceGroupName))


    ###########################################################################################################################################################
    #
    # Return Workspace name
    #
    ###########################################################################################################################################################
    Return $WorkspaceName
  }
  Return $WorkspaceName
}
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVCmMOYBFPr7toPFh98wbGEWp
# 9zygggMmMIIDIjCCAgqgAwIBAgIQVIJucZNUEZlNFZMEf+jSajANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUpLSBiryqX0hD
# uv5pLyGRGl1nZfUwDQYJKoZIhvcNAQEBBQAEggEAjGknOX37AjYaxgzFp5qp28n8
# bcAvoCMd5rmubJBqLCiuE2qcZ337bWJ4pditR5gCrjiS4/VADtlIR6zbd0YrXNdx
# 7GS47Vze5S+WW+75DsGQyEGJzQx6n28cjcChBdndQxMEg3rYw8YgQ/f6bmOoBqBg
# ogYIpn81GEf7XvC9PF1Cp27RJXexsjRZsgueyLVKr9viqPE6nsDg4rqHWMTZAcrU
# NDE2JyaEurMTwa75lAKdkO1PUddWwaKzEJf3h7xfUHGD9PdlBOzEhhBiyHbjCR6c
# 7ETV3d3aajsHy6trD4gGQBB4mjqlk6sq99nWNxPxIByFHyezzeZKwZtOa+ssmA==
# SIG # End signature block