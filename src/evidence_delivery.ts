import { attachReceipt, saveArtifact } from "./artifacts.js";
import type { SearchResult } from "./search.js";
import type { WorkerReceipt } from "./types.js";

export const INLINE_RESPONSE_MAX_BYTES = 16_000;
export const CONTEXT_PACK_INLINE_MAX_BYTES = INLINE_RESPONSE_MAX_BYTES;

export interface ContextPackSlice {
  start: number;
  end: number;
  text: string;
}

export interface ContextPackFile extends Record<string, unknown> {
  file: string;
  bytes: number;
  slices: ContextPackSlice[];
}

export interface ContextPackPayload extends Record<string, unknown> {
  task: string;
  mode: "zero_llm_symbol_slices";
  files: ContextPackFile[];
  file_count: number;
  packed_bytes: number;
  truncated: boolean;
}

function byteLength(value: unknown): number {
  return Buffer.byteLength(JSON.stringify(value), "utf8");
}

function compactContextPack(full: ContextPackPayload): ContextPackPayload {
  if (byteLength(full) <= CONTEXT_PACK_INLINE_MAX_BYTES) return full;

  const compact: ContextPackPayload = {
    ...full,
    files: full.files.map((file) => ({
      file: file.file,
      bytes: file.bytes,
      slices: []
    })),
    truncated: true
  };

  if (byteLength(compact) > CONTEXT_PACK_INLINE_MAX_BYTES) {
    throw new Error("read_pack metadata exceeds the 16000 byte inline budget; narrow the path list");
  }

  outer: for (let fileIndex = 0; fileIndex < full.files.length; fileIndex += 1) {
    for (const slice of full.files[fileIndex].slices) {
      compact.files[fileIndex].slices.push(slice);
      if (byteLength(compact) > CONTEXT_PACK_INLINE_MAX_BYTES) {
        compact.files[fileIndex].slices.pop();
        break outer;
      }
    }
  }

  return compact;
}

export function deliverContextPack(
  input: Record<string, unknown>,
  full: ContextPackPayload
): ContextPackPayload & { receipt: WorkerReceipt } {
  const artifact = saveArtifact("read_pack", full);
  if (!artifact) {
    throw new Error("read_pack could not persist its evidence artifact");
  }

  const compact = compactContextPack(full);
  return attachReceipt(compact, {
    tool: "read_pack",
    category: "context_pack",
    input,
    output: compact,
    artifactRefs: [artifact.artifact_ref],
    truncated: compact.truncated
  });
}

export function deliverSearchResult(
  input: Record<string, unknown>,
  full: SearchResult
): SearchResult & { receipt: WorkerReceipt } {
  const artifact = saveArtifact("search", full);
  if (!artifact) {
    throw new Error("search could not persist its evidence artifact");
  }

  let inlineCount = full.results.length;
  while (true) {
    const compact: SearchResult = {
      ...full,
      results: full.results.slice(0, inlineCount),
      truncated: full.truncated || inlineCount < full.results.length
    };
    const delivered = attachReceipt(compact as SearchResult & Record<string, unknown>, {
      tool: "search",
      category: "search",
      input,
      output: full,
      artifactRefs: [artifact.artifact_ref],
      truncated: compact.truncated
    });
    if (byteLength(delivered) <= INLINE_RESPONSE_MAX_BYTES) {
      return delivered as SearchResult & { receipt: WorkerReceipt };
    }
    if (inlineCount === 0) {
      throw new Error("search metadata exceeds the 16000 byte inline budget; narrow the search input");
    }
    inlineCount = Math.max(0, Math.min(inlineCount - 1, Math.floor(inlineCount * 0.8)));
  }
}
