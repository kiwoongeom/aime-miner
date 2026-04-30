# Aime Miner Package

> Self-contained CPU miner for Aime cryptocurrency.
> Uses XMRig — the standard RandomX miner.

Supports both **Linux/WSL** (with included pre-built binary) and **Windows** (XMRig downloaded separately).

---

## Quick Start (Linux / macOS / WSL)

### 1. Install (first time only)
```bash
bash install_xmrig.sh
```
Builds XMRig from source. Takes ~10-20 min.

Or just use the pre-built `xmrig-bin` already in this repo (Linux x86-64, 5.3MB).

### 2. Mine
```bash
./aime-mine.sh <YOUR_AIME_ADDRESS>
```
Defaults: 4 threads, solo mining via local Aime node at `127.0.0.1:17081`.

### 3. Stop
- **Ctrl+C** — clean stop
- **Close terminal** — auto-stop via SIGHUP
- **Watchdog** — kills miner if parent shell dies (10 min check)

---

## Quick Start (Windows)

### 1. Get xmrig.exe (one-time)

Download official XMRig Windows binary:
- Go to: https://github.com/xmrig/xmrig/releases/latest
- Download: `xmrig-X.X.X-msvc-win64.zip`
- Extract zip → find `xmrig.exe` inside
- Copy `xmrig.exe` next to `aime-mine.bat` (in this folder)

### 2. Mine

Open Command Prompt or PowerShell, navigate to this folder, then:
```cmd
aime-mine.bat <YOUR_AIME_ADDRESS>
```

Example:
```cmd
aime-mine.bat AQWWPyLG4exW1QNg2HZnGBgoXxkKCPf2WetZCd3n4k7nPusWGoC73nKRcUuEvCkZ1d26kNGgbuXGf7DcaJADpN484v1XjDr 4
```

### 3. Stop
- **Ctrl+C** — XMRig stops cleanly
- **Close window** — Windows kills the process automatically

> Note: Windows version doesn't include the watchdog feature (it's not easily implemented in pure batch). However, Windows console handles Ctrl+C and window-close cleanup natively, so the miner won't survive your CMD session.

---

## Examples

### Solo mining (your local Aime node)
```bash
# Linux/WSL — terminal 1: run the daemon
./aimed

# Linux/WSL — terminal 2: start mining
./aime-mine.sh AQWWPyLG4... 4

# Windows: run aimed (e.g., via WSL), then in CMD:
aime-mine.bat AQWWPyLG4... 4
```

### Pool mining (when a pool exists)
```bash
# Linux:
./aime-mine.sh AQWWPyLG4... 4 pool.aime.network:3333

# Windows:
aime-mine.bat AQWWPyLG4... 4 pool.aime.network:3333
```

### All threads
```bash
# Linux:
./aime-mine.sh AQWWPyLG4... $(nproc)

# Windows:
aime-mine.bat AQWWPyLG4... %NUMBER_OF_PROCESSORS%
```

---

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
```

Live updating display. Press `h` for hashrate snapshot, `Ctrl+C` to stop.

---

## Auto-stop behavior (Linux/WSL only)

The Linux wrapper script ensures the miner doesn't survive your terminal session:

| Event | Behavior |
|---|---|
| You press Ctrl+C | Miner stops cleanly (within 3 seconds) |
| You close terminal X button | SIGHUP → miner stops (~1 second) |
| You run `kill <miner PID>` | Trap catches SIGTERM → cleanup |
| You SSH disconnect | SSH kills shell → SIGHUP → miner stops |
| Edge case: shell dies but signal lost | Watchdog catches within 10 min, kills miner |

You should NEVER have a stranded XMRig process consuming CPU.

For Windows, the standard CMD console behavior provides equivalent automatic cleanup on Ctrl+C and window close — no watchdog needed.

---

## Verify it stopped

```bash
# Linux:
pgrep -f xmrig
# If empty, miner is fully stopped

