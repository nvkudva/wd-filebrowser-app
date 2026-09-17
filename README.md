# WD FileBrowser App

Registers [File Browser](https://filebrowser.org) as a native app on a WD My Cloud
EX2 Ultra (OS 5) so it appears on the dashboard **Apps** page with a **Go to app**
link and an **Uninstall** button — without going through WD's signed `.bin` upload
(OS 5 rejects unsigned community packages).

Tested on firmware **5.33.102**, `armv7l`.

## How it works

WD's `apkg` daemon builds the dashboard app list from `/var/www/xml/apkg_all.xml`.
The signed-upload path is only enforced at *upload* time. Since we have root SSH,
we place a normal WD app directory under `Nas_Prog`, inject the app's `<item>` into
`apkg_all.xml`, and supervise the process with `monit` (the same supervisor WD uses
for Plex) so it starts at boot and restarts on crash.

## Files (`app/`)

| File | Purpose |
|------|---------|
| `apkg.xml` | App manifest the dashboard reads (name, port 8088, icon) |
| `apkg.rc` | WD package metadata |
| `start.sh` | Start hook — launches filebrowser on `0.0.0.0:8088` |
| `stop.sh` | Stop hook |
| `init.sh` | Install hook (no-op; filebrowser is self-contained) |
| `remove.sh` | Uninstall hook — stops app, removes monit watch, drops registry item |
| `clean.sh` | Post-remove hook (no-op) |
| `filebrowser.png` | Dashboard tile icon |
| `monit.filebrowser.conf` | monit watch → boot-start + crash-restart |

The 34 MB `filebrowser` binary and `fb.db` are not tracked; the installer fetches
the binary.

## Install (on the NAS, over SSH)

```bash
NAS=sshd@192.168.0.103        # your NAS SSH user@ip
scp -r app "$NAS":/tmp/fb-app
ssh "$NAS" 'sh /tmp/fb-app/install.sh'   # see install.sh below
```

## Caveats

- **LAN exposure**: filebrowser binds `0.0.0.0:8088` so the dashboard link works.
  It has its own login. To keep it localhost-only (SSH-tunnel access), change the
  bind in `start.sh` back to `127.0.0.1`.
- **Firmware updates** (not normal reboots) can wipe the registry entry and the
  monit conf, since both live on the firmware partition. Re-run the installer after
  a major OS update. The app dir under `Nas_Prog` survives on the data volume.
- If the dashboard **Uninstall** button refuses (the app wasn't installed via WD's
  signed flow), run `sh /mnt/HD/HD_a2/Nas_Prog/filebrowser/remove.sh` over SSH.
