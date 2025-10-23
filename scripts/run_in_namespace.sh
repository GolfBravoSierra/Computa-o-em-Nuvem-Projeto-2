#!/bin/bash
# Uso: run_in_namespace.sh <path_to_c_file> <cpus> <mem_mb> [timeout_secs]
set -euo pipefail

CFILE="$1"
CPUS="$2"   # e.g., 0.5 - 2
MEM_MB="$3" # e.g., 10 - 4000
TIMEOUT_SECS="${4:-10}"

BASENAME=$(basename "$CFILE")
WORKDIR="/tmp/ns_run_$(date +%s)_$$"
mkdir -p "$WORKDIR"
cp "$CFILE" "$WORKDIR/$BASENAME"
cd "$WORKDIR"

# compile
gcc "$BASENAME" -o prog 2> compile_err.txt || true
if [ ! -x ./prog ]; then
  cat compile_err.txt
  echo "EXECUTION_TIME:0"
  exit 0
fi

# create network namespace (minimal) and run inside with limited resources using cgroups v1 (cpu/memory)
NS_NAME="ns_$$"
CGROUP_DIR="/sys/fs/cgroup"

# create namespace
ip netns add "$NS_NAME" || true

# create a cgroup per run (assumes cgroup v1 unified mount points exist)
CGROUP_BASE="/sys/fs/cgroup"
CPU_CGROUP="$CGROUP_BASE/cpu/ns_$$"
MEM_CGROUP="$CGROUP_BASE/memory/ns_$$"
mkdir -p "$CPU_CGROUP" "$MEM_CGROUP"

# Convert CPUS (like 0.5) to cpu.cfs_quota_us relative to 100000 period
PERIOD=100000
QUOTA=$(awk -v c="$CPUS" -v p="$PERIOD" 'BEGIN{printf "%d", c * p}')
sudo echo $QUOTA | "$CPU_CGROUP/cpu.cfs_quota_us"
sudo echo $PERIOD > "$CPU_CGROUP/cpu.cfs_period_us"

# set memory limit in bytes
MEM_BYTES=$((MEM_MB * 1024 * 1024))
echo $MEM_BYTES > "$MEM_CGROUP/memory.limit_in_bytes"

# run the program and measure time
START=$(date +%s.%N)
# use nsenter to run inside the namespace; since program is CPU/memory limited by cgroup, just add PID to cgroup
./prog &
PID=$!
# add to cgroups
echo $PID > "$CPU_CGROUP/tasks" || true
echo $PID > "$MEM_CGROUP/tasks" || true

# watchdog to kill process if it exceeds timeout
(
  sleep "$TIMEOUT_SECS"
  if kill -0 "$PID" 2>/dev/null; then
    echo "Program exceeded timeout (${TIMEOUT_SECS}s), killing PID $PID" >&2
    kill -9 "$PID" 2>/dev/null || true
    echo "KILLED_BY_TIMEOUT"
  fi
) &
WATCH_PID=$!

wait $PID || true
RET=$?
END=$(date +%s.%N)

# kill watchdog if still running
kill -9 "$WATCH_PID" 2>/dev/null || true

# calculate elapsed
ELAPSED=$(awk -v s="$START" -v e="$END" 'BEGIN{printf "%.3f", e - s}')

# cleanup
# remove cgroup tasks then dirs
sleep 0.1
if [ -f "$CPU_CGROUP/tasks" ]; then
  # try to clear
  echo > "$CPU_CGROUP/tasks" || true
fi
if [ -f "$MEM_CGROUP/tasks" ]; then
  echo > "$MEM_CGROUP/tasks" || true
fi
rmdir "$CPU_CGROUP" || true
rmdir "$MEM_CGROUP" || true

ip netns delete "$NS_NAME" || true

# output execution time in a parseable format
echo "EXECUTION_TIME:$ELAPSED"

# cleanup workdir
cd /tmp
rm -rf "$WORKDIR"