# Windows:
tasklist | findstr xmrig
REM If no output, miner is fully stopped
```

---

## Files

| File | Platform | Purpose |
|---|---|---|
| `install_xmrig.sh` | Linux | Builds XMRig from source |
| `aime-mine.sh` | Linux/macOS/WSL | Mining wrapper with auto-stop + watchdog |
| `aime-mine.bat` | Windows | Mining wrapper (uses xmrig.exe) |
| `xmrig-bin` | Linux x86-64 | Pre-built XMRig binary (5.3 MB) |
| `xmrig.exe` | Windows | (You download separately, see above) |
| `~/.aime-miner.log` or `aime-miner.log` | Both | Mining logs |

---

## Mining Performance

Expected hashrates with the `aime-mine.sh` defaults:

| CPU | Hashrate |
|---|---|
| Intel i5-8400 (6c/6t) | ~3 KH/s |
| AMD Ryzen 5 5600 (6c/12t) | ~6 KH/s |
| Intel i9-13900K (24c/32t) | ~18 KH/s |
| AMD Threadripper 3960X (24c/48t) | ~30 KH/s |

To maximize hashrate:
- **Linux**: Enable hugepages: `sudo sysctl -w vm.nr_hugepages=1280`
- **Windows**: Run as Administrator (XMRig auto-configures hugepages)
- Use all physical cores (not hyperthreads): `--threads=<physical_core_count>`
- **Linux**: Set CPU governor to performance: `sudo cpupower frequency-set -g performance`
- **Windows**: Set Power Plan to "High performance" or "Ultimate Performance"
- Disable other CPU-heavy programs

---

## Troubleshooting

### "xmrig binary not found" / "xmrig.exe not found"
- Linux: Run `bash install_xmrig.sh` first
- Windows: Download xmrig.exe from https://github.com/xmrig/xmrig/releases

### "RandomX dataset init slow"
First mine takes ~30s to build the 256MB RandomX dataset. Subsequent runs reuse it.

### "Pool unreachable" or "Connection refused"
- Verify aimed is running: `pgrep -a aimed` (Linux) or check Task Manager (Windows)
- Verify RPC port: `curl http://127.0.0.1:17081/get_info`
- Check pool URL/port

### Hashrate way lower than expected
- Disable CPU power saving
- Enable hugepages
- Check `htop` (Linux) or Task Manager (Windows) — should see threads at 100% CPU
- **Linux**: Try MSR mod: run as root once: `sudo aime-xmrig --rdmsr`
- **Windows**: Run aime-mine.bat as Administrator

### Background mining (detach from terminal)
If you want mining to survive terminal close:

**Linux**: Use `screen` or `tmux`:
```bash
screen -S aime-miner
./aime-mine.sh <ADDR> 4
# Detach with Ctrl+A, D
# Re-attach later: screen -r aime-miner
```

**Windows**: Use Task Scheduler or run as a service (advanced). The simple `.bat` requires the window to stay open.

---

## Distribution

To share with another miner:

### Linux package
```bash
cd /path/to/miner-package
tar czf aime-miner-linux.tar.gz install_xmrig.sh aime-mine.sh README.md xmrig-bin

# Recipient:
tar xzf aime-miner-linux.tar.gz
./aime-mine.sh <THEIR_ADDRESS>
```

### Windows package
```bat
REM On your machine (CMD or PowerShell):
mkdir aime-miner-windows
copy aime-mine.bat aime-miner-windows\
copy README.md aime-miner-windows\
REM (User downloads xmrig.exe themselves and places it here)
REM Compress aime-miner-windows folder to ZIP

REM Recipient:
REM 1. Extract ZIP
REM 2. Download xmrig.exe (link in README)
REM 3. Run: aime-mine.bat <THEIR_ADDRESS>
```

### Cross-platform package (clone GitHub repo)
```bash
git clone https://github.com/kiwoongeom/aime-miner.git
cd aime-miner
# Linux: ./aime-mine.sh <ADDR>
# Windows: aime-mine.bat <ADDR>  (after downloading xmrig.exe)
```
