#!/bin/sh
# X session of the kiosk user: no desktop, only openbox (for hotkeys) + the launcher.
export GDK_BACKEND=x11 NO_AT_BRIDGE=1 GTK_A11Y=none LANG=C.UTF-8
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
xset s off -dpms s noblank 2>/dev/null
xsetroot -solid '#20232a' -cursor_name left_ptr 2>/dev/null
pulseaudio --start --exit-idle-time=-1 --log-target=syslog 2>/dev/null
( sleep 3; pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 85% ) >/dev/null 2>&1 &
openbox --config-file /opt/kiosk/rc.xml >/dev/null 2>&1 &
exec /opt/kiosk/kiosk.py
