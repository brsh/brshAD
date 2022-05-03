function Get-adLogonEvents {
	<#
	.SYNOPSIS
	Filter the Domain's Security log for unsuccessful Logons

	.DESCRIPTION
	This function will parse thru the Security event log on the PDCEmulator within an AD domain
	(the PDCE gets replicated logon/logoff events from all DCs). This lets you quickly find users
	who've "mis-typed" their passwords or locked out their account (or both!).

	It will try to find the PDCE automatically by default, but you can set the source to any box
	but it won't return anything if that box isn't auditing those events.

	You can also use the IncludeSuccess and IncludeLogoff switches to see even more data! If you
	really want ... trust me - DCs get hammered with this stuff.

	The default time frame for the query is the past 20 minutes. You can adjust that via the Minutes,
	Hours, and Days switches (they are mutually exclusive). Of course, the log has to have data
	that stretches that far back.

	The goal was to have a quick way to _try_ to see where bad password events are coming from -
	cuz sometimes, Users have an orphaned session somewhere.... Of course, the source isn't always
	captured in the event - so ... hit or miss (mostly hit).

	It also pulls all the known (by me and my internet searches) explanations for login failures.
	I mean, it's pulling the data, might as well go all in.

	.PARAMETER UserName
	Filter the search on a specific user name. This is not a fuzzy or regex search - must be exact

	.PARAMETER Minutes
	How many minutes back to search (default is 20)

	.PARAMETER Hours
	How many hours back to search

	.PARAMETER Days
	How many days back to search

	.PARAMETER IncludeSuccess
	Include Successful events

	.PARAMETER IncludeLogoff
	Include Logoff events

	.PARAMETER PDCEmulator
	Specify a different server to query - default is the PDCE for the domain

	.EXAMPLE
	Get-adLogonEvents

	Returns the last 20 minutes of logon failures and account lockout events

	.EXAMPLE
	Get-adLogonEvents -Username gfleegman

	Returns the last 20 minutes of logon failures for Guy Fleegman

	.EXAMPLE
	Get-adLogonEvents -Username gfleegman -IncludeSuccess

	Returns the last 20 minutes of all logon events for Guy Fleegman

	.EXAMPLE
	Get-adLogonEvents -IncludeSuccess -Hours 4

	Returns the last 4 hours of all logon events - this includes Computer account logons

	.EXAMPLE
	Get-adLogonEvents -IncludeSuccess -Hours 4 | Where-Object UserName -notmatch "\$"

	Returns the last 4 hours of all logon events - this excludes Computer account logons
	#>
	[CmdletBinding(DefaultParameterSetName = 'Minutes')]
	param (
		[Parameter(Mandatory = $false)]
		[string] $UserName = '',
		[Parameter(Mandatory = $false, ParameterSetName = 'Minutes')]
		[int] $Minutes = 20,
		[Parameter(Mandatory = $true, ParameterSetName = 'Hours')]
		[int] $Hours,
		[Parameter(Mandatory = $true, ParameterSetName = 'Days')]
		[int] $Days,
		[switch] $IncludeSuccess = $false,
		[switch] $IncludeLogoff = $false,
		[Parameter(Mandatory = $false)]
		[string] $PDCEmulator = ((Get-adFSMORoleOwner).PDCEmulator.Name)
	)
	if (-not (Test-IsAdmin)) {
		Write-Status -Message 'You must run this as Admin to query the security log' -Level 0 -Type 'Error'
		Throw 'PowerShell is not running as Admin'
	}

	if ($PSCmdlet.ParameterSetName -eq "Minutes") {
		$TheDate = (get-date (get-date).AddMinutes(-$Minutes).ToUniversalTime() -UFormat '%Y-%m-%dT%H:%M:%S.000Z')
	} elseif ($PSCmdlet.ParameterSetName -eq "Hours") {
		$TheDate = (get-date (get-date).AddHours(-$Hours).ToUniversalTime() -UFormat '%Y-%m-%dT%H:%M:%S.000Z')
		#$Milliseconds = (New-TimeSpan -Hours $Hours).TotalMilliseconds
	} else {
		$TheDate = (get-date (get-date).AddDays(-$Days).ToUniversalTime() -UFormat '%Y-%m-%dT%H:%M:%S.000Z')
	}
	[string] $FilterSet = 'Logon Failures'

	[string] $Events = "EventID=4625 or EventID=4740"
	if ($IncludeSuccess) {
		$Events = "$Events or EventID=4624 or EventID=4648"
		$FilterSet = "${FilterSet} & Successes"
	}
	if ($IncludeLogoff) {
		$Events = "$Events or EventID=4634 or EventID=4647"
		$FilterSet = "${FilterSet}, Logoffs"
	}


	$FilterPath = @"
*[
System[($Events)
and TimeCreated[@SystemTime >= '$TheDate']]
$(if ($UserName.Trim().Length -gt 0) { "and EventData[Data[@Name='TargetUserName']='$UserName']" })
]
"@

	[long] $LogCount = (Get-WinEvent -ListLog 'Security' -ComputerName $PDCEmulator -ErrorAction SilentlyContinue).RecordCount
	if ($LogCount -eq 0) { $LogCount = 100 }
	$EarliestRecord = (Get-WinEvent -ComputerName $PDCEmulator -LogName 'Security' -Oldest -MaxEvents 1 -ErrorAction SilentlyContinue).TimeCreated
	if ($null -eq $EarliestRecord) { $EarliestRecord = Get-Date }
	Write-Status -Message 'Security EventLog Statistics' -Level 0 -Type 'Info'
	Write-Status -Message 'Total Entries:', ("{0:#,#}" -f $LogCount) -Level 1 -Type 'Info', 'Warning'
	Write-Status -Message 'Oldest Event :', $($EarliestRecord.ToString('yyyy-MMM-dd  hh:mm:sstt')) -Level 1 -Type 'Info', 'Warning'
	Write-Status -Message 'Showing      :', $FilterSet -Type Info, Warning -Level 1

	try {
		Get-WinEvent -FilterXPath $filterPath -LogName Security -ErrorAction Stop -ComputerName $PDCEmulator | ForEach-Object {
			$Event = $_
			[string[]] $Type = switch ($Event.ID) {
				'4624' { 'Logon', 'Success' }
				'4625' { 'Logon', 'Failure' }
				'4634' { 'Logoff', 'Complete' }
				'4647' { 'Logoff', 'Initiated' }
				'4648' { 'Logon', 'AlternateCreds' }
				'4740' { 'Lockout', 'Locked' }
				'4779' { 'Disconnect', 'n/a' }
			}
			$b = [xml] $Event.ToXML()
			[string] $newUserName = ($b.Event.EventData.Data | where Name -eq 'TargetUserName' ).'#text'
			[string] $LogonType = ($b.Event.EventData.Data | where Name -eq 'LogonType' ).'#text'
			[string] $Domain = if ($Event.ID -eq '4740') {
				''
			} else {
				($b.Event.EventData.Data | where Name -eq 'TargetDomainName' ).'#text'
			}
			[string] $WorkstationName = if ($Event.ID -eq '4740') {
				($b.Event.EventData.Data | where Name -eq 'TargetDomainName' ).'#text'
			} else {
				($b.Event.EventData.Data | where Name -eq 'WorkstationName' ).'#text'
			}
			[string] $IpAddress = ($b.Event.EventData.Data | where Name -eq 'IpAddress' ).'#text'
			[string] $StatusCode = ($b.Event.EventData.Data | where Name -eq 'Status' ).'#text'
			[string] $SubStatusCode = ($b.Event.EventData.Data | where Name -eq 'SubStatus' ).'#text'
			[string] $AuthPackage = ($b.Event.EventData.Data | Where-Object Name -eq 'AuthenticationPackageName').'#text'


			[string] $LogonTypeText = switch ($LogonType) {
				'2' { 'Interactive' }
				'3' { 'Network' }
				'4' { 'Batch' }
				'5' { 'Service' }
				'7' { 'UI_Unlock' }
				'8' { 'NetworkCleartext' }
				'9' { 'NewCredentials' }
				'10' { 'RemoteInteractive' }
				'11' { 'CachedInteractive' }
				DEFAULT { $LogonType }
			}

			[string] $SourceWorkstation = if (($WorkstationName.Trim().Length -eq 0) -or ($WorkstationName.Trim() -eq '-')) {
				if ($IpAddress.Trim().Length -gt 0) {
					try {
						[string] $fqdn = (Resolve-DnsName -type ptr -name $IpAddress -DnsOnly -ErrorAction Stop).NameHost
						$fqdn.Substring(0, $fqdn.Indexof('.'))
					} catch {
						$IpAddress.Trim()
					}
				} else { '' }
			} else { $WorkstationName }

			[string] $SubStatusCodeMod = if ($StatusCode -eq '0xc0000234') { $StatusCode } else { $SubStatusCode }
			[string] $FailureReason = if ($SubStatusCodeMod.Trim().Length -gt 0) {
			(Get-adLogonFailureCodes -Code $SubStatusCodeMod).Text
			} else { '' }
			if ($FailureReason.Trim().Length -eq 0) { $FailureReason = $SubStatusCodeMod }

			[pscustomobject] @{
				PSTypeName    = 'brshAD.LogonEvents'
				TimeCreated   = $Event.TimeCreated
				UserName      = $newUserName
				EventID       = $Event.ID
				Type          = $Type[0]
				Outcome       = $Type[1]
				Logontype     = $LogonTypeText
				AuthPackage   = $AuthPackage
				Domain        = $Domain
				Workstation   = $SourceWorkstation
				IP            = $IpAddress
				Status        = $StatusCode
				SubStatus     = $SubStatusCode
				FailureReason = $FailureReason
				ProviderName  = $Event.ProviderName
				EventOpcode   = $Event.LevelDisplayName
				LogName       = $Event.LogName
				Keywords      = $Event.KeywordsDisplayNames
				Message       = $Event.Message
			}
		}

	} catch {
		Write-Status -Message 'Error getting event logs' -Level 0 -Type 'Error' -e $_
	}
}

