#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failed=0

cat > "$WORK/sysctl" <<'STAND_IN'
#!/bin/bash
for key in "$@"; do
  case "$key" in
    hw.ncpu) echo "$CORES" ;;
    hw.memsize) echo $((GB << 30)) ;;
    kern.memorystatus_level) echo "$FREE_PERCENT" ;;
  esac
done
STAND_IN
chmod +x "$WORK/sysctl"

expect() {
  local want="$1" machine="$2" got rc=0
  shift 2
  got="$(env PATH="$WORK:$PATH" $machine "$HERE/lanes.sh" "$@" 2> /dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || got="exit $rc"
  [ "$got" = "$want" ] || { echo "✘ lanes.sh $* on $machine: printed '$got', expected '$want'" >&2; failed=1; }
}

idle="CORES=16 GB=64 FREE_PERCENT=50"
busy="CORES=8 GB=16 FREE_PERCENT=10"
expect 16 "$idle" 1
expect 16 "$idle" 2
expect 8 "$idle" 4
expect 12 "$idle" 2.5
expect 1 "$busy" 2
expect "exit 2" "$idle"
expect "exit 2" "$idle" 0
expect "exit 2" "$idle" 0.0
expect "exit 2" "$idle" two
expect "exit 2" "$idle" 2 3

here="$("$HERE/lanes.sh" 1 2> /dev/null)"
[[ $here =~ ^[1-9][0-9]*$ ]] || { echo "✘ lanes.sh 1 on this machine: printed '$here', expected a count of at least one" >&2; failed=1; }

exit $failed
