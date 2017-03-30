#requires -version 3

<#
.Synopsis
   Manga downloader for www.mangatown.com

.DESCRIPTION
   Downloads manga by given URL
   
   Author: Petr Egorov ()

.EXAMPLE
   .\Grab-Manga.ps1 -BaseURI 'http://www.mangatown.com/manga/angel_beats_heaven_s_door/' -OutFolder "C:\Downloads\Manga\Angel Beats! - Heaven's Door"
#>

[CMDletBinding()]
param(
	[Parameter(Mandatory)]
    [ValidateScript({[uri]::New($_)})]
	[string]$BaseURI,

    [Parameter(Mandatory)]
    [ValidateScript({[System.IO.Path]::GetFullPath($_)})]
    [string]$OutFolder
)

#region FUNCTIONS

workflow Get-MangaImage {
    Param(
        [Parameter(Mandatory)]
        [string[]]$PagesURI,
        [string]$Location
    )

    foreach -parallel ($Page in $PagesURI) {
        inlineScript {
            $pageContent = Invoke-WebRequest -Uri $using:Page -SessionVariable mangatown
            $pageDOM = $pageContent.ParsedHtml

            # Get images by ID (usually only one)
            $Images = $pageDOM.getElementById('image') | Select-Object -ExpandProperty src

            Set-Location -Path $using:Location
            foreach ($img in $Images) {
                try {
                    $outImg = [System.IO.Path]::GetFileName($img) -replace '\?.+$' # get rid of tokens, etc.
                    
                    Invoke-WebRequest -Uri $img -OutFile $outImg -WebSession $mangatown -ErrorAction Stop
                    Write-Output "Downloaded [$img] to [$outImg]"
                }
                catch {
                    Write-Error -Exception $_.Exception -Message "[$outImg] ERROR: $($_.Exception.Message)"
                }
            }
        }
    }
}

#endregion FUNCTIONS

#region MAIN

# Check out folder
if (-not (Test-Path $OutFolder)) {
    try {
        New-Item -ItemType Directory -Path $OutFolder -Force -ErrorAction Stop
    }
    catch {
        Write-Error -Exception $_.Exception -Message "Unable to create directory: $($_.Exception.Message)"
        break
    }
}

# Get contents of manga page
$baseContent = Invoke-WebRequest -Uri $BaseURI
$baseDOM = $baseContent.ParsedHtml

# Get chapter links
$Chapters = $DOM.getElementsByTagName('a') | Where-Object -FilterScript { $_.href -Match '^.+/c\d{3}/?$'} | 
				Select-Object -ExpandProperty href -Unique | Sort-Object # for correct order

foreach ($Chapter in $Chapters) {
    $chapContent = Invoke-WebRequest -Uri $Chapter
    $chapDOM = $chapContent.ParsedHtml

    # Get pages links
    $Pages = $chapDOM.getElementsByTagName('option') | Select-Object -ExpandProperty value -Unique

    $chapDir = Split-Path -Path ([uri]::new($Chapter).AbsolutePath) -Leaf
    if (Test-Path "$OutFolder\$chapDir") {
        Write-Warning "Folder [$OutFolder\$chapDir] exists - content may be overwritten!"
    }
    else {
        New-Item -ItemType Directory -Path "$OutFolder\$chapDir" -Force
    }
	    
    Write-Host -f Yellow "Chapter [$chapDir] - $($Pages.count) pages"

    Get-MangaImage -PagesURI $Pages -Location "$OutFolder\$chapDir"
}

#endregion MAIN