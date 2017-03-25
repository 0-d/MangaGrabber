[CMDletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$BaseURI, #  Example: 'http://www.mangatown.com/manga/kuzu_no_honkai'
	[int]$ChapterStart = 1,
	[Parameter(Mandatory)]
	[int]$ChapterEnd,
	[string]$ChapterExtra,
	[ValidateSet('Chrome', 'FireFox', 'InternetExplorer', 'Opera', 'Safari')]
	[string]$UserAgent = 'InternetExplorer'
)

	$UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::"$UserAgent"
	[float[]]$Chapters = $ChapterStart..$ChapterEnd
	

if ($ChapterExtra) {
	[float[]]$Extras = $ChapterExtra.Split()
    $Chapters = $Chapters + $Extras
}

foreach ($c in $Chapters) {
	# Create dir for current chapter and CD to it
    New-Item -ItemType Directory -Name "ch0$c" -Force
    Set-Location -Path "ch0$c"

    $chapterURI = "$BaseURI/c0$c"
    $chapData = Invoke-WebRequest -Uri $chapterURI -UserAgent $ua | select -ExpandProperty RawContent
    $pattern = "\<option value=`"$chapterURI/\d{1,3}.html`"\s?\>(\d{1,3})\</option\>"
    $optionsList = $chapData.Split("`n") | Where {$_ -match $pattern}
    $pagesList = [int[]]($optionsList | %{($_ -replace $pattern, '$1').Trim()})
    [int]$maxPage = $pagesList | measure -Maximum | select -ExpandProperty Maximum

    foreach ($p in (1..$maxPage) ) {
        
		# We need 3-digit name
        $num = "00$p"
        $num = $num[($num.Length -3)..($num.Length - 1)] -join ''
        
        $webpage = Invoke-WebRequest -Uri "$chapterURI/$p.html" -UserAgent $ua -SessionVariable TempMangaSession | 
					select -ExpandProperty RawContent

        $string = $webpage.Split("`n") | where {$_ -Match 'img src="http://h.mangatown.com/store/manga/'}
        $URI = $string -replace '^.*src="(.+ttl=\d{8,12})"\s.+$', '$1'

        Write-Verbose "Downloading: $URI`t"
        try {
            Invoke-WebRequest -Uri $URI -UserAgent $ua -OutFile "$num.jpg" -WebSession $TempMangaSession
            Write-Verbose "OK ($num.jpg)"
        }
        catch {
            Write-Verbose -f Red "FAIL: [$($_.Exception.Message)]"
        }
    }

	# Return to parent
    Set-Location -Path ..
}