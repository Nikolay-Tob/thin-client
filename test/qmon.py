#!/usr/bin/env python3
import socket, sys, time
cmd = " ".join(sys.argv[1:])
s = socket.socket(socket.AF_UNIX); s.connect("/work/qmon"); s.settimeout(3)
try: s.recv(4096)
except Exception: pass
s.sendall((cmd + "\n").encode()); time.sleep(0.8)
try: print(s.recv(65536).decode(errors="replace")[-400:])
except Exception: pass
