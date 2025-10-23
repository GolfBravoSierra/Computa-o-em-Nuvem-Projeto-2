#!/usr/bin/env bash
# Uso: run_in_namespace.sh <path_to_c_file> <cpus> <mem_mb> [timeout_secs]
set -euo pipefail

CFILE="$1"
CPUS="$2"   
MEM_MB="$3" 
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

# create network namespace and run inside with limited resources using cgroups v1 (cpu/memory)
NS_NAME="ns_$$"
CGROUP_DIR="/sys/fs/cgroup"

# create namespace
ip netns add "$NS_NAME" || true



IS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
  IS_ROOT=1
fi

write_to() {
  # write_to <file> <content>
  local _file="$1"
  shift
  local _content="$*"
  if [ "$IS_ROOT" -eq 1 ]; then
    printf '%s' "$_content" > "$_file" || true
  else
    printf '%s' "$_content" | sudo tee "$_file" >/dev/null || true
  fi
}

mkdir_p() {
  local _dir="$1"
  if [ "$IS_ROOT" -eq 1 ]; then
    mkdir -p "$_dir" || true
  else
    sudo mkdir -p "$_dir" || true
  fi
}

rmdir_safe() {
  local _dir="$1"
  if [ "$IS_ROOT" -eq 1 ]; then
    rmdir "$_dir" || true
  else
    sudo rmdir "$_dir" || true
  fi
}

# create a cgroup per run
CGROUP_BASE="/sys/fs/cgroup"
CPU_CGROUP="$CGROUP_BASE/cpu/ns_$$"
MEM_CGROUP="$CGROUP_BASE/memory/ns_$$"
mkdir_p "$CPU_CGROUP"
mkdir_p "$MEM_CGROUP"

# Convert CPUS to cpu.cfs_quota_us relative to 100000 period
PERIOD=100000
QUOTA=$(awk -v c="$CPUS" -v p="$PERIOD" 'BEGIN{printf "%d", c * p}')
write_to "$CPU_CGROUP/cpu.cfs_quota_us" "$QUOTA"
write_to "$CPU_CGROUP/cpu.cfs_period_us" "$PERIOD"

# set memory limit in bytes
MEM_BYTES=$((MEM_MB * 1024 * 1024))
write_to "$MEM_CGROUP/memory.limit_in_bytes" "$MEM_BYTES"

# run the program and measure time
START=$(date +%s.%N)

./prog &
PID=$!
# add to cgroups
write_to "$CPU_CGROUP/tasks" "$PID" || true
write_to "$MEM_CGROUP/tasks" "$PID" || true

# kill process if it exceeds timeout
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

# kill  if still running
kill -9 "$WATCH_PID" 2>/dev/null || true

# calculate elapsed
ELAPSED=$(awk -v s="$START" -v e="$END" 'BEGIN{printf "%.3f", e - s}')

# cleanup
sleep 0.1
rmdir_safe "$CPU_CGROUP"
rmdir_safe "$MEM_CGROUP"

ip netns delete "$NS_NAME" || true

# output execution time in a parseable format
echo "EXECUTION_TIME:$ELAPSED"

# cleanup workdir
cd /tmp
rm -rf "$WORKDIR"
