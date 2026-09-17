#!/bin/sh
# WD apkg uninstall hook: stop app, remove monit watch, drop registry item.
monit unmonitor filebrowser 2>/dev/null
rm -f /etc/monit/conf-enabled/filebrowser
monit reload 2>/dev/null
sh "/mnt/HD/HD_a2/Nas_Prog/filebrowser/stop.sh" "/mnt/HD/HD_a2/Nas_Prog/filebrowser"
ALL=/var/www/xml/apkg_all.xml
if grep -q "<name>filebrowser</name>" "$ALL" 2>/dev/null; then
  awk "BEGIN{skip=0} /<item>/{buf=$0; collecting=1; next} collecting{buf=buf ORS $0; if($0 ~ /<\/item>/){collecting=0; if(buf ~ /<name>filebrowser<\/name>/){next} else print buf} next} {print}" "$ALL" > /tmp/apkg_all.rm && cp -a /tmp/apkg_all.rm "$ALL"
fi
exit 0
