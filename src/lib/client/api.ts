/**
 * Browser-side typed fetch helpers for `/api/repo/*` endpoints and multi-rule prompt composition.
 */
import type {
  CommitDetail,
  CommitListResponse,
  FilePayload,
  RawFilePayload,
  RepoTree,
  SearchIndex,
} from "@/lib/types";

/** Client error carrying the HTTP status returned by a Next.js API route handler. */
export class ApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function requestJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  const response = await fetch(url, {
    signal,
    headers: { Accept: "application/json" },
    cache: "no-store",
  });

  let data: unknown = null;

  try {
    data = await response.json();
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new ApiError("The server returned an unreadable response.", response.status);
    }
    throw error;
  }

  if (!response.ok) {
    const message =
      data && typeof data === "object" && "error" in data && typeof data.error === "string"
        ? data.error
        : `Request failed with status ${response.status}.`;
    throw new ApiError(message, response.status);
  }

  return data as T;
}

/** Fetches the classified repository tree snapshot. */
export function fetchTree(signal?: AbortSignal): Promise<RepoTree> {
  return requestJson<RepoTree>("/api/repo/tree", signal);
}

/** Fetches parsed file content, Shiki HTML, JSONC entries, and metadata for one path. */
export function fetchFile(path: string, signal?: AbortSignal): Promise<FilePayload> {
  const params = new URLSearchParams({ path });
  return requestJson<FilePayload>(`/api/repo/file?${params.toString()}`, signal);
}

/** Fetches unhighlighted raw file text at the default branch or a historical commit SHA. */
export function fetchRawFile(path: string, ref?: string): Promise<RawFilePayload> {
  const params = new URLSearchParams({ path, raw: "1" });
  if (ref) {
    params.set("ref", ref);
  }
  return requestJson<RawFilePayload>(`/api/repo/file?${params.toString()}`);
}

/** Fetches paginated repository commit summaries, optionally filtered to a single file path. */
export function fetchCommits(options: {
  path?: string;
  page?: number;
  perPage?: number;
  signal?: AbortSignal;
}): Promise<CommitListResponse> {
  const params = new URLSearchParams({
    page: String(options.page ?? 1),
    per_page: String(options.perPage ?? 30),
  });
  if (options.path) {
    params.set("path", options.path);
  }
  return requestJson<CommitListResponse>(
    `/api/repo/commits?${params.toString()}`,
    options.signal,
  );
}

/** Fetches parsed unified diff details for a specific commit SHA. */
export function fetchCommit(sha: string, signal?: AbortSignal): Promise<CommitDetail> {
  return requestJson<CommitDetail>(`/api/repo/commits/${sha}`, signal);
}

/** Fetches the pre-indexed JSON keys, Markdown headings, and token estimates for search. */
export function fetchSearchIndex(signal?: AbortSignal): Promise<SearchIndex> {
  return requestJson<SearchIndex>("/api/repo/index", signal);
}

/** Fetches selected AI rule files in parallel and concatenates them with HTML source markers. */
export async function buildCombinedPrompt(paths: string[]): Promise<string> {
  const contents = await Promise.all(paths.map((path) => fetchRawFile(path)));

  return contents
    .map(
      (file) => `\n\n---\n<!-- Source: ${file.path} -->\n\n${file.raw.trim()}\n`,
    )
    .join("")
    .trim();
}

/** Formats API, network, or generic Error values into concise user-facing messages. */
export function describeApiError(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message;
  }
  if (error instanceof TypeError) {
    return "Network request failed. Check your connection and try again.";
  }
  if (error instanceof Error) {
    return error.message;
  }
  return "An unexpected error occurred.";
}
