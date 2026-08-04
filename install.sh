#!/usr/bin/env bash
# ===========================================================================
# IDE Super Worker - One-Click Installer (macOS/Linux)
# Installs the MCP worker and auto-detects your IDE client
#
# Usage: curl -fsSL https://raw.githubusercontent.com/dickmatrix/ide-super-worker/main/install.sh | bash
# ============================================================================

set -e

# --- Configuration ---
REPO_URL="https://github.com/dickmatrix/ide-super-worker.git"
INSTALL_DIR="$HOME/.ide-super-worker"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# --- Banner ---
echo ""
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  IDE Super Worker - One-Click Installer${NC}"
echo -e "${GREEN}  Cut your AI coding costs by up to 90%${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# --- Step 1: Check prerequisites ---
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

if command -v node &> /dev/null; then
    echo -e "${GREEN}      Node.js found: $(node --version)${NC}"
else
    echo -e "${RED}      Node.js not found!${NC}"
    echo -e "${RED}      Please install Node.js 20+ from https://nodejs.org/${NC}"
    exit 1
fi

if command -v git &> /dev/null; then
    echo -e "${GREEN}      Git found: $(git --version)${NC}"
else
    echo -e "${RED}      Git not found!${NC}"
    echo -e "${RED}      Please install Git from https://git-scm.com/${NC}"
    exit 1
fi

echo ""

# --- Step 2: Clone or update repo ---
echo -e "${YELLOW}[2/5] Downloading IDE Super Worker...${NC}"

if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${GRAY}      Updating existing installation...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null
else
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo ""

# --- Step 3: Install dependencies ---
echo -e "${YELLOW}[3/5] Installing dependencies...${NC}"
npm install --silent 2>/dev/null
npm run build --silent 2>/dev/null

if [ ! -f "dist/index.js" ]; then
    echo -e "${RED}      Build failed! Check errors above.${NC}"
    exit 1
fi
echo -e "${GREEN}      Build successful!${NC}"
echo ""

# --- Step 4: Detect IDE clients ---
echo -e "${YELLOW}[4/5] Detecting IDE clients...${NC}"

DETECTED_CLIENTS=()

# Cursor
if [ -d "$HOME/.cursor" ]; then
    DETECTED_CLIENTS+=("Cursor:$HOME/.cursor/mcp.json")
    echo -e "${GREEN}      Found: Cursor${NC}"
fi

# VS Code
if [ -d "$HOME/.vscode" ]; then
    DETECTED_CLIENTS+=("VS Code:$HOME/.vscode/mcp.json")
    echo -e "${GREEN}      Found: VS Code${NC}"
fi

# TRAE
if [ -d "$HOME/.trae" ]; then
    DETECTED_CLIENTS+=("TRAE:$HOME/.trae/mcp.json")
    echo -e "${GREEN}      Found: TRAE${NC}"
fi

# Claude Desktop (macOS)
if [ -d "$HOME/Library/Application Support/Claude" ]; then
    DETECTED_CLIENTS+=("Claude Desktop:$HOME/Library/Application Support/Claude/claude_desktop_config.json")
    echo -e "${GREEN}      Found: Claude Desktop${NC}"
fi

# Windsurf
if [ -d "$HOME/.windsurf" ]; then
    DETECTED_CLIENTS+=("Windsurf:$HOME/.windsurf/mcp.json")
    echo -e "${GREEN}      Found: Windsurf${NC}"
fi

if [ ${#DETECTED_CLIENTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}      No supported IDE detected.${NC}"
    echo -e "${GRAY}      You can manually configure MCP later.${NC}"
else
    echo -e "${GREEN}      Found ${#DETECTED_CLIENTS[@]} IDE(s)${NC}"
fi

echo ""

# --- Step 5: Configure API key ---
echo -e "${YELLOW}[5/5] Configure your cheap model gateway...${NC}"
echo ""
echo -e "${NC}      To save on costs, you need an OpenAI-compatible API key.${NC}"
echo -e "${NC}      Recommended providers (cheap, reliable):${NC}"
echo -e "${GRAY}        - DeepSeek (https://platform.deepseek.com)${NC}"
echo -e "${GRAY}        - OneAPI (any public instance)${NC}"
echo -e "${GRAY}        - Your own OpenAI-compatible endpoint${NC}"
echo ""

read -p "      Enter your gateway base URL (or press Enter to skip): " BASE_URL
if [ -n "$BASE_URL" ]; then
    read -p "      Enter your API key: " API_KEY
    
    cat > "$INSTALL_DIR/.env" << EOF
ONEAPI_BASE_URL=$BASE_URL
ONEAPI_API_KEY=$API_KEY
CLAUDE_MODEL=deepseek-v4-flash
CLAUDE_CODE_MODEL=sonnet
USE_OPENAI_ADAPTER=1
SANDBOX_ROOT=$HOME
WORKER_LITE_LLM=0
WORKER_METRICS_FILE=$INSTALL_DIR/.worker-metrics.jsonl
EOF
    echo -e "${GREEN}      Configuration saved!${NC}"
else
    echo -e "${GRAY}      Skipped. You can configure later by editing .env${NC}"
fi

# --- Register MCP config ---
if [ ${#DETECTED_CLIENTS[@]} -gt 0 ] && [ -n "$BASE_URL" ]; then
    echo ""
    echo -e "${YELLOW}Registering MCP server for detected IDEs...${NC}"
    
    for client_entry in "${DETECTED_CLIENTS[@]}"; do
        IFS=':' read -r name config_path <<< "$client_entry"
        config_dir=$(dirname "$config_path")
        mkdir -p "$config_dir"
        
        if [ -f "$config_path" ]; then
            existing=$(cat "$config_path")
        else
            existing='{}'
        fi
        
        # Use jq if available, otherwise fallback to simple approach
        if command -v jq &> /dev/null; then
            new_config=$(echo "$existing" | jq --arg cmd "node" \
                --arg cwd "$INSTALL_DIR" \
                --arg args "$INSTALL_DIR/dist/index.js" \
                --arg base_url "$BASE_URL" \
                --arg api_key "$API_KEY" \
                '.mcpServers["ide-super-worker"] = {
                    "command": $cmd,
                    "args": [$args],
                    "cwd": $cwd,
                    "env": {
                        "ONEAPI_BASE_URL": $base_url,
                        "ONEAPI_API_KEY": $api_key,
                        "CLAUDE_MODEL": "deepseek-v4-flash",
                        "CLAUDE_CODE_MODEL": "sonnet",
                        "USE_OPENAI_ADAPTER": "1",
                        "SANDBOX_ROOT": env.HOME,
                        "WORKER_LITE_LLM": "0"
                    }
                }')
            echo "$new_config" > "$config_path"
        fi
        echo -e "${GREEN}      Registered for ${name}${NC}"
    done
fi

# --- Final summary ---
echo ""
echo -e "${CYAN}=============================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""
echo -e "${NC}  Project installed at: ${INSTALL_DIR}${NC}"
echo ""
echo -e "${YELLOW}  Next steps:${NC}"
echo -e "${NC}  1. Restart your IDE client${NC}"
echo -e "${NC}  2. Ask your AI assistant to 'search for files' or 'read code'${NC}"
echo -e "${NC}  3. Watch the cost savings in real-time!${NC}"
echo ""
echo -e "${YELLOW}  View savings dashboard:${NC}"
echo -e "${GRAY}  node ${INSTALL_DIR}/dist/dashboard.js${NC}"
echo ""
echo -e "${GRAY}  Need help? https://github.com/dickmatrix/ide-super-worker/issues${NC}"
echo ""
