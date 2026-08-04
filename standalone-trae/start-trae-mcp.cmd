@echo off
REM ===========================================================================
REM  IDE Super Worker - TRAE 专属 MCP 启动脚本
REM  功能: 为 TRAE MCP 实例设置独立的全局协调目录和资源限制
REM        使 TRAE 的 worker 任务不与 Codex / Claude / Kimi 争抢全局槽位
REM
REM  原理: env.ts 加载 .env 时不会覆盖已设置的环境变量。
REM        本脚本在启动 node 之前设置隔离变量，优先级高于 .env。
REM        其余变量 (API Key、网关地址、模型等) 仍从 .env 继承。
REM
REM  用法: 在 TRAE 的 MCP 服务器配置中，将 command 改为此脚本路径，
REM        args 改为空数组 (脚本内部已包含 node dist/index.js)。
REM        或者直接运行此脚本进行本地测试。
REM ===========================================================================

setlocal

set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

REM --- 隔离: 全局协调目录 (核心隔离点) ---
REM TRAE 使用独立目录，不与 Codex/Claude/Kimi 共享全局 FIFO 槽位
set "WORKER_GLOBAL_COORDINATION_DIR=%LOCALAPPDATA%/ide-super-worker/coordination-trae"

REM --- 隔离: 指标文件 ---
set "WORKER_METRICS_FILE=%PROJECT_ROOT%\.worker-metrics-trae.jsonl"

REM --- 隔离: 熔断器状态文件 ---
set "WORKER_TOOL_CIRCUIT_STATE_FILE=%PROJECT_ROOT%\.worker-circuit-state-trae.json"

REM --- 资源限制: 降低并发，避免抢占机器资源 ---
REM per-MCP 实例最大并发 job (低于 .env 的 6，给其他 agent 留余量)
set "MAX_RUNNING_JOBS=3"
REM TRAE 独立池中的全局 heavy 槽位 (不与其他 agent 共享)
set "WORKER_GLOBAL_HEAVY_MAX=1"
set "WORKER_GLOBAL_HEAVY_QUEUE_MAX=4"
REM TRAE 独立池中的全局 lite 槽位
set "WORKER_GLOBAL_LITE_MAX=1"
set "WORKER_GLOBAL_LITE_QUEUE_MAX=6"
REM 等待全局槽位的超时
set "WORKER_GLOBAL_ACQUIRE_TIMEOUT_MS=300000"

REM --- 以下变量不覆盖 .env 已有值，仅作为保底默认 ---
REM SANDBOX_ROOT、ONEAPI_BASE_URL、CLAUDE_MODEL 等均从 .env 继承

REM --- 启动 MCP 服务器 ---
node "%PROJECT_ROOT%\dist\index.js"

endlocal
