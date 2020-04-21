function Get-adUsersGroups {
	<#
	.SYNOPSIS
	Gets the groups a user is a member of

	.DESCRIPTION
	A recursive search of all the domain groups a user is a member of. Supply a user, and
	it will do the rest.

	I use this mostly for reporting back in jira - so one of the outputs is markdown
	intended to make copypasta simple. It does both lists and tables (or it tries to,
	anyway... copypasta lists to jira doesn't always work - and jira will drop lines with
	a hashtag). It also does a tree and object outputs.

	.PARAMETER User
	The user (or group .. it can do groups) name

	.PARAMETER MarkDown
	The type of markdown to output. None, List, Table, and Tree

	.PARAMETER Server
	The domain or specific DC to connect to (note: domain can fail if a DC is not reachable)

	.PARAMETER Credential
	User with rights to read the info

	.EXAMPLE
	Get-adUsersGroup username

	.EXAMPLE
	Get-adUsersGroup -User username -Server dc1.mydomain.com -credential $(get-credential)

	.NOTES
	General notes
	#>
	[CmdletBinding(DefaultParameterSetName = 'NoPic')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Pic')]
		[Parameter(Mandatory = $true, ParameterSetName = 'NoPic')]
		[Alias('Username', 'Name')]
		$User,
		[ValidateSet('Tree', 'List', 'Table', 'None')]
		[string] $MarkDown = 'None',
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-ADForest).Domains | Sort-Object | Where-Object { $_ -match $WordToComplete }
				} else {
					(Get-ADForest).Domains
				}
			})]
		[alias('Domain')]
		[string] $Server = '',
		[pscredential] $Credential,
		[Parameter(Mandatory = $true, ParameterSetName = 'Pic')]
		[Parameter(Mandatory = $false, ParameterSetName = 'NoPic')]
		[Alias('Save', 'Image', 'Jpg')]
		[switch] $Picture = $false,
		[Parameter(Mandatory = $true, ParameterSetName = 'Pic')]
		[Alias('Path', 'SaveTo')]
		[ValidateScript( {
				If (Test-Path -Path $_.ToString() -PathType Container) {
					$true
				} else {
					Throw "$_ is not a valid destination folder. Enter in 'c:\directory' format"
				}
			})]
		[string] $folder = $(if ($PSCommandPath) { (Split-Path -Parent $PSCommandPath) + '\' } else { '.\' } )
	)
	[int] $Level = 0

	$splat = @{	}
	if ($Server.Trim().Length -gt 0) {
		$splat.Server = $Server
	}
	if ($null -ne $Credential) {
		$splat.Credential = $Credential
	}

	if ($MarkDown -match 'Tree') { $Level = 0 }

	$obj = Get-ADUser -LDAPFilter "(SAMAccountName=$User)" @splat -errorAction SilentlyContinue

	if ($null -eq $obj) {
		$obj = Get-ADGroup -LDAPFilter "(SAMAccountName=$User)" @splat -errorAction SilentlyContinue
	}

	if ($null -ne $Obj) {
		$ret = $Obj | get-adobject | Get-ParentGroup -Level $Level -Markdown $Markdown @splat
		if (-not $psboundparameters.ContainsKey('Picture')) {
			$ret
		} else {
			[string] $DN = $obj.DistinguishedName
			[string] $Domain = ($DN -split 'DC=')[1].Trim(',')
			$RunTime = get-date
			[string] $FileName = "$($obj.samAccountName)_$Domain"
			[string] $text = "Run Time: {0}" -f (get-date $RunTime -UFormat "%a, %b %d, %Y -- %r UTC%Z") | Out-String
			$text += "" | Out-String
			$text += "Domain: $Domain"
			$text += "" | Out-String
			$text += "Object: $DN"
			$text += "" | Out-String
			$text += ($ret | format-table -Wrap | out-string).Trim("`n").TrimStart("`n")

			DrawIt -Text $text -Filename "${Folder}\${filename}$(get-date $RunTime -f '_yyyy_MM-dd_HHmm').png"
		}
	}
}
