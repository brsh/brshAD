function Get-adSecurityAuditUserInfo {
	<#
	.SYNOPSIS
	Pulls all users from AD and highlights if they are in a designated Admin group

	.DESCRIPTION
	This is an auditing function intended to list users and whether they are in a
	designated Admin group.

	By "designated Admin group", I, of course, mean you can specify what groups are
	considered to be admin groups.

	For example, Domain Admins are a mandatory admin group for all computers within
	an AD Domain. But, you might have other groups which designate Admins on a smaller
	subset of systems - maybe your DBAs are admins on DB servers, and their group is
	"DBA Admins" (I used the generic "Server Admin" in the parameter default).

	So, you can specify an array of groups that this function will then consider to
	be an Admin Group, and it will flag the users appropriately.

	The default display will just show the user and highlight if they are an admin
	and if their account is enabled. More info, like group membership, is available.

	This function can also be used with the Get-adLocalAdministrators function. You
	use that function to get the groups, and this function to compare membership.

	.PARAMETER Domain
	The AD Domain to query. Defaults to the current user's domain. Other domains might require different credentials

	.PARAMETER Credential
	A credential that has the power to pull such data

	.PARAMETER AdminGroups
	An array of groups to consider as Admin Groups

	.EXAMPLE
	Get-adSecurityAuditUserInfo

	Returns a table of users considered to be admins on servers within the domain

	.EXAMPLE
	Get-adSecurityAuditUserInfo | ConvertTo-CSV -NoTypeInformation | Out-File .\Admins.csv

	Returns a table of users considered to be admins on servers within the domain, and saves the info as a csv

	.EXAMPLE
	Get-adSecurityAuditUserInfo -Domain OtherDomain.com -Credential (Get-Credential)

	Returns a table of users considered to be admins on servers within the OtherDomain.com domain

	#>
	param (
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adADDomain -Filter "$WordToComplete").Name
				} else {
					(Get-adADDomain).Name
				}
			})]
		[string] $Domain = $env:USERDNSDOMAIN,
		[pscredential] $Credential,
		[string[]] $AdminGroups = @("$env:USERDOMAIN\Domain Admins", "$env:USERDOMAIN\Server Admin")
	)

	$UserSplat = @{
		filter      = '*'
		Properties  = 'MemberOf', 'UIDNumber', 'Description'
		ErrorAction = 'SilentlyContinue'
	}
	$GroupSplat = @{
		ErrorAction = 'SilentlyContinue'
	}
	if ($null -ne $Credential) {
		$UserSplat.Credential = $Credential
		$UserSplat.Server = $Domain
		$GroupSplat.Credential = $Credential
		$GroupSplat.Server = $Domain
	}

	Get-adUser @UserSplat | ForEach-Object {
		[PSCustomObject] @{
			PSTypeName     = 'brshAD.SECUserInfo'
			Name           = $_.Name
			UserName       = $_.samAccountName
			LinuxUser      = [bool] ($_.uidNumber)
			AccountEnabled = [bool] ($_.Enabled)
			Groups         = @($_.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_ @GroupSplat).Name }) -join ', '
			Domain         = (($_.DistinguishedName | Select-String -Pattern 'DC=\w+,').Matches[0].Value -replace '(DC=|,)', '').ToUpper()
			IsInAdminGroup = [bool] (($_.MemberOf | ForEach-Object {
						$Group = $_
						foreach ($AG in $AdminGroups) {
							if ($Group -match ($AG -replace "^\w+\\", '')) {
								$true; break
							}
						}
					}) | Sort-Object -Descending | Select-Object -First 1)
			Description    = $_.Description
		}
	}
}

function Get-adLocalAdministrators {
	<#
	.SYNOPSIS
	Pulls users and groups from the specified servers' local Admin group

	.DESCRIPTION
	This is an auditing function intended to inventory various servers and list users
	and groups that are in the local Administrators group.

	This function can also be used with the Get-adSecurityAuditUserInfo function. You
	use this function to get the groups, and that function to compare membership.

	.PARAMETER Name
	The name of the computer(s) to query

	.PARAMETER Credential
	A credential that has access rights to the computer(s) (if needed)

	.PARAMETER Group
	Group and sort the results by the "member" name

	.EXAMPLE
	Get-adLocalAdministrators -Name 'Server1', 'Server2'

	Pulls the members of the local admins group on Server1 and Server 2

	.EXAMPLE
	Get-adComputer -filter * | Get-adLocalAdministrators

	Gets a list of all computers from AD and sends them down the pipeline

	.EXAMPLE
	Get-adLocalAdministrators -Name 'Server1', 'Server2' -Group

	Pulls the members and then sorts and groups them by name (same as adding Group-Object and Sort-Object)

	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Array of computers to query.")]
		[Alias('Computer', 'VM', 'System', 'Server', 'Workstation', 'ComputerName')]
		[string[]] $Name,
		[pscredential] $Credential,
		[switch] $Group = $false
	)

	BEGIN {
		[scriptblock] $InvokeCommandScriptBlock = {
			try {
				Get-LocalGroupMember -Group Administrators -ErrorAction Stop | Where-Object { $_.Name -notmatch "Administrator$" }
			} catch {
				New-Object -TypeName PSObject -Property @{ Name = "Error: $($_.CategoryInfo.Reason)"; PSComputerName = $PSComputerName; ObjectClass = 'Error' }
			}
		}
		$Computers = [System.Collections.ArrayList]::new()
	}

	PROCESS {
		foreach ($Computer in $Name) {
			if (($null -ne $Computer) -or ($Computer.Trim().Length -gt 0)) {
				[void] $Computers.Add($Computer)
			}
		}
	}

	END {
		$Splat = @{
			'Computer'         = $Computers.ToArray()
			'ScriptBlock'      = $InvokeCommandScriptBlock
			'SessionOption'    = (New-PSSessionOption -NoMachineProfile -OpenTimeout 4000 -OperationTimeout 30000 -MaxConnectionRetryCount 2)
			'HideComputerName' = $true
			'ErrorAction'      = 'SilentlyContinue'
		}
		if ($Credential) {
			$Splat.Add('Credential', $Credential)
		}
		if ($Group) {
			$Sort = @(
				@{ Expression = 'Count'; Descending = $true },
				@{ Expression = 'Name'; Descending = $false }
			)
			$Select = @(
				@{ Expression = 'Count' },
				@{ Expression = 'Name' },
				@{ Expression = { ($_.Group.ObjectClass -split ' ')[0] }; Name = 'ObjectClass' },
				@{ Expression = { [array] ($_.Group.PSComputerName.ToUpper()) }; Name = 'PSComputerName' }
			)
			Invoke-Command @Splat | Group-Object Name | Sort-Object $Sort | Select-Object $Select
		} else {
			Invoke-Command @Splat | ForEach-Object {
				[PSCustomObject] @{
					PSTypeName     = 'brshAD.SECGroupInfo'
					PSComputerName = $_.PSComputerName.ToUpper()
					Name           = $_.Name
					SID            = $_.SID
					ObjectClass    = $_.ObjectClass
				}
			}
		}
	}
}
