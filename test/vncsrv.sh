#!/bin/sh
export DISPLAY=:98
Xvfb :98 -screen 0 1280x720x24 >/dev/null 2>&1 &
sleep 2
xsetroot -solid '#2a5a8a' 2>/dev/null
xclock -geometry 300x300+60+60 >/dev/null 2>&1 &
xterm -geometry 70x12+420+80 -e 'sh -c "echo REMOTE VNC DESKTOP OK; date; sleep 100000"' >/dev/null 2>&1 &
x11vnc -display :98 -rfbport 5900 -passwd test123 -forever -shared -noxdamage -quiet >/work/x11vnc.log 2>&1 &
wait
