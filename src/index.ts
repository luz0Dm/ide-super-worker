import "./env.js"; // must run before any module reads process.env (e.g. config.ts)
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { IDLE_EXIT_MS } from "./config.js";
import { runningJobCount } from "./jobs.js";
import { createCodexWorkerServer, shutdownRunningJobs } from "./server.js";
import { startToolErrorReviewLoop, stopToolErrorReviewLoop } from "./tool_error_control.js";

const server = createCodexWorkerServer();
const transport = new StdioServerTransport();
let idleTimer: NodeJS.Timeout | undefined;
let terminationPromise: Promise<void> | undefined;

function clearIdleTimer(): void {
  if (!idleTimer) return;
  clearTimeout(idleTimer);
  idleTimer = undefined;
}

function terminate(exitCode = 0): Promise<void> {
  terminationPromise ??= (async () => {
    clearIdleTimer();
    process.stdin.off("data", scheduleIdleExit);
    stopToolErrorReviewLoop();
    await shutdownRunningJobs();
    try {
      await server.close();
    } catch {
      // The transport may already be closed by the client.
    }
    process.exit(exitCode);
  })();
  return terminationPromise;
}

function scheduleIdleExit(): void {
  clearIdleTimer();
  if (IDLE_EXIT_MS === 0 || terminationPromise) return;
  idleTimer = setTimeout(() => {
    if (runningJobCount() > 0) {
      scheduleIdleExit();
      return;
    }
    void terminate();
  }, IDLE_EXIT_MS);
  idleTimer.unref?.();
}

process.stdin.on("data", scheduleIdleExit);
transport.onclose = () => void terminate();

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.once(signal, () => {
    void terminate();
  });
}

server
  .connect(transport)
  .then(() => {
    scheduleIdleExit();
    try {
      startToolErrorReviewLoop();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const stack = error instanceof Error && error.stack ? `\n${error.stack}` : "";
      console.error(`[warn][tool-error-control] review loop not started: ${message}${stack}`);
    }
  })
  .catch((error) => {
    console.error(error);
    void terminate(1);
  });
