/**
 * IDE Super Worker - Real-time Cost Savings Dashboard
 * Shows live metrics on how much money the worker is saving you
 *
 * Usage: npm run dashboard
 *        node dist/dashboard.js
 */

import * as fs from "node:fs";
import * as path from "node:path";
import * as readline from "node:readline";

// --- Configuration ---
const METRICS_FILE = process.env.WORKER_METRICS_FILE || path.join(process.cwd(), ".worker-metrics.jsonl");

// --- Pricing (USD per 1M tokens) ---
const PRICING: Record<string, { input: number; output: number; cache: number }> = {
  // Baseline: expensive models you'd otherwise use
  "claude-sonnet": { input: 3.0, output: 15.0, cache: 0.3 },
  "claude-opus": { input: 15.0, output: 75.0, cache: 1.5 },
  "gpt-4o": { input: 2.5, output: 10.0, cache: 1.25 },
  "gpt-4-turbo": { input: 10.0, output: 30.0, cache: 2.5 },
  // Cheap models the worker actually uses
  "deepseek-v4-flash": { input: 0.27, output: 1.10, cache: 0.07 },
  "deepseek-v4-pro": { input: 0.435, output: 0.87, cache: 0.0036 },
  "qwen": { input: 0.27, output: 1.10, cache: 0.07 },
};

const BASELINE_MODEL = process.env.BASELINE_MODEL || "claude-sonnet";

// --- Types ---
interface MetricsRow {
  ts: string;
  event: string;
  tool?: string;
  route?: string;
  prompt_tokens?: number;
  completion_tokens?: number;
  cached_tokens?: number;
  model?: string;
  category?: string;
}

interface SavingsStats {
  totalCalls: number;
  totalPromptTokens: number;
  totalCompletionTokens: number;
  totalCacheTokens: number;
  costWithBaseline: number;
  costWithWorker: number;
  totalSavings: number;
  savingsPercent: number;
  last24h: { calls: number; savings: number };
  topTools: Record<string, number>;
  byModel: Record<string, { tokens: number; cost: number }>;
}

// --- Functions ---
function parseMetrics(): MetricsRow[] {
  if (!fs.existsSync(METRICS_FILE)) return [];
  const lines = fs.readFileSync(METRICS_FILE, "utf-8").trim().split("\n");
  const rows: MetricsRow[] = [];
  for (const line of lines) {
    try {
      const row = JSON.parse(line);
      if (row.event === "upstream_call" || row.event === "tool_call") {
        rows.push(row);
      }
    } catch {
      // skip malformed lines
    }
  }
  return rows;
}

function calculateSavings(rows: MetricsRow[]): SavingsStats {
  const baseline = PRICING[BASELINE_MODEL] || PRICING["claude-sonnet"];
  let totalPromptTokens = 0;
  let totalCompletionTokens = 0;
  let totalCacheTokens = 0;
  let actualCost = 0;
  let baselineCost = 0;
  const topTools: Record<string, number> = {};
  const byModel: Record<string, { tokens: number; cost: number }> = {};
  let last24hCalls = 0;
  let last24hSavings = 0;
  const now = Date.now();
  const oneDayMs = 24 * 60 * 60 * 1000;

  for (const row of rows) {
    const prompt = row.prompt_tokens || 0;
    const completion = row.completion_tokens || 0;
    const cached = row.cached_tokens || 0;
    totalPromptTokens += prompt;
    totalCompletionTokens += completion;
    totalCacheTokens += cached;

    const modelName = row.model || "deepseek-v4-flash";
    const modelPricing = PRICING[modelName] || PRICING["deepseek-v4-flash"];
    const actualCallCost =
      (prompt * modelPricing.input) / 1_000_000 +
      (completion * modelPricing.output) / 1_000_000 +
      (cached * modelPricing.cache) / 1_000_000;
    const baselineCallCost =
      (prompt * baseline.input) / 1_000_000 +
      (completion * baseline.output) / 1_000_000 +
      (cached * baseline.cache) / 1_000_000;

    actualCost += actualCallCost;
    baselineCost += baselineCallCost;

    if (!byModel[modelName]) {
      byModel[modelName] = { tokens: 0, cost: 0 };
    }
    byModel[modelName].tokens += prompt + completion;
    byModel[modelName].cost += actualCallCost;

    const tool = row.tool || "unknown";
    topTools[tool] = (topTools[tool] || 0) + (prompt + completion);

    const rowTime = new Date(row.ts).getTime();
    if (now - rowTime < oneDayMs) {
      last24hCalls++;
      last24hSavings += baselineCallCost - actualCallCost;
    }
  }

  return {
    totalCalls: rows.length,
    totalPromptTokens,
    totalCompletionTokens,
    totalCacheTokens,
    costWithBaseline: baselineCost,
    costWithWorker: actualCost,
    totalSavings: baselineCost - actualCost,
    savingsPercent: baselineCost > 0 ? ((baselineCost - actualCost) / baselineCost) * 100 : 0,
    last24h: { calls: last24hCalls, savings: last24hSavings },
    topTools,
    byModel,
  };
}

function formatCurrency(amount: number): string {
  if (amount < 0.01) return `$${amount.toFixed(6)}`;
  if (amount < 1) return `$${amount.toFixed(4)}`;
  return `$${amount.toFixed(2)}`;
}

