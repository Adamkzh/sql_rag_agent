#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[start] %s\n' "$*"
}

cleanup() {
  echo
  echo "Stopping dev servers..."
  kill "$BACK_PID" "$FRONT_PID" 2>/dev/null || true
}
trap cleanup EXIT

cd "$ROOT"
log "Starting backend (uvicorn server:app --reload --port 8000)..."
uvicorn server:app --reload --port 8000 &
BACK_PID=$!

log "Starting frontend (npm run dev -- --host --port 5173)..."
cd "$ROOT/ui"
npm run dev -- --host --port 5173 &
FRONT_PID=$!

cd "$ROOT"
log "Backend PID: $BACK_PID, Frontend PID: $FRONT_PID"
log "Press Ctrl+C to stop both."

# macOS ships an older bash without wait -n; poll instead.
while true; do
  if ! kill -0 "$BACK_PID" 2>/dev/null; then
    EXITED=$BACK_PID
    break
  fi
  if ! kill -0 "$FRONT_PID" 2>/dev/null; then
    EXITED=$FRONT_PID
    break
  fi
  sleep 1
done

# Capture exit status for the process that finished first.
STATUS=0
wait "$EXITED" || STATUS=$?
echo "Process $EXITED exited (status $STATUS); shutting down..."
