[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$TestRoot = Join-Path $ProjectRoot '.agents\tests'
$Results = Join-Path $TestRoot 'results\windows.tsv'
New-Item -ItemType Directory -Path (Split-Path -Parent $Results) -Force | Out-Null
Set-Content -LiteralPath $Results -Value "id`tstatus`tobserved`tevidence" -Encoding utf8

Import-Module (Join-Path $TestRoot 'lib\RunCase.psm1') -Force
$cases = Get-Content -LiteralPath (Join-Path $TestRoot 'scenarios\cases.tsv') -Encoding UTF8 | Select-Object -Skip 1
$rows = New-Object 'System.Collections.Generic.List[object]'

# Dogrulayici artik kullanici Claude ve Codex yapilandirmasina da bakiyor. Sonuc
# gelistiricinin makinesinde plugin kurulu olup olmamasina gore degismesin
# diye butun paket yalitilmis ve bos bir yapilandirma dizini ile kosar.
$IsolatedConfigDir = Join-Path $ProjectRoot (Join-Path '.agents' (Join-Path 'runtime' ('test-home-' + [guid]::NewGuid().ToString('N').Substring(0, 8))))
New-Item -ItemType Directory -Path $IsolatedConfigDir -Force | Out-Null
$env:CLAUDE_CONFIG_DIR = $IsolatedConfigDir
$env:CODEX_HOME = $IsolatedConfigDir

$powerShellFiles = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })
$missingBom = @($powerShellFiles | Where-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  $bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF
})
if ($missingBom.Count -eq 0) {
  $rows.Add([pscustomobject]@{ Id = 'static:windows-bom'; Status = 'PASS'; Observed = 'PASS'; Evidence = 'all-powershell-sources-utf8-bom' })
} else {
  $rows.Add([pscustomobject]@{ Id = 'static:windows-bom'; Status = 'FAIL'; Observed = 'E_POWERSHELL_UTF8_BOM'; Evidence = ($missingBom.FullName -join ',') })
}

$validator = Join-Path $ProjectRoot '.agents\validators\ps\agent-kit.ps1'
$doctorRoot = Join-Path $TestRoot 'fixtures\validator\solo-one-active\repo'
try {
  $codexDoctor = (& $validator doctor -Root $doctorRoot -Client codex -Format json | Out-String) | ConvertFrom-Json
  $claudeDoctor = (& $validator doctor -Root $doctorRoot -Client claude -Format json | Out-String) | ConvertFrom-Json
  $claudeHasCodexDiagnostics = @($claudeDoctor.diagnostics | Where-Object { $_.code -eq 'AKW110' -or $_.path -eq '.codex/hooks.json' }).Count -gt 0
  $claudeHookWarning = @($claudeDoctor.diagnostics | Where-Object { $_.code -eq 'AKW401' -and $_.path -eq '.claude/settings.json' }).Count -gt 0
  if ($codexDoctor.client -eq 'codex' -and $claudeDoctor.client -eq 'claude' -and -not $claudeHasCodexDiagnostics -and $claudeHookWarning -and $null -eq $claudeDoctor.codexDocLimit) {
    $rows.Add([pscustomobject]@{ Id = 'static:client-doctor'; Status = 'PASS'; Observed = 'PASS'; Evidence = 'provider-specific-diagnostics' })
  } else {
    $rows.Add([pscustomobject]@{ Id = 'static:client-doctor'; Status = 'FAIL'; Observed = 'E_CLIENT_DIAGNOSTICS'; Evidence = 'codex-claude-diagnostics-mixed' })
  }
} catch {
  $rows.Add([pscustomobject]@{ Id = 'static:client-doctor'; Status = 'FAIL'; Observed = 'E_CLIENT_DIAGNOSTICS'; Evidence = $_.Exception.GetType().Name })
}

