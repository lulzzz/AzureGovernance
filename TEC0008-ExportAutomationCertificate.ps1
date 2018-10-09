###############################################################################################################################################################
# Exports an Azure Automation Certificate to a file service. This is necessary because Azure Automation doesn't offer an export certificate option. 
# The export is possible from within an automation runbook only, because the certificates are available in the sandbox only.
# The runbook needs to run on a hybrid worker because of the use of Azure Files.
#
# Error Handling: There is no error handling avaialble in this pattern. Errors only occur if there is a problem with the infrastructure.
#                 These types of errors are automatically logged as errors in the runbooks log. 
# 
# Output:         None
#
# Requirements:   None
#
# Template:       TEC0008-ExportAutomationCertificate
#
# Change log:
# 1.0             Initial version 
#
###############################################################################################################################################################
workflow TEC0008-ExportAutomationCertificate
{
  [OutputType([object])] 	

  param
  (
    [Parameter(Mandatory=$false)][String] $CertificateName = 'AzureRunAsCertificate'
  )
  $VerbosePreference = 'Continue'
  
  TEC0005-SetAzureContext

  inlineScript
  {
    # Retrieve Certificate from Sandbox  
    $Certificate = Get-AutomationCertificate -Name AzureRunAsCertificate
    Write-Verbose -Message ('TEC0005-CertificateToExport: ' + ($Certificate | Out-String))

    # Map drive to save Certificate 
    $acctKey = ConvertTo-SecureString -String "cj1V0LhBM+QpAGnbcVKQyf/tRkuUxjyRBWu6D1GqVXhcSopkiJmXDhG90FDDYBZl0I+Cf+2Y4Mqt+lRzt6pq4Q==" -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\felwustecore01s", $acctKey
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\felwustecore01s.file.core.windows.net\temp" -Credential $Credential -Persist
 
    # Export Certificate without private key
    #Export-Certificate -Cert $Certificate -FilePath 'Z:\' + $CertificateName +'.cer' -Type CERT 
    Export-Certificate -Cert $Certificate -FilePath 'Z:\AzureRunAsCertificate.cer' -Type CERT 
    
    # Export Certificate with private key
    $Password = ConvertTo-SecureString 'Password' -AsPlainText -Force
    Export-PfxCertificate -Cert $Certificate  -FilePath Z:\AzureRunAsCertificate.pfx -Password $Password 
        
    # Remove mapped drive
    Remove-PSDrive -Name Z
  }
}