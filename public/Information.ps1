Function Get-adHelp {
	<#
	.SYNOPSIS
	List commands available in the brshAD Module

	.DESCRIPTION
	List all available commands in this module

	.EXAMPLE
	Get-adHelp
	#>
	Write-Host ""
	Write-Host "Getting available functions..." -ForegroundColor Yellow

	$all = @()
	$list = Get-Command -Type function -Module "brshAD" | Where-Object { $_.Name -in $script:ShowHelp }
	$list | ForEach-Object {
		if ($PSVersionTable.PSVersion.Major -lt 6) {
			$RetHelp = Get-Help $_.Name -ShowWindow:$false -ErrorAction SilentlyContinue
		} else {
			$RetHelp = Get-Help $_.Name -ErrorAction SilentlyContinue
		}
		if ($RetHelp.Description) {
			$Infohash = @{
				Command     = $_.Name
				Description = $RetHelp.Synopsis
			}
			$out = New-Object -TypeName psobject -Property $InfoHash
			$all += $out
		}
	}
	$all | Select-Object Command, Description | format-table -Wrap -AutoSize | Out-String | Write-Host
}

function Get-adDomainControllers {
	<#
    .SYNOPSIS
        List domain controllers

    .DESCRIPTION
        This function polls the domain for the following info on AD Domain Controllers:
            Name
            Domain
            FQDN
            IPAddress
            OS
            Site
            Current Time (with variance due to script run time)
            Roles
            Partitions
            Forest Name
            IsGC

    .EXAMPLE
        PS C:\> Get-adDomainControllers

    .EXAMPLE
        PS C:\> Get-adDomainControllers | format-list *

    .INPUTS
        None

    #>
	[system.directoryservices.activedirectory.domain]::GetCurrentDomain().DomainControllers | ForEach-Object {
		$OSmod = [string] $_.OSVersion
		try {
			if ($OSmod.Length -gt 0) {
				$OSmod = $OSmod.Replace("Windows", "")
				$OSmod = $OSmod.Replace("Server", "")
			}
		} catch { }

		try {
			if ($null -eq $_.CurrentTime) {
				$CurrentTime = [datetime] "1/1/1901"
			} else {
				$CurrentTime = [datetime] $_.CurrentTime
			}
		} catch { $CurrentTime = [datetime] "1/1/1901" }

		try {
			[String] $IsGC = "No"
			if (($_).IsGlobalCatalog()) { $IsGC = "Yes" }
		} catch { $IsGC = "Unknown" }

		$InfoHash = @{
			Name        = $_.Name.ToString().Split(".")[0]
			Domain      = $_.Domain
			FQDN        = $_.Name
			IPAddress   = $_.IPAddress
			OS          = $OSmod.Trim()
			Site        = $_.SiteName
			CurrentTime = $CurrentTime
			Roles       = $_.Roles
			Partitions  = $_.Partitions
			Forest      = $_.Forest
			IsGC        = $IsGC
		}
		$InfoStack = New-Object -TypeName PSObject -Property $InfoHash

		#Add a (hopefully) unique object type name
		$InfoStack.PSTypeNames.Insert(0, "DomainController.Information")

		#Sets the "default properties" when outputting the variable... but really for setting the order
		$defaultProperties = @('Name', 'IPAddress', 'OS', 'Site')
		$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
		$InfoStack | Add-Member MemberSet PSStandardMembers $PSStandardMembers

		$InfoStack
	}
}

function Get-adFunctionalLevels {
	<#
.SYNOPSIS
    Forest and domain functional levels

.DESCRIPTION
    Queries AD to get the the forest and domain functional levels

.EXAMPLE
    Get-adFunctionalLevels

    Windows2008R2Domain
    Windows2003Forest

#>
	[system.directoryservices.activedirectory.domain]::GetCurrentDomain().DomainMode
	[system.directoryservices.activedirectory.forest]::GetCurrentForest().ForestMode
}
