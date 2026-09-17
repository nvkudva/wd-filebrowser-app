# CLAUDE.md — WD FileBrowser App

Context for future work on this repo. The README covers usage; this file records the
**non-obvious** findings from reverse-engineering the WD My Cloud EX2 Ultra (OS 5) so a
future session doesn't rediscover them.

## The device

- WD My Cloud EX2 Ultra, firmware **5.33.102**, arch **armv7l**, kernel 4.14 (Armada).
- Root SSH: `ssh sshd@192.168.0.103` (user is literally `sshd`). Enabled in the WD UI.
- Third-party apps live under `/mnt/HD/HD_a2/Nas_Prog/<app>/` — the **data volume**,
  which survives firmware updates. `/`, `/var/www`, `/etc` are the ext4 **firmware
  partition**: writable and persistent across normal reboots, but replaced by a firmware
  **update**. So anything we drop in `/etc` (monit conf) or `/var/www` (registry) is
  reboot-safe but update-fragile; the app dir is fully safe.

## Why there is no dashboard app tile (the core finding)

The user wanted a real tile on the OS 5 dashboard Apps page. It is **not achievable for
an unsigned app**, and we confirmed why empirically:

- The dashboard is served by **`nasAdmin`** (Go binary, ports 8543/80). It does not read
  the legacy XML directly; the legacy `apkg` layer feeds it.
- The app list the UI shows comes from `/var/www/xml/apkg_all.xml`. A monit-supervised
  **`apkg` daemon** rebuilds this file from its own authoritative store
  (`/tmp/apkg_all.xml`). **Hand-editing `apkg_all.xml` works only until the next rebuild**
  — we injected a filebrowser `<item>`, it showed nothing to the user, and the daemon
  reverted the file ~2 min later. Do not go down this path again.
- Install/verification: `upload_apkg` and the `apkg` binary decrypt `apkg.sign` with
  `openssl bf-cbc -d -k "<key>"` (symmetric Blowfish, key hardcoded/embedded) and compare
  to `apkg.xml`. WD apps ship a valid `apkg.sign`; ours cannot without WD's key.
- The CGI `apkg_mgr.cgi` has a `module_sign_flag` — likely the toggle that disables the
  signature check for manual `.bin` uploads. **We did not flip it** (security downgrade,
  user's decision). That, or a WD-signed package, is the only route to a persistent tile.

**Do not** attempt to recover the Blowfish key or forge `apkg.sign` — it was blocked as a
security-weakening action, correctly. If the user ever wants the tile, the honest options
are: (a) they accept flipping `module_sign_flag` and use the UI's "install manually", or
(b) a WD/SanDisk partner-signed package (effectively closed for OS 5).

## How persistence actually works

- OS 5 uses **`monit`** as the service supervisor (conf dir `/etc/monit/conf-enabled/`,
  reload with `monit reload`, per-service `monit monitor|unmonitor|status|restart <name>`).
  It starts services at boot and restarts on crash. This is what WD uses for Plex, and
  what we use for filebrowser (`/etc/monit/conf-enabled/filebrowser`).
- There is **no** `/etc/init.d` hook that starts Nas_Prog apps, and cron (`crond` runs,
  `/etc/cron.d`, `/var/spool/cron/crontabs/root`) is not needed. `monit` is the mechanism —
  prefer it over init.d/cron/XML for anything new.
- A monit `check process ... matching "<path>/<binary>"` block with `start`/`stop program`
  pointing at the app's `start.sh <appdir>` / `stop.sh <appdir>` is the whole pattern.

## filebrowser specifics

- Binary: single static Go executable (~34 MB, `linux-armv7`), v2.63.23. Data/users in a
  **bbolt** DB `fb.db` — **single-writer**: the running server locks it, so any
  `filebrowser ... -d fb.db` CLI call (users, config) must be done with the server
  **stopped** (`monit unmonitor` + `stop.sh`), then `monit monitor` to bring it back.
- Bind: launched with `-a 0.0.0.0 -p 8088` so the LAN can reach it (needed for any UI
  link). Originally it was `127.0.0.1` only, reached via SSH tunnel
  (`ssh -N -L 8088:127.0.0.1:8088`). Toggle in `start.sh`.
- Auth: JWT in the SPA's `localStorage['jwt']`. `POST /api/login {username,password}`
  returns the raw token. Password rules: **min length configurable**
  (`config set --minimumPasswordLength`, lowered to 5 here) **plus a hardcoded
  zxcvbn-style strength check** with no disable flag — so `admin` is rejected as "too
  easy" regardless of length. Only way to force a trivial password is patching the bcrypt
  hash into bbolt directly (declined).
- Current user: `admin` (was `vijay`, id 1). Never commit the password to the repo — the
  git guard blocks it as credential leakage.

## Screenshot capture (for docs)

`screencapture` is blocked (no display). The working method: **headless Chrome + CDP** via
node (node v26 has global `WebSocket`). Launch Chrome
`--headless=new --remote-debugging-port=<p> --user-data-dir=/tmp/...`, connect to the
`/json` page's `webSocketDebuggerUrl`, then for an authenticated view: navigate to the
origin, `Runtime.evaluate` `localStorage.setItem('jwt', <token>)`, navigate to `/files/`,
`Page.captureScreenshot`. The login page needs no auth. See git history for the exact
script.

## Related

- Reusable, generalized version of this whole procedure is the personal skill
  `~/.claude/skills/make-wd-nas-app/` (SKILL.md + `scripts/install-app.sh`). Update both
  together if the method changes.
- Open follow-ups in [TODO.md](TODO.md).
