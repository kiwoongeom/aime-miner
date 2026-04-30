#!/bin/bash
# Aime mining wrapper — dual mode with auto-stop + watchdog.
#
# Address resolution order:
#   1. Command-line argument $1
#   2. AIME_ADDRESS environment variable
#   3. ~/.aime/last-wallet-address.txt (auto-saved by aime-wallet-cli)
#   4. ./aime-address.txt (per-folder override)
#   → If none found, prints help.
#
# SOLO mode (when POOL is a daemon RPC port like 17081):
#   - Uses aimed's built-in miner via start_mining RPC
#   - Polls get_info every 5s for live status display
#   - On exit: calls stop_mining RPC
#
# POOL mode (when POOL is a stratum URL):
#   - Uses XMRig directly
#   - On exit: kills XMRig process
#
# Both modes:
#   - Press Ctrl+C → clean stop
#   - Close terminal → SIGHUP → auto-stop
#   - Watchdog: every 10 min checks parent shell, kills if gone

set -uo pipefail

# ===== ADDRESS RESOLUTION =====
ADDR=""
ADDR_SOURCE=""
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
    ADDR="$1"
    ADDR_SOURCE="command-line argument"
elif [ -n "${AIME_ADDRESS:-}" ]; then
    ADDR="$AIME_ADDRESS"
    ADDR_SOURCE="AIME_ADDRESS env var"
elif [ -f "$HOME/.aime/last-wallet-address.txt" ]; then
    ADDR=$(head -1 "$HOME/.aime/last-wallet-address.txt" | tr -d '[:space:]')
    ADDR_SOURCE="$HOME/.aime/last-wallet-address.txt"
elif [ -f "./aime-address.txt" ]; then
    ADDR=$(head -1 "./aime-address.txt" | tr -d '[:space:]')
    ADDR_SOURCE="./aime-address.txt"
fi

if [ -z "$ADDR" ]; then
    cat <<EOF
Usage: $0 [AIME_ADDRESS] [THREADS] [POOL]

No address found. Set one of:
  1. Command line:    $0 AQWWPyLG... 4
  2. Environment:     export AIME_ADDRESS=AQWWPyLG...
                      $0
  3. Saved file:      mkdir -p ~/.aime
                      echo "AQWWPyLG..." > ~/.aime/last-wallet-address.txt
                      $0
  4. Per-folder:      echo "AQWWPyLG..." > ./aime-address.txt
                      $0

Examples:
  $0 AQWWPyLG4exW1... 4                      (solo mining via local node)
  $0 AQWWPyLG4... 4 pool.aime.network:3333   (pool mining)
  $0 "" 8                                     (auto-load address, 8 threads)

Auto-stop: Ctrl+C, terminal close, or watchdog (10min check).

EOF
    exit 1
fi

# Address sanity check
if [[ ! "$ADDR" =~ ^A[a-zA-Z0-9]{94}$ ]]; then
    echo "[WARN] Address does not match expected Aime format (95 chars starting with 'A')" >&2
    echo "[WARN] Got: $ADDR" >&2
    sleep 2
fi

# ===== ARGS =====
THREADS="${2:-$(($(nproc) / 2))}"
POOL="${3:-127.0.0.1:17081}"

# Detect mode
MODE="POOL"
if [[ "$POOL" == *":17081" ]] || [[ "$POOL" == *":27081" ]] || [[ "$POOL" == *":37081" ]]; then
    MODE="SOLO"
fi

SCRIPT_PID=$$
PARENT_PID=$PPID
WATCHDOG_PID=""
XMRIG_PID=""

# ============= SOLO MODE =============
solo_mine() {
    echo "[INFO] SOLO mode — mining via Aime daemon at $POOL"
    echo "[INFO] Address: $ADDR (from $ADDR_SOURCE)"
    echo "[INFO] Threads: $THREADS"

    if ! curl -s --max-time 3 "http://$POOL/get_info" | grep -q '"status".*"OK"'; then
        echo "[ERROR] Cannot reach Aime daemon at $POOL"
        echo "[ERROR] Is aimed running? Try: pgrep -a aimed"
        exit 1
    fi

    RESP=$(curl -s -X POST "http://$POOL/start_mining" \
        -H 'Content-Type: application/json' \
        -d "{\"miner_address\":\"$ADDR\",\"threads_count\":$THREADS,\"do_background_mining\":false,\"ignore_battery\":true}")

    if ! echo "$RESP" | grep -q '"status".*"OK"'; then
        echo "[ERROR] start_mining failed:"
        echo "$RESP"
        exit 1
    fi
    echo "[INFO] Mining started inside aimed daemon."
    echo "[INFO] Press Ctrl+C to stop"
    echo ""

    PREV_HEIGHT=0
    BLOCKS_THIS_SESSION=0

    while true; do
        sleep 5
        INFO=$(curl -s "http://$POOL/get_info")
        HEIGHT=$(echo "$INFO" | python3 -c "import json,sys;print(json.load(sys.stdin).get('height',0))" 2>/dev/null || echo 0)
        DIFF=$(echo "$INFO" | python3 -c "import json,sys;print(json.load(sys.stdin).get('difficulty',0))" 2>/dev/null || echo 0)

        if [ "$HEIGHT" -gt "$PREV_HEIGHT" ] && [ "$PREV_HEIGHT" -gt 0 ]; then
            NEW_BLOCKS=$((HEIGHT - PREV_HEIGHT))
            BLOCKS_THIS_SESSION=$((BLOCKS_THIS_SESSION + NEW_BLOCKS))
            echo "[$(date +%H:%M:%S)] +$NEW_BLOCKS block(s) found! Total this session: $BLOCKS_THIS_SESSION"
        fi
        PREV_HEIGHT=$HEIGHT

        printf "\r[STATUS] height=%-6s  diff=%-12s  session_blocks=%-3s  time=%s" \
            "$HEIGHT" "$DIFF" "$BLOCKS_THIS_SESSION" "$(date +%H:%M:%S)"
    done
}

