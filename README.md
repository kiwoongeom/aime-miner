# Aime Miner Package

> Self-contained CPU miner for Aime cryptocurrency.
> Uses XMRig — the standard RandomX miner.

Supports both **Linux/WSL** (with included pre-built binary) and **Windows** (XMRig downloaded separately). Address can be passed as argument, env var, or saved to a file for auto-loading.

---

## Quick Start (Linux / macOS / WSL)

### 1. Install (first time only)
```bash
bash install_xmrig.sh
```
Or just use the pre-built `xmrig-bin` (Linux x86-64, 5.3MB) already in this repo.

### 2. Save your address (one-time, optional but recommended)
```bash
mkdir -p ~/.aime
echo "AQWWPyLG4exW1QNg2HZnGBgoXxkKCPf2WetZCd3n4k7nPusWGoC73nKRcUuEvCkZ1d26kNGgbuXGf7DcaJADpN484v1XjDr" > ~/.aime/last-wallet-address.txt
```

### 3. Mine
```bash
./aime-mine.sh                  # Auto-loads address from file (default 4 threads)
./aime-mine.sh "" 8             # Auto-load address, 8 threads
./aime-mine.sh AQWWPy... 4      # Explicit address
```

### 4. Stop
- **Ctrl+C** — clean stop
- **Close terminal** — auto-stop via SIGHUP
- **Watchdog** — kills miner if parent shell dies (10 min check)

---

## Quick Start (Windows)

### 1. Get xmrig.exe (one-time)

- Go to: https://github.com/xmrig/xmrig/releases/latest
- Download: `xmrig-X.X.X-msvc-win64.zip`
- Extract → find `xmrig.exe`
- Copy `xmrig.exe` next to `aime-mine.bat`

### 2. Save your address (one-time, optional)

In CMD:
```cmd
mkdir "%USERPROFILE%\.aime"
echo AQWWPyLG4exW1QNg2HZnG... > "%USERPROFILE%\.aime\last-wallet-address.txt"
```

### 3. Mine
```cmd
aime-mine.bat                   REM Auto-loads address (default 4 threads)
aime-mine.bat "" 8              REM Auto-load address, 8 threads
aime-mine.bat AQWWPy... 4       REM Explicit address
```

### 4. Stop
- **Ctrl+C** — XMRig stops cleanly
- **Close window** — Windows kills the process automatically

---

## Address resolution priority

Both `aime-mine.sh` and `aime-mine.bat` look for the address in this order:

1. **Command-line argument** — `aime-mine.sh AQWWPy... 4`
2. **Environment variable** — `export AIME_ADDRESS=AQWWPy... && aime-mine.sh`
3. **Saved file** — `~/.aime/last-wallet-address.txt` (Linux) or `%USERPROFILE%\.aime\last-wallet-address.txt` (Windows)
4. **Per-folder override** — `./aime-address.txt`

If nothing found → prints help.

This means: once you save your address (option 3 or 4), you can run `./aime-mine.sh` with no arguments forever.

---

## Examples

### Solo mining with saved address
```bash
# Set up once:
echo "AQWWPyLG..." > ~/.aime/last-wallet-address.txt

# Mine anytime, anywhere:
./aime-mine.sh
```

### Pool mining (when a pool exists)
```bash
./aime-mine.sh AQWWPyLG4... 4 pool.aime.network:3333
```

### All threads
```bash
# Linux
./aime-mine.sh "" $(nproc)

# Windows
aime-mine.bat "" %NUMBER_OF_PROCESSORS%
```

### Multiple wallets (per-folder override)
```bash
mkdir mining-rig-1 && cd mining-rig-1
echo "AddressForRig1..." > aime-address.txt
../aime-mine.sh   # Uses Rig1 address
cd ..

mkdir mining-rig-2 && cd mining-rig-2
echo "AddressForRig2..." > aime-address.txt
../aime-mine.sh   # Uses Rig2 address
```

---

## What you'll see (CLI behavior)

XMRig is a terminal application. Output looks like:

