function Get-adUnsignedLDAPBind {
	<#
	.SYNOPSIS
	Parses the DirectoryServices EventLog for IPs using unsigned LDAP binds

	.DESCRIPTION
	You have to enable extra logging for the Directory Service, or you'll only see
	summary events (id 2887). BUT, once enabled, the actual account and source IP
	will be logged and this function will parse out that information.

	Technically, this function parses the IP and account, then groups and counts
	that information... but still.

	# Enable Simple LDAP Bind Logging
	Reg Add HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics /v "16 LDAP Interface Events" /t REG_DWORD /d 2

	# Disable Simple LDAP Bind Logging.
	Reg Add HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics /v "16 LDAP Interface Events" /t REG_DWORD /d 0

	.EXAMPLE
	Get-adUnsignedLDAPBind

	.LINK
	https://support.microsoft.com/en-us/help/4520412/2020-ldap-channel-binding-and-ldap-signing-requirement-for-windows
	https://blogs.technet.microsoft.com/russellt/2016/01/13/identifying-clear-text-ldap-binds-to-your-dcs/
	#>

	Get-WinEvent -FilterHashtable @{ID = 2889; LogName = 'Directory Service' } | Select-Object -ExpandProperty Message |
	ForEach-Object {
		$hold = ($_ | select-string -Pattern '(\w*\\.*|\d{1,3}(\.\d{1,3}){3})' -AllMatches).Matches
		New-Object -TypeName PSObject -Property @{ User = $Hold[1].Value.ToString().Trim(); IP = $Hold[0].Value }
	} | Group-Object IP, User |
	Select-Object @{Label = 'IP'; expression = { (($_.Name -split ',')[0]).Trim() } }, @{Label = 'User'; expression = { (($_.Name -split ',')[1]).Trim() } }, Count
}

function Get-adLDAPsBindInfo {
	<#
	.SYNOPSIS
	Parses the Security EventLog for WinFilter events to find LDAPS connections

	.DESCRIPTION
	I wish this was as easy as unsigned (although, technically, unsigned reqs
	a reg hack to get the deets ... and then it's too much deets...). BUT, this
	will parse the Security log for IP Filtering notices on ports 636 and 3269,
	returning the source IP and a count.

	By default, this function will filter out the DCs from the current user's domain.
	You can include them via the -IncludeDCs switch.

	Depending how many records... this can be very slow. At least, the filter happens
	in the get, as opposed to getting it all and where-object'ing it down....

	.PARAMETER IncludeDCs
	Will include the DCs from the current domain in the output

	.EXAMPLE
	Get-adLDAPsBindInfo
	#>
	param (
		$IncludeDCs = $false
	)

	Write-Host 'This can be slow. Lots of data to sift thru...' -ForegroundColor Yellow

	$xml = @'
<QueryList>
	<Query Id="0" Path="Security">
		<Select Path="Security">*[System[(EventID=5156)]] and
			(*[EventData
				[
					Data[@Name='Protocol']='6' and
					Data[@Name='SourcePort']='636']
				] or
			*[EventData
				[
					Data[@Name='Protocol']='6' and
					Data[@Name='SourcePort']='3269']
				])
		</Select>
	</Query>
</QueryList>
'@

	if ($IncludeDCs) {
		$ExcludeIPs = $null
	} else {
		$ExcludeIPs = ([system.net.dns]::GetHostByName($env:USERDNSDOMAIN)).AddressList | ForEach-Object { $_.ToString() }
	}

	Get-WinEvent -FilterXML $xml | Select-Object -ExpandProperty Message |
	ForEach-Object {
		$hold = ($_ | select-string -pattern 'Source.*' -AllMatches).Matches
		$Address = $Hold[0].Value.ToString().Trim().Split(':')[1].Trim()
		$Port = $Hold[1].Value.ToString().Trim().Split(':')[1].Trim()
		if (-not ($ExcludeIPs -contains $Address)) {
			New-Object -TypeName PSObject -Property @{ SourceAddress = $Address; SourcePort = $Port }
		}
	} | Group-Object SourceAddress, SourcePort |
	Select-Object @{Label = 'IP'; expression = { (($_.Name -split ',')[0]).Trim() } }, @{Label = 'User'; expression = { (($_.Name -split ',')[1]).Trim() } }, Count
}
