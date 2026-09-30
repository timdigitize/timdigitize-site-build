# timdigitize.com - otomatik yayin kurulumu (bir kez, yonetici PowerShell ile)
# Kullanim (tek satir):
#   iwr https://raw.githubusercontent.com/timdigitize/timdigitize-site-build/main/ops/install.ps1 -useb | iex
# Ne yapar: deploy-site.ps1'i indirir, "Timsan-SiteDeploy" zamanlanmis gorevini (SYSTEM, 5 dk) kurar,
# ilk calistirmayi DryRun olarak yapar ve sonucu gosterir. Gercek ilk yayin icin: powershell -File deploy-site.ps1 -Force

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Ops = 'C:\ProgramData\TimsanOps\site-deploy'
$Script = Join-Path $Ops 'deploy-site.ps1'
$Raw = 'https://raw.githubusercontent.com/timdigitize/timdigitize-site-build/main/ops/deploy-site.ps1'

New-Item -ItemType Directory -Force -Path $Ops | Out-Null
Invoke-WebRequest -Uri $Raw -OutFile $Script -UseBasicParsing -Headers @{ 'User-Agent' = 'timsan-site-deploy' }
Write-Host "Indirildi: $Script"

$taskName = 'Timsan-SiteDeploy'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Script`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Zamanlanmis gorev kuruldu: $taskName (her 5 dk)"

Write-Host '--- Deneme calistirma (DryRun, degisiklik yapmaz) ---'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -Force -DryRun
Write-Host '--- Bitti. Gercek ilk yayin icin: ---'
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File `"$Script`" -Force"
Write-Host "Gunluk: $Ops\deploy.log"
