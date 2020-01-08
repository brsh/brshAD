function Get-adLinuxUser {
	<#
	.SYNOPSIS
	Gets users and their *nix UID

	.DESCRIPTION
	All AD users that are *nix enabled have a user ID that *nix then references for permissions on
	resources (like files, folders, ... everything just about). This function, by default, pulls a
	list of all users that are *nix enabled - listing them with their UID. You can filter by AccountName
	and by uid.

	You also have the option to include non-*nix enable users, if you happen to be looking for them.
	BUT, only if you filter on an actual AccountName ... there (generally) are too many users to return
	otherwise....

	.PARAMETER uid
	Allows filtering on a specific UID

	.PARAMETER samAccountName
	Allows filtering on a partial name - will match the text anywhere in the Account Name

	.PARAMETER IncludeNonNixUsers
	Include users that are not nix enabled

	.EXAMPLE
	Get-adLinuxUser

	Returns all *nix enabled users

	.EXAMPLE
	Get-adLinuxUser -uid 10000

	Returns the user with UID 10000 (or nothing if there is no user with that UID)

	.EXAMPLE
	Get-adLinuxUser -samAccountName dev

	Returns all *nix enabled users with 'dev' in the Account Name

	.EXAMPLE
	Get-adLinuxUser -samAccountName dev -IncludeNonNixGroups

	Returns all *nix enabled users with dev in the Account Name even if they are not *nix enabled
	#>

	param (
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxUser | Sort-Object uidNumber | Where-Object { $_.uidNumber -match $WordToComplete }).uidNumber
				} else {
					(Get-adLinuxUser | Sort-Object uidNumber).uidNumber
				}
			})]
		[Parameter(Mandatory = $true, ParameterSetName = 'uid', Position = 0)]
		[int] $uid,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxUser | Where-Object { $_.samAccountName -match $WordToComplete }).samAccountName
				} else {
					(Get-adLinuxUser).samAccountName
				}
			})]
		[Parameter(Mandatory = $false, ParameterSetName = 'name', Position = 0)]
		[string] $samAccountName,
		[string] $Domain = $env:USERDOMAIN,
		[pscredential] $Credential,
		[Parameter(Mandatory = $false, ParameterSetName = 'name', Position = 0)]
		[switch] $IncludeNonNixUsers = $false
	)

	[string] $filter = "uidNumber -like '*'"

	if ($PSBoundParameters.ContainsKey('uid')) {
		$filter = "uidNumber -like $uid"
	} else {
		if ($samAccountName.trim().Length -gt 0) {
			if ($IncludeNonNixUsers) {
				$filter = "samAccountName -like '*$samAccountName*'"
			} else {
				$filter = "uidNumber -like '*' -and samAccountName -like '*$samAccountName*'"
			}
		}
	}

	$FullDomain = Get-DomainInfo -Domain $Domain -Credential $Credential -Quiet

	$splatUser = @{
		Server     = $FullDomain.DNSRoot
		Filter     = $filter
		Properties = 'uidNumber', 'unixHomeDirectory', 'loginShell', 'gidNumber', 'msSFU30NisDomain'
	}

	$splatDomain = @{
		Server = $FullDomain.DNSRoot
	}

	if ($Credential) {
		$splatUser.Credential = $Credential
		$splatDomain.Credential = $Credential
	}

	try {
		#Get-ADUser -filter $filter -Properties uidNumber, unixHomeDirectory, loginShell, gidNumber, msSFU30NisDomain @splat | Sort-Object samAccountName | ForEach-Object {
		Get-ADUser @splatUser | Sort-Object samAccountName | ForEach-Object {
			$_.PSTypeNames.Insert(0, "brshAD.LinuxUser")
			$name = $_.samAccountName
			$gid = $_.gidNumber
			try {
				if (($null -ne $_.gidNumber) -and ($_.gidNumber -ge 0) ) {
					$group = get-adGroup -filter "gidNumber -eq $($_.gidNumber)" @splatDomain
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupName' -Value $group.Name -ErrorAction Stop -Force
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupDistinguishedName' -Value $group.DistinguishedName -ErrorAction Stop -Force
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupsamAccountName' -Value $group.samAccountName -ErrorAction Stop -Force
				} else {
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupName' -Value '' -ErrorAction Stop -Force
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupDistinguishedName' -Value '' -ErrorAction Stop -Force
					Add-Member -InputObject $_ -MemberType NoteProperty -Name 'unixGroupsamAccountName' -Value '' -ErrorAction Stop -Force
				}
			} catch {
				Write-Status "Could not query gidNumber from AD" -e $_ -Type "Error" -Level 0
				Write-status "Name:", $name -type Warning, Info -Level 1
				Write-status "gid :", $gid -type Warning, Info -Level 1
			}
			$_
		}
	} catch {
		Write-Status "Could not query AD" -e $_ -Type "Error" -Level 0
	}
}

