# TRAE 专属 MCP 配置

> 为 TRAE MCP 实例提供独立的全局协调目录和资源限制，不与 Codex / Claude / Kimi 争抢槽位。

## 问题背景

项目 `.env` 中 `WORKER_GLOBAL_COORDINATION_DIR` 指向共享路径：

```
%LOCALAPPDATA%/ide-super-worker/coordination
```

所有通过此 MCP 服务器启动的 agent（Codex、Claude、Kimi、TRAE）共享同一套
全局 FIFO 槽位。当 TRAE 启动 heavy job 时，会占用 `WORKER_GLOBAL_HEAVY_MAX`
（默认 1）的唯 一槽位，阻塞其他 agent 的任务，反之亦然。

## 隔离方案

`start-trae-mcp.cmd` 在启动 `node dist/index.js` 之前设置以下环境变量。
由于 `env.ts` 加载 `.env` 时**不覆盖已设置的变量**，这些值优先级高于 `.env`。

### 隔离变量

| 变量 | TRAE 专属值 | .env 默认值 (其他 agent 不变) |
| --- | --- | --- |
| `WORKER_GLOBAL_COORDINATION_DIR` | `...coordination-trae` | `...coordination` |
| `WORKER_METRICS_FILE` | `.worker-metrics-trae.jsonl` | `.worker-metrics.jsonl` |
| `WORKER_TOOL_CIRCUIT_STATE_FILE` | `.worker-circuit-state-trae.json` | `.worker-metrics.jsonl.state.json` |
| `MAX_RUNNING_JOBS` | 3 | 6 |
| `WORKER_GLOBAL_HEAVY_MAX` | 1 | 1 (默认) |
| `WORKER_GLOBAL_HEAVY_QUEUE_MAX` | 4 | 8 (默认) |

TRAE 实例拥有独立的全局槽位池，与 Codex/Claude 完全隔离。API Key、网关地址、
模型名称等其余配置仍从 `.env` 继承，无需重复配置。

## 配置方法

### 方式 A：通过 TRAE UI 更改 MCP 服务器命令

1. 打开 TRAE 设置 → MCP 服务器管理
2. 找到 `mcp_codex-async-worker` 服务器
3. 将启动命令改为：
   ```
   /path/to/ide-super-worker/standalone-trae/start-trae-mcp.cmd
   ```
4. 将参数清空（脚本内部已包含 `node dist/index.js`）
5. 保存并重启 MCP 服务器

### 方式 B：在 TRAE MCP 配置中直接设置环境变量

如果 TRAE 支持为 MCP 服务器设置自定义环境变量，直接添加以下变量即可
（无需使用包装脚本）：

```ini
WORKER_GLOBAL_COORDINATION_DIR=%LOCALAPPDATA%/ide-super-worker/coordination-trae
WORKER_METRICS_FILE=/path/to/ide-super-worker/.worker-metrics-trae.jsonl
WORKER_TOOL_CIRCUIT_STATE_FILE=/path/to/ide-super-worker/.worker-circuit-state-trae.json
MAX_RUNNING_JOBS=3
WORKER_GLOBAL_HEAVY_MAX=1
WORKER_GLOBAL_HEAVY_QUEUE_MAX=4
WORKER_GLOBAL_LITE_MAX=1
WORKER_GLOBAL_LITE_QUEUE_MAX=6
WORKER_GLOBAL_ACQUIRE_TIMEOUT_MS=300000
```

## 验证

配置完成后，通过 MCP `shell` 工具检查环境变量：

```
echo %WORKER_GLOBAL_COORDINATION_DIR%
```

预期输出包含 `coordination-trae`，而非共享的 `coordination`。

## 不受影响的配置

以下文件**不做任何修改**：

- `.env` — 其他 agent 的共享默认配置
- `standalone-codex/config.toml` — Codex 独立配置
- `standalone-codex/start-codex-worker.bat` — Codex 启动脚本
- `codex-mcp.example.toml` — 示例模板

## 清理

如需移除 TRAE 隔离配置，删除以下文件即可：

- `standalone-trae/` 目录
- `.worker-metrics-trae.jsonl`
- `.worker-circuit-state-trae.json`
- `%LOCALAPPDATA%/ide-super-worker/coordination-trae/` 目录
