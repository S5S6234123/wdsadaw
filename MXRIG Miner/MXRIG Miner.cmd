@echo off
set "MXRIG_SELF=%~f0"
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:MXRIG_SELF); $m='# MXRIG-'+'POWERSHELL-PAYLOAD'; $i=$t.IndexOf($m); if($i -lt 0){throw 'Embedded PowerShell section not found'}; . ([scriptblock]::Create($t.Substring($i + $m.Length)))" >> "%~dp0MXRIG Miner.log" 2>&1
set "MXRIG_RC=%ERRORLEVEL%"
set "MXRIG_SELF="
exit /b %MXRIG_RC%
# MXRIG-POWERSHELL-PAYLOAD

# MXRIG Miner: double-clickable updater + launcher for the official XMRig release.
# The CMD header starts this embedded PowerShell section with a process-only policy override.
# The hidden launcher checks for updates and starts mining when hardware is ready.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'xmrig/xmrig'
$runtimeRoot = Join-Path (Split-Path -Parent $env:MXRIG_SELF) '.mxrig-runtime'
$cudaPluginRepo = 'xmrig/xmrig-cuda'

$runtimePrefix = [System.IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
$runningMiner = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='xmrig.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)
})
if ($runningMiner.Count -gt 0) {
    Write-Host 'MXRIG Miner is already running. See MXRIG Miner.log.'
    exit 0
}
$wallet = '4ANT4hVxsJfHXLobKkq882UCpS2vNrnsCT7LdWyDKeoEgDpnWWxsJhgQL9tWszKV2bJKFxSGJLGXQMcLZK4TLniv5bfN1xs'

Write-Host 'MXRIG Miner: checking the official XMRig GitHub release...' -ForegroundColor Cyan
Write-Host "Pool: xmrpool.eu:3333 (TLS) | Wallet: $($wallet.Substring(0,8))...$($wallet.Substring($wallet.Length - 6))"
Write-Host 'Miner runs hidden. Read MXRIG Miner.log for status; double-click Stop MXRIG Miner.vbs to stop it.'

