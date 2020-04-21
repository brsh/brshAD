Function DrawIt {
	param (
		[String] $Text = "Hello World",
		[string] $FileName = ''
	)

	#Let's remove invalid filesystem characters and ones we just don't like in filenames
	$invalidChars = ([IO.Path]::GetInvalidFileNameChars() + "," + ";") -join ''
	$re = "[{0}]" -f [RegEx]::Escape($invalidChars)
	$FileName = $FileName -replace $re
	$FileName = $FileName.Replace(" ", "")
	$FileName = $FileName.Trim('.')

	Add-Type -AssemblyName System.Drawing

	$height = [int]( ($($text | Measure-Object -line).Lines * 22) + 25 )
	if ($Height -lt 350 ) { $height = 350 }

	$longest = 0
	foreach ($line in $Text.Split("`n")) {
		$hold = $line.ToString().Length
		if ($hold -gt $longest) { $longest = $hold }
	}
	$length = [int]( $longest * 12)

	$bmp = new-object System.Drawing.Bitmap $length, $height
	$font = new-object System.Drawing.Font Consolas, 14
	$brushBg = [System.Drawing.Brushes]::White
	$brushFg = [System.Drawing.Brushes]::Black
	$graphics = [System.Drawing.Graphics]::FromImage($bmp)
	$graphics.FillRectangle($brushBg, 0, 0, $bmp.Width, $bmp.Height)
	$graphics.DrawString($Text, $font, $brushFg, 10, 10)
	$graphics.Dispose()
	"Writing picture..." | Write-Verbose
	$bmp.Save($FileName)
}
