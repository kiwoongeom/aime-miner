# Aime Miner Package

> Self-contained CPU miner for Aime cryptocurrency.
> Uses XMRig — the standard RandomX miner.

## Quick Start

### 1. Install (first time only)

```bash
bash install_xmrig.sh
```

Builds XMRig from source. Takes ~10-20 min.
Output: `xmrig/build/xmrig` (and copy to `~/.local/bin/aime-xmrig`)

### 2. Mine

```bash
./aime-mine.sh <YOUR_AIME_ADDRESS>
```

Defaults:
- Half your CPU cores
- Solo mining via local Aime node at `127.0.0.1:17081` (you must be running `aimed`)

### 3. Stop

- **Ctrl+C** — clean stop
- **Close terminal window** — auto-stop via SIGHUP
- **Watchdog** — if parent shell dies silently, miner is killed within 10 min

## Examples

### Solo mining (local Aime node)
```bash
# In one terminal: run the daemon
./aimed

# In another terminal: start mining
./aime-mine.sh AQWWPyLG4exW1QNg2HZnGBgoXxkKCPf2WetZCd3n4k7nPusWGoC73nKRcUuEvCkZ1d26kNGgbuXGf7DcaJADpN484v1XjDr 4
```

### Pool mining (when pool exists)
```bash
./aime-mine.sh AQWWPyLG4... 4 pool.aime.network:3333
```

### All threads
```bash
./aime-mine.sh AQWWPyLG4... $(nproc)
```

## What you'll see (CLI behavior)

XMRig is a terminal application. Output looks like:

```
 * ABOUT        XMRig/6.22.0 gcc/13.3.0
 * LIBS         libuv/1.48.0 OpenSSL/3.0.13 hwloc/2.10.0
 * HUGE PAGES   supported
 * 1GB PAGES    disabled
 * CPU          AMD Ryzen Threadripper 3960X 24-Core Processor (1)
                 64-bit AES VM
                 L2:12.0 MB L3:128.0 MB 24C/48T NUMA:1
 * MEMORY       2.6/93.7 GB (3%)
 * MOTHERBOARD  ASUS - PRIME TRX40-PRO
 * DONATE       1%
 * ASSEMBLY     auto:ryzen
 * POOL #1      127.0.0.1:17081 algo auto
 * COMMANDS     'h' hashrate, 'p' pause, 'r' resume, 's' results, 'c' connection
[2026-04-28 12:34:56.789]  net      use pool 127.0.0.1:17081
[2026-04-28 12:34:56.890]  cpu      use profile rx (4 threads)
[2026-04-28 12:34:57.012]  randomx  init dataset algo rx/0 (4 threads)
[2026-04-28 12:34:58.123]  randomx  dataset ready (1112 ms)
[2026-04-28 12:34:58.234]  cpu      START hashrate threads 4 max 4
[2026-04-28 12:35:58.345]  miner    speed 10s/60s/15m  6.2  6.1  n/a   H/s
[2026-04-28 12:36:58.456]  miner    speed 10s/60s/15m  6.3  6.2  6.1   H/s
```

Live updating display. Press `h` for hashrate snapshot, `Ctrl+C` to stop.

## Auto-stop behavior

The wrapper script ensures the miner doesn't survive your terminal session:

| Event | Behavior |
|---|---|
| You press Ctrl+C | Miner stops cleanly (within 3 seconds) |
| You close terminal X button | SIGHUP → miner stops (~1 second) |
| You run `kill <miner PID>` | Trap catches SIGTERM → cleanup |
| You SSH disconnect | SSH kills shell → SIGHUP → miner stops |
| Edge case: shell dies but signal lost | Watchdog catches within 10 min, kills miner |

You should NEVER have a stranded XMRig process consuming CPU.

## Verify it stopped

```bash
pgrep -f xmrig
# If empty, miner is fully stopped
```

## Files

- `install_xmrig.sh` — One-time setup script (builds XMRig)
- `aime-mine.sh` — Mining wrapper with auto-stop + watchdog
- `xmrig/` — XMRig source tree (after install_xmrig.sh)
- `xmrig/build/xmrig` — Compiled miner binary
- `~/.aime-miner.log` — Mining logs (auto-rotated)

## Mining Performance

Expected hashrates with the `aime-mine.sh` defaults:

| CPU | Hashrate |
|---|---|
| Intel i5-8400 (6c/6t) | ~3 KH/s |
| AMD Ryzen 5 5600 (6c/12t) | ~6 KH/s |
| Intel i9-13900K (24c/32t) | ~18 KH/s |
| AMD Threadripper 3960X (24c/48t) | ~30 KH/s |

To maximize hashrate:
- Enable hugepages: `sudo sysctl -w vm.nr_hugepages=1280`
- Use all physical cores (not hyperthreads): `--threads=<physical_core_count>`
- Set CPU governor to performance: `sudo cpupower frequency-set -g performance`
- Disable other CPU-heavy programs

## Troubleshooting

### "xmrig binary not found"
Run `bash install_xmrig.sh` first.

### "RandomX dataset init slow"
First mine takes ~30s to build the 256MB RandomX dataset. Subsequent runs reuse it.

### "Pool unreachable" or "Connection refused"
- Verify aimed is running: `pgrep -a aimed`
- Verify RPC port: `curl http://127.0.0.1:17081/get_info`
- Check pool URL/port

### Hashrate way lower than expected
- Disable CPU power saving
- Enable hugepages
- Check `htop` — should see threads at 100% CPU
- Try MSR mod: run as root once: `sudo aime-xmrig --rdmsr`

### Background mining (detach from terminal)
If you want mining to survive terminal close, use `screen` or `tmux`:

```bash
# Start in screen session
screen -S aime-miner
./aime-mine.sh <ADDR> 4
# Detach with Ctrl+A, D
# Re-attach later: screen -r aime-miner
```

But our wrapper assumes foreground — if you detach, the watchdog/auto-stop still works (kills miner if outer process dies).

## Distribution

To share with another miner:

```bash
# On your machine
cd /root/aime/miner-package
tar czf aime-miner.tar.gz install_xmrig.sh aime-mine.sh README.md

# (Optionally, also include pre-built binary if recipient has compatible CPU/OS)
tar czf aime-miner-prebuilt.tar.gz install_xmrig.sh aime-mine.sh README.md xmrig/build/xmrig
```

Recipient:
```bash
tar xzf aime-miner.tar.gz
cd aime-miner
bash install_xmrig.sh   # Skip if pre-built binary included
./aime-mine.sh <THEIR_ADDRESS>
```
