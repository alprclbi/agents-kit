[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$PackageRoot,
  [Parameter(Mandatory = $true)][string]$OutputZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$OutputZip = [IO.Path]::GetFullPath($OutputZip)
$packagePrefix = $PackageRoot.TrimEnd('\') + '\'
if (($OutputZip -eq $PackageRoot) -or $OutputZip.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "E_OUTPUT_INSIDE_SOURCE $OutputZip"
}
$OutputDirectory = Split-Path -Parent $OutputZip
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { throw "E_OUTPUT_DIRECTORY $OutputDirectory" }

$ReleaseRoot = Join-Path ([IO.Path]::GetTempPath()) ("agent-kit-release-{0}" -f [guid]::NewGuid())
$ReleasePackage = Join-Path $ReleaseRoot 'agents-kit'
$OutputTemp = $null
New-Item -ItemType Directory -Path $ReleaseRoot -ErrorAction Stop | Out-Null

try {
  $releasePrefix = [IO.Path]::GetFullPath($ReleaseRoot).TrimEnd('\') + '\'
  $releasePath = [IO.Path]::GetFullPath($ReleasePackage)
  if (-not $releasePath.StartsWith($releasePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "E_RELEASE_TARGET $releasePath" }
  Copy-Item -LiteralPath $PackageRoot -Destination $ReleasePackage -Recurse -ErrorAction Stop

  function Assert-ReleaseChild([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $prefix = $releasePath.TrimEnd('\') + '\'
    if (($full -ne $releasePath) -and -not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "E_RELEASE_CHILD $full" }
    return $full
  }

  function Clear-ReleaseDirectory([string]$Relative, [string]$Keep) {
    $targetRoot = Assert-ReleaseChild (Join-Path $ReleasePackage $Relative)
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) { return }
    Get-ChildItem -LiteralPath $targetRoot -Force | Where-Object { $_.Name -ne $Keep } | ForEach-Object {
      $target = Assert-ReleaseChild $_.FullName
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    }
  }

  Clear-ReleaseDirectory '.agents\changes\active' 'README.md'
  Clear-ReleaseDirectory '.agents\changes\archive' 'README.md'
  Clear-ReleaseDirectory '.agents\local' 'README.md'
  Clear-ReleaseDirectory '.agents\runtime' 'README.md'
  Clear-ReleaseDirectory '.agents\tests\results' '.gitignore'
  Clear-ReleaseDirectory '.agents\evals\results' '.gitignore'

  $logsPath = Assert-ReleaseChild (Join-Path $ReleasePackage '.agents\logs')
  if (Test-Path -LiteralPath $logsPath) { Remove-Item -LiteralPath $logsPath -Recurse -Force -ErrorAction Stop }
  # Git deposu ve GitHub depo yonetim dosyalari dagitim paketine GIRMEZ.
  # sh/package-release.sh ile PARITE; birini degistiren digerini de degistirir.
  foreach ($repoOnly in @('.git', '.github\ISSUE_TEMPLATE', '.github\PULL_REQUEST_TEMPLATE.md', 'CODE_OF_CONDUCT.md')) {
    $repoOnlyPath = Assert-ReleaseChild (Join-Path $ReleasePackage $repoOnly)
    if (Test-Path -LiteralPath $repoOnlyPath) { Remove-Item -LiteralPath $repoOnlyPath -Recurse -Force -ErrorAction Stop }
  }
  $nestedZip = Assert-ReleaseChild (Join-Path $ReleasePackage 'agents-kit.zip')
  if (Test-Path -LiteralPath $nestedZip) { Remove-Item -LiteralPath $nestedZip -Force -ErrorAction Stop }

  & (Join-Path $ReleasePackage '.agents\tests\run.ps1')
  if ($LASTEXITCODE -ne 0) { throw "E_RELEASE_TEST $LASTEXITCODE" }
  & (Join-Path $ReleasePackage '.agents\validators\ps\agent-kit.ps1') manifest -Root $ReleasePackage -Format text
  if ($LASTEXITCODE -ne 0) { throw "E_RELEASE_MANIFEST $LASTEXITCODE" }
  Clear-ReleaseDirectory '.agents\tests\results' '.gitignore'

  $TempZip = Join-Path $ReleaseRoot 'agents-kit.zip'
  Compress-Archive -LiteralPath $ReleasePackage -DestinationPath $TempZip -ErrorAction Stop
  $VerifyRoot = Join-Path $ReleaseRoot 'verify'
  Expand-Archive -LiteralPath $TempZip -DestinationPath $VerifyRoot -ErrorAction Stop
  $Extracted = Join-Path $VerifyRoot 'agents-kit'
  & (Join-Path $Extracted '.agents\tests\run.ps1')
  if ($LASTEXITCODE -ne 0) { throw "E_RELEASE_EXTRACTED_TEST $LASTEXITCODE" }
  & (Join-Path $Extracted '.agents\validators\ps\agent-kit.ps1') manifest -Root $Extracted -Format text
  if ($LASTEXITCODE -ne 0) { throw "E_RELEASE_EXTRACTED_MANIFEST $LASTEXITCODE" }

  $OutputTemp = Join-Path $OutputDirectory (".agents-kit.zip.{0}" -f [guid]::NewGuid())
  Copy-Item -LiteralPath $TempZip -Destination $OutputTemp -ErrorAction Stop
  if ((Get-FileHash -LiteralPath $TempZip -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $OutputTemp -Algorithm SHA256).Hash) { throw 'E_OUTPUT_COPY_HASH' }
  Move-Item -LiteralPath $OutputTemp -Destination $OutputZip -Force -ErrorAction Stop
  $OutputTemp = $null
  $hash = (Get-FileHash -LiteralPath $OutputZip -Algorithm SHA256).Hash.ToLowerInvariant()
  $bytes = (Get-Item -LiteralPath $OutputZip).Length
  Write-Output "PASS package-release sha256=$hash bytes=$bytes"
} finally {
  if ($OutputTemp -and (Test-Path -LiteralPath $OutputTemp)) { Remove-Item -LiteralPath $OutputTemp -Force -ErrorAction SilentlyContinue }
  $cleanupPath = [IO.Path]::GetFullPath($ReleaseRoot)
  $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if ($cleanupPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $cleanupPath -Recurse -Force -ErrorAction SilentlyContinue }
}
