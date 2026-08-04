import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import * as path from "node:path";

async function main(): Promise<void> {
  const cwd = path.resolve(process.cwd());
  const transport = new StdioClientTransport({
    command: "node",
    args: ["dist/index.js"],
    cwd,
    env: {
      ...process.env,
      SANDBOX_ROOT: cwd,
      ONEAPI_BASE_URL: process.env.ONEAPI_BASE_URL || "https://gateway.example.test/v1",
      ONEAPI_API_KEY: process.env.ONEAPI_API_KEY || "unit-test-api-key"
    }
  });

  const client = new Client({ name: "codex-worker-smoke", version: "1.0.0" }, { capabilities: {} });
  await client.connect(transport);

  const tools = await client.listTools();
  const names = tools.tools.map((tool) => tool.name).sort();
  const expected = [
    "apply_edits",
    "cancel",
    "diff_digest",
    "draft",
    "get",
    "get_artifact_slice",
    "history",
    "read_pack",
    "search",
    "shell",
    "start",
    "tail",
    "wait"
  ];
  if (JSON.stringify(names) !== JSON.stringify(expected)) {
    throw new Error(`Unexpected tools: ${names.join(", ")}`);
  }
  const startSchema = tools.tools.find((tool) => tool.name === "start")?.inputSchema as any;
  if (
    startSchema?.properties?.verification_policy?.properties?.task_kind?.enum?.join(",") !==
      "read_only,modifying" ||
    !String(startSchema?.properties?.semantic_gate?.description || "").includes("independent semantic reviewer")
  ) {
    throw new Error("Expected start schema to expose verification_policy and the real semantic reviewer contract");
  }

  for (const name of ["analyze", "review"]) {
    const stale = await client.callTool({ name, arguments: {} });
    if (stale.isError) throw new Error(`Expected stale ${name} calls to return a structured payload`);
    const staleContent = Array.isArray(stale.content) ? (stale.content as Array<{ text?: unknown }>) : [];
    const stalePayload = JSON.parse(String(staleContent[0]?.text || "{}"));
    if (
      stalePayload.contract_version !== "outcome.v1" ||
      stalePayload.status !== "error" ||
      stalePayload.category !== "unknown" ||
      stalePayload.error?.message !== `Tool not found: ${name}`
    ) {
      throw new Error(`Expected stale ${name} calls to return Tool not found without closing the transport`);
    }
  }
  if ((await client.listTools()).tools.length !== expected.length) {
    throw new Error("Expected the transport to stay connected after stale tool calls");
  }

  const missing = await client.callTool({ name: "get", arguments: { job_id: "missing-job" } });
  if (missing.isError) {
    throw new Error("Expected get(missing-job) to return a structured error payload, not MCP isError");
  }
  const missingContent = Array.isArray(missing.content) ? (missing.content as Array<{ text?: unknown }>) : [];
  const missingPayload = JSON.parse(String(missingContent[0]?.text || "{}"));
  if (
    missingPayload.status !== "ok" ||
    missingPayload.degraded !== true ||
    missingPayload.degradation_reason !== "job_not_found_or_expired" ||
    !missingPayload.fallback?.action ||
    missingPayload.receipt?.status !== "ok"
  ) {
    throw new Error("Expected get(missing-job) to return the structured degraded payload");
  }

  const badSearch = await client.callTool({ name: "search", arguments: { pattern: "never-matches", dirs: [path.join(cwd, "__missing__")] } });
  if (badSearch.isError) {
    throw new Error("Expected search(bad-dir) to return a structured rejection payload, not MCP isError");
  }
  const badSearchContent = Array.isArray(badSearch.content) ? (badSearch.content as Array<{ text?: unknown }>) : [];
  const badSearchPayload = JSON.parse(String(badSearchContent[0]?.text || "{}"));
  if (
    badSearchPayload.degraded !== true ||
    !String(badSearchPayload.degradation_reason || "").includes("missing or inaccessible") ||
    badSearchPayload.count !== 0 ||
    badSearchPayload.receipt?.status !== "ok"
  ) {
    throw new Error("Expected search(bad-dir) to return the structured degraded payload");
  }

  await client.close();
  console.log(`smoke passed: ${names.join(", ")}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
