# Install-AMDDriver (Türkçe)

Bu depo, AMD Adrenalin “MinimalSetup” sürücüsünü en güncel sürümden dinamik olarak indirip sessiz kurulum yapan PowerShell betiğini içerir.

## Hızlı Başlangıç

Aşağıdaki tek satırlık komutu PowerShell penceresinde çalıştırdığınızda betik indirilecek ve kurulum başlayacaktır:

```
Set-ExecutionPolicy -Scope Process Bypass -Force; $u='https://raw.githubusercontent.com/byGOG/Install-AMDDriver/main/Install-AMDDriver.ps1'; $f="$env:TEMP\Install-AMDDriver.ps1"; iwr $u -OutFile $f; Unblock-File $f; & $f
```

- Bu komut, betiği geçici klasöre indirir ve çalıştırır.
- Betik, AMD’nin “rn-rad-win-latest” sayfasındaki en güncel “minimalsetup” web yükleyicisini bulur, indirir ve imza doğrulaması yapar.
- Ardından sessiz kurulum başlatılır. Gerekirse kurulum aşamasında yönetici (UAC) yükseltmesi yapılır.

## Betik Dosyası

- `Install-AMDDriver.ps1`:1 — Ana betik. Dinamik sürüm tespiti, indirme, imza doğrulama ve sessiz kurulum adımlarını yürütür.

## Kullanım (Gelişmiş)

- En güncel sürümü indirip sessiz kurulum:
  - `powershell -ExecutionPolicy Bypass -File .\Install-AMDDriver.ps1`
- Sadece indirmek (kurulum yok), klasör belirtmek:
  - `./Install-AMDDriver.ps1 -DownloadOnly -DownloadDirectory C:\AMD\Pkg`
- Belirli bir URL ile çalıştırmak (ör. belirli sürüm):
  - `./Install-AMDDriver.ps1 -Url 'https://drivers.amd.com/drivers/installer/25.10/whql/amd-software-adrenalin-edition-25.9.1-minimalsetup-250901_web.exe'`
- Sessiz kurulum parametrelerini değiştirmek:
  - `./Install-AMDDriver.ps1 -SilentArgs '/INSTALL /QUIET /NORESTART'`
- İmza doğrulaması başarısızsa ve bilerek devam etmek isterseniz:
  - `./Install-AMDDriver.ps1 -Force`

## Nasıl Çalışır

- “rn-rad-win-latest” sürüm notu sayfasından “minimalsetup” web yükleyici bağlantısı çıkarılır.
- Dosya indirildikten sonra “MZ” (EXE) kontrolü ve Authenticode imzası doğrulanır.
- Varsayılan sessiz argümanlar `-install -quiet -norestart` kullanılır; başarısız olursa yaygın alternatifler denenir.

## Gereksinimler

- Windows 10/11
- PowerShell 5.1 veya 7+ (önerilir)
- İnternet bağlantısı
- Kurulum için yönetici yetkisi (betik UAC yükseltmesi isteyebilir)

## İpuçları

- Konsolda Türkçe karakter sorunu yaşarsanız: `chcp 65001` komutunu çalıştırın veya PowerShell 7 kullanın.
- AMD web sayfa yapısı değişirse dinamik tespit başarısız olabilir; bu durumda `-Url` parametresiyle doğrudan indirme bağlantısı verin.

