Set-StrictMode -Version Latest

function Find-AgentKitRoot {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Start)

  $current = [IO.Path]::GetFullPath($Start)
  while ($true) {
    if ((Test-Path -LiteralPath (Join-Path $current 'AGENTS.md') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $current '.agents\config.json') -PathType Leaf)) {
      return $current
    }
    $parent = Split-Path -Parent $current
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { throw 'AKE900 proje kökü bulunamadı' }
    $current = $parent
  }
}

# Hook girisleri icin kok kesfi. Once Git koku denenir ve orada iskele
# varsa o secilir; yoksa Find-AgentKitRoot ile yukari isaretci aranir.
# ak_discover_root (lib.sh) ile PARITE.
function Resolve-AgentKitDiscoveredRoot {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Start)

  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    # Windows PowerShell 5.1'de Stop tercihiyle yerel komutun stderr'i
    # sonlandirici hataya donusur; Git deposu disinda git hep stderr yazar.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $candidate = $null
    try {
      Push-Location -LiteralPath $Start
      try { $candidate = [string](& $git.Source rev-parse --show-toplevel 2>$null) } finally { Pop-Location }
      if ($LASTEXITCODE -ne 0) { $candidate = $null }
    } catch { $candidate = $null } finally { $ErrorActionPreference = $previousPreference }
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath (Join-Path $candidate '.agents\config.json') -PathType Leaf)) {
      return [IO.Path]::GetFullPath($candidate)
    }
  }
  return Find-AgentKitRoot -Start $Start
}

function Read-AgentKitJson {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "AKE901 JSON dosyası eksik: $Path" }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AgentKitActiveWork {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Root)

  $activeRoot = Join-Path $Root '.agents\changes\active'
  if (-not (Test-Path -LiteralPath $activeRoot -PathType Container)) { return @() }
  $activeStatuses = @('draft', 'ready', 'in_progress', 'blocked', 'review')
  $records = @()
  foreach ($directory in Get-ChildItem -LiteralPath $activeRoot -Directory -Force | Sort-Object Name) {
    $workPath = Join-Path $directory.FullName 'work.json'
    if (-not (Test-Path -LiteralPath $workPath -PathType Leaf)) { continue }
    $work = Read-AgentKitJson -Path $workPath
    if ($activeStatuses -contains [string]$work.status) {
      $records += [pscustomobject]@{ Id = [string]$work.id; Path = $workPath; Work = $work }
    }
  }
  return @($records)
}

function Resolve-AgentKitWork {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$Branch,
    [string]$ExplicitId
  )

  # Cozum sirasi: acik work-id -> isaretci dosyasi -> branch -> tek aktif is.
  # ak_resolve_work (lib.sh) ile birebir ayni. Source ve StalePointer
  # alanlari cagirana cozumun nereden geldigini bildirir.
  $active = @(Get-AgentKitActiveWork -Root $Root)
  $stale = ''
  if (-not [string]::IsNullOrEmpty($ExplicitId)) {
    $matches = @($active | Where-Object { $_.Id -eq $ExplicitId })
    if ($matches.Count -eq 1) { return [pscustomobject]@{ Code = 0; Id = $ExplicitId; Candidates = @($ExplicitId); Source = 'explicit'; StalePointer = '' } }
    return [pscustomobject]@{ Code = 1; Id = $null; Candidates = @($active.Id); Source = 'none'; StalePointer = '' }
  }
  $pointerFile = Join-Path $Root '.agents\runtime\current-work'
  if (Test-Path -LiteralPath $pointerFile -PathType Leaf) {
    $pointerId = (Get-Content -LiteralPath $pointerFile -Raw -Encoding UTF8).Trim()
    if (-not [string]::IsNullOrEmpty($pointerId)) {
      $pointerMatches = @($active | Where-Object { $_.Id -eq $pointerId })
      if ($pointerMatches.Count -eq 1) {
        return [pscustomobject]@{ Code = 0; Id = $pointerId; Candidates = @($pointerId); Source = 'pointer'; StalePointer = '' }
      }
      # Bayat isaretci: sessizce yanlis ise yazma, cagirana bildir.
      $stale = $pointerId
    }
  }
  if (-not [string]::IsNullOrEmpty($Branch)) {
    $matches = @($active | Where-Object { $_.Work.git -and [string]$_.Work.git.branch -eq $Branch })
    if ($matches.Count -eq 1) { return [pscustomobject]@{ Code = 0; Id = $matches[0].Id; Candidates = @($matches[0].Id); Source = 'branch'; StalePointer = $stale } }
    if ($matches.Count -gt 1) { return [pscustomobject]@{ Code = 2; Id = $null; Candidates = @($matches.Id); Source = 'none'; StalePointer = $stale } }
  }
  if ($active.Count -eq 1) { return [pscustomobject]@{ Code = 0; Id = $active[0].Id; Candidates = @($active[0].Id); Source = 'single'; StalePointer = $stale } }
  if ($active.Count -eq 0) { return [pscustomobject]@{ Code = 1; Id = $null; Candidates = @(); Source = 'none'; StalePointer = $stale } }
  return [pscustomobject]@{ Code = 2; Id = $null; Candidates = @($active.Id); Source = 'none'; StalePointer = $stale }
}

