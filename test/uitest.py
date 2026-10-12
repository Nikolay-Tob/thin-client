import importlib.util, json, os, sys
os.environ["HOME"] = "/tmp/kh"; os.makedirs("/tmp/kh", exist_ok=True)
spec = importlib.util.spec_from_file_location("kiosk", "/work/kit/overlay/opt/kiosk/kiosk.py")
k = importlib.util.module_from_spec(spec); spec.loader.exec_module(k)
conf = k.CONF
if os.path.exists(conf): os.remove(conf)
app = k.Kiosk()
# new profile: RDP
app.add_profile()
f = app.f
f["name"].set_text("Office RDP"); f["host"].set_text("10.1.2.3"); f["port"].set_text("3390")
f["user"].set_text("ivan"); f["password"].set_text("p@ss"); f["domain"].set_text("CORP")
f["multimon"].set_active(True); f["usb"].set_active(True); f["boot"].set_active(True)
app.save_form(True)
# second profile: VNC
app.add_profile()
f["name"].set_text("Lab VNC"); f["proto"].set_active_id("vnc"); f["host"].set_text("192.168.0.5"); f["password"].set_text("secret")
app.save_form(True)
data = json.load(open(conf))
print("profiles:", [(p["name"], p["proto"], p["host"], p["port"]) for p in data["profiles"]], "default ->", [p["name"] for p in data["profiles"] if p["id"] == data["default"]])
# command lines the app would run
for p in data["profiles"]:
    c = app.build_cmd(dict(p)); print(p["proto"], "->", " ".join(x if not x.startswith("/p:") else "/p:***" for x in c))
# reload from disk
k2 = k.Config(); print("reloaded:", len(k2.data["profiles"]), "profiles, default ok:", k2.data["default"] == data["default"])
print("file mode:", oct(os.stat(conf).st_mode & 0o777))
# delete + language switch
app.sel_id = data["profiles"][1]["id"]; app.del_profile()
print("after delete:", len(json.load(open(conf))["profiles"]))
