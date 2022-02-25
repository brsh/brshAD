function Get-adLiveComputer {
	<#
	.SYNOPSIS
	Mixes Get-ADComputer with ping to pull a list of "online" computers

	.DESCRIPTION
	This function tries to get a list of recently active computers based on the
	replicated LastLogonTimeStamp in AD. The problem with this time stamp is
	it's not current - while it is updated, that update is not replicated very
	often. By default, it's "within 2 weeks" ... but that cana be adjusted.
	There is an attribute that is current, but it's not replicated and you
	must connect to each DC to get the most recent time.

	So, anyway, this function will pull a list of computers from AD that have
	a LastLoginTimeStamp within a set period of time. You can specify that set
	period via the -WithinDays switch, or, if you don't, the function will try
	to get the msDS-LogonTimeSyncInterval, and use that. Following that, it does
	a quick WMI (cough CIM cough) ping to see if the system is actually online.

	The final list, then, is based on age in AD plus a ping response... with the
	expectation that the list is pretty current.

	.PARAMETER Domain
	The Domain to query - expects an FQDN

	.PARAMETER WithinDays
	How many days since AD "saw" this machine (defaults to the Domain's msDS-LogonTimeSyncInterval)

	.PARAMETER Credential
	A cred to access the appropriate domain

	.EXAMPLE
	Get-adLiveComputer

	Pulls the current domain for all "live" computers

	.EXAMPLE
	Get-adLiveComputer -Domain abc.com -Credential (Get-Credential)

	Pulls abc.com for all "live" computers, using a prompted cred

	.EXAMPLE
	Get-adLiveComputer -WithinDays 30

	Pulls the current domain for all live computers, with a LastLogonTimeStamp within 30 days (assuming ping works, of course)
	#>
	[CmdLetBinding()]
	param (
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adADDomain -Filter "$WordToComplete").Name
				} else {
					(Get-adADDomain).Name
				}
			})]
		[string] $Domain = (Get-adADDomain)[0].Name,
		[int] $WithinDays,
		[pscredential] $Credential
	)

	try {
		Import-Module -Name ActiveDirectory -ErrorAction Stop -Verbose:$false
	} catch {
		Write-Status -Message 'This function requires the ActiveDirectory PowerShell module' -level 0 -Type 'Info'
		Write-Status -Message '... which was not found' -level 1 -Type 'Error' -e $_
		Throw 'ActiveDirectory module not found.'
	}

	[bool] $Verbose = $false
	if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
		$Verbose = $true
	}

	if (Test-IsVerbose) {
		Write-Status -Message "Looking for DCs for $Domain" -Level 0 -Type 'Info'
	}

	try {
		$Servers = Resolve-DnsName "_ldap._tcp.dc._msdcs.$Domain" -Type SRV -Verbose:$false -ErrorAction Stop | Where-Object { $_.QueryType -eq 'A' } |
			Sort-Object Name -Unique

		if (Test-IsVerbose) {
			Write-Status -Message "Found $($Servers.Count) DCs" -Level 1 -Type 'Good'
		}
	} catch {
		Write-Status "Error finding DCs for $Domain" -Level 1 -e $_ -Type Error
		Throw "Could not find DCs for $Domain"
	}

	[string] $Server = (Get-adQuickPing -Name ($Servers.Name) | Where-Object { $_.Online } | Sort-Object ResponseTime | Select-Object -First 1).Address
	if (Test-IsVerbose) {
		Write-Status -Message "`"Closest`" is $Server" -Level 1 -Type 'Good'
	}

	if (($null -eq $WithinDays) -or ($WithinDays -eq 0)) {
		$AgeSplat = @{
			Server  = $Server
			Verbose = $Verbose
		}
		if ($null -ne $Credential) {
			$AgeSplat.Credential = $Credential
		}

		$WithinDays = Get-adDomainReplicationAge @AgeSplat
	}

	$Field = @{
		Name = 'LastLogon'
		expr = { ([datetime]::FromFileTime($_.lastLogonTimeStamp)) }
	}
	$DNSHostName = @{
		Name = 'DNSHostName'
		expr = { ($_.DNSHostName).ToLower() }
	}
	$Time = (Get-Date).AddDays( - ($WithinDays))
	$Filter = { (Enabled -eq 'true') -and (LastLogonTimestamp -gt $time) -and (servicePrincipalName -NotLike "MSServerCluster/*") -and (OperatingSystem -Like "Windows*") }
	$WhereWindows = { $_.OperatingSystem -match 'Windows' }
	$WherePing = {
		$Response = Get-adQuickPing -Name ($_.DNSHostName) -Verbose:$Verbose
		if (($Response.Online) -and ($Response.DNSName -match $Response.Address )) {
			$true
		} else {
			$false
		}
	}

	$Splat = @{
		Filter     = $Filter
		Properties = 'Name', 'OperatingSystem', 'LastLogonTimeStamp', 'Enabled', 'DNSHostName'
		Server     = $Server
	}

	if ($null -ne $Credential) {
		$Splat.Credential = $Credential
	}

	if (Test-IsVerbose) {
		Write-Status -Message "Pulling clients from $Domain" -Level 0 -Type 'Info'
	}

	(Get-ADComputer @Splat).Where($WherePing) |
		Select-Object Name, OperatingSystem, $Field, $DNSHostName | Sort-Object Name
}

function Get-adDomainReplicationAge {
	<#
	.SYNOPSIS
	Gets the value of the msDS-LogonTimeSyncInterval for the domain

	.DESCRIPTION
	Pulls the value of the msDS-LogonTimeSyncInterval that governs how often the
	LastLogonTimeStamp is replicated between Domain Controllers

	.PARAMETER Server
	A DC or the Domain to query

	.PARAMETER Credential
	A credential to use if the current one won't work

	.EXAMPLE
	Get-adDomainReplicationAge

	Gets the msDS-LogonTimeSyncInterval for the current domain

	.EXAMPLE
	Get-adDomainReplicationAge -Server abc.com -Credential (Get-Credential)

	Gets the msDS-LogonTimeSyncInterval for the abc.com domain using the supplied cred

	.NOTES
	General notes
	#>
	[CmdLetBinding()]
	param (
		[Alias('Domain', 'DomainController')]
		[string] $Server = (Get-adADDomain)[0].Name,
		[pscredential] $Credential
	)
	if (Test-IsVerbose) {
		Write-Status -Message "Checking LogonTimeSyncInterval for $Server" -Level 0 -Type 'Info'
	}
	$Splat = @{
		Server      = $Server
		ErrorAction = 'Stop'
	}
	if ($null -ne $Credential) {
		$Splat.Credential = $Credential
	}
	Try {
		$ADDomainInfo = Get-ADDomain @Splat
		if (Test-IsVerbose) {
			Write-Status -Message "Connected to $($ADDomainInfo.DistinguishedName)" -Level 1 -Type 'Info'
		}

		$ADDomainDistinguishedName = $ADDomainInfo.DistinguishedName

		$DirectoryServicesNamingContext = Get-ADObject -Identity "$ADDomainDistinguishedName" -Properties * @Splat

		$ReplicationValue = $DirectoryServicesNamingContext."msDS-LogonTimeSyncInterval"
		if (Test-IsVerbose) {
			Write-Status -Message "Replication Value =", "$([int] $ReplicationValue)", $(if (([int] $ReplicationValue) -eq 0) { "`(Note: 0 = 14 days`)" }) -Type 'Info', 'Good', 'Info' -Level 2
		}

		if (([int] $ReplicationValue) -ge 1) {
			$ReplicationValue + 1
		} else {
			15
		}
	} Catch {
		if (Test-IsVerbose) {
			Write-Status -Message "Error pulling the info" -e $_ -level 1 -Type 'Error'
		}
		30
	}
}

function Get-adQuickPing {
	<#
	.SYNOPSIS
	A simple CIM ping wrapper

	.DESCRIPTION
	Just a simple function to wrap the win32_Ping class

	.PARAMETER Name
	The name or IP to pin

	.PARAMETER TimeOutMS
	How long to wait for a response

	.EXAMPLE
	Get-adQuickPing -Name vm.abc.com

	.EXAMPLE
	'vm1.abc.com', 'vm2.abc.com' | Get-adQuickPing
	#>
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('Computer', 'ComputerName', 'System', 'VM', 'Workstation', 'DNSName', 'DNSHostName')]
		[string[]] $Name,
		[int] $TimeOutMS = 500
	)

	BEGIN {
		$StatusCode_ReturnValue = @{
			0     = 'Success'
			11001 = 'Buffer Too Small'
			11002 = 'Destination Net Unreachable'
			11003 = 'Destination Host Unreachable'
			11004 = 'Destination Protocol Unreachable'
			11005 = 'Destination Port Unreachable'
			11006 = 'No Resources'
			11007 = 'Bad Option'
			11008 = 'Hardware Error'
			11009 = 'Packet Too Big'
			11010 = 'Request Timed Out'
			11011 = 'Bad Request'
			11012 = 'Bad Route'
			11013 = 'TimeToLive Expired Transit'
			11014 = 'TimeToLive Expired Reassembly'
			11015 = 'Parameter Problem'
			11016 = 'Source Quench'
			11017 = 'Option Too Big'
			11018 = 'Bad Destination'
			11032 = 'Negotiating IPSEC'
			11050 = 'General Failure'
		}

		$statusFriendlyText = @{
			Name       = 'Status'
			Expression = {
				if ($null -ne $_.StatusCode) {
					$StatusCode_ReturnValue[([int] $_.StatusCode)]
				} else {
					'Null - Name not found'
				}
			}
		}

		$IsOnline = @{
			Name       = 'Online'
			Expression = { $_.StatusCode -eq 0 }
		}

		$DNSName = @{
			Name       = 'DNSName'
			Expression = { if ($_.StatusCode -eq 0) {
					if ($_.Address -like '*.*.*.*') {
						[Net.DNS]::GetHostByAddress($_.Address).HostName
					} else {
						[Net.DNS]::GetHostByName($_.Address).HostName
					}
				}
			}
		}
	}

	PROCESS {
		$Name | ForEach-Object {

			[string] $PingAble = $_
			if ($PingAble -match '\n') {
				$PingAble = $PingAble -replace "\n.+" , ''
			}

			$Response = Try {
				$PingResponse = Get-CIMInstance -Class Win32_PingStatus -Filter "Address='$($PingAble.ToLower())' and Timeout=$($TimeOutMS)" -ErrorAction Stop -Verbose:$false |
					Select-Object -Property Address, $IsOnline, $DNSName, $statusFriendlyText, ResponseTime
					$PingResponse.PSTypeNames.Insert(0, 'brshAD.QuickPing')
					$PingResponse

				} catch {
					[PSCustomObject] @{
						PSTypeName   = 'brshAD.QuickPing'
						Address      = $PingAble
						Online       = $false
						DNSName      = $PingAble
						Status       = $_.Exception.Message
						ResponseTime = 99999
					} # | Select-Object -Property Address, Online, DNSName, Status, ResponseTime
				}
				if (Test-IsVerbose) {
					Write-Status -Message "$($Response.Address):", $(if ($Response.Online) { "Online -- $($Response.ResponseTime)ms" } else { 'Offline' }) -Level 3 -Type Info, $(if ($Response.Online) { 'Good' } else { 'Warning' })
				}
				$Response
			}
		}

		END { }
	}
