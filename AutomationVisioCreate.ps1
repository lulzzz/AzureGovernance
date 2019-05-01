<# 
	This PowerShell script was automatically converted to PowerShell Workflow so it can be run as a runbook.
	Specific changes that have been made are marked with a comment starting with “Converter:”
#>
workflow AutomationVisioCreate {
	
	# Converter: Wrapping initial script in an InlineScript activity, and passing any parameters for use within the InlineScript
	# Converter: If you want this InlineScript to execute on another host rather than the Automation worker, simply add some combination of -PSComputerName, -PSCredential, -PSConnectionURI, or other workflow common parameters (http://technet.microsoft.com/en-us/library/jj129719.aspx) as parameters of the InlineScript
	inlineScript {
		﻿# File Locations
		$PatternStencilLocation = 'D:\OneDrive\Documents\WindowsPowerShell\Core-co - ae747229-5897-4d01-93bb-284e69893c47\weu-co-rsg-automation-01\weu-co-aut-prod-01\AutomationVisioCreatePatternStencil.vssx'
		$RunbookLocation = 'D:\OneDrive\Documents\WindowsPowerShell\Core-co - ae747229-5897-4d01-93bb-284e69893c47\weu-co-rsg-automation-01\weu-co-aut-prod-01'
		
		# Create Visio Object - open Visio
		$Visio = New-Object -ComObject Visio.Application 
		
		# Create new document on basic template and set as active page
		$Documents = $visio.Documents
		$Document = $Documents.Add("Basic Diagram.vst") 
		$Pages = $Visio.ActiveDocument.Pages
		$Page = $Pages.Item(1)
		Write-Verbose -Message 'File Opened'
		
		# Open the DB Crow Stencil and define shape data
		$PatternStencil = $PatternStencilLocation
		$Stencil = $Visio.Documents.Add($PatternStencil)
		$EntityShape = $stencil.Masters.Item("Entity") 
		$InputParameterShape = $stencil.Masters.Item("Input") 
		$OutputParameterShape = $stencil.Masters.Item("Output") 
		$CalledRunbookShape = $stencil.Masters.Item("Patterns Called") 
		$PowerShellModulesShape = $stencil.Masters.Item("Modules Used") 
		$SeparatorShape = $stencil.Masters.Item("Separator") 
		Write-Verbose -Message 'Stencil Opened'
		
		# Get all Runbook files 
		Set-Location $RunbookLocation
		$Files = Get-ChildItem  -Name PAT*, TEC*, SOL*
		$Counter = 0
		
		# Process each Runbook file
		foreach ($File in $Files)
		{
  		# Defines the spacing between Entities
  		$Counter = $Counter + 5
  		$Content = Get-Content $File
  		$InputParameters = @()
  		$CalledRunbooks = @()
  		$OutputParameters = @()
  		$PowerShellModules = @()
		
		# Find the input and output parameters
  		foreach ($Line in $Content)
  		{
    		# Get the Input Parameters
    		if ($Line -match 'Mandatory') 
    		{
      		$InputParameter = (($Line.Split('$')[2]).split('=')[0]).split(' ')[0]
      		$InputParameters = $InputParameters + ('$' + $InputParameter)
    		}
		
    		# Get the Output Parameters
    		if ($Line -match 'Output:') 
    		{
      		$OutputParameter = ($Line -Split('Output:         '))[1]
      		$OutputParameters = $OutputParameters + $OutputParameter -Split(', ')
    		}
		
    		# Get called Runbooks
    		if ($Line -match "TEC\d{4}-(.+)" -or $Line -match "PAT\d{4}-(.+)" -and $Line -notmatch $File.Split('-')[0])
    		{
      		$CalledRunbooks = $CalledRunbooks + ($Matches[0] -split (' '))[0]
    		}
		
    		# Get required PowerShell Modules
    		if ($Line -match 'Import-Module') 
    		{
      		$PowerShellModules = ($Line -Split('Import-Module '))[1]
      		$PowerShellModules = $PowerShellModules -Split(', ')
    		}
		
  		}
  		$Calledrunbooks = $Calledrunbooks | Sort-Object -Unique
		
  		# Create a new Entity shape
  		$Shape = $Page.Drop($EntityShape, $Counter, 8) 
  		$Shape.Text = $File.Split('.')[0]
		
  		# Add attributes to the Entity shape for input and output parameters
  		$Sequence = 0
  		foreach ($InputParameter in $InputParameters)  
  		{
    		$Sequence++
    		$Attribute = $Page.DropIntoList($InputParameterShape, $Shape, $Sequence)
    		$Attribute.Text = ("$InputParameter")
  		}
		
  		$Sequence++
  		$Attribute = $Page.DropIntoList($SeparatorShape, $Shape, $Sequence)
		
  		foreach ($OutputParameter in $OutputParameters)  
  		{
    		$Sequence++
    		$Attribute = $Page.DropIntoList($OutputParameterShape, $Shape, $Sequence)
    		$Attribute.Text = ("$OutputParameter")
  		}
  		
  		$Sequence++
  		$Attribute = $Page.DropIntoList($SeparatorShape, $Shape, $Sequence)
		
  		foreach ($CalledRunbook in $CalledRunbooks)  
  		{
    		$Sequence++
    		$Attribute = $Page.DropIntoList($CalledRunbookShape, $Shape, $Sequence)
    		$Attribute.Text = ("$CalledRunbook")
  		}
		
  		$Sequence++
  		$Attribute = $Page.DropIntoList($SeparatorShape, $Shape, $Sequence)
		
  		foreach ($PowerShellModules in $PowerShellModules)  
  		{
    		$Sequence++
    		$Attribute = $Page.DropIntoList($PowerShellModulesShape, $Shape, $Sequence)
    		$Attribute.Text = ("$PowerShellModules")
  		}
  		Write-Verbose -Message "Diagram created for: $File"
		}
		
	}
}