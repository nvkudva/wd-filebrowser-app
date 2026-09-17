#!/bin/sh
# Install/register File Browser as a WD My Cloud OS 5 dashboard app.
# Run on the NAS as root (via SSH). Idempotent.
set -e

APPDIR=/mnt/HD/HD_a2/Nas_Prog/filebrowser
ALL=/var/www/xml/apkg_all.xml
MONIT=/etc/monit/conf-enabled/filebrowser
SRC="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$APPDIR"

# 1. Install app files (everything except this installer and the monit conf).
for f in apkg.xml apkg.rc start.sh stop.sh init.sh remove.sh clean.sh filebrowser.png; do
  cp -f "$SRC/$f" "$APPDIR/$f"
done
chmod +x "$APPDIR"/*.sh

# 2. Fetch the filebrowser binary if absent (armv7 build).
if [ ! -x "$APPDIR/filebrowser" ]; then
  echo "Downloading filebrowser binary..."
  curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/linux-armv7-filebrowser.tar.gz \
    | tar xz -C "$APPDIR" filebrowser
  chmod +x "$APPDIR/filebrowser"
fi

# 3. Register in the dashboard app list (inject <item> if missing).
if ! grep -q "<name>filebrowser</name>" "$ALL" 2>/dev/null; then
  cp -a "$ALL" "$ALL.bak.filebrowser"
  sed -n '/<item>/,/<\/item>/p' "$APPDIR/apkg.xml" > /tmp/fb_item.xml
  awk -v item=/tmp/fb_item.xml '
    /<\/apkg>/ && !done { while((getline line < item)>0) print line; done=1 }
    { print }' "$ALL" > /tmp/apkg_all.new
  cp -a /tmp/apkg_all.new "$ALL"
  rm -f /tmp/fb_item.xml /tmp/apkg_all.new
  echo "Registered in $ALL"
fi

# 4. Supervise with monit (boot-start + crash-restart).
cp -f "$SRC/monit.filebrowser.conf" "$MONIT"
monit reload 2>/dev/null || true
sleep 2
monit monitor filebrowser 2>/dev/null || true

echo "Done. Open the dashboard Apps page -> File Browser -> Go to app (http://<nas>:8088)"
