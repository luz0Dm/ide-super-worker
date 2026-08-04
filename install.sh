#!/usr/bin/env bash
# ===========================================================================
# IDE Super Worker - One-Click Installer (macOS/Linux)
#
# Usage:
#   Default:    curl -fsSL https://isw.deno.dev/install.sh | bash
#   Fast mode:  curl -fsSL https://isw.deno.dev/install.sh | bash -s deepseek
#
# Presets: deepseek, openrouter, together, custom
# ============================================================================

set -e

PRESET="${1:-}"
INSTALL_DIR="$HOME/.ide-super-worker"
REPO_URL="https://github.com/dickmatrix/ide-super-worker.git"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# --- Banner ---
echo ""
echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}  IDE Super Worker - Installer${NC}"
echo -e "${GREEN}  Cut AI coding costs by up to 90%${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""

# --- Step 1: Prerequisites ---
echo -e "${YELLOW}[1/4] Checking...${NC}"
command -v node >/dev/null 2>&1 || { echo -e "${RED}  Node.js missing: https://nodejs.org${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}  Git missing: https://git-scm.com${NC}"; exit 1; }
echo -e "${GREEN}  OK - node + git found${NC}"
echo ""

# --- Step 2: Download ---
echo -e "${YELLOW}[2/4] Downloading...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR" && git pull origin main 2>/dev/null
else
    [ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null
fi
cd "$INSTALL_DIR"
npm install --silent 2>/dev/null
npm run build --silent 2>/dev/null
[ ! -f "dist/index.js" ] && { echo -e "${RED}  Build failed!${NC}"; exit 1; }
echo -e "${GREEN}  OK - installed to ${INSTALL_DIR}${NC}"
echo ""

# --- Step 3: Configure API Key ---
echo -e "${YELLOW}[3/4] Configure API key...${NC}"
echo ""

# Suggest presets
show_menu() {
    echo -e "${NC}  Choose your cheap model provider:${NC}"
    echo ""
    echo -e "${CYAN}    1) DeepSeek    - \$0.27/1M input (best price)${NC}"
    echo -e "${CYAN}    2) OpenRouter  - 200+ models, auto-routing${NC}"
    echo -e "${CYAN}    3) Together AI - \$0.18/1M tokens, free trial${NC}"
    echo -e "${CYAN}    4) Custom      - I have my own gateway${NC}"
    echo ""
}

BASE_URL=""
API_KEY=""
MODEL=""

case "$PRESET" in
    deepseek) BASE_URL="https://api.deepseek.com/v1"; MODEL="deepseek-chat" ;;
    openrouter) BASE_URL="https://openrouter.ai/api/v1"; MODEL="auto" ;;
    together) BASE_URL="https://api.together.xyz/v1"; MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo" ;;
    custom) ;;
    *)
        show_menu
        read -p "  Enter 1-4 (default: 1): " choice
        case "$choice" in
            2) BASE_URL="https://openrouter.ai/api/v1"; MODEL="auto"; PRESET_NAME="OpenRouter" ;;
            3) BASE_URL="https://api.together.xyz/v1"; MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"; PRESET_NAME="Together AI" ;;
            4) ;;
            *) BASE_URL="https://api.deepseek.com/v1"; MODEL="deepseek-chat"; PRESET_NAME="DeepSeek" ;;
        esac
        ;;
esac

if [ -z "$PRESET" ] || [ -n "$choice" ]; then
    case "${PRESET:-$choice}" in
        deepseek|1) PRESET_NAME="DeepSeek"; PRESET_URL="https://platform.deepseek.com" ;;
        openrouter|2) PRESET_NAME="OpenRouter"; PRESET_URL="https://openrouter.ai/keys" ;;
        together|3) PRESET_NAME="Together AI"; PRESET_URL="https://api.together.ai/signin" ;;
    esac
fi

if [ -n "$BASE_URL" ]; then
    echo -e "${GREEN}  Provider: ${PRESET_NAME}${NC}"
    echo -e "${GRAY}  Get key:  ${PRESET_URL}${NC}"
    echo ""
    read -p "  Paste API key (or Enter to skip): " API_KEY
