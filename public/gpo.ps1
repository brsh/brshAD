function Find-adGPOSetting {
	<#
	.SYNOPSIS
	Search all GPOs for specific text

	.DESCRIPTION
	Combs through all the GPOs in a domain and tries to find specific text.
	Cuz, as far as I can tell, it's not possible (easily) to find which GPO
	is setting a setting. Of course, you still need to know what the text
	of the setting _is_ in order to search for it, but that's actually
	pretty easy, since there's even an excel spreadsheet that lists these
	things. Plus, ya know, the search site of your choice.

	Inspired by/based on Search-GPOsForString.ps1 by Tony Murray
	https://gallery.technet.microsoft.com/scriptcenter/Search-all-GPOs-in-a-b155491c

	.PARAMETER SearchText
	The text to search for

	.PARAMETER Domain
	The FQDN of the domain to query (you have to be able to reach and be auth'd by it)

	.EXAMPLE
	Find-adGPOSetting -SearchText 'Always prompt for password upon connection'

	.LINK
	https://gallery.technet.microsoft.com/scriptcenter/Search-all-GPOs-in-a-b155491c
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias('Text')]
		[string] $SearchText,
		[string] $Domain = $env:USERDNSDOMAIN
	)

	Write-Verbose 'Importing GroupPolicy module'
	Import-Module GroupPolicy -ErrorAction SilentlyContinue -Verbose:$false

	if (Get-Module GroupPolicy) {
		$allGposInDomain = Get-GPO -All -Domain $DomainName -ErrorAction SilentlyContinue | Sort-Object DisplayName
		Write-Verbose "Found $($allGposInDomain.Count) GPOs"
		foreach ($gpo in $allGposInDomain) {
			$resp = [ordered] @{
				PSTypeName       = 'brshAD.GPOSearch'
				Found            = $false
				Name             = $gpo.DisplayName
				ID               = $gpo.ID
				Owner            = $gpo.Owner
				CreationTime     = $gpo.CreationTime
				ModificationTime = $gpo.ModificationTime
				Status           = $gpo.GPOStatus
				WMIFilter        = $gpo.WMIFilter.Name
				Path             = $gpo.Path
			}
			$Report = Get-GPOReport -Guid $gpo.Id -ReportType Xml

			if ($Report -match $SearchText) {
				$resp.Found = $True
			}
			# else {
			# 	$resp.Found = $false
			# }
			[PSCustomObject] $resp
		}
	} else {
		Write-Verbose 'GroupPolicy module not imported... maybe not found?'
	}
}
