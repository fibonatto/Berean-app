#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
dir="Berean/Resources/Library"
status=0

for file in "$dir"/library-*.json; do
  if ! jq -e '
    (.id | type == "string")
    and (.kind | IN("creed", "prayer", "confession", "catechism"))
    and (.language | type == "string")
    and (.title | type == "string")
    and (.sections | type == "array" and length > 0)
    and all(.sections[].blocks[];
      (.type == "paragraph" and (.text | type == "string"))
      or (.type == "verse" and (.lines | type == "array" and length > 0))
      or (.type == "qa" and (.number | type == "number")
          and (.question | type == "string") and (.answer | type == "string")))
  ' "$file" >/dev/null; then
    echo "invalid: $file"
    status=1
  fi
done

duplicates=$(jq -s -r '
  group_by([.id, .language])
  | map(select(length > 1) | "\(.[0].id) (\(.[0].language))")
  | .[]
' "$dir"/library-*.json)

if [ -n "$duplicates" ]; then
  echo "duplicate documents:"
  echo "$duplicates"
  status=1
fi

exit "$status"
