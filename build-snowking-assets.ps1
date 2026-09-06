param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $PSScriptRoot 'assets-source'
$outputDir = Join-Path $PSScriptRoot 'assets-hq'
$manifestPath = Join-Path $outputDir 'manifest.json'

$sourcePaths = @{
    awake = Join-Path $sourceDir 'xuewang-awake.png'
    happy = Join-Path $sourceDir 'xuewang-happy.png'
    sleeping = Join-Path $sourceDir 'xuewang-sleeping.png'
    hungry = Join-Path $sourceDir 'xuewang-hungry.png'
    bullied = Join-Path $sourceDir 'xuewang-bullied.png'
    angry = Join-Path $sourceDir 'xuewang-angry.png'
    smug = Join-Path $sourceDir 'xuewang-smug.png'
    stuffed = Join-Path $sourceDir 'xuewang-stuffed.png'
    shy = Join-Path $sourceDir 'xuewang-shy.png'
    dizzy = Join-Path $sourceDir 'xuewang-dizzy.png'
    pout = Join-Path $sourceDir 'xuewang-pout.png'
    crawl = Join-Path $sourceDir 'xuewang-crawl-sneak.png'
    capeBurrito = Join-Path $sourceDir 'xuewang-cape-burrito.png'
    pancake = Join-Path $sourceDir 'xuewang-pancake-fall.png'
    iceMagic = Join-Path $sourceDir 'xuewang-ice-magic.png'
    snackStruggle = Join-Path $sourceDir 'xuewang-snack-struggle.png'
    crownChase = Join-Path $sourceDir 'xuewang-crown-chase.png'
    snowball = Join-Path $sourceDir 'xuewang-snowball-slide.png'
    cheekSquish = Join-Path $sourceDir 'xuewang-cheek-squish-fixed.png'
    feastGuard = Join-Path $sourceDir 'xuewang-feast-guard.png'
}

foreach ($entry in $sourcePaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value)) {
        throw "缺少主姿态素材：$($entry.Value)"
    }
}

if ((Test-Path -LiteralPath $manifestPath) -and -not $Force) {
    Write-Output "动画已存在；需要重建时请加 -Force：$manifestPath"
    exit 0
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

function New-NormalizedMaster {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$CanvasWidth = 192,
        [int]$CanvasHeight = 208
    )

    $original = [Drawing.Bitmap]::new($Path)
    try {
        $rgba = [Drawing.Bitmap]::new($original.Width, $original.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $copyGraphics = [Drawing.Graphics]::FromImage($rgba)
        try {
            $copyGraphics.Clear([Drawing.Color]::Transparent)
            $copyGraphics.DrawImage($original, 0, 0, $original.Width, $original.Height)
        } finally {
            $copyGraphics.Dispose()
        }

        $rect = [Drawing.Rectangle]::new(0, 0, $rgba.Width, $rgba.Height)
        $bits = $rgba.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $bytes = [byte[]]::new([Math]::Abs($bits.Stride) * $bits.Height)
            [Runtime.InteropServices.Marshal]::Copy($bits.Scan0, $bytes, 0, $bytes.Length)
            $minX = $rgba.Width
            $minY = $rgba.Height
            $maxX = -1
            $maxY = -1
            for ($y = 0; $y -lt $rgba.Height; $y++) {
                $row = $y * $bits.Stride
                for ($x = 0; $x -lt $rgba.Width; $x++) {
                    if ($bytes[$row + ($x * 4) + 3] -gt 6) {
                        if ($x -lt $minX) { $minX = $x }
                        if ($x -gt $maxX) { $maxX = $x }
                        if ($y -lt $minY) { $minY = $y }
                        if ($y -gt $maxY) { $maxY = $y }
                    }
                }
            }
        } finally {
            $rgba.UnlockBits($bits)
        }

        if ($maxX -lt $minX -or $maxY -lt $minY) {
            $rgba.Dispose()
            throw "素材没有可见像素：$Path"
        }

        $cropWidth = $maxX - $minX + 1
        $cropHeight = $maxY - $minY + 1
        $scale = [Math]::Min(182.0 / $cropWidth, 198.0 / $cropHeight)
        $drawWidth = [int][Math]::Round($cropWidth * $scale)
        $drawHeight = [int][Math]::Round($cropHeight * $scale)
        $drawX = [int][Math]::Round(($CanvasWidth - $drawWidth) / 2.0)
        $drawY = $CanvasHeight - $drawHeight - 4

        $master = [Drawing.Bitmap]::new($CanvasWidth, $CanvasHeight, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($master)
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
            $destination = [Drawing.Rectangle]::new($drawX, $drawY, $drawWidth, $drawHeight)
            $source = [Drawing.Rectangle]::new($minX, $minY, $cropWidth, $cropHeight)
            $graphics.DrawImage($rgba, $destination, $source, [Drawing.GraphicsUnit]::Pixel)
        } finally {
            $graphics.Dispose()
            $rgba.Dispose()
        }
        return $master
    } finally {
        $original.Dispose()
    }
}

