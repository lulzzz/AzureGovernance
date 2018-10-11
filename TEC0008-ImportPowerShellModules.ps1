###############################################################################################################################################################
# Imports the PowerShell Modules from the PowerShell Repository on an Azure Files share in the Core Storage Account. The PowerShell Modules are imported to 
# the Hybrid Runbook Worker where this Runbook is executed. Prior to the import all PowerShell Modules are deleted. This ensures that Modules no longer used
# are removed. Some Modules can't be deleted because they haven't been installed using the Install-Module cmdlet, but that is intentional. These modules
# don't need to be de-installed/updated. 
#
# Hybrid Runbook Workers need the following executed under the Automation user: Install-Module AzureAutomationAuthoringToolkit -Scope CurrentUser 
#
# The Modules imported using the Import-Module at the beginning of the Workflow won't be updated properly. These Modules are locked and can't be deleted. The 
# result is that there might be two versions of these Modules installed. This can be remediated manually or by running this Runbook again. 
#
# For the following reasons this Runbook doesn't support execution on a Azure Automation Server:
# - Nuget is required which is not available on Azure Automation servers
# - Azure Automation only supports Zip as a format to import Modules
# - To create the ZIP the modules need to first be downloaded from PowerShell Gallery - which requires Nuget 
#
# 
# Output:         None
#
# Requirements:   See Import-Module in code below / Drive letter Z available for mapping
#
# Template:       TEC0008-ImportPowerShellModules
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0008-ImportPowerShellModules
{
  [OutputType([object])] 	

  param
  (
    # no parameters
  )
  
  #############################################################################################################################################################
  #  
  # Import modules prior to Verbose setting to avoid clutter in Azure Automation log
  #
  #############################################################################################################################################################
  InlineScript
  {
    $VerbosePreference = 'SilentlyContinue'
    $Result = Import-Module AzureAutomationAuthoringToolkit, AzureRM.Resources, AzureRM.Storage, PowerShellGet
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet

  InlineScript
  {
    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $AzureAutomationCredential = Get-AutomationPSCredential -Name 'CRE-AUTO-AutomationUser' -Verbose:$false
    $RepositoryPath = '\\rocweu0005core01s.file.core.windows.net\powershell-module-repository\PublishedModules'
    $RepositoryName = 'PublishedModules'


    ###########################################################################################################################################################
    #
    # Register the PowerShell Repository on the Azure File Share in the core storage account - need to connect New-PSDrive to enable access
    #
    ###########################################################################################################################################################
    $StorageAccountName = Get-AutomationVariable -Name 'VAR-AUTO-StorageAccountName' -Verbose:$false
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageAccountKey = ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$StorageAccountName", $StorageAccountKey
    $Result = New-PSDrive -Name Z -PSProvider FileSystem -Root $RepositoryPath -Credential $Credential
    $Result = Register-PSRepository -Name $RepositoryName -SourceLocation $RepositoryPath -ErrorAction SilentlyContinue
    $Repository = Get-PSRepository -Name $RepositoryName
    Write-Verbose -Message ('TEC0007-RepositoryRegistered: ' + ($Repository | Out-String))


    ###########################################################################################################################################################
    #
    # Remove all modules from the current session
    #
    ###########################################################################################################################################################
    $Modules = Get-Module
    foreach ($Module in $Modules)
    {
      Remove-Module $Module.Name -Force
    }

 
    ###########################################################################################################################################################
    # 
    # De-install all modules
    # The following modules in the following locations will not be de-installed: 
    # - C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules
    # - C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation\7.2.13848.0
    # - C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation\7.2.13848.0\HybridAgent\Modules
    # - C:\Program Files\Microsoft Monitoring Agent\Agent\PowerShell\
    #
    ###########################################################################################################################################################
    $Modules = Get-Module -ListAvailable
    foreach ($Module in $Modules)
    {
      Write-Verbose -Message ('TEC0007-Removing: ' + $Module.Name)
      $Result = Uninstall-Module $Module.Name -Force -ErrorAction SilentlyContinue
    }
 

    ###########################################################################################################################################################
    #
    # Reset $env:PSModulePath
    # The following will be re-added automatically: C:\Users\<user>\Documents\WindowsPowerShell\Modules
    #
    ###########################################################################################################################################################
     $PSmodulePath = @()
     $env:PSmodulePath -split(";") | Where-Object {$_ -like 'C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules\' -or `
                                                   $_ -like 'C:\Program Files\Microsoft Monitoring Agent\Agent\*' -or `
                                                   $_ -like 'C:\Program Files\WindowsPowerShell\Modules\'} `
                                   | ForEach-Object -Process {$PSmodulePath += $_}
     $env:PSmodulepath = $PSmodulePath -join(';')
 

    ###########################################################################################################################################################
    #
    # Install modles - will add entry in $env:PSModulePath
    #
    ###########################################################################################################################################################
    $Modules = Find-Module -Repository PublishedModules
    foreach ($Module in $Modules)
    {
      Install-Module -Name $Module.Name -Repository PublishedModules -Force -AllowClobber
      Write-Verbose -Message ('TEC0007-Installing: ' + $Module.Name)
    }

    # The Module needs to be installed with the scope of the Automation user - see description at top of workflow
    $Result = Remove-Item 'C:\Program Files\WindowsPowerShell\Modules\AzureAutomationAuthoringToolkit' -Recurse -Force
  }
}