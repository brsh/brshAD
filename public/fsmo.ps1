Function Get-adFSMORoleOwner {
	<#
.SYNOPSIS
    FSMO role owners

.DESCRIPTION
    Retrieves the list of FSMO role owners of a forest and domain.

	And did you think there were only 5 FSMO roles? Well howdy-do!

.NOTES
    Name: Get-FSMORoleOwner
    Author: Boe Prox
    DateCreated: 06/9/2011
    http://learn-powershell.net/2011/06/12/fsmo-roles-and-powershell/

.EXAMPLE
    Get-adFSMORoleOwner

    DomainNamingMaster  : dc1.rivendell.com
    Domain              : rivendell.com
    RIDOwner            : dc1.rivendell.com
    Forest              : rivendell.com
    InfrastructureOwner : dc1.rivendell.com
    SchemaMaster        : dc1.rivendell.com
    PDCOwner            : dc1.rivendell.com
	DomainDNSZones		: dc1.rivendell.com
	ForestDNSZones		: dc1.rivendell.com

    Description
    -----------
    Retrieves the FSMO role owners each domain in a forest. Also lists the domain and forest.

#>
	[cmdletbinding()]
	Param()
	# 	Try {
	# 		$forest = [system.directoryservices.activedirectory.Forest]::GetCurrentForest()
	# 		ForEach ($domain in $forest.domains) {
	# 			$forestproperties = @{
	# 				Forest             = $Forest.name
	# 				Domain             = $domain.name
	# 				SchemaRole         = $forest.SchemaRoleOwner
	# 				NamingRole         = $forest.NamingRoleOwner
	# 				RidRole            = $Domain.RidRoleOwner
	# 				PdcRole            = $Domain.PdcRoleOwner
	# 				InfrastructureRole = $Domain.InfrastructureRoleOwner
	# 			}
	# 			if ($forestproperties.Domain -eq $forestproperties.Forest) {
	# 				try {
	# 					$forestproperties.ForestDNSZones = (Get-ADObject "cn=infrastructure,DC=ForestDNSZones,DC=smarshdev,DC=com" -Properties fSMORoleOwner).fSMORoleOwner
	# 				} catch {
	# 					$forestproperties.ForestDNSZones = "Error: Couldn't Read"
	# 				}
	# 			}
	# 			try {
	# 				$forestproperties.DomainDNSZones = (Get-ADObject "cn=infrastructure,DC=DomainDNSZones,DC=smarshdev,DC=com" -Properties fSMORoleOwner).fSMORoleOwner
	# 			} catch {
	# 				$forestproperties.DomainDNSZones = "Error: Couldn't Read"
	# 			}
	# 			$newobject = New-Object PSObject -Property $forestproperties
	# 			$newobject.PSTypeNames.Insert(0, "ForestRoles")
	# 			$newobject
	# 		}
	# 	} Catch {
	# 		Write-Warning "$($Error)"
	# 	}
	# }

	# function Get-adFSMODNS {
	Try {
		$forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
		ForEach ($domain in $forest.domains) {
			$forestproperties = @{
				Forest             = $Forest.name
				Domain             = $domain.name
				SchemaRole         = $forest.SchemaRoleOwner
				NamingRole         = $forest.NamingRoleOwner
				RidRole            = $Domain.RidRoleOwner
				PdcRole            = $Domain.PdcRoleOwner
				InfrastructureRole = $Domain.InfrastructureRoleOwner
			}
			if ($forestproperties.Domain -eq $forestproperties.Forest) {
				try {
					$searchBase = "LDAP://$($Forest.Name)/DC=ForestDnsZones,DC=$($forest.name.Replace('.',',DC='))"
					$query = new-object System.DirectoryServices.DirectoryEntry($searchBase)
					$adSearch = new-object System.DirectoryServices.DirectorySearcher($query)
					$null = $adSearch.PropertiesToLoad.Add('fSMORoleOwner')
					$roleHolderDN = ($adSearch.FindAll() | Select-Object -ExpandProperty Properties).fsmoroleowner
					[string] $b = $roleHolderDN.Replace('CN=NTDS Settings,', '').Split(',')
					$b = $b.Trim().Replace('CN=NTDS Settings,', '').Replace('CN', '').Split('=', [StringSplitOptions]::RemoveEmptyEntries)[0].TrimEnd(',').ToLower().Trim()
					if ($b.Length -gt 0) {
						$forestproperties.ForestDNSZones = "${b}`.$($domain.Name)"
					} else {
						$forestproperties.ForestDNSZones = $roleHolderDN
					}
				} catch {
					if ($PSVersionTable.PSVersion.Major -eq 2) {
						$forestproperties.ForestDNSZones = "(doesn't work on PSv2)"
					} else {
						$forestproperties.ForestDNSZones = $_.Exception.Message
					}
				}
			}
			try {
				$searchBase = "LDAP://$($Domain.Name)/DC=DomainDnsZones,DC=$($Domain.Name.Replace('.',',DC='))"
				$query = new-object System.DirectoryServices.DirectoryEntry($searchBase)
				$adSearch = new-object System.DirectoryServices.DirectorySearcher($query)
				$null = $adSearch.PropertiesToLoad.Add('fSMORoleOwner')
				$roleHolderDN = ($adSearch.FindAll() | Select-Object -ExpandProperty Properties).fsmoroleowner
				[string] $b = $roleHolderDN.Replace('CN=NTDS Settings,', '').Split(',')
				$b = $b.Trim().Replace('CN=NTDS Settings,', '').Replace('CN', '').Split('=', [StringSplitOptions]::RemoveEmptyEntries)[0].TrimEnd(',').ToLower().Trim()
				if ($b.Length -gt 0) {
					$forestproperties.DomainDNSZones = "${b}`.$($domain.Name)"
				} else {
					$forestproperties.DomainDNSZones = $roleHolderDN
				}
			} catch {
				if ($PSVersionTable.PSVersion.Major -eq 2) {
					$forestproperties.DomainDNSZones = "(doesn't work on PSv2)"
				} else {
					$forestproperties.DomainDNSZones = $_.Exception.Message
				}

			}
			$newobject = New-Object PSObject -Property $forestproperties
			$newobject.PSTypeNames.Insert(0, "ForestRoles")
			$newobject
		}
	} Catch {
		Write-Warning "$($Error)"
	}
}
