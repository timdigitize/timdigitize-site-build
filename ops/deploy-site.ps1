# timdigitize.com - otomatik yayin (sunucu tarafi)
# GitHub'daki timdigitize-site-build deposunun son halini indirir ve IIS site kokune senkronlar.
# Calistiran: zamanlanmis gorev "Timsan-SiteDeploy" (SYSTEM, 5 dakikada bir). Elle: powershell -File deploy-site.ps1 [-Force] [-DryRun]
param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo      = 'timdigitize/timdigitize-site-build'
$Branch    = 'main'
$SiteRoot  = 'C:\inetpub\wwwroot\timdigitize-site'
$Ops       = 'C:\ProgramData\TimsanOps\site-deploy'
$StateFile = Join-Path $Ops 'current-sha.txt'
$LogFile   = Join-Path $Ops 'deploy.log'
$BackupDir = Join-Path $Ops 'backup'
$HealthUrl = 'https://timdigitize.com/tr/'
# Sunucuya ozel, depoda olmayan dosyalar: asla silinmez / ustune yazilmaz
$KeepDirs  = @('App_Data', '.well-known')
$KeepFiles = @('capi.ashx')

New-Item -ItemType Directory -Force -Path $Ops, $BackupDir | Out-Null

function Log($msg) {
    $line = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    $headers = @{ 'User-Agent' = 'timsan-site-deploy'; 'Accept' = 'application/vnd.github+json' }
    $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/commits/$Branch" -Headers $headers -TimeoutSec 30
    $sha = $commit.sha
    $current = if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } else { '' }

    if (-not $Force -and $sha -eq $current) {
        # Degisiklik yok; sessizce cik (log sisirmemek icin yazmiyoruz)
        exit 0
    }
    Log "Yeni surum: $sha (mevcut: $(if ($current) { $current } else { 'yok' }))"

    # Betik kendini gunceller (bir sonraki calismada devreye girer)
    try {
        $selfUrl = "https://raw.githubusercontent.com/$Repo/$Branch/ops/deploy-site.ps1"
        $latest = (Invoke-WebRequest -Uri $selfUrl -UseBasicParsing -Headers $headers -TimeoutSec 30).Content
        $mine = Get-Content $PSCommandPath -Raw
        if ($latest -and $latest.Length -gt 1000 -and $latest.Trim() -ne $mine.Trim()) {
            [IO.File]::WriteAllText($PSCommandPath, $latest, (New-Object Text.UTF8Encoding $false))
            Log 'deploy-site.ps1 guncellendi (yeni surum bir sonraki calismada gecerli)'
        }
    } catch { Log "Betik guncelleme atlandi: $($_.Exception.Message)" }

    # Calisma klasoru: sha + zaman damgasi (ayni surum icin es zamanli iki calisma cakismasin)
    Get-ChildItem $Ops -Directory -Filter 'work-*' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-2) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $work = Join-Path $Ops ('work-' + $sha.Substring(0, 7) + '-' + (Get-Date -Format 'HHmmss') + '-' + $PID)
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $zip = Join-Path $work 'site.zip'

    Invoke-WebRequest -Uri "https://codeload.github.com/$Repo/zip/refs/heads/$Branch" -OutFile $zip -Headers @{ 'User-Agent' = 'timsan-site-deploy' } -TimeoutSec 300
    Expand-Archive -Path $zip -DestinationPath $work -Force
    $src = Get-ChildItem -Path $work -Directory | Where-Object { $_.Name -like 'timdigitize-site-build-*' } | Select-Object -First 1
    if (-not $src) { throw 'Zip icinde site klasoru bulunamadi' }
    $srcPath = $src.FullName

    # Guvenlik kontrolleri: bos veya yarim derleme yayinlanmasin
    foreach ($must in @('index.html', 'web.config', 'tr\index.html', 'sitemap.xml', 'VERSION.txt')) {
        if (-not (Test-Path (Join-Path $srcPath $must))) { throw "Eksik dosya: $must - yayin iptal" }
    }
    $pageCount = (Get-ChildItem -Path $srcPath -Recurse -Filter index.html).Count
    if ($pageCount -lt 300) { throw "Sayfa sayisi supheli dusuk ($pageCount) - yayin iptal" }
    # Depo icindeki ops/ ve README sunucuya kopyalanmaz
    Remove-Item (Join-Path $srcPath 'ops') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $srcPath 'README.md') -Force -ErrorAction SilentlyContinue

    # Mevcut canlinin yedegi (son 5 yedek tutulur)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $BackupDir $stamp
    if (-not $DryRun) {
        robocopy $SiteRoot $backup /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        Get-ChildItem $BackupDir -Directory | Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Senkron: robocopy /MIR (kaynakta olmayani siler), sunucuya ozel dosyalar haric
    $rcArgs = @($srcPath, $SiteRoot, '/MIR', '/R:2', '/W:2', '/NFL', '/NDL', '/NJH', '/NP', '/XD') + $KeepDirs + @('/XF') + $KeepFiles
    if ($DryRun) { $rcArgs += '/L' }
    $out = & robocopy @rcArgs
    $rc = $LASTEXITCODE
    Log ("robocopy cikis kodu {0}{1}" -f $rc, $(if ($DryRun) { ' (DryRun)' } else { '' }))
    if ($rc -ge 8) { throw "robocopy hatasi ($rc)" }

    if ($DryRun) { Log 'DryRun bitti, degisiklik yapilmadi'; exit 0 }

    # Saglik kontrolu; basarisizsa yedege don
    Start-Sleep -Seconds 3
    try {
        $resp = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 30 -Headers @{ 'Cache-Control' = 'no-cache' }
        if ($resp.StatusCode -ne 200 -or $resp.Content.Length -lt 5000) { throw "Beklenmeyen yanit: $($resp.StatusCode) / $($resp.Content.Length) bayt" }
        Log "Saglik kontrolu OK ($($resp.StatusCode), $($resp.Content.Length) bayt)"
    } catch {
        Log "SAGLIK KONTROLU BASARISIZ: $($_.Exception.Message) - yedege donuluyor"
        robocopy $backup $SiteRoot /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD $KeepDirs /XF $KeepFiles | Out-Null
        throw 'Geri alindi'
    }

    Set-Content -Path $StateFile -Value $sha -Encoding ASCII
    $ver = Get-Content (Join-Path $srcPath 'VERSION.txt') -Raw
    Log ("YAYINLANDI {0} | {1}" -f $sha.Substring(0, 7), ($ver -replace "`r?`n", ' '))
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}
catch {
    Log "HATA: $($_.Exception.Message)"
    exit 1
}
