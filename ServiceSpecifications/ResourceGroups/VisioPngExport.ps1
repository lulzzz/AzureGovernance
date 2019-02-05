# Create Visio application object
$VisioApp = New-Object -ComObject Visio.Application

# Parameters
$FileDirectory = 'D:\OneDrive\Documents\WindowsPowerShell\wiki\AzureGovernance.wiki\ServiceSpecifications\ResourceGroups' 
$FileBaseName = $null
$Document = $VisioApp.Documents.Open('D:\OneDrive\Documents\WindowsPowerShell\wiki\AzureGovernance.wiki\ServiceSpecifications\ResourceGroups\Resource-Groups.vsdx')

# Export
$Pages = $VisioApp.ActiveDocument.Pages
$intPageNumber = 1
Foreach($Page in $Pages)
{
  $Page.Export("$FileDirectory\$($FileBaseName)$($Page.Name).png") 
  $intPageNumber++
}

# Close document and Visio
$Document.Close()
$VisioApp.Quit()