# CLAUDE HOOK KAYNAGI PARITESI.
#
# sh tarafindaki .agents/tests/static/claude-hook-source.sh ile ayni matris.
# AKW401 yalniz proje ayarina bakarsa plugin ile goc edilmis her projede
# yanlis uyari uretir; iki dogrulayici da ayni kaynak listesini taramali.
$hookTmp = Join-Path $ProjectRoot ('.agents\runtime\hook-source-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
  $hookRepo = Join-Path $hookTmp 'repo'
  New-Item -ItemType Directory -Path $hookTmp -Force | Out-Null
  Copy-Item -LiteralPath $doctorRoot -Destination $hookRepo -Recurse
  $hookPackage = Join-Path $hookTmp 'paket'
  New-Item -ItemType Directory -Path (Join-Path $hookPackage 'hooks') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $hookPackage 'hooks\hooks.json') -Value '{"hooks":{"SessionStart":[]}}' -Encoding utf8
  $hookLessPackage = Join-Path $hookTmp 'paket-hooksuz'
  New-Item -ItemType Directory -Path $hookLessPackage -Force | Out-Null

  $newHome = {
    param($Path, $Enabled, $InstallPath)
    New-Item -ItemType Directory -Path (Join-Path $Path 'plugins') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $Path 'settings.json') -Value ('{"enabledPlugins":{"agents-kit@agents-kit":' + $Enabled + '}}') -Encoding utf8
    $record = [pscustomobject]@{ version = 2; plugins = [pscustomobject]@{ 'agents-kit@agents-kit' = @([pscustomobject]@{ scope = 'user'; installPath = $InstallPath; version = '1.2.0' }) } }
    Set-Content -LiteralPath (Join-Path $Path 'plugins\installed_plugins.json') -Value ($record | ConvertTo-Json -Depth 6) -Encoding utf8
  }

  $warns = {
    param($ConfigDir)
    $env:CLAUDE_CONFIG_DIR = $ConfigDir
    $report = (& $validator doctor -Root $hookRepo -Client claude -Format json | Out-String) | ConvertFrom-Json
    return (@($report.diagnostics | Where-Object { $_.code -eq 'AKW401' -and $_.path -eq '.claude/settings.json' }).Count -gt 0)
  }

  $hookFailures = New-Object 'System.Collections.Generic.List[string]'

  $emptyHome = Join-Path $hookTmp 'home-bos'
  New-Item -ItemType Directory -Path $emptyHome -Force | Out-Null
  if (-not (& $warns $emptyHome)) { $hookFailures.Add('kaynak-yok') }

  $pluginHome = Join-Path $hookTmp 'home-plugin'
  & $newHome $pluginHome 'true' $hookPackage
  if (& $warns $pluginHome) { $hookFailures.Add('etkin-plugin') }

  $disabledHome = Join-Path $hookTmp 'home-kapali'
  & $newHome $disabledHome 'false' $hookPackage
  if (-not (& $warns $disabledHome)) { $hookFailures.Add('kapali-plugin') }

  $hookLessHome = Join-Path $hookTmp 'home-hooksuz'
  & $newHome $hookLessHome 'true' $hookLessPackage
  if (-not (& $warns $hookLessHome)) { $hookFailures.Add('hooksuz-paket') }

  $userHome = Join-Path $hookTmp 'home-kullanici'
  New-Item -ItemType Directory -Path $userHome -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $userHome 'settings.json') -Value '{"hooks":{"SessionStart":[]}}' -Encoding utf8
  if (& $warns $userHome) { $hookFailures.Add('kullanici-ayari') }

  New-Item -ItemType Directory -Path (Join-Path $hookRepo '.claude') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"hooks":{"SessionStart":[]}}' -Encoding utf8
  if (& $warns $emptyHome) { $hookFailures.Add('proje-ayari') }

  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"hooks":{}}' -Encoding utf8
  if (-not (& $warns $emptyHome)) { $hookFailures.Add('bos-hooks-nesnesi') }

  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.local.json') -Value '{"hooks":{"Stop":[]}}' -Encoding utf8
  if (& $warns $emptyHome) { $hookFailures.Add('proje-yerel-ayari') }
  Remove-Item -LiteralPath (Join-Path $hookRepo '.claude\settings.local.json') -Force

  $projectHome = Join-Path $hookTmp 'home-proje'
  New-Item -ItemType Directory -Path (Join-Path $projectHome 'plugins') -Force | Out-Null
  $projectRecord = [pscustomobject]@{ version = 2; plugins = [pscustomobject]@{ 'agents-kit@agents-kit' = @([pscustomobject]@{ installPath = $hookPackage }) } }
  Set-Content -LiteralPath (Join-Path $projectHome 'plugins\installed_plugins.json') -Value ($projectRecord | ConvertTo-Json -Depth 6) -Encoding utf8
  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"hooks":{},"enabledPlugins":{"agents-kit@agents-kit":true}}' -Encoding utf8
  if (& $warns $projectHome) { $hookFailures.Add('projede-etkinlestirilen-plugin') }

  # Claude Code ayar onceligi: proje yerel > proje > kullanici. Kullanici
  # acmis ama proje kapatmissa o projede hook yuklenmez; birlesim almak
  # kapali plugini calisiyor gosterirdi.
  $precHome = Join-Path $hookTmp 'home-oncelik'
  & $newHome $precHome 'true' $hookPackage
  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"enabledPlugins":{"agents-kit@agents-kit":false}}' -Encoding utf8
  if (-not (& $warns $precHome)) { $hookFailures.Add('proje-kapatmasi-ezmeli') }

  $precHomeOff = Join-Path $hookTmp 'home-ters'
  & $newHome $precHomeOff 'false' $hookPackage
  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"enabledPlugins":{"agents-kit@agents-kit":true}}' -Encoding utf8
  if (& $warns $precHomeOff) { $hookFailures.Add('proje-acmasi-ezmeli') }

  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.json') -Value '{"enabledPlugins":{"agents-kit@agents-kit":true}}' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $hookRepo '.claude\settings.local.json') -Value '{"enabledPlugins":{"agents-kit@agents-kit":false}}' -Encoding utf8
  if (-not (& $warns $precHome)) { $hookFailures.Add('proje-yerel-en-ustte') }
  Remove-Item -LiteralPath (Join-Path $hookRepo '.claude\settings.local.json') -Force

  if ($hookFailures.Count -eq 0) {
    $rows.Add([pscustomobject]@{ Id = 'static:claude-hook-source'; Status = 'PASS'; Observed = 'PASS'; Evidence = 'project-local-user-plugin-sources' })
  } else {
    $rows.Add([pscustomobject]@{ Id = 'static:claude-hook-source'; Status = 'FAIL'; Observed = 'E_HOOK_SOURCE'; Evidence = ($hookFailures -join ',') })
  }
} catch {
  $rows.Add([pscustomobject]@{ Id = 'static:claude-hook-source'; Status = 'FAIL'; Observed = 'E_HOOK_SOURCE'; Evidence = $_.Exception.GetType().Name })
} finally {
  $env:CLAUDE_CONFIG_DIR = $IsolatedConfigDir
  $env:CODEX_HOME = $IsolatedConfigDir
  if (Test-Path -LiteralPath $hookTmp) { Remove-Item -LiteralPath $hookTmp -Recurse -Force }
}

