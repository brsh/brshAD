function Get-adSubnetsWithoutSite {
	<#
	.SYNOPSIS
	Parse the Netlogon log for IPs not assigned to a site

	.DESCRIPTION
	If a logon occurs from a subnet that has not been assigned to a site,
	the logon will be processed by a DC from any site ... that might not
	be a problem if your network is small and/or fast... but the more sites
	you have, the more you can run into slow logons. And gut forfend you have
	roaming profiles, lots of GPOs, netlgon scripts....

	This script parses the netlogon log file (%SystemRoot%\debug\netlogon.log)
	and breaks out any system/ip info for the error 'no client site'

	I recommend piping this to "Sort-Object IP -Unique" or "Group-Object IP"

	.EXAMPLE
	Get-adSubnetsWithoutSite

	Lists all (or any) "siteless" Systems

	.EXAMPLE
	Get-adSubnetsWithoutSite | Sort-Object IP -Unique

	Sorts the list of "siteless" Systems down to unique IPs

	.EXAMPLE
	Get-adSubnetsWithoutSite | Group-Object IP

	Groups the list of "siteless" Systems by IPs
	#>

	[string] $IPLog = "$($env:SystemRoot)\debug\netlogon.log"
	if (Test-Path $IPLog ) {
		Get-Content $IPLog | ForEach-Object {
			$a = [string] $_
			if ($a -match 'NO_CLIENT_SITE') {
				New-Object -TypeName PSCustomObject -Property @{
					Date   = $a.Split(' ')[0]
					Time   = $a.Split(' ')[1]
					System = $a.Split(' ')[-2]
					IP     = $a.SPlit(' ')[-1]
				}
			}
		}
	} else {
		Write-Status -Message "Could not find file:", $IPLog -Type Error, Warning -Level 1
	}
}