function Test-AgentKitOwnership {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$WorkId
  )

  $active = @(Get-AgentKitActiveWork -Root $Root)
  $selected = $active | Where-Object { $_.Id -eq $WorkId } | Select-Object -First 1
  if (-not $selected) { return @() }
  $conflicts = @()
  foreach ($other in $active | Where-Object { $_.Id -ne $WorkId }) {
    foreach ($kind in @('resources', 'ports', 'migrations')) {
      $left = @($selected.Work.ownership.$kind)
      $right = @($other.Work.ownership.$kind)
      foreach ($value in $left) {
        if ($right -contains $value) { $conflicts += [pscustomobject]@{ WorkId = $other.Id; Kind = $kind; Value = [string]$value } }
      }
    }
    foreach ($leftPath in @($selected.Work.ownership.paths)) {
      $leftPrefix = ([string]$leftPath) -replace '/\*\*$', ''
      foreach ($rightPath in @($other.Work.ownership.paths)) {
        $rightPrefix = ([string]$rightPath) -replace '/\*\*$', ''
        if ($leftPrefix -eq $rightPrefix -or $leftPrefix.StartsWith($rightPrefix + '/') -or $rightPrefix.StartsWith($leftPrefix + '/')) {
          $conflicts += [pscustomobject]@{ WorkId = $other.Id; Kind = 'paths'; Value = "$leftPath|$rightPath" }
        }
      }
    }
  }
  return @($conflicts)
}

# Markdown bolumunun ilk anlamli satiri; ak_md_section_first (lib.sh) ile
# parite. Bolum yoksa veya bossa $null.
function Get-AgentKitMarkdownSectionFirst {
  param([string[]]$Lines, [string]$Heading)
  $inside = $false
  foreach ($line in $Lines) {
    $line = $line -replace "`r$", ''
    if ($line -eq "## $Heading") { $inside = $true; continue }
    if (-not $inside) { continue }
    if ($line.StartsWith('## ')) { break }
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    return ($line -replace '^\s*[-*]\s+', '')
  }
  return $null
}

# Kabul kriterleri bolumundeki isaretlenmemis maddeler; ak_md_open_criteria ile parite.
function Get-AgentKitOpenCriteria {
  param([string[]]$Lines)
  $inside = $false
  $open = @()
  foreach ($line in $Lines) {
    $line = $line -replace "`r$", ''
    if ($line -eq '## Kabul kriterleri') { $inside = $true; continue }
    if (-not $inside) { continue }
    if ($line.StartsWith('## ')) { break }
    if ($line -match '^\s*[-*]\s+\[\s\]\s*') { $open += ($line -replace '^\s*[-*]\s+\[\s\]\s*', '') }
  }
  return $open
}

