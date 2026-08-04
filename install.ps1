# ===========================================================================
# IDE Super Worker - One-Click Installer (Windows)
#
# Usage:
#   Default:    iwr -useb https://isw.deno.dev/install.ps1 | iex
#   Fast mode:  iwr -useb https://isw.deno.dev/install.ps1 | iex -Preset deepseek
#
# Presets: deepseek, openrouter, together, custom
# ===========================================================================

param(
    [ValidateSet("deepseek", "openrouter", "together", "custom", "")]
    [string]$Preset = ""
)

$ErrorActionPreference = "Stop"
$InstallDir = "$env:USERPROFILE\.ide-super-worker"
$RepoUrl = "https://github.com/dickmatrix/ide-super-worker.git"

# --- Banner ---
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  IDE Super Worker - Installer" -ForegroundColor Cyan
Write-Host "  Cut AI coding costs by up to 90%" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# --- Built-in gateway presets ---
$Presets = @{
    deepseek = @{
        Name = "DeepSeek (recommended)"
        BaseUrl = "https://api.deepseek.com/v1"
        Model = "deepseek-chat"
        SignupUrl = "https://platform.deepseek.com"
        Note = "$0.27/1M input, $1.10/1M output tokens"
    }
    openrouter = @{
        Name = "OpenRouter (multi-model)"
        BaseUrl = "https://openrouter.ai/api/v1"
        Model = "auto"
        SignupUrl = "https://openrouter.ai/keys"
        Note = "Access 200+ models, pay-as-you-go"
    }
    together = @{
        Name = "Together AI"
        BaseUrl = "https://api.together.xyz/v1"
        Model = "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"
        SignupUrl = "https://api.together.ai/signin"
        Note = "$0.18/1M tokens, free trial available"
    }
}

# --- Step 1: Prerequisites ---
Write-Host "[1/4] Checking..." -ForegroundColor Yellow
$nodeOk = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
$gitOk = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if (-not $nodeOk) { Write-Host "  Node.js missing: https://nodejs.org" -ForegroundColor Red; exit 1 }
if (-not $gitOk) { Write-Host "  Git missing: https://git-scm.com" -ForegroundColor Red; exit 1 }
Write-Host "  OK - node + git found" -ForegroundColor Green
Write-Host ""

# --- Step 2: Download ---
Write-Host "[2/4] Downloading..." -ForegroundColor Yellow
if (Test-Path "$InstallDir\.git") {
    Set-Location $InstallDir
    git pull origin main 2>$null | Out-Null
} else {
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    git clone --depth 1 $RepoUrl $InstallDir 2>$null | Out-Null
}
Set-Location $InstallDir
npm install --silent 2>$null | Out-Null
npm run build --silent 2>$null | Out-Null
if (-not (Test-Path "dist\index.js")) { Write-Host "  Build failed!" -ForegroundColor Red; exit 1 }
Write-Host "  OK - installed to $InstallDir" -ForegroundColor Green
Write-Host ""

# --- Step 3: Configure API Key ---
Write-Host "[3/4] Configure API key..." -ForegroundColor Yellow
Write-Host ""

$selectedPreset = $null

if ($Preset -and $Presets.ContainsKey($Preset)) {
    $selectedPreset = $Presets[$Preset]
} else {
    Write-Host "  Choose your cheap model provider:" -ForegroundColor White
    Write-Host ""
    Write-Host "    1) DeepSeek    - $0.27/1M input tokens (best price)" -ForegroundColor Cyan
    Write-Host "    2) OpenRouter  - 200+ models, auto-routing" -ForegroundColor Cyan
    Write-Host "    3) Together AI - $0.18/1M tokens, free trial" -ForegroundColor Cyan
    Write-Host "    4) Custom      - I have my own gateway" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "  Enter 1-4 (default: 1)"
    switch ($choice) {
        "2" { $selectedPreset = $Presets["openrouter"] }
        "3" { $selectedPreset = $Presets["together"] }
        "4" { $selectedPreset = $null }
        default { $selectedPreset = $Presets["deepseek"] }
    }
}

Write-Host ""