function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toString();
}

function drawBar(percent: number, width: number = 30): string {
  const filled = Math.round((Math.min(percent, 100) / 100) * width);
  const empty = width - filled;
  return "█".repeat(filled) + "░".repeat(empty);
}

function renderDashboard(stats: SavingsStats): string {
  const lines: string[] = [];
  lines.push("");
  lines.push("╔══════════════════════════════════════════════════════════╗");
  lines.push("║          IDE Super Worker - Cost Savings Dashboard      ║");
  lines.push("╠══════════════════════════════════════════════════════════╣");
  lines.push("║                                                        ║");
  lines.push(`║  TOTAL SAVINGS: ${formatCurrency(stats.totalSavings).padEnd(10)} ${drawBar(stats.savingsPercent)} ${stats.savingsPercent.toFixed(0)}%  ║`);
  lines.push("║                                                        ║");
  lines.push(`║  You would have spent:  ${formatCurrency(stats.costWithBaseline).padEnd(12)}                       ║`);
  lines.push(`║  You actually spent:    ${formatCurrency(stats.costWithWorker).padEnd(12)}                       ║`);
  lines.push("║                                                        ║");
  lines.push("╠══════════════════════════════════════════════════════════╣");
  lines.push(`║  Total API Calls:     ${stats.totalCalls.toString().padEnd(12)}                       ║`);
  lines.push(`║  Total Tokens:        ${formatTokens(stats.totalPromptTokens + stats.totalCompletionTokens).padEnd(12)}                       ║`);
  lines.push(`║  Input Tokens:        ${formatTokens(stats.totalPromptTokens).padEnd(12)}                       ║`);
  lines.push(`║  Output Tokens:       ${formatTokens(stats.totalCompletionTokens).padEnd(12)}                       ║`);
  lines.push("║                                                        ║");
  lines.push("╠══════════════════════════════════════════════════════════╣");
  lines.push("║  Last 24 Hours:                                        ║");
  lines.push(`║    Calls: ${stats.last24h.calls.toString().padEnd(8)}  Savings: ${formatCurrency(stats.last24h.savings).padEnd(12)}             ║`);
  lines.push("║                                                        ║");

  const modelEntries = Object.entries(stats.byModel);
  if (modelEntries.length > 0) {
    lines.push("╠══════════════════════════════════════════════════════════╣");
    lines.push("║  Models Used:                                          ║");
    for (const [model, data] of modelEntries) {
      const shortModel = model.length > 20 ? model.slice(0, 17) + "..." : model;
      lines.push(`║    ${shortModel.padEnd(22)} ${formatTokens(data.tokens).padEnd(8)} ${formatCurrency(data.cost).padEnd(8)}     ║`);
    }
    lines.push("║                                                        ║");
  }

  const sortedTools = Object.entries(stats.topTools)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  if (sortedTools.length > 0) {
    lines.push("╠══════════════════════════════════════════════════════════╣");
    lines.push("║  Top Tools:                                            ║");
    for (const [tool, tokens] of sortedTools) {
      lines.push(`║    ${tool.padEnd(20)} ${formatTokens(tokens).padEnd(10)}                    ║`);
    }
  }

  lines.push("║                                                        ║");
  lines.push("╚══════════════════════════════════════════════════════════╝");
  lines.push("");
  lines.push("  Press 'q' to quit | Auto-refreshes every 5 seconds");
  lines.push("");
  return lines.join("\n");
}

function renderNoData(): string {
  return [
    "",
    "╔══════════════════════════════════════════════════════════╗",
    "║          IDE Super Worker - Cost Savings Dashboard      ║",
    "╠══════════════════════════════════════════════════════════╣",
    "║                                                        ║",
    "║  No metrics data found yet.                            ║",
    "║                                                        ║",
    "║  Start using your AI assistant normally. The worker    ║",
    "║  will automatically track your savings.               ║",
    "║                                                        ║",
    "║  Expected savings: 80-95% on bulk read/edit tasks      ║",
    "║                                                        ║",
    "╚══════════════════════════════════════════════════════════╝",
    "",
  ].join("\n");
}

// --- Main ---
function main(): void {
  if (!fs.existsSync(METRICS_FILE)) {
    console.log(renderNoData());
    process.exit(0);
  }

  let lastSize = 0;
  const refresh = () => {
    try {
      const stats = fs.statSync(METRICS_FILE);
      if (stats.size === lastSize) return;
      lastSize = stats.size;
      const rows = parseMetrics();
      const savings = calculateSavings(rows);
      console.clear();
      console.log(renderDashboard(savings));
    } catch {
      // ignore transient errors
    }
  };

  refresh();
  const interval = setInterval(refresh, 5000);

  try {
    fs.watchFile(METRICS_FILE, { interval: 2000 }, refresh);
  } catch {
    // watch not critical
  }

  readline.emitKeypressEvents(process.stdin);
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }

  process.stdin.on("keypress", (_str, key) => {
    if (key.name === "q" || (key.ctrl && key.name === "c")) {
      clearInterval(interval);
      try {
        fs.unwatchFile(METRICS_FILE);
      } catch {
        // ignore
      }
      console.log("\nDashboard closed. Savings will continue tracking in the background.\n");
      process.exit(0);
    }
  });
}

main();
