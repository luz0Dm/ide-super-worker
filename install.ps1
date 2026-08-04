# ===========================================================================
# IDE Super Worker - One-Click Installer (Windows)
# Installs the MCP worker and auto-detects your IDE client
#
# Usage: powershell -ExecutionPolicy Bypass -c "iwr -useb https://raw.githubusercontent.com/dickmatrix/ide-super-worker/main/install.ps1 | iex"
# ============================================================================

$ErrorActionPreference = "Stop"

# --- Configuration ---
$RepoUrl = "https://github.com/dickmatrix/ide-super-worker.git"
$InstallDir = "$env:USERPROFILE\.ide-super-worker"
$ReleaseUrl = "https://api.github.com/repos/dickmatrix/ide-super-worker/releases/latest"

# --- Banner ---
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  IDE Super Worker - One-Click Installer" -ForegroundColor Cyan
Write-Host "  Cut your AI coding costs by up to 90%" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Check prerequisites ---
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow

# Check Node.js
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "      Node.js found: $nodeVersion" -ForegroundColor Green
    } else {
        Write-Host "      Node.js not found!" -ForegroundColor Red
        Write-Host "      Please install Node.js 20+ from https://nodejs.org/" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "      Node.js not found!" -ForegroundColor Red
    Write-Host "      Please install Node.js 20+ from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Check Git
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "      Git found: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "      Git not found!" -ForegroundColor Red
        Write-Host "      Please install Git from https://git-scm.com/" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "      Git not found!" -ForegroundColor Red
    Write-Host "      Please install Git from https://git-scm.com/" -ForegroundColor Red
    exit 1
}

Write-Host ""

# --- Step 2: Clone or update repo ---
Write-Host "[2/5] Downloading IDE Super Worker..." -ForegroundColor Yellow

if (Test-Path "$InstallDir\.git") {
    Write-Host "      Updating existing installation..." -ForegroundColor Gray
    Set-Location $InstallDir
    git pull origin main 2>$null
} else {
    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
    }
    git clone $RepoUrl $InstallDir
    Set-Location $InstallDir
}

Write-Host ""

# --- Step 3: Install dependencies ---
Write-Host "[3/5] Installing dependencies..." -ForegroundColor Yellow
npm install --silent 2>$null
npm run build --silent 2>$null

if (-not (Test-Path "dist\index.js")) {
    Write-Host "      Build failed! Check errors above." -ForegroundColor Red
    exit 1
}
Write-Host "      Build successful!" -ForegroundColor Green
Write-Host ""

# --- Step 4: Detect IDE clients ---
Write-Host "[4/5] Detecting IDE clients..." -ForegroundColor Yellow

$DetectedClients = @()

# Cursor
$cursorConfig = "$env:USERPROFILE\.cursor\mcp.json"
if (Test-Path (Split-Path $cursorConfig)) {
    $DetectedClients += @{ Name = "Cursor"; ConfigPath = $cursorConfig; Type = "cursor" }
    Write-Host "      Found: Cursor" -ForegroundColor Green
}

# VS Code
$vsCodeConfig = "$env:USERPROFILE\.vscode\mcp.json"
if (Test-Path (Split-Path $vsCodeConfig)) {
    $DetectedClients += @{ Name = "VS Code"; ConfigPath = $vsCodeConfig; Type = "vscode" }
    Write-Host "      Found: VS Code" -ForegroundColor Green
}

# TRAE
$traeConfig = "$env:USERPROFILE\.trae\mcp.json"
if (Test-Path (Split-Path $traeConfig)) {
    $DetectedClients += @{ Name = "TRAE"; ConfigPath = $traeConfig; Type = "trae" }
    Write-Host "      Found: TRAE" -ForegroundColor Green
}

# Claude Desktop
$claudeConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path (Split-Path $claudeConfig)) {
    $DetectedClients += @{ Name = "Claude Desktop"; ConfigPath = $claudeConfig; Type = "claude" }
    Write-Host "      Found: Claude Desktop" -ForegroundColor Green
}

# Windsurf
$windsurfConfig = "$env:USERPROFILE\.windsurf\mcp.json"
if (Test-Path (Split-Path $windsurfConfig)) {
    $DetectedClients += @{ Name = "Windsurf"; ConfigPath = $windsurfConfig; Type = "windsurf" }
    Write-Host "      Found: Windsurf" -ForegroundColor Green
}

