function Invoke-adDCDiag {
	<#
	.SYNOPSIS
	Colorizes the output of DCDiag

	.DESCRIPTION
	DCDiag is handy. It is not always easy to read. This function helps that
	by adding color to various things - for example, it highlights the Test
	Name at the beginning of the test and the result at the end. Very handy...

	Of course, it's a reasonably brute force method.

	.PARAMETER Verbose
	Adds the /v switch to make DCDiag more verbose

	.PARAMETER Comprehensive
	Adds the /c switch to make DCDiag run a larger collection of tests

	.PARAMETER Site
	Adds the /a switch to make DCDiag run the tests "across the Site"

	.PARAMETER Enterprise
	Adds the /e switch to make DCDiag run the tests "across the enterprise" (overrides Site aka /a)

	.PARAMETER DomainController
	Specifies a specific Domain Controller against which to run the tests

	.EXAMPLE
	Invoke-DCDiag -Verbose -Comprehensive -Enterprise

	Runs a lot of DCDiag tests against a lot of DCs

	.LINK
	https://blogs.technet.microsoft.com/askds/2011/03/22/what-does-dcdiag-actually-do/
	https://rakhesh.com/windows/active-directory-troubleshooting-with-dcdiag-part-1/
	https://rakhesh.com/windows/active-directory-troubleshooting-with-dcdiag-part-2/
	#>

	param (
		[switch] $Verbose = $false,
		[switch] $Comprehensive = $false,
		[Switch] $Site = $false,
		[switch] $Enterprise = $false,
		[string] $DomainController
	)

	[string] $DcDiag = (get-command dcdiag.exe -ErrorAction SilentlyContinue).Definition

	$sb = New-Object -TypeName System.Text.StringBuilder
	switch ($true) {
		$Verbose { [void] $sb.Append('/v ') }
		$Comprehensive { [void] $sb.Append('/c ') }
		$Site { [void] $sb.Append('/a ') }
		$Enterprise { [void] $sb.Append('/e ') }
	}

	# if ($Verbose) { [void] $sb.Append('/v ') }
	# if ($Comprehensive) { [void] $sb.Append('/c ') }
	# if ($Site) { [void] $sb.Append('/a ') }
	# if ($Enterprise) { [void] $sb.Append('/e ') }

	if ($DcDiag.Length -gt 0) {

		if ($sb.Length -gt 0) {
			$DcDiag = "$DcDiag $($sb.ToString())"
		}
		invoke-expression $DcDiag -ErrorAction Stop | ForEach-Object {
			[string] $line = $_
			switch -wildcard ($line.Trim()) {
				"Directory Server Diagnosis" { write-host $line -ForegroundColor Green -BackgroundColor Black; break }
				"Performing initial setup:" { write-host $line -ForegroundColor Green -BackgroundColor Black; break }
				"Running * tests on*" { write-host $line -ForegroundColor White -BackgroundColor Black; break }
				"Starting test:*" { write-host $line -ForegroundColor Yellow; break }
				"A warning event occurred*" { write-host "$($line.Split(".")[0]). " -ForegroundColor Yellow -NoNewline; write-host $line.Split(".")[1].Trim() -ForegroundColor White; break }
				"An error event occurred*" { write-host "$($line.Split(".")[0]). " -ForegroundColor Red -NoNewline; write-host $line.Split(".")[1].Trim() -ForegroundColor White; break }
				"There are warning or error events*" { write-host $line -ForegroundColor Yellow; break }
				"A* event occurred" { write-host $line -ForegroundColor Red; break }
				"Test:*" { write-host $line -ForegroundColor Yellow; break }
				"*passed test*" { write-host $line -ForegroundColor Green; break }
				"....*passed" { write-host $line -ForegroundColor Green; break }
				"*tests passed*" { write-host $line -ForegroundColor Green; break }
				"*failed test*" { write-host $line -ForegroundColor Red; break }
				"*Testing server:*" { write-host "$($line.Split(":")[0]): " -ForegroundColor White -BackgroundColor Black -NoNewline; write-host $line.Split(":")[1].Trim() -ForegroundColor Cyan -BackgroundColor Black }
				"Object is up-to-date on all servers." { write-host $line -ForegroundColor Green; break }
				"All expected sites and bridgeheads are replicating*" { write-host $line -ForegroundColor Green; break }
				"*is up and replicating fine." { write-host $line -ForegroundColor Green; break }
				"*service is running" { write-host ($line -Split 'service is running')[0] -ForegroundColor Yellow -NoNewline; write-host 'service is ' -NoNewline; write-host 'running' -ForegroundColor Green; break }
				"*service is stopped" { write-host ($line -Split 'service is stopped')[0] -ForegroundColor Yellow -NoNewline; write-host 'service is ' -NoNewline; write-host 'stopped' -ForegroundColor Red; break }
				"Summary of test results for DNS servers" { write-host $line -ForegroundColor Yellow; break }
				"Summary of DNS test results:" { write-host $line -ForegroundColor Yellow; break }
				"DC:*" { write-host $line -ForegroundColor Yellow; break }
				"Domain:*" { write-host $line -ForegroundColor Yellow; break }
				"*``[Valid``]*" { write-host ($line -Split '\[Valid\]')[0] -NoNewline; write-host '[Valid]' -ForegroundColor Green -NoNewline; write-host ($line -Split '\[Valid\]')[-1]; break }
				"*was found*" { write-host ($line -Split 'was found')[0] -NoNewline; write-host 'was found' -ForegroundColor Green -NoNewline; write-host ($line -Split 'was found')[-1]; break }
				"*was not found*" { write-host ($line -Split 'was not found')[0] -NoNewline; write-host 'was not found' -ForegroundColor Red -NoNewline; write-host ($line -Split 'was not found')[-1]; break }
				"*is advertising*" { write-host ($line -Split 'is advertising')[0] -NoNewline; write-host 'is advertising' -ForegroundColor Green -NoNewline; write-host ($line -Split 'is advertising')[-1]; break }
				"*is not advertising*" { write-host ($line -Split 'is not advertising')[0] -NoNewline; write-host 'is not advertising' -ForegroundColor Yellow -NoNewline; write-host ($line -Split 'is not advertising')[-1]; break }
				"*are correct*" { write-host $line -ForegroundColor Green; break }
				"*Unable to verify the convergence*" { write-host $line -ForegroundColor Yellow; break }
				"Warning:*" { write-host $line -ForegroundColor Yellow; break }
				"Error:*" { write-host $line -ForegroundColor Red; break }
				"*failed*" { write-host $line -ForegroundColor Red; break }
				"*failure*" { write-host $line -ForegroundColor Red; break }
				"*broken*" { write-host $line -ForegroundColor Red; break }
				"*can't get changes*" { write-host $line -ForegroundColor Red; break }
				"*is disconnected*" { write-host $line -ForegroundColor Red; break }
				"DNS delegation for the domain*is operational*" { write-host ($line -Split 'is operational')[0] -NoNewline; write-host 'is operational' -ForegroundColor Green -NoNewline; write-host ($line -Split 'is operational')[-1]; break }
				"Name resolution is functional*is registered*" { write-host ($line -Split 'is functional')[0] -NoNewline; write-host 'is functional' -ForegroundColor Green -NoNewline; write-host ($line -Split 'is functional')[-1]; break }
				"Name resolution is not functional*" { write-host ($line -Split 'is not functional')[0] -NoNewline; write-host 'is not functional' -ForegroundColor Red -NoNewline; write-host ($line -Split 'is not functional')[-1]; break }
				"Matching*record found at*" {
					$p = "Matching(.*?) record"
					$a = $line -Split 'found';
					$r = [regex]::Match($a, $p)
					$b = $a -Split ($r.Groups[1].Value)
					write-host $b[0] -NoNewline -ForegroundColor Green;
					write-host $r.Groups[1].Value -ForegroundColor Yellow -NoNewline;
					write-host $b[1] -NoNewline;
					write-host 'found' -ForegroundColor Green -NoNewline;
					write-host $a[-1];
					break
				}
				"*Missing*record at*" {
					$p = "Missing(.*?) record"
					$a = $line -Split 'at';
					$r = [regex]::Match($a, $p)
					$b = $a -Split ($r.Groups[1].Value)
					write-host $b[0] -NoNewline -ForegroundColor Red;
					write-host $r.Groups[1].Value -ForegroundColor Yellow -NoNewline;
					write-host $b[1] -NoNewline;
					write-host 'at' -NoNewline;
					write-host $a[-1];
					break
				}
				DEFAULT { if ($line.trim().Length -gt 0) { write-host $line } }
			}
		}
	} else {
		Write-Status -Message 'Invoke-adDcDiag Error' -Type Error -Level 0
		Write-Status -Message 'Could not run command', $DcDiag -Type Warning, Info -Level 1
		#Write-Host "Could not run command $DcDiag" -ForegroundColor Yellow
	}
}
