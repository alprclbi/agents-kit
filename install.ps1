# Agents Kit kurulumu (Windows).
#
# Kullanim: kendi projenin KOKUNDE calistir.
#   git clone --depth 1 https://github.com/alprclbi/agents-kit $env:TEMP\ak
#   cd C:\senin\projen
#   & $env:TEMP\ak\install.ps1
#
# Hedef her zaman calisma dizinidir, kitin bulundugu yer degil.
# install.sh ile DAVRANIS PARITESI tasir; birini degistiren digerini de
# degistirir.
#
# Cikis kodlari:
#   0  kuruldu
#   2  hata (yanlis hedef, bozuk kaynak)
#   3  hicbir sey yazilmadi: cakisma, iptal, ya da kit zaten kurulu
[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'

$kit = Split-Path -Parent $PSCommandPath
$target = (Get-Location).Path
$manifestPath = Join-Path $kit '.agents\manifest.json'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  Write-Output "HATA: kit kaynagi eksik: $manifestPath"
  exit 2
}

# --- Hedef dogrulamasi -------------------------------------------------
# En sik hata: kullanici kendi projesine cd etmeyi unutur ve kiti ev
# dizinine ya da kit kaynaginin icine kurar. Ucu de reddedilir.
$kitFull = [IO.Path]::GetFullPath($kit).TrimEnd('\')
$targetFull = [IO.Path]::GetFullPath($target).TrimEnd('\')
if ($targetFull -eq $kitFull -or $targetFull.StartsWith($kitFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
  Write-Output 'HATA: kit kaynaginin icindesin.'
  Write-Output 'Once kendi projenin kokune cd et, sonra bu betigi calistir.'
  exit 2
}
$profileDir = [Environment]::GetFolderPath('UserProfile')
if ($profileDir -and $targetFull -eq [IO.Path]::GetFullPath($profileDir).TrimEnd('\')) {
  Write-Output 'HATA: hedef ev dizini olamaz. Kendi projenin kokune cd et.'
  exit 2
}
if ($targetFull -match '^[A-Za-z]:$') {
  Write-Output 'HATA: hedef surucu koku olamaz.'
  exit 2
}

$versionFile = Join-Path $kit '.agents\VERSION'
$version = 'bilinmiyor'
if (Test-Path -LiteralPath $versionFile) { $version = (Get-Content -LiteralPath $versionFile -Raw).Trim() }

if (Test-Path -LiteralPath (Join-Path $target '.agents\manifest.json')) {
  Write-Output 'Kit bu projede zaten kurulu.'
  Write-Output ''
  Write-Output "Guncelleme icin ajanina soyle:  update skill'ini calistir"
  Write-Output "Kaldirma icin:                  remove-kit skill'ini calistir"
  exit 3
}

# --- Kurulacak dosyalar ------------------------------------------------
# Liste manifestten uretilir, elle tutulmaz: kit buyudukce kurulum
# listesi kendiliginden guncel kalir.
#
# Kok belgeler (README, LICENSE, CONTRIBUTING, SECURITY, CHANGELOG,
# CODE_OF_CONDUCT) ve .github KURULMAZ: kitin kendi deposuna aittirler
# ve kullanicinin dosyalarini ezerlerdi. Kok .gitignore da kurulmaz;
# kullanicinin projesinde is kayitlari genelde takimla paylasilir.
# .agents/tests ve .agents/evals kitin KENDI gelistirme altyapisidir;
# kullanicinin deposunda is gormez. Plugin manifestleri de kuruluma
# girmez: onlar dagitim paketini anlatir, kullanicinin projesini degil.
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$payload = @($manifest.files | ForEach-Object { $_.path } | Where-Object {
  ($_ -like '.agents/*' -or $_ -like '.claude/*' -or $_ -like '.codex/*' -or
   $_ -like 'skills/*' -or
   $_ -eq 'AGENTS.md' -or $_ -eq 'CLAUDE.md' -or $_ -eq 'AGENT-KIT-START.md') -and
  $_ -notlike '.agents/tests/*' -and $_ -notlike '.agents/evals/*'
})
if ($payload.Count -eq 0) { Write-Output 'HATA: kurulacak dosya bulunamadi.'; exit 2 }

# Skill kaynagi kit deposunda skills/ altinda yasar; plugin paketlemesi
# orayi bekler. Kullanicinin projesinde ise .agents/skills/ altina gider:
# Codex'in repo duzeyindeki kanonik yolu orasi ve .claude/skills/
# adaptorleri de oraya isaret eder. Tek kaynak, iki hedef.
function Get-TargetPath {
  param([string]$Rel)
  if ($Rel -like 'skills/*') { return ".agents/$Rel" }
  return $Rel
}

$conflicts = New-Object System.Collections.Generic.List[string]
foreach ($rel in $payload) {
  $win = $rel -replace '/', '\'
  if (-not (Test-Path -LiteralPath (Join-Path $kit $win))) {
    Write-Output "HATA: kaynakta eksik dosya: $rel"
    exit 2
  }
  $dstWin = (Get-TargetPath $rel) -replace '/', '\'
  if (Test-Path -LiteralPath (Join-Path $target $dstWin)) { $conflicts.Add((Get-TargetPath $rel)) }
}

$client = 'tespit edilemedi'
if (Test-Path -LiteralPath (Join-Path $target '.claude')) { $client = 'Claude Code' }
elseif (Get-Command claude -ErrorAction SilentlyContinue) { $client = 'Claude Code' }
elseif (Test-Path -LiteralPath (Join-Path $target '.codex')) { $client = 'Codex' }
elseif (Get-Command codex -ErrorAction SilentlyContinue) { $client = 'Codex' }

Write-Output "Agents Kit $version"
Write-Output "Hedef   : $targetFull"
Write-Output "Istemci : $client"
Write-Output ''

if ($conflicts.Count -gt 0) {
  Write-Output "Cakisan dosyalar var; HICBIR SEY YAZILMADI ($($conflicts.Count) dosya):"
  Write-Output ''
  foreach ($c in $conflicts) { Write-Output "  $c" }
  Write-Output ''
  Write-Output 'Mevcut dosyalarini ezmek yerine ajanina soyle:'
  Write-Output ''
  Write-Output ("  Su dosyayi oku ve uygula: " + $kitFull + '\skills\init\SKILL.md')
  Write-Output "  Kit koku: $kitFull"
  Write-Output ''
  Write-Output 'init her hedefi siniflar ve exact diff onaylanmadan yazmaz.'
  Write-Output 'Kit kaynagini SILME; skill oradan okunuyor.'
  exit 3
}

Write-Output "Cakisma yok. $($payload.Count) dosya kopyalanacak."
if (-not $Yes) {
  $answer = Read-Host 'Devam edilsin mi? [e/H]'
  if ($answer -notmatch '^(e|E|evet|Evet|y|Y|yes)$') {
    Write-Output 'Iptal edildi, hicbir sey yazilmadi.'
    exit 3
  }
}

$copied = 0
$installedMap = @{}
foreach ($rel in $payload) {
  $win = $rel -replace '/', '\'
  $dst = Get-TargetPath $rel
  $dstWin = $dst -replace '/', '\'
  $dest = Join-Path $target $dstWin
  $destDir = Split-Path -Parent $dest
  if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
  }
  Copy-Item -LiteralPath (Join-Path $kit $win) -Destination $dest -Force
  $installedMap[$rel] = $dst
  $copied++
}
Write-Output ''
Write-Output "kopyalandi   : $copied dosya"

# --- Hedefteki manifesti kurulan dosyalara indir ------------------------
# Kaynak manifest kitin KENDI deposunu anlatir; kurmadigimiz dosyalari da
# listeler. Filtrelenmezse kullanicinin ilk manifest --check komutu
# "dosya eksik" der.
$targetManifestPath = Join-Path $target '.agents\manifest.json'
$keep = New-Object System.Collections.Generic.HashSet[string]
foreach ($rel in $payload) { [void]$keep.Add($rel) }
[void]$keep.Add('.agents/manifest.json')
$tm = Get-Content -LiteralPath $targetManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
# Yol yeniden eslemesi manifeste de yansir: skills/x kaynakta, hedefte
# .agents/skills/x. Yansitilmazsa ilk manifest --check "dosya eksik" der.
$tm.files = @($tm.files | Where-Object { $keep.Contains($_.path) } | ForEach-Object {
  if ($installedMap.ContainsKey($_.path)) { $_.path = $installedMap[$_.path] }
  $_
})
$json = ($tm | ConvertTo-Json -Depth 12) -replace "`r`n", "`n" -replace "`r", "`n"
[IO.File]::WriteAllText($targetManifestPath, $json + "`n", (New-Object Text.UTF8Encoding($false)))

# --- Kisisel tercih dosyasini tohumla ----------------------------------
# Uslup kurallari .agents/local/preferences.md icinde yasar ve o dosya
# git disinda oldugu icin KURULUMA GIRMEZ. Tohumlanmazsa yeni kurulumda
# hic uslup kurali olmaz; ajan uzun yazar ve kullanici sebebini bilmez.
# Var olan dosyaya dokunmuyoruz.
$prefsTarget = Join-Path $target '.agents\local\preferences.md'
$prefsExample = Join-Path $kit '.agents\preferences.example.md'
if (-not (Test-Path -LiteralPath $prefsTarget) -and (Test-Path -LiteralPath $prefsExample)) {
  $prefsDir = Split-Path -Parent $prefsTarget
  if (-not (Test-Path -LiteralPath $prefsDir)) { New-Item -ItemType Directory -Path $prefsDir -Force | Out-Null }
  Copy-Item -LiteralPath $prefsExample -Destination $prefsTarget -Force
  Write-Output 'tercihler    : .agents/local/preferences.md olusturuldu (uslup kurallari)'
}

# --- Satir sonu korumasi ------------------------------------------------
# Manifest hash'leri LF'e bagli. Hedef depoda .gitattributes yoksa git
# kit dosyalarini CRLF ile checkout edebilir ve dogrulama TAKIM
# ARKADASINDA duser. Var olan dosyaya dokunmuyoruz.
$ga = Join-Path $target '.gitattributes'
if (-not (Test-Path -LiteralPath $ga)) {
  $lines = @(
    '# Agents Kit dosyalari LF olmali: manifest dogrulamasi bayt',
    '# duzeyinde calisir, CRLF sizarsa klonlayanda duser.',
    '.agents/** text eol=lf',
    '.claude/** text eol=lf',
    '.codex/** text eol=lf',
    'AGENTS.md text eol=lf',
    'CLAUDE.md text eol=lf',
    'AGENT-KIT-START.md text eol=lf'
  )
  [IO.File]::WriteAllText($ga, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
  Write-Output 'gitattributes: olusturuldu (kit dosyalari icin LF)'
}

$validator = Join-Path $target '.agents\validators\ps\agent-kit.ps1'
if (Test-Path -LiteralPath $validator) {
  # NOT: cagrilan .ps1 basarida "exit" demiyor, bu yuzden $LASTEXITCODE
  # guncellenmiyor ve stale deger okunuyordu. Karari ciktidan veriyoruz.
  $manifestReport = (& $validator manifest -Root $targetFull -ManifestMode check 2>&1 | Out-String)
  if ($manifestReport -match 'PASS manifest') { Write-Output 'manifest     : butunluk dogrulandi' }
  else { Write-Output 'manifest     : DOGRULANAMADI' }
  $report = (& $validator doctor -Root $targetFull -Client codex -Format text 2>$null | Out-String)
  if ($report -match 'AKW401') { Write-Output 'hook         : etkin degil, mekanik koruma dusuk' }
  else { Write-Output 'hook         : yapilandirilmis' }
}

Write-Output ''
Write-Output 'Sonraki adim:'
if ($client -eq 'Codex') {
  Write-Output "  1. Codex ac, /hooks ile uc hook'u incele ve guven karari ver"
} else {
  Write-Output "  1. Ajani ac; kurallar ve hook'lar ilk oturumda devreye girer"
}
Write-Output '  2. .agents/project.md dosyasini doldur'
Write-Output ''
Write-Output 'Ayrinti: AGENT-KIT-START.md'

# Bu betik artik BIRINCIL yol degil. Plugin yolu klon, gecici dizin ve
# yol yapistirma istemez; ayrica araclari kendi kendine gunceller.
Write-Output ''
Write-Output 'NOT: Bu betik cevrimdisi ve CI kurulumu icindir.'
Write-Output 'Claude Code veya Codex kullaniyorsan plugin yolu daha kolay:'
Write-Output '  /plugin marketplace add alprclbi/agents-kit'
Write-Output '  /plugin install agents-kit@agents-kit'
Write-Output 'Codex: codex plugin marketplace add alprclbi/agents-kit'
exit 0