try {
    if ($wallet.Length -ne 95 -or $wallet -notmatch '^[1-9A-HJ-NP-Za-km-z]+$') {
        throw 'The configured Monero address is invalid. It must be a 95-character Base58 receive address from your wallet.'
    }

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'MXRIG-Miner-Updater' }
    if (-not $release.tag_name -or $release.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') {
        throw 'GitHub returned an unexpected release tag.'
    }
    $version = $Matches[1]
    $archiveName = "xmrig-$version-windows-x64.zip"
    $checksumName = 'SHA256SUMS'
    $archiveAsset = $release.assets | Where-Object name -eq $archiveName | Select-Object -First 1
    $checksumAsset = $release.assets | Where-Object name -eq $checksumName | Select-Object -First 1
    if (-not $archiveAsset -or -not $checksumAsset) {
        throw "The official release is missing $archiveName or $checksumName."
    }

    $versionDir = Join-Path $runtimeRoot $version
    $miner = Join-Path $versionDir 'xmrig.exe'
    if (-not (Test-Path -LiteralPath $miner -PathType Leaf)) {
        New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
        $stageDir = Join-Path $runtimeRoot ('.download-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageDir | Out-Null
        try {
            $archivePath = Join-Path $stageDir $archiveName
            $checksumsPath = Join-Path $stageDir $checksumName
            Invoke-WebRequest -Uri $archiveAsset.browser_download_url -OutFile $archivePath
            Invoke-WebRequest -Uri $checksumAsset.browser_download_url -OutFile $checksumsPath

            $expectedLine = Get-Content -LiteralPath $checksumsPath | Where-Object { $_ -match "\s\*?$([Regex]::Escape($archiveName))$" } | Select-Object -First 1
            if (-not $expectedLine -or $expectedLine -notmatch '^([A-Fa-f0-9]{64})\s+\*?') {
                throw 'Could not find a valid published SHA-256 checksum for the Windows archive.'
            }
            $expectedHash = $Matches[1].ToLowerInvariant()
            $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualHash -ne $expectedHash) {
                throw "XMRig archive checksum mismatch. Expected $expectedHash, got $actualHash."
            }

            $extractDir = Join-Path $stageDir 'extract'
            Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir
            $downloadedMiner = Get-ChildItem -LiteralPath $extractDir -Filter 'xmrig.exe' -File -Recurse | Select-Object -First 1
            if (-not $downloadedMiner) { throw 'The verified archive did not contain xmrig.exe.' }
            New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
            Copy-Item -LiteralPath $downloadedMiner.FullName -Destination $miner
        }
        finally {
            Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Installed verified XMRig $version under .mxrig-runtime."
    }
    else {
        Write-Host "XMRig $version is already up to date."
    }

    $useCuda = $false
    $cudaDll = Join-Path $versionDir 'xmrig-cuda.dll'
    $nvidiaAdapters = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA' })
    if ($nvidiaAdapters.Count -gt 0) {
        Write-Host "NVIDIA GPU detected: $($nvidiaAdapters[0].Name)" -ForegroundColor Cyan
        Write-Host 'Preparing the official XMRig CUDA plugin...' -ForegroundColor Cyan
        $cudaRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$cudaPluginRepo/releases/latest" -Headers @{ 'User-Agent' = 'MXRIG-Miner-Updater' }
        if (-not $cudaRelease.tag_name -or $cudaRelease.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') {
            throw 'GitHub returned an unexpected CUDA plugin release tag.'
        }
        $cudaVersion = $Matches[1]
        $cudaArchiveName = "xmrig-cuda-$cudaVersion-cuda12_9-win64.zip"
        $cudaArchiveAsset = $cudaRelease.assets | Where-Object name -eq $cudaArchiveName | Select-Object -First 1
        $cudaChecksumsAsset = $cudaRelease.assets | Where-Object name -eq 'SHA256SUMS' | Select-Object -First 1
        if (-not $cudaArchiveAsset -or -not $cudaChecksumsAsset) {
            throw 'The official CUDA release is missing the CUDA 12.9 Windows archive or SHA256SUMS.'
        }

        $cudaStamp = Join-Path $versionDir '.cuda-verified.txt'
        $cudaVerified = $false
        if ((Test-Path -LiteralPath $cudaDll -PathType Leaf) -and (Test-Path -LiteralPath $cudaStamp -PathType Leaf)) {
            $stampLines = @(Get-Content -LiteralPath $cudaStamp)
            if ($stampLines.Count -ge 3 -and $stampLines[0] -eq $cudaArchiveName) {
                $installedCudaHash = (Get-FileHash -LiteralPath $cudaDll -Algorithm SHA256).Hash.ToLowerInvariant()
                $cudaVerified = ($installedCudaHash -eq $stampLines[2])
            }
        }
        if (-not $cudaVerified) {
            $pluginStage = Join-Path $runtimeRoot ('.cuda-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $pluginStage -Force | Out-Null
            try {
                $cudaArchivePath = Join-Path $pluginStage $cudaArchiveName
                $cudaChecksumsPath = Join-Path $pluginStage 'SHA256SUMS'
                Invoke-WebRequest -Uri $cudaArchiveAsset.browser_download_url -OutFile $cudaArchivePath
                Invoke-WebRequest -Uri $cudaChecksumsAsset.browser_download_url -OutFile $cudaChecksumsPath
                $cudaExpectedLine = Get-Content -LiteralPath $cudaChecksumsPath | Where-Object { $_ -match "\s\*?$([Regex]::Escape($cudaArchiveName))$" } | Select-Object -First 1
                if (-not $cudaExpectedLine -or $cudaExpectedLine -notmatch '^([A-Fa-f0-9]{64})\s+\*?') {
                    throw 'Could not find a valid published SHA-256 checksum for the CUDA plugin archive.'
                }
                $cudaExpectedHash = $Matches[1].ToLowerInvariant()
                $cudaActualHash = (Get-FileHash -LiteralPath $cudaArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($cudaActualHash -ne $cudaExpectedHash) {
                    throw 'The CUDA plugin archive checksum did not match the official release checksum.'
                }
                $cudaExtractDir = Join-Path $pluginStage 'extract'
                Expand-Archive -LiteralPath $cudaArchivePath -DestinationPath $cudaExtractDir
                $downloadedCudaDll = Get-ChildItem -LiteralPath $cudaExtractDir -Filter 'xmrig-cuda.dll' -File -Recurse | Select-Object -First 1
                if (-not $downloadedCudaDll) { throw 'The verified CUDA archive did not contain xmrig-cuda.dll.' }
                Get-ChildItem -LiteralPath $cudaExtractDir -File -Recurse | Copy-Item -Destination $versionDir -Force
                $installedCudaHash = (Get-FileHash -LiteralPath $cudaDll -Algorithm SHA256).Hash.ToLowerInvariant()
                Set-Content -LiteralPath $cudaStamp -Value @($cudaArchiveName, $cudaExpectedHash, $installedCudaHash) -Encoding ASCII
            }
            finally {
                Remove-Item -LiteralPath $pluginStage -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $useCuda = $true
    }
    else {
        Write-Host 'No NVIDIA GPU detected. CUDA is skipped; CPU mining will start.' -ForegroundColor Yellow
    }

    $xmrigArgs = @('--coin', 'monero', '-o', 'xmrpool.eu:3333', '--tls', '-u', $wallet, '-p', 'x', '--rig-id=home_pc', '--keepalive', '--randomx-wrmsr=-1', '--print-time=60')
    if ($useCuda) {
        $xmrigArgs += @('--cuda', "--cuda-loader=$cudaDll")
        Write-Host 'Starting CPU + NVIDIA GPU mining. Review both backend hashrates and temperatures.' -ForegroundColor Yellow
    }
    else {
        Write-Host 'Starting CPU mining. Review the miner output and temperatures.' -ForegroundColor Yellow
    }
    Push-Location -LiteralPath $versionDir
    try {
        & $miner @xmrigArgs
    }
    finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) { throw "XMRig exited with code $LASTEXITCODE." }
}
catch {
    Write-Error $_
    exit 1
}