$BaseUrl = ""
$ApiKey = ""
$Model = ""

if ($selectedPreset) {
    Write-Host "  Provider: $($selectedPreset.Name)" -ForegroundColor Green
    Write-Host "  Pricing:  $($selectedPreset.Note)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Get your API key at: $($selectedPreset.SignupUrl)" -ForegroundColor Yellow
    Write-Host ""
    $BaseUrl = $selectedPreset.BaseUrl
    $Model = $selectedPreset.Model
    $ApiKey = Read-Host "  Paste your API key (or press Enter to configure later)"
} else {
    $BaseUrl = Read-Host "  Gateway base URL"
    $Model = Read-Host "  Model name (e.g. deepseek-chat)"
    $ApiKey = Read-Host "  API key"
}

if ($ApiKey) {
    $envContent = @"
ONEAPI_BASE_URL=$BaseUrl
ONEAPI_API_KEY=$ApiKey
CLAUDE_MODEL=$Model
CLAUDE_CODE_MODEL=sonnet
USE_OPENAI_ADAPTER=1
SANDBOX_ROOT=$env:USERPROFILE
WORKER_LITE_LLM=0
WORKER_METRICS_FILE=$InstallDir\.worker-metrics.jsonl
"@
    Set-Content -Path "$InstallDir\.env" -Value $envContent
    Write-Host ""
    Write-Host "  OK - API key saved" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Skipped. Configure later: $InstallDir\.env" -ForegroundColor Gray
}

Write-Host ""

# --- Step 4: Register IDE ---
Write-Host "[4/4] Register IDE server..." -ForegroundColor Yellow
Write-Host ""

$IDEs = @(
    @{ Name = "Cursor"; Path = "$env:USERPROFILE\.cursor\mcp.json" },
    @{ Name = "VS Code"; Path = "$env:USERPROFILE\.vscode\mcp.json" },
    @{ Name = "TRAE"; Path = "$env:USERPROFILE\.trae\mcp.json" },
    @{ Name = "Windsurf"; Path = "$env:USERPROFILE\.windsurf\mcp.json" },
    @{ Name = "Claude Desktop"; Path = "$env:APPDATA\Claude\claude_desktop_config.json" }
)

$found = 0
foreach ($ide in $IDEs) {
    $dir = Split-Path $ide.Path
    if (Test-Path $dir) {
        $found++
        Write-Host "  Found: $($ide.Name)" -ForegroundColor Green

        $mcpEntry = @{
            command = "node"
            args = @("$InstallDir\dist\index.js")
            cwd = $InstallDir
            env = @{
                ONEAPI_BASE_URL = $BaseUrl
                ONEAPI_API_KEY = if ($ApiKey) { $ApiKey } else { "YOUR_KEY_HERE" }
                CLAUDE_MODEL = $Model
                CLAUDE_CODE_MODEL = "sonnet"
                USE_OPENAI_ADAPTER = "1"
                SANDBOX_ROOT = $env:USERPROFILE
                WORKER_LITE_LLM = "0"
                WORKER_METRICS_FILE = "$InstallDir\.worker-metrics.jsonl"
            }
        }

        $config = @{}
        if (Test-Path $ide.Path) {
            try { $config = Get-Content $ide.Path -Raw | ConvertFrom-Json -AsHashtable } catch {}
        }
        if (-not $config) { $config = @{} }
        if (-not $config["mcpServers"]) { $config["mcpServers"] = @{} }
        $config["mcpServers"]["ide-super-worker"] = $mcpEntry
        $config | ConvertTo-Json -Depth 10 | Set-Content $ide.Path
    }
}

if ($found -eq 0) {
    Write-Host "  No IDE found. See README for manual setup." -ForegroundColor Gray
}

# --- Done ---
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Done!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Restart your IDE" -ForegroundColor White
Write-Host "  2. Ask AI to 'read a file' or 'run tests'" -ForegroundColor White
Write-Host "  3. Watch savings:" -ForegroundColor White
Write-Host ""
Write-Host "     node $InstallDir\dist\dashboard.js" -ForegroundColor Gray
Write-Host ""
