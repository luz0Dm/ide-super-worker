# AGENTS.md - IDE Super Worker Routing Rules

This repository exists to reduce premium Codex context usage. Treat worker
routing as part of the task, not as an optional optimization.

## Routing Contract

防降智三原则：证据归 worker，判断归主模型；summary/digest 是线索不是结论；关键 diff 主模型亲审。

- 本仓 MCP 默认使用 `WORKER_LITE_LLM=0`（纯证据模式）。
- Before repository-wide search, bulk file reads, review, diffs, test output, or
  implementation loops, expose `mcp__codex_async_worker` tools with
  `tool_search` if they are not already callable.
- Use `mcp__codex_async_worker.search` for repo discovery instead of main-thread
  `rg` when the output could be more than a few lines.
- Evidence tools are deterministic and high-fidelity; use them freely:
  `read_pack`, `diff_digest`, `shell` (with `digest:true` for tests/builds/lint),
  `history`, `apply_edits`, `get_artifact_slice`.
- Public evidence routing uses `read_pack`, `diff_digest`, and
  `get_artifact_slice`; analysis, judgment, and code review belong to the main
  model. The historical worker-LLM analyze/review and quality/fan-out modules
  have no public MCP entry point.
- `WORKER_LITE_LLM=1` enables only the remaining explicitly gated gateway
  features, such as failure diagnosis, diff red-team judgment, and `draft`.
- `semantic_gate` is a separate post-execution verification control. Callers
  may set it explicitly, and documented tool-error self-heal may raise later
  `start` calls to `warn`; neither moves general analysis or code review back
  to the worker.
- Shell digests, failure digests, and job `summary` are leads, not verdicts.
  Acceptance decisions use only `outcome.status` / `outcome.reason_codes`,
  `checks`, scope, and the diff itself.
- Use `mcp__codex_async_worker.start` for implementation loops with
  `verification_policy`, scoped paths, and explicit checks. For critical
  changes, set `include_diff:true` (or read the diff artifact via
  `get_artifact_slice`) and review the full diff in the main thread before
  accepting; for mechanical tasks `include_diff:false` is fine.
- Keep `WORKER_FAILURE_DIGEST` off and `diff_digest` red_team off. Do not
  enable legacy worker-LLM judgment merely to satisfy routing metrics.
- Use `mcp__codex_async_worker.diff_digest`, then fetch only required ranges
  through `get_artifact_slice`, before ingesting full diffs.

## Main-Thread Budget

Keep the main Codex thread for planning, analysis, decisions, code review, small
verification, and final integration. Do not use main-thread shell or file reads
as a substitute for worker tools when the task is large enough to affect context
usage.

## Audits

- Run `npm run codex:audit -- --since-minutes=60` when checking whether recent
  work is being routed through the worker.
- Run `npm run stats:gate` for the existing metrics gate.
- Do not require or optimize an analysis/review worker-share ratio; those
  judgments intentionally remain in the main model.
- Remember that worker metrics can only see worker/tool audit rows. Direct
  main-thread file reads, shell output, and chat context are outside the metrics
  file unless explicitly instrumented.

## Mythos Gate

- 重型或高风险任务在最终结论前必须使用 `$mythos` 执行 `optimize` 或 `gate`。
- 重型任务包括整仓/多文件修改、根因诊断、架构迁移、安全认证、发布门禁和多来源研究。
