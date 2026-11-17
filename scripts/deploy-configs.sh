#!/usr/bin/env bash
# Deploys sanitized IDE and AI agent configuration templates to local system paths.
# Supports macOS and Linux for VS Code-family IDEs, Antigravity, OpenCode,
# CommandCode, MCP servers, and project .agents workspaces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

TARGET_RAW="all"
IDE_SELECTION="auto"
WORKSPACE_PATH="."
DRY_RUN=0
NO_BACKUP=0
RESOLVE_PATHS=0

RUN_TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
STAT_WRITTEN=0
STAT_BACKED_UP=0
STAT_SKIPPED=0
STAT_ERRORS=0
UNRESOLVED_VARS=$'\n'
TRANSFORMED_LINE=""

print_usage() {
    cat <<'EOF'
Usage: deploy-configs.sh [options]

Options:
  --target <name>     Target(s) to deploy (comma-separated allowed): all (default),
                      ide, antigravity, opencode, commandcode, mcp, workspace
  --ide <target>      IDE target for settings.json: auto (default), all, vscode,
                      antigravity, cursor, windsurf, codium
  --workspace <path>  Target project directory for workspace target (default: .)
  --resolve-paths     Auto-detect flutter, java JDK, and HOME; substitute ${HOME},
                      ${env:FLUTTER_ROOT}, ${env:JAVA_HOME}, and set ${env:*} vars
  --dry-run           Print planned backups and writes without modifying files
  --no-backup         Overwrite existing files without creating *.bak.<timestamp>
  -h, --help          Show this help message
EOF
}

ide_to_cli() {
    case "$1" in
        vscode)      printf 'code' ;;
        antigravity) printf 'agy' ;;
        cursor)      printf 'cursor' ;;
        windsurf)    printf 'windsurf' ;;
        codium)      printf 'codium' ;;
        *)           return 1 ;;
    esac
}

ide_to_folder() {
    case "$1" in
        vscode)      printf 'Code' ;;
        antigravity) printf 'Antigravity' ;;
        cursor)      printf 'Cursor' ;;
        windsurf)    printf 'Windsurf' ;;
        codium)      printf 'VSCodium' ;;
        *)           return 1 ;;
    esac
}

ide_display_name() {
    case "$1" in
        vscode)      printf 'VS Code' ;;
        antigravity) printf 'Antigravity' ;;
        cursor)      printf 'Cursor' ;;
        windsurf)    printf 'Windsurf' ;;
        codium)      printf 'VSCodium' ;;
        *)           printf '%s' "$1" ;;
    esac
}

validate_ide_option() {
    case "$1" in
        auto|all|vscode|antigravity|cursor|windsurf|codium) return 0 ;;
        *)
            printf 'Error: invalid --ide value "%s"\n' "$1" >&2
            exit 1
            ;;
    esac
}

validate_target_token() {
    case "$1" in
        all|ide|antigravity|opencode|commandcode|mcp|workspace) return 0 ;;
        *)
            printf 'Error: invalid --target value "%s"\n' "$1" >&2
            exit 1
            ;;
    esac
}

