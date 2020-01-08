function Get-NextAvailableID {
	param (
		[string] $type = 'GID',
		[string] $Domain,
		[pscredential] $Credential
	)

	$splat = @{
		Domain = $Domain
	}

	if ($Credential) {
		$splat.Credential = $Credential
	}

	$Nis = Get-ypConfig @splat

	if ($null -ne $Nis) {
		if ($type -match '^U') {
			[int] $highest = $Nis.msSFU30MaxUidNumber
		} else {
			[int] $highest = $Nis.msSFU30MaxGidNumber
		}
		New-Object -TypeName PSCustomObject -Property @{
			PSTypeName = 'brshAD.NextLinuxID'
			Highest    = $highest
			Next       = $highest + 1
		}
	} else {
		Write-Status 'No value available for Max ID' -Type 'Error' -Level 0
	}
}

function Set-NextAvailableID {
	param (
		[string] $type = 'GID',
		[string] $Domain = $env:USERDOMAIN,
		[pscredential] $Credential
	)
	#! If successful, returns the NextLinuxID Object

	$splat = @{
		Domain = $Domain
	}

	if ($Credential) {
		$splat.Credential = $Credential
	}

	$Max = Get-NextAvailableID @splat -Type $type

	$Nis = Get-ypConfig @splat

	Try {
		if ($null -ne $Nis) {
			if ($type -match '^U') {
				# $objSplat.Replace = @{ msSFU30MaxUidNumber = $max.Next }
				# Set-ADObject @objSplat
				Set-AdObject $Nis -Replace @{ msSFU30MaxUidNumber = $max.Next } -ErrorAction Stop
			} else {
				# $objSplat.Replace = @{ msSFU30MaxGidNumber = $max.Next }
				# Set-ADObject @objSplat
				Set-AdObject $Nis -Replace @{ msSFU30MaxGidNumber = $max.Next } -ErrorAction Stop
			}
			$max
		} else {
			Write-Status 'No value available to set Max ID' -Type 'Error' -Level 0
		}
	} catch {
		Write-Status 'Could not set MaxID!' -E $_ -Type 'Error' -Level 0
	}
}

function Get-ypConfig {
	param (
		[string] $Domain = $env:USERDOMAIN,
		[pscredential] $Credential
	)
	$splat = @{
		Domain = $Domain
		Quiet  = $true
	}
	if ($Credential) {
		$splat.Credential = $Credential
	}
	$FullDomain = Get-DomainInfo @splat

	$objSplat = @{
		Properties  = '*'
		Server      = $FullDomain.DNSRoot
		Identity    = "CN=$($FullDomain.NetBIOSName),CN=ypServers,CN=ypServ30,CN=RpcServices,CN=System,$($FullDomain.DistinguishedName)"
		ErrorAction = 'Stop'
	}
	if ($Credential) {
		$objSplat.Credential = $Credential
	}

	try {
		get-ADObject @objSplat
	} catch {
		write-status -Message 'Could not get Yellow Pages config' -Type Error -E $_ -Level 0
	}
}
