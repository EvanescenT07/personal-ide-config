/**
 * Deterministic file-tree classifier mapping Git tree blobs into workbench
 * categories (`ideConfigs`, `aiRules`, `scripts`, `docs`) and Shiki languages.
 */
import "server-only";

import type { FileCategory } from "@/lib/types";

const AI_DIRECTORY =
  /(^|\/)(rules|prompts|agents|agent|skills|cursor|copilot|claude|windsurf|opencode|commandcode|antigravity)(\/|$)/i;

const AI_FILENAME =
  /(^|\/)(\.cursorrules|copilot-instructions\.md|CLAUDE\.md|GEMINI\.md|AGENTS\.md|SKILL\.md|rules\.md|opencode\.jsonc|mcp_config[^/]*\.json|\.skill-lock\.json|[^/]*rules[^/]*\.(md|mdx|mdc|txt)|[^/]*prompt[^/]*\.(md|mdx|mdc|txt))$/i;

const SCRIPT_EXTENSION = /\.(sh|ps1|bat|cmd|zsh)$/i;
const SCRIPT_FILENAME = /(^|\/)(Makefile|Dockerfile)$/i;

const DOC_FILENAME =
  /(^|\/)(README|LICENSE|CHANGELOG|CONTRIBUTING|CODE_OF_CONDUCT)(\.[a-z]+)?$/i;

const IDE_FILENAME =
  /(^|\/)(\.editorconfig|\.ideavimrc|\.vimrc|\.prettierrc[^/]*|\.eslintrc[^/]*|settings\.json|keybindings\.json|extensions\.json|extensions\.txt|tasks\.json|launch\.json)$/i;

const IDE_DIRECTORY =
  /(^|\/)(\.vscode|vscode|ide|config|settings|snippets|profiles)(\/|$)/i;

const IDE_EXTENSION =
  /\.(json|jsonc|yaml|yml|toml|lua|vim|ideavimrc|editorconfig|code-snippets|code-profile)$/i;

const TEXT_DOC_EXTENSION = /\.(md|mdx|txt|pbtxt)$/i;

const EXTENSION_LIST = /extensions?/i;

const IGNORED_PREFIXES = [
  "node_modules/",
  ".next/",
  ".git/",
  ".vercel/",
  "src/",
  "public/",
  "out/",
  "coverage/",
];

const IGNORED_FILES = new Set([
  "package.json",
  "package-lock.json",
  "pnpm-lock.yaml",
  "yarn.lock",
  "bun.lock",
  "tsconfig.json",
  "tsconfig.tsbuildinfo",
  "next-env.d.ts",
  "next.config.ts",
  "next.config.js",
  "next.config.mjs",
  "tailwind.config.ts",
  "postcss.config.mjs",
  "postcss.config.js",
  ".gitignore",
  ".DS_Store",
  "Thumbs.db",
  ".env",
  ".env.local",
  ".env.example",
]);

const BINARY_EXTENSION =
  /\.(png|jpe?g|gif|webp|avif|ico|icns|pdf|zip|gz|tar|rar|7z|woff2?|ttf|otf|eot|mp3|mp4|mov|webm|wasm|exe|dll|so|dylib)$/i;

const LANGUAGE_BY_EXTENSION: Record<string, string> = {
  json: "jsonc",
  jsonc: "jsonc",
  md: "markdown",
  mdx: "markdown",
  mdc: "markdown",
  ts: "typescript",
  tsx: "typescript",
  js: "javascript",
  jsx: "javascript",
  yaml: "yaml",
  yml: "yaml",
  toml: "toml",
  lua: "lua",
  sh: "shellscript",
  bash: "shellscript",
  zsh: "shellscript",
  ps1: "powershell",
  bat: "bat",
  cmd: "bat",
  cfg: "ini",
  ini: "ini",
  editorconfig: "ini",
  ideavimrc: "viml",
  vimrc: "viml",
  vim: "viml",
  pbtxt: "ini",
  txt: "text",
};

export interface GitHubTreeBlob {
  path: string;
  type: string;
  size?: number;
}

export interface ClassifiedFile {
  path: string;
  name: string;
  extension: string;
  size: number;
  category: FileCategory;
  isJson: boolean;
  isMarkdown: boolean;
  isAiRule: boolean;
  language: string;
}

