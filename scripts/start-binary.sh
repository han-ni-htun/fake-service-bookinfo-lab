#!/usr/bin/env bash
# Launch the four services as independent local processes, without Docker.
set -euo pipefail

# Resolve the repository root and binary path. Download fake-service separately.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${FAKE_SERVICE_BIN:-${ROOT_DIR}/fake-service}"
RUN_DIR="${ROOT_DIR}/.run"

# Fail early if the binary is absent or cannot be executed.
if [[ ! -x "$BIN" ]]; then
  echo "Missing executable: $BIN" >&2
  echo "Download the matching binary from https://github.com/nicholasjackson/fake-service/releases/" >&2
  echo "Place it at the repo root as ./fake-service and run chmod +x ./fake-service." >&2
  exit 1
fi

# Avoid conflicting with an already-running binary/Compose deployment.
for port in 9090 9091 9092 9093; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $port is already in use. Stop the existing process before starting." >&2
    exit 1
  fi
done

# Keep logs and PIDs outside tracked source files.
mkdir -p "$RUN_DIR"

# Start leaf services before services that depend on them.
(
  cd "$RUN_DIR"
  NAME=details MESSAGE="Book Details" LISTEN_ADDR=127.0.0.1:9091 "$BIN" >details.log 2>&1 & echo $! >details.pid
  NAME=ratings MESSAGE="Book Ratings" LISTEN_ADDR=127.0.0.1:9093 "$BIN" >ratings.log 2>&1 & echo $! >ratings.pid
  NAME=reviews MESSAGE="Book Reviews" LISTEN_ADDR=127.0.0.1:9092 UPSTREAM_URIS=http://127.0.0.1:9093 "$BIN" >reviews.log 2>&1 & echo $! >reviews.pid
  NAME=productpage MESSAGE="Hello from Bookinfo Product Page" LISTEN_ADDR=127.0.0.1:9090 UPSTREAM_URIS=http://127.0.0.1:9091,http://127.0.0.1:9092 UPSTREAM_WORKERS=2 "$BIN" >productpage.log 2>&1 & echo $! >productpage.pid
)

# Print local endpoint and where to find logs.
echo "Started four local fake-service processes."
echo "Test: curl -i http://127.0.0.1:9090"
echo "UI:   http://127.0.0.1:9090/ui/"
echo "Logs: $RUN_DIR"
