#!/bin/sh
export DISPLAY=:99 NO_AT_BRIDGE=1 HOME=/tmp/kh
mkdir -p /tmp/kh; rm -f /tmp/kh/uitest.out
Xvfb :99 -screen 0 1366x768x24 >/dev/null 2>&1 &
XP=$!
sleep 2
/usr/bin/python3.12 /work/kit/test/uitest.py > /work/uitest.out 2>&1
kill $XP
echo done >> /work/uitest.out
