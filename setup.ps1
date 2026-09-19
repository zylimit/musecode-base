# setup.ps1 — musecode-base 注入式安装（Windows PowerShell）。
# 用法：pwsh -File setup.ps1 [-Target C:\path\to\project] [-DryRun]
param([string]$Target = ".", [switch]$DryRun)
$ErrorActionPreference = "Stop"
$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($Target)) { throw "target 不能为空" }
if ($Target -match "\.\.") { throw "target 含 ..：$Target" }
if ([System.IO.Path]::IsPathRooted($Target)) { $FullTarget = [System.IO.Path]::GetFullPath($Target) }
else { $FullTarget = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Target)) }
if ($FullTarget -eq $Src) { throw "target 不能是脚手架源码自己" }
$Payload = @("AGENTS.md","ARCHITECTURE.md","HARNESS.md","README.md","SCALING.md",".gitignore","FRAMEWORK-MANIFEST.json","setup.sh","setup.ps1")
$PayloadDirs = @("docs",".agents/skills",".agents/memory",".agents/workflows",".agents/harness",".agents/rules",".agents/feedback/templates","scripts","tests",".muse")
$SkipRx = "harness-state/|\.framework-new$|\.bak$|/evidence/|__pycache__|\.pyc$|\.pytest_cache|/\.git/|node_modules|\.DS_Store|\.mypy_cache|\.ruff_cache|module-catalog\.json$|arch-baseline\.json$"
$FeedbackIndex = ".agents/feedback/FEEDBACK-INDEX.md"
$files = New-Object System.Collections.Generic.List[string]
foreach ($p in $Payload) { if (Test-Path (Join-Path $Src $p)) { $files.Add($p) } }
foreach ($d in $PayloadDirs) {
  $dd = Join-Path $Src $d
  if (!(Test-Path $dd)) { continue }
  Get-ChildItem -Recurse -Force -File $dd | ForEach-Object {
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
  } elseif (Test-Path "$t.framework-new") {
    if ($DryRun) { Write-Output "conflict $rel (keep existing sidecar)" }
    else {
      if ((Get-FileHash $s).Hash -eq (Get-FileHash "$t.framework-new").Hash) { $cSkip++ }
      else { Write-Output "keep     $rel.framework-new (已有 sidecar，不覆盖)"; $cConflict++ }
    }
    if ($DryRun) { $cConflict++ }
  } else {
    if ($DryRun) { Write-Output "conflict $rel -> $rel.framework-new" } else { Copy-Item $s "$t.framework-new" }
    $cConflict++
  }
}
$indexTarget = Join-Path $FullTarget $FeedbackIndex
if (!(Test-Path $indexTarget)) {
  if ($DryRun) { Write-Output "init     $FeedbackIndex (absent)" }
  else {
    New-Item -ItemType Directory -Force -Path (Split-Path $indexTarget) | Out-Null
    @("# Feedback Index","",
    "> 经验教训索引。新建或更新 feedback 文件后，同步更新此索引。",
    "> 格式：每条一行，``- [标题](文件名.md) — 一句话描述``",
    "> 模板：templates/feedback-topic-template.md",
    "> 毕业/跳过状态看各文件 frontmatter（graduated/skipped），供 evolution-engine 扫描。") | Set-Content $indexTarget
    $cCreate++
  }
}
Write-Output "result: create=$cCreate conflict=$cConflict skip=$cSkip"
if ($cConflict -gt 0) { Write-Output "note: *.framework-new 需手工合并（你的定制未被覆盖）" }
