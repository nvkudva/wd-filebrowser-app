#!/bin/sh
# WD apkg start hook. Arg $1 = install path (falls back to script dir).
path="$1"; [ -z "$path" ] && path="$(cd "$(dirname "$0")" && pwd)"
DB="$path/fb.db"; LOG="$path/fb.log"
pgrep -f "$path/filebrowser" >/dev/null && { echo "already running"; exit 0; }
nohup "$path/filebrowser" -d "$DB" -a 0.0.0.0 -p 8088 >> "$LOG" 2>&1 &
sleep 2
pgrep -f "$path/filebrowser" >/dev/null && echo "started 0.0.0.0:8088" || { echo FAILED; tail -5 "$LOG"; exit 1; }