resolve_abs_path() {
    local target="$1"
    if [[ -d "$target" ]]; then
        (cd "$target" && pwd -P)
        return
    fi
    local parent
    parent="$(dirname "$target")"
    local base
    base="$(basename "$target")"
    if [[ -d "$parent" ]]; then
        printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
    else
        case "$target" in
            /*) printf '%s\n' "$target" ;;
            *)  printf '%s/%s\n' "$(pwd -P)" "$target" ;;
        esac
    fi
}

resolve_symlink_chain() {
    local current="$1"
    local guard=0
    while [[ -L "$current" && $guard -lt 20 ]]; do
        local link_target
        link_target="$(readlink "$current")"
        if [[ "$link_target" == /* ]]; then
            current="$link_target"
        else
            current="$(cd "$(dirname "$current")" && pwd -P)/$link_target"
        fi
        guard=$((guard + 1))
    done
    local dir
    dir="$(cd "$(dirname "$current")" && pwd -P)"
    printf '%s/%s\n' "$dir" "$(basename "$current")"
}

find_flutter_root() {
    if [[ -n "${FLUTTER_ROOT:-}" && -d "${FLUTTER_ROOT}" ]]; then
        printf '%s\n' "$FLUTTER_ROOT"
        return 0
    fi
    if ! command -v flutter >/dev/null 2>&1; then
        return 0
    fi
    local bin_path
    bin_path="$(resolve_symlink_chain "$(command -v flutter)")"
    local bin_dir
    bin_dir="$(dirname "$bin_path")"
    if [[ "$(basename "$bin_dir")" == "bin" ]]; then
        local candidate
        candidate="$(dirname "$bin_dir")"
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
        fi
    fi
}

find_java_home() {
    if [[ -n "${JAVA_HOME:-}" && -d "${JAVA_HOME}" ]]; then
        printf '%s\n' "$JAVA_HOME"
        return 0
    fi
    if [[ "$OS_NAME" == "Darwin" && -x /usr/libexec/java_home ]]; then
        local mac_java=""
        mac_java="$(/usr/libexec/java_home 2>/dev/null || true)"
        if [[ -n "$mac_java" && -d "$mac_java" ]]; then
            printf '%s\n' "$mac_java"
            return 0
        fi
    fi
    if ! command -v java >/dev/null 2>&1; then
        return 0
    fi
    local bin_path
    bin_path="$(resolve_symlink_chain "$(command -v java)")"
    local bin_dir
    bin_dir="$(dirname "$bin_path")"
    if [[ "$(basename "$bin_dir")" != "bin" ]]; then
        return 0
    fi
    local candidate
    candidate="$(dirname "$bin_dir")"
    if [[ "$candidate" == "/usr" ]]; then
        return 0
    fi
    if [[ -f "${candidate}/release" || -x "${bin_dir}/javac" ]]; then
        printf '%s\n' "$candidate"
    fi
}

record_unresolved_var() {
    local var_name="$1"
    if [[ "$UNRESOLVED_VARS" != *$'\n'"${var_name}"$'\n'* ]]; then
        UNRESOLVED_VARS="${UNRESOLVED_VARS}${var_name}"$'\n'
    fi
}

json_escape() {
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s' "$val"
}

transform_json_line() {
    local line="$1"
    local comment_regex='^[[:space:]]*//'
    local env_regex='\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}'

    if [[ ! $line =~ $comment_regex ]]; then
        if [[ "$line" == *'${HOME}'* ]]; then
            local esc_home
            esc_home="$(json_escape "$HOME")"
            line="${line//\$\{HOME\}/$esc_home}"
        fi

        local rebuilt=""
        local rest="$line"
        while [[ $rest =~ $env_regex ]]; do
            local full_match="${BASH_REMATCH[0]}"
            local var_name="${BASH_REMATCH[1]}"
            local prefix="${rest%%"$full_match"*}"
            rest="${rest#*"$full_match"}"

            local replacement=""
            if [[ "$var_name" == "FLUTTER_ROOT" ]]; then
                if [[ -n "$RESOLVED_FLUTTER_ROOT" ]]; then
                    replacement="$(json_escape "$RESOLVED_FLUTTER_ROOT")"
                fi
            elif [[ "$var_name" == "JAVA_HOME" ]]; then
                if [[ -n "$RESOLVED_JAVA_HOME" ]]; then
                    replacement="$(json_escape "$RESOLVED_JAVA_HOME")"
                fi
            else
                local env_val=""
                env_val="$(printenv "$var_name" 2>/dev/null || true)"
                if [[ -n "$env_val" ]]; then
                    replacement="$(json_escape "$env_val")"
                fi
            fi

            if [[ -n "$replacement" ]]; then
                rebuilt="${rebuilt}${prefix}${replacement}"
            else
                record_unresolved_var "$var_name"
                rebuilt="${rebuilt}${prefix}${full_match}"
            fi
        done
        line="${rebuilt}${rest}"
    fi
    TRANSFORMED_LINE="$line"
}