function Get-adLogonFailureCodes {
	<#
	.SYNOPSIS
	Just a handy Logon Event Code Error parser

	.DESCRIPTION
	Lists all the known (by me) codes why a logon might fail.

	You can filter on the Code (or part thereof) or the Text (or part thereof).

	.PARAMETER Code
	The 0x code for the error

	.PARAMETER Text
	Search/filter on the STATUS text for the error

	.EXAMPLE
	Get-adLogonFailureCode

	Returns all codes

	.EXAMPLE
	Get-adLogonFailureCode -Code 0xc0000022

	Returns the Status_Error_Denied code

	.EXAMPLE
	Get-adLogonFailureCode -Text 'Denied'

	Returns all the codes with Denied in the text

	#>
	[CmdletBinding(DefaultParameterSetName = 'Code')]
	param (
		[Parameter(Mandatory = $false, ParameterSetName = 'Code', Position = 0)]
		[string] $Code,
		[Parameter(Mandatory = $false, ParameterSetName = 'Text')]
		[string] $Text
	)

	$SubStatuses = @(
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC0000022'
			Text        = 'STATUS_ACCESS_DENIED'
			Explanation = 'Access to the system is denied.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000005E'
			Text        = 'STATUS_NO_LOGON_SERVERS'
			Explanation = 'There are currently no logon servers available to service the logon request.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000064'
			Text        = 'STATUS_NO_SUCH_USER'
			Explanation = 'User logon with misspelled or bad user account (or the auth DB was unavailable while the request was in process - think reboot of a DC)'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000006A'
			Text        = 'STATUS_WRONG_PASSWORD'
			Explanation = 'This return status indicates that the value provided as the current password is not correct. That said, it _could_ also be related to not being allowed to logon (maybe not admin or not in the RDP group)'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000006C'
			Text        = 'STATUS_PASSWORD_RESTRICTION'
			Explanation = 'User is attempting to reset password and it does not meet requirements specified by policy (length, history, complexity)'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000006D'
			Text        = 'STATUS_LOGON_FAILURE'
			Explanation = 'This is either due to a bad username or authentication information'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000006E'
			Text        = 'STATUS_ACCOUNT_RESTRICTION'
			Explanation = 'Indicates a referenced user name and authentication information are valid, but some user account restriction has prevented successful authentication (such as time-of-day restrictions).'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000006F'
			Text        = 'STATUS_INVALID_LOGON_HOURS'
			Explanation = 'The user account has time restrictions and cannot be logged onto at this time.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000070'
			Text        = 'STATUS_INVALID_WORKSTATION'
			Explanation = 'The user account is restricted so that it cannot be used to log on from the source workstation.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000071'
			Text        = 'STATUS_PASSWORD_EXPIRED'
			Explanation = 'The user account password has expired.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000072'
			Text        = 'STATUS_ACCOUNT_DISABLED'
			Explanation = 'The referenced account is currently disabled and cannot be logged on to.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC000009A'
			Text        = 'STATUS_INSUFFICIENT_RESOURCES'
			Explanation = 'Resource issues on the system are preventing Netlogon from connecting or operating properly'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC00000DC'
			Text        = 'STATUS_INVALID_SERVER_STATE'
			Explanation = 'Indicates the SAM Server was in the wrong state to perform the desired operation.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC00000DF'
			Text        = 'STATUS_NO_SUCH_DOMAIN'
			Explanation = 'The specified domain did not exist.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000133'
			Text        = 'STATUS_TIME_DIFFERENCE_AT_DC'
			Explanation = 'The time at the primary domain controller is different from the time at the backup domain controller or member server by too large an amount.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC000015B'
			Text        = 'STATUS_LOGON_TYPE_NOT_GRANTED'
			Explanation = 'A user has requested a type of logon (for example, interactive or network) that has not been granted. An administrator has control over who can logon interactively and through the network.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC000018A'
			Text        = 'STATUS_NO_TRUST_LSA_SECRET'
			Explanation = 'Your connection to the domain is broken from this machine. You can try nltest /sc_query:{Domain} to query and/or nltest /sc_reset:{Domain} to try a quick fix'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC000018B'
			Text        = 'STATUS_NO_TRUST_SAM_ACCOUNT'
			Explanation = 'On applicable Windows Server releases, the SAM database does not have a computer account for this workstation trust relationship.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC000018C'
			Text        = 'STATUS_TRUSTED_DOMAIN_FAILURE'
			Explanation = 'The logon request failed because the trust relationship between the primary domain and the trusted domain failed. You can try nltest /sc_query:{Domain} to query and/or nltest /sc_reset:{Domain} to try a quick fix'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC000018D'
			Text        = 'STATUS_TRUSTED_RELATIONSHIP_FAILURE'
			Explanation = 'The logon request failed because the trust relationship between this workstation and the primary domain failed. You can try nltest /sc_query:{Domain} to query and/or nltest /sc_reset:{Domain} to try a quick fix'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000190'
			Text        = 'STATUS_TRUST_FAILURE'
			Explanation = 'The network logon failed. This might be because the validation authority cannot be reached.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC0000192'
			Text        = 'STATUS_NETLOGON_NOT_STARTED'
			Explanation = 'An attempt was made to logon, but the netlogon service was not started.'
		}
		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC0000193'
			Text        = 'STATUS_ACCOUNT_EXPIRED'
			Explanation = 'The user account has expired.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC0000224'
			Text        = 'STATUS_PASSWORD_MUST_CHANGE'
			Explanation = 'The user password must be changed before logging on the first time.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000233'
			Text        = 'STATUS_DOMAIN_CONTROLLER_NOT_FOUND'
			Explanation = 'A domain controller for this domain was not found.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0000234'
			Text        = 'STATUS_ACCOUNT_LOCKED_OUT'
			Explanation = 'The user account has been automatically locked because too many invalid logon attempts or password change attempts have been requested. Note: this shows as a main Status - not a SubStatus code'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0XC0000413'
			Text        = 'STATUS_AUTHENTICATION_FIREWALL_FAILED'
			Explanation = 'Logon Failure: The machine you are logging onto is protected by an authentication firewall. The specified account is not allowed to authenticate to the machine.'
		}

		[PSCustomObject] @{
			PSTypeName  = 'brshAD.LogonFailureCode'
			Code        = '0xC0020050'
			Text        = 'RPC_NT_CALL_CANCELLED'
			Explanation = 'RPC communication issues'
		}

	)

	if ($Code.Trim().Length -gt 0) {
		$SubStatuses | Where-Object { $_.Code -match $Code }
	} elseif ($Text.Trim().Length -gt 0) {
		$SubStatuses | Where-Object { $_.Text -match $Text }
	} else {
		$SubStatuses
	}

}
