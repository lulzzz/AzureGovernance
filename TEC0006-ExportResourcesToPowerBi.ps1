###############################################################################################################################################################
# Exporting resources and tags to Power BI using 'Streaming Dataset'.
#
# Error Handling: There is no error handling available in this pattern. 
# 
# Output:         None
#
# Requirements:   None
#
# Template:       None
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0006-ExportResourcesToPowerBi
{
  [OutputType([object])] 	

  param
	(
  )

  $VerbosePreference ='Continue'

  TEC0005-SetAzureContext

  InlineScript
  {
    ###########################################################################################################################################################
    #
    # Select all resources, tags and write to table
    #
    ###########################################################################################################################################################
    # Create table
    $Table = New-Object System.Data.Datatable
    [void]$Table.Columns.Add('KeyName')
    [void]$Table.Columns.Add('KeyRgName')
    [void]$Table.Columns.Add('KeyType')

    $Resource = Get-AzureRmResource | Where-Object {
                                                      # $_.ResourceType -eq 'Microsoft.Web/sites' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Web/serverFarms' -or 
                                                      # $_.ResourceType -eq 'microsoft.storsimple/managers' -or 
                                                      $_.ResourceType -eq 'Microsoft.Storage/storageAccounts' -or 
                                                      $_.ResourceType -eq 'Microsoft.Sql/servers/databases' -or 
                                                      $_.ResourceType -eq 'Microsoft.Sql/servers' -or 
                                                      $_.ResourceType -eq 'Microsoft.RecoveryServices/vaults' -or 
                                                      # $_.ResourceType -eq 'Microsoft.OperationsManagement/solutions' -or 
                                                      # $_.ResourceType -eq 'Microsoft.OperationalInsights/workspaces' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/virtualNetworks' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/virtualNetworkGateways' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Network/routeTables' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/publicIPAddresses' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/networkSecurityGroups' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/networkInterfaces' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/localNetworkGateways' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/loadBalancers' -or 
                                                      $_.ResourceType -eq 'Microsoft.Network/connections' -or 
                                                      $_.ResourceType -eq 'Microsoft.KeyVault/vaults' -or 
                                                      # $_.ResourceType -eq 'microsoft.insights/components' -or 
                                                      # $_.ResourceType -eq 'microsoft.insights/autoscalesettings' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Insights/alertrules' -or 
                                                      # $_.ResourceType -eq 'Microsoft.DataFactory/dataFactories' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Compute/virtualMachines/extensions' -or 
                                                      $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' -or 
                                                      # $_.ResourceType -eq 'Microsoft.ClassicStorage/storageAccounts' -or 
                                                      # $_.ResourceType -eq 'Microsoft.ClassicNetwork/networkSecurityGroups' -or 
                                                      # $_.ResourceType -eq 'Microsoft.Automation/automationAccounts/runbooks' -or 
                                                      $_.ResourceType -eq 'Microsoft.Automation/automationAccounts' 
                                                      # $_.ResourceType -eq 'Microsoft.AppService/gateways'
                                                   }
    $Counter = $Resource.Count
    do
    {
      $Counter = $Counter - 1
      $Resource.Name[$Counter]
      $Tags = (Get-AzureRmResource -ResourceName $Resource.Name[$Counter] -ResourceGroupName $Resource.ResourceGroupName[$Counter]).Tags
      # Add columns to table
      if ($Tags.Length -ne 0)
      {
        foreach ($Tag in $Tags.Keys)
        {
          try
          {
            [void]$Table.Columns.Add($Tag)
          }
          catch
          {
            'Column already existing'
          }
        }

        $Row = $Table.NewRow()
        $Row.KeyName = $Resource.Name[$Counter]
        $Row.KeyRgName = $Resource.ResourceGroupName[$Counter]
        #$C = (($Resource.ResourceType[$Counter]).Split('.')).Count
        #$Row.KeyType = (($Resource.ResourceType[$Counter]).Split('.'))[$C-1]
        $Row.KeyType = $Resource.ResourceType[$Counter]

        foreach ($Tag in $Tags.GetEnumerator())
        {
          # Convert key/value pair to string
          $Name = $Tag.Name.ToString()
          $Value = $Tag.Value.ToString()
          Set-Variable -Name Var3 -Value $Name  
          $Row.(Get-Variable -Name Var3 -ValueOnly) = $Value
        }
        $Table.Rows.Add($Row)
      }
    } until ($Counter -eq 0) 
    
    ###############################################################################################################################################################
    #
    # Create oauth token
    #
    ###############################################################################################################################################################    
    # Load Active Directory Authentication Library (ADAL) Assemblies
    $adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
    [System.Reflection.Assembly]::LoadFrom($adal)
    [System.Reflection.Assembly]::LoadFrom($adalforms)
     
    # Client ID
    $ClientId = '3fbc29dd-c3dd-4376-b41a-c2897b810126' 
 
    # Resource URI to Azure Service Management API
    $ResourceAppIdURI = 'https://analysis.windows.net/powerbi/api'
 
    # Authority to Azure AD Tenant
    $Authority = 'https://login.windows.net/common/oauth2/authorize' 
 
    # Set user credentials 
    $UserName = 'adminfb@swissmbc.ch'
    $Password = 'Xilef123$'
    $Credentials = New-Object 'Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential' -ArgumentList $UserName,$Password
 
    # Create AuthenticationContext tied to Azure AD Tenant
    $AuthContext = New-Object 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $Authority

    # Acquire token
    $AuthResult = $AuthContext.AcquireToken($ResourceAppIdURI, $ClientId, $Credentials) 

    ###############################################################################################################################################################
    #
    # Get dataset
    #
    ###############################################################################################################################################################
    $Endpoint = 'https://api.powerbi.com/v1.0/myorg/datasets'
    $Headers = @{'Authorization' = ('Bearer ' + $authResult.AccessToken)}
    $Dataset = Invoke-RestMethod -Method Get -Uri $Endpoint -Headers $Headers
    $DatasetId = $Dataset.value.id

    ###############################################################################################################################################################
    #
    # Get table
    #
    ###############################################################################################################################################################
    $Endpoint = "https://api.powerbi.com/v1.0/myorg/datasets/$DatasetId/tables"
    $BiTable = Invoke-RestMethod -Method Get -Uri $Endpoint -Headers $Headers
    $BiTableName = $BiTable.value.name

    ###############################################################################################################################################################
    #
    # Stream data to Power BI
    #
    ###############################################################################################################################################################
    $Counter = $Table.GetChildRows.Count
    do
    {
      $Counter-- 
      $payload = $null
      $payload = @{
      'KeyName' = $Table.Rows[$Counter].KeyName
      'KeyRgName' = $Table.Rows[$Counter].KeyRgName
      'KeyType' = $Table.Rows[$Counter].KeyType
      'Billing' = $Table.Rows[$Counter].Billing
      }
    $Endpoint = "https://api.powerbi.com/v1.0/myorg/datasets/$DatasetId/tables/$BiTableName/rows"
    $Result = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $Headers -Body (ConvertTo-Json @($Payload)) 
    }
    until ($Counter -eq 0)
  }
}