function New-FrameSpec {
    param(
        [double]$X = 0,
        [double]$Y = 0,
        [double]$Angle = 0,
        [double]$ScaleX = 1,
        [double]$ScaleY = 1,
        [double]$Brightness = 1
    )
    [ordered]@{ X=$X; Y=$Y; Angle=$Angle; ScaleX=$ScaleX; ScaleY=$ScaleY; Brightness=$Brightness }
}

$masters = @{
    awake = New-NormalizedMaster -Path $sourcePaths.awake
    happy = New-NormalizedMaster -Path $sourcePaths.happy
    sleeping = New-NormalizedMaster -Path $sourcePaths.sleeping
    hungry = New-NormalizedMaster -Path $sourcePaths.hungry
    bullied = New-NormalizedMaster -Path $sourcePaths.bullied
    angry = New-NormalizedMaster -Path $sourcePaths.angry
    smug = New-NormalizedMaster -Path $sourcePaths.smug
    stuffed = New-NormalizedMaster -Path $sourcePaths.stuffed
    shy = New-NormalizedMaster -Path $sourcePaths.shy
    dizzy = New-NormalizedMaster -Path $sourcePaths.dizzy
    pout = New-NormalizedMaster -Path $sourcePaths.pout
    crawl = New-NormalizedMaster -Path $sourcePaths.crawl
    capeBurrito = New-NormalizedMaster -Path $sourcePaths.capeBurrito
    pancake = New-NormalizedMaster -Path $sourcePaths.pancake
    iceMagic = New-NormalizedMaster -Path $sourcePaths.iceMagic
    snackStruggle = New-NormalizedMaster -Path $sourcePaths.snackStruggle
    crownChase = New-NormalizedMaster -Path $sourcePaths.crownChase
    snowball = New-NormalizedMaster -Path $sourcePaths.snowball
    cheekSquish = New-NormalizedMaster -Path $sourcePaths.cheekSquish
    feastGuard = New-NormalizedMaster -Path $sourcePaths.feastGuard
}

