# Create Visio application object
$VisioApp = New-Object -ComObject Visio.Application

# Parameters
$FileDirectory = 'D:\OneDrive\Documents\WindowsPowerShell\wiki\AzureGovernance.wiki\Runbooks' 
$FileBaseName = $null
$Document = $VisioApp.Documents.Open('D:\OneDrive\Documents\WindowsPowerShell\wiki\AzureGovernance.wiki\Runbooks\Runbooks.vsdx')

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



