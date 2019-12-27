function Get-NextAvailableID {
	param (
		[string] $type = 'GID'
	)
	if ($type -match '^U') {
		[int] $highest = (Get-adLinuxUser | Sort-Object uidNumber -Descending | Select-Object -First 1).uidNumber
	} else {
		[int] $highest = (Get-adLinuxGroup | Sort-Object gidNumber -Descending | Select-Object -First 1).gidNumber
	}
	New-Object -TypeName PSCustomObject -Property @{
		PSTypeName = 'brshAD.NextLinuxID'
		Highest    = $highest
		Next       = $highest + 1
	}
}