function Get-adLinuxGroup {
	<#
	.SYNOPSIS
	Gets groups and their *nix GID

	.DESCRIPTION
	All AD groups that are *nix enabled have a group ID that *nix then references for permissions on
	resources (like files, folders, ... everything just about). This function, by default, pulls a
	list of all groups that are *nix enabled - listing them with their GID. You can filter by name
	and by gid.

	You also have the option to include non-*nix enable groups, if you happen to be looking for them.
	BUT, only if you filter on an actual name ... there (generally) are too many groups to return
	otherwise....

	.PARAMETER gid
	Allows filtering on a specific GID

	.PARAMETER Name
	Allows filtering on a partial name - will match the text anywhere in the group name

	.PARAMETER IncludeNonNixGroups
	Include groups that are not nix enabled

	.EXAMPLE
	Get-adLinuxGroup

	Returns all *nix enabled groups

	.EXAMPLE
	Get-adLinuxGroup -gid 10000

	Returns the group with GID 10000 (or nothing if there is no group with that GID)

	.EXAMPLE
	Get-adLinuxGroup -Name dev

	Returns all *nix enabled groups with 'dev' in the name

	.EXAMPLE
	Get-adLinuxGroup -Name dev -IncludeNonNixGroups

	Returns all *nix enabled groups with dev in the name even if they are not *nix enabled
	#>

	[CmdLetBinding(DefaultParameterSetName = 'name')]
	param (
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxGroup | Sort-Object gidNumber | Where-Object { $_.gidNumber -match $WordToComplete }).gidNumber
				} else {
					(Get-adLinuxGroup | Sort-Object gidNumber).gidNumber
				}
			})]
		[Parameter(Mandatory = $true, ParameterSetName = 'gid', Position = 0)]
		[int] $gid,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxGroup | Where-Object { $_.Name -match $WordToComplete }).Name
				} else {
					(Get-adLinuxGroup).Name
				}
			})]
		[Parameter(Mandatory = $false, ParameterSetName = 'name', Position = 0)]
		[string] $Name,
		[string] $Domain = $env:USERDOMAIN,
		[pscredential] $Credential,
		[Parameter(Mandatory = $false, ParameterSetName = 'name', Position = 0)]
		[switch] $IncludeNonNixGroups = $false
	)

	$FullDomain = Get-DomainInfo -Domain $Domain -Credential $Credential -Quiet

	[string] $filter = "gidNumber -like '*'"

	if ($PSBoundParameters.ContainsKey('gid')) {
		$filter = "gidNumber -like $gid"
	} else {
		if ($name.trim().Length -gt 0) {
			if ($IncludeNonNixGroups) {
				$filter = "name -like '*$name*'"
			} else {
				$filter = "gidNumber -like '*' -and name -like '*$name*'"
			}
		}
	}

	$splatDomain = @{
		Server     = $FullDomain.DNSRoot
		Filter     = $filter
		Properties = 'gidNumber', 'msSFU30NisDomain'
	}

	if ($Credential) {
		$splatDomain.Credential = $Credential
	}

	try {
		Get-ADGroup @splatDomain | Sort-Object Name | ForEach-Object {
			$_.PSTypeNames.Insert(0, "brshAD.LinuxGroup")
			$_
		}
	} catch {
		Write-Status "Could not query AD" -e $_ -Type "Error" -Level 0
	}
}

function Get-adLinuxNextAvailableGID {
	param (
		[string] $Domain = $ENV:USERDNSDOMAIN,
		[pscredential] $Credential,
		[switch] $AsObject = $false
	)

	$splat = @{
		Type   = 'GID'
		Domain = $Domain
	}

	if ($Credential) {
		$splat.Credential = $Credential
	}

	$retval = Get-NextAvailableID @splat
	if ($AsObject) {
		$retval
	} else {
		$retval.Next
	}
}

function Get-adLinuxNextAvailableUID {
	param (
		[string] $Domain = $ENV:USERDNSDOMAIN,
		[pscredential] $Credential,
		[switch] $AsObject = $false
	)
	$splat = @{
		Type   = 'UID'
		Domain = $Domain
	}

	if ($Credential) {
		$splat.Credential = $Credential
	}

	$retval = Get-NextAvailableID @splat
	if ($AsObject) {
		$retval
	} else {
		$retval.Next
	}
}



