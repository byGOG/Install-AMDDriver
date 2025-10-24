# Requires -RunAsAdministrator
param(
    [switch]$DownloadOnly,
    [string]$DownloadDirectory = $env:TEMP,
    [string]$SilentArgs = '-install -quiet -norestart',
    [string]$Url,
    [switch]$Force,              # skip signature check
    [int]$WebTimeoutSec = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

## Yönetici yükseltmesini yalnızca kurulum aşamasında yap

function Get-LatestAmdMinimalSetupUrl {
    param(
        [string]$RelNotesUrl = 'https://www.amd.com/en/support/kb/release-notes/rn-rad-win-latest'
    )
    Write-Info "Son sürüm notları alınıyor: $RelNotesUrl"
    $headers = @{ 'User-Agent'='Mozilla/5.0'; 'Accept-Language'='en-US,en;q=0.9' }
    $resp = Invoke-WebRequest -Uri $RelNotesUrl -UseBasicParsing -Headers $headers -TimeoutSec $WebTimeoutSec
    $link = $resp.Links | Where-Object { $_.href -like 'https://drivers.amd.com/drivers/installer/*minimalsetup*_*_web.exe' } | Select-Object -First 1
    if (-not $link) {
        # Fallback: search within raw HTML
        $pattern = 'https://drivers\.amd\.com/[\w/\.-]*minimalsetup[\w\.-]*_web\.exe'
        $m = [regex]::Match($resp.Content, $pattern)
        if ($m.Success) { return $m.Value }
        throw 'minimalsetup web yükleyici bağlantısı bulunamadı.'
    }
    return $link.href
}

function Test-FileIsExe([string]$Path){
    if(-not (Test-Path -LiteralPath $Path)) { return $false }
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $buf = New-Object byte[] 2
        $null = $fs.Read($buf,0,2)
        return ($buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)  # 'MZ'
    } finally { $fs.Dispose() }
}

function Download-AmdInstaller([string]$Url,[string]$OutDir){
    if(-not (Test-Path -LiteralPath $OutDir)){ New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $fileName = Split-Path $Url -Leaf
    $outPath  = Join-Path $OutDir $fileName
    $headers = @{ 'User-Agent'='Mozilla/5.0'; 'Referer'='https://www.amd.com/en/support' }
    Write-Info "İndiriliyor: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $outPath -Headers $headers -UseBasicParsing -TimeoutSec $WebTimeoutSec
    if(-not (Test-FileIsExe $outPath)){
        Remove-Item -LiteralPath $outPath -Force -ErrorAction SilentlyContinue | Out-Null
        throw 'İndirilen dosya yürütülebilir değil (MZ imzası yok). AMD bağlantısı yönlendirmiş olabilir.'
    }
    Write-Info ("İndirildi: {0} ({1:N0} bayt)" -f $outPath, (Get-Item $outPath).Length)
    return $outPath
}

function Assert-Signature([string]$Path){
    $sig = Get-AuthenticodeSignature -FilePath $Path
    if($sig.Status -ne 'Valid'){
        if($Force){ Write-Warn "İmza durumu: $($sig.Status). -Force ile devam ediliyor." }
        else { throw "Dijital imza geçerli değil: $($sig.Status)" }
    } else {
        Write-Info "İmza doğrulandı: $($sig.SignerCertificate.Subject)"
    }
}

function Start-SilentInstall([string]$Exe,[string]$Args){
    Write-Info "Sessiz kurulum başlatılıyor..."
    Write-Info "Komut: `"$Exe`" $Args"
    $p = Start-Process -FilePath $Exe -ArgumentList $Args -Verb RunAs -PassThru -Wait -WindowStyle Hidden
    Write-Info "Kurulum çıkış kodu: $($p.ExitCode)"
    return $p.ExitCode
}

try {
    $url = if([string]::IsNullOrWhiteSpace($Url)) { Get-LatestAmdMinimalSetupUrl } else { $Url }
    Write-Info "Bulunan sürüm: $url"

    $downloadPath = Download-AmdInstaller -Url $url -OutDir $DownloadDirectory
    Assert-Signature -Path $downloadPath

    if($DownloadOnly){
        Write-Info 'Yalnızca indirme istendi (-DownloadOnly). Kurulum yapılmadı.'
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Info 'Kurulum için yönetici ayrıcalıkları gerekiyor; tekrar başlatılıyor...'
        $psi = @{
            FilePath   = (Get-Process -Id $PID).Path
            ArgumentList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") + ( $PSBoundParameters.GetEnumerator() | ForEach-Object {
                if ($_.Key -and ($_.Value -is [switch])) { "-$($_.Key)" } elseif($_.Key){ "-$($_.Key)", "`"$($_.Value)`"" }
            } )
            Verb      = 'RunAs'
            WindowStyle = 'Hidden'
            Wait      = $true
        }
        Start-Process @psi
        exit $LASTEXITCODE
    }

    # En yaygın AMD kurulum seçenekleri. Kullanıcı gerekirse -SilentArgs ile geçersiz kılabilir.
    $exit = Start-SilentInstall -Exe $downloadPath -Args $SilentArgs
    if($exit -ne 0){
        Write-Warn "Çıkış kodu $exit. Alternatif sessiz parametreler deneniyor..."
        $fallbackArgs = @(
            '/INSTALL /QUIET /NORESTART',
            '/SILENT /NORESTART',
            '/S',
            '/VERYSILENT',
            '-install -silent -norestart'
        )
        foreach($fa in $fallbackArgs){
            Write-Info "Deneniyor: $fa"
            $exit = Start-SilentInstall -Exe $downloadPath -Args $fa
            if($exit -eq 0){ break }
        }
    }

    if($exit -eq 0){ Write-Host '[OK] AMD sürücü kuruldu.' -ForegroundColor Green }
    else { Write-Err "Kurulum tamamlanamadı. Çıkış kodu: $exit"; exit $exit }
}
catch {
    Write-Err $_
    exit 1
}
