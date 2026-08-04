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
const BASELINE_MODEL = process.env.BASELINE_MODEL || "claude-sonnet";

// --- Pricing (USD per 1M tokens) ---
const PRICING: Record<string, { input: number; output: number; cache: number; label: string }> = {
  "claude-sonnet": { input: 3.0, output: 15.0, cache: 0.3, label: "Claude Sonnet" },
  "claude-opus": { input: 15.0, output: 75.0, cache: 1.5, label: "Claude Opus" },
  "gpt-4o": { input: 2.5, output: 10.0, cache: 1.25, label: "GPT-4o" },
  "gpt-4-turbo": { input: 10.0, output: 30.0, cache: 2.5, label: "GPT-4 Turbo" },
  "deepseek-chat": { input: 0.27, output: 1.10, cache: 0.07, label: "DeepSeek" },
  "deepseek-v4-flash": { input: 0.27, output: 1.10, cache: 0.07, label: "DeepSeek" },
  "deepseek-v4-pro": { input: 0.435, output: 0.87, cache: 0.0036, label: "DeepSeek Pro" },
  "qwen": { input: 0.27, output: 1.10, cache: 0.07, label: "Qwen" },
  "auto": { input: 0.50, output: 1.50, cache: 0.10, label: "Mixed" },
};

// --- Goals ---
const COFFEE_PRICE = 4.50;
const STARTER_SAVINGS_TARGET = 5.0;
const MONTHLY_GROWTH_RATE = 0.15;

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
  coffeeCups: number;
  projectPerDay: number;
  daysToTarget: number;
  firstSeen: string;
  lastSeen: string;
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
  let firstSeen = "";
  let lastSeen = "";

  for (const row of rows) {
    const prompt = row.prompt_tokens || 0;
    const completion = row.completion_tokens || 0;
    const cached = row.cached_tokens || 0;
    totalPromptTokens += prompt;
    totalCompletionTokens += completion;
    totalCacheTokens += cached;

    // Track time range
    if (!firstSeen || row.ts < firstSeen) firstSeen = row.ts;
    if (!lastSeen || row.ts > lastSeen) lastSeen = row.ts;

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

  const totalSavings = baselineCost - actualCost;
  const coffeeCups = Math.floor(totalSavings / COFFEE_PRICE);
  const daysSinceFirst = firstSeen
    ? Math.max(1, (now - new Date(firstSeen).getTime()) / oneDayMs)
    : 1;
  const projectPerDay = totalSavings / daysSinceFirst;
  const daysToTarget =
    projectPerDay > 0 ? Math.max(0, Math.ceil((STARTER_SAVINGS_TARGET - totalSavings) / projectPerDay)) : 0;

  return {
    totalCalls: rows.length,
    totalPromptTokens,
    totalCompletionTokens,
    totalCacheTokens,
    costWithBaseline: baselineCost,
    costWithWorker: actualCost,
    totalSavings,
    savingsPercent: baselineCost > 0 ? ((baselineCost - actualCost) / baselineCost) * 100 : 0,
    coffeeCups,
    projectPerDay,
    daysToTarget,
    firstSeen,
    lastSeen,
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
  lines.push("  ===============================================");
  lines.push("    IDE Super Worker - Cost Savings Dashboard");
  lines.push("  ===============================================");
  lines.push("");
  lines.push("    " + drawBar(stats.savingsPercent) + " " + stats.savingsPercent.toFixed(0) + "% saved");
  lines.push("");
  lines.push("    Saved this month:    " + padRight(formatCurrency(stats.totalSavings), 18) + emojiForSavings(stats.totalSavings));
  lines.push("    Would have cost:     " + padRight(formatCurrency(stats.costWithBaseline), 18) + "without worker");
  lines.push("    Actually spent:      " + padRight(formatCurrency(stats.costWithWorker), 18) + "with worker");
  lines.push("");
  lines.push("  -----------------------------------------------");
  lines.push("    REWARD EQUIVALENTS");
  lines.push("  -----------------------------------------------");
  lines.push("");
  if (stats.coffeeCups > 0) {
    lines.push("    That's " + stats.coffeeCups + " cups of coffee."
              + (stats.coffeeCups >= 3 ? " Go grab one!" : " Keep going!"));
  } else {
    lines.push("    " + formatCurrency(STARTER_SAVINGS_TARGET - stats.totalSavings)
              + " to your first cup of coffee.");
    if (stats.daysToTarget > 0 && stats.daysToTarget <= 7) {
      lines.push("    At this rate: " + stats.daysToTarget + " day" + (stats.daysToTarget > 1 ? "s" : "") + " to go.");
    }
  }
  lines.push("");
  lines.push("  -----------------------------------------------");
  lines.push("    ACTIVITY");
  lines.push("  -----------------------------------------------");
  lines.push("");
  lines.push("    Total calls:         " + padRight(stats.totalCalls.toString(), 10)
            + "24h calls: " + stats.last24h.calls);
  lines.push("    Total tokens:        " + padRight(formatTokens(stats.totalPromptTokens + stats.totalCompletionTokens), 10)
            + "24h saved: " + formatCurrency(stats.last24h.savings));

  const modelEntries = Object.entries(stats.byModel);
  if (modelEntries.length > 0) {
    lines.push("");
    lines.push("  -----------------------------------------------");
    lines.push("    MODELS USED");
    lines.push("  -----------------------------------------------");
    lines.push("");
    for (const [model, data] of modelEntries) {
      const pricing = PRICING[model];
      const label = pricing ? pricing.label : model;
      lines.push("    " + padRight(label, 20)
                + padRight(formatTokens(data.tokens), 8)
                + formatCurrency(data.cost));
    }
  }

  const sortedTools = Object.entries(stats.topTools)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  if (sortedTools.length > 0) {
    lines.push("");
    lines.push("  -----------------------------------------------");
    lines.push("    TOP TOOLS");
    lines.push("  -----------------------------------------------");
    lines.push("");
    for (const [tool, tokens] of sortedTools) {
      lines.push("    " + padRight(tool, 20) + formatTokens(tokens));
    }
  }

  lines.push("");
  lines.push("  ===============================================");
  lines.push("  Press 'q' to quit  |  Auto-refreshes every 5s");
  lines.push("");
  return lines.join("\n");
}

function emojiForSavings(savings: number): string {
  if (savings >= 20) return "  That's a pizza.";
  if (savings >= 10) return "  Nice.";
  if (savings >= 5) return "  Keep going!";
  return "";
}

function padRight(s: string, n: number): string {
  while (s.length < n) s += " ";
  return s;
}

function renderNoData(): string {
  return [
    "",
    "  ===============================================",
    "    IDE Super Worker - Cost Savings Dashboard",
    "  ===============================================",
    "",
    "  Waiting for your first AI coding calls...",
    "",
    "  Use your IDE normally. The worker will track",
    "  every cheap call and show your savings here.",
    "",
    "  Expected savings: 80-95% on bulk tasks.",
    "",
    "  Just saved enough for:",
    "    [] Coffee   ($4.50) - coming soon!",
    "",
    "  Press 'q' to quit  |  Auto-refreshes every 5s",
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
