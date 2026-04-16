# Claude Code Init - Windows PowerShell
# Usage: git clone https://github.com/codestreamkr/claude-code-init.git $env:TEMP\claude-init; & $env:TEMP\claude-init\install.ps1

param(
    [string]$Repo = "https://github.com/codestreamkr/claude-code-init.git"
)

$ErrorActionPreference = "Stop"
$ClaudeDir = "$env:USERPROFILE\.claude"

git config --global http.sslVerify false

# [1/4] ~/.claude/ 디렉토리 준비
Write-Host "[1/4] Preparing ~/.claude/ ..." -ForegroundColor Cyan
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    Write-Host "  ~/.claude/ created"
} else {
    Write-Host "  ~/.claude/ already exists"
}

# [2/4] git repo 연결
Write-Host "[2/4] Connecting git repo..." -ForegroundColor Cyan
$gitDir = Join-Path $ClaudeDir ".git"

if (Test-Path $gitDir) {
    # 이미 git repo → fetch + reset
    Push-Location $ClaudeDir
    $existing = git remote get-url origin 2>$null
    if ($existing -ne $Repo) {
        git remote set-url origin $Repo
    }
    git fetch origin
    git reset --hard origin/main
    Pop-Location
    Write-Host "  updated to latest"
} else {
    # git repo 없음 → 기존 파일 백업 후 clone
    $backupTargets = @("settings.json", "statusline.js", "CLAUDE.md")
    foreach ($f in $backupTargets) {
        $src = Join-Path $ClaudeDir $f
        if (Test-Path $src) {
            $dst = Join-Path $ClaudeDir "${f}~backup"
            Move-Item $src $dst -Force
            Write-Host "  backed up: $f -> ${f}~backup"
        }
    }

    # temp 경로에 clone 후 .git만 이동
    $TempDir = "$env:TEMP\claude-init-clone"
    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
    git clone $Repo $TempDir
    Move-Item "$TempDir\.git" "$ClaudeDir\.git"
    Remove-Item $TempDir -Recurse -Force

    # reset --hard로 최신 파일 배포
    Push-Location $ClaudeDir
    git reset --hard HEAD
    Pop-Location
    Write-Host "  cloned and applied"
}

# [3/4] MCP 서버 등록
Write-Host "[3/4] Registering MCP servers..." -ForegroundColor Cyan
if (Get-Command claude -ErrorAction SilentlyContinue) {
    & claude mcp add magic npx -- -y @21st-dev/magic
    if ($LASTEXITCODE -eq 0) { Write-Host "  registered: magic" } else { Write-Host "  skipped: magic" }
    & claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
    if ($LASTEXITCODE -eq 0) { Write-Host "  registered: sequential-thinking" } else { Write-Host "  skipped: sequential-thinking" }
} else {
    Write-Host "  skipped (claude not found)"
}

# [4/4] 결과 확인
Write-Host "[4/4] Verifying..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed files:" -ForegroundColor Green
$configFiles = @("CLAUDE.md", "settings.json", "statusline.js", ".gitignore")
foreach ($f in $configFiles) {
    if (Test-Path (Join-Path $ClaudeDir $f)) {
        Write-Host "  + $f"
    }
}
Get-ChildItem "$ClaudeDir\commands" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  + commands/$($_.Directory.Name)/$($_.Name)"
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "  Location: $ClaudeDir"
Write-Host "  Push changes: cd $ClaudeDir && git add -A && git commit -m 'update' && git push"
Write-Host ""
Write-Host "Next: run 'claude' to authenticate and verify." -ForegroundColor Yellow

# 임시 클론 디렉토리 정리
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir -like "$env:TEMP*") {
    Remove-Item $ScriptDir -Recurse -Force
}
