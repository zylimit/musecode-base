# setup.ps1 — musecode-base 注入式安装（Windows PowerShell）。
# 用法：pwsh -File setup.ps1 [-Target C:\path\to\project] [-DryRun]
param([string]$Target = ".", [switch]$DryRun)
$ErrorActionPreference = "Stop"
$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($Target)) { throw "target 不能为空" }
if ($Target -match "\.\.") { throw "target 含 ..：$Target" }
$FullTarget = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Target))
if ($FullTarget -eq $Src) { throw "target 不能是脚手架源码自己" }
$Payload = @("AGENTS.md","ARCHITECTURE.md","HARNESS.md","README.md","SCALING.md",".gitignore","FRAMEWORK-MANIFEST.json","setup.sh","setup.ps1")
$PayloadDirs = @("docs",".agents/skills",".agents/memory",".agents/workflows",".agents/harness","scripts","src","tests",".muse")
$SkipRx = "harness-state/|\.framework-new$|\.bak$|/evidence/|__pycache__|\.pyc$|\.pytest_cache|/\.git/|node_modules|\.DS_Store"
$files = New-Object System.Collections.Generic.List[string]
foreach ($p in $Payload) { if (Test-Path (Join-Path $Src $p)) { $files.Add($p) } }
foreach ($d in $PayloadDirs) {
  $dd = Join-Path $Src $d
  if (!(Test-Path $dd)) { continue }
  Get-ChildItem -Recurse -File $dd | ForEach-Object {
    $rel = [System.IO.Path]::GetRelativePath($Src, $_.FullName).Replace("\","/")
    if ($rel -notmatch $SkipRx) { $files.Add($rel) }
  }
}
$cCreate = 0; $cConflict = 0; $cSkip = 0
if ($DryRun) { Write-Output "setup dry-run: $Src -> $FullTarget (zero-write)" } else { New-Item -ItemType Directory -Force -Path $FullTarget | Out-Null }
foreach ($rel in ($files | Sort-Object -Unique)) {
  $s = Join-Path $Src $rel; $t = Join-Path $FullTarget $rel
  if (!(Test-Path $t)) {
    if ($DryRun) { Write-Output "create   $rel" } else { New-Item -ItemType Directory -Force -Path (Split-Path $t) | Out-Null; Copy-Item $s $t }
    $cCreate++
  } elseif ((Get-FileHash $s).Hash -eq (Get-FileHash $t).Hash) {
    if ($DryRun) { Write-Output "skip     $rel (identical)" }
    $cSkip++
  } else {
    if ($DryRun) { Write-Output "conflict $rel -> $rel.framework-new" } else { Copy-Item $s "$t.framework-new" }
    $cConflict++
  }
}
Write-Output "result: create=$cCreate update=0 conflict=$cConflict skip=$cSkip"
if ($cConflict -gt 0) { Write-Output "note: *.framework-new 需手工合并（你的定制未被覆盖）" }