function Disable-adLinuxUser {
	<#
	.SYNOPSIS
	Disables the Linux login for a user (or removes the attribs completely)

	.DESCRIPTION
	Sometimes you need to keep a *nix enabled user from being a *nix enabled user.
	The simplest way is to remove all *nix attributes - boom done! But... that's
	not necessarily the best way: it "orphans" the UID.

	But wait, there's another way: set the user's login shell to something
	fake - like /bin/false instead of /bin/bash. That way, if they try to log in to
	a *nix box, it can't load a shell and login fails. And you can re-enable them
	later just by setting a real shell and their UID is intact and safe and their
	perms continue to be valid.

	This script, by default, sets the login shell to /bin/false thereby 'disabling'
	the *nix-ness of the user.

	This script can also remove all the *nix attribs, in the event you want to do
	that. It's not recommended, but you can do it if you want - just use the
	RemoveAll switch - boom done.

	.PARAMETER uid
	The UID of the user to disable

	.PARAMETER samAccountName
	The Account Name of the user to disable

	.PARAMETER RemoveAll
	Remove all *nix attributes - not the preferred option :)

	.PARAMETER Force
	Just do it, don't ask for confirmation

	.PARAMETER WhatIf
	Just tell me what you _would_ do without the WhatIf switch

	.EXAMPLE
	Disable-adLinuxUser -uid 1000

	Disables the user with uid 1000

	.EXAMPLE
	Disable-adLinuxUser -samAccountName AUser -Force

	Disables the AUser without pausing to ask for confirmation

	.EXAMPLE
	Disable-adLinuxUser -uid 1000 -RemoveAll

	Removes all *nix attributes from the user with UID 1000 ... incl that UID!!
	#>
	[CmdletBinding(DefaultParameterSetName = 'name')]
	param (
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxUser | Sort-Object uidNumber | Where-Object { $_.uidNumber -match $WordToComplete }).uidNumber
				} else {
					(Get-adLinuxUser | Sort-Object uidNumber).uidNumber
				}
			})]
		[Parameter(Mandatory = $true, ParameterSetName = 'uid', Position = 0, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
		[int] $uid,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adLinuxUser | Where-Object { $_.samAccountName -match $WordToComplete }).samAccountName
				} else {
					(Get-adLinuxUser).samAccountName
				}
			})]
		[Parameter(Mandatory = $true, ParameterSetName = 'name', Position = 0, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
		[string] $samAccountName,
		[string] $Domain = $env:USERDOMAIN,
		[pscredential] $Credential,
		[switch] $RemoveAll = $false,
		[switch] $Force = $false,
		[switch] $WhatIf = $false
	)

	$FullDomain = Get-DomainInfo -Domain $Domain -Credential $Credential -Quiet

	$SplatUser = @{
		Domain = $FullDomain.DNSRoot
	}

	if ($Credential) {
		$SplatUser.Credential = $Credential
	}

	if ($PSBoundParameters.ContainsKey('uid')) {
		$splatUser.uid = $uid
	} else {
		$splatUser.samAccountName = $samAccountName
	}

	#Write-Status 'Validating user...' -Type Info -Level 0
	$user = Get-adLinuxUser @SplatUser

	if ($null -eq $user) {
		Write-Status 'User not found' -Type Error -Level 0
		Write-Status 'Probably not a linux enabled user (or bad creds). Aborting' -Type Warning -Level 1
	} else {
		#Write-Status 'User found!' -Type 'Good' -Level 1
		Write-User -User $user -Level 2

		$splat = @{
			Server      = $FullDomain.DNSRoot
			Identity    = $user.SamAccountName
			ErrorAction = 'Stop'
			WhatIf      = $WhatIf
			Confirm     = -not $Force
		}

		if ($Credential) {
			$splat.Credential = $Credential
		}

		if (-not $RemoveAll) {
			try {
				#Write-Status -Message 'Attempting to disable linux for user' -Type Info -Level 0
				$splat.Replace = @{ loginShell = "/bin/false" }
				Set-ADUser @splat
			} catch {
				Write-Status -Message 'Error setting AD attribute' -e $_ -type Error -Level 1
			}
		} else {
			try {
				#Write-Status -Message 'Attempting to clear all linux attributes for user' -Type Info -Level 0
				#Write-Status -Message 'RemoveAll option enabled!' -Type Warning -Level 1
				$splat.Clear = 'msSFU30Name', 'uid', 'msSFU30NisDomain', 'uidNumber', 'gidNumber', 'loginShell', 'unixHomeDirectory'
				Set-adUser @splat
			} catch {
				Write-Status -Message 'Error clearing AD attributes' -e $_ -type Error -Level 1
			}
		}
		#Write-Status 'Re-Validating user...' -Type Info -Level 0
		$user = Get-adLinuxUser @SplatUser
		if ($null -eq $user) {
			Write-Status 'User not found' -Type Error -Level 0
			if ($RemoveAll) {
				Write-Status "That's expected when you remove all attributes" -Type Good -Level 1
			} else {
				Write-Status "That probably not good..." -Type Warning -Level 1
			}
		} else {
			#Write-Status 'User found!' -Type 'Good' -Level 1
			Write-User -User $user -Level 2 -After
		}
		Write-Host ''
	}
}