resolve_json_template_file() {
    local src="$1"
    local dest="$2"
    local output=""
    local line=""

    while IFS= read -r line; do
        transform_json_line "$line"
        output="${output}${TRANSFORMED_LINE}"$'\n'
    done < "$src"

    if [[ -n "$line" ]]; then
        transform_json_line "$line"
        output="${output}${TRANSFORMED_LINE}"
    fi

    printf '%s' "$output" > "$dest"
}

is_json_template() {
    case "$1" in
        *.json|*.jsonc) return 0 ;;
        *) return 1 ;;
    esac
}

deploy_single_file() {
    local src="$1"
    local dest="$2"
    local allow_resolve="$3"

    if [[ ! -f "$src" ]]; then
        printf '[WARN] Missing template source: %s\n' "$src" >&2
        STAT_ERRORS=$((STAT_ERRORS + 1))
        return
    fi

    local exists=0
    if [[ -f "$dest" ]]; then
        exists=1
    fi
    local backup_path="${dest}.bak.${RUN_TIMESTAMP}"

    local should_resolve=0
    if [[ $RESOLVE_PATHS -eq 1 && "$allow_resolve" == "1" ]] && is_json_template "$src"; then
        should_resolve=1
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        if [[ $exists -eq 1 && $NO_BACKUP -eq 0 ]]; then
            printf '  [DRY-RUN] Backup : %s -> %s\n' "$dest" "$backup_path"
            STAT_BACKED_UP=$((STAT_BACKED_UP + 1))
        fi
        if [[ $should_resolve -eq 1 ]]; then
            printf '  [DRY-RUN] Write  : %s -> %s (with path/env resolution)\n' "$src" "$dest"
        else
            printf '  [DRY-RUN] Write  : %s -> %s\n' "$src" "$dest"
        fi
        STAT_WRITTEN=$((STAT_WRITTEN + 1))
        return
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ $exists -eq 1 && $NO_BACKUP -eq 0 ]]; then
        cp "$dest" "$backup_path"
        printf '  [BACKUP] %s\n' "$backup_path"
        STAT_BACKED_UP=$((STAT_BACKED_UP + 1))
    fi

    if [[ $should_resolve -eq 1 ]]; then
        resolve_json_template_file "$src" "$dest"
    else
        cp "$src" "$dest"
    fi

    printf '  [WRITE]  %s\n' "$dest"
    STAT_WRITTEN=$((STAT_WRITTEN + 1))
}

deploy_directory_tree() {
    local src_dir="$1"
    local dest_dir="$2"
    local allow_resolve="$3"

    if [[ ! -d "$src_dir" ]]; then
        printf '[WARN] Missing template directory: %s\n' "$src_dir" >&2
        STAT_ERRORS=$((STAT_ERRORS + 1))
        return
    fi

    local clean_src="${src_dir%/}"
    while IFS= read -r src_file; do
        local rel_path="${src_file#"$clean_src"/}"
        deploy_single_file "$src_file" "${dest_dir}/${rel_path}" "$allow_resolve"
    done < <(find "$clean_src" -type f ! -name 'README.md' | sort)
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            if [[ $# -lt 2 ]]; then
                printf 'Error: --target requires an argument\n' >&2
                exit 1
            fi
            TARGET_RAW="$2"
            shift 2
            ;;
        --target=*)
            TARGET_RAW="${1#*=}"
            shift
            ;;
        --ide)
            if [[ $# -lt 2 ]]; then
                printf 'Error: --ide requires an argument\n' >&2
                exit 1
            fi
            IDE_SELECTION="$2"
            shift 2
            ;;
        --ide=*)
            IDE_SELECTION="${1#*=}"
            shift
            ;;
        --workspace)
            if [[ $# -lt 2 ]]; then
                printf 'Error: --workspace requires a path\n' >&2
                exit 1
            fi
            WORKSPACE_PATH="$2"
            shift 2
            ;;
        --workspace=*)
            WORKSPACE_PATH="${1#*=}"
            shift
            ;;
        --resolve-paths)
            RESOLVE_PATHS=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-backup)
            NO_BACKUP=1
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            printf 'Error: unknown option "%s"\n' "$1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