solo_cleanup() {
    echo ""
    echo "[INFO] Stopping miner via stop_mining RPC..."
    curl -s -X POST "http://$POOL/stop_mining" >/dev/null 2>&1 || true
}

# ============= POOL MODE =============
pool_mine() {
    echo "[INFO] POOL mode — mining via stratum at $POOL"
    echo "[INFO] Address: $ADDR (from $ADDR_SOURCE)"
    echo "[INFO] Threads: $THREADS"

    XMRIG_LOCAL="$(dirname "$(readlink -f "$0")")/xmrig-bin"
    XMRIG_LOCAL2="$(dirname "$(readlink -f "$0")")/xmrig/build/xmrig"
    if [ -x "$XMRIG_LOCAL" ]; then
        XMRIG="$XMRIG_LOCAL"
    elif [ -x "$XMRIG_LOCAL2" ]; then
        XMRIG="$XMRIG_LOCAL2"
    elif command -v aime-xmrig >/dev/null 2>&1; then
        XMRIG="$(command -v aime-xmrig)"
    else
        echo "[ERROR] xmrig not found. Run: bash install_xmrig.sh"
        exit 1
    fi
    echo "[INFO] Using miner: $XMRIG"

    CONFIG=$(mktemp /tmp/xmrig.aime.XXXXXX.json)
    cat > "$CONFIG" <<EOF
{
    "autosave": false,
    "background": false,
    "colors": true,
    "title": false,
    "randomx": {"init": -1, "mode": "auto", "1gb-pages": false, "rdmsr": true, "wrmsr": true, "numa": true},
    "cpu": {"enabled": true, "huge-pages": true, "huge-pages-jit": true, "yield": true, "threads": $THREADS},
    "pools": [{
        "url": "$POOL",
        "user": "$ADDR",
        "pass": "aime-worker",
        "tls": false,
        "keepalive": true,
        "algo": "rx/0",
        "nicehash": false
    }],
    "log-file": "$HOME/.aime-miner.log",
    "print-time": 60
}
EOF

    "$XMRIG" --config="$CONFIG" &
    XMRIG_PID=$!
    echo "[INFO] Miner PID: $XMRIG_PID"
    wait "$XMRIG_PID"
    rm -f "$CONFIG"
}

pool_cleanup() {
    if [ -n "$XMRIG_PID" ] && kill -0 "$XMRIG_PID" 2>/dev/null; then
        kill -TERM "$XMRIG_PID" 2>/dev/null
        for i in 1 2 3; do
            sleep 1
            kill -0 "$XMRIG_PID" 2>/dev/null || break
        done
        kill -KILL "$XMRIG_PID" 2>/dev/null || true
    fi
}

# ============= COMMON CLEANUP + WATCHDOG =============
CLEANED_UP=false
cleanup() {
    local exit_code=$?
    [ "$CLEANED_UP" = "true" ] && exit "$exit_code"
    CLEANED_UP=true
    echo ""
    echo "[INFO] Cleaning up..."
    if [ -n "$WATCHDOG_PID" ] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        kill -TERM "$WATCHDOG_PID" 2>/dev/null || true
    fi
    if [ "$MODE" = "SOLO" ]; then
        solo_cleanup
    else
        pool_cleanup
    fi
    echo "[INFO] Stopped."
    exit "$exit_code"
}
trap cleanup EXIT INT TERM HUP

# Watchdog
(
    while true; do
        sleep 600
        if ! kill -0 "$PARENT_PID" 2>/dev/null; then
            echo "" >&2
            echo "[WATCHDOG] Parent shell (PID $PARENT_PID) is gone — stopping miner" >&2
            kill -TERM "$SCRIPT_PID" 2>/dev/null
            exit 0
        fi
    done
) &
WATCHDOG_PID=$!
echo "[INFO] Watchdog started (PID $WATCHDOG_PID, interval 10min)"
echo ""

if [ "$MODE" = "SOLO" ]; then
    solo_mine
else
    pool_mine
fi
