param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$version = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw "VERSION 格式无效：$version" }

$requiredFiles = @(
    '雪王现代桌宠.ps1',
    '启动动态雪王.vbs',
    'design-tokens.json',
    'README.md',
    'VERSION',
    'NOTICE.txt'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $relativePath))) { throw "缺少运行文件：$relativePath" }
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'assets-hq\manifest.json'))) { throw '缺少动画清单' }

$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$safeVersion = $version -replace '[^0-9A-Za-z.-]', '-'
$packageBase = "SnowCourt-XueWangPet-$safeVersion-$stamp"
$archivePath = Join-Path $resolvedOutput "$packageBase.zip"
$checksumPath = "$archivePath.sha256.txt"
$stagingRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(), "xuewang-release-$([Guid]::NewGuid().ToString('N'))")

try {
    [IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    foreach ($relativePath in $requiredFiles) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $relativePath) -Destination (Join-Path $stagingRoot $relativePath)
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'assets-hq') -Destination (Join-Path $stagingRoot 'assets-hq') -Recurse

    $runtimeFiles = @(Get-ChildItem -LiteralPath $stagingRoot -Recurse -File)
    if ($runtimeFiles.Count -lt 270) { throw "发布包文件数量异常：$($runtimeFiles.Count)" }
    if ($runtimeFiles.Name -contains 'state.json' -or $runtimeFiles.Name -contains 'build-snowking-assets.ps1') { throw '发布包混入用户状态或开发文件' }

    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal
    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($checksumPath, "$hash  $([IO.Path]::GetFileName($archivePath))`r`n", [Text.UTF8Encoding]::new($false))

    [pscustomobject]@{
        Version = $version
        Archive = $archivePath
        Checksum = $checksumPath
        RuntimeFiles = $runtimeFiles.Count
        UncompressedMB = [Math]::Round((($runtimeFiles | Measure-Object Length -Sum).Sum / 1MB), 2)
        ArchiveMB = [Math]::Round(((Get-Item -LiteralPath $archivePath).Length / 1MB), 2)
    }
} finally {
    $resolvedStage = [IO.Path]::GetFullPath($stagingRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedStage.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedStage)) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