else
    read -p "  Gateway base URL: " BASE_URL
    read -p "  Model name: " MODEL
    read -p "  API key: " API_KEY
fi

if [ -n "$API_KEY" ]; then
    cat > "$INSTALL_DIR/.env" << EOF
ONEAPI_BASE_URL=$BASE_URL
ONEAPI_API_KEY=$API_KEY
CLAUDE_MODEL=$MODEL
CLAUDE_CODE_MODEL=sonnet
USE_OPENAI_ADAPTER=1
SANDBOX_ROOT=$HOME
WORKER_LITE_LLM=0
WORKER_METRICS_FILE=$INSTALL_DIR/.worker-metrics.jsonl
EOF
    echo -e "${GREEN}  OK - saved${NC}"
else
    echo -e "${GRAY}  Skipped. Configure later: ${INSTALL_DIR}/.env${NC}"
fi

echo ""

# --- Step 4: Register IDE ---
echo -e "${YELLOW}[4/4] Register IDE server...${NC}"

declare -A IDE_PATHS=(
    ["Cursor"]="$HOME/.cursor/mcp.json"
    ["VS Code"]="$HOME/.vscode/mcp.json"
    ["TRAE"]="$HOME/.trae/mcp.json"
    ["Windsurf"]="$HOME/.windsurf/mcp.json"
    ["Claude Desktop"]="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
)

for ide in "${!IDE_PATHS[@]}"; do
    config_path="${IDE_PATHS[$ide]}"
    config_dir=$(dirname "$config_path")
    if [ -d "$config_dir" ]; then
        echo -e "${GREEN}  Found: ${ide}${NC}"
        mkdir -p "$config_dir"

        key_value="${API_KEY:-YOUR_KEY_HERE}"
        if command -v jq >/dev/null 2>&1; then
            jq --arg cmd "node" --arg args "$INSTALL_DIR/dist/index.js" \
               --arg cwd "$INSTALL_DIR" \
               --arg base_url "$BASE_URL" --arg api_key "$key_value" \
               --arg model "$MODEL" \
               '.mcpServers["ide-super-worker"] = {
                   "command": $cmd, "args": [$args], "cwd": $cwd,
                   "env": {
                       "ONEAPI_BASE_URL": $base_url, "ONEAPI_API_KEY": $api_key,
                       "CLAUDE_MODEL": $model, "CLAUDE_CODE_MODEL": "sonnet",
                       "USE_OPENAI_ADAPTER": "1", "SANDBOX_ROOT": env.HOME,
                       "WORKER_LITE_LLM": "0"
                   }
               }' "$config_path" > "$config_path.tmp" 2>/dev/null && mv "$config_path.tmp" "$config_path" \
               || echo "{}" | jq --arg cmd "node" --arg args "$INSTALL_DIR/dist/index.js" \
               --arg cwd "$INSTALL_DIR" --arg base_url "$BASE_URL" --arg api_key "$key_value" \
               --arg model "$MODEL" \
               '{mcpServers: {"ide-super-worker": {
                   "command": $cmd, "args": [$args], "cwd": $cwd,
                   "env": {
                       "ONEAPI_BASE_URL": $base_url, "ONEAPI_API_KEY": $api_key,
                       "CLAUDE_MODEL": $model, "CLAUDE_CODE_MODEL": "sonnet",
                       "USE_OPENAI_ADAPTER": "1", "SANDBOX_ROOT": env.HOME,
                       "WORKER_LITE_LLM": "0"
                   }
               }}}' > "$config_path"
        fi
    fi
done

# --- Done ---
echo ""
echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN}  Done!${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e "${NC}  1. Restart your IDE${NC}"
echo -e "${NC}  2. Ask AI to 'read a file' or 'run tests'${NC}"
echo -e "${NC}  3. Watch savings:${NC}"
echo ""
echo -e "${GRAY}     node ${INSTALL_DIR}/dist/dashboard.js${NC}"
echo ""
