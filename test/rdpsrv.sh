#!/bin/sh
export DISPLAY=:98
exec freerdp-shadow-cli3 /port:3389 -auth -sec-nla > /work/rdpsrv.log 2>&1