# Oturum basi "nerede kalmistik" ozeti. ak_work_summary (lib.sh) ile
# METIN PARITESI tasir; tahmin uretmez, eksik alan "kayıtlı değil" yazar.
function Get-AgentKitWorkSummary {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$WorkId
  )
  $missing = 'kayıtlı değil'
  $dir = Join-Path $Root ".agents\changes\active\$WorkId"
  $phase = $null
  $next = $null
  $statusPath = Join-Path $dir 'status.md'
  if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
    $statusLines = @(Get-Content -LiteralPath $statusPath -Encoding UTF8)
    $phase = Get-AgentKitMarkdownSectionFirst -Lines $statusLines -Heading 'Mevcut aşama'
    $next = Get-AgentKitMarkdownSectionFirst -Lines $statusLines -Heading 'Sıradaki en küçük güvenli adım'
  }
  $work = Read-AgentKitJson -Path (Join-Path $dir 'work.json')
  # updatedAt ham metinden okunur: PowerShell 7 ConvertFrom-Json ISO
  # tarihini DateTime'a cevirip yerel bicimde basar ve sh ile ayrisir.
  $updated = $null
  $workRaw = Get-Content -LiteralPath (Join-Path $dir 'work.json') -Raw -Encoding UTF8
  if ($workRaw -match '"updatedAt"\s*:\s*"([^"]*)"') { $updated = $Matches[1] }
  $spec = $null
  if ($work.PSObject.Properties.Name -contains 'artifacts' -and $null -ne $work.artifacts -and $work.artifacts.PSObject.Properties.Name -contains 'spec') { $spec = [string]$work.artifacts.spec }
  if (-not [string]::IsNullOrEmpty($spec) -and ($spec.StartsWith('/') -or $spec.Contains('..') -or $spec.Contains('\') -or $spec -match '^[A-Za-z]:')) { $spec = $null }
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add('Özet:')
  $lines.Add('- Aşama: ' + $(if ([string]::IsNullOrEmpty($phase)) { $missing } else { $phase }))
  $lines.Add('- Son checkpoint: ' + $(if ([string]::IsNullOrEmpty($updated)) { $missing } else { $updated }))
  $lines.Add('- Sıradaki adım: ' + $(if ([string]::IsNullOrEmpty($next)) { $missing } else { $next }))
  $specPath = $null
  if (-not [string]::IsNullOrEmpty($spec)) { $specPath = Join-Path $Root ($spec -replace '/', '\') }
  if ($null -ne $specPath -and (Test-Path -LiteralPath $specPath -PathType Leaf)) {
    $open = @(Get-AgentKitOpenCriteria -Lines @(Get-Content -LiteralPath $specPath -Encoding UTF8) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $lines.Add('- Açık kabul ölçütü: ' + $open.Count)
    foreach ($item in @($open | Select-Object -First 5)) { $lines.Add('  - ' + $item) }
    if ($open.Count -gt 5) { $lines.Add('  - (+' + ($open.Count - 5) + ' daha)') }
  } else {
    $lines.Add('- Açık kabul ölçütü: spec kayıtlı değil')
  }
  return ($lines -join "`n")
}

function New-AgentKitDiagnostic {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [Parameter(Mandatory = $true)][ValidateSet('error', 'warning', 'info', 'skip')][string]$Severity,
    [Parameter(Mandatory = $true)][bool]$Blocking,
    [Parameter(Mandatory = $true)][string]$Message,
    [AllowNull()][string]$Path,
    [AllowNull()][string]$Remediation
  )
  return [pscustomobject]@{ code = $Code; severity = $Severity; blocking = $Blocking; message = $Message; path = $Path; remediation = $Remediation }
}

function Limit-AgentKitContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$MaxChars
  )
  $info = New-Object System.Globalization.StringInfo($Text)
  if ($info.LengthInTextElements -le $MaxChars) { return $Text }
  return $info.SubstringByTextElements(0, $MaxChars)
}

# Salt okunur kabuk komutu siniflandirmasi. ak_readonly_command (lib.sh)
# ile birebir ayni davranir; parite testi readonly-command.sh icinde.
# Fail-closed: taninmayan her komut mutasyondur.
#
# Boru hatti yalniz HER parcasi salt okunursa salt okunurdur. Satir sonu
# ikinci bir komut demektir; parantez PowerShell'de alt ifade calistirir
# (echo (Remove-Item x) silmeyi calistirir).
function Test-AgentKitReadOnlyCommand {
  [CmdletBinding()]
  param([AllowEmptyString()][AllowNull()][string]$Command)
  if ([string]::IsNullOrWhiteSpace($Command)) { return $false }
  foreach ($mark in '>', '<', '||', '&', ';', '`', '$(', '${', '(', "`n", "`r") {
    if ($Command.Contains($mark)) { return $false }
  }
  foreach ($segment in $Command.Split('|')) {
    if (-not (Test-AgentKitReadOnlySegment -Segment $segment)) { return $false }
  }
  return $true
}

# Tek bir boru parcasi. Bayrak kontrolu tirnak ve ters bolu silinmis metin
# uzerinde yapilir: kabuk '-ex''ec' yazimini -exec olarak calistirir.
# ak_readonly_segment (lib.sh) ile parite.
function Test-AgentKitReadOnlySegment {
  [CmdletBinding()]
  param([AllowEmptyString()][AllowNull()][string]$Segment)
  if ([string]::IsNullOrWhiteSpace($Segment)) { return $false }
  $plain = $Segment -replace "['`"\\]", ''
  $parts = $Segment.Trim() -split '\s+'
  $verb = $parts[0]
  if (@('ls', 'cat', 'head', 'tail', 'wc', 'pwd', 'echo', 'grep', 'jq') -contains $verb) { return $true }
  if ($verb -eq 'rg') {
    # --pre her dosya icin keyfi bir komut calistirir.
    return (-not $plain.Contains('--pre'))
  }
  if ($verb -eq 'find') {
    foreach ($flag in '-exec', '-ok', '-delete', '-fprint', '-fls') {
      if ($plain.Contains($flag)) { return $false }
    }
    return $true
  }
  if ($verb -eq 'git' -and $parts.Count -ge 2) {
    # --output diff/log ciktisini dosyaya yazar.
    if ($plain.Contains('--output')) { return $false }
    return (@('status', 'log', 'diff', 'show', 'rev-parse') -contains $parts[1])
  }
  return $false
}

# Salt okunur MCP araci siniflandirmasi. ak_readonly_mcp_tool (lib.sh) ile
# birebir ayni davranir; parite testi readonly-command.sh icinde. Karar
# yalniz mcp__<sunucu>__<eylem> adindaki eylemin fiilinden verilir.
# Fail-closed: taninmayan her MCP araci mutasyondur.
function Test-AgentKitReadOnlyMcpTool {
  [CmdletBinding()]
  param([AllowEmptyString()][AllowNull()][string]$Tool)
  if ([string]::IsNullOrEmpty($Tool) -or $Tool -cnotmatch '^mcp__.+__.+$') { return $false }
  $action = $Tool.Substring($Tool.LastIndexOf('__') + 2)
  if ($action -cmatch '_and_|_or_') { return $false }
  return ($action -cmatch '^(get|list|read|search)(_.+|[A-Z].*)?$')
}

# --- Claude hook kaynagi ---------------------------------------------------
#
# AKW401 "hook yok" demeden once hook'un gelebilecegi her kaynak taranir.
# Kit 1.2.0 ile hook'lar plugin paketiyle geliyor: goc edilmis bir projede
# .claude\settings.json bos kalir ama mekanik koruma calisir. Yalniz proje
# dosyasina bakmak o projelerin hepsinde yanlis uyari uretir.
# Kaynak listesi ve sirasi sh tarafiyla birebir ayni olmalidir.

function Read-AgentKitOptionalJson {
  [CmdletBinding()]
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  try { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

# Bos nesne yapilandirma degildir: "hooks": {} hicbir hook yuklemez.
function Test-AgentKitSettingsHooks {
  [CmdletBinding()]
  param([string]$Path)

  $settings = Read-AgentKitOptionalJson -Path $Path
  if ($null -eq $settings) { return $false }
  if (-not ($settings.PSObject.Properties.Name -contains 'hooks')) { return $false }
  if ($null -eq $settings.hooks) { return $false }
  return @($settings.hooks.PSObject.Properties).Count -gt 0
}

function Get-AgentKitClaudeConfigDir {
  [CmdletBinding()]
  param()

  if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) { return $env:CLAUDE_CONFIG_DIR }
  $userHome = if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $env:USERPROFILE } elseif (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $env:HOME } else { $null }
  if ($null -eq $userHome) { return $null }
  return (Join-Path $userHome '.claude')
}

function Get-AgentKitClaudeHookSource {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Root)

  $projectSettings = Join-Path $Root '.claude\settings.json'
  $projectLocal = Join-Path $Root '.claude\settings.local.json'
  if (Test-AgentKitSettingsHooks -Path $projectSettings) { return 'project' }
  if (Test-AgentKitSettingsHooks -Path $projectLocal) { return 'project-local' }

  $configDir = Get-AgentKitClaudeConfigDir
  if ($null -eq $configDir) { return $null }
  $userSettings = Join-Path $configDir 'settings.json'
  if (Test-AgentKitSettingsHooks -Path $userSettings) { return 'user' }

  $installed = Read-AgentKitOptionalJson -Path (Join-Path $configDir 'plugins\installed_plugins.json')
  if ($null -eq $installed) { return $null }
  if (-not ($installed.PSObject.Properties.Name -contains 'plugins')) { return $null }
  if ($null -eq $installed.plugins) { return $null }

  # Etkinlik kontrolu atlanamaz: kurulu ama kapali bir plugin hic hook
  # yuklemez, sessiz kalmak korumayi oldugundan genis gosterir.
  # Dosyalar ARTAN oncelik sirasinda okunur ve ayni anahtar icin son dosya
  # kazanir; Claude Code ayar onceligi de boyle calisir. Birlesim almak
  # yanlis olurdu: kullanici acmis ama proje kapatmissa hook yuklenmez.
  $merged = @{}
  foreach ($settingsPath in @($userSettings, $projectSettings, $projectLocal)) {
    $settings = Read-AgentKitOptionalJson -Path $settingsPath
    if ($null -eq $settings) { continue }
    if (-not ($settings.PSObject.Properties.Name -contains 'enabledPlugins')) { continue }
    if ($null -eq $settings.enabledPlugins) { continue }
    foreach ($entry in $settings.enabledPlugins.PSObject.Properties) {
      $merged[$entry.Name] = $entry.Value
    }
  }
  $enabled = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($key in $merged.Keys) {
    if ($merged[$key] -is [bool] -and $merged[$key]) { [void]$enabled.Add($key) }
  }
  if ($enabled.Count -eq 0) { return $null }

  foreach ($plugin in $installed.plugins.PSObject.Properties) {
    if (-not $enabled.Contains($plugin.Name)) { continue }
    foreach ($record in @($plugin.Value)) {
      if ($null -eq $record) { continue }
      if (-not ($record.PSObject.Properties.Name -contains 'installPath')) { continue }
      $package = [string]$record.installPath
      if ([string]::IsNullOrWhiteSpace($package)) { continue }
      if (Test-Path -LiteralPath (Join-Path $package 'hooks\hooks.json') -PathType Leaf) { return 'plugin' }
    }
  }
  return $null
}

