###############################################################################################################################################################
# Imports all the Runbooks from GitHub into Azure Automation. Prior to the import all Runbooks in the Azure Automation Account are deleted - except the 
# ones with Webhooks.
# This Runbook needs to be executed from the Automation Account to which the Runbooks are imported. 
# 
# Output:         None
#
# Requirements:   See Import-Module in code below 
#
# Template:       TEC0004-GitHubImport -GitHubRepo $GitHubRepo
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0004-GitHubImportAll
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $GitHubRepo = '/fbodmer/AzureGovernance'
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module Az.Automation, Az.Resources
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


  InlineScript
  {
    $GitHubRepo = $Using:GitHubRepo


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AutomationAccountName = Get-AutomationVariable -Name VAR-AUTO-AutomationAccountName -Verbose:$false
    $ResourceGroupName = (Get-AzResource | Where-Object {$_.Name -eq $AutomationAccountName}).ResourceGroupName

    # Below is not required for public GitHub Repositories
    # $GitHubCredentials = Get-AutomationPSCredential -Name CRE-AUTO-GitHubUser -Verbose:$false
    # Convert to plain text and then to Base64, e.g. for use with non-Windows systems
    # $Username = $GitHubCredentials.GetNetworkCredential().username
    # $Password = $GitHubCredentials.GetNetworkCredential().password
    # $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    # $Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo)} 

    Write-Verbose -Message ('TEC0004-CoreResourceGroup: ' + ($ResourceGroupName))
    Write-Verbose -Message ('TEC0004-AutomationAccountName: ' + ($AutomationAccountName))


    ###########################################################################################################################################################
    #
    # Get list of all Runbooks
    #
    ###########################################################################################################################################################
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Result = Invoke-WebRequest -Uri "https://api.github.com/repos$GitHubRepo/contents" -UseBasicParsing -Verbose:$false #-Headers $Headers                      # Header not required for public Repos
    $Runbooks = (($Result.Content | ConvertFrom-Json) | Where-Object {$_.name -Like '*.ps1'}).name
    Write-Verbose -Message ('TEC0004-RunbooksInGitHub: ' + ($Runbooks | Out-String))


    ###########################################################################################################################################################
    #
    # Delete existing Runbooks in Azure Automation Account - except the ones with a Webhook (preserve them)
    #
    ###########################################################################################################################################################
    # Prepare access to Azure Automation Runbooks
    $AutomationAccount = (Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName | Where-Object {$_.AutomationAccountName -eq $AutomationAccountName})
    Write-Verbose -Message ('TEC0004-AutomatonAccountUsed: ' + $ResourceGroupName + ' - ' + ($AutomationAccount | Out-String))

    # Get all Runbooks
    $RunbooksAll = @()
    $RunbooksAll = (Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount.AutomationAccountName).Name
    Write-Verbose -Message ('TEC0004-AllRunbooksInAccount: ' + ($RunbooksAll | Out-String))

    # Get all Webhooks
    $Webhooks = @()
    $Webhooks = (Get-AzAutomationWebhook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName).RunbookName
    Write-Verbose -Message ('TEC0004-RunbooksWithWebhooks: ' + ($Webhooks | Out-String))

    # Runbooks that don't have Webhook configured
    $RunbooksWithoutWebhooks = $RunbooksAll | ?{$Webhooks -notcontains $_}
    Write-Verbose -Message ('TEC0004-RunbooksWithoutWebhooks: ' + ($RunbooksWithoutWebhooks | Out-String))
 
    # Remove all runbooks without Webhooks in Azure Automation Runbook Account
    $Counter = $RunbooksWithoutWebhooks.Count
    Write-Verbose -Message ('TEC0004-NumberOfRunbooksWithoutWebhooks: ' + $Counter)

    if($Counter -gt 0)
    {
      foreach ($RunbooksWithoutWebhook in $RunbooksWithoutWebhooks)
      { 
        $Result = Remove-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
                                                  -AutomationAccountName $AutomationAccountName `
                                                  -Name $RunbooksWithoutWebhook `
                                                  -Force
        Write-Verbose -Message ('TEC0004-RunbookDeleted: ' + $RunbooksWithoutWebhook)
      }
    }
    else
    {
      Write-Verbose -Message ('TEC0004-NoPatternRunbooksToDelete: There are no runbooks in the Automation Account to be deleted')
    }


    ###########################################################################################################################################################
    #
    # Import the Runbooks
    #
    ###########################################################################################################################################################
    foreach ($Runbook in $Runbooks)
    {
      # Get individual Runbooks in GitHub
      $RunbookGitHub = Invoke-WebRequest -Uri https://api.github.com/repos$GitHubRepo/contents/$Runbook -UseBasicParsing -Verbose:$false #-Headers $Headers      # Not required for public Repos
      $RunbookContent = $RunbookGitHub.Content | ConvertFrom-Json
      $RunbookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($RunbookContent.content))
      $Result = Out-File -InputObject $RunbookContent -FilePath D:\$Runbook -Force

      # Import to Azure Automation
      $Result = Import-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
                                      -Type PowerShellWorkflow `
                                      -Path D:\$Runbook `
                                      -LogVerbose $true `
                                      -Published `
                                      -Description 'Imported from GitHub' `
                                      -Force
      Write-Verbose -Message ('TEC0004-RunbookImported: ' + $Runbook)
    }
  }
}
