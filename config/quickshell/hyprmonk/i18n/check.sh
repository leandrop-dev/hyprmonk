#!/usr/bin/env bash
# Checks a translation against the shell (services/I18n.qml):
#   missing   texts the shell shows that the file does not translate
#   unused    texts in the file that nothing shows any more
#   unwrapped QML text properties holding a plain literal, not through I18n
# The texts are every literal in I18n.tr("…"), I18n.mark("…") and
# I18n.trn("…", "…"), and the key guide's sections and descriptions, read
# from the running Hyprland (hypr/binds.lua). Run from anywhere:
#   i18n/check.sh [pt_PT]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
shell=$(dirname "$here")
file="$here/${1:-pt_PT}.json"

# Each text as a JSON string, one per line: the literal as written in QML,
# whose escapes (\n, \") JSON reads the same way.
texts() {
    grep -rhoP 'I18n\.(tr|mark)\(\s*"(?:[^"\\]|\\.)*"' "$shell" --include='*.qml' \
        | sed -E 's/^I18n\.(tr|mark)\(\s*//'
    grep -rhoP 'I18n\.trn\(\s*"(?:[^"\\]|\\.)*"\s*,\s*"(?:[^"\\]|\\.)*"' "$shell" --include='*.qml' \
        | sed -E 's/^I18n\.trn\(\s*//' | grep -oP '"(?:[^"\\]|\\.)*"'
    grep -rhoP 'I18n\.trc\(\s*"[^"]*"\s*,\s*"(?:[^"\\]|\\.)*"' "$shell" --include='*.qml' \
        | sed -E 's/^I18n\.trc\(\s*"([^"]*)"\s*,\s*"/"\1|/'
    if command -v hyprctl > /dev/null && hyprctl binds -j > /dev/null 2>&1; then
        hyprctl binds -j | jq -c '.[].description | select(. != "") | capture("^(?<s>[^:]*): (?<d>.*)$") | .s, .d'
    fi
}

wanted=$(texts | jq -s 'unique')
have=$(jq 'keys' "$file")

echo "Missing from $(basename "$file"):"
jq -rn --argjson w "$wanted" --argjson h "$have" '$w - $h | .[] | "  " + (. | tojson)'
echo "Unused in $(basename "$file"):"
jq -rn --argjson w "$wanted" --argjson h "$have" '$h - $w | .[] | "  " + (. | tojson)'
echo "Unwrapped (QML text properties with a plain literal):"
grep -rnP '^\s*(text|tooltip|placeholder|message|note|title|caption|label|detail|description|summary)\s*:\s*.*"[^"\\]*[A-Za-z]{2}[^"]*"' "$shell" --include='*.qml' \
    | grep -v 'I18n\.' | sed "s|^$shell/|  |" || true
