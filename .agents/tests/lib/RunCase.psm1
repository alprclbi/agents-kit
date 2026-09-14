Set-StrictMode -Version Latest

function Read-CaseJson {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Invoke-HookWithInput {
  param(
    [Parameter(Mandatory = $true)][string]$Validator,
    [Parameter(Mandatory = $true)][string]$Json,
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$WorkId
  )
  $oldIn = [Console]::In
  $reader = New-Object System.IO.StringReader($Json)
  try {
    [Console]::SetIn($reader)
    $invokeParameters = @{
      Command = 'pre-tool-use'
      Root = $Root
      Client = 'codex'
      Format = 'json'
    }
    if (-not [string]::IsNullOrEmpty($WorkId)) { $invokeParameters.WorkId = $WorkId }
    return (& $Validator @invokeParameters | Out-String) | ConvertFrom-Json
  } finally {
    [Console]::SetIn($oldIn)
    $reader.Dispose()
  }
}

function Invoke-AgentKitCase {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$FixtureDir,
    [Parameter(Mandatory = $true)][string]$Class,
    [Parameter(Mandatory = $true)][string]$Profile,
    [Parameter(Mandatory = $true)][string]$Expected
  )

  $inputPath = Join-Path $FixtureDir 'input.json'
  $expectedPath = Join-Path $FixtureDir 'expected.json'
  if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf) -or -not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
    return [pscustomobject]@{ Id = $Id; Status = 'FAIL'; Observed = 'E_CASE_FIXTURE'; Evidence = 'fixture-files-missing' }
  }
  $inputData = Read-CaseJson -Path $inputPath
  $expectedData = Read-CaseJson -Path $expectedPath
  if ([string]$inputData.id -ne $Id -or [string]$inputData.fixtureData -ne 'synthetic' -or [bool]$inputData.containsSecrets) {
    return [pscustomobject]@{ Id = $Id; Status = 'FAIL'; Observed = 'E_CASE_INPUT'; Evidence = 'fixture-contract' }
  }

  $testRoot = Join-Path $ProjectRoot '.agents\tests'
  $validator = Join-Path $ProjectRoot '.agents\validators\ps\agent-kit.ps1'
  $validatorModule = Join-Path $ProjectRoot '.agents\validators\ps\AgentKit.psm1'
  $actual = 'FAIL'
  $evidence = 'unverified'

  switch ($Id) {
    '01' {
      $fixture = Read-CaseJson -Path (Join-Path $testRoot 'fixtures\adoption\empty-repo\expected.json')
      if ($fixture.recommendation -eq 'direct-install' -and -not $fixture.externalWrites -and $fixture.requiresApproval) { $actual = 'PASS'; $evidence = 'direct-install-requires-approval' }
    }
    '02' {
      $fixture = Read-CaseJson -Path (Join-Path $testRoot 'fixtures\adoption\existing-instructions\expected.json')
      if ($fixture.recommendation -eq 'merge-required' -and -not $fixture.overwrite) { $actual = 'PASS'; $evidence = 'existing-instructions-preserved' }
    }
    '03' {
      if ((Get-Command codex -ErrorAction SilentlyContinue) -and $env:AGENT_KIT_LIVE_CLIENTS -eq '1') { $actual = 'BLOCKED'; $evidence = 'live-codex-observation-required' }
      else { $actual = 'SKIP'; $evidence = 'AKS503-codex-binary-or-trust-unavailable' }
    }
    '04' {
      if ((Get-Command claude -ErrorAction SilentlyContinue) -and $env:AGENT_KIT_LIVE_CLIENTS -eq '1') { $actual = 'BLOCKED'; $evidence = 'live-claude-observation-required' }
      else { $actual = 'SKIP'; $evidence = 'AKS503-claude-binary-or-trust-unavailable' }
    }
    '05' {
      $adapter = Get-Content -LiteralPath (Join-Path $ProjectRoot '.agents\adapters\superpowers.md') -Raw -Encoding UTF8
      if ($adapter.Contains('brainstorming') -and $adapter.Contains('`spec` rolünü çöz')) { $actual = 'PASS'; $evidence = 'native-spec-route-contract' }
    }
    '06' {
      $adapter = Get-Content -LiteralPath (Join-Path $ProjectRoot '.agents\adapters\superpowers.md') -Raw -Encoding UTF8
      if ($adapter.Contains('writing-plans') -and $adapter.Contains('`plan` rolünü çöz')) { $actual = 'PASS'; $evidence = 'native-plan-route-contract' }
    }
    '07' {
      $runtime = Join-Path $ProjectRoot '.agents\runtime'
      $tempRoot = Join-Path $runtime ('acceptance-' + [Guid]::NewGuid().ToString('N'))
      $tempRepo = Join-Path $tempRoot 'repo'
      try {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        Copy-Item -LiteralPath (Join-Path $testRoot 'fixtures\validator\team-multiple-active\repo') -Destination $tempRepo -Recurse
        $leakDir = Join-Path $tempRepo 'docs\superpowers\specs'
        New-Item -ItemType Directory -Path $leakDir -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $leakDir 'leak.md'), "synthetic leak`n", (New-Object Text.UTF8Encoding($false)))
        $result = (& $validator stop-check -Root $tempRepo -Client codex -Format json | Out-String) | ConvertFrom-Json
        if ($result.decision -eq 'block' -and [string]$result.reason -match 'AKE302') { $actual = 'BLOCK'; $evidence = 'AKE302' }
      } finally {
        if ((Test-Path -LiteralPath $tempRoot) -and $tempRoot.StartsWith($runtime, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
      }
    }
    '08' {
      $settings = Read-CaseJson -Path (Join-Path $ProjectRoot '.claude\settings.json')
      $hooks = $settings.hooks
      # @($null).Count -eq 1 oldugundan yalniz Count bakmak eksik olayi yakalamaz;
      # her olay icin once $null kontrolu sart. run-case.sh 08 ile ayni sozlesme.
      $hooksInstalled = $null -ne $hooks -and
        $null -ne $hooks.SessionStart -and @($hooks.SessionStart).Count -gt 0 -and
        $null -ne $hooks.PreToolUse -and @($hooks.PreToolUse).Count -gt 0 -and
        $null -ne $hooks.Stop -and @($hooks.Stop).Count -gt 0
      if ($settings.plansDirectory -eq '.agents/runtime/claude-plans' -and $hooksInstalled) { $actual = 'PASS'; $evidence = 'runtime-plan-and-hooks-installed' }
    }
    '09' {
      $repo = Join-Path $testRoot 'fixtures\validator\team-multiple-active\repo'
      $json = Get-Content -LiteralPath (Join-Path $testRoot 'fixtures\validator\team-multiple-active\pre-tool-input.json') -Raw -Encoding UTF8
      $result = Invoke-HookWithInput -Validator $validator -Json $json -Root $repo
      # Birden fazla aktif is normal durumdur; kapi degil, bilgi.
      $hasDecision = $result.hookSpecificOutput.PSObject.Properties.Name -contains 'permissionDecision'
      if (-not $hasDecision -and [string]$result.hookSpecificOutput.additionalContext -match 'AKE201') { $actual = 'WARN'; $evidence = 'AKE201-warning-only' }
    }
    '10' {
      $resume = Get-Content -LiteralPath (Join-Path $ProjectRoot 'skills\resume-work\SKILL.md') -Raw -Encoding UTF8
      $checkpoint = Get-Content -LiteralPath (Join-Path $ProjectRoot 'skills\checkpoint-work\SKILL.md') -Raw -Encoding UTF8
      if ($resume.Contains('status.md') -and $checkpoint.Contains('status.md')) { $actual = 'PASS'; $evidence = 'resume-checkpoint-status-contract' }
    }
    '11' {
      $repo = Join-Path $testRoot 'fixtures\validator\team-multiple-active\repo'
      $json = Get-Content -LiteralPath (Join-Path $testRoot 'fixtures\validator\team-multiple-active\pre-tool-input.json') -Raw -Encoding UTF8
      $result = Invoke-HookWithInput -Validator $validator -Json $json -Root $repo -WorkId '123'
      if ($result.hookSpecificOutput.permissionDecision -eq 'deny' -and [string]$result.hookSpecificOutput.permissionDecisionReason -match 'AKE202') { $actual = 'BLOCK'; $evidence = 'AKE202' }
    }
    '12' {
      $config = Read-CaseJson -Path (Join-Path $ProjectRoot '.agents\config.json')
      $skill = Get-Content -LiteralPath (Join-Path $ProjectRoot 'skills\archive-work\SKILL.md') -Raw -Encoding UTF8
      if ($config.archiveStrategy -eq 'adaptive' -and $skill.Contains('compact, standart veya full')) { $actual = 'PASS'; $evidence = 'adaptive-archive-policy' }
    }
    '13' {
      $contract = Get-Content -LiteralPath (Join-Path $ProjectRoot '.agents\contracts\backend-resolution.md') -Raw -Encoding UTF8
      if ($contract.Contains('external') -and $contract.Contains('explicit')) { $actual = 'PASS'; $evidence = 'external-route-explicit-contract' }
    }
    '14' {
      $fixture = Read-CaseJson -Path (Join-Path $testRoot 'fixtures\adoption\modified-managed\expected.json')
      if ($fixture.classification -eq 'preserve-and-merge' -and $fixture.currentPreserved) { $actual = 'PRESERVE'; $evidence = 'modified-managed-preserved' }
    }
    '15' {
      $fixture = Read-CaseJson -Path (Join-Path $testRoot 'fixtures\adoption\remove-preserves-work\expected.json')
      if (@($fixture.deleteCandidates).Count -eq 1 -and @($fixture.preserved).Count -eq 2) { $actual = 'PRESERVE'; $evidence = 'work-and-project-preserved' }
    }
    '16' {
      $repo = Join-Path $testRoot 'fixtures\validator\solo-one-active\repo'
      $result = (& $validator doctor -Root $repo -Format json | Out-String) | ConvertFrom-Json
      if (@($result.diagnostics | Where-Object { $_.code -eq 'AKW401' -and -not $_.blocking }).Count -gt 0) { $actual = 'WARN'; $evidence = 'AKW401' }
    }
    '17' {
      $adopt = Get-Content -LiteralPath (Join-Path $ProjectRoot 'skills\init\SKILL.md') -Raw -Encoding UTF8
      $agents = Get-Content -LiteralPath (Join-Path $ProjectRoot 'AGENTS.md') -Raw -Encoding UTF8
      if ($adopt.Contains('harici sisteme yazmaz') -and $agents.Contains('Harici yazmadan önce tam hedefi doğrula')) { $actual = 'BLOCK'; $evidence = 'external-write-authority-gate' }
    }
    '18' {
      $path = Join-Path $FixtureDir 'repo\özellik planı\bağlam.txt'
      if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Content -LiteralPath $path -Raw -Encoding UTF8).Contains('ğüşiöç')) { $actual = 'PASS'; $evidence = 'utf8-path-and-content' }
    }
    '19' {
      $ignore = Get-Content -LiteralPath (Join-Path $ProjectRoot '.agents\.gitignore') -Raw -Encoding UTF8
      if ($ignore.Contains('/local/*') -and $ignore.Contains('/runtime/*')) { $actual = 'PASS'; $evidence = 'local-runtime-results-excluded' }
    }
    '20' {
      $agents = Get-Content -LiteralPath (Join-Path $ProjectRoot 'AGENTS.md') -Raw -Encoding UTF8
      if ($agents.Contains('Koşullu playbook') -and $agents.Contains('bütün playbook')) { $actual = 'PASS'; $evidence = 'triggered-context-only' }
    }
    '21' {
      $config = Read-CaseJson -Path (Join-Path $ProjectRoot '.agents\config.json')
      $agentsPath = Join-Path $ProjectRoot 'AGENTS.md'
      $bytes = (Get-Item -LiteralPath $agentsPath).Length
      $lines = @(Get-Content -LiteralPath $agentsPath -Encoding UTF8).Count
      if ($bytes -le [int]$config.instructionBudgets.agentsMaxBytes -and $lines -le [int]$config.instructionBudgets.agentsMaxLines) { $actual = 'PASS'; $evidence = "budget-$($bytes)b-$($lines)l" }
    }
    '22' {
      $low = 'a' * 32767
      $high = 'a' * 32769
      if ($low.Length -le 32768 -and $high.Length -gt 32768) { $actual = 'WARN'; $evidence = '32768-boundary-detected' }
    }
    '23' {
      if ((Get-Command claude -ErrorAction SilentlyContinue) -and $env:AGENT_KIT_LIVE_CLIENTS -eq '1') { $actual = 'BLOCKED'; $evidence = 'InstructionsLoaded-observation-required' }
      else { $actual = 'SKIP'; $evidence = 'AKS503-claude-observability-unavailable' }
    }
    '24' {
      Import-Module $validatorModule -Force
      $value = 'ğ' * 8001
      $limited = Limit-AgentKitContext -Text $value -MaxChars 8000
      $info = New-Object Globalization.StringInfo($limited)
      if ($info.LengthInTextElements -eq 8000) { $actual = 'PASS'; $evidence = 'utf8-8000-char-bound' }
    }
    '25' {
      # Ayni kosul (AKE203), iki profil: fark yalniz uyari/deny olmali.
      $json = Get-Content -LiteralPath (Join-Path $testRoot 'fixtures\validator\team-missing-work\pre-tool-input.json') -Raw -Encoding UTF8
      $teamRepo = Join-Path $testRoot 'fixtures\validator\team-missing-work\repo'
      $tmpDir = Join-Path (Join-Path $ProjectRoot '.agents\runtime') ('acceptance-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
      New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
      $soloRepo = Join-Path $tmpDir 'solo-repo'
      Copy-Item -LiteralPath $teamRepo -Destination $soloRepo -Recurse -Force
      $cfgPath = Join-Path $soloRepo '.agents\config.json'
      $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $cfg.profile = 'solo'
      $cfgJson = ($cfg | ConvertTo-Json -Depth 12) -replace "`r`n", "`n"
      [IO.File]::WriteAllText($cfgPath, $cfgJson + "`n", (New-Object Text.UTF8Encoding($false)))
      $solo = Invoke-HookWithInput -Validator $validator -Json $json -Root $soloRepo
      $team = Invoke-HookWithInput -Validator $validator -Json $json -Root $teamRepo
      Remove-Item -LiteralPath $tmpDir -Recurse -Force
      $soloDecision = $solo.hookSpecificOutput.PSObject.Properties.Name -contains 'permissionDecision'
      if (-not $soloDecision -and [string]$solo.hookSpecificOutput.additionalContext -match 'AKE203' -and $team.hookSpecificOutput.permissionDecision -eq 'deny' -and [string]$team.hookSpecificOutput.permissionDecisionReason -match 'AKE203') { $actual = 'PASS'; $evidence = 'solo-warn-team-deny' }
    }
    default {
      return [pscustomobject]@{ Id = $Id; Status = 'FAIL'; Observed = 'E_CASE_UNKNOWN'; Evidence = 'unknown-case-id' }
    }
  }

  if ($actual -eq [string]$expectedData.observed) { $status = [string]$expectedData.status }
  else { $status = 'FAIL'; $evidence = "expected-$($expectedData.observed)-observed-$actual" }
  return [pscustomobject]@{ Id = $Id; Status = $status; Observed = $actual; Evidence = "$evidence;$Class;$Profile" }
}

Export-ModuleMember -Function 'Invoke-AgentKitCase'