# CODEX HOOK KAYNAGI PARITESI.
#
# sh tarafindaki .agents/tests/static/codex-hook-source.sh ile ayni matris.
# Codex'in kayit yeri TOML'dur; iki kanit kabul edilir: plugin paketindeki
# hooks/hooks.json ve config.toml icindeki [hooks.state."<anahtar>:...] blogu.
# Ikisi de yalniz plugin blogu enabled = true ise sayilir.
$codexTmp = Join-Path $ProjectRoot ('.agents\runtime\codex-hook-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
  $codexRepo = Join-Path $codexTmp 'repo'
  New-Item -ItemType Directory -Path $codexTmp -Force | Out-Null
  Copy-Item -LiteralPath $doctorRoot -Destination $codexRepo -Recurse

  $newCodexHome = {
    param($Path, $Enabled, $Extra)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $lines = @(
      '[marketplaces.agents-kit]',
      'source_type = "git"',
      '',
      '[plugins."agents-kit@agents-kit"]',
      ('enabled = ' + $Enabled),
      ''
    )
    if (-not [string]::IsNullOrEmpty($Extra)) { $lines += $Extra }
    Set-Content -LiteralPath (Join-Path $Path 'config.toml') -Value ($lines -join "`n") -Encoding utf8
  }

  $newCodexPackage = {
    param($HomePath)
    $package = Join-Path $HomePath 'plugins\cache\agents-kit\agents-kit\1.2.0\hooks'
    New-Item -ItemType Directory -Path $package -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $package 'hooks.json') -Value '{"hooks":{"SessionStart":[]}}' -Encoding utf8
  }

  $codexWarns = {
    param($HomePath)
    $env:CODEX_HOME = $HomePath
    $report = (& $validator doctor -Root $codexRepo -Client codex -Format json | Out-String) | ConvertFrom-Json
    return (@($report.diagnostics | Where-Object { $_.code -eq 'AKW401' -and $_.path -eq '.codex/hooks.json' }).Count -gt 0)
  }

  $codexFailures = New-Object 'System.Collections.Generic.List[string]'

  $codexEmpty = Join-Path $codexTmp 'home-bos'
  New-Item -ItemType Directory -Path $codexEmpty -Force | Out-Null
  if (-not (& $codexWarns $codexEmpty)) { $codexFailures.Add('kaynak-yok') }

  $codexPluginHome = Join-Path $codexTmp 'home-plugin'
  & $newCodexHome $codexPluginHome 'true' ''
  & $newCodexPackage $codexPluginHome
  if (& $codexWarns $codexPluginHome) { $codexFailures.Add('etkin-plugin-paketi') }

  $codexDisabled = Join-Path $codexTmp 'home-kapali'
  & $newCodexHome $codexDisabled 'false' ''
  & $newCodexPackage $codexDisabled
  if (-not (& $codexWarns $codexDisabled)) { $codexFailures.Add('kapali-plugin') }

  $codexNoProof = Join-Path $codexTmp 'home-kanitsiz'
  & $newCodexHome $codexNoProof 'true' ''
  if (-not (& $codexWarns $codexNoProof)) { $codexFailures.Add('kanitsiz-etkin-plugin') }

  $codexState = Join-Path $codexTmp 'home-state'
  & $newCodexHome $codexState 'true' "[hooks.state.`"agents-kit@agents-kit:hooks/hooks.json:session_start:0:0`"]`ntrusted_hash = `"sha256:abc`"`n"
  if (& $codexWarns $codexState) { $codexFailures.Add('guvenilen-hook-kaydi') }

  $codexSub = Join-Path $codexTmp 'home-altbolum'
  New-Item -ItemType Directory -Path $codexSub -Force | Out-Null
  $subLines = @(
    '[plugins."agents-kit@agents-kit".policy]',
    'enabled = true',
    '',
    '[hooks.state."agents-kit@agents-kit:hooks/hooks.json:stop:0:0"]',
    'trusted_hash = "sha256:abc"'
  )
  Set-Content -LiteralPath (Join-Path $codexSub 'config.toml') -Value ($subLines -join "`n") -Encoding utf8
  if (-not (& $codexWarns $codexSub)) { $codexFailures.Add('alt-bolum-enabled') }

  $codexUser = Join-Path $codexTmp 'home-kullanici'
  New-Item -ItemType Directory -Path $codexUser -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $codexUser 'hooks.json') -Value '{"hooks":{}}' -Encoding utf8
  if (& $codexWarns $codexUser) { $codexFailures.Add('kullanici-hooks-json') }

  New-Item -ItemType Directory -Path (Join-Path $codexRepo '.codex') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $codexRepo '.codex\hooks.json') -Value '{"hooks":{}}' -Encoding utf8
  if (& $codexWarns $codexEmpty) { $codexFailures.Add('proje-hooks-json') }

  if ($codexFailures.Count -eq 0) {
    $rows.Add([pscustomobject]@{ Id = 'static:codex-hook-source'; Status = 'PASS'; Observed = 'PASS'; Evidence = 'project-user-plugin-trusted-sources' })
  } else {
    $rows.Add([pscustomobject]@{ Id = 'static:codex-hook-source'; Status = 'FAIL'; Observed = 'E_CODEX_HOOK_SOURCE'; Evidence = ($codexFailures -join ',') })
  }
} catch {
  $rows.Add([pscustomobject]@{ Id = 'static:codex-hook-source'; Status = 'FAIL'; Observed = 'E_CODEX_HOOK_SOURCE'; Evidence = $_.Exception.GetType().Name })
} finally {
  $env:CODEX_HOME = $IsolatedConfigDir
  if (Test-Path -LiteralPath $codexTmp) { Remove-Item -LiteralPath $codexTmp -Recurse -Force }
}

