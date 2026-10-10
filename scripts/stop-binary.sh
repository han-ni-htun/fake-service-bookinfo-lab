#!/usr/bin/env bash
# Stop only processes recorded by the local start script.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${ROOT_DIR}/.run"

# Validate PID command lines before sending SIGTERM, in case a PID was reused.
for service in productpage reviews ratings details; do
  pid_file="${RUN_DIR}/${service}.pid"
  [[ -f "$pid_file" ]] || continue
  pid="$(cat "$pid_file")"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$command_line" == *fake-service* ]]; then
      kill "$pid" 2>/dev/null || true
      echo "Stopped $service (PID $pid)"
    else
      echo "Skipped $service: PID $pid is not fake-service" >&2
    fi
  fi
  rm -f "$pid_file"
done
