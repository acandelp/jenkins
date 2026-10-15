#!/bin/bash
set -euo pipefail

TOP_N=${1:-5}

echo "Checking top $TOP_N resource consumers (current usage)..." >&2

# Get CPU usage by namespace (convert from millicores to cores)
echo "CPU"
oc adm top pods --all-namespaces --no-headers 2>/dev/null | \
  awk '{
    # Parse CPU value from column 3 (remove "m" for millicores)
    cpu = $3
    if (cpu ~ /m$/) {
      cpu_cores = substr(cpu, 1, length(cpu)-1) / 1000
    } else {
      cpu_cores = cpu
    }
    cpu_total[$1] += cpu_cores
  } END {
    for (ns in cpu_total) print ns "|" cpu_total[ns]
  }' | \
  sort -t'|' -k2 -rn | \
  head -n "$TOP_N"

# Get Memory usage by namespace (in bytes)
echo "MEMORY"
oc adm top pods --all-namespaces --no-headers 2>/dev/null | \
  awk '{
    # Parse memory value from column 4 (could be Mi or Gi)
    mem = $4
    if (mem ~ /Mi$/) {
      mem_bytes = substr(mem, 1, length(mem)-2) * 1024 * 1024
    } else if (mem ~ /Gi$/) {
      mem_bytes = substr(mem, 1, length(mem)-2) * 1024 * 1024 * 1024
    } else {
      mem_bytes = mem
    }
    memory[$1] += mem_bytes
  } END {
    for (ns in memory) print ns "|" memory[ns]
  }' | \
  sort -t'|' -k2 -rn | \
  head -n "$TOP_N"