# MANIFEST KAPSAMI PARITESI.
#
# sh tarafindaki .agents/tests/static/manifest-scope.sh ile ayni senaryo:
# kullanicinin projesinde manifest --write uygulama kodunu ICERI ALMAMALI.
$scopeTmp = Join-Path $ProjectRoot (Join-Path '.agents' (Join-Path 'runtime' ('manifest-scope-' + [guid]::NewGuid().ToString('N').Substring(0, 8))))
try {
  $scopeProject = Join-Path $scopeTmp 'proje'
  New-Item -ItemType Directory -Path (Join-Path $scopeProject '.agents\runtime') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $scopeProject '.agents\playbooks') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $scopeProject '.claude') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $scopeProject 'src') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $doctorRoot '.agents\config.json') -Destination (Join-Path $scopeProject '.agents\config.json')
  Copy-Item -LiteralPath (Join-Path $ProjectRoot 'AGENTS.md') -Destination (Join-Path $scopeProject 'AGENTS.md')
  Copy-Item -LiteralPath (Join-Path $ProjectRoot 'CLAUDE.md') -Destination (Join-Path $scopeProject 'CLAUDE.md')
  Copy-Item -LiteralPath (Join-Path $ProjectRoot '.agents\playbooks\verification.md') -Destination (Join-Path $scopeProject '.agents\playbooks\verification.md')
  Set-Content -LiteralPath (Join-Path $scopeProject '.claude\settings.json') -Value '{"plansDirectory":".agents/runtime/claude-plans"}' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject 'src\uygulama.py') -Value 'print("merhaba")' -Encoding utf8
  # Kullanicinin KIT DIZINLERI ICINDE actigi kendi icerigi.
  New-Item -ItemType Directory -Path (Join-Path $scopeProject '.agents\ads') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $scopeProject '.agents\specs') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $scopeProject '.agents\ads\2026-09-06.md') -Value 'gunluk not' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject '.agents\specs\kendi-specim.md') -Value 'kendi specim' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject '.claude\launch.json') -Value '{}' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject '.claude\settings.local.json') -Value '{}' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject 'README.md') -Value '# Kullanicinin kendi README dosyasi' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $scopeProject 'LICENSE') -Value 'MIT' -Encoding utf8

  & $validator manifest -Root $scopeProject -ManifestMode write | Out-Null
  $scopeManifest = (Get-Content -LiteralPath (Join-Path $scopeProject '.agents\manifest.json') -Raw -Encoding UTF8) | ConvertFrom-Json
  $scopePaths = @($scopeManifest.files | ForEach-Object { $_.path })

  $scopeFailures = New-Object 'System.Collections.Generic.List[string]'
  foreach ($bad in @('src/uygulama.py', 'README.md', 'LICENSE', '.agents/ads/2026-09-06.md', '.agents/specs/kendi-specim.md', '.claude/launch.json', '.claude/settings.local.json')) {
    if ($scopePaths -contains $bad) { $scopeFailures.Add('girdi:' + $bad) }
  }
  foreach ($need in @('AGENTS.md', 'CLAUDE.md', '.agents/config.json', '.agents/playbooks/verification.md', '.claude/settings.json')) {
    if (-not ($scopePaths -contains $need)) { $scopeFailures.Add('eksik:' + $need) }
  }
  # Asil derdimiz: kullanici kodunu degistirince butunluk kontrolu dusmemeli.
  Set-Content -LiteralPath (Join-Path $scopeProject 'src\uygulama.py') -Value 'print("degisti")' -Encoding utf8
  $scopeCheck = (& $validator manifest -Root $scopeProject -ManifestMode check 2>&1 | Out-String)
  if ($scopeCheck -notmatch 'PASS manifest') { $scopeFailures.Add('kod-degisince-bozuldu') }

  if ($scopeFailures.Count -eq 0) {
    $rows.Add([pscustomobject]@{ Id = 'static:manifest-scope'; Status = 'PASS'; Observed = 'PASS'; Evidence = 'project-scope-excludes-app-files' })
  } else {
    $rows.Add([pscustomobject]@{ Id = 'static:manifest-scope'; Status = 'FAIL'; Observed = 'E_MANIFEST_SCOPE'; Evidence = ($scopeFailures -join ',') })
  }
} catch {
  $rows.Add([pscustomobject]@{ Id = 'static:manifest-scope'; Status = 'FAIL'; Observed = 'E_MANIFEST_SCOPE'; Evidence = $_.Exception.GetType().Name })
} finally {
  if (Test-Path -LiteralPath $scopeTmp) { Remove-Item -LiteralPath $scopeTmp -Recurse -Force }
}

