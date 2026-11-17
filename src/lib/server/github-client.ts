/**
 * Server-only GitHub REST API v3 and raw CDN client with ISR caching tags,
 * rate-limit tracking, and environment-driven repository coordinates.
 */
import "server-only";

import { Octokit } from "@octokit/rest";
import { RequestError } from "@octokit/request-error";

import type { RateLimitInfo } from "@/lib/types";

const DEFAULT_OWNER = "EvanescenT07";
// Fallback repository slug; overridden by GITHUB_REPO in .env or .env.local.
const DEFAULT_REPO = "vscode-config";

/** Wraps upstream GitHub REST or raw CDN failures with an HTTP status code. */
export class GitHubApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "GitHubApiError";
    this.status = status;
  }
}

/** Raised when GITHUB_OWNER or GITHUB_REPO contains invalid path characters. */
export class RepositoryConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RepositoryConfigError";
  }
}

export interface RepoCoordinates {
  owner: string;
  repo: string;
}

export interface GitHubTreeBlobResponse {
  path: string;
  mode: string;
  type: "blob" | "tree" | "commit";
  sha: string;
  size?: number;
  url: string;
}

export interface GitHubTreeResponse {
  sha: string;
  url: string;
  tree: GitHubTreeBlobResponse[];
  truncated: boolean;
}

export interface GitHubCommitListItem {
  sha: string;
  html_url: string;
  commit: {
    message: string;
    author: {
      name: string;
      email: string;
      date: string;
    } | null;
    committer: {
      name: string;
      email: string;
      date: string;
    } | null;
  };
  author: {
    login: string;
    avatar_url: string;
  } | null;
  stats?: {
    additions: number;
    deletions: number;
    total: number;
  };
  files?: GitHubCommitFile[];
}

export interface GitHubCommitFile {
  filename: string;
  previous_filename?: string;
  status: string;
  additions: number;
  deletions: number;
  changes: number;
  patch?: string;
}

export interface GitHubCommitDetailResponse extends GitHubCommitListItem {
  stats: {
    additions: number;
    deletions: number;
    total: number;
  };
  files: GitHubCommitFile[];
}

interface CachePolicy {
  revalidate: number | false;
  tags: string[];
}

let rateLimit: RateLimitInfo = {
  remaining: null,
  limit: null,
  resetAt: null,
};

/** Returns the most recently observed GitHub API rate-limit headers. */
export function getRateLimit(): RateLimitInfo {
  return rateLimit;
}

function readRateLimit(headers: Record<string, string | number | undefined>): void {
  const remaining = Number(headers["x-ratelimit-remaining"]);
  const limit = Number(headers["x-ratelimit-limit"]);
  const reset = Number(headers["x-ratelimit-reset"]);

  if (Number.isFinite(remaining)) {
    rateLimit = {
      remaining,
      limit: Number.isFinite(limit) ? limit : rateLimit.limit,
      resetAt: Number.isFinite(reset)
        ? new Date(reset * 1000).toISOString()
        : rateLimit.resetAt,
    };
  }
}

function getCoordinates(): RepoCoordinates {
  const owner = process.env.GITHUB_OWNER?.trim() || DEFAULT_OWNER;
  const repo = process.env.GITHUB_REPO?.trim() || DEFAULT_REPO;

  if (!/^[A-Za-z0-9_.-]+$/.test(owner) || !/^[A-Za-z0-9_.-]+$/.test(repo)) {
    throw new RepositoryConfigError(
      "GITHUB_OWNER and GITHUB_REPO must contain only letters, numbers, dots, dashes, or underscores.",
    );
  }

  return { owner, repo };
}

/** Resolves and validates the configured GitHub repository owner and name. */
export function getRepoCoordinates(): RepoCoordinates {
  return getCoordinates();
}

let octokitInstance: Octokit | null = null;

function getOctokit(): Octokit {
  if (octokitInstance) {
    return octokitInstance;
  }

  const token = process.env.GITHUB_TOKEN?.trim();

  octokitInstance = new Octokit({
    auth: token || undefined,
    userAgent: "ide-config-hub",
  });

  return octokitInstance;
}

function createCachedFetch(policy: CachePolicy): typeof fetch {
  return (input, init) =>
    fetch(input, {
      ...init,
      next: {
        revalidate: policy.revalidate,
        tags: policy.tags,
      },
    } as RequestInit & { next: { revalidate: number | false; tags: string[] } });
}

