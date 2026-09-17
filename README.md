# WD FileBrowser App

Runs [File Browser](https://filebrowser.org) — a web-based file manager — as a
headless, auto-starting service on a WD My Cloud EX2 Ultra (OS 5), for faster file
management than the stock dashboard.

Tested on firmware **5.33.102**, `armv7l`.

Access it at **http://<nas-ip>:8088** (e.g. http://192.168.0.103:8088).

## Status: headless service (no dashboard tile)

This runs as a background service supervised by `monit`. It does **not** appear as a
tile on the WD dashboard **Apps** page. See [Why there's no app tile](#why-theres-no-app-tile)
below and [TODO.md](TODO.md).

## How it works

- The `filebrowser` binary runs from `/mnt/HD/HD_a2/Nas_Prog/filebrowser/`, bound to
  `0.0.0.0:8088`, with its data in `fb.db`.
- `monit` supervises it (`/etc/monit/conf-enabled/filebrowser`) so it **starts at
  boot and restarts on crash** — the same supervisor WD uses for Plex.
- The WD app scaffold (`apkg.xml`, `start.sh`, etc.) is kept for a possible future
  tile integration, but is not what keeps the service running today — `monit` is.

## Why there's no app tile

OS 5's `apkg` daemon rebuilds the dashboard app list (`/var/www/xml/apkg_all.xml`)
from its own **signature-verified** store. Manually inserting an entry works only
until the next rebuild, which drops any app not installed through WD's signed flow.
Getting a persistent tile requires one of:

1. A **WD-signed** package — needs WD's private signing key (not publicly available;
   not forged here).
2. **Disabling the firmware signature check** (`module_sign_flag`) so the dashboard's
   "install manually" accepts unsigned packages — a real security downgrade to the NAS.
3. A WD/SanDisk **partner/developer** arrangement — aimed at vendors, effectively
   closed for OS 5 and not viable for a personal app.

Given the tradeoffs, this project runs headless. Tracking the tile work in
[TODO.md](TODO.md).

## Files (`app/`)

| File | Purpose |
|------|---------|
| `install.sh` | Idempotent installer — deploys files, fetches binary, wires monit |
| `apkg.xml` | WD app manifest (name, port 8088, icon) — for future tile use |
| `apkg.rc` | WD package metadata |
| `start.sh` | Start hook — launches filebrowser on `0.0.0.0:8088` |
| `stop.sh` | Stop hook |
| `init.sh` | Install hook (no-op; filebrowser is self-contained) |
| `remove.sh` | Uninstall hook — stops app, removes monit watch, drops registry item |
| `clean.sh` | Post-remove hook (no-op) |
| `filebrowser.png` | Tile icon (for future tile use) |
| `monit.filebrowser.conf` | monit watch → boot-start + crash-restart |

The 34 MB `filebrowser` binary, `fb.db`, and logs are not tracked; the installer
fetches the binary.

## Install (on the NAS, over SSH)

```bash
NAS=sshd@192.168.0.103        # your NAS SSH user@ip
scp -r app "$NAS":/tmp/fb-app
ssh "$NAS" 'sh /tmp/fb-app/install.sh'
```

## Reset / change the login password

The `fb.db` database is single-writer, so the running server must be stopped first
(and monit told not to respawn it).

**Web UI (easiest, no downtime):** log in → **Settings → User Management** → edit the
user → set new password → Save.

**CLI over SSH:**

```bash
ssh sshd@192.168.0.103 'D=/mnt/HD/HD_a2/Nas_Prog/filebrowser
monit unmonitor filebrowser
sh "$D/stop.sh" "$D"
"$D/filebrowser" users ls -d "$D/fb.db"                       # list usernames
"$D/filebrowser" users update admin --password "NEW_PASSWORD" -d "$D/fb.db"
monit monitor filebrowser'                                    # restarts the server
```

Replace `admin` with your username and `NEW_PASSWORD` with the new password.

## Debugging

All commands run over SSH: `ssh sshd@192.168.0.103`. App dir: `/mnt/HD/HD_a2/Nas_Prog/filebrowser`.

| Symptom | Check |
|---------|-------|
| Can't reach `:8088` | `pgrep -f "filebrowser -d"` — is it running? |
| Is it listening on the LAN? | `netstat -ltnp \| grep 8088` — expect `:::8088` (not `127.0.0.1`) |
| monit health | `monit status filebrowser` — expect `status OK`, `monitoring Monitored` |
| Startup / runtime errors | `tail -50 /mnt/HD/HD_a2/Nas_Prog/filebrowser/fb.log` |
| Didn't start at boot | `monit summary \| grep filebrowser`; `cat /etc/monit/conf-enabled/filebrowser` |
| Manual restart | `monit restart filebrowser` (or `stop.sh` then `start.sh` with the app dir as arg) |
| Port already in use | `netstat -ltnp \| grep 8088` then `kill` the stale PID; `monit restart filebrowser` |
| DB locked / corrupt | stop the server before any `filebrowser` CLI call; a locked `fb.db` means a process still holds it |

Common gotchas:
- The `start.sh`/`stop.sh` hooks take the app dir as `$1`; run them as
  `sh start.sh /mnt/HD/HD_a2/Nas_Prog/filebrowser`.
- After a firmware **update** (not a normal reboot), the `monit` conf can be wiped —
  re-run `install.sh`. The app dir on the data volume survives.
- If monit keeps restarting a broken instance, `monit unmonitor filebrowser` while
  you investigate, then `monit monitor filebrowser` when done.

## Caveats

- **LAN exposure**: filebrowser binds `0.0.0.0:8088` so it's reachable on the LAN
  (it has its own login). To restrict to localhost + SSH tunnel, change the bind in
  `start.sh` back to `127.0.0.1` and reach it via
  `ssh -N -L 8088:127.0.0.1:8088 sshd@<nas-ip>`.
- **Firmware updates** can wipe the monit conf (it lives on the firmware partition).
  Re-run `install.sh` after a major OS update.
