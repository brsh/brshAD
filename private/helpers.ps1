function Split-Domain {
	param (
		[string] $Domain
	)
	if ($Domain.Split('.')[0] -ne $Domain) {
		$Domain.Split('.')[0].Trim()
	} else {
		$Domain.Trim()
	}
}

function Get-DomainInfo {
	param (
		[string] $Domain,
		[pscredential] $Credential,
		[switch] $Quiet = $false
	)
	$Splat = @{
		Server      = $Domain
		ErrorAction = 'Stop'
	}
	if ($Credential) {
		$Splat.Credential = $Credential
	}

	try {
		if (-not $Quiet) {
			Write-Status -Message "Attempting to get info about the Domain $Domain" -Type Info -Level 0
		}
		$FullDomain = Get-ADDomain @splat
	} catch {
		Write-Status "Could not pull information on the domain - will try to make it up" -e $_ -Type Warning -Level 1
		$FullDomain = @{
			NetBIOSName = Split-Domain -Domain $Domain
		}

		if ($Domain.Split('.')[0] -ne $Domain) {
			$q = ''
			$Domain.Split('.') | ForEach-Object { $q = "${q}dc=$($_.Trim())," }
			$FullDomain.DistinguishedName = $q.TrimEnd(',').Trim()
			$FullDomain.DNSRoot = $Domain
		} else {
			$FullDomain.DistinguishedName = "dn=$($Domain.Trim()),dn=com"
			$FullDomain.DNSRoot = "$($Domain.Trim())`.com"
		}

	}
	if (-not $Quiet) {
		Write-Status -Message "Domain DN: ", $FullDomain.DistinguishedName -Type Good, Info -Level 1
	}
	$FullDomain
}

function Write-User {
	param (
		$user,
		[int] $Level = 0,
		[Switch] $After = $false
	)

	$splat = @{
		Type  = 'Warning', 'Info'
		Level = $Level
	}

	[string] $When = "Before"
	if ($After) { $When = "After" }

	[pscustomobject] @{
		PSTypeName     = 'brshAD.UserEdit'
		Name           = $User.Name
		DN             = $User.DistinguishedName
		samAccountName = $User.samAccountName
		uID            = $User.uidNumber
		gID            = $User.gidNumber
		Shell          = $User.loginShell
		Home           = $User.unixHomeDirectory
		When           = $When
	}
}

function Test-IsVerbose {
	[CmdletBinding()]
	param()
	[System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference
}

function Test-IsAdmin {
	[bool]$IsAdmin = $false
	if ( ([System.Environment]::OSVersion.Version.Major -gt 5) -and ( # Vista and ...
			new-object Security.Principal.WindowsPrincipal (
				[Security.Principal.WindowsIdentity]::GetCurrent()) # current user is admin
		).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
		$IsAdmin = $True
	} else {
		$IsAdmin = $False
	}
	$IsAdmin
}

function Get-TitleCase {
	param (
		[string] $String = 'no text specified'
	)
	(Get-Culture).TextInfo.ToTitleCase($String)
}
