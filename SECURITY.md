# Security Policy

## Supported Versions

The public repository tracks the latest release only until a formal release process is established.

## Reporting A Vulnerability

Open a private security advisory on GitHub, or contact the maintainer through the repository issue tracker and request a private disclosure channel. Do not post exploit details or live credentials in public issues.

## Operational Notes

- Never commit `.env`, real provider keys, GitHub tokens, terminal logs, or generated archives.
- Rotate any credential that was pasted into chat, shell history, issue text, or logs.
- Keep `SANDBOX_ROOT` narrow. The worker refuses paths outside this root.
- Prefer `scoped_patch` for write tasks so out-of-scope edits are marked failed.
- Keep `ALLOW_BYPASS_PERMISSIONS` disabled unless you fully trust the caller.
- Use HTTPS provider endpoints outside private networks.
- Treat third-party model gateways as data processors for the prompts and files
  you send through `start`, a configured semantic gate, or the legacy worker-LLM
  lane.

## Built-In Guardrails

- Secret redaction for common API key variables and bearer tokens.
- Realpath-based sandbox checks.
- Optional scoped patch enforcement.
- Deterministic `search`, `read_pack`, `diff_digest`, and `shell` evidence
  paths; analysis, judgment, and code review remain in the main model by default.
- Public evidence routing is limited to deterministic tools such as
  `read_pack`, `diff_digest`, and `get_artifact_slice`; historical
  quality/fan-out modules have no public MCP entry point.
- Semantic verification is a separate post-execution gate and does not enable
  general worker analysis or review.
- Optional git worktree isolation for parallel jobs.
