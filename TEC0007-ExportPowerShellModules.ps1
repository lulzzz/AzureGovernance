###############################################################################################################################################################
# Exports the PowerShell Modules as well as all the dependent modules to a PowerShell Repository on an Azure Files share in the Core Storage Account. 
# The PowerShell Modules are exported from the Hybrid Runbook Worker where this Runbook is executed. 
# For the following reasons this Runbook doesn't support execution on a Azure Automation Server:
# - Nuget is required which is not available on Azure Automation servers
# - Azure Automation only supports Zip as a format to import Modules
# - To create the ZIP the modules need to first be downloaded from PowerShell Gallery - which requires Nuget
# 
# Output:         None
#
# Requirements:   See Import-Module in code below 
#
# Template:       TEC0007-ExportPowerShellModules
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0007-ExportPowerShellModules
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
    $Result = Import-Module AzureRM.Resources, AzureRM.Storage, PowerShellGet
    $VerbosePreference = 'Continue'
  }
  TEC0005-AzureContextSet


    ###########################################################################################################################################################
    #
    # Parameters
    #
    ###########################################################################################################################################################
    $RepositoryPath = '\\rocweu0005core01s.file.core.windows.net\powershell-module-repository\PublishedModules'
    $RepositoryName = 'PublishedModules'

  InlineScript
  {
    $RepositoryPath = $Using:RepositoryPath
    $RepositoryName = $Using:RepositoryName 


    ###########################################################################################################################################################
    #
    # Register the PowerShell Repository on the Azure File Share in the core storage account - need to connect New-PSDrive to enable access
    #
    ###########################################################################################################################################################
    $StorageAccountName = Get-AutomationVariable -Name VAR-AUTO-StorageAccountName -Verbose:$false
    $StorageAccount = Get-AzureRmResource | Where-Object {$_.Name -eq $StorageAccountName}
    $StorageAccountKey = (Get-AzureRMStorageAccountKey -ResourceGroupName $StorageAccount.ResourceGroupName -Name $StorageAccount.Name).Value[0]
    $StorageAccountKey = ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$StorageAccountName", $StorageAccountKey
    $Result = New-PSDrive -Name Z -PSProvider FileSystem -Root $RepositoryPath -Credential $Credential
    $Result = Register-PSRepository -Name $RepositoryName -SourceLocation $RepositoryPath -ErrorAction SilentlyContinue -Verbose:$false
    $Repository = Get-PSRepository -Name $RepositoryName -Verbose:$false
    Write-Verbose -Message ('TEC0007-RepositoryRegistered: ' + ($Repository | Out-String))
  }


    ###########################################################################################################################################################
    #
    # Get all Modules and their dependent Modules
    #
    ###########################################################################################################################################################
    # Get the installed modules
    $VerbosePreference = 'SilentlyContinue'
    $Modules = Get-Module -ListAvailable -Verbose:$false
    $VerbosePreference = 'Continue'
    Write-Verbose -Message ('TEC0007-ModulesWithoutDependencies: ' + ($Modules| Out-String))

    # Get the module information for each of the installed modules including their dependencies on other modules, get only information for installed version
    $Report = foreach -Parallel ($Module in $Modules)
    {
      Write-Verbose -Message ('TEC0007-CheckingDependencies: ' + ($Module.Name))
      $WORKFLOW:VerbosePreference = 'SilentlyContinue'
      Find-Module -Name $Module.Name -RequiredVersion $Module.Version -IncludeDependencies -Repository PSGallery -ErrorAction SilentlyContinue -Verbose:$false
      $WORKFLOW:VerbosePreference = 'Continue'
    }
 
    # Create a report
    $ModulesToExport = foreach ($Item in $Report)
    {
      [PSCustomObject]@{Modulename = $Item.Name; ModuleVersion = $Item.Version; DependencyModuleName = $Item.Dependencies.Name; `
                        DependencyModuleMinimumVersion = $Item.Dependencies.MinimumVersion}
    }

    # Remove duplicate Module entries keeping the highest version only. 
    # Example: AzureRm.Tags requires MinimumVersion AzureRm.Profile 5.5.1 but AzureRm.Profile 5.3.4 is already installed as main Module not as dependent Module
    $ModulesToExport = $ModulesToExport | Sort-Object -Property ModuleVersion -Descending | Sort-Object -Unique Modulename

    # Re-Sort to ensure that Dependency Modules are imported first
    $ModulesToExport = $ModulesToExport | Sort-Object -Property DependencyModuleName -Descending

    Write-Verbose -Message ('TEC0007-ModulesToExport: ' + ($ModulesToExport| Out-String))


    ###########################################################################################################################################################
    #
    # Delete all Modules in PowerShell Repository
    #
    ###########################################################################################################################################################
    $VerbosePreference = 'SilentlyContinue'
    $Result = Remove-Item -Path $RepositoryPath\*.*
    $VerbosePreference = 'Continue'
    Write-Verbose -Message ('TEC0007-ModulesInTargetRepositoryDeleted: ' + ($RepositoryName| Out-String))


    ###########################################################################################################################################################
    #
    # Export all Modules and dependent Modules to PowerShell Repository
    #
    ###########################################################################################################################################################
    foreach ($ModuleToExport in $ModulesToExport)
    {
      $VerbosePreference = 'SilentlyContinue'
      $Result = Publish-Module -Name $ModuleToExport.Modulename -Repository PublishedModules -ErrorAction SilentlyContinue -Force                                # Force required to install Nuget
      $VerbosePreference = 'Continue'
      Write-Verbose -Message ('TEC0007-ModuleExported: ' + ($ModuleToExport.Modulename))
    }
  
}