/**
 * Server Component data loaders that convert expected GitHub or configuration errors
 * into recoverable UI error payloads during initial SSR rendering.
 */
import "server-only";

import {
  GitHubApiError,
  RepositoryConfigError,
} from "@/lib/server/github-client";
import { getCommitList, getRepoTree } from "@/lib/server/repo-service";
import type { CommitListResponse, RepoTree } from "@/lib/types";

export interface InitialTreeData {
  tree: RepoTree | null;
  error: string | null;
}

export interface InitialHistoryData extends InitialTreeData {
  commits: CommitListResponse | null;
}

/** Loads the repository file tree for the main workbench view without throwing on API throttling. */
export async function loadInitialTree(): Promise<InitialTreeData> {
  try {
    const tree = await getRepoTree();
    return { tree, error: null };
  } catch (error) {
    if (error instanceof GitHubApiError || error instanceof RepositoryConfigError) {
      return { tree: null, error: error.message };
    }
    throw error;
  }
}

/** Loads both the file tree and the first page of commits for the `/history` route. */
export async function loadInitialHistory(): Promise<InitialHistoryData> {
  const initial = await loadInitialTree();

  if (!initial.tree) {
    return { ...initial, commits: null };
  }

  try {
    const commits = await getCommitList({ perPage: 30 });
    return { ...initial, commits };
  } catch (error) {
    if (error instanceof GitHubApiError || error instanceof RepositoryConfigError) {
      return { ...initial, commits: null };
    }
    throw error;
  }
}
