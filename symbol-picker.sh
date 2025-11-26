#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="${SCRIPT_DIR}/symbols.csv"

if [[ ! -f "${CSV_FILE}" ]]; then
  echo "symbols.csv not found next to this script: ${CSV_FILE}" >&2
  exit 1
fi

if ! command -v wofi >/dev/null 2>&1; then
  echo "wofi is required but not found in PATH" >&2
  exit 1
fi

if ! command -v wl-copy >/dev/null 2>&1; then
  echo "wl-copy (from wl-clipboard) is required but not found in PATH" >&2
  exit 1
fi

menu_input="$(python - "$CSV_FILE" <<'PY'
import csv, sys
from pathlib import Path

csv_path = Path(sys.argv[1])

def fit(text, width):
    text = text.strip()
    if len(text) <= width:
        return text.ljust(width)
    # Keep it ASCII to match the CSV; trim with "..."
    return (text[: max(0, width - 3)] + "...").ljust(width)

rows = []
with csv_path.open(newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        rows.append({
            "symbol": row.get("symbol", "").strip(),
            "name": row.get("name", "").strip(),
            "category": row.get("category", "").strip(),
        })

# Set widths based on data but cap so lines stay compact.
name_width = min(max((len(r["name"]) for r in rows), default=4), 28)
cat_width = min(max((len(r["category"]) for r in rows), default=4), 18)

for r in rows:
    symbol = r["symbol"]
    name = fit(r["name"] or "", name_width)
    category = fit(r["category"] or "", cat_width)
    # Align columns for readability; separator tab still used for extraction.
    label = f"{symbol:<3} {name} {category}"
    print(f"{label}\t{symbol}")
PY
)"

selection="$(printf '%s\n' "${menu_input}" | wofi --dmenu --prompt "Pick symbol" --matching fuzzy --insensitive --cache-file /dev/null)"

[[ -n "${selection}" ]] || exit 0

symbol="${selection##*$'\t'}"

printf '%s' "${symbol}" | wl-copy
printf 'Copied: %s\n' "${symbol}"
