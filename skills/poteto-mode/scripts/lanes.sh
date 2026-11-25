#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: lanes.sh <GB per lane>" >&2
  echo "  GB per lane   the memory one lane takes at its peak: its instance of the app, its browser, and its agent" >&2
  exit 2
}
per_lane="${1:-}"
[ $# -eq 1 ] || usage
[[ $per_lane =~ ^[0-9]*\.?[0-9]+$ ]] && awk -v p="$per_lane" 'BEGIN { exit !(p > 0) }' || usage

if mac="$(sysctl -n hw.ncpu hw.memsize kern.memorystatus_level 2> /dev/null)"; then
  read -r cores bytes free_percent <<< "$(tr '\n' ' ' <<< "$mac")"
  free_gb="$(awk -v b="$bytes" -v p="$free_percent" 'BEGIN { print b * p / 100 / 2^30 }')"
elif [ -r /proc/meminfo ]; then
  cores="$(getconf _NPROCESSORS_ONLN)"
  free_gb="$(awk '$1 == "MemAvailable:" { print $2 / 2^20 }' /proc/meminfo)"
else
  echo "lanes.sh: cannot read the cores and the free memory of this machine" >&2
  exit 1
fi

awk -v cores="$cores" -v free="$free_gb" -v per="$per_lane" 'BEGIN {
  by_memory = int(free / per)
  lanes = cores < by_memory ? cores : by_memory
  if (lanes < 1) lanes = 1
  print lanes
  printf "%d cores, %.1f GB free, %s GB per lane: %d by memory\n", cores, free, per, by_memory > "/dev/stderr"
}'
