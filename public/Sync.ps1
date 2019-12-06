function Sync-AllDomainControllers {
	[CmdletBinding()]
	param(
		[string] $Domain = $Env:USERDNSDOMAIN
	)
	$DistinguishedName = (Get-ADDomain -Server $Domain).DistinguishedName
	(Get-ADDomainController -Filter * -Server $Domain).Name | ForEach-Object {
		Write-Verbose -Message "Sync-DomainController - Forcing synchronization $_"
		RepAdmin /SyncAll $_ $DistinguishedName /e /A | Out-Null
	}
}

function Get-adSyncStatus {
	<#
	.SYNOPSIS
	Itemizes AD Repliction Status

	.DESCRIPTION
	A formatting wrapper around the Get-ADReplicationPartnerMetadata cmdlet
	in the PowerShell AD Module.

	By default, this will pull a quick table of replication dates and failure
	count for all DCs in the user's forest - with color-coding to make errors
	easier to see:

	* If the last replication time was a while ago, the dates will be yellow
	  or red
    * If the lastsuccess date does not equal the lastattempt, it will be yellow
	* If the consecutive failure numbers are above 0, they will be yellow or red,
	  depending on how many failures there were.

	You can access more info with Format-List as well as Select-Object.
	I recommend you look into that if you want.

	Also, you can summarize (like for automated monitoring). Simply pipe this
	function to Measure-Object and sum the ConsecutiveFailures property. Anything
	more than 1 means there's a replication problem somewhere.

	.PARAMETER Extended
	Shows a little extra info

	.PARAMETER Partition
	Select a specific partition's replication status. The switch will try to enum the non-dns partitions
	Defaults to * (or all partitions)

	.PARAMETER Target
	The source to hit - defaults to the current user's domain - but you can specify a server or an alt domain

	.PARAMETER Scope
	Specify forest, domain, site, or server to limit the ... scope. Not all scopes are valid for all targets

	.EXAMPLE
	Get-adSyncStatus

	Source		Partner		LastAttempt		LastSuccess		 Fails		Partition
	DC-1		DC-2		04-Nov 04:52p	04-Nov 04:52p	     0		Configuration
	DC-1		DC-2		04-Nov 04:52p	04-Nov 04:52p	     0		domain
	DC-1		DC-2		04-Nov 04:52p	04-Nov 04:52p	     0		Schema
	DC-2		DC-1		04-Nov 04:42p	04-Nov 04:42p	     0		Configuration
	DC-2		DC-1		04-Nov 04:42p	04-Nov 04:42p	     0		domain
	DC-2		DC-1		04-Nov 04:42p	04-Nov 04:42p	     0		Schema
	#>

	[CmdletBinding()]
	param(
		[switch] $Extended,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-adPartition -Filter "$WordToComplete").NickName
				} else {
					(Get-adPartition).NickName
				}
			})]
		[string] $Partition = '*',
		[string] $Target = $env:USERDNSDOMAIN,
		[ValidateSet('Forest', 'Domain', 'Site', 'Server')]
		[string] $Scope = 'Forest'
	)
	if ($Partition -ne '*') {
		$Partition = (Get-adPartition -Filter $Partition).Path
	}

	$Options = @{
		Target        = $Target
		Partition     = $Partition
		Scope         = $Scope
		ErrorAction   = 'SilentlyContinue'
		ErrorVariable = 'ProcessErrors'
	}

	$Replication = Get-ADReplicationPartnerMetadata @Options

	if ($ProcessErrors) {
		foreach ($_ in $ProcessErrors) {
			Write-Warning -Message "Get-WinADForestReplicationPartnerMetaData - Error on server $($_.Exception.ServerName): $($_.Exception.Message)"
		}
	}
	foreach ($_ in $Replication) {
		$ServerPartner = (Resolve-DnsName -Name $_.PartnerAddress -Verbose:$false -ErrorAction SilentlyContinue)
		$ServerInitiating = (Resolve-DnsName -Name $_.Server -Verbose:$false -ErrorAction SilentlyContinue)
		$ReplicationObject = [ordered] @{
			PSTypeName                = 'brshAD.ReplicationMetadata'

			Source                    = $(($_.Server.Split('.'))[0]).ToUpper()
			SourceFullName            = $_.Server
			SourceIPV4                = $ServerInitiating.IP4Address
			SourceDomain              = $(($_.Server.Split('.'))[1])
			Partner                   = $(($ServerPartner.NameHost.Split('.'))[0]).ToUpper()
			PartnerFullName           = $ServerPartner.NameHost
			PartnerIPV4               = $ServerPartner.IP4Address
			PartnerDomain             = $(($ServerPartner.NameHost.Split('.'))[1])
			LastAttempt               = $_.LastReplicationAttempt
			LastResult                = $_.LastReplicationResult
			LastSuccess               = $_.LastReplicationSuccess
			ConsecutiveFailures       = $_.ConsecutiveReplicationFailures
			LastChangeUsn             = $_.LastChangeUsn
			PartnerType               = $_.PartnerType
			Partition                 = $((($_.Partition.Split(','))[0]).Split('=')[1])
			PartitionFQDN             = $_.Partition
			TwoWaySync                = $_.TwoWaySync
			ScheduledSync             = $_.ScheduledSync
			SyncOnStartup             = $_.SyncOnStartup
			CompressChanges           = $_.CompressChanges
			DisableScheduledSync      = $_.DisableScheduledSync
			IgnoreChangeNotifications = $_.IgnoreChangeNotifications
			IntersiteTransport        = $_.IntersiteTransport
			IntersiteTransportGuid    = $_.IntersiteTransportGuid
			IntersiteTransportType    = $_.IntersiteTransportType
			UsnFilter                 = $_.UsnFilter
			Writable                  = $_.Writable
		}
		if ($Extended) {
			$ReplicationObject.PartnerDN = $_.Partner
			$ReplicationObject.PartnerAddress = $_.PartnerAddress
			$ReplicationObject.PartnerGuid = $_.PartnerGuid
			$ReplicationObject.PartnerInvocationId = $_.PartnerInvocationId
			$ReplicationObject.PartitionGuid = $_.PartitionGuid
		}
		[PSCustomObject] $ReplicationObject
	}
}
