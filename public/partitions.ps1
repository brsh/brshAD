function Get-adPartition {
	[cmdletbinding()]
	param (
		[switch] $ExcludeDNS = $false,
		[string] $Server = $env:USERDNSDOMAIN,
		[string] $Filter = ''
	)
	$all = Get-ADDomainController -Server $Server | Select-Object -ExpandProperty Partitions

	$all | ForEach-Object {
		if ($ExcludeDNS -and ($_.ToString() -match 'DnsZone')) {
			Write-Verbose "Skipping DNSZone $_"
		} else {
			$Partition = [ordered] @{
				PSTypeName = 'brshAD.Partition'
				Nickname   = $($_.ToString().Split(',')[0].Split('=')[1])
				Path       = $_
			}
			$retval = [PSCustomObject] $Partition
			if ($Filter.Length -gt 0) {
				if ($Partition.Nickname -match "^$Filter") { $retval }
			} else {
				$retval
			}
		}
	}
}