# --- Codex hook kaynagi ----------------------------------------------------
#
# Claude tarafiyla ayni hata sinifi. Codex'in kayit yeri JSON degil TOML'dur
# ve kurulu plugin listesi tutan bir dosya yoktur; tek otorite
# <CODEX_HOME>\config.toml dosyasidir. Kaynak listesi ve sirasi sh tarafiyla
# birebir ayni olmalidir.

function Get-AgentKitCodexHome {
  [CmdletBinding()]
  param()

  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { return $env:CODEX_HOME }
  $userHome = if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $env:USERPROFILE } elseif (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $env:HOME } else { $null }
  if ($null -eq $userHome) { return $null }
  return (Join-Path $userHome '.codex')
}

# [plugins."ad@market"] bloklarindan enabled = true olanlarin anahtarlari.
# Alt bolum ([plugins."ad@market".policy]) kasitla eslesmez; oradaki enabled
# baska seyi anlatir.
function Get-AgentKitCodexEnabledPlugins {
  [CmdletBinding()]
  param([string]$Path)

  $keys = New-Object 'System.Collections.Generic.List[string]'
  if ([string]::IsNullOrWhiteSpace($Path)) { return $keys }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $keys }
  $current = ''
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    if ($line -match '^\s*\[') {
      $current = ''
      if ($line -match '^\s*\[plugins\."([^"]+)"\]\s*$') { $current = $Matches[1] }
      continue
    }
    if ($current -ne '' -and $line -match '^\s*enabled\s*=\s*true\s*(#.*)?$') { [void]$keys.Add($current) }
  }
  return $keys
}

