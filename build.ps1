<#
.SYNOPSIS
  Builds lerd-setup.exe, the Inno Setup installer for lerd on Windows (WSL2).

.PARAMETER LerdRepo
  Checkout of lerd, used for the logo and the license. Defaults to ..\lerd-wsl.

.PARAMETER Version
  Version shown in Add/Remove Programs. Defaults to the repo's latest tag.
#>
param(
    [string]$LerdRepo = (Join-Path $PSScriptRoot '..\lerd-wsl'),
    [string]$Version
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$assets = Join-Path $PSScriptRoot 'assets'
New-Item -ItemType Directory -Force $assets | Out-Null
$logo = [System.Drawing.Image]::FromFile((Resolve-Path (Join-Path $LerdRepo 'internal\ui\icons\icon-512.png')))
$brand = [System.Drawing.Color]::FromArgb(255, 45, 32)

function Resize([System.Drawing.Image]$img, [int]$w, [int]$h, [System.Drawing.Color]$bg, [double]$scale) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.SmoothingMode = 'HighQuality'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear($bg)
    $side = [int]([Math]::Min($w, $h) * $scale)
    $g.DrawImage($img, [int](($w - $side) / 2), [int](($h - $side) / 2), $side, $side)
    $g.Dispose()
    $bmp
}

# An .ico whose frames are PNGs, which every Windows since Vista reads.
function Write-Ico([string]$path, [int[]]$sizes) {
    $frames = foreach ($s in $sizes) {
        $bmp = Resize $logo $s $s ([System.Drawing.Color]::Transparent) 1.0
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        , $ms.ToArray()
    }
    $out = New-Object System.IO.BinaryWriter ([System.IO.File]::Create($path))
    $out.Write([uint16]0); $out.Write([uint16]1); $out.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i] % 256 # 256 is written as 0
        $out.Write([byte]$s); $out.Write([byte]$s); $out.Write([byte]0); $out.Write([byte]0)
        $out.Write([uint16]1); $out.Write([uint16]32)
        $out.Write([uint32]$frames[$i].Length); $out.Write([uint32]$offset)
        $offset += $frames[$i].Length
    }
    foreach ($f in $frames) { $out.Write($f) }
    $out.Close()
}

Write-Ico (Join-Path $assets 'lerd.ico') @(16, 24, 32, 48, 64, 256)

# Wizard images at 100%, 125%, 150%, 200% and 250% DPI, as Inno's modern style expects.
$i = 0
foreach ($scale in 1.0, 1.25, 1.5, 2.0, 2.5) {
    $small = Resize $logo ([int](58 * $scale)) ([int](58 * $scale)) ([System.Drawing.Color]::White) 1.0
    $small.Save((Join-Path $assets "wizard-small-$i.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
    $small.Dispose()
    $large = Resize $logo ([int](164 * $scale)) ([int](314 * $scale)) $brand 0.8
    $large.Save((Join-Path $assets "wizard-$i.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
    $large.Dispose()
    $i++
}
$logo.Dispose()

Copy-Item (Join-Path $LerdRepo 'LICENSE') (Join-Path $assets 'LICENSE.txt') -Force

if (-not $Version) {
    $tag = git -C $LerdRepo describe --tags --abbrev=0 2>$null
    $Version = if ($tag) { $tag.TrimStart('v') } else { '0.0.0' }
}

$iscc = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'ISCC.exe not found; install Inno Setup 6 (winget install JRSoftware.InnoSetup)' }

& $iscc "/DAppVersion=$Version" (Join-Path $PSScriptRoot 'lerd.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }
