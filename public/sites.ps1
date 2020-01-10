function Get-adSubnetsWithoutSite {
	<#
	.SYNOPSIS
	Parse the Netlogon log for IPs not assigned to a site

	.DESCRIPTION
	If a logon occurs from a subnet that has not been assigned to a site,
	the logon will be processed by a DC from any site ... that might not
	be a problem if your network is small and/or fast... but the more sites
	you have, the more you can run into slow logons. And gut forfend you have
	roaming profiles, lots of GPOs, netlogon scripts....

	This script parses the netlogon log file (%SystemRoot%\debug\netlogon.log)
	and breaks out any system/ip info for the error 'no client site' - and
	because of that: * It Needs to Be Run On a DC * (and possy all of them).

	<strikethru>I recommend piping this to "Sort-Object IP -Unique" or
	"Group-Object IP"</strikethru>

	Well, I did recommend that, but now I've just built that in ... please
	note that using these switches mean the output is buffered into those
	commands :)

	.PARAMETER Group
	Pipes the output to Group-Object by IP (also sorts, but not unique)

	.PARAMETER Unique
	Pipes the output to Sort-Object -Unique by IP

	.EXAMPLE
	Get-adSubnetsWithoutSite

	Lists all (or any) "siteless" Systems

	.EXAMPLE
	Get-adSubnetsWithoutSite | Sort-Object IP -Unique

	Sorts the list of "siteless" Systems down to unique IPs

	.EXAMPLE
	Get-adSubnetsWithoutSite -Unique

	Sorts the list of "siteless" Systems down to unique IPs

	.EXAMPLE
	Get-adSubnetsWithoutSite | Group-Object IP

	Groups the list of "siteless" Systems by IPs

	.EXAMPLE
	Get-adSubnetsWithoutSite -Group

	Groups the list of "siteless" Systems by IPs

	#>
	[CmdletBinding(DefaultParameterSetName = 'Unique')]
	param (
		[Parameter(ParameterSetName = 'Group')]
		[switch] $Group = $false,
		[Parameter(ParameterSetName = 'Unique')]
		[switch] $Unique = $false
	)

	[string] $IPLog = "$($env:SystemRoot)\debug\netlogon.log"
	$All = @()
	try {
		if (Test-Path $IPLog -ErrorAction Stop) {
			Get-Content $IPLog | ForEach-Object {
				$a = [string] $_
				if ($a -match 'NO_CLIENT_SITE') {
					$NoClient = New-Object -TypeName PSCustomObject -Property @{
						Date   = $a.Split(' ')[0]
						Time   = $a.Split(' ')[1]
						System = $a.Split(' ')[-2]
						IP     = $a.Split(' ')[-1]
					}
					switch ($true) {
						$Group { $All += $NoClient; break }
						$Unique { $All += $NoClient; break }
						DEFAULT { $NoClient; break }
					}
				}
			}
			if ($All.Count -gt 0) {
				switch ($true) {
					$Group { $All | Sort-Object IP | Group-Object IP; break }
					$Unique { $All | Sort-Object IP -Unique; break }
				}
			}
		} else {
			Write-Status -Message "Could not find file:", $IPLog -Type Error, Warning -Level 1
			Write-Status -Message 'Unfortunately, this needs to run on a DC (at the moment)' -Type Info -Level 2
		}
	} catch {
		Write-Status -Message "Weird... an error occurred. Maybe you're not an admin?" -Type Error -E $_ -Level 1
	}
}

function Get-adSiteInformation {
	<#
	.SYNOPSIS
	Pulls Site Information like name, IPs...

	.DESCRIPTION
	A quick format of various info about Sites

	.EXAMPLE
	Get-adSiteInformation
	#>

	$CurForestName = $env:USERDNSDOMAIN
	$a = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $CurForestName)
	[array] $ADSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a).sites
	$ADSites
}

function Get-adSiteLinkInformation {
	<#
	.SYNOPSIS
	Pulls Site Link info incl. Schedule

	.DESCRIPTION
	Sometimes you need to know the replication schedule....

	.EXAMPLE
	Get-ADSiteLinkInformation

	.LINK
	https://blogs.technet.microsoft.com/ashleymcglone/2011/06/29/report-and-edit-ad-site-links-from-powershell-turbo-your-ad-replication/
	#>

	$SiteCount = @{Name = "SiteCount"; Expression = { $_.SiteList.Count } }
	$SiteSchedule = @{Name = "Schedule"; Expression = { If ($_.Schedule) { If (($_.Schedule -Join " ").Contains("240")) { "NonDefault" }Else { "24x7" } }Else { "24x7" } } }
	Get-ADObject -Filter 'objectClass -eq "siteLink"' -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -Property Options, Cost, ReplInterval, SiteList, Schedule |
	Select-Object Name, $SiteCount, Cost, ReplInterval, $SiteSchedule, Options
}
