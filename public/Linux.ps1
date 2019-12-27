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

	try {
		Get-ADUser -filter $filter -Properties uidNumber, unixHomeDirectory, loginShell, gidNumber | Sort-Object samAccountName | ForEach-Object {
			$_.PSTypeNames.Insert(0, "brshAD.LinuxUser")
			$name = $_.samAccountName
			$gid = $_.gidNumber
			try {
				if (($null -ne $_.gidNumber) -and ($_.gidNumber -ge 0) ) {
					$group = get-adGroup -filter "gidNumber -eq $($_.gidNumber)"
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
				Write-status "Name: ", $name -type Warning, Info -Level 1
				Write-status "gid : ", $gid -type Warning, Info -Level 1
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
		[Parameter(Mandatory = $false, ParameterSetName = 'name', Position = 0)]
		[switch] $IncludeNonNixGroups = $false
	)
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

	try {
		Get-ADGroup -filter $filter  -Properties gidNumber | Sort-Object Name | ForEach-Object {
			$_.PSTypeNames.Insert(0, "brshAD.LinuxGroup")
			$_
		}
	} catch {
		Write-Status "Could not query AD" -e $_ -Type "Error" -Level 0
	}
}

function Get-adLinuxNextAvailableGID {
	param (
		[switch] $AsObject = $false
	)
	$retval = Get-NextAvailableID -Type 'GID'
	if ($AsObject) {
		$retval
	} else {
		$retval.Next
	}
}

function Get-adLinuxNextAvailableUID {
	param (
		[switch] $AsObject = $false
	)
	$retval = Get-NextAvailableID -Type 'UID'
	if ($AsObject) {
		$retval
	} else {
		$retval.Next
	}
}
