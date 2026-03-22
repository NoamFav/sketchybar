#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

NOW=$(date +%s)
MONTH_AGO=$((NOW - 30 * 24 * 3600))
MIN=15
MAX=20

ISKRA_JSON=$(iskra status -json)

# Emit "timestamp<TAB>pipe-record" for each repo
get_ts_records() {
  jq -r '.results[] |
    (.remote.url // "" | if test("github\\.com")
      then capture("github\\.com[:/](?<s>[^/]+/[^.]+)").s
      else "-"
    end) as $slug |
    "\(.path)\t\(.name)\t\(.branch)\t\(.changes.staged)\t\(.changes.uncommitted)\t\(.changes.untracked)\t\(.remote.ahead)\t\(.remote.behind)\t\($slug)"
  ' <<< "$ISKRA_JSON" | while IFS=$'\t' read -r path name branch staged uc ut ahead behind slug; do
    ts=$(git -C "$path" log -1 --format=%ct 2>/dev/null || echo 0)
    printf "%s\t%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
      "$ts" "$name" "$path" "$branch" "$staged" "$uc" "$ut" "$ahead" "$behind" "$slug"
  done
}

# Sort descending by timestamp, cap at MAX.
# Include repos from the last month; if fewer than MIN, top up with older ones.
count=0
while IFS=$'\t' read -r ts record; do
  [ "$ts" -eq 0 ] && continue
  [ "$count" -ge "$MAX" ] && break
  [ "$ts" -lt "$MONTH_AGO" ] && [ "$count" -ge "$MIN" ] && break
  echo "$record"
  count=$((count + 1))
done < <(get_ts_records | sort -t$'\t' -k1 -rn)