foreach ($line in $cases) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $parts = $line -split "`t", 6
  if ($parts.Count -ne 6) {
    $rows.Add([pscustomobject]@{ Id = 'unknown'; Status = 'FAIL'; Observed = 'E_CASE_CATALOG'; Evidence = 'invalid-tsv-row' })
    continue
  }
  $fixtureDir = Join-Path $TestRoot ("fixtures\acceptance\" + $parts[2])
  try {
    $rows.Add((Invoke-AgentKitCase -ProjectRoot $ProjectRoot -Id $parts[0] -FixtureDir $fixtureDir -Class $parts[3] -Profile $parts[4] -Expected $parts[5]))
  } catch {
    $rows.Add([pscustomobject]@{ Id = $parts[0]; Status = 'FAIL'; Observed = 'E_CASE_EXCEPTION'; Evidence = $_.Exception.GetType().Name })
  }
}

if (Test-Path -LiteralPath $IsolatedConfigDir) { Remove-Item -LiteralPath $IsolatedConfigDir -Recurse -Force }

foreach ($row in $rows) {
  Add-Content -LiteralPath $Results -Value ("{0}`t{1}`t{2}`t{3}" -f $row.Id, $row.Status, $row.Observed, $row.Evidence) -Encoding utf8
}

$blocking = @($rows | Where-Object { $_.Status -in @('FAIL', 'BLOCKED') })
if ($blocking.Count -gt 0) {
  [Console]::Error.WriteLine("FAIL acceptance; ayrıntı: $Results")
  exit 2
}

$summary = $rows | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("PASS acceptance " + ($summary -join ' '))
exit 0
