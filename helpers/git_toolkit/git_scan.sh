#!/usr/bin/env bash
set -euo pipefail

# Config (override via env)
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Neoware}"
MAX_REPOS="${MAX_REPOS:-10}"    # hard cap
RECENT_DAYS="${RECENT_DAYS:-0}" # 0 = no time filter

# Ignore noisy paths (gh-pages cache, node_modules, build outputs, vendored code, etc.)
# Add/remove as you like
IGNORE_PATTERNS=(
    "/node_modules/"
    "/.cache/"
    "/dist/"
    "/build/"
    "/out/"
    "/.venv/"
    "/venv/"
    "/.tox/"
    "/target/"
    "/.git/modules/" # submodule internals
)

[[ -d "$PROJECTS_DIR" ]] || {
    echo "!! PROJECTS_DIR missing: $PROJECTS_DIR" >&2
    exit 0
}

# Find candidate repos (top-level .git dirs)
mapfile -t repos < <(find "$PROJECTS_DIR" -type d -name .git -prune -print 2>/dev/null | sed 's#/.git$##')

# Filter out ignored paths
filtered=()
for r in "${repos[@]}"; do
    skip=0
    for pat in "${IGNORE_PATTERNS[@]}"; do
        [[ "$r" == *"$pat"* ]] && {
            skip=1
            break
        }
    done
    ((skip == 0)) && filtered+=("$r")
done

# De-duplicate
if ((${#filtered[@]})); then
    mapfile -t filtered < <(printf '%s\n' "${filtered[@]}" | awk '!seen[$0]++')
fi

# Map last-commit timestamp
declare -A when=()
for r in "${filtered[@]}"; do
    when["$r"]="$(git -C "$r" log -1 --format=%ct 2>/dev/null || echo 0)"
done

# Sort by last activity desc
mapfile -t sorted < <(
    for p in "${filtered[@]}"; do
        printf "%s %s\n" "${when[$p]:-0}" "$p"
    done | sort -nr | awk '{ $1=""; sub(/^ /,""); print }'
)

now="$(date +%s)"
count=0
for r in "${sorted[@]}"; do
    [[ -d "$r/.git" ]] || continue

    ts="${when[$r]:-0}"
    if ((RECENT_DAYS > 0)); then
        ((ts == 0)) && continue
        ((now - ts > RECENT_DAYS * 24 * 3600)) && continue
    fi

    name="$(basename "$r")"
    branch="$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"

    # dirty (incl. untracked)
    dirty="0"
    git -C "$r" status --porcelain >/dev/null 2>&1 &&
        [[ -n "$(git -C "$r" status --porcelain 2>/dev/null)" ]] && dirty="1"

    # ahead/behind (safe if no upstream)
    if git -C "$r" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        read -r behind ahead < <(git -C "$r" rev-list --left-right --count @{u}...HEAD 2>/dev/null | awk '{print $1, $2}')
        ahead="${ahead:-0}"
        behind="${behind:-0}"
    else
        ahead="0"
        behind="0"
    fi

    rel="$(git -C "$r" log -1 --date=relative --format='%ad' 2>/dev/null || echo '-')"

    remote_url="$(git -C "$r" remote get-url origin 2>/dev/null || echo '-')"
    slug="-"
    if [[ "$remote_url" =~ github.com[:/]+([^/]+)/([^/.]+) ]]; then
        slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi

    printf "%s|%s|%s|%s|%s|%s|%s|%s\n" \
        "$name" "$r" "$branch" "$dirty" "$ahead" "$behind" "$rel" "$slug"

    count=$((count + 1))
    ((MAX_REPOS > 0 && count >= MAX_REPOS)) && break
done
