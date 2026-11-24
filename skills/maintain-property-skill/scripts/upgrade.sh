#!/bin/bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")/../../create-property-skill" && pwd)"
TEMPLATES="$SOURCE/templates"
SHIPPED="$SOURCE/sealed-history.txt"
TARGET="${1:-}"
[ -n "$TARGET" ] && [ -f "$TARGET/props.config.sh" ] && [ -f "$TARGET/spec/config.ts" ] || {
  echo "usage: upgrade.sh <properties-skill-folder>" >&2
  exit 64
}
left=0
if [ -d "$TARGET/replaced" ]; then
  echo "replaced/ still holds what the last upgrade kept: $(ls "$TARGET/replaced" | tr '\n' ' ')"
  echo "Move what this app needs into the app's files, delete the folder, then run the upgrade again."
  exit 2
fi

sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }

note() {
  echo "$1"
  left=1
}

shipped() { grep -qxF "$(cd "$TARGET" && sha "$1")" "$SHIPPED"; }

keep_edit() {
  local file="$1"
  [ -f "$TARGET/$file" ] || return 0
  ! shipped "$file" || return 0
  mkdir -p "$TARGET/replaced"
  cp "$TARGET/$file" "$TARGET/replaced/$(basename "$file")"
  note "$file was edited here. The edited copy is replaced/$(basename "$file"): move what this app needs into the app's files, then delete the copy"
}

changed=0
while read -r _ file; do
  cmp -s "$TEMPLATES/$file" "$TARGET/$file" && continue
  keep_edit "$file"
  mkdir -p "$(dirname "$TARGET/$file")"
  cp "$TEMPLATES/$file" "$TARGET/$file"
  echo "updated $file"
  changed=$((changed + 1))
done < "$TEMPLATES/SEALED.sha256"

for file in "$TARGET"/spec/*.ts; do
  name="spec/$(basename "$file")"
  case "$name" in spec/config.ts | spec/actions.ts | spec/properties.ts) continue ;; esac
  grep -q " $name\$" "$TEMPLATES/SEALED.sha256" && continue
  if shipped "$name"; then
    rm "$file"
    echo "removed $name, which jeanz no longer ships"
  else
    note "$name is not a sealed file: delete it, or move it into a folder under spec/ when it is this app's own"
  fi
done
cp "$TEMPLATES/SEALED.sha256" "$TARGET/SEALED.sha256"
chmod +x "$TARGET/props.sh"
echo "$changed sealed file(s) updated in $TARGET"

for app in config actions properties; do
  [ -f "$TARGET/spec/$app.ts" ] || continue
  while read -r path; do
    [ -f "$TARGET/spec/$path" ] || note "spec/$app.ts imports ./$path, which is not there: $TEMPLATES/spec/$app.ts shows the import and the names to use"
  done < <(sed -nE 's/.*from "\.\/([^"]+)".*/\1/p' "$TARGET/spec/$app.ts")
done
for name in $(grep -oE '^export const [A-Z_]+' "$TEMPLATES/spec/config.ts" | awk '{print $3}'); do
  grep -qE "^export const $name[^A-Z_]" "$TARGET/spec/config.ts" || note "spec/config.ts lacks $name: copy its line from $TEMPLATES/spec/config.ts and fill it for this app"
done
for name in $(grep -oE '^[A-Z_]+=' "$TEMPLATES/props.config.sh" | tr -d '='); do
  grep -qE "^$name=" "$TARGET/props.config.sh" || note "props.config.sh lacks $name: copy its line from $TEMPLATES/props.config.sh"
done
[ $left -eq 0 ] || exit 2
