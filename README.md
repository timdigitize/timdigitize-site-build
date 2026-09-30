# timdigitize-site-build

timdigitize.com'un **derlenmiş** hâli. Elle düzenlenmez; kaynak kod özel depodadır
(`timdigitize/timdigitize-website`). Her `main` push'unda GitHub Actions siteyi derleyip buraya yazar,
sunucudaki `Timsan-SiteDeploy` görevi 5 dakika içinde alıp yayınlar.

- `VERSION.txt` — hangi kaynak commit'inden, ne zaman derlendiği
- `ops/deploy-site.ps1` — sunucu tarafı yayın betiği
- `ops/install.ps1` — sunucuya tek seferlik kurulum

## Sunucu kurulumu (bir kez)

Yönetici PowerShell'de:

```powershell
iwr https://raw.githubusercontent.com/timdigitize/timdigitize-site-build/main/ops/install.ps1 -useb | iex
```

Ardından gerçek ilk yayın:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\TimsanOps\site-deploy\deploy-site.ps1 -Force
```

Günlük: `C:\ProgramData\TimsanOps\site-deploy\deploy.log`. Yedekler: `...\site-deploy\backup\` (son 5).
Geri almak için: yedek klasörünü `robocopy <yedek> C:\inetpub\wwwroot\timdigitize-site /MIR /XD App_Data /XF capi.ashx` ile geri kopyalayın
ve `current-sha.txt` dosyasını silin.

Sunucuya özel ve depoda olmayan dosyalar korunur: `capi.ashx`, `App_Data\`, `.well-known\`.
