#!/bin/sh
path="$1"; [ -z "$path" ] && path="$(cd "$(dirname "$0")" && pwd)"
pkill -f "$path/filebrowser"; sleep 1
pgrep -f "$path/filebrowser" >/dev/null && { pkill -9 -f "$path/filebrowser"; sleep 1; }
echo stopped
