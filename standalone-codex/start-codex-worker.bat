@echo off
REM ===========================================================================
REM  Codex Async Worker - 独立启动脚本
REM  功能: 临时替换 codex config.toml 为此项目专属配置，退出后自动恢复
REM  不影响原有 Codex 配置
REM ===========================================================================

setlocal EnableDelayedExpansion

set "CODEX_HOME=%USERPROFILE%\.codex"
set "CODEX_CONFIG=%CODEX_HOME%\config.toml"
set "BACKUP_CONFIG=%CODEX_HOME%\config.toml.bak.standalone"
set "WORKER_CONFIG=d:\知识库\_Areas（长期领域）\mcp-codex-worker-rewrite\standalone-codex\config.toml"

REM 检查 worker 配置文件是否存在
if not exist "%WORKER_CONFIG%" (
    echo [ERROR] 找不到 Worker 配置文件: %WORKER_CONFIG%
    pause
    exit /b 1
)

REM 备份当前 codex config（如果存在且未备份）
if exist "%CODEX_CONFIG%" (
    if not exist "%BACKUP_CONFIG%" (
        echo [INFO] 备份原有 Codex 配置...
        copy /Y "%CODEX_CONFIG%" "%BACKUP_CONFIG%" >nul
        echo [INFO] 已备份到: %BACKUP_CONFIG%
    ) else (
        echo [INFO] 备份已存在，跳过: %BACKUP_CONFIG%
    )
) else (
    echo [INFO] 原有 config.toml 不存在，无需备份
)

REM 复制 worker 配置到 codex 目录
echo [INFO] 启用 Worker 专属配置...
copy /Y "%WORKER_CONFIG%" "%CODEX_CONFIG%" >nul

REM 设置 API Keys 环境变量（替换为你自己的 key）
set "ONEAPI_API_KEY=your-oneapi-key-here"
set "FALLBACK_API_KEY=your-fallback-key-here"

echo ===========================================================================
echo   Codex Async Worker - 独立模式启动
echo   配置文件: %WORKER_CONFIG%
echo   MCP路径:  d:\知识库\_Areas（长期领域）\mcp-codex-worker-rewrite\dist\index.js
echo ===========================================================================
echo.
echo 按 Ctrl+C 退出时将自动恢复原有 Codex 配置...
echo.

REM 启动 Codex
call codex

REM === Codex 退出后 ===
echo.
echo [INFO] Codex 已退出，恢复原有配置...

if exist "%BACKUP_CONFIG%" (
    copy /Y "%BACKUP_CONFIG%" "%CODEX_CONFIG%" >nul
    del "%BACKUP_CONFIG%" >nul 2>&1
    echo [INFO] 已恢复原有 Codex 配置
) else (
    echo [WARN] 找不到备份文件，配置未恢复
)

echo [INFO] 完成
timeout /t 3
