workflow Test
{
  InlineScript
  {
    $VerbosePreference = 'Continue' 
    Write-Verbose -Message ('Modules: ' + (Get-Module | Out-String))
    [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.DisableFormatUpdates
    [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.DisableFormatUpdates = $false
    [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.DisableFormatUpdates 
    $Result = Import-Module SQLServer -NoClobber -ErrorAction SilentlyContinue
    [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.DisableFormatUpdates = $true
    [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.DisableFormatUpdates 
    Write-Verbose -Message ('Modules: ' + (Get-Module | Out-String))
    Write-Verbose -Message 'Test'
  }
}


