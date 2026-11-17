#!/usr/bin/env bash
# Installs curated VS Code-family extensions across detected or selected IDEs.
# Supports VS Code (code), Antigravity (agy), Cursor (cursor), Windsurf (windsurf),
# and VSCodium (codium) on macOS and Linux.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IDE_SELECTION="auto"
INSTALL_MODE="all"
EXTENSIONS_FILE="${REPO_ROOT}/ide/extensions.txt"
USE_FORCE=0
DRY_RUN=0

print_usage() {
    cat <<'EOF'
Usage: install-extensions.sh [options]

Options:
  --ide <target>   Target IDE: auto (default), all, vscode, antigravity,
                   cursor, windsurf, or codium
  --missing        Only install extensions missing from --list-extensions
  --file <path>    Path to extensions list (default: <repo>/ide/extensions.txt)
  --force          Pass --force to the IDE CLI when installing extensions
  --dry-run        Print planned commands without modifying any IDE
  -h, --help       Show this help message
EOF
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

trim_whitespace() {
    local val="$1"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    printf '%s' "$val"
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

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --missing)
            INSTALL_MODE="missing"
            shift
            ;;
        --file)
            if [[ $# -lt 2 ]]; then
                printf 'Error: --file requires a path\n' >&2
                exit 1
            fi
            EXTENSIONS_FILE="$2"
            shift 2
            ;;
        --file=*)
            EXTENSIONS_FILE="${1#*=}"
            shift
            ;;
        --force)
            USE_FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
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

if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    printf 'Error: extensions file not found: %s\n' "$EXTENSIONS_FILE" >&2
    exit 1
fi

extensions=()
seen_lower=$'\n'

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    stripped="${raw_line%%#*}"
    trimmed="$(trim_whitespace "$stripped")"
    if [[ -z "$trimmed" ]]; then
        continue
    fi
    lower_id="$(to_lower "$trimmed")"
    if [[ "$seen_lower" != *$'\n'"${lower_id}"$'\n'* ]]; then
        seen_lower="${seen_lower}${lower_id}"$'\n'
        extensions+=("$trimmed")
    fi
done < "$EXTENSIONS_FILE"

if [[ ${#extensions[@]} -eq 0 ]]; then
    printf '[WARN] No extension IDs found in %s.\n' "$EXTENSIONS_FILE"
    exit 0
fi

ALL_IDES=(vscode antigravity cursor windsurf codium)
target_ides=()

case "$IDE_SELECTION" in
    auto)
        for key in "${ALL_IDES[@]}"; do
            cli_bin="$(ide_to_cli "$key")"
            if command -v "$cli_bin" >/dev/null 2>&1; then
                target_ides+=("$key")
            fi
        done
        if [[ ${#target_ides[@]} -eq 0 ]]; then
            printf '[WARN] No supported IDE CLI found in PATH (checked: code, agy, cursor, windsurf, codium).\n' >&2
            exit 0
        fi
        ;;
    all)
        target_ides=("${ALL_IDES[@]}")
        ;;
    *)
        cli_bin="$(ide_to_cli "$IDE_SELECTION")"
        if ! command -v "$cli_bin" >/dev/null 2>&1; then
            printf 'Error: %s CLI (%s) was not found in PATH.\n' "$(ide_display_name "$IDE_SELECTION")" "$cli_bin" >&2
            exit 1
        fi
        target_ides=("$IDE_SELECTION")
        ;;
esac

printf 'Loaded %d extension(s) from %s (mode=%s, dry_run=%d).\n' \
    "${#extensions[@]}" "$EXTENSIONS_FILE" "$INSTALL_MODE" "$DRY_RUN"

summary_lines=()
any_failures=0
found_any_cli=0

for key in "${target_ides[@]}"; do
    label="$(ide_display_name "$key")"
    cli_bin="$(ide_to_cli "$key")"

    if ! command -v "$cli_bin" >/dev/null 2>&1; then
        printf '[SKIP] %s: CLI "%s" not found in PATH.\n' "$label" "$cli_bin"
        summary_lines+=("$(printf '%-12s (%-8s) : skipped (CLI missing)' "$label" "$cli_bin")")
        continue
    fi

    found_any_cli=1
    cli_path="$(command -v "$cli_bin")"
    printf '\n==> %s (%s)\n' "$label" "$cli_path"

    installed_lower=$'\n'
    if [[ "$INSTALL_MODE" == "missing" ]]; then
        if ! raw_installed="$("$cli_bin" --list-extensions 2>/dev/null)"; then
            printf '[WARN] Failed to list existing extensions via %s; skipping %s.\n' "$cli_bin" "$label" >&2
            any_failures=1
            summary_lines+=("$(printf '%-12s (%-8s) : list failed (skipped)' "$label" "$cli_bin")")
            continue
        fi
        installed_count=0
        while IFS= read -r inst_line || [[ -n "$inst_line" ]]; do
            inst_trimmed="$(trim_whitespace "$inst_line")"
            if [[ -n "$inst_trimmed" ]]; then
                inst_lower="$(to_lower "$inst_trimmed")"
                installed_lower="${installed_lower}${inst_lower}"$'\n'
                installed_count=$((installed_count + 1))
            fi
        done <<< "$raw_installed"
        printf 'Detected %d already installed extension(s).\n' "$installed_count"
    fi

    installed=0
    skipped=0
    failed=0
    would_install=0

    for ext_id in "${extensions[@]}"; do
        ext_lower="$(to_lower "$ext_id")"
        if [[ "$INSTALL_MODE" == "missing" && "$installed_lower" == *$'\n'"${ext_lower}"$'\n'* ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        install_args=(--install-extension "$ext_id")
        if [[ $USE_FORCE -eq 1 ]]; then
            install_args+=(--force)
        fi

        if [[ $DRY_RUN -eq 1 ]]; then
            printf '  [DRY-RUN] %s %s\n' "$cli_bin" "${install_args[*]}"
            would_install=$((would_install + 1))
            continue
        fi

        printf '  Installing %s...\n' "$ext_id"
        if "$cli_bin" "${install_args[@]}"; then
            installed=$((installed + 1))
        else
            printf '[WARN] Failed to install "%s" for %s.\n' "$ext_id" "$label" >&2
            failed=$((failed + 1))
            any_failures=1
        fi
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        summary_lines+=("$(printf '%-12s (%-8s) : would_install=%d, skipped=%d' "$label" "$cli_bin" "$would_install" "$skipped")")
    else
        summary_lines+=("$(printf '%-12s (%-8s) : installed=%d, skipped=%d, failed=%d' "$label" "$cli_bin" "$installed" "$skipped" "$failed")")
    fi
done

if [[ $found_any_cli -eq 0 ]]; then
    printf '[WARN] No supported IDE CLI found in PATH (checked: code, agy, cursor, windsurf, codium).\n' >&2
fi

printf '\n--- Extension Install Summary ---\n'
for line in "${summary_lines[@]}"; do
    printf '%s\n' "$line"
done

if [[ $any_failures -ne 0 ]]; then
    exit 1
fi