function Get-AgentKitCodexHookSource {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Root)

  if (Test-Path -LiteralPath (Join-Path $Root '.codex\hooks.json') -PathType Leaf) { return 'project' }

  $codexHome = Get-AgentKitCodexHome
  if ($null -eq $codexHome) { return $null }
  if (Test-Path -LiteralPath (Join-Path $codexHome 'hooks.json') -PathType Leaf) { return 'user' }

  $configPath = Join-Path $codexHome 'config.toml'
  $keys = @(Get-AgentKitCodexEnabledPlugins -Path $configPath)
  if ($keys.Count -eq 0) { return $null }
  $configText = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8

  foreach ($key in $keys) {
    # Codex hook'u kaydedip kullanici guvendiyse bu blogu yazar; kayit paket
    # yerlesiminden bagimsiz ve guven duzeyinde bir kanittir.
    if ($configText.Contains('[hooks.state."' + $key + ':')) { return 'plugin-trusted' }
    $at = $key.IndexOf('@')
    if ($at -lt 1) { continue }
    $name = $key.Substring(0, $at)
    $marketplace = $key.Substring($at + 1)
    $cache = Join-Path (Join-Path (Join-Path $codexHome 'plugins') 'cache') (Join-Path $marketplace $name)
    if (-not (Test-Path -LiteralPath $cache -PathType Container)) { continue }
    foreach ($package in (Get-ChildItem -LiteralPath $cache -Directory -ErrorAction SilentlyContinue)) {
      if (Test-Path -LiteralPath (Join-Path $package.FullName 'hooks\hooks.json') -PathType Leaf) { return 'plugin' }
    }
  }
  return $null
}

Export-ModuleMember -Function @(
  'Find-AgentKitRoot',
  'Resolve-AgentKitDiscoveredRoot',
  'Read-AgentKitJson',
  'Resolve-AgentKitWork',
  'Test-AgentKitOwnership',
  'New-AgentKitDiagnostic',
  'Limit-AgentKitContext',
  'Get-AgentKitWorkSummary',
  'Test-AgentKitReadOnlyCommand',
  'Test-AgentKitReadOnlyMcpTool',
  'Get-AgentKitClaudeHookSource',
  'Get-AgentKitCodexHookSource'
)