/** Filters out web-app internals, lockfiles, env files, and binary assets from the Git tree. */
export function shouldIgnore(path: string): boolean {
  const normalized = path.replace(/\\/g, "/");
  if (!normalized || normalized.endsWith("/")) {
    return true;
  }

  if (BINARY_EXTENSION.test(normalized)) {
    return true;
  }

  const filename = normalized.split("/").pop() ?? normalized;
  if (IGNORED_FILES.has(normalized) || filename === ".DS_Store" || filename === "Thumbs.db") {
    return true;
  }

  return IGNORED_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}

function extensionOf(path: string): string {
  const filename = path.split("/").pop() ?? path;
  const dotIndex = filename.lastIndexOf(".");
  return dotIndex > 0 ? filename.slice(dotIndex + 1).toLowerCase() : "";
}

/**
 * Classifies a repository path into a workbench category.
 * Documentation rules (`PRD*`, `README`, `docs/`) execute before AI/IDE directory checks
 * so directory READMEs never pollute `aiRules` or `ideConfigs`.
 */
export function classifyPath(path: string, _size = 0): FileCategory {
  const normalized = path.replace(/\\/g, "/");
  const filename = normalized.split("/").pop() ?? normalized;

  if (/^PRD[\s._-]/i.test(filename) || DOC_FILENAME.test(filename) || /^docs\//i.test(normalized)) {
    return "docs";
  }

  if (
    SCRIPT_EXTENSION.test(filename) ||
    SCRIPT_FILENAME.test(filename) ||
    /^scripts\//i.test(normalized)
  ) {
    return "scripts";
  }

  if (/^ide\//i.test(normalized) || IDE_FILENAME.test(filename)) {
    return "ideConfigs";
  }

  if (/^agent\//i.test(normalized) || AI_DIRECTORY.test(normalized) || AI_FILENAME.test(filename)) {
    return "aiRules";
  }

  if (
    IDE_DIRECTORY.test(normalized) ||
    IDE_EXTENSION.test(filename) ||
    (EXTENSION_LIST.test(filename) && /\.txt$/i.test(filename))
  ) {
    return "ideConfigs";
  }

  if (TEXT_DOC_EXTENSION.test(filename)) {
    return "docs";
  }

  return "docs";
}

/** Converts a Git tree blob entry into structured UI metadata, or returns null if ignored. */
export function classifyBlob(blob: GitHubTreeBlob): ClassifiedFile | null {
  if (blob.type !== "blob" || shouldIgnore(blob.path)) {
    return null;
  }

  const category = classifyPath(blob.path, blob.size ?? 0);
  const extension = extensionOf(blob.path);
  const name = blob.path.split("/").pop() ?? blob.path;
  const isJson = extension === "json" || extension === "jsonc";
  const isMarkdown = extension === "md" || extension === "mdx" || extension === "mdc";

  return {
    path: blob.path,
    name,
    extension,
    size: blob.size ?? 0,
    category,
    isJson,
    isMarkdown,
    isAiRule: isAiRulePath(blob.path),
    language: languageFor(blob.path),
  };
}

/** Resolves a Shiki-compatible language identifier for extensions and leading-dot config files. */
export function languageFor(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  const filename = (normalized.split("/").pop() ?? normalized).toLowerCase();
  const ext = extensionOf(normalized);

  if (ext && LANGUAGE_BY_EXTENSION[ext]) {
    return LANGUAGE_BY_EXTENSION[ext];
  }

  if (filename.startsWith(".")) {
    const dotKey = filename.slice(1);
    if (LANGUAGE_BY_EXTENSION[dotKey]) {
      return LANGUAGE_BY_EXTENSION[dotKey];
    }
    if (dotKey === "cursorrules") {
      return "markdown";
    }
  }

  if (filename === "dockerfile" || filename === "makefile") {
    return "shellscript";
  }

  return "text";
}

/**
 * Returns true only for prompt-combinable text/Markdown AI rules and skills,
 * excluding structured JSON/JSONC agent configs so the prompt combiner never mixes JSON into prompts.
 */
export function isAiRulePath(path: string): boolean {
  if (classifyPath(path) !== "aiRules") {
    return false;
  }

  const normalized = path.replace(/\\/g, "/");
  const filename = normalized.split("/").pop() ?? normalized;
  const ext = extensionOf(normalized);

  return (
    ext === "md" ||
    ext === "mdx" ||
    ext === "mdc" ||
    ext === "txt" ||
    /^\.cursorrules$/i.test(filename)
  );
}
