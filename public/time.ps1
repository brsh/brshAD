function Test-adTimeServer {
  <#
	.SYNOPSIS
	Wrapper for W32tm's TimeServer Test

	.DESCRIPTION
	Because w32tm's switches and config and all that are a pain to remember,
	this function wraps the stripchart command ... which naturally is what
	one would call a Time Server Test switch (yeah, it's not a test per se,
	it's a strip chart of the offset between this and another computer, but
	c'mon! It's a fricken' TEST!).

	It does use write-host for info, but returns the time and offset (or
	error) as objects. That said, I can't test all the results, so it
	will write-host "Unformatted" for anything it doesn't know.

  For the record, this function just runs w32tm.exe with the following:

  /stripchart - Displays a strip chart of the time offset between here and "there"
  /computer   - The "there" that the strip charts compares
  /DataOnly   - Disables the actual chart portion of the strip chart
  /Period     - The time between samples
  /Sample     - How many samples

  There are other settings that I chose not to include. I'm funny like that.

	.PARAMETER Computer
	The Computer (DNS Name or IP) to test against

	.PARAMETER Period
	Time between samples in seconds (default is 2s)

	.PARAMETER Samples
	How many samples (default is 5)

	.EXAMPLE
	Test-adTimeServer -Computer time.windows.com
	#>

  param (
    [string] $Computer = "ntp1.$($ENV:USERDNSDOMAIN)",
    [int] $Period = 2,
    [int] $Samples = 5
  )

  function New-timeObject {
    param (
      $Time,
      $Data,
      $Offset
    )
    [PSCustomObject] @{
      Time   = $Time
      Offset = $Offset
    }
  }

  w32tm.exe /stripchart /computer:$Computer /DataOnly /Period:$period /Samples:$Samples | ForEach-Object {
    Switch -Regex ($_) {
      'error:' { [string] $a, $b = $_ -split ' '; New-TimeObject -Time ($a.TrimEnd(',')) -Offset ($b -Join ' '); break }
      '^\d+:\d+:\d+,' { [string] $a, $b, $c = $_ -split ' '; New-TimeObject -Time ($a.TrimEnd(',')) -Offset $b; break }
      '^Tracking' { Write-Host $_ -ForegroundColor Yellow; break }
      '^Collecting' { $null = $_ }
      '^The current time' { Write-Host $_ -ForegroundColor Cyan ; break }
      DEFAULT { Write-host "$_" -ForegroundColor Yellow ; break }
    }
  }
}

function Get-adTimeSource {
  <#
	.SYNOPSIS
	Just a wrapper for w32tm /query /source

	.DESCRIPTION
	Again, it's hard to remember all the switches for w32tm... or even the name of the
	command itself - w32tm??? Really? Even with 8.3 you could call it something more
	memerable!

  For the record, this function just runs w32tm.exe with the following:

  /Query    : queries
  /Source   : the source
  /Computer : asks another computer for info (you need rights)

  .PARAMETER Computer
  The computer to query for the config

	.EXAMPLE
	Get-adTimeServer
	#>
  param (
    [String] $Computer = '.'
  )

  [string] $retval = w32tm.exe /query /source /computer:$Computer

  if ($retval -match 'error') {
    $retval = ($retval.Split(':')[1..($retval.Count)]).Trim() -Join ' '
  }

  [PSCustomObject] @{
    Source = $retval
  }
}

function Get-adTimeStatus {
  <#
	.SYNOPSIS
	Just a wrapper for w32tm /query /status

	.DESCRIPTION
	Again, it's hard to remember all the switches for w32tm... or even the name of the
	command itself - w32tm??? Really? Even with 8.3 you could call it something more
	memerable!

  For the record, this function just runs w32tm.exe with the following:

  /Query    : queries
  /Status   : the status
  /Computer : asks another computer for info (you need rights)
  /Verbose  : sets the verbose flag

  .PARAMETER Computer
  The computer to query for the config

	.EXAMPLE
	Get-adTimeStatus
	#>
  param (
    [String] $Computer = '.'
  )

  [string[]] $retval = w32tm.exe /query /status /computer:$Computer /verbose

  if ($retval -match ' error ') {
    $retval = ($retval.Split(':')[1..($retval.Count)]).Trim() -Join ' '
    [PSCustomObject] @{
      Status = $retval
    }
  } else {
    $hash = [ordered] @{ }
    $retval | ForEach-Object {
      if ($_.Trim().Length -gt 0) {
        [string] $a, [string] $b = $_ -split ':'
        $hash.Add($a.Trim(), $b.Trim())
      }
    }
    [PSCustomObject] $hash
  }
}

function Get-adTimePeers {
  <#
	.SYNOPSIS
	Just a wrapper for w32tm /query /peers

	.DESCRIPTION
	Again, it's hard to remember all the switches for w32tm... or even the name of the
	command itself - w32tm??? Really? Even with 8.3 you could call it something more
	memerable!

  For the record, this function just runs w32tm.exe with the following:

  /Query    : queries
  /Peers    : the peers
  /Computer : asks another computer for info (you need rights)
  /Verbose  : sets the verbose flag

  .PARAMETER Computer
  The computer to query for the config

	.EXAMPLE
	Get-adTimeStatus
	#>
  param (
    [String] $Computer = '.'
  )

  [string[]] $retval = w32tm.exe /query /peers /computer:$Computer /verbose

  if ($retval -match ' error ') {
    $retval = ($retval.Split(':')[1..($retval.Count)]).Trim() -Join ' '
    [PSCustomObject] @{
      Status = $retval
    }
  } else {
    $hash = [ordered] @{ }
    $retval[1..($retval.Count)] | ForEach-Object {
      if ($_.Trim().Length -gt 0) {
        [string] $a, [string] $b = $_ -split ':'
        $hash.Add($a.Trim(), $b.Trim())
      }
    }
    [PSCustomObject] $hash
  }
}

function Test-adTimeMonitor {
  <#
.SYNOPSIS
Wrapper for w32tm /monitor

.DESCRIPTION
YEah, it's just a wrapper. I _started_ work on parsing the output
into objects... but I don't have time to really fig it out at the
mo. That's what later is for.

For the record, this function just runs w32tm.exe with the following:

/monitor  : calls out to the current domain and gets info
/nowarn   : swallows the name resolution error

If you use the actual command, you can also leverage the following:
/domain   : monitors the specified domain (can be user more than once)
/computer : monitors the specified computers (commas, no spaces) (can be user more than once)
/threads  : how many threads to use (default is 3; allowed is 1-50)

.EXAMPLE
Test-adTimeMonitor
#>
  w32tm.exe /monitor /nowarn

  # [string[]] $retval = w32tm.exe /monitor /nowarn
  # $retval = $retval | Where-Object { ($_.Trim().Length -gt 0) -and ($_ -notmatch '^(Getting|Analyzing)') }

  # switch -Regex ($retval) {
  #   '^\S+' {
  #     if ($Obj) { $Obj }

  #     $Obj = New-Object -Type PSObject
  #     $Obj | Add-Member -type NoteProperty -Name "Server" -Value ($Matches[0] -split '\[')[0].Trim()
  #   }
  #   '^\s+ICMP:(\s+|\S+)' {
  #     $Obj | Add-Member -type NoteProperty -name ICMP -Value ($_ -split ':')[1].Trim()

  #   }
  #   '^\s+NTP:(\s+|\S+)' {
  #     $Obj | Add-Member -type NoteProperty -name NTP -Value ($_ -split ':')[1].Trim()
  #   }
  #   '^\s+RefID:(\s+|\S+)' {
  #     $Obj | Add-Member -type NoteProperty -name RefID -Value ($_ -split ':')[1].Trim()
  #   }
  #   '^\s+Stratum:(\s+|\S+)' {
  #     $Obj | Add-Member -type NoteProperty -name Stratum -Value ($_ -split ':')[1].Trim()
  #   }
  #   DEFAULT { $Obj }
  # }
}

function Sync-adTime {
  <#
  .SYNOPSIS
  Wrapper for the w32tm.exe /resync

  .DESCRIPTION
  Simple wrapper for w32tm.exe /resync - to request the computer resync it's clock
  as soon as possible - throwing out all error stats.

  For the record, this function just runs w32tm.exe with the following:

  /resync     : The resync command
  /rediscover : redetect the network config and rediscover the sources, then resync
  /computer   : try connecting to and resyncing on the specified computer (needs rights)

  .PARAMETER Computer
  The computer to try to resync (defaults to local)

  .PARAMETER Rediscover
  Rediscover network config and sources

  .EXAMPLE
  Sync-adTime
  #>

  param (
    [string] $Computer = '.',
    [switch] $Rediscover = $false
  )
  if ($Rediscover) {
    w32tm.exe /resync /rediscover /computer:$Computer
  } else {
    w32tm.exe /resync /computer:$Computer
  }
}