```
 * ABOUT        XMRig/6.22.0 gcc/13.3.0
 * LIBS         libuv/1.48.0 OpenSSL/3.0.13 hwloc/2.10.0
 * HUGE PAGES   supported
 * CPU          AMD Ryzen Threadripper 3960X 24-Core Processor (1)
 * MEMORY       2.6/93.7 GB (3%)
 * POOL #1      127.0.0.1:17081 algo auto
 * COMMANDS     'h' hashrate, 'p' pause, 'r' resume, 's' results, 'c' connection
[12:34:56]  net      use pool 127.0.0.1:17081
[12:34:57]  cpu      use profile rx (4 threads)
[12:34:58]  randomx  init dataset algo rx/0 (4 threads)
[12:35:58]  miner    speed 10s/60s/15m  6.2  6.1  n/a   H/s
```

Live updating display. Press `h` for hashrate snapshot, `Ctrl+C` to stop.

---

## Auto-stop behavior (Linux/WSL only)

| Event | Behavior |
|---|---|
| You press Ctrl+C | Miner stops cleanly (within 3 seconds) |
| You close terminal X button | SIGHUP → miner stops (~1 second) |
| You SSH disconnect | SSH kills shell → SIGHUP → miner stops |
| Edge case: shell dies but signal lost | Watchdog catches within 10 min, kills miner |

For Windows, CMD's standard console behavior provides equivalent automatic cleanup on Ctrl+C and window close — no watchdog needed.

You should NEVER have a stranded XMRig process consuming CPU.

---

## Files

| File | Platform | Purpose |
|---|---|---|
| `install_xmrig.sh` | Linux | Builds XMRig from source |
| `aime-mine.sh` | Linux/macOS/WSL | Mining wrapper with auto-stop + watchdog |
| `aime-mine.bat` | Windows | Mining wrapper (uses xmrig.exe) |
| `xmrig-bin` | Linux x86-64 | Pre-built XMRig binary (5.3 MB) |
| `xmrig.exe` | Windows | Download separately (see above) |

---

## Mining Performance

| CPU | Hashrate |
|---|---|
| Intel i5-8400 (6c/6t) | ~3 KH/s |
| AMD Ryzen 5 5600 (6c/12t) | ~6 KH/s |
| Intel i9-13900K (24c/32t) | ~18 KH/s |
| AMD Threadripper 3960X (24c/48t) | ~30 KH/s |

To maximize hashrate:
- **Linux**: Enable hugepages: `sudo sysctl -w vm.nr_hugepages=1280`
- **Windows**: Run as Administrator (XMRig auto-configures hugepages)
- Use all physical cores (not hyperthreads): match `--threads` to your physical core count
- Set CPU power plan to "High performance"
- Disable other CPU-heavy programs

---

## Troubleshooting

### "No address found"
Set your address one of four ways: command-line, env var, saved file, or per-folder file. See "Address resolution priority" above.

### "xmrig binary not found" / "xmrig.exe not found"
- Linux: Run `bash install_xmrig.sh` first
- Windows: Download xmrig.exe from https://github.com/xmrig/xmrig/releases

### "RandomX dataset init slow"
First mine takes ~30s to build the 256MB RandomX dataset. Subsequent runs reuse it.

### "Pool unreachable" / "Connection refused"
- Verify aimed is running: `pgrep -a aimed` (Linux) or check Task Manager (Windows)
- Verify RPC port: `curl http://127.0.0.1:17081/get_info`
- Check pool URL/port

### Hashrate way lower than expected
- Disable CPU power saving
- Enable hugepages
- **Linux**: Try MSR mod: `sudo aime-xmrig --rdmsr`
- **Windows**: Run aime-mine.bat as Administrator

---

## Distribution

To share with another miner:

### Linux
```bash
tar czf aime-miner-linux.tar.gz install_xmrig.sh aime-mine.sh README.md xmrig-bin
```

### Windows
```cmd
mkdir aime-miner-windows
copy aime-mine.bat aime-miner-windows\
copy README.md aime-miner-windows\
REM Recipient downloads xmrig.exe themselves and places it in folder
```

### Cross-platform (just clone)
```bash
git clone https://github.com/kiwoongeom/aime-miner.git
cd aime-miner
# Linux: ./aime-mine.sh
# Windows: aime-mine.bat (after downloading xmrig.exe)
```