validate_ide_option "$IDE_SELECTION"

OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin)
        IDE_CONFIG_BASE="${HOME}/Library/Application Support"
        ;;
    Linux)
        IDE_CONFIG_BASE="${XDG_CONFIG_HOME:-${HOME}/.config}"
        ;;
    *)
        printf '[WARN] Unsupported POSIX OS "%s"; defaulting IDE config base to XDG config.\n' "$OS_NAME" >&2
        IDE_CONFIG_BASE="${XDG_CONFIG_HOME:-${HOME}/.config}"
        ;;
esac

XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
GEMINI_DIR="${HOME}/.gemini"
GEMINI_CONFIG_DIR="${GEMINI_DIR}/config"
RESOLVED_WORKSPACE="$(resolve_abs_path "$WORKSPACE_PATH")"

include_all=0
explicit_workspace=0
parsed_targets=()

IFS=',' read -r -a raw_tokens <<< "$TARGET_RAW"
if [[ ${#raw_tokens[@]} -eq 0 ]]; then
    printf 'Error: --target cannot be empty\n' >&2
    exit 1
fi
for tok in "${raw_tokens[@]}"; do
    validate_target_token "$tok"
    if [[ "$tok" == "all" ]]; then
        include_all=1
    elif [[ "$tok" == "workspace" ]]; then
        explicit_workspace=1
    fi
done

if [[ $include_all -eq 1 ]]; then
    parsed_targets=(ide antigravity mcp opencode commandcode workspace)
else
    seen_targets=$'\n'
    for tok in "${raw_tokens[@]}"; do
        if [[ "$seen_targets" != *$'\n'"${tok}"$'\n'* ]]; then
            seen_targets="${seen_targets}${tok}"$'\n'
            parsed_targets+=("$tok")
        fi
    done
fi

RESOLVED_FLUTTER_ROOT=""
RESOLVED_JAVA_HOME=""
if [[ $RESOLVE_PATHS -eq 1 ]]; then
    RESOLVED_FLUTTER_ROOT="$(find_flutter_root || true)"
    RESOLVED_JAVA_HOME="$(find_java_home || true)"
    printf 'Path resolution summary:\n'
    printf '  HOME         : %s\n' "$HOME"
    printf '  FLUTTER_ROOT : %s\n' "${RESOLVED_FLUTTER_ROOT:-<not detected; keeping placeholder>}"
    printf '  JAVA_HOME    : %s\n' "${RESOLVED_JAVA_HOME:-<not detected; keeping placeholder>}"
fi

printf 'Deploying configs (os=%s, targets=%s, dry_run=%d, backup=%d).\n' \
    "$OS_NAME" "$(IFS=','; echo "${parsed_targets[*]}")" "$DRY_RUN" "$((1 - NO_BACKUP))"

ALL_IDES=(vscode antigravity cursor windsurf codium)

for active_target in "${parsed_targets[@]}"; do
    case "$active_target" in
        ide)
            printf '\n==> Target: ide\n'
            ide_src="${REPO_ROOT}/ide/settings.json"
            target_ides=()
            case "$IDE_SELECTION" in
                auto)
                    for key in "${ALL_IDES[@]}"; do
                        cli_bin="$(ide_to_cli "$key")"
                        folder="$(ide_to_folder "$key")"
                        if command -v "$cli_bin" >/dev/null 2>&1 || [[ -d "${IDE_CONFIG_BASE}/${folder}" ]]; then
                            target_ides+=("$key")
                        fi
                    done
                    ;;
                all)
                    target_ides=("${ALL_IDES[@]}")
                    ;;
                *)
                    target_ides=("$IDE_SELECTION")
                    ;;
            esac

            if [[ ${#target_ides[@]} -eq 0 ]]; then
                printf '[WARN] No supported IDE installation detected. Pass --ide <name> or --ide all to force.\n' >&2
                STAT_SKIPPED=$((STAT_SKIPPED + 1))
                continue
            fi

            for key in "${target_ides[@]}"; do
                label="$(ide_display_name "$key")"
                folder="$(ide_to_folder "$key")"
                printf '  IDE: %s\n' "$label"
                deploy_single_file "$ide_src" "${IDE_CONFIG_BASE}/${folder}/User/settings.json" 1
            done
            ;;

        antigravity)
            printf '\n==> Target: antigravity\n'
            deploy_single_file "${REPO_ROOT}/AGENTS.md" "${GEMINI_DIR}/GEMINI.md" 0
            deploy_single_file "${REPO_ROOT}/agent/antigravity/skills.json" "${GEMINI_CONFIG_DIR}/skills.json" 1

            config_template="${REPO_ROOT}/agent/antigravity/config.template.json"
            if [[ -f "$config_template" ]]; then
                deploy_single_file "$config_template" "${GEMINI_CONFIG_DIR}/config.template.json" 1
            fi
            live_config="${GEMINI_CONFIG_DIR}/config.json"
            if [[ -f "$live_config" ]]; then
                printf '  [NOTE] Preserved live "%s". Merge plugins/permissions manually from config.template.json.\n' "$live_config"
            else
                printf '  [NOTE] "%s" is not overwritten automatically. Review config.template.json to initialize manually.\n' "$live_config"
            fi
            ;;

        mcp)
            printf '\n==> Target: mcp\n'
            deploy_single_file "${REPO_ROOT}/agent/mcp/mcp_config.json" "${GEMINI_CONFIG_DIR}/mcp_config.json" 1
            ;;

        opencode)
            printf '\n==> Target: opencode\n'
            deploy_directory_tree "${REPO_ROOT}/agent/opencode" "${XDG_CONFIG_DIR}/opencode" 1
            ;;

        commandcode)
            printf '\n==> Target: commandcode\n'
            deploy_directory_tree "${REPO_ROOT}/agent/commandcode" "${HOME}/.opencode" 1
            ;;

        workspace)
            printf '\n==> Target: workspace\n'
            if [[ $include_all -eq 1 && $explicit_workspace -eq 0 && "${RESOLVED_WORKSPACE%/}" == "${REPO_ROOT%/}" ]]; then
                printf '  [SKIP] Workspace resolves to this config repository. Pass --target workspace or --workspace <dir> to deploy .agents/.\n'
                STAT_SKIPPED=$((STAT_SKIPPED + 1))
                continue
            fi
            deploy_directory_tree "${REPO_ROOT}/agent/workspace" "${RESOLVED_WORKSPACE}/.agents" 1
            ;;
    esac
done

printf '\n--- Config Deployment Summary ---\n'
printf 'written=%d, backed_up=%d, skipped=%d, errors=%d\n' \
    "$STAT_WRITTEN" "$STAT_BACKED_UP" "$STAT_SKIPPED" "$STAT_ERRORS"

if [[ $RESOLVE_PATHS -eq 1 ]]; then
    trimmed_unresolved="$(printf '%s' "$UNRESOLVED_VARS" | tr '\n' ' ' | sed 's/^ *//; s/ *$//')"
    if [[ -n "$trimmed_unresolved" ]]; then
        printf '[NOTE] Unresolved placeholders kept intact (set env vars or edit deployed files manually): %s\n' "$trimmed_unresolved"
    fi
fi

if [[ $STAT_ERRORS -gt 0 ]]; then
    exit 1
fi
