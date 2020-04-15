function Get-ParentGroup {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		$group,
		[int] $level,
		[string] $MarkDown = 'None',
		[String] $Server = '',
		[pscredential] $Credential
	)

	BEGIN {
		$splat = @{ }
		if ($Server.Trim().Length -gt 0) {
			$splat.Server = $Server
		}
		if ($null -ne $Credential) {
			$splat.Credential = $Credential
		}
	}

	PROCESS {
		$retval = $group | Get-ADPrincipalGroupMembership @splat | Get-ADGroup -Properties Description @splat
		if ($retval) {
			$retval | foreach-object {
				Out-GroupInfo -Group $_ -Level $Level -Markdown $Markdown -Parent $Group.samAccountName
				$_ | Get-ParentGroup -Level ($Level + 1) -Markdown $Markdown @splat
			}
		}
	}
}

function Out-GroupInfo {
	param (
		$Group,
		[int] $Level,
		[string] $Parent = '',
		[string] $MarkDown = 'None'
	)

	[string] $Name = $_.samAccountName
	[string] $Description = "$($_.Description)"
	if ($Description.Trim().Length -eq 0) {
		$Description = 'No description'
	}
	switch ($MarkDown) {
		'Tree'	{ write-host "|-$('--' * $Level)$Name"; break }
		'List'	{ write-host "$('*' * $Level) $Name - $Description"; break }
		'Table'	{ write-host "| $('*' * $Level) $Name | $Description |"; break }
		Default {
			[pscustomobject] @{
				Group       = $Name
				Parent      = $Parent
				Description = $Description
			}
			break
		}
	}
}
