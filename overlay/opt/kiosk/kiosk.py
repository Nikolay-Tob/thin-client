#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Thin-client kiosk: connection profiles (RDP/VNC), network and system settings.

Runs inside a bare X session (openbox). Hotkeys call `kiosk.py --ctl <cmd>`,
which talks to the running instance over a unix datagram socket.
"""
import os
import sys
import socket

SOCK = "/tmp/kiosk-ctl.sock"

if len(sys.argv) >= 3 and sys.argv[1] == "--ctl":
    _s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        _s.sendto(sys.argv[2].encode(), SOCK)
    except OSError:
        sys.exit(1)
    sys.exit(0)

import json
import re
import time
import uuid
import ipaddress
import subprocess
import threading

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk  # noqa: E402

VERSION = "1.0"


def _wait_data():
    """The data partition is mounted by systemd; give it a moment on slow media."""
    if os.path.exists("/dev/disk/by-label/KIOSKDATA"):
        for _ in range(60):
            if os.path.ismount("/data"):
                break
            time.sleep(0.5)
    return os.path.ismount("/data")


PERSISTENT = _wait_data()
DATA_DIR = "/data/kiosk" if PERSISTENT else os.path.expanduser("~/.config/kiosk")
CONF = os.path.join(DATA_DIR, "config.json")
CLIENT_LOG = "/tmp/kiosk-client.log"
VNC_PASS = "/tmp/kiosk-vncpass"

KEYBOARDS = [
    ("us", "English (US)", ["us"], None),
    ("us-ru-alt", "English + Русская (Alt+Shift)", ["us,ru"], "grp:alt_shift_toggle"),
    ("us-ru-ctrl", "English + Русская (Ctrl+Shift)", ["us,ru"], "grp:ctrl_shift_toggle"),
]

TR = {
    "ru": {
        "title": "Тонкий клиент",
        "tab_conn": "Подключение", "tab_net": "Сеть", "tab_sys": "Система",
        "profiles": "Профили", "add": "Добавить", "dup": "Копия", "delete": "Удалить",
        "name": "Название", "proto": "Протокол", "host": "Адрес сервера", "port": "Порт",
        "user": "Пользователь", "password": "Пароль", "domain": "Домен",
        "fullscreen": "На весь экран", "multimon": "Использовать все мониторы",
        "size": "Размер окна", "sound": "Звук", "clipboard": "Общий буфер обмена",
        "usb": "Проброс USB-устройств", "ignorecert": "Не проверять сертификат",
        "extra": "Доп. параметры клиента",
        "save": "Сохранить", "connect": "Подключиться", "boot": "Подключаться при загрузке",
        "default_mark": "при загрузке", "new_profile": "Новый профиль",
        "back": "Вернуться к сеансу", "disconnect": "Отключиться",
        "status_ready": "Готово. Выберите профиль и нажмите «Подключиться».",
        "status_noprofile": "Профилей нет. Добавьте профиль слева и сохраните его.",
        "status_wait_net": "Ожидание сети…",
        "status_connecting": "Подключение: {}…",
        "status_ended": "Сеанс завершён (код {}). {}",
        "status_retry": "Повтор через {} с. Любое нажатие отменяет автоповтор.",
        "status_saved": "Сохранено.",
        "status_nohost": "Укажите адрес сервера.",
        "status_notpersist": "Внимание: раздел данных не примонтирован, настройки не сохранятся!",
        "ask_creds": "Введите учётные данные",
        "ok": "OK", "cancel": "Отмена",
        "net_iface": "Интерфейс", "net_mode": "Настройка IP", "dhcp": "Автоматически (DHCP)",
        "static": "Вручную", "ip": "IP-адрес", "mask": "Маска / префикс", "gw": "Шлюз",
        "dns": "DNS (через запятую)", "ssid": "Сеть Wi-Fi", "wifi_pass": "Пароль Wi-Fi",
        "hidden": "Скрытая сеть", "scan": "Найти сети", "apply": "Применить",
        "net_status": "Состояние сети", "scanning": "Поиск сетей…", "no_dev": "Сетевых интерфейсов нет",
        "net_applied": "Сеть настроена.", "net_failed": "Ошибка: {}", "bad_ip": "Неверный IP-адрес или маска.",
        "signal": "Сигнал", "security": "Защита",
        "language": "Язык интерфейса", "autoreconnect": "Автоматически переподключаться",
        "keyboard": "Раскладка клавиатуры", "power": "Питание",
        "reboot": "Перезагрузить", "shutdown": "Выключить",
        "confirm_reboot": "Перезагрузить компьютер?", "confirm_shutdown": "Выключить компьютер?",
        "hotkeys": "Горячие клавиши",
        "hotkeys_text": (
            "Ctrl+Alt+Shift+S — окно настроек и профилей\n"
            "Ctrl+Alt+Shift+N — сетевые настройки\n"
            "Ctrl+Alt+Shift+P — питание и система\n"
            "Ctrl+Alt+Shift+R — переподключиться\n"
            "Ctrl+Alt+Shift+D — отключиться\n"
            "Ctrl+Alt+Shift+Пробел — показать/скрыть это окно\n"
            "Esc — вернуться к сеансу"),
        "version": "Версия {}",
    },
    "en": {
        "title": "Thin client",
        "tab_conn": "Connection", "tab_net": "Network", "tab_sys": "System",
        "profiles": "Profiles", "add": "Add", "dup": "Copy", "delete": "Delete",
        "name": "Name", "proto": "Protocol", "host": "Server address", "port": "Port",
        "user": "User", "password": "Password", "domain": "Domain",
        "fullscreen": "Fullscreen", "multimon": "Use all monitors",
        "size": "Window size", "sound": "Sound", "clipboard": "Shared clipboard",
        "usb": "USB device redirection", "ignorecert": "Ignore certificate errors",
        "extra": "Extra client options",
        "save": "Save", "connect": "Connect", "boot": "Connect at boot",
        "default_mark": "at boot", "new_profile": "New profile",
        "back": "Back to session", "disconnect": "Disconnect",
        "status_ready": "Ready. Pick a profile and press Connect.",
        "status_noprofile": "No profiles yet. Add one on the left and save it.",
        "status_wait_net": "Waiting for network…",
        "status_connecting": "Connecting: {}…",
        "status_ended": "Session ended (code {}). {}",
        "status_retry": "Retrying in {} s. Any click cancels auto-retry.",
        "status_saved": "Saved.",
        "status_nohost": "Enter the server address.",
        "status_notpersist": "Warning: data partition is not mounted, settings will not be saved!",
        "ask_creds": "Enter credentials",
        "ok": "OK", "cancel": "Cancel",
        "net_iface": "Interface", "net_mode": "IP configuration", "dhcp": "Automatic (DHCP)",
        "static": "Manual", "ip": "IP address", "mask": "Mask / prefix", "gw": "Gateway",
        "dns": "DNS (comma separated)", "ssid": "Wi-Fi network", "wifi_pass": "Wi-Fi password",
        "hidden": "Hidden network", "scan": "Scan", "apply": "Apply",
        "net_status": "Network status", "scanning": "Scanning…", "no_dev": "No network interfaces",
        "net_applied": "Network configured.", "net_failed": "Error: {}", "bad_ip": "Invalid IP address or mask.",
        "signal": "Signal", "security": "Security",
        "language": "Interface language", "autoreconnect": "Reconnect automatically",
        "keyboard": "Keyboard layout", "power": "Power",
        "reboot": "Reboot", "shutdown": "Shut down",
        "confirm_reboot": "Reboot the computer?", "confirm_shutdown": "Shut the computer down?",
        "hotkeys": "Hotkeys",
        "hotkeys_text": (
            "Ctrl+Alt+Shift+S — settings and profiles\n"
            "Ctrl+Alt+Shift+N — network settings\n"
            "Ctrl+Alt+Shift+P — power and system\n"
            "Ctrl+Alt+Shift+R — reconnect\n"
            "Ctrl+Alt+Shift+D — disconnect\n"
            "Ctrl+Alt+Shift+Space — show/hide this window\n"
            "Esc — back to the session"),
        "version": "Version {}",
    },
}

DEFAULT_PROFILE = {
    "name": "", "proto": "rdp", "host": "", "port": "", "user": "", "password": "",
    "domain": "", "fullscreen": True, "multimon": False, "width": 1920, "height": 1080,
    "sound": True, "clipboard": True, "usb": False, "ignorecert": True, "extra": "",
}


# ----------------------------------------------------------------- helpers
def run(args, timeout=30):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:  # noqa: BLE001
        return 1, str(e)


def nm_split(line):
    """Split nmcli terse output on unescaped ':' and unescape."""
    return [p.replace("\\:", ":").replace("\\\\", "\\") for p in re.split(r"(?<!\\):", line)]


def vnc_obfuscate(password):
    """VNC password file contents (DES with the fixed, bit-reversed key)."""
    from cryptography.hazmat.primitives.ciphers import Cipher, modes
    try:
        from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
    except ImportError:
        from cryptography.hazmat.primitives.ciphers.algorithms import TripleDES
    key = bytes(int("{:08b}".format(b)[::-1], 2) for b in (23, 82, 107, 6, 35, 78, 88, 7))
    pw = password.encode("latin-1", "replace")[:8].ljust(8, b"\0")
    enc = Cipher(TripleDES(key * 3), modes.ECB()).encryptor()
    return enc.update(pw) + enc.finalize()


def apply_keyboard(key):
    for k, _label, layout, opt in KEYBOARDS:
        if k == key:
            cmd = ["setxkbmap", "-layout", layout[0], "-option", ""]
            if opt:
                cmd += ["-option", opt]
            run(cmd, 5)
            return


# ------------------------------------------------------------------- config
class Config:
    def __init__(self):
        self.data = {"lang": "ru", "default": "", "autoreconnect": True,
                     "keyboard": "us-ru-alt", "profiles": []}
        self.load()

    def load(self):
        try:
            with open(CONF, "r", encoding="utf-8") as f:
                self.data.update(json.load(f))
        except Exception:  # noqa: BLE001
            pass

    def save(self):
        try:
            os.makedirs(DATA_DIR, exist_ok=True)
            tmp = CONF + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.chmod(tmp, 0o600)
            os.replace(tmp, CONF)
            return True
        except Exception:  # noqa: BLE001
            return False

    def profile(self, pid):
        for p in self.data["profiles"]:
            if p.get("id") == pid:
                return p
        return None


# --------------------------------------------------------------------- app
class Kiosk:
    def __init__(self):
        self.cfg = Config()
        self.proc = None
        self.started = 0.0
        self.user_stop = False
        self.interacted = False
        self.retry_id = 0
        self.retry_left = 0
        self.net_wait_id = 0
        self.current_pid = ""
        self.sel_id = ""
        self.loading_form = False
        self.net_devs = []
        self.scan_busy = False

        css = Gtk.CssProvider()
        Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
        css.load_from_data(b"""
            * { font-size: 12pt; }
            .status { padding: 4px 6px; }
            button { padding: 4px 12px; }
            entry { padding: 3px 6px; }
            notebook > header > tabs > tab { padding: 6px 18px; }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.win = Gtk.Window()
        self.win.set_decorated(False)
        self.win.connect("delete-event", lambda *a: True)
        self.win.connect("key-press-event", self.on_key)
        self.win.connect("button-press-event", lambda *a: self.touch())
        self.build_ui()
        self.start_ctl()
        apply_keyboard(self.cfg.data.get("keyboard", "us"))
        GLib.timeout_add_seconds(3, self.refresh_net_status)
        GLib.idle_add(self.startup)

    # ------------------------------------------------------------- i18n
    def _(self, key, *a):
        s = TR.get(self.cfg.data.get("lang", "ru"), TR["en"]).get(key, key)
        return s.format(*a) if a else s

    # --------------------------------------------------------------- UI
    def build_ui(self):
        old = self.win.get_child()
        if old:
            self.win.remove(old)
        self.win.set_title(self._("title"))
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        root.set_border_width(10)
        self.nb = Gtk.Notebook()
        self.nb.append_page(self.build_conn_tab(), Gtk.Label(label=self._("tab_conn")))
        self.nb.append_page(self.build_net_tab(), Gtk.Label(label=self._("tab_net")))
        self.nb.append_page(self.build_sys_tab(), Gtk.Label(label=self._("tab_sys")))
        self.nb.connect("switch-page", lambda *a: self.touch())
        root.pack_start(self.nb, True, True, 0)

        bar = Gtk.Box(spacing=8)
        self.status = Gtk.Label(xalign=0)
        self.status.set_line_wrap(True)
        self.status.get_style_context().add_class("status")
        bar.pack_start(self.status, True, True, 0)
        self.btn_back = Gtk.Button(label=self._("back"))
        self.btn_back.connect("clicked", lambda *a: self.hide_window())
        self.btn_disc = Gtk.Button(label=self._("disconnect"))
        self.btn_disc.connect("clicked", lambda *a: self.disconnect())
        bar.pack_end(self.btn_disc, False, False, 0)
        bar.pack_end(self.btn_back, False, False, 0)
        root.pack_start(bar, False, False, 0)
        self.win.add(root)
        self.reload_profiles()
        self.update_buttons()
        root.show_all()
        self.update_buttons()

    def build_conn_tab(self):
        box = Gtk.Box(spacing=14)
        box.set_border_width(10)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        left.pack_start(Gtk.Label(label=self._("profiles"), xalign=0), False, False, 0)
        self.store = Gtk.ListStore(str, str)
        self.tree = Gtk.TreeView(model=self.store)
        self.tree.set_headers_visible(False)
        self.tree.append_column(Gtk.TreeViewColumn("p", Gtk.CellRendererText(), text=1))
        self.tree.get_selection().connect("changed", self.on_profile_selected)
        sw = Gtk.ScrolledWindow()
        sw.set_size_request(300, -1)
        sw.add(self.tree)
        left.pack_start(sw, True, True, 0)
        row = Gtk.Box(spacing=6)
        for key, cb in (("add", self.add_profile), ("dup", self.dup_profile), ("delete", self.del_profile)):
            b = Gtk.Button(label=self._(key))
            b.connect("clicked", cb)
            row.pack_start(b, True, True, 0)
        left.pack_start(row, False, False, 0)
        box.pack_start(left, False, False, 0)

        g = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.f = {}

        def add_row(r, key, widget):
            lab = Gtk.Label(label=self._(key), xalign=1)
            g.attach(lab, 0, r, 1, 1)
            g.attach(widget, 1, r, 3, 1)
            widget.set_hexpand(True)
            self.f[key] = widget
            self.f[key + "_label"] = lab

        r = 0
        add_row(r, "name", Gtk.Entry()); r += 1
        proto = Gtk.ComboBoxText()
        proto.append("rdp", "RDP (Windows)")
        proto.append("vnc", "VNC")
        proto.connect("changed", lambda *a: self.on_proto_changed())
        add_row(r, "proto", proto); r += 1
        add_row(r, "host", Gtk.Entry()); r += 1
        add_row(r, "port", Gtk.Entry()); r += 1
        add_row(r, "user", Gtk.Entry()); r += 1
        pw = Gtk.Entry()
        pw.set_visibility(False)
        add_row(r, "password", pw); r += 1
        add_row(r, "domain", Gtk.Entry()); r += 1
        cbg = Gtk.Grid(column_homogeneous=True, column_spacing=12, row_spacing=4)
        for i, key in enumerate(("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert")):
            cb = Gtk.CheckButton(label=self._(key))
            cbg.attach(cb, i % 2, i // 2, 1, 1)
            self.f[key] = cb
        g.attach(cbg, 1, r, 3, 1)
        r += 1
        self.f["fullscreen"].connect("toggled", lambda *a: self.on_proto_changed())
        sz = Gtk.Box(spacing=6)
        self.f["width"] = Gtk.SpinButton.new_with_range(640, 7680, 10)
        self.f["height"] = Gtk.SpinButton.new_with_range(480, 4320, 10)
        sz.pack_start(self.f["width"], False, False, 0)
        sz.pack_start(Gtk.Label(label="×"), False, False, 0)
        sz.pack_start(self.f["height"], False, False, 0)
        lab = Gtk.Label(label=self._("size"), xalign=1)
        g.attach(lab, 0, r, 1, 1)
        g.attach(sz, 1, r, 3, 1)
        self.f["size_label"] = lab
        self.f["size_box"] = sz
        r += 1
        add_row(r, "extra", Gtk.Entry()); r += 1

        btns = Gtk.Box(spacing=8)
        self.f["boot"] = Gtk.CheckButton(label=self._("boot"))
        btns.pack_start(self.f["boot"], True, True, 0)
        save = Gtk.Button(label=self._("save"))
        save.connect("clicked", lambda *a: self.save_form(True))
        conn = Gtk.Button(label=self._("connect"))
        conn.get_style_context().add_class("suggested-action")
        conn.connect("clicked", lambda *a: self.connect_selected())
        btns.pack_end(conn, False, False, 0)
        btns.pack_end(save, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(g)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        right.set_hexpand(True)
        right.pack_start(scroll, True, True, 0)
        right.pack_start(btns, False, False, 0)
        box.pack_start(right, True, True, 0)
        return box

    def build_net_tab(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_border_width(10)
        self.net_info = Gtk.Label(xalign=0)
        self.net_info.set_selectable(False)
        box.pack_start(Gtk.Label(label=self._("net_status"), xalign=0), False, False, 0)
        box.pack_start(self.net_info, False, False, 0)

        g = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.n = {}
        r = 0
        self.n["dev"] = Gtk.ComboBoxText()
        self.n["dev"].connect("changed", lambda *a: self.on_net_dev_changed())
        g.attach(Gtk.Label(label=self._("net_iface"), xalign=1), 0, r, 1, 1)
        g.attach(self.n["dev"], 1, r, 2, 1)
        r += 1
        self.n["mode"] = Gtk.ComboBoxText()
        self.n["mode"].append("auto", self._("dhcp"))
        self.n["mode"].append("manual", self._("static"))
        self.n["mode"].set_active_id("auto")
        self.n["mode"].connect("changed", lambda *a: self.on_net_mode_changed())
        g.attach(Gtk.Label(label=self._("net_mode"), xalign=1), 0, r, 1, 1)
        g.attach(self.n["mode"], 1, r, 2, 1)
        r += 1
        for key in ("ip", "mask", "gw", "dns"):
            e = Gtk.Entry()
            e.set_hexpand(True)
            self.n[key] = e
            g.attach(Gtk.Label(label=self._(key), xalign=1), 0, r, 1, 1)
            g.attach(e, 1, r, 2, 1)
            r += 1
        self.wifi_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.wstore = Gtk.ListStore(str, str, str)
        self.wtree = Gtk.TreeView(model=self.wstore)
        for i, title in enumerate((self._("ssid"), self._("signal"), self._("security"))):
            self.wtree.append_column(Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=i))
        self.wtree.get_selection().connect("changed", self.on_ssid_selected)
        wsw = Gtk.ScrolledWindow()
        wsw.set_min_content_height(140)
        wsw.add(self.wtree)
        self.wifi_box.pack_start(wsw, True, True, 0)
        wg = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.n["ssid"] = Gtk.Entry()
        self.n["ssid"].set_hexpand(True)
        self.n["wpass"] = Gtk.Entry()
        self.n["wpass"].set_visibility(False)
        self.n["wpass"].set_hexpand(True)
        self.n["hidden"] = Gtk.CheckButton(label=self._("hidden"))
        scan = Gtk.Button(label=self._("scan"))
        scan.connect("clicked", lambda *a: self.scan_wifi())
        wg.attach(Gtk.Label(label=self._("ssid"), xalign=1), 0, 0, 1, 1)
        wg.attach(self.n["ssid"], 1, 0, 1, 1)
        wg.attach(scan, 2, 0, 1, 1)
        wg.attach(Gtk.Label(label=self._("wifi_pass"), xalign=1), 0, 1, 1, 1)
        wg.attach(self.n["wpass"], 1, 1, 1, 1)
        wg.attach(self.n["hidden"], 1, 2, 2, 1)
        self.wifi_box.pack_start(wg, False, False, 0)
        g.attach(self.wifi_box, 0, r, 3, 1)
        r += 1
        apply_btn = Gtk.Button(label=self._("apply"))
        apply_btn.get_style_context().add_class("suggested-action")
        apply_btn.connect("clicked", lambda *a: self.apply_net())
        apply_btn.set_halign(Gtk.Align.END)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(g)
        box.pack_start(scroll, True, True, 0)
        box.pack_start(apply_btn, False, False, 0)
        GLib.idle_add(self.load_net_devs)
        return box

    def build_sys_tab(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_border_width(14)
        g = Gtk.Grid(column_spacing=10, row_spacing=8)
        lang = Gtk.ComboBoxText()
        lang.append("ru", "Русский")
        lang.append("en", "English")
        lang.set_active_id(self.cfg.data.get("lang", "ru"))
        lang.connect("changed", self.on_lang_changed)
        g.attach(Gtk.Label(label=self._("language"), xalign=1), 0, 0, 1, 1)
        g.attach(lang, 1, 0, 1, 1)
        kb = Gtk.ComboBoxText()
        for k, label, _l, _o in KEYBOARDS:
            kb.append(k, label)
        kb.set_active_id(self.cfg.data.get("keyboard", "us"))
        kb.connect("changed", self.on_kb_changed)
        g.attach(Gtk.Label(label=self._("keyboard"), xalign=1), 0, 1, 1, 1)
        g.attach(kb, 1, 1, 1, 1)
        ar = Gtk.CheckButton(label=self._("autoreconnect"))
        ar.set_active(bool(self.cfg.data.get("autoreconnect", True)))
        ar.connect("toggled", self.on_autoreconnect_toggled)
        g.attach(ar, 1, 2, 1, 1)
        box.pack_start(g, False, False, 0)
        box.pack_start(Gtk.Label(label=self._("hotkeys"), xalign=0), False, False, 0)
        hk = Gtk.Label(label=self._("hotkeys_text"), xalign=0)
        hk.set_selectable(False)
        box.pack_start(hk, False, False, 0)
        pw = Gtk.Box(spacing=8)
        b1 = Gtk.Button(label=self._("reboot"))
        b1.connect("clicked", lambda *a: self.power("reboot"))
        b2 = Gtk.Button(label=self._("shutdown"))
        b2.connect("clicked", lambda *a: self.power("poweroff"))
        pw.pack_start(b1, False, False, 0)
        pw.pack_start(b2, False, False, 0)
        box.pack_start(Gtk.Label(label=self._("power"), xalign=0), False, False, 0)
        box.pack_start(pw, False, False, 0)
        box.pack_end(Gtk.Label(label=self._("version", VERSION), xalign=0), False, False, 0)
        return box

    # ------------------------------------------------------ window control
    def show_window(self, tab=None):
        if tab is not None:
            self.nb.set_current_page(tab)
        self.win.fullscreen()
        self.win.set_keep_above(True)
        self.win.show_all()
        self.update_buttons()
        self.win.present()

    def hide_window(self):
        if self.running():
            self.win.hide()

    def running(self):
        return self.proc is not None and self.proc.poll() is None

    def update_buttons(self):
        run_now = self.running()
        self.btn_back.set_visible(run_now)
        self.btn_disc.set_visible(run_now)
        self.btn_back.set_no_show_all(not run_now)
        self.btn_disc.set_no_show_all(not run_now)

    def set_status(self, text):
        self.status.set_text(text)

    def touch(self):
        """User interacted: stop auto-retry/auto-start timers."""
        self.interacted = True
        if self.retry_id:
            GLib.source_remove(self.retry_id)
            self.retry_id = 0
        if self.net_wait_id:
            GLib.source_remove(self.net_wait_id)
            self.net_wait_id = 0
        return False

    def on_key(self, w, ev):
        self.touch()
        if ev.keyval == Gdk.KEY_Escape and self.running():
            self.hide_window()
            return True
        return False

    # -------------------------------------------------------------- control
    def start_ctl(self):
        try:
            os.unlink(SOCK)
        except OSError:
            pass
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(SOCK)
        self.sock.setblocking(False)
        GLib.io_add_watch(self.sock.fileno(), GLib.IO_IN, self.on_ctl)

    def on_ctl(self, fd, cond):
        try:
            cmd = self.sock.recv(256).decode().strip()
        except OSError:
            return True
        self.touch()
        if cmd == "settings":
            self.show_window(0)
        elif cmd == "network":
            self.show_window(1)
        elif cmd == "power":
            self.show_window(2)
        elif cmd == "disconnect":
            self.disconnect()
        elif cmd == "reconnect":
            self.reconnect()
        elif cmd == "toggle":
            if self.win.get_visible() and self.running():
                self.hide_window()
            else:
                self.show_window()
        return True

    # ----------------------------------------------------------- profiles
    def reload_profiles(self, select=None):
        self.loading_form = True
        self.store.clear()
        sel_iter = None
        default = self.cfg.data.get("default", "")
        for p in self.cfg.data["profiles"]:
            label = p.get("name") or p.get("host") or "?"
            if p["id"] == default:
                label += "  ★ " + self._("default_mark")
            it = self.store.append([p["id"], label])
            if p["id"] == (select or self.sel_id):
                sel_iter = it
        self.loading_form = False
        if sel_iter is None and len(self.store) > 0:
            sel_iter = self.store.get_iter_first()
        if sel_iter is not None:
            self.tree.get_selection().select_iter(sel_iter)
        else:
            self.sel_id = ""
            self.fill_form(dict(DEFAULT_PROFILE), False)

    def on_profile_selected(self, sel):
        if self.loading_form:
            return
        model, it = sel.get_selected()
        if it is None:
            return
        pid = model[it][0]
        self.sel_id = pid
        p = self.cfg.profile(pid)
        if p:
            self.fill_form(p, self.cfg.data.get("default") == pid)

    def fill_form(self, p, is_default):
        self.loading_form = True
        f = self.f
        for key in ("name", "host", "port", "user", "password", "domain", "extra"):
            f[key].set_text(str(p.get(key, "")))
        f["proto"].set_active_id(p.get("proto", "rdp"))
        for key in ("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert"):
            f[key].set_active(bool(p.get(key, DEFAULT_PROFILE[key])))
        f["width"].set_value(int(p.get("width", 1920)))
        f["height"].set_value(int(p.get("height", 1080)))
        f["boot"].set_active(is_default)
        self.loading_form = False
        self.on_proto_changed()

    def read_form(self):
        f = self.f
        p = {"id": self.sel_id or uuid.uuid4().hex[:8]}
        for key in ("name", "host", "port", "user", "password", "domain", "extra"):
            p[key] = f[key].get_text().strip() if key not in ("password",) else f[key].get_text()
        p["proto"] = f["proto"].get_active_id() or "rdp"
        for key in ("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert"):
            p[key] = f[key].get_active()
        p["width"] = int(f["width"].get_value())
        p["height"] = int(f["height"].get_value())
        if not p["name"]:
            p["name"] = p["host"]
        return p

    def on_proto_changed(self):
        if self.loading_form:
            return
        rdp = self.f["proto"].get_active_id() != "vnc"
        for key in ("user", "domain", "sound", "usb", "ignorecert", "extra", "clipboard"):
            self.f[key].set_sensitive(rdp or key in ("clipboard",))
            lab = self.f.get(key + "_label")
            if lab:
                lab.set_sensitive(rdp)
        fs = self.f["fullscreen"].get_active()
        self.f["size_box"].set_sensitive(not fs)
        self.f["size_label"].set_sensitive(not fs)
        self.f["multimon"].set_sensitive(fs)

    def save_form(self, notify=False):
        p = self.read_form()
        profiles = self.cfg.data["profiles"]
        for i, old in enumerate(profiles):
            if old["id"] == p["id"]:
                profiles[i] = p
                break
        else:
            profiles.append(p)
        self.sel_id = p["id"]
        if self.f["boot"].get_active():
            self.cfg.data["default"] = p["id"]
        elif self.cfg.data.get("default") == p["id"]:
            self.cfg.data["default"] = ""
        ok = self.cfg.save()
        self.reload_profiles(p["id"])
        if notify:
            self.set_status(self._("status_saved") if ok else "Save failed")
        return p

    def add_profile(self, *a):
        self.sel_id = ""
        self.tree.get_selection().unselect_all()
        p = dict(DEFAULT_PROFILE)
        p["name"] = self._("new_profile")
        self.fill_form(p, not self.cfg.data["profiles"])

    def dup_profile(self, *a):
        p = self.read_form()
        self.sel_id = ""
        p["name"] = p["name"] + " (2)"
        self.tree.get_selection().unselect_all()
        self.fill_form(p, False)

    def del_profile(self, *a):
        if not self.sel_id:
            return
        self.cfg.data["profiles"] = [p for p in self.cfg.data["profiles"] if p["id"] != self.sel_id]
        if self.cfg.data.get("default") == self.sel_id:
            self.cfg.data["default"] = ""
        self.sel_id = ""
        self.cfg.save()
        self.reload_profiles()

    def connect_selected(self):
        p = self.save_form()
        self.interacted = False
        self.connect(p)

    # ------------------------------------------------------------ sessions
    def startup(self):
        if not PERSISTENT:
            self.set_status(self._("status_notpersist"))
        prof = self.cfg.profile(self.cfg.data.get("default", ""))
        self.show_window(0)
        if prof and prof.get("host"):
            self.current_pid = prof["id"]
            self.set_status(self._("status_wait_net"))
            self.net_deadline = time.time() + 40
            self.net_wait_id = GLib.timeout_add(1000, self.wait_net)
        else:
            self.set_status(self._("status_noprofile") if not self.cfg.data["profiles"]
                            else self._("status_ready"))
        return False

    def wait_net(self):
        rc, out = run(["nmcli", "-t", "-g", "STATE", "general"], 4)
        state = out.strip()
        if state.startswith("connected") or time.time() > self.net_deadline:
            self.net_wait_id = 0
            prof = self.cfg.profile(self.current_pid)
            if prof:
                self.connect(prof)
            return False
        return True

    def reconnect(self):
        prof = self.cfg.profile(self.current_pid) or self.cfg.profile(self.cfg.data.get("default", ""))
        if not prof:
            self.show_window(0)
            return
        self.interacted = False
        self.connect(prof)

    def ask_credentials(self, prof):
        d = Gtk.Dialog(title=self._("ask_creds"), transient_for=self.win, modal=True)
        d.add_button(self._("cancel"), Gtk.ResponseType.CANCEL)
        d.add_button(self._("ok"), Gtk.ResponseType.OK)
        d.set_default_response(Gtk.ResponseType.OK)
        g = Gtk.Grid(column_spacing=10, row_spacing=8)
        g.set_border_width(14)
        eu, ep = Gtk.Entry(), Gtk.Entry()
        eu.set_text(prof.get("user", ""))
        ep.set_visibility(False)
        ep.set_activates_default(True)
        eu.set_activates_default(True)
        g.attach(Gtk.Label(label=self._("user"), xalign=1), 0, 0, 1, 1)
        g.attach(eu, 1, 0, 1, 1)
        g.attach(Gtk.Label(label=self._("password"), xalign=1), 0, 1, 1, 1)
        g.attach(ep, 1, 1, 1, 1)
        d.get_content_area().add(g)
        d.show_all()
        (ep if eu.get_text() else eu).grab_focus()
        resp = d.run()
        res = (eu.get_text(), ep.get_text()) if resp == Gtk.ResponseType.OK else None
        d.destroy()
        return res

    def build_cmd(self, p):
        host = p["host"].strip()
        port = p.get("port", "").strip()
        if p["proto"] == "vnc":
            cmd = ["xtigervncviewer", "-Shared"]
            if p.get("fullscreen", True):
                cmd.append("-FullScreen")
                if p.get("multimon"):
                    cmd.append("-FullScreenMode=All")
            # FullscreenSystemKeys=0: do not grab the keyboard, so the Ctrl+Alt+Shift hotkeys keep working
            cmd += ["-MenuKey", "none", "-ReconnectOnError=0", "-FullscreenSystemKeys=0"]
            if p.get("password"):
                with open(VNC_PASS, "wb") as f:
                    f.write(vnc_obfuscate(p["password"]))
                os.chmod(VNC_PASS, 0o600)
                cmd += ["-passwd", VNC_PASS]
            cmd.append("{}::{}".format(host, port) if port else host)
            return cmd
        target = "{}:{}".format(host, port) if port else host
        cmd = ["xfreerdp3", "/v:" + target]
        if p.get("user"):
            cmd.append("/u:" + p["user"])
        if p.get("password"):
            cmd.append("/p:" + p["password"])
        if p.get("domain"):
            cmd.append("/d:" + p["domain"])
        if p.get("fullscreen", True):
            cmd.append("/f")
            if p.get("multimon"):
                cmd.append("/multimon")
        else:
            cmd.append("/size:{}x{}".format(p.get("width", 1280), p.get("height", 720)))
        cmd.append("+clipboard" if p.get("clipboard", True) else "-clipboard")
        if p.get("sound", True):
            cmd += ["/sound:sys:pulse", "/microphone:sys:pulse"]
        if p.get("usb"):
            cmd.append("/usb:auto")
        if p.get("ignorecert", True):
            cmd.append("/cert:ignore")
        cmd += ["-grab-keyboard", "+auto-reconnect", "/auto-reconnect-max-retries:3",
                "/dynamic-resolution", "/network:auto"]
        if p.get("extra"):
            import shlex
            cmd += shlex.split(p["extra"])
        return cmd

    def connect(self, prof):
        self.touch_timers_only()
        prof = dict(prof)
        if not prof.get("host"):
            self.show_window(0)
            self.set_status(self._("status_nohost"))
            return
        self.current_pid = prof.get("id", "")
        if prof["proto"] == "rdp" and (not prof.get("user") or not prof.get("password")):
            self.show_window(0)
            creds = self.ask_credentials(prof)
            if creds is None:
                return
            prof["user"], prof["password"] = creds
        if self.running():
            self.user_stop = True
            self.proc.terminate()
            try:
                self.proc.wait(3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        cmd = self.build_cmd(prof)
        self.user_stop = False
        try:
            log = open(CLIENT_LOG, "w")
            self.proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, start_new_session=True)
        except Exception as e:  # noqa: BLE001
            self.proc = None
            self.show_window()
            self.set_status(self._("status_ended", "-", str(e)))
            return
        self.started = time.time()
        self.set_status(self._("status_connecting", prof.get("name") or prof["host"]))
        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, self.proc.pid, self.on_exit)
        GLib.timeout_add_seconds(3, self.hide_if_alive, self.proc.pid)
        if prof["proto"] == "vnc":
            # TigerVNC keeps a modal error dialog open instead of exiting: watch its log.
            GLib.timeout_add_seconds(1, self.watch_vnc_log, self.proc.pid)
        self.update_buttons()

    def touch_timers_only(self):
        if self.retry_id:
            GLib.source_remove(self.retry_id)
            self.retry_id = 0
        if self.net_wait_id:
            GLib.source_remove(self.net_wait_id)
            self.net_wait_id = 0

    def watch_vnc_log(self, pid):
        if self.proc is None or self.proc.pid != pid or self.proc.poll() is not None:
            return False
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                text = f.read()
        except OSError:
            return True
        if re.search(r"(unable to connect|Failed to connect|Authentication (failed|failure)|"
                     r"No matching security|Connection (refused|reset|closed|timed out)|"
                     r"Disconnected)", text):
            try:
                self.proc.terminate()
            except OSError:
                pass
            return False
        return True

    def hide_if_alive(self, pid):
        if self.proc is not None and self.proc.pid == pid and self.proc.poll() is None:
            self.win.hide()
        return False

    def on_exit(self, pid, status):
        code = os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status
        if self.proc is None or self.proc.pid != pid:
            return
        self.proc.poll()
        self.proc = None
        try:
            os.unlink(VNC_PASS)
        except OSError:
            pass
        if self.user_stop:
            self.user_stop = False
            self.show_window(0)
            self.set_status(self._("status_ready"))
            return
        tail = ""
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                lines = [ln.strip() for ln in f.read().splitlines() if ln.strip()]
            tail = " | ".join(lines[-2:])[-220:]
        except OSError:
            pass
        self.show_window(0)
        self.set_status(self._("status_ended", code, tail))
        if self.cfg.data.get("autoreconnect", True) and not self.interacted:
            self.retry_left = 10 if time.time() - self.started < 15 else 3
            self.retry_id = GLib.timeout_add_seconds(1, self.retry_tick, tail, code)

    def retry_tick(self, tail, code):
        if self.interacted:
            self.retry_id = 0
            return False
        self.retry_left -= 1
        if self.retry_left <= 0:
            self.retry_id = 0
            self.reconnect()
            return False
        self.set_status(self._("status_ended", code, tail) + "\n" + self._("status_retry", self.retry_left))
        return True

    def disconnect(self):
        if self.running():
            self.user_stop = True
            self.proc.terminate()
        else:
            self.show_window(0)

    # ------------------------------------------------------------- network
    def run_async(self, fn, done):
        def worker():
            res = fn()
            GLib.idle_add(done, res)
        threading.Thread(target=worker, daemon=True).start()

    def load_net_devs(self):
        rc, out = run(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"], 6)
        devs = []
        for line in out.splitlines():
            parts = nm_split(line)
            if len(parts) >= 2 and parts[1] in ("ethernet", "wifi"):
                devs.append((parts[0], parts[1]))
        self.net_devs = devs
        cb = self.n["dev"]
        cb.remove_all()
        for d, t in devs:
            cb.append(d, "{} ({})".format(d, "Wi-Fi" if t == "wifi" else "Ethernet"))
        if devs:
            cb.set_active(0)
        else:
            cb.append("", self._("no_dev"))
            cb.set_active(0)
        self.on_net_mode_changed()
        return False

    def cur_dev(self):
        did = self.n["dev"].get_active_id()
        for d, t in self.net_devs:
            if d == did:
                return d, t
        return None, None

    def on_net_dev_changed(self):
        d, t = self.cur_dev()
        self.wifi_box.set_visible(t == "wifi")
        self.wifi_box.set_no_show_all(t != "wifi")
        if t == "wifi":
            self.scan_wifi()

    def on_net_mode_changed(self):
        manual = self.n["mode"].get_active_id() == "manual"
        for k in ("ip", "mask", "gw", "dns"):
            self.n[k].set_sensitive(manual)
        d, t = self.cur_dev()
        self.wifi_box.set_visible(t == "wifi")

    def scan_wifi(self):
        d, t = self.cur_dev()
        if t != "wifi" or self.scan_busy:
            return
        self.scan_busy = True
        self.set_status(self._("scanning"))

        def work():
            return run(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list",
                        "ifname", d, "--rescan", "yes"], 25)

        def done(res):
            self.scan_busy = False
            rc, out = res
            self.wstore.clear()
            seen = set()
            for line in out.splitlines():
                parts = nm_split(line)
                if len(parts) >= 3 and parts[0] and parts[0] not in seen:
                    seen.add(parts[0])
                    self.wstore.append([parts[0], parts[1] + "%", parts[2] or "—"])
            self.set_status("")
            return False
        self.run_async(work, done)

    def on_ssid_selected(self, sel):
        model, it = sel.get_selected()
        if it is not None:
            self.n["ssid"].set_text(model[it][0])

    def refresh_net_status(self):
        def work():
            _, a = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], 5)
            _, b = run(["ip", "-4", "-o", "addr", "show", "scope", "global"], 5)
            return a, b

        def done(res):
            a, b = res
            ips = {}
            for line in b.splitlines():
                m = re.match(r"\d+:\s+(\S+)\s+inet\s+(\S+)", line)
                if m:
                    ips[m.group(1)] = m.group(2)
            lines = []
            for line in a.splitlines():
                p = nm_split(line)
                if len(p) >= 4 and p[1] in ("ethernet", "wifi"):
                    lines.append("{}: {} {} {}".format(p[0], p[2], p[3], ips.get(p[0], "")).strip())
            self.net_info.set_text("\n".join(lines) or "—")
            return False
        if self.win.get_visible():
            self.run_async(work, done)
        return True

    def apply_net(self):
        dev, typ = self.cur_dev()
        if not dev:
            return
        mode = self.n["mode"].get_active_id()
        name = "kiosk-" + dev
        args = []
        if mode == "manual":
            try:
                mask = self.n["mask"].get_text().strip()
                ip = ipaddress.ip_address(self.n["ip"].get_text().strip())
                prefix = mask.lstrip("/") if mask.lstrip("/").isdigit() else \
                    str(ipaddress.ip_network("0.0.0.0/" + mask).prefixlen)
                gw = self.n["gw"].get_text().strip()
                if gw:
                    ipaddress.ip_address(gw)
                args = ["ipv4.method", "manual", "ipv4.addresses", "{}/{}".format(ip, prefix)]
                if gw:
                    args += ["ipv4.gateway", gw]
                dns = ",".join(x.strip() for x in self.n["dns"].get_text().split(",") if x.strip())
                if dns:
                    args += ["ipv4.dns", dns]
            except ValueError:
                self.set_status(self._("bad_ip"))
                return
        else:
            args = ["ipv4.method", "auto"]
        ssid = self.n["ssid"].get_text().strip()
        wpass = self.n["wpass"].get_text()
        hidden = self.n["hidden"].get_active()

        def work():
            run(["nmcli", "connection", "delete", name], 10)
            base = ["nmcli", "connection", "add", "type", typ, "ifname", dev, "con-name", name,
                    "connection.autoconnect", "yes"]
            if typ == "wifi":
                if not ssid:
                    return 1, "SSID?"
                base += ["ssid", ssid]
                if hidden:
                    base += ["802-11-wireless.hidden", "yes"]
                if wpass:
                    base += ["wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", wpass]
            rc, out = run(base + args, 20)
            if rc != 0:
                return rc, out
            return run(["nmcli", "connection", "up", name], 45)

        def done(res):
            rc, out = res
            self.set_status(self._("net_applied") if rc == 0 else self._("net_failed", out.strip()[:200]))
            return False
        self.set_status("…")
        self.run_async(work, done)

    # -------------------------------------------------------------- system
    def on_lang_changed(self, cb):
        lang = cb.get_active_id()
        if lang and lang != self.cfg.data.get("lang"):
            self.cfg.data["lang"] = lang
            self.cfg.save()
            page = self.nb.get_current_page()
            self.build_ui()
            self.nb.set_current_page(page)
            self.win.show_all()

    def on_kb_changed(self, cb):
        k = cb.get_active_id()
        if k:
            self.cfg.data["keyboard"] = k
            self.cfg.save()
            apply_keyboard(k)

    def on_autoreconnect_toggled(self, cb):
        self.cfg.data["autoreconnect"] = cb.get_active()
        self.cfg.save()

    def power(self, what):
        msg = self._("confirm_reboot" if what == "reboot" else "confirm_shutdown")
        d = Gtk.MessageDialog(transient_for=self.win, modal=True, message_type=Gtk.MessageType.QUESTION,
                              buttons=Gtk.ButtonsType.NONE, text=msg)
        d.add_button(self._("cancel"), Gtk.ResponseType.CANCEL)
        d.add_button(self._("ok"), Gtk.ResponseType.OK)
        resp = d.run()
        d.destroy()
        if resp == Gtk.ResponseType.OK:
            run(["systemctl", what], 10)


def main():
    Kiosk()
    Gtk.main()


if __name__ == "__main__":
    main()
