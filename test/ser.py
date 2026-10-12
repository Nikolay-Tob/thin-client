#!/usr/bin/env python3
"""usage: ser.py 'command' [timeout]  -- run a command in the guest debug shell on the serial socket"""
import socket, sys, time, uuid
cmd = sys.argv[1]; tmo = float(sys.argv[2]) if len(sys.argv) > 2 else 20
s = socket.socket(socket.AF_UNIX); s.connect("/work/ser.sock"); s.settimeout(1)
mark = "END" + uuid.uuid4().hex[:8]
s.sendall(("\n" + cmd + "; echo " + mark + "\n").encode())
buf = b""; t0 = time.time()
while time.time() - t0 < tmo:
    try:
        d = s.recv(65536)
        if not d: break
        buf += d
        if buf.count(mark.encode()) >= 2: break
    except socket.timeout:
        pass
out = buf.decode(errors="replace")
i = out.rfind(mark); j = out.find(mark)
print(out[j+len(mark):i] if i != j else out[-3000:])
