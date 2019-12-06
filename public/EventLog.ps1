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
