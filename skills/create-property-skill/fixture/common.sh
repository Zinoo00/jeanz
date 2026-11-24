sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }

start_fixture() {
  PORT="$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  BASE="http://127.0.0.1:$PORT"
  mkdir -p "$EVIDENCE"
  SERVER_LOG="$EVIDENCE/server.log"
  python3 -I "$SKILL/fixture/server.py" "$PORT" "$SKILL/fixture/app" > "$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  disown "$SERVER_PID"
  for _ in $(seq 20); do curl -s -o /dev/null "$BASE/login.html" && break; sleep 0.5; done
}

login_with() { echo "curl -s -D - -o /dev/null -X POST -d password=$1 $BASE/login | sed -n 's/^Set-Cookie: \\([^;]*\\).*/\\1/p'"; }

copy() {
  local dest="$WORK/$1" login="$2" disposable="$3"
  mkdir -p "$dest"
  cp -R "$SKILL/templates/." "$dest/"
  cp "$SKILL/fixture/config.ts" "$SKILL/fixture/properties.ts" "$SKILL/fixture/actions.ts" "$dest/spec/"
  chmod +x "$dest/props.sh"
  sed -e 's/<app>/fixture/g' -e 's/<run-command>/python3 server.py/g' -e 's/<stop-command>/kill the server/g' "$dest/SKILL.md.template" > "$dest/SKILL.md"
  rm "$dest/SKILL.md.template"
  echo '| `spinnerClears` | The spinner clears within 3 seconds |' >> "$dest/SKILL.md"
  {
    echo "ORIGIN=\"$BASE/app.html\""
    echo "READY_URL=\"$BASE/app.html\""
    echo "READY_TEXT=\"signed in as fixture\""
    echo "DISPOSABLE=\"$disposable\""
    echo "DISPOSABLE_HOSTS=()"
    echo "WIDTH=1024"
    echo "HEIGHT=768"
    printf 'LOGIN=%q\n' "$login"
    echo "HEADERS=()"
    echo "BOMBADIL_ARGS=()"
    echo "OUT_ROOT=\"$EVIDENCE\""
  } > "$dest/props.config.sh"
  echo "$dest"
}

reseal() {
  local files
  files="$(awk '{print $2}' "$1/SEALED.sha256")"
  (cd "$1" && sha $files > SEALED.sha256)
}

run_dir_of() { echo "$1" | sed -n 's/^run: \([^ ]*\) .*/\1/p'; }
exit_of() { local rc=0; "$@" > "$EVIDENCE/last.out" 2>&1 || rc=$?; echo "$rc"; }