function translateGitHubError(error: RequestError): GitHubApiError {
  if (error.status === 403 || error.status === 429) {
    return new GitHubApiError(
      "GitHub API rate limit reached. Add a read-only GITHUB_TOKEN to raise the limit.",
      error.status,
    );
  }

  if (error.status === 404) {
    return new GitHubApiError("Repository resource not found on GitHub.", 404);
  }

  return new GitHubApiError(error.message, error.status);
}

async function request<T>(
  route: string,
  params: Record<string, unknown>,
  policy: CachePolicy,
): Promise<T> {
  try {
    const response = await getOctokit().request(route, {
      ...params,
      request: { fetch: createCachedFetch(policy) },
    });

    readRateLimit(response.headers as Record<string, string | number | undefined>);
    return response.data as T;
  } catch (error) {
    if (error instanceof RequestError) {
      throw translateGitHubError(error);
    }
    if (error instanceof TypeError) {
      throw new GitHubApiError(
        "Could not reach GitHub. Check the network connection and try again.",
        502,
      );
    }
    throw error;
  }
}

/** Resolves the configured default branch or queries GitHub repository metadata. */
export async function getDefaultBranch(): Promise<string> {
  const configured = process.env.GITHUB_DEFAULT_BRANCH?.trim();
  if (configured) {
    return configured;
  }

  const { owner, repo } = getCoordinates();
  const data = await request<{ default_branch: string }>(
    "GET /repos/{owner}/{repo}",
    { owner, repo },
    { revalidate: 3600, tags: ["repo-meta"] },
  );

  return data.default_branch;
}

/** Fetches the full recursive Git tree for the given branch or tree SHA. */
export async function getRecursiveTree(branch: string): Promise<GitHubTreeResponse> {
  const { owner, repo } = getCoordinates();

  return request<GitHubTreeResponse>(
    "GET /repos/{owner}/{repo}/git/trees/{tree_sha}",
    { owner, repo, tree_sha: branch, recursive: "1" },
    { revalidate: 300, tags: ["repo-tree"] },
  );
}

/** Fetches a paginated commit list, optionally filtered to a single repository path. */
export async function getCommitPage(
  options: { path?: string; page?: number; perPage?: number },
): Promise<GitHubCommitListItem[]> {
  const { owner, repo } = getCoordinates();
  const perPage = Math.min(Math.max(options.perPage ?? 30, 1), 100);

  return request<GitHubCommitListItem[]>(
    "GET /repos/{owner}/{repo}/commits",
    {
      owner,
      repo,
      path: options.path,
      page: Math.max(options.page ?? 1, 1),
      per_page: perPage,
    },
    { revalidate: 120, tags: ["repo-commits", "repo-tree"] },
  );
}

/** Fetches full commit statistics and file patches for an immutable commit SHA. */
export async function getCommitDetails(sha: string): Promise<GitHubCommitDetailResponse> {
  const { owner, repo } = getCoordinates();

  return request<GitHubCommitDetailResponse>(
    "GET /repos/{owner}/{repo}/commits/{ref}",
    { owner, repo, ref: sha },
    { revalidate: false, tags: ["repo-commits"] },
  );
}

/** Checks whether a Git ref string matches a 7-40 character hexadecimal commit SHA. */
export function isCommitSha(value: string): boolean {
  return /^[0-9a-f]{7,40}$/i.test(value);
}

/** Fetches raw file content from GitHub Raw CDN using immutable caching for commit SHAs. */
export async function getRawFile(path: string, ref: string): Promise<string> {
  const { owner, repo } = getCoordinates();
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const encodedRef = encodeURIComponent(ref);
  const immutable = isCommitSha(ref);

  const response = await fetch(
    `https://raw.githubusercontent.com/${owner}/${repo}/${encodedRef}/${encodedPath}`,
    {
      headers: { "User-Agent": "ide-config-hub" },
      next: {
        revalidate: immutable ? false : 300,
        tags: ["repo-file", "repo-tree"],
      },
    },
  );

  if (!response.ok) {
    throw new GitHubApiError(
      response.status === 404
        ? `File "${path}" was not found at "${ref}".`
        : `Raw file request failed with status ${response.status}.`,
      response.status,
    );
  }

  return response.text();
}
