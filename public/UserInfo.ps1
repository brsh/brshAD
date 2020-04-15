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
	param (
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
		[pscredential] $Credential
	)
	[int] $Level = 1

	$splat = @{	}
	if ($Server.Trim().Length -gt 0) {
		$splat.Server = $Server
	}
	if ($null -ne $Credential) {
		$splat.Credential = $Credential
	}

	if ($MarkDown -match 'Tree') { $Level = 0 }

	Get-ADPrincipalGroupMembership -Identity $User @splat | Get-ADGroup @splat -Properties description | ForEach-Object {
		Out-GroupInfo -Group $_ -Level $Level -Markdown $Markdown
		$_ | Get-ParentGroup -Level ($Level + 1) -Markdown $Markdown @splat
	}
}
