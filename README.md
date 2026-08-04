# IDE Super Worker

**Cut your AI coding costs by 90% with one command — keep using Claude/GPT, just stop wasting them on reading files and running tests.**

```
╔══════════════════════════════════════════════════════════╗
║          IDE Super Worker - Cost Savings Dashboard      ║
╠══════════════════════════════════════════════════════════╣
║                                                        ║
║  TOTAL SAVINGS: $47.83  ████████████████████████ 92%   ║
║                                                        ║
║  You would have spent:  $52.15                          ║
║  You actually spent:    $4.32                           ║
║                                                        ║
╚══════════════════════════════════════════════════════════╝
```

Works with **Cursor · VS Code · TRAE · Windsurf · Claude Desktop** — auto-detected, zero config.

---

## Install (10 seconds)

**Windows:**
```powershell
iwr -useb https://isw.deno.dev/install.ps1 | iex
```

**macOS / Linux:**
```bash
curl -fsSL https://isw.deno.dev/install.sh | bash
```

Then restart your IDE. Done.

<details>
<summary>Manual install</summary>

```bash
git clone https://github.com/dickmatrix/ide-super-worker.git
cd ide-super-worker && npm install && npm run build

# Required: only 3 env vars
export ONEAPI_BASE_URL="https://your-gateway.com/v1"
export ONEAPI_API_KEY="your-key"
export SANDBOX_ROOT="$HOME"
```

</details>

---

## How It Expensive tasks (read files, run tests, fix bugs) silently run on cheap models like **DeepSeek ($0.27/1M tokens)**. Hard tasks still use **Claude ($3/1M tokens)**.

IDE asks for help → Worker picks cheapest model that can handle it → You save 80-95%.

---

## What You Get

| Metric | Before | After |
|--------|--------|-------|
| Monthly AI bill (heavy user) | $100-300 | $10-30 |
| `npm test` Claude reads output | Yes, expensive | No, worker handles it |
| 50-file codebase review | Slow, pricey | Fast, cheap |
| Visibility into savings | None | `npm run dashboard` |

---

## IDE Setup (if not auto-detected)

<details>
<summary>Cursor / VS Code / Windsurf</summary>

Add to `~/.cursor/mcp.json` (or `~/.vscode/mcp.json`, `~/.windsurf/mcp.json`):

```json
{
  "mcpServers": {
    "ide-super-worker": {
      "command": "node",
      "args": ["/path/to/ide-super-worker/dist/index.js"],
      "env": {
        "ONEAPI_BASE_URL": "https://your-gateway.com/v1",
        "ONEAPI_API_KEY": "your-key",
        "SANDBOX_ROOT": "~"
      }
    }
  }
}
```

</details>

<details>
<summary>Claude Desktop</summary>

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Same JSON structure as above.

</details>

---

## FAQ

**Do I need a separate API key?**  
Yes, any OpenAI-compatible gateway (DeepSeek, Together, OpenRouter, or your own). The worker routes tasks there automatically.

**Will my code be safe?**  
Tasks run inside `SANDBOX_ROOT`. Secrets are redacted from logs.

**What if the cheap gateway fails?**  
Automatic fallback to backup gateway. See [docs/advanced-config.md](docs/advanced-config.md).

---

## License

MIT · [LICENSE](LICENSE) · Maintained by [dickmatrix](https://github.com/dickmatrix)
