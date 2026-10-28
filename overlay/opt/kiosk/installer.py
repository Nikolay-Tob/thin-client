#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Installer GUI ("Install to PC" boot menu entry): copies this system to an internal disk of the computer.

Runs in the same bare X session as the kiosk (session.sh starts it instead of kiosk.py when the kernel command
line has kiosk.install=1). The actual work is done by kiosk-install@<disk>.service (root); this window only
lists the disks, asks for confirmation and shows the progress.
"""
import json
import os
import subprocess

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk  # noqa: E402

TOOL = "/usr/local/sbin/kiosk-install"
LOG = "/run/kiosk-install.log"

TR = {
    "ru": {
        "title": "Установка на ПК",
        "intro": "Система будет установлена на внутренний диск этого компьютера, после чего она будет загружаться "
                 "с него без флешки. Выберите диск:",
        "warn": "ВНИМАНИЕ: все данные на выбранном диске будут безвозвратно удалены!",
        "nodisk": "Подходящие диски не найдены (нужен диск не меньше {0}, кроме самой флешки).",
        "keepcfg": "Перенести профили и сетевые настройки с этой флешки",
        "install": "Установить", "cancel": "Отмена (перезагрузка)", "refresh": "Обновить список",
        "confirm": "Стереть диск {0} ({1}) и установить систему?\n\nВсе данные на нём будут удалены.",
        "erase": "Стереть и установить",
        "back": "Назад",
        "working": "Идёт установка. Не выключайте компьютер и не вынимайте флешку.",
        "done": "Установка завершена.\n\nИзвлеките флешку и нажмите «Перезагрузить». Компьютер загрузится с установленной системы.",
        "reboot": "Перезагрузить", "shutdown": "Выключить",
        "error": "Ошибка установки:\n{0}",
        "removable": "съёмный", "unknown": "диск",
    },
    "en": {
        "title": "Install to PC",
        "intro": "The system will be installed on an internal disk of this computer and will then boot from it "
                 "without the flash drive. Choose the disk:",
        "warn": "WARNING: all data on the selected disk will be permanently erased!",
        "nodisk": "No suitable disk found (a disk of at least {0} other than this flash drive is required).",
        "keepcfg": "Copy profiles and network settings from this flash drive",
        "install": "Install", "cancel": "Cancel (reboot)", "refresh": "Refresh the list",
        "confirm": "Erase disk {0} ({1}) and install the system?\n\nAll data on it will be deleted.",
        "erase": "Erase and install",
        "back": "Back",
        "working": "Installing. Do not power off the computer and do not remove the flash drive.",
        "done": "Installation finished.\n\nRemove the flash drive and press “Reboot”. The computer will boot from the installed system.",
        "reboot": "Reboot", "shutdown": "Shut down",
        "error": "Installation failed:\n{0}",
        "removable": "removable", "unknown": "disk",
    },
}


def human(n):
    for unit, div in (("ТБ", 1 << 40), ("ГБ", 1 << 30), ("МБ", 1 << 20)):
        if n >= div:
            return "%.1f %s" % (n / div, unit)
    return "%d B" % n


def human_en(n):
    return human(n).replace("ТБ", "TB").replace("ГБ", "GB").replace("МБ", "MB")


def load_lang():
    for p in ("/data/kiosk/config.json",):
        try:
            with open(p, encoding="utf-8") as f:
                return json.load(f).get("lang", "ru")
        except Exception:  # noqa: BLE001
            pass
    return "ru"


class Installer:
    def __init__(self):
        self.lang = load_lang()
        if self.lang not in TR:
            self.lang = "ru"
        self.disks = []
        self.need = 0
        self.sel = None
        self.timer = None

        Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
        css = Gtk.CssProvider()
        css.load_from_data(b"""
            * { font-size: 13pt; }
            .title { font-size: 24pt; font-weight: bold; }
            .warn { color: #c0392b; font-weight: bold; }
            .ok { color: #1e7e34; font-weight: bold; }
            button { padding: 8px 20px; }
            .disk { padding: 10px; }
        """)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.win = Gtk.Window()
        self.win.set_decorated(False)
        self.win.connect("delete-event", lambda *a: True)
        self.win.fullscreen()
        self.show_select()
        self.win.show_all()

    def _(self, key, *a):
        s = TR[self.lang][key]
        return s.format(*a) if a else s

    def size(self, n):
        return human(n) if self.lang == "ru" else human_en(n)

    def set_page(self, widget):
        old = self.win.get_child()
        if old:
            self.win.remove(old)
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        widget.set_halign(Gtk.Align.CENTER)
        widget.set_valign(Gtk.Align.CENTER)
        widget.set_size_request(820, -1)
        widget.set_margin_start(30)
        widget.set_margin_end(30)
        outer.pack_start(widget, True, True, 0)
        self.win.add(outer)
        self.win.show_all()

    def label(self, text, cls=None, wrap=True):
        lb = Gtk.Label(label=text)
        lb.set_line_wrap(wrap)
        lb.set_xalign(0)
        lb.set_max_width_chars(70)
        if cls:
            lb.get_style_context().add_class(cls)
        return lb

    # ------------------------------------------------------------ select disk
    def load_disks(self):
        try:
            r = subprocess.run([TOOL, "list"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30)
            j = json.loads(r.stdout)
            self.disks, self.need = j["disks"], j["need"]
        except Exception:  # noqa: BLE001
            self.disks, self.need = [], 0

    def show_select(self):
        self.load_disks()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.pack_start(self.label(self._("title"), "title"), False, False, 0)
        box.pack_start(self.label(self._("intro")), False, False, 0)
        self.radios = []
        first = None
        if not self.disks:
            box.pack_start(self.label(self._("nodisk", self.size(self.need or (2 << 30))), "warn"), False, False, 8)
        for d in self.disks:
            tran = d["tran"].upper() or self._("unknown")
            if d["removable"]:
                tran += ", " + self._("removable")
            txt = "%s    %s    %s    [%s]" % (d["name"], self.size(d["size"]), d["model"] or "", tran)
            rb = Gtk.RadioButton.new_with_label_from_widget(first, txt)
            rb.get_style_context().add_class("disk")
            if first is None:
                first = rb
            rb.connect("toggled", lambda w, dd=d: w.get_active() and setattr(self, "sel", dd))
            self.radios.append((rb, d))
            box.pack_start(rb, False, False, 0)
        if self.disks:
            self.sel = self.disks[0]
        self.keep = Gtk.CheckButton(label=self._("keepcfg"))
        self.keep.set_active(True)
        if self.disks:
            box.pack_start(self.keep, False, False, 6)
        box.pack_start(self.label(self._("warn"), "warn"), False, False, 4)
        row = Gtk.Box(spacing=10)
        b_inst = Gtk.Button(label=self._("install"))
        b_inst.set_sensitive(bool(self.disks))
        b_inst.connect("clicked", self.on_install)
        b_ref = Gtk.Button(label=self._("refresh"))
        b_ref.connect("clicked", lambda *a: self.show_select())
        b_can = Gtk.Button(label=self._("cancel"))
        b_can.connect("clicked", lambda *a: self.power("reboot"))
        row.pack_start(b_inst, False, False, 0)
        row.pack_start(b_ref, False, False, 0)
        row.pack_end(b_can, False, False, 0)
        box.pack_start(row, False, False, 10)
        self.set_page(box)
        if self.disks:
            b_inst.grab_focus()

    # ---------------------------------------------------------------- confirm
    def on_install(self, *a):
        d = self.sel
        if not d:
            return
        dlg = Gtk.MessageDialog(transient_for=self.win, modal=True, message_type=Gtk.MessageType.WARNING,
                                text=self._("confirm", d["name"], self.size(d["size"])))
        dlg.add_button(self._("back"), Gtk.ResponseType.CANCEL)
        dlg.add_button(self._("erase"), Gtk.ResponseType.OK)
        dlg.set_default_response(Gtk.ResponseType.CANCEL)
        resp = dlg.run()
        dlg.destroy()
        if resp == Gtk.ResponseType.OK:
            self.start(d)

    # --------------------------------------------------------------- progress
    def start(self, d):
        unit = "kiosk-install@%s%s.service" % (os.path.basename(d["name"]), "" if self.keep.get_active() else "_nocfg")
        try:
            os.remove(LOG)
        except OSError:
            pass
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.pack_start(self.label(self._("title"), "title"), False, False, 0)
        box.pack_start(self.label(self._("working")), False, False, 0)
        self.bar = Gtk.ProgressBar()
        self.bar.set_show_text(True)
        self.bar.set_text("0 %")
        box.pack_start(self.bar, False, False, 6)
        self.status = self.label("")
        box.pack_start(self.status, False, False, 0)
        self.set_page(box)
        r = subprocess.run(["systemctl", "start", "--no-block", unit], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True)
        if r.returncode != 0:
            self.show_result(False, r.stdout.strip())
            return
        self.unit = unit
        self.timer = GLib.timeout_add(500, self.poll)

    def poll(self):
        try:
            with open(LOG, encoding="utf-8", errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            lines = []
        for ln in lines:
            if ln.startswith("PROGRESS "):
                _, pct, msg = (ln.split(" ", 2) + [""])[:3]
                try:
                    self.bar.set_fraction(int(pct) / 100.0)
                    self.bar.set_text("%s %%" % pct)
                    self.status.set_text(msg)
                except ValueError:
                    pass
        if any(ln == "DONE" for ln in lines):
            self.timer = None
            self.show_result(True, "")
            return False
        err = [ln for ln in lines if ln.startswith("ERROR ")]
        if err:
            self.timer = None
            self.show_result(False, err[-1][6:])
            return False
        st = subprocess.run(["systemctl", "is-active", self.unit], stdout=subprocess.PIPE, text=True).stdout.strip()
        if st == "failed":
            self.timer = None
            self.show_result(False, "service failed")
            return False
        return True

    def show_result(self, ok, msg):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.pack_start(self.label(self._("title"), "title"), False, False, 0)
        box.pack_start(self.label(self._("done") if ok else self._("error", msg), "ok" if ok else "warn"), False, False, 8)
        row = Gtk.Box(spacing=10)
        b1 = Gtk.Button(label=self._("reboot"))
        b1.connect("clicked", lambda *a: self.power("reboot"))
        b2 = Gtk.Button(label=self._("shutdown"))
        b2.connect("clicked", lambda *a: self.power("poweroff"))
        row.pack_start(b1, False, False, 0)
        row.pack_start(b2, False, False, 0)
        if not ok:
            b3 = Gtk.Button(label=self._("back"))
            b3.connect("clicked", lambda *a: self.show_select())
            row.pack_end(b3, False, False, 0)
        box.pack_start(row, False, False, 10)
        self.set_page(box)
        b1.grab_focus()

    def power(self, what):
        subprocess.Popen(["systemctl", what])


if __name__ == "__main__":
    Installer()
    Gtk.main()