$animations = [ordered]@{
    failed = @{ intervalMs=340; master='awake'; specs=@(
        (New-FrameSpec -Y 2 -Angle -2 -ScaleX .98 -ScaleY 1.01 -Brightness .78),
        (New-FrameSpec -Y 3 -Angle -1 -ScaleX .99 -ScaleY 1.00 -Brightness .76),
        (New-FrameSpec -Y 4 -Angle 0 -ScaleX 1.00 -ScaleY .99 -Brightness .74),
        (New-FrameSpec -Y 3 -Angle 1 -ScaleX .99 -ScaleY 1.00 -Brightness .76),
        (New-FrameSpec -Y 2 -Angle 2 -ScaleX .98 -ScaleY 1.01 -Brightness .78),
        (New-FrameSpec -Y 3 -Angle 1 -ScaleX .99 -ScaleY 1.00 -Brightness .76),
        (New-FrameSpec -Y 4 -Angle 0 -ScaleX 1.00 -ScaleY .99 -Brightness .74),
        (New-FrameSpec -Y 3 -Angle -1 -ScaleX .99 -ScaleY 1.00 -Brightness .76)
    ) }
    feeding = @{ intervalMs=430; master='happy'; specs=@(
        (New-FrameSpec -Y 1 -Angle -2 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -Y -1 -Angle 1 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -Y 0 -Angle -1 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y -2 -Angle 2 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -Y 0 -Angle 0 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -Y 1 -Angle -1 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    idle = @{ intervalMs=360; master='awake'; specs=@(
        (New-FrameSpec -Y 1 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 0 -Angle -1 -ScaleX 1.005 -ScaleY .995),
        (New-FrameSpec -Y -1 -Angle 0 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 0 -Angle 1 -ScaleX 1.005 -ScaleY .995),
        (New-FrameSpec -Y 1 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 0 -Angle 0 -ScaleX .997 -ScaleY 1.003)
    ) }
    jumping = @{ intervalMs=180; master='happy'; specs=@(
        (New-FrameSpec -Y 3 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -Y -4 -Angle -2 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -Y -11 -Angle 0 -ScaleX .97 -ScaleY 1.05),
        (New-FrameSpec -Y -4 -Angle 2 -ScaleX .99 -ScaleY 1.03),
        (New-FrameSpec -Y 3 -ScaleX 1.05 -ScaleY .95)
    ) }
    petting = @{ intervalMs=360; master='happy'; specs=@(
        (New-FrameSpec -Y 1 -Angle -2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -Y 2 -Angle -3 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -Y 1 -Angle -1 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -Y 0 -Angle 2 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -Y 1 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 0 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    review = @{ intervalMs=340; master='awake'; specs=@(
        (New-FrameSpec -X -1 -Angle -5),
        (New-FrameSpec -X -2 -Angle -7 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X -1 -Angle -3),
        (New-FrameSpec -X 1 -Angle 3),
        (New-FrameSpec -X 2 -Angle 7 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X 1 -Angle 5)
    ) }
    'running-left' = @{ intervalMs=105; master='happy'; specs=@(
        (New-FrameSpec -X -2 -Y 2 -Angle 3 -ScaleX -1.03 -ScaleY .97),
        (New-FrameSpec -X -3 -Y -2 -Angle 1 -ScaleX -1.00 -ScaleY 1.02),
        (New-FrameSpec -X -4 -Y -5 -Angle -1 -ScaleX -.98 -ScaleY 1.04),
        (New-FrameSpec -X -3 -Y -1 -Angle -3 -ScaleX -1.00 -ScaleY 1.01),
        (New-FrameSpec -X -2 -Y 2 -Angle -2 -ScaleX -1.03 -ScaleY .97),
        (New-FrameSpec -X -3 -Y -2 -Angle 0 -ScaleX -1.00 -ScaleY 1.02),
        (New-FrameSpec -X -4 -Y -5 -Angle 2 -ScaleX -.98 -ScaleY 1.04),
        (New-FrameSpec -X -3 -Y -1 -Angle 3 -ScaleX -1.00 -ScaleY 1.01)
    ) }
    'running-right' = @{ intervalMs=105; master='happy'; specs=@(
        (New-FrameSpec -X 2 -Y 2 -Angle -3 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 3 -Y -2 -Angle -1 -ScaleX 1.00 -ScaleY 1.02),
        (New-FrameSpec -X 4 -Y -5 -Angle 1 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X 3 -Y -1 -Angle 3 -ScaleX 1.00 -ScaleY 1.01),
        (New-FrameSpec -X 2 -Y 2 -Angle 2 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 3 -Y -2 -Angle 0 -ScaleX 1.00 -ScaleY 1.02),
        (New-FrameSpec -X 4 -Y -5 -Angle -2 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X 3 -Y -1 -Angle -3 -ScaleX 1.00 -ScaleY 1.01)
    ) }
    running = @{ intervalMs=120; master='happy'; specs=@(
        (New-FrameSpec -Y 2 -Angle -3 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -Y -3 -Angle -1 -ScaleX 1.00 -ScaleY 1.03),
        (New-FrameSpec -Y -6 -Angle 1 -ScaleX .98 -ScaleY 1.05),
        (New-FrameSpec -Y -2 -Angle 3 -ScaleX 1.00 -ScaleY 1.02),
        (New-FrameSpec -Y 2 -Angle 1 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -Y -2 -Angle -1 -ScaleX 1.00 -ScaleY 1.02)
    ) }
    sleeping = @{ intervalMs=1500; master='sleeping'; specs=@(
        (New-FrameSpec -Y 2 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 1 -ScaleX 1.012 -ScaleY .992)
    ) }
    waiting = @{ intervalMs=340; master='awake'; specs=@(
        (New-FrameSpec -Angle -2 -X -1),
        (New-FrameSpec -Angle -4 -X -2 -Y -1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Angle -1 -X -1),
        (New-FrameSpec -Angle 2 -X 1),
        (New-FrameSpec -Angle 4 -X 2 -Y -1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Angle 1 -X 1)
    ) }
    waving = @{ intervalMs=260; master='happy'; specs=@(
        (New-FrameSpec -Angle -3 -X -1 -Y 0 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Angle 2 -X 1 -Y -2 -ScaleX .99 -ScaleY 1.02),
        (New-FrameSpec -Angle -1 -X 0 -Y -4 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -Angle 3 -X 1 -Y -1 -ScaleX 1.01 -ScaleY .99)
    ) }
    hungry = @{ intervalMs=300; master='hungry'; specs=@(
        (New-FrameSpec -X -1 -Angle -2 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -X 1 -Y -1 -Angle 2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X 2 -Y -2 -Angle 3 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 0 -Y -1 -Angle 0 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X -1 -Angle -2 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    bullied = @{ intervalMs=420; master='bullied'; specs=@(
        (New-FrameSpec -Y 2 -Angle -2 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -Y 3 -Angle 2 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 2 -Angle -1 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -Y 3 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 2 -Angle -2 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -Y 1 -Angle 0 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    angry = @{ intervalMs=180; master='angry'; specs=@(
        (New-FrameSpec -X -2 -Angle -3 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 2 -Y -2 -Angle 3 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -X -2 -Y 1 -Angle -2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X 2 -Y -3 -Angle 2 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X -1 -Y 1 -Angle -1 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X 1 -Angle 1 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    smug = @{ intervalMs=380; master='smug'; specs=@(
        (New-FrameSpec -Y 1 -Angle -2),
        (New-FrameSpec -Y 0 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y -1 -Angle 2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -Y 0 -Angle 0 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 1 -Angle -2)
    ) }
    stuffed = @{ intervalMs=520; master='stuffed'; specs=@(
        (New-FrameSpec -Y 2 -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 1 -ScaleX 1.015 -ScaleY .99),
        (New-FrameSpec -Y 0 -ScaleX 1.025 -ScaleY .985),
        (New-FrameSpec -Y 1 -ScaleX 1.015 -ScaleY .99),
        (New-FrameSpec -Y 2 -ScaleX 1.00 -ScaleY 1.00)
    ) }
    shy = @{ intervalMs=380; master='shy'; specs=@(
        (New-FrameSpec -X -1 -Angle -3),
        (New-FrameSpec -X -2 -Y 1 -Angle -5 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -X -1 -Angle -2),
        (New-FrameSpec -X 1 -Angle 2),
        (New-FrameSpec -X 0 -Angle 0)
    ) }
    dizzy = @{ intervalMs=150; master='dizzy'; specs=@(
        (New-FrameSpec -X -3 -Angle -6),
        (New-FrameSpec -X 3 -Y -2 -Angle 6 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -X -2 -Y 1 -Angle -4 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X 2 -Y -1 -Angle 5 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -X -1 -Angle -3),
        (New-FrameSpec -X 1 -Angle 3)
    ) }
    pout = @{ intervalMs=420; master='pout'; specs=@(
        (New-FrameSpec -X -1 -Angle -2),
        (New-FrameSpec -X 1 -Angle 2 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X -1 -Angle -1),
        (New-FrameSpec -X 1 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X 0 -Angle 0)
    ) }
    'crown-tap' = @{ intervalMs=190; master='pout'; specs=@(
        (New-FrameSpec -Y 1 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -Y 4 -Angle 3 -ScaleX 1.06 -ScaleY .94),
        (New-FrameSpec -Y -2 -Angle -4 -ScaleX .97 -ScaleY 1.04),
        (New-FrameSpec -Y 1 -Angle 1 -ScaleX 1.01 -ScaleY .99)
    ) }
    'cheek-poke' = @{ intervalMs=210; master='pout'; specs=@(
        (New-FrameSpec -X -2 -ScaleX .98 -ScaleY 1.01),
        (New-FrameSpec -X 4 -Angle 3 -ScaleX 1.04 -ScaleY .97),
        (New-FrameSpec -X -1 -Angle -2 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -X 1 -Angle 1)
    ) }
    'ear-touch' = @{ intervalMs=260; master='shy'; specs=@(
        (New-FrameSpec -X -1 -Angle -4),
        (New-FrameSpec -X -3 -Y 1 -Angle -7 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -X 1 -Angle 3),
        (New-FrameSpec -X 0 -Angle 0)
    ) }
    'belly-poke' = @{ intervalMs=220; master='stuffed'; specs=@(
        (New-FrameSpec -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 2 -ScaleX 1.06 -ScaleY .94),
        (New-FrameSpec -Y -1 -ScaleX .97 -ScaleY 1.04),
        (New-FrameSpec -ScaleX 1.01 -ScaleY .99)
    ) }
    'wand-touch' = @{ intervalMs=190; master='angry'; specs=@(
        (New-FrameSpec -X -2 -Angle -5),
        (New-FrameSpec -X 3 -Y -2 -Angle 7 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -X -1 -Angle -3),
        (New-FrameSpec -X 1 -Angle 2)
    ) }
    'cape-pull' = @{ intervalMs=210; master='bullied'; specs=@(
        (New-FrameSpec -X 1 -Angle 2),
        (New-FrameSpec -X 5 -Y 1 -Angle 6 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X -2 -Y -1 -Angle -4 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -X 0 -Angle 0)
    ) }
    'foot-tickle' = @{ intervalMs=150; master='dizzy'; specs=@(
        (New-FrameSpec -X -3 -Y -2 -Angle -5),
        (New-FrameSpec -X 3 -Y -5 -Angle 5 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -X -2 -Y 0 -Angle -4 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 2 -Y -3 -Angle 4)
    ) }
    'wake-startle' = @{ intervalMs=180; master='angry'; specs=@(
        (New-FrameSpec -Y 3 -ScaleX 1.06 -ScaleY .94),
        (New-FrameSpec -Y -9 -ScaleX .94 -ScaleY 1.08),
        (New-FrameSpec -X -3 -Y -3 -Angle -6),
        (New-FrameSpec -X 2 -Y 0 -Angle 4)
    ) }
    'doro-crawl' = @{ intervalMs=125; master='crawl'; specs=@(
        (New-FrameSpec -X -4 -Y 2 -Angle -2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X -1 -Y -2 -Angle 1 -ScaleX .99 -ScaleY 1.02),
        (New-FrameSpec -X 3 -Y 1 -Angle 2 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 6 -Y -2 -Angle -1 -ScaleX .99 -ScaleY 1.02),
        (New-FrameSpec -X 2 -Y 1 -Angle -2 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X -2 -Y -1 -Angle 1)
    ) }
    'food-sneak' = @{ intervalMs=210; master='crawl'; specs=@(
        (New-FrameSpec -X -4 -Angle -3 -Brightness .92),
        (New-FrameSpec -X -1 -Y -2 -Angle -1 -ScaleX 1.01 -ScaleY .99 -Brightness .95),
        (New-FrameSpec -X 3 -Y -3 -Angle 2 -Brightness .98),
        (New-FrameSpec -X 6 -Y -1 -Angle 3),
        (New-FrameSpec -X 2 -Angle 0 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X -2 -Angle -2 -Brightness .94)
    ) }
    'guard-pounce' = @{ intervalMs=145; master='crawl'; specs=@(
        (New-FrameSpec -X -5 -Y 3 -ScaleX 1.06 -ScaleY .94),
        (New-FrameSpec -X 0 -Y -5 -Angle 3 -ScaleX .96 -ScaleY 1.05),
        (New-FrameSpec -X 6 -Y -8 -Angle 6 -ScaleX .94 -ScaleY 1.07),
        (New-FrameSpec -X 2 -Y 2 -Angle -3 -ScaleX 1.08 -ScaleY .92),
        (New-FrameSpec -X 0 -Y 1 -ScaleX 1.02 -ScaleY .98)
    ) }
    'cape-burrito' = @{ intervalMs=430; master='capeBurrito'; specs=@(
        (New-FrameSpec -Y 2 -Angle -2),
        (New-FrameSpec -Y 1 -Angle 2 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 0 -Angle -1 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -Y 1 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Y 2 -Angle -2)
    ) }
    'nightmare-hide' = @{ intervalMs=320; master='capeBurrito'; specs=@(
        (New-FrameSpec -X -2 -Y 2 -Angle -3 -Brightness .78),
        (New-FrameSpec -X 2 -Y 3 -Angle 3 -Brightness .76),
        (New-FrameSpec -X -2 -Y 2 -Angle -2 -Brightness .80),
        (New-FrameSpec -X 1 -Y 1 -Angle 2 -Brightness .82),
        (New-FrameSpec -X 0 -Y 2 -Brightness .79)
    ) }
    'sulk-cocoon' = @{ intervalMs=500; master='capeBurrito'; specs=@(
        (New-FrameSpec -X 2 -Angle 2 -Brightness .88),
        (New-FrameSpec -X 3 -Y 1 -Angle 4 -Brightness .86),
        (New-FrameSpec -X 1 -Angle 1 -Brightness .90),
        (New-FrameSpec -X -1 -Angle -1 -Brightness .92),
        (New-FrameSpec -X 2 -Angle 2 -Brightness .88)
    ) }
    'pancake-fall' = @{ intervalMs=260; master='pancake'; specs=@(
        (New-FrameSpec -Y -8 -ScaleX .94 -ScaleY 1.08),
        (New-FrameSpec -Y 5 -ScaleX 1.10 -ScaleY .90),
        (New-FrameSpec -Y 2 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -Y 4 -ScaleX 1.08 -ScaleY .92),
        (New-FrameSpec -Y 2 -ScaleX 1.03 -ScaleY .97)
    ) }
    'foot-slip' = @{ intervalMs=150; master='pancake'; specs=@(
        (New-FrameSpec -X -5 -Y -6 -Angle -6 -ScaleX .96 -ScaleY 1.04),
        (New-FrameSpec -X 5 -Y 1 -Angle 6 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -X -2 -Y 5 -Angle -3 -ScaleX 1.08 -ScaleY .92),
        (New-FrameSpec -X 2 -Y 3 -Angle 2 -ScaleX 1.05 -ScaleY .95),
        (New-FrameSpec -Y 2)
    ) }
    'belly-flop' = @{ intervalMs=210; master='pancake'; specs=@(
        (New-FrameSpec -Y -9 -ScaleX .93 -ScaleY 1.08),
        (New-FrameSpec -Y 7 -ScaleX 1.12 -ScaleY .88),
        (New-FrameSpec -Y 3 -ScaleX 1.07 -ScaleY .93),
        (New-FrameSpec -Y 5 -ScaleX 1.10 -ScaleY .90),
        (New-FrameSpec -Y 2 -ScaleX 1.04 -ScaleY .96)
    ) }
    'ice-spell' = @{ intervalMs=150; master='iceMagic'; specs=@(
        (New-FrameSpec -Y 2 -Angle -5 -ScaleX .98 -ScaleY 1.02 -Brightness .90),
        (New-FrameSpec -Y -5 -Angle 2 -ScaleX 1.01 -ScaleY 1.03 -Brightness 1.00),
        (New-FrameSpec -Y -8 -Angle 5 -ScaleX 1.04 -ScaleY 1.04 -Brightness 1.10),
        (New-FrameSpec -Y -4 -Angle -2 -ScaleX 1.02 -ScaleY 1.02 -Brightness 1.06),
        (New-FrameSpec -Y 0 -Angle 2 -Brightness 1.00),
        (New-FrameSpec -Y 2 -Angle -3 -Brightness .94)
    ) }
    'queen-decree' = @{ intervalMs=260; master='iceMagic'; specs=@(
        (New-FrameSpec -Y 1 -Angle -3 -Brightness .94),
        (New-FrameSpec -Y -3 -Angle 0 -ScaleX 1.02 -ScaleY 1.02),
        (New-FrameSpec -Y -5 -Angle 3 -ScaleX 1.04 -ScaleY 1.03 -Brightness 1.08),
        (New-FrameSpec -Y -3 -Angle 0 -ScaleX 1.02 -ScaleY 1.02),
        (New-FrameSpec -Y 1 -Angle -3 -Brightness .96)
    ) }
    'wand-backfire' = @{ intervalMs=130; master='iceMagic'; specs=@(
        (New-FrameSpec -X -3 -Y -3 -Angle -7 -Brightness 1.08),
        (New-FrameSpec -X 4 -Y -7 -Angle 8 -ScaleX .96 -ScaleY 1.05 -Brightness 1.16),
        (New-FrameSpec -X -5 -Y 1 -Angle -9 -ScaleX 1.05 -ScaleY .95 -Brightness .92),
        (New-FrameSpec -X 3 -Y -2 -Angle 6 -Brightness 1.08),
        (New-FrameSpec -X -1 -Y 2 -Angle -3 -Brightness .90)
    ) }
    'snack-struggle' = @{ intervalMs=190; master='snackStruggle'; specs=@(
        (New-FrameSpec -X -2 -Angle -3 -ScaleX .99 -ScaleY 1.01),
        (New-FrameSpec -X 2 -Y -2 -Angle 3 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X -3 -Y 1 -Angle -4 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 3 -Y -3 -Angle 4 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -X 0 -Angle 0)
    ) }
    'snack-cry' = @{ intervalMs=390; master='snackStruggle'; specs=@(
        (New-FrameSpec -Y 1 -Angle -2 -Brightness .91),
        (New-FrameSpec -Y 2 -Angle 2 -ScaleX 1.01 -ScaleY .99 -Brightness .88),
        (New-FrameSpec -Y 3 -Angle -2 -ScaleX .99 -ScaleY 1.01 -Brightness .86),
        (New-FrameSpec -Y 2 -Angle 1 -Brightness .90),
        (New-FrameSpec -Y 1 -Angle -1 -Brightness .92)
    ) }
    'bag-bite' = @{ intervalMs=145; master='snackStruggle'; specs=@(
        (New-FrameSpec -X -3 -Y 1 -Angle -5 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X 3 -Y -3 -Angle 5 -ScaleX .97 -ScaleY 1.04),
        (New-FrameSpec -X -2 -Y 2 -Angle -4 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -X 2 -Y -2 -Angle 4 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -Angle 0)
    ) }
    'crown-drop' = @{ intervalMs=170; master='crownChase'; specs=@(
        (New-FrameSpec -X -5 -Y 2 -Angle -4),
        (New-FrameSpec -X 0 -Y -4 -Angle 1 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X 5 -Y -6 -Angle 5 -ScaleX .96 -ScaleY 1.05),
        (New-FrameSpec -X 2 -Y 1 -Angle -2 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -X -1 -Angle 0)
    ) }
    'crown-chase' = @{ intervalMs=110; master='crownChase'; specs=@(
        (New-FrameSpec -X -7 -Y 2 -Angle -5 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X -2 -Y -4 -Angle -1 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X 4 -Y -7 -Angle 4 -ScaleX .96 -ScaleY 1.06),
        (New-FrameSpec -X 8 -Y -3 -Angle 7 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -X 3 -Y 1 -Angle 2 -ScaleX 1.04 -ScaleY .96),
        (New-FrameSpec -X -2 -Angle -2)
    ) }
    'snowball-play' = @{ intervalMs=180; master='snowball'; specs=@(
        (New-FrameSpec -X -3 -Y 2 -Angle -4 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X 0 -Y -5 -Angle 0 -ScaleX .98 -ScaleY 1.04),
        (New-FrameSpec -X 4 -Y -7 -Angle 5 -ScaleX .96 -ScaleY 1.06),
        (New-FrameSpec -X 1 -Y -3 -Angle 1 -ScaleX .99 -ScaleY 1.03),
        (New-FrameSpec -X -2 -Y 1 -Angle -3)
    ) }
    'snowball-slide' = @{ intervalMs=105; master='snowball'; specs=@(
        (New-FrameSpec -X -8 -Y 1 -Angle -6),
        (New-FrameSpec -X -3 -Y -4 -Angle -2 -ScaleX .98 -ScaleY 1.03),
        (New-FrameSpec -X 3 -Y -6 -Angle 3 -ScaleX .96 -ScaleY 1.05),
        (New-FrameSpec -X 8 -Y -2 -Angle 7 -ScaleX .98 -ScaleY 1.02),
        (New-FrameSpec -X 3 -Y 2 -Angle 3 -ScaleX 1.03 -ScaleY .97),
        (New-FrameSpec -X -2 -Angle -2)
    ) }
    'cheek-squish' = @{ intervalMs=180; master='cheekSquish'; specs=@(
        (New-FrameSpec -ScaleX 1.00 -ScaleY 1.00),
        (New-FrameSpec -Y 1 -ScaleX 1.07 -ScaleY .94),
        (New-FrameSpec -Y -2 -ScaleX .94 -ScaleY 1.05),
        (New-FrameSpec -Y 1 -ScaleX 1.08 -ScaleY .93),
        (New-FrameSpec -ScaleX 1.01 -ScaleY .99)
    ) }
    'cheek-boing' = @{ intervalMs=125; master='cheekSquish'; specs=@(
        (New-FrameSpec -X -5 -ScaleX 1.08 -ScaleY .94),
        (New-FrameSpec -X 5 -ScaleX .94 -ScaleY 1.05),
        (New-FrameSpec -X -3 -Angle -3 -ScaleX 1.06 -ScaleY .95),
        (New-FrameSpec -X 3 -Angle 3 -ScaleX .96 -ScaleY 1.03),
        (New-FrameSpec -ScaleX 1.01 -ScaleY .99)
    ) }
    'feast-guard' = @{ intervalMs=350; master='feastGuard'; specs=@(
        (New-FrameSpec -X -1 -Angle -2),
        (New-FrameSpec -X 1 -Y -1 -Angle 2 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -X -1 -Angle -1),
        (New-FrameSpec -X 1 -Y -1 -Angle 1 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Angle 0)
    ) }
    'midnight-feast' = @{ intervalMs=420; master='feastGuard'; specs=@(
        (New-FrameSpec -X -2 -Y 1 -Angle -2 -Brightness .74),
        (New-FrameSpec -X 1 -Y 0 -Angle 1 -Brightness .78),
        (New-FrameSpec -X 2 -Y -1 -Angle 2 -Brightness .82),
        (New-FrameSpec -X -1 -Y 0 -Angle -1 -Brightness .78),
        (New-FrameSpec -X -2 -Y 1 -Angle -2 -Brightness .74)
    ) }
    'last-bite' = @{ intervalMs=260; master='feastGuard'; specs=@(
        (New-FrameSpec -X -2 -Angle -3),
        (New-FrameSpec -X 2 -Y -2 -Angle 3 -ScaleX 1.02 -ScaleY .98),
        (New-FrameSpec -X -1 -Y 1 -Angle -1),
        (New-FrameSpec -X 1 -Y -1 -Angle 2 -ScaleX 1.01 -ScaleY .99),
        (New-FrameSpec -Angle 0)
    ) }
}

$manifest = [ordered]@{}
try {
    foreach ($animation in $animations.GetEnumerator()) {
        $state = [string]$animation.Key
        $definition = $animation.Value
        $stateDir = Join-Path $outputDir $state
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        $relativeFrames = [Collections.Generic.List[string]]::new()
        $index = 0

        foreach ($spec in $definition.specs) {
            $frame = [Drawing.Bitmap]::new(192, 208, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [Drawing.Graphics]::FromImage($frame)
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
                $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.TranslateTransform(96 + [single]$spec.X, 104 + [single]$spec.Y)
                $graphics.RotateTransform([single]$spec.Angle)
                $graphics.ScaleTransform([single]$spec.ScaleX, [single]$spec.ScaleY)
                $graphics.TranslateTransform(-96, -104)

                $attributes = [Drawing.Imaging.ImageAttributes]::new()
                try {
                    $brightness = [single]$spec.Brightness
                    $matrix = [Drawing.Imaging.ColorMatrix]::new()
                    $matrix.Matrix00 = $brightness
                    $matrix.Matrix11 = $brightness
                    $matrix.Matrix22 = $brightness
                    $matrix.Matrix33 = 1
                    $matrix.Matrix44 = 1
                    $attributes.SetColorMatrix($matrix)
                    $source = $masters[[string]$definition.master]
                    $destination = [Drawing.Rectangle]::new(0, 0, 192, 208)
                    $graphics.DrawImage($source, $destination, 0, 0, 192, 208, [Drawing.GraphicsUnit]::Pixel, $attributes)
                } finally {
                    $attributes.Dispose()
                }
            } finally {
                $graphics.Dispose()
            }

            $fileName = 'frame-{0:d2}.png' -f $index
            $framePath = Join-Path $stateDir $fileName
            $frame.Save($framePath, [Drawing.Imaging.ImageFormat]::Png)
            $frame.Dispose()
            $relativeFrames.Add("$state/$fileName")
            $index++
        }

        $manifest[$state] = [ordered]@{
            intervalMs = [int]$definition.intervalMs
            frames = @($relativeFrames)
        }
    }

    $json = $manifest | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($manifestPath, $json, [Text.UTF8Encoding]::new($false))
} finally {
    foreach ($master in $masters.Values) { $master.Dispose() }
}

$frameCount = ($manifest.Values | ForEach-Object { @($_.frames).Count } | Measure-Object -Sum).Sum
Write-Output "XUEWANG_ASSETS_OK states=$($manifest.Count) frames=$frameCount size=192x208 rgba=True"
