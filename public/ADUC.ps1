
function Start-adADUC {
	<#
	.SYNOPSIS
	Start ADUC for non-trusted domains

	.DESCRIPTION
	Running a local instance of AD Users and Computers against a non-trusted domain can be...
	difficult. But it doesn't have to be. This script just automates starting ADUC with the
	correct switches and auth to connect to an un-trusted domain. Assuming, of course, that
	you have network connectivity and the appropriate access.

	The script attempts a DNS lookup to get the "closest" Domain Controller (based on site
	configuration, assuming site configuration is ... configured).

	Basically, it just runs a cmd window with a runas command, using the DC IP, the user
	account, and the approps switches. The cmd window closes after asking for the password.

	Note: Automatic suggestions/tab completion for the Domain list can be accomplished by
	adding domains (1 per line) to the config/ADDomains.txt file. The first domain in the
	list will be the default for this function; otherwise, it uses the users Domain (which
	is basically the same as using ADUC natively).

	.PARAMETER Domain
	The Domain against which to run ADUC

	.PARAMETER UserName
	The username to use to connect to the domain (I provide a sample to translate based on 1 type of possible naming scheme)

	.EXAMPLE
	Start-adADUC

	Starts ADUC against the default domain

	.EXAMPLE
	Start-adADUC -domain other.com

	Starts ADUC against the other.com domain

	.EXAMPLE
	Start-adADUC -domain other.com -user mewho

	Starts ADUC against the other.com domain, with the other\mewho user account

	.NOTES
	General notes
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
		[string] $Domain = $script:ADDomainList[0],
		[string] $UserName = ''
	)

	[string] $DC = try {
		[System.Net.Dns]::GetHostByName($Domain).AddressList[0].IPAddressToString
	} catch {
		$Domain
	}
	if (($null -eq $DC) -or ($DC.Trim().Length -eq 0)) { $DC = $Domain }

	if ($UserName.Trim().Length -eq 0) {
		$un = $env:USERNAME.Split('.')
		$UserName = "$($Domain.Split('.')[0])\$($un[0].Substring(0,1))$($un[1])".ToLower()
	}

	Write-Status -Message "Trying to start ADUC against:" -Type 'Info' -level 0
	Write-Status -Message "Domain:", $Domain -Type 'Info', 'Good' -level 1
	Write-Status -Message "DC    :", $DC -Type 'Info', 'Good' -level 1
	Write-Status -Message "As    :", $UserName -Type 'Info', 'Good' -level 1
	Write-Status -Message "Please keep an eye out for the CMD window with the password prompt" -Type 'Warning' -level 0
	Write-Status -Message "This _can_ take a while to start..." -Type 'Good' -level 0

	$hash = @{
		FilePath         = 'C:\windows\system32\cmd.exe'
		Verb             = 'runas'
		WorkingDirectory = $PSHOME
		ArgumentList     = "/c runas /netonly /user:$UserName `"mmc.exe dsa.msc /server=$DC`""
	}

	start-process @hash
}

function Get-adADDomain {
	param (
		[string] $Filter = ''
	)

	if (test-path $script:ScriptPath\config\ADDomains.txt) {
		$all = @(Get-Content $ScriptPath\config\ADDomains.txt | Where-Object { $_ -notmatch "^#" })
	} else {
		$all = @($env:USERDNSDOMAIN)
	}
	$all | ForEach-Object {
		$ADDomain = [ordered] @{
			Name = $_
		}
		$retval = [PSCustomObject] $ADDomain
		if ($Filter.Length -gt 0) {
			if ($ADDomain.Name -match "$Filter") { $retval }
		} else {
			$retval
		}
	}
}