if ($DetectedClients.Count -eq 0) {
    Write-Host "      No supported IDE detected." -ForegroundColor Yellow
    Write-Host "      You can manually configure MCP later." -ForegroundColor Gray
} else {
    Write-Host "      Found $($DetectedClients.Count) IDE(s)" -ForegroundColor Green
}
Write-Host ""

# --- Step 5: Configure API key ---
Write-Host "[5/5] Configure your cheap model gateway..." -ForegroundColor Yellow
Write-Host ""
Write-Host "      To save on costs, you need an OpenAI-compatible API key." -ForegroundColor White
Write-Host "      Recommended providers (cheap, reliable):" -ForegroundColor White
Write-Host "        - DeepSeek (https://platform.deepseek.com)" -ForegroundColor Gray
Write-Host "        - OneAPI (any public instance)" -ForegroundColor Gray
Write-Host "        - Your own OpenAI-compatible endpoint" -ForegroundColor Gray
Write-Host ""

$BaseUrl = Read-Host "      Enter your gateway base URL (or press Enter to skip)"
if ($BaseUrl) {
    $ApiKey = Read-Host "      Enter your API key"
    
    # Create .env file
    $envContent = @"
ONEAPI_BASE_URL=$BaseUrl
ONEAPI_API_KEY=$ApiKey
CLAUDE_MODEL=deepseek-v4-flash
CLAUDE_CODE_MODEL=sonnet
USE_OPENAI_ADAPTER=1
SANDBOX_ROOT=$env:USERPROFILE
WORKER_LITE_LLM=0
WORKER_METRICS_FILE=$InstallDir\.worker-metrics.jsonl
"@
    Set-Content -Path "$InstallDir\.env" -Value $envContent
    Write-Host "      Configuration saved!" -ForegroundColor Green
} else {
    Write-Host "      Skipped. You can configure later by editing .env" -ForegroundColor Gray
}

# --- Register MCP config for detected clients ---
if ($DetectedClients.Count -gt 0 -and $BaseUrl) {
    Write-Host ""
    Write-Host "Registering MCP server for detected IDEs..." -ForegroundColor Yellow
    
    $mcpServerEntry = @{
        command = "node"
        args = @("$InstallDir\dist\index.js")
        cwd = $InstallDir
        env = @{
            ONEAPI_BASE_URL = $BaseUrl
            ONEAPI_API_KEY = $ApiKey
            CLAUDE_MODEL = "deepseek-v4-flash"
            CLAUDE_CODE_MODEL = "sonnet"
            USE_OPENAI_ADAPTER = "1"
            SANDBOX_ROOT = $env:USERPROFILE
            WORKER_LITE_LLM = "0"
        }
    }

    foreach ($client in $DetectedClients) {
        $configDir = Split-Path $client.ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $existingConfig = @{}
        if (Test-Path $client.ConfigPath) {
            try {
                $existingConfig = Get-Content $client.ConfigPath -Raw | ConvertFrom-Json -AsHashtable
            } catch {}
        }
        
        if (-not $existingConfig.ContainsKey("mcpServers")) {
            $existingConfig["mcpServers"] = @{}
        }
        
        $existingConfig["mcpServers"]["ide-super-worker"] = $mcpServerEntry
        
        $existingConfig | ConvertTo-Json -Depth 10 | Set-Content $client.ConfigPath
        Write-Host "      Registered for $($client.Name)" -ForegroundColor Green
    }
}

# --- Final summary ---
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project installed at: $InstallDir" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your IDE client" -ForegroundColor White
Write-Host "  2. Ask your AI assistant to 'search for files' or 'read code'" -ForegroundColor White
Write-Host "  3. Watch the cost savings in real-time!" -ForegroundColor White
Write-Host ""
Write-Host "  View savings dashboard:" -ForegroundColor Yellow
Write-Host "  node $InstallDir\dist\dashboard.js" -ForegroundColor Gray
Write-Host ""
Write-Host "  Need help? https://github.com/dickmatrix/ide-super-worker/issues" -ForegroundColor Gray
Write-Host ""
