#!/bin/sh
# thin-client-build.sh - self-extracting builder for the RDP/VNC kiosk thin client (Ubuntu 24.04 based).
# Unpacks the build kit next to this script and builds thin-client.img (USB flash drive: BIOS + UEFI/Secure Boot)
# and thin-client.vhd (BIOS virtual machines).
# Needs: Ubuntu 24.04 (VM or WSL2 is fine), root, internet, ~8 GB free disk. Takes ~10-15 minutes.
# Usage: sudo sh thin-client-build.sh [output-dir]      (default: ./out)
set -eu
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo sh $0 [output-dir]" >&2; exit 1; }
DEST=${KIT_DIR:-$PWD/thin-client-kit}
mkdir -p "$DEST"
echo "== unpacking the kit to $DEST"
cat > "$DEST/README.md" <<'__KIT_EOF__'
# Тонкий клиент на флешке (RDP / VNC, киоск)

Загрузочная флешка на базе Ubuntu 24.04. После включения компьютера сразу подключается к выбранному серверу
по **RDP** (Windows) или **VNC**. Рабочего стола и доступа к Linux у пользователя нет: есть только окно настроек,
которое открывается горячими клавишами.

**Скачать:** [последний релиз](https://github.com/Nikolay-Tob/thin-client/releases/latest)
(`thin-client.img` — для флешки, `thin-client.vhd` — для виртуальных машин, `SHA256SUMS.txt` — контрольные суммы).

## Возможности
- Загрузка в режимах **BIOS и UEFI**, в том числе с включённым **Secure Boot**; x86_64.
- Подключение стартует сразу при загрузке (профиль с отметкой «Подключаться при загрузке»).
- Профили подключений добавляются в окне настроек (готовых профилей в образе нет). Хранятся на самой флешке.
- RDP: FreeRDP 3 — звук и микрофон, общий буфер обмена, проброс USB-устройств, несколько мониторов, динамическое разрешение.
- VNC: два клиента на выбор — TigerVNC (буфер обмена, несколько мониторов, шифрование TLS) и SSVNC (масштабирование и выбор режима курсора). По умолчанию клиент выбирается автоматически.
- **Масштаб изображения** в профиле: «Авто», «Вписать в экран» (с сохранением пропорций), «Растянуть на весь экран», «Как есть (1:1)», 50 / 75 / 125 / 150 / 200 %. Для RDP: «Авто» (разрешение под экран), «Растянуть» (размер из профиля на весь экран), «Как есть», крупнее интерфейс Windows 125 / 150 / 200 %.
- **Курсор мыши (VNC):** «Авто» (курсор сервера, точка, если его нет), «Форма курсора с сервера (X11)», «Курсор рисует сервер (в картинке)», «Локальная стрелка + курсор сервера». Если видна только точка, выберите «Курсор рисует сервер».
- Сеть: Ethernet (DHCP или статический IP), Wi-Fi (поиск сетей, WPA-PSK, скрытые сети). Настройки сохраняются на флешке.
- **Установка на ПК:** пункт «Установка на ПК» в меню загрузчика переносит систему на внутренний диск компьютера (BIOS и UEFI), дальше флешка не нужна.
- Интерфейс на русском и английском, раскладка клавиатуры English / English + Русская.
- Корень системы только для чтения (squashfs, изменения живут в оперативной памяти): внезапное выключение систему не портит, пишется только раздел с настройками.
- Раздел с настройками при первом запуске сам расширяется на всё свободное место флешки.

## Скриншоты
| | |
|---|---|
| ![Первый запуск](docs/screens/01-first-run.png) | ![Профили](docs/screens/02-profiles.png) |
| **Первый запуск:** профилей нет, окно настроек откроется само. | **Профили подключений:** добавить, копировать, удалить; звёздочка — запуск при загрузке. |
| ![Сеть](docs/screens/03-network.png) | ![Система](docs/screens/04-system.png) |
| **Сеть:** статический IP или DHCP, Wi-Fi. Сохранённые значения показываются после перезагрузки. | **Система:** язык, раскладка, горячие клавиши, перезагрузка и выключение. |
| ![VNC](docs/screens/05-vnc-session.png) | ![RDP](docs/screens/06-rdp-session.png) |
| **Сеанс VNC** на весь экран (тестовый сервер). | **Сеанс RDP** на весь экран (тестовый сервер). |
| ![UEFI Secure Boot](docs/screens/07-uefi-secureboot.png) | ![Меню загрузчика BIOS](docs/screens/08-boot-menu-bios.png) |
| **Загрузка в UEFI с включённым Secure Boot.** | **Меню загрузчика (BIOS):** пункт «Установка на ПК». |
| ![Меню загрузчика UEFI](docs/screens/09-boot-menu-uefi.png) | ![Выбор диска](docs/screens/10-install-select.png) |
| **Меню загрузчика (UEFI + Secure Boot):** там пункт называется «Install to PC» (GRUB не загружает шрифт с кириллицей при Secure Boot). | **Установка:** выбор диска, перенос настроек с флешки. |
| ![Подтверждение](docs/screens/11-install-confirm.png) | ![Прогресс](docs/screens/12-install-progress.png) |
| **Подтверждение:** диск будет стёрт. | **Копирование и проверка** загрузочного раздела и системы. |
| ![Готово](docs/screens/13-install-done.png) | ![Профиль VNC](docs/screens/14-vnc-profile.png) |
| **Готово:** извлеките флешку и перезагрузите компьютер. | **Профиль VNC:** масштаб изображения, режим курсора, выбор клиента. |
| ![VNC вписан](docs/screens/15-vnc-fit.png) | |
| **VNC «Вписать в экран»:** картинка 1024×768 вписана в экран с сохранением пропорций. | |

Скриншоты сделаны в эмуляторе QEMU с тестовыми серверами.

## Запись на флешку
Образ около 0,9 ГБ, подойдёт любая флешка от 2 ГБ. **Все данные на флешке будут стёрты.**
- **Windows:** [Rufus](https://rufus.ie) или [balenaEtcher](https://etcher.balena.io). В Rufus выберите «Образ DD» (режим DD).
- **Linux:** `sudo dd if=thin-client.img of=/dev/sdX bs=4M status=progress conv=fsync` (`/dev/sdX` — флешка, проверьте имя командой `lsblk`).

`thin-client.vhd` — динамический диск (4 ГБ виртуально) для виртуальных машин с BIOS (Hyper-V поколения 1, VirtualBox, QEMU).

## Установка на внутренний диск компьютера
1. Загрузитесь с флешки и в первую секунду загрузки нажмите **Esc** (или удерживайте **Shift**): откроется меню загрузчика.
2. Выберите **«Установка на ПК»** (в UEFI с Secure Boot — «Install to PC») и нажмите Enter.
3. В окне установщика выберите диск, при желании оставьте галочку «Перенести профили и сетевые настройки с этой флешки», нажмите «Установить» и подтвердите.
4. После сообщения «Установка завершена» извлеките флешку и нажмите «Перезагрузить».

**Выбранный диск будет полностью стёрт** (включая Windows и другие системы). Установка копирует загрузочный раздел и систему с флешки
и проверяет копию; раздел с настройками занимает всё остальное место диска. На установленной системе пункта установки в меню нет.
Диск получается с таблицей разделов MBR (как у флешки), поэтому для данных используется не более 2 ТБ. UEFI-запись «Thin client» создаётся
автоматически, на других компьютерах загрузка идёт по пути `\EFI\BOOT\BOOTX64.EFI`.

## Первый запуск
1. Загрузитесь с флешки (в меню выбора загрузки, обычно F8/F10/F12/Esc). Secure Boot можно оставить включённым.
2. Окно настроек откроется само: **«Добавить»**, заполните профиль (протокол, адрес, логин, пароль), отметьте
   **«Подключаться при загрузке»**, нажмите **«Сохранить»** и **«Подключиться»**.
3. Сеть: по умолчанию DHCP по кабелю. Статический IP и Wi-Fi — вкладка **«Сеть»**, затем **«Применить»**.
4. Дальше при каждом включении подключение стартует само.

## Горячие клавиши (работают и во время сеанса)
| Клавиши | Действие |
|---|---|
| F12 | открыть/скрыть меню настроек |
| Ctrl+Alt+Shift+S | окно настроек и профилей |
| Ctrl+Alt+Shift+N | сетевые настройки |
| Ctrl+Alt+Shift+P | питание и система (язык, раскладка, перезагрузка, выключение) |
| Ctrl+Alt+Shift+R | переподключиться |
| Ctrl+Alt+Shift+D | отключиться |
| Ctrl+Alt+Shift+Пробел | показать/скрыть окно |
| Esc | вернуться к сеансу |

F12 перехватывается киоском глобально, поэтому внутри удалённого сеанса эта клавиша приложениям не передаётся (используйте другие приложения/сочетания или меню).

Переключение раскладки RU/EN: **CapsLock** (вариант: Win+Пробел). Alt+Shift и Ctrl+Shift не используются: они входят в горячие клавиши киоска.

## Меню загрузчика
Скрыто. Нажмите Esc или Shift при старте: обычная загрузка, установка на ПК, безопасный графический режим (nomodeset), подробный лог.

## Где хранятся данные и безопасность
- Профили: `/data/kiosk/config.json` на разделе `KIOSKDATA` флешки (права 600). **Пароли хранятся открытым текстом**
  и флешка не шифруется: храните её как ключ. Если пароль не сохранён в профиле, при подключении по RDP он спрашивается.
- Сеть: профили NetworkManager и `/etc/netplan` лежат на том же разделе.
- По умолчанию сертификат RDP-сервера не проверяется (опция «Не проверять сертификат» в профиле).
- Всё, что система пишет в процессе работы, живёт в оперативной памяти и пропадает при выключении, кроме раздела данных.

## Что проверено
Проверено в QEMU: загрузка BIOS, UEFI с Secure Boot, VHD (BIOS); VNC- и RDP-сеансы; горячие клавиши во время сеанса;
DHCP и статический IP с сохранением после перезагрузки; сохранение профилей; расширение раздела данных.
Установка на диск: BIOS и UEFI с Secure Boot, загрузка установленной системы (в том числе при оставленной флешке), перенос настроек.
**Не проверено на реальном железе:** установка на реальные диски (SATA/NVMe), Wi-Fi, проброс USB, несколько мониторов, звук, запуск VHD в Hyper-V и VirtualBox.
Если что-то не работает, откройте issue с описанием компьютера (модель, видео, Wi-Fi-адаптер).

## Сборка самостоятельно
Нужны Ubuntu 24.04 (подойдёт виртуальная машина или WSL2), root, интернет и ~8 ГБ места, около 10–15 минут.

    sudo sh thin-client-build.sh ./out        # -> out/thin-client.img и out/thin-client.vhd

Или из исходников репозитория: `sudo sh build-all.sh ./out`. Скрипты не используют loop-устройства.
Состав: `build-rootfs.sh` (Ubuntu 24.04 + ядро HWE + Xorg/openbox + FreeRDP 3 + TigerVNC + NetworkManager, корень в squashfs),
`build-image.sh` (разметка, BIOS- и UEFI-загрузчики), `overlay/` (приложение `opt/kiosk/kiosk.py`, службы systemd, настройки),
`boot/` (grub.cfg), `test/` (запуск в QEMU, тестовые VNC/RDP-серверы).

## VNC: масштаб, курсор, клиенты
- **TigerVNC** (`xtigervncviewer`): шифрование TLS, несколько мониторов, подстройка разрешения сервера. Локального масштабирования и режимов курсора нет; «Как есть» отключает подстройку разрешения сервера.
- **SSVNC** (`ssvncviewer`, на базе TightVNC): масштаб «Вписать», «Растянуть», проценты; все режимы курсора. **Ограничения:** нет TLS/RA2, только пароль VNC или без пароля; нет нескольких мониторов.
- Клиент «Авто»: SSVNC, если выбран масштаб (кроме «Авто» и «Как есть») или режим курсора не «Авто», иначе TigerVNC. Размер экрана сервера определяется отдельным запросом (RFB), поэтому при неверном пароле или недоступном сервере «Вписать» работает как обычный полноэкранный режим без масштаба.
- При ошибке пароля повторные попытки не выполняются, показывается сообщение. Журнал клиента: вкладка «Система» → «Журнал и сведения о системе».
- Точное сопоставление координат мыши при масштабировании на реальном железе не проверялось (проверено в QEMU).

## История изменений
- **1.5** — VNC: выбор режима курсора и клиента (TigerVNC / SSVNC), масштабирование изображения (вписать / растянуть / 1:1 / проценты), то же для RDP. Исправлено: бесконечные повторы при неверном пароле, флаг буфера обмена VNC, уникальное имя хоста (`thin-<mac>`), синхронизация времени (NTP), диалог «Журнал» на вкладке «Система», F12 работает и поверх SSVNC, команда `reload` для горячей перезагрузки настроек.
- **1.4** — пункт «Установка на ПК» в меню загрузчика: установка системы на внутренний диск (BIOS и UEFI, с переносом настроек и проверкой копии).
  Меню загрузчика стало графическим (с кириллицей в BIOS); если рядом стоят флешка и установленный диск с одинаковыми метками, система берёт свой раздел данных.
- **1.3** — добавлена горячая клавиша **F12**: открывает меню настроек, повторное нажатие возвращает к сеансу.
- **1.2** — исправлено: горячие клавиши не работали (например, в VirtualBox). Раскладка по умолчанию переключалась по Alt+Shift,
  а эти клавиши входят в Ctrl+Alt+Shift. Теперь раскладка переключается по **CapsLock** (или Win+Пробел), выбор — на вкладке «Система».
  Старые настройки с Alt+Shift / Ctrl+Shift автоматически заменяются на CapsLock.
  Мышь в VNC: программный курсор в X-сервере (на виртуальных видеокартах аппаратный курсор бывает невидим) и точка вместо невидимого
  курсора сервера (`DotWhenNoCursor`).
- **1.1** — исправлено: настройки сети (статический IP, Wi-Fi) не сохранялись после перезагрузки. Ubuntu NetworkManager хранит
  новые подключения в `/etc/netplan`, а он находился в RAM; теперь лежит на разделе с данными. Вкладка «Сеть» показывает сохранённые
  значения; профиль не привязан к имени сетевой карты (работает и на другом компьютере).
- **1.0** — первая версия.

---

## English summary
Bootable USB thin client (Ubuntu 24.04, x86_64, BIOS + UEFI/Secure Boot) that connects straight to an RDP or VNC server at
boot; kiosk mode, settings window via hotkeys (F12 or Ctrl+Alt+Shift+S/N/P/R/D/Space), "Install to PC" entry in the boot menu (Esc at start) copies the system to an internal disk, Ethernet/Wi-Fi/static IP, audio, clipboard,
USB redirection, multi-monitor, Russian/English UI. VNC: choice of client (TigerVNC / SSVNC), mouse cursor mode and image scaling (fit / stretch / 1:1 / percent). Settings are stored on the flash drive (`KIOSKDATA` partition).
Download `thin-client.img` from the [latest release](https://github.com/Nikolay-Tob/thin-client/releases/latest) and write it with
Rufus/balenaEtcher (DD mode) or `dd`. Build it yourself with `sudo sh thin-client-build.sh ./out`.
__KIT_EOF__
mkdir -p "$DEST/boot"
cat > "$DEST/boot/early.cfg" <<'__KIT_EOF__'
if ! [ -f ($root)/boot/grub/grub.cfg ]; then
    search --no-floppy --label --set=root KIOSKBOOT
fi
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
__KIT_EOF__
mkdir -p "$DEST/boot"
cat > "$DEST/boot/grub.cfg" <<'__KIT_EOF__'
# Thin client boot menu (hidden: press Esc/Shift during boot to show it)
set timeout_style=hidden
set timeout=1
set default=0
# Use the disk we were started from; search by label only if the kernel is not here
# (so a flash drive left plugged in next to an installed disk does not confuse the loader).
if ! [ -f ($root)/boot/vmlinuz ]; then
    search --no-floppy --label --set=root KIOSKBOOT
fi

# Graphical menu with a Unicode font (Cyrillic titles). Under UEFI Secure Boot GRUB refuses to load a font
# file ("prohibited by secure boot policy"): then the menu stays in plain text mode with an ASCII title.
set cyr=0
if loadfont ($root)/boot/grub/unicode.pf2; then
    set cyr=1
    set gfxmode=auto
    set gfxpayload=keep
    insmod all_video
    insmod gfxterm
    if terminal_output gfxterm; then true; else terminal_output console; fi
fi
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Thin client" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet loglevel=3 vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
#INSTALL-BEGIN
if [ "$cyr" = 1 ]; then set install_title="Установка на ПК (Install to PC)"; else set install_title="Install to PC"; fi
menuentry "$install_title" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 kiosk.install=1 quiet loglevel=3 vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
#INSTALL-END
menuentry "Thin client (safe graphics, nomodeset)" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet loglevel=3 nomodeset vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
menuentry "Thin client (verbose boot log)" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 loglevel=7 usbcore.autosuspend=-1 console=tty0
    initrd /boot/initrd.img
}
__KIT_EOF__
cat > "$DEST/build-all.sh" <<'__KIT_EOF__'
#!/bin/sh
# One command: builds thin-client.img (flash drive, BIOS+UEFI/Secure Boot) and thin-client.vhd (BIOS VMs).
# Needs: Ubuntu 24.04 (a VM or WSL2 is fine), root, internet, ~8 GB free disk. Takes ~10-15 minutes.
# Usage: sudo ./build-all.sh [output-dir]      (default: ./out)
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUTDIR=$(mkdir -p "${1:-./out}" && cd "${1:-./out}" && pwd)
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
export OUT=${OUT:-$OUTDIR/work}
export R=${R:-$OUT/rootfs}
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$OUT"
echo "== host packages"
apt-get update -qq || true
apt-get install -y -qq debootstrap qemu-utils dosfstools e2fsprogs squashfs-tools grub-pc-bin grub-efi-amd64-bin \
    grub-common mtools fdisk shim-signed grub-efi-amd64-signed zstd python3
sh "$KIT/build-rootfs.sh"
sh "$KIT/build-image.sh"
cp "$OUT/build/disk.img" "$OUTDIR/thin-client.img"
echo "== VHD (dynamic, 4 GiB virtual size; the data partition grows to fill it on first boot)"
cp "$OUT/build/disk.img" "$OUT/build/vhd-src.img"
truncate -s 4096M "$OUT/build/vhd-src.img"
qemu-img convert -f raw -O vpc -o subformat=dynamic,force_size=on "$OUT/build/vhd-src.img" "$OUTDIR/thin-client.vhd"
rm -f "$OUT/build/vhd-src.img"
ls -lh "$OUTDIR/thin-client.img" "$OUTDIR/thin-client.vhd"
echo "DONE: $OUTDIR/thin-client.img  $OUTDIR/thin-client.vhd   (you can delete $OUT to free space)"
__KIT_EOF__
cat > "$DEST/build-image.sh" <<'__KIT_EOF__'
#!/bin/sh
# Assemble the bootable disk image from root.sqsh + boot files: BIOS (embedded GRUB) and UEFI (signed shim/GRUB, Secure Boot).
# Layout: MBR; p1 ESP FAT32 "KIOSKBOOT" (128M), p2 squashfs root, p3 ext4 "KIOSKDATA" (grows to fill the device on first boot).
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/work}
W=$OUT/build; mkdir -p "$W"; cd "$W"
rm -f disk.img esp.img data.img core.img
ESP_MIB=128; DATA_MIB=128
ROOT_BYTES=$(stat -c %s "$OUT/root.sqsh"); ROOT_MIB=$(( (ROOT_BYTES + 1048575) / 1048576 ))
TOTAL_MIB=$((1 + ESP_MIB + ROOT_MIB + DATA_MIB))
echo "root=${ROOT_MIB}MiB total=${TOTAL_MIB}MiB"

# --- ESP: signed shim + GRUB (UEFI / Secure Boot), grub.cfg, kernel, initrd
truncate -s ${ESP_MIB}M esp.img
mkfs.vfat -F 32 -n KIOSKBOOT esp.img >/dev/null
mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/ubuntu ::/boot ::/boot/grub ::/boot/grub/fonts
mcopy -i esp.img /usr/lib/shim/shimx64.efi.signed ::/EFI/BOOT/BOOTX64.EFI
mcopy -i esp.img /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed ::/EFI/BOOT/grubx64.efi
mcopy -i esp.img /usr/lib/shim/mmx64.efi ::/EFI/BOOT/mmx64.efi
for d in boot/grub EFI/BOOT EFI/ubuntu; do mcopy -i esp.img "$KIT/boot/grub.cfg" ::/$d/grub.cfg; done
mcopy -i esp.img /usr/share/grub/unicode.pf2 ::/boot/grub/unicode.pf2
mcopy -i esp.img "$OUT/bootfiles/vmlinuz" ::/boot/vmlinuz
mcopy -i esp.img "$OUT/bootfiles/initrd.img" ::/boot/initrd.img

# --- data partition (ext4)
rm -rf dd; mkdir -p dd/kiosk dd/nm
chown 1000:1000 dd/kiosk; chmod 700 dd/kiosk; chown 0:0 dd/nm; chmod 755 dd/nm
mke2fs -q -t ext4 -L KIOSKDATA -E root_owner=0:0 -d dd data.img ${DATA_MIB}M

# --- disk with MBR; disk id 4b50d0c1 makes root=PARTUUID=4b50d0c1-02
truncate -s ${TOTAL_MIB}M disk.img
sfdisk -q disk.img <<EOF
label: dos
label-id: 0x4b50d0c1
unit: sectors

start=2048, size=$((ESP_MIB*2048)), type=ef, bootable
start=$((2048+ESP_MIB*2048)), size=$((ROOT_MIB*2048)), type=83
start=$((2048+ESP_MIB*2048+ROOT_MIB*2048)), size=$((DATA_MIB*2048)), type=83
EOF
dd if=esp.img of=disk.img bs=1M seek=1 conv=notrunc status=none
dd if="$OUT/root.sqsh" of=disk.img bs=1M seek=$((1+ESP_MIB)) conv=notrunc status=none
dd if=data.img of=disk.img bs=1M seek=$((1+ESP_MIB+ROOT_MIB)) conv=notrunc status=none

# --- BIOS GRUB: core.img written straight into the gap after the MBR (no loop devices needed)
grub-mkimage -d /usr/lib/grub/i386-pc -O i386-pc -o core.img -c "$KIT/boot/early.cfg" -p '(hd0,msdos1)/boot/grub' \
  biosdisk part_msdos part_gpt fat ext2 normal configfile linux search search_label search_fs_uuid echo test ls cat boot gzio minicmd \
  font gfxterm all_video video video_fb loadenv terminal
python3 - "$W/disk.img" "$W/core.img" <<'PY'
import struct, sys
disk, corep = sys.argv[1:3]
boot = bytearray(open('/usr/lib/grub/i386-pc/boot.img', 'rb').read())
core = bytearray(open(corep, 'rb').read())
nsec = (len(core) + 511) // 512
assert nsec < 2000, nsec
core += b'\0' * (nsec * 512 - len(core))
struct.pack_into('<Q', boot, 0x5c, 1)                         # core.img starts at LBA 1
struct.pack_into('<QHH', core, 512 - 12, 2, nsec - 1, 0x820)  # blocklist: the rest of core.img
with open(disk, 'r+b') as f:
    mbr = f.read(512)
    f.seek(0); f.write(bytes(boot[:440]) + mbr[440:512])      # keep disk id + partition table
    f.seek(512); f.write(core)
print("BIOS grub embedded: core", nsec, "sectors")
PY
echo BUILD_OK; ls -lh disk.img
__KIT_EOF__
cat > "$DEST/build-rootfs.sh" <<'__KIT_EOF__'
#!/bin/sh
# Build the thin-client root filesystem (Ubuntu 24.04 noble) -> $OUT/root.sqsh and $OUT/bootfiles/{vmlinuz,initrd.img}
# Resumable: finished stages are recorded in $OUT/stamps. Needs root and network access to archive.ubuntu.com.
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/work}
R=${R:-/srv/rootfs}
export DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
mkdir -p "$OUT/stamps" "$OUT/cache" "$OUT/bootfiles"
log() { echo "== $(date +%T) $*"; }
stage() { [ -f "$OUT/stamps/$1" ]; }
done_stage() { touch "$OUT/stamps/$1"; }
mounts() { mountpoint -q $R/proc || mount -t proc proc $R/proc; mountpoint -q $R/sys || mount -t sysfs sys $R/sys
           mountpoint -q $R/dev || mount --bind /dev $R/dev; mountpoint -q $R/dev/pts || mount -t devpts devpts $R/dev/pts; }
umounts() { for m in dev/pts dev sys proc; do umount $R/$m 2>/dev/null || true; done; }
trap umounts EXIT

if ! stage s1-debootstrap; then
    log debootstrap
    rm -rf "$R"; mkdir -p "$R"
    debootstrap --variant=minbase --arch=amd64 --components=main,universe --cache-dir="$OUT/cache" noble "$R" http://archive.ubuntu.com/ubuntu
    done_stage s1-debootstrap
fi

if ! stage s2-packages; then
    log chroot-setup
    mounts
    cp /etc/resolv.conf $R/etc/resolv.conf
    rm -f $R/etc/apt/sources.list
    cat > $R/etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\nAcquire::Languages "none";\n' > $R/etc/apt/apt.conf.d/99kiosk
    chroot $R apt-get update -qq
    log base-packages
    chroot $R apt-get install -y -qq overlayroot initramfs-tools zstd
    sed -i 's/^COMPRESS=.*/COMPRESS=zstd/; s/^MODULES=.*/MODULES=most/' $R/etc/initramfs-tools/initramfs.conf
    KVER=$(chroot $R apt-cache depends linux-image-generic-hwe-24.04 | awk '$1=="Depends:" && $2 ~ /^linux-image-[0-9]/ {sub("linux-image-","",$2); print $2; exit}')
    echo "$KVER" > "$OUT/stamps/kver"
    log "kernel $KVER"
    chroot $R apt-get install -y -qq linux-image-$KVER linux-modules-$KVER linux-firmware intel-microcode amd64-microcode
    log desktop-packages
    chroot $R apt-get install -y -qq systemd systemd-sysv udev dbus libpam-systemd polkitd network-manager wpasupplicant iw rfkill \
        wireless-regdb ca-certificates iproute2 kmod pciutils usbutils fdisk xserver-xorg-core xserver-xorg-input-libinput \
        xserver-xorg-video-fbdev xinit x11-xserver-utils x11-xkb-utils xkb-data openbox python3 python3-gi gir1.2-gtk-3.0 \
        python3-cryptography fonts-dejavu-core adwaita-icon-theme librsvg2-common freerdp3-x11 tigervnc-viewer pulseaudio \
        pulseaudio-utils alsa-utils tzdata
    done_stage s2-packages
fi

if ! stage s3-configure; then
    log configure
    mounts
    cp -a "$KIT/overlay/." $R/
    chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/installer.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata $R/usr/local/sbin/kiosk-install
    for g in audio video plugdev input render; do chroot $R getent group $g >/dev/null || chroot $R groupadd -r $g; done
    chroot $R id kiosk >/dev/null 2>&1 || chroot $R useradd -m -u 1000 -s /bin/bash -G audio,video,plugdev,input,render kiosk
    chroot $R systemctl enable kiosk.service kiosk-growdata.service NetworkManager.service
    chroot $R systemctl set-default multi-user.target
    chroot $R systemctl mask getty@.service autovt@.service NetworkManager-wait-online.service apt-daily.timer \
        apt-daily-upgrade.timer motd-news.timer e2scrub_all.timer fstrim.timer systemd-remount-fs.service 2>&1 | tail -2
    printf '127.0.0.1 localhost\n127.0.1.1 kiosk\n' > $R/etc/hosts
    ln -sf /usr/share/zoneinfo/UTC $R/etc/localtime; echo UTC > $R/etc/timezone
    mkdir -p $R/data $R/etc/NetworkManager/system-connections
    printf 'LANG=C.UTF-8\n' > $R/etc/default/locale
    log initramfs
    chroot $R update-initramfs -u -k all
    done_stage s3-configure
fi

if ! stage s4-prune; then
    log prune
    mounts
    KVER=$(cat "$OUT/stamps/kver")
    cp $R/boot/vmlinuz-$KVER "$OUT/bootfiles/vmlinuz"
    cp $R/boot/initrd.img-$KVER "$OUT/bootfiles/initrd.img"
    # software-only graphics: drop Mesa/LLVM and Ghostscript (huge, pulled in as library dependencies)
    PK=$(chroot $R dpkg-query -W -f='${Package}\n' 'libllvm*' mesa-libgallium libgl1-mesa-dri 'libgs10*' libgs-common poppler-data libspectre1 2>/dev/null | tr '\n' ' ')
    [ -n "$PK" ] && chroot $R dpkg --force-depends -r $PK 2>&1 | tail -3 || true
    rm -f $R/usr/lib/x86_64-linux-gnu/imlib2/loaders/ps.so
    (cd $R/usr/lib/firmware && rm -rf mellanox netronome qed dpaa2 cxgb4 bnx2x liquidio nvidia qcom mrvl/prestera)
    chroot $R apt-get clean
    rm -rf $R/boot/* $R/usr/share/man $R/usr/share/info $R/usr/share/lintian $R/usr/share/doc-base
    find $R/usr/share/doc -type f ! -name copyright -delete; find $R/usr/share/doc -type d -empty -delete 2>/dev/null || true
    find $R/usr/share/locale -mindepth 1 -maxdepth 1 ! -name locale.alias -exec rm -rf {} +
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/var/cache/debconf/*-old $R/var/lib/dpkg/*-old $R/tmp/* $R/root/.cache 2>/dev/null || true
    find $R/var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    : > $R/etc/machine-id; rm -f $R/var/lib/dbus/machine-id; ln -sf /etc/machine-id $R/var/lib/dbus/machine-id
    done_stage s4-prune
fi

# installer needs efibootmgr (UEFI boot entry); added as a separate stage so existing rootfs caches stay usable
if ! stage s5-installer; then
    log installer-packages
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    chroot $R apt-get update -qq
    # apt refuses to install while the pruned Mesa/LLVM packages are 'broken': fetch the .debs and use dpkg
    chroot $R sh -c 'cd /tmp && apt-get download efibootmgr libefiboot1t64 libefivar1t64 libpopt0 && dpkg -i --force-depends /tmp/*.deb && rm -f /tmp/*.deb'
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/efibootmgr 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s5-installer
fi

# SSVNC viewer (local scaling, cursor modes) and NTP client; fetched as .debs (apt refuses to install into the pruned tree)
if ! stage s6-extras; then
    log extras
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    chroot $R apt-get update -qq
    chroot $R sh -c 'cd /tmp && apt-get download ssvnc systemd-timesyncd && dpkg -i --force-depends /tmp/systemd-timesyncd_*.deb \
        && mkdir -p /tmp/ssvnc-x && dpkg-deb -x /tmp/ssvnc_*.deb /tmp/ssvnc-x \
        && install -D -m 755 /tmp/ssvnc-x/usr/lib/ssvnc/vncviewer /opt/ssvnc/ssvncviewer \
        && install -D -m 644 /tmp/ssvnc-x/usr/share/doc/ssvnc/copyright /opt/ssvnc/copyright \
        && rm -rf /tmp/*.deb /tmp/ssvnc-x'
    chroot $R systemctl enable systemd-timesyncd.service
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/systemd-timesyncd 2>/dev/null || true
    rm -f $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s6-extras
fi

# always refresh our own files (cheap, idempotent) so edits to overlay/ end up in the image
cp -a "$KIT/overlay/." $R/
chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/installer.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata $R/usr/local/sbin/kiosk-install
umounts
log squashfs
rm -f "$OUT/root.sqsh"
mksquashfs $R "$OUT/root.sqsh" -comp zstd -Xcompression-level 12 -b 256K -noappend -no-xattrs -quiet
ls -lh "$OUT/root.sqsh"
echo ROOTFS_DONE
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
: > "$DEST/overlay/etc/NetworkManager/conf.d/10-dns-resolved.conf"
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
: > "$DEST/overlay/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
cat > "$DEST/overlay/etc/NetworkManager/conf.d/kiosk.conf" <<'__KIT_EOF__'
[main]
plugins=keyfile
dns=default
[device]
wifi.scan-rand-mac-address=no
[connectivity]
enabled=false
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/X11/xorg.conf.d"
cat > "$DEST/overlay/etc/X11/xorg.conf.d/10-kiosk.conf" <<'__KIT_EOF__'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZap" "true"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection

# Software mouse cursor: the hardware cursor is invisible on some virtual GPUs (VirtualBox VMSVGA, VMware, ...)
Section "OutputClass"
    Identifier "kiosk-swcursor"
    Driver "modesetting"
    Option "SWcursor" "true"
EndSection
__KIT_EOF__
mkdir -p "$DEST/overlay/etc"
cat > "$DEST/overlay/etc/fstab" <<'__KIT_EOF__'
# Root is a read-only squashfs with a RAM overlay (overlayroot).
# The persistent data partition (LABEL=KIOSKDATA) is mounted on /data by kiosk-growdata.service.
__KIT_EOF__
mkdir -p "$DEST/overlay/etc"
cat > "$DEST/overlay/etc/hostname" <<'__KIT_EOF__'
kiosk
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/polkit-1/rules.d"
cat > "$DEST/overlay/etc/polkit-1/rules.d/50-kiosk-install.rules" <<'__KIT_EOF__'
// The installer GUI (user kiosk, only in the "Install to PC" boot mode) starts kiosk-install@<disk>.service.
polkit.addRule(function(action, subject) {
    if (subject.user == "kiosk" &&
        action.id.indexOf("org.freedesktop.systemd1.manage-units") == 0 &&
        action.lookup("unit") && action.lookup("unit").indexOf("kiosk-install@") == 0) {
        return polkit.Result.YES;
    }
});
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/polkit-1/rules.d"
cat > "$DEST/overlay/etc/polkit-1/rules.d/50-kiosk.rules" <<'__KIT_EOF__'
polkit.addRule(function(action, subject) {
    if (subject.user == "kiosk" &&
        (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 ||
         action.id.indexOf("org.freedesktop.login1.") == 0)) {
        return polkit.Result.YES;
    }
});
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/sysctl.d"
cat > "$DEST/overlay/etc/sysctl.d/90-kiosk.conf" <<'__KIT_EOF__'
kernel.sysrq = 0
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/journald.conf.d"
cat > "$DEST/overlay/etc/systemd/journald.conf.d/kiosk.conf" <<'__KIT_EOF__'
[Journal]
Storage=volatile
RuntimeMaxUse=16M
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/logind.conf.d"
cat > "$DEST/overlay/etc/systemd/logind.conf.d/kiosk.conf" <<'__KIT_EOF__'
[Login]
NAutoVTs=0
ReserveVT=0
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleLidSwitch=ignore
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system/NetworkManager.service.d"
cat > "$DEST/overlay/etc/systemd/system/NetworkManager.service.d/kiosk.conf" <<'__KIT_EOF__'
[Unit]
After=kiosk-growdata.service
Wants=kiosk-growdata.service
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system"
cat > "$DEST/overlay/etc/systemd/system/kiosk-growdata.service" <<'__KIT_EOF__'
[Unit]
Description=Prepare persistent data partition (grow, check, mount)
After=systemd-udevd.service systemd-udev-trigger.service local-fs.target
Before=NetworkManager.service kiosk.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/kiosk-growdata
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system"
cat > "$DEST/overlay/etc/systemd/system/kiosk-install@.service" <<'__KIT_EOF__'
[Unit]
Description=Install the thin client onto an internal disk (%i)
ConditionKernelCommandLine=kiosk.install=1

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/kiosk-install unit %i
StandardOutput=truncate:/run/kiosk-install.log
StandardError=inherit
TimeoutStartSec=infinity
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system"
cat > "$DEST/overlay/etc/systemd/system/kiosk.service" <<'__KIT_EOF__'
[Unit]
Description=Thin client kiosk session (Xorg + launcher)
After=systemd-user-sessions.service systemd-logind.service kiosk-growdata.service NetworkManager.service
Wants=kiosk-growdata.service
Wants=NetworkManager.service

[Service]
User=kiosk
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/usr/bin/xinit /opt/kiosk/session.sh -- /usr/bin/Xorg :0 vt1 -keeptty -nolisten tcp -noreset
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/udev/rules.d"
cat > "$DEST/overlay/etc/udev/rules.d/90-kiosk-usb.rules" <<'__KIT_EOF__'
# allow the kiosk user to redirect any USB device into the remote session
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0666"
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/installer.py" <<'__KIT_EOF__'
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
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/kiosk.py" <<'__KIT_EOF__'
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

VERSION = "1.5"


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
SSVNC = "/opt/ssvnc/ssvncviewer"   # TightVNC-based viewer: local scaling and cursor modes (TigerVNC has neither)
VNC_PASS = "/tmp/kiosk-vncpass"
# one saved NetworkManager profile per link type, not bound to an interface name
# (interface names differ between computers the flash drive is moved to)
NM_PROFILE = {"ethernet": "kiosk-ethernet", "wifi": "kiosk-wifi"}

# NB: layout switching must not use Alt+Shift or Ctrl+Shift: those combinations are part of the
# Ctrl+Alt+Shift hotkeys, and X switches the group before the hotkey letter arrives, so the hotkey is lost.
KEYBOARDS = [
    ("us", "English (US)", ["us"], None),
    ("us-ru-caps", "English + Русская (CapsLock)", ["us,ru"], "grp:caps_toggle"),
    ("us-ru-win", "English + Русская (Win+Пробел)", ["us,ru"], "grp:win_space_toggle"),
]
OLD_KEYBOARD_IDS = {"us-ru-alt": "us-ru-caps", "us-ru-ctrl": "us-ru-caps"}

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
            "F12 — открыть/скрыть меню настроек\n"
            "Ctrl+Alt+Shift+S — окно настроек и профилей\n"
            "Ctrl+Alt+Shift+N — сетевые настройки\n"
            "Ctrl+Alt+Shift+P — питание и система\n"
            "Ctrl+Alt+Shift+R — переподключиться\n"
            "Ctrl+Alt+Shift+D — отключиться\n"
            "Ctrl+Alt+Shift+Пробел — показать/скрыть это окно\n"
            "Esc — вернуться к сеансу"),
        "version": "Версия {}",
        "scale": "Масштаб изображения", "cursor": "Курсор мыши (VNC)", "vncclient": "Клиент VNC",
        "sc_auto_vnc": "Авто (разрешение сервера под экран, если сервер умеет)",
        "sc_fit": "Вписать в экран (с сохранением пропорций)", "sc_stretch": "Растянуть на весь экран",
        "sc_original": "Как есть (1:1)",
        "sc_z50": "Масштаб 50 %", "sc_z75": "Масштаб 75 %", "sc_z125": "Масштаб 125 %",
        "sc_z150": "Масштаб 150 %", "sc_z200": "Масштаб 200 %",
        "sc_auto_rdp": "Авто (разрешение под экран)",
        "sc_stretch_rdp": "Растянуть: размер из профиля на весь экран",
        "sc_original_rdp": "Как есть: размер из профиля, без масштаба",
        "sc_ui125": "Крупнее интерфейс Windows 125 %", "sc_ui150": "Крупнее интерфейс Windows 150 %",
        "sc_ui200": "Крупнее интерфейс Windows 200 %",
        "cur_auto": "Авто (курсор сервера, точка если его нет)",
        "cur_x11": "Форма курсора с сервера (курсор X11)",
        "cur_remote": "Курсор рисует сервер (в картинке)",
        "cur_arrow": "Локальная стрелка + курсор сервера",
        "cl_auto": "Авто", "cl_tiger": "TigerVNC (TLS/RA2, несколько мониторов)",
        "cl_ssvnc": "SSVNC (масштаб, выбор курсора; без TLS)",
        "hint_tiger": "Клиент: TigerVNC.", "hint_ssvnc": "Клиент: SSVNC (масштабирование и режимы курсора; без шифрования TLS, только пароль VNC).",
        "hint_noscale": "TigerVNC не масштабирует картинку: выберите «Авто» или «Как есть», либо клиент SSVNC.",
        "log_btn": "Журнал и сведения о системе", "close": "Закрыть",
        "status_authfail": "Ошибка входа: проверьте логин и пароль. Автоповтор отключён. {}",
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
            "F12 — open/hide the settings menu\n"
            "Ctrl+Alt+Shift+S — settings and profiles\n"
            "Ctrl+Alt+Shift+N — network settings\n"
            "Ctrl+Alt+Shift+P — power and system\n"
            "Ctrl+Alt+Shift+R — reconnect\n"
            "Ctrl+Alt+Shift+D — disconnect\n"
            "Ctrl+Alt+Shift+Space — show/hide this window\n"
            "Esc — back to the session"),
        "version": "Version {}",
        "scale": "Image scaling", "cursor": "Mouse cursor (VNC)", "vncclient": "VNC client",
        "sc_auto_vnc": "Auto (server resolution follows the screen if supported)",
        "sc_fit": "Fit to screen (keep aspect ratio)", "sc_stretch": "Stretch to the whole screen",
        "sc_original": "As is (1:1)",
        "sc_z50": "Zoom 50 %", "sc_z75": "Zoom 75 %", "sc_z125": "Zoom 125 %",
        "sc_z150": "Zoom 150 %", "sc_z200": "Zoom 200 %",
        "sc_auto_rdp": "Auto (resolution follows the screen)",
        "sc_stretch_rdp": "Stretch: profile size scaled to the whole screen",
        "sc_original_rdp": "As is: profile size, no scaling",
        "sc_ui125": "Larger Windows UI 125 %", "sc_ui150": "Larger Windows UI 150 %",
        "sc_ui200": "Larger Windows UI 200 %",
        "cur_auto": "Auto (server cursor, a dot if there is none)",
        "cur_x11": "Cursor shape from the server (X11 cursor)",
        "cur_remote": "Server draws the cursor (in the picture)",
        "cur_arrow": "Local arrow + server cursor",
        "cl_auto": "Auto", "cl_tiger": "TigerVNC (TLS/RA2, multi-monitor)",
        "cl_ssvnc": "SSVNC (scaling, cursor modes; no TLS)",
        "hint_tiger": "Client: TigerVNC.", "hint_ssvnc": "Client: SSVNC (scaling and cursor modes; no TLS encryption, VNC password only).",
        "hint_noscale": "TigerVNC cannot scale the picture: pick “Auto” or “As is”, or the SSVNC client.",
        "log_btn": "Log and system information", "close": "Close",
        "status_authfail": "Login failed: check the user name and password. Auto-retry is off. {}",
    },
}

DEFAULT_PROFILE = {
    "name": "", "proto": "rdp", "host": "", "port": "", "user": "", "password": "",
    "domain": "", "fullscreen": True, "multimon": False, "width": 1920, "height": 1080,
    "sound": True, "clipboard": True, "usb": False, "ignorecert": True, "extra": "",
    "scale": "auto", "cursor": "auto", "vncclient": "auto",
}

# scale modes per protocol: (id, translation key)
SCALES_VNC = [("auto", "sc_auto_vnc"), ("fit", "sc_fit"), ("stretch", "sc_stretch"), ("original", "sc_original"),
              ("z50", "sc_z50"), ("z75", "sc_z75"), ("z125", "sc_z125"), ("z150", "sc_z150"), ("z200", "sc_z200")]
SCALES_RDP = [("auto", "sc_auto_rdp"), ("stretch", "sc_stretch_rdp"), ("original", "sc_original_rdp"),
              ("ui125", "sc_ui125"), ("ui150", "sc_ui150"), ("ui200", "sc_ui200")]
CURSORS = [("auto", "cur_auto"), ("x11", "cur_x11"), ("remote", "cur_remote"), ("arrow", "cur_arrow")]
VNC_CLIENTS = [("auto", "cl_auto"), ("tiger", "cl_tiger"), ("ssvnc", "cl_ssvnc")]
# the client printed one of these: wrong login/password, do not hammer the server with retries (account lockout)
AUTH_FAIL_RE = re.compile(r"(LOGON_FAILURE|ACCESS_DENIED|ACCOUNT_LOCKED|WRONG_PASSWORD|PASSWORD_EXPIRED|PASSWORD_MUST_CHANGE|"
                          r"ACCOUNT_DISABLED|AUTHENTICATION_FAILED|Authentication (failed|failure)|"
                          r"authentication failed|SecurityResult.*(failed|failure))", re.I)


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


def _vnc_des(password, data):
    """DES-ECB with the VNC password as key (each key byte bit-reversed): the VNC auth response and password file."""
    from cryptography.hazmat.primitives.ciphers import Cipher, modes
    try:
        from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
    except ImportError:
        from cryptography.hazmat.primitives.ciphers.algorithms import TripleDES
    key = bytes(int("{:08b}".format(b)[::-1], 2) for b in password.ljust(8, b"\0")[:8])
    enc = Cipher(TripleDES(key * 3), modes.ECB()).encryptor()
    return enc.update(data) + enc.finalize()


def vnc_obfuscate(password):
    """VNC password file contents (DES with the fixed, bit-reversed key)."""
    pw = password.encode("latin-1", "replace")[:8].ljust(8, b"\0")
    return _vnc_des(bytes((23, 82, 107, 6, 35, 78, 88, 7)), pw)


def rfb_probe(host, port, password, timeout=3.0):
    """Ask a VNC server for its desktop size (RFB handshake only). Returns (w, h) or None."""
    import struct

    def recvn(sock, n):
        buf = b""
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise OSError("closed")
            buf += chunk
        return buf

    s = None
    try:
        s = socket.create_connection((host, int(port) if port else 5900), timeout)
        s.settimeout(timeout)
        ver = recvn(s, 12)
        if ver[:7] != b"RFB 003" or ver[8:11] == b"003":   # RFB 3.3 has no security type list: not supported here
            return None
        s.sendall(b"RFB 003.008\n")
        n = recvn(s, 1)[0]
        if n == 0:
            return None
        types = recvn(s, n)
        if 1 in types:
            s.sendall(b"\x01")
        elif 2 in types and password:
            s.sendall(b"\x02")
            chal = recvn(s, 16)
            pw = password.encode("latin-1", "replace")
            s.sendall(_vnc_des(pw, chal))
        else:
            return None
        if struct.unpack(">I", recvn(s, 4))[0] != 0:
            return None
        s.sendall(b"\x01")
        w, h = struct.unpack(">HH", recvn(s, 24)[:4])
        return (w, h) if w and h else None
    except (OSError, ValueError, struct.error):
        return None
    finally:
        if s is not None:
            try:
                s.close()
            except OSError:
                pass
        time.sleep(0.2)


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
                     "keyboard": "us-ru-caps", "profiles": []}
        self.load()

    def load(self):
        try:
            with open(CONF, "r", encoding="utf-8") as f:
                self.data.update(json.load(f))
        except Exception:  # noqa: BLE001
            pass
        kb = self.data.get("keyboard")
        if kb in OLD_KEYBOARD_IDS:  # Alt+Shift / Ctrl+Shift switching broke the hotkeys
            self.data["keyboard"] = OLD_KEYBOARD_IDS[kb]

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

        g = Gtk.Grid(column_spacing=10, row_spacing=4)
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
        for key, items in (("scale", []), ("cursor", CURSORS), ("vncclient", VNC_CLIENTS)):
            cb = Gtk.ComboBoxText()
            for ident, tkey in items:
                cb.append(ident, self._(tkey))
            cb.connect("changed", (lambda *a: self.on_proto_changed()) if key == "scale"
                       else (lambda *a: self.update_vnc_hint()))
            add_row(r, key, cb); r += 1
        self.vnc_hint = Gtk.Label(xalign=0)
        self.vnc_hint.set_line_wrap(True)
        g.attach(self.vnc_hint, 1, r, 3, 1)
        r += 1

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
        b3 = Gtk.Button(label=self._("log_btn"))
        b3.connect("clicked", lambda *a: self.show_log())
        pw.pack_end(b3, False, False, 0)
        box.pack_start(Gtk.Label(label=self._("power"), xalign=0), False, False, 0)
        box.pack_start(pw, False, False, 0)
        box.pack_end(Gtk.Label(label=self._("version", VERSION), xalign=0), False, False, 0)
        return box

    def system_info(self):
        sw, sh = self.screen_size()
        lines = ["Version: " + VERSION, "Kernel: " + os.uname().release,
                 "Firmware: " + ("UEFI" if os.path.isdir("/sys/firmware/efi") else "BIOS"),
                 "Screen: %dx%d" % (sw, sh),
                 "Root: " + (run(["findmnt", "-rn", "-o", "SOURCE", "/media/root-ro"], 3)[1].strip() or "?"),
                 "Data: " + (run(["findmnt", "-rn", "-o", "SOURCE", "/data"], 3)[1].strip() or "not mounted"),
                 "Time: " + time.strftime("%Y-%m-%d %H:%M:%S %Z"),
                 "NTP synchronized: " + run(["timedatectl", "show", "-p", "NTPSynchronized", "--value"], 3)[1].strip(),
                 "", run(["ip", "-br", "addr"], 3)[1].strip(), "", "--- client log ---"]
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                lines += [ln for ln in f.read().splitlines()[-60:]]
        except OSError:
            lines.append("(no client log yet)")
        return "\n".join(lines)

    def show_log(self):
        d = Gtk.Dialog(title=self._("log_btn"), transient_for=self.win, modal=True)
        d.add_button(self._("close"), Gtk.ResponseType.CLOSE)
        tv = Gtk.TextView()
        tv.set_editable(False)
        tv.set_monospace(True)
        tv.get_buffer().set_text(self.system_info())
        sw = Gtk.ScrolledWindow()
        sw.set_size_request(900, 520)
        sw.add(tv)
        d.get_content_area().add(sw)
        d.show_all()
        d.run()
        d.destroy()

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
        elif cmd == "menu":  # F12: open the settings, or hide them again during a session
            if self.win.get_visible() and self.running():
                self.hide_window()
            else:
                self.show_window(0)
        elif cmd == "reload":   # re-read config.json (edited by hand or by a script)
            self.cfg.load()
            self.reload_profiles()
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
        self.rebuild_scale(p.get("proto", "rdp"), p.get("scale", "auto"))
        f["cursor"].set_active_id(p.get("cursor", "auto") if p.get("cursor", "auto") in dict(CURSORS) else "auto")
        f["vncclient"].set_active_id(p.get("vncclient", "auto") if p.get("vncclient", "auto") in dict(VNC_CLIENTS) else "auto")
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
        p["scale"] = f["scale"].get_active_id() or "auto"
        p["cursor"] = f["cursor"].get_active_id() or "auto"
        p["vncclient"] = f["vncclient"].get_active_id() or "auto"
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
        proto = "rdp" if rdp else "vnc"
        if getattr(self, "scale_proto", None) != proto:
            self.rebuild_scale(proto, self.f["scale"].get_active_id() or "auto")
        # the picture size is the profile size when not fullscreen, or for scaled RDP modes
        scale = self.f["scale"].get_active_id() or "auto"
        size_used = (not fs) or (rdp and scale in ("stretch", "original"))
        self.f["size_box"].set_sensitive(size_used)
        self.f["size_label"].set_sensitive(size_used)
        self.f["multimon"].set_sensitive(fs)
        for key in ("cursor", "vncclient"):
            self.f[key].set_sensitive(not rdp)
            self.f[key + "_label"].set_sensitive(not rdp)
        self.update_vnc_hint()

    def rebuild_scale(self, proto, keep="auto"):
        """The list of scaling modes depends on the protocol."""
        cb = self.f["scale"]
        was = self.loading_form
        self.loading_form = True
        cb.remove_all()
        for ident, tkey in (SCALES_RDP if proto == "rdp" else SCALES_VNC):
            cb.append(ident, self._(tkey))
        if not cb.set_active_id(keep):
            cb.set_active_id("auto")
        self.scale_proto = proto
        self.loading_form = was

    def update_vnc_hint(self):
        if self.loading_form or "vnc_hint" not in self.__dict__:
            return
        if self.f["proto"].get_active_id() != "vnc":
            self.vnc_hint.set_text("")
            return
        p = {"proto": "vnc", "scale": self.f["scale"].get_active_id() or "auto",
             "cursor": self.f["cursor"].get_active_id() or "auto",
             "vncclient": self.f["vncclient"].get_active_id() or "auto"}
        eng = self.vnc_engine(p)
        text = self._("hint_ssvnc" if eng == "ssvnc" else "hint_tiger")
        if p["vncclient"] == "tiger" and (p["scale"] not in ("auto", "original") or p["cursor"] != "auto"):
            text = self._("hint_noscale")
        self.vnc_hint.set_markup("<small>%s</small>" % GLib.markup_escape_text(text))

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

    def screen_size(self):
        """Size of the primary monitor in pixels."""
        try:
            disp = Gdk.Display.get_default()
            mon = disp.get_primary_monitor() or disp.get_monitor(0)
            g = mon.get_geometry()
            return g.width, g.height
        except Exception:  # noqa: BLE001
            return 1920, 1080

    def vnc_engine(self, p):
        """TigerVNC by default; SSVNC when the profile needs local scaling or another cursor mode."""
        want = p.get("vncclient", "auto")
        if want in ("tiger", "ssvnc"):
            return want if want == "tiger" or os.path.exists(SSVNC) else "tiger"
        needs = p.get("scale", "auto") not in ("auto", "original") or p.get("cursor", "auto") != "auto"
        return "ssvnc" if needs and os.path.exists(SSVNC) else "tiger"

    def write_vnc_pass(self, password):
        fd = os.open(VNC_PASS, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(vnc_obfuscate(password))

    def ssvnc_scale(self, p, host, port):
        """-scale argument for SSVNC: it can only scale by a ratio or to a fixed size, so ask the server for its size."""
        mode = p.get("scale", "auto")
        if mode == "original":
            return None
        if mode.startswith("z") and mode[1:].isdigit():
            return "%.4f" % (int(mode[1:]) / 100.0)
        if p.get("fullscreen", True):
            sw, sh = self.screen_size()
        else:
            sw, sh = int(p.get("width", 1280)), int(p.get("height", 720))
        if mode == "stretch":
            return "%dx%d" % (sw, sh)
        size = rfb_probe(host, port, p.get("password", ""))    # "fit" / "auto": needs the remote desktop size
        if not size:
            return None
        return "%.4f" % min(sw / size[0], sh / size[1])

    def build_vnc_cmd(self, p, host, port):
        engine = self.vnc_engine(p)
        if engine == "ssvnc":
            cmd = [SSVNC, "-shared", "-noraiseonbeep", "-nograbkbd"]   # no keyboard grab: F12 and Ctrl+Alt+Shift hotkeys must reach openbox
            if p.get("fullscreen", True):
                cmd.append("-fullscreen")
            else:
                cmd += ["-geometry", "%dx%d+0+0" % (int(p.get("width", 1280)), int(p.get("height", 720)))]
            sc = self.ssvnc_scale(p, host, port)
            if sc:
                cmd += ["-scale", sc]
            cur = p.get("cursor", "auto")
            if cur == "remote":
                cmd.append("-nocursorshape")
            elif cur == "arrow":
                cmd += ["-nocursorshape", "-x11cursor"]
            elif cur == "x11":
                cmd.append("-x11cursor")
        else:
            cmd = ["xtigervncviewer", "-Shared"]
            if p.get("fullscreen", True):
                cmd.append("-FullScreen")
                if p.get("multimon"):
                    cmd.append("-FullScreenMode=All")
            # FullscreenSystemKeys=0: do not grab the keyboard, so the Ctrl+Alt+Shift hotkeys keep working
            # DotWhenNoCursor=1: some servers send an invisible cursor; show a dot so the pointer is never lost
            cmd += ["-MenuKey", "none", "-ReconnectOnError=0", "-FullscreenSystemKeys=0", "-DotWhenNoCursor=1"]
            if p.get("scale", "auto") == "original":
                cmd.append("-RemoteResize=0")        # keep the server resolution, no resize request
            if not p.get("clipboard", True):
                cmd += ["-SendClipboard=0", "-AcceptClipboard=0", "-SendPrimary=0", "-SetPrimary=0"]
        if p.get("password"):
            self.write_vnc_pass(p["password"])
            cmd += ["-passwd", VNC_PASS]
        cmd.append("{}::{}".format(host, port) if port else host)
        return cmd

    def build_cmd(self, p):
        host = p["host"].strip()
        port = p.get("port", "").strip()
        if p["proto"] == "vnc":
            return self.build_vnc_cmd(p, host, port)
        target = "{}:{}".format(host, port) if port else host
        cmd = ["xfreerdp3", "/v:" + target]
        if p.get("user"):
            cmd.append("/u:" + p["user"])
        if p.get("password"):
            cmd.append("/p:" + p["password"])
        if p.get("domain"):
            cmd.append("/d:" + p["domain"])
        scale = p.get("scale", "auto")
        fixed = scale in ("stretch", "original")
        size = "/size:{}x{}".format(p.get("width", 1280), p.get("height", 720))
        if p.get("fullscreen", True):
            cmd.append("/f")
            if p.get("multimon"):
                cmd.append("/multimon")
            if fixed:
                cmd.append(size)
        else:
            cmd.append(size)
        if scale == "stretch":
            cmd.append("/smart-sizing")                  # scale the fixed-size desktop to the window / screen
        elif scale.startswith("ui") and scale[2:].isdigit():
            cmd.append("/scale-desktop:" + scale[2:])    # bigger Windows UI (DPI scaling)
        cmd.append("+clipboard" if p.get("clipboard", True) else "-clipboard")
        if p.get("sound", True):
            cmd += ["/sound:sys:pulse", "/microphone:sys:pulse"]
        if p.get("usb"):
            cmd.append("/usb:auto")
        if p.get("ignorecert", True):
            cmd.append("/cert:ignore")
        cmd += ["-grab-keyboard", "+auto-reconnect", "/auto-reconnect-max-retries:3", "/network:auto"]
        if not fixed:
            cmd.append("/dynamic-resolution")
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
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                authfail = bool(AUTH_FAIL_RE.search(f.read()))
        except OSError:
            authfail = False
        if authfail:   # wrong password: retrying every few seconds could lock the account out
            self.set_status(self._("status_authfail", ""))
            return
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
        self.load_saved_net()
        if t == "wifi":
            self.scan_wifi()

    def load_saved_net(self):
        """Show the saved profile of the selected link type in the form."""
        d, t = self.cur_dev()
        if not t:
            return
        rc, out = run(["nmcli", "-t", "-s", "-f",
                       "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,"
                       "802-11-wireless.ssid,802-11-wireless.hidden,802-11-wireless-security.psk",
                       "connection", "show", NM_PROFILE[t]], 10)
        vals = {}
        if rc == 0:
            for line in out.splitlines():
                k, _, v = line.partition(":")
                v = v.replace("\\:", ":").strip()
                vals[k] = "" if v == "--" else v
        manual = vals.get("ipv4.method") == "manual"
        addr = re.split(r"[,\s|]+", vals.get("ipv4.addresses", "").strip())[0]
        ip, _, prefix = addr.partition("/")
        self.n["mode"].set_active_id("manual" if manual else "auto")
        self.n["ip"].set_text(ip if manual else "")
        self.n["mask"].set_text(prefix if manual else "")
        self.n["gw"].set_text(vals.get("ipv4.gateway", "") if manual else "")
        self.n["dns"].set_text(",".join(x for x in re.split(r"[,\s|]+", vals.get("ipv4.dns", "")) if x)
                               if manual else "")
        if t == "wifi":
            self.n["ssid"].set_text(vals.get("802-11-wireless.ssid", ""))
            self.n["wpass"].set_text(vals.get("802-11-wireless-security.psk", ""))
            self.n["hidden"].set_active(vals.get("802-11-wireless.hidden") == "yes")
        self.on_net_mode_changed()

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
        name = NM_PROFILE[typ]
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
            for old_name in (name, "kiosk-" + dev):  # the second one: profiles of older versions
                run(["nmcli", "-w", "30", "connection", "delete", old_name], 40)
            base = ["nmcli", "connection", "add", "type", typ, "ifname", "*", "con-name", name,
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
            return run(["nmcli", "-w", "40", "connection", "up", name, "ifname", dev], 50)

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
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/rc.xml" <<'__KIT_EOF__'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance><strength>10</strength><screen_edge_strength>20</screen_edge_strength></resistance>
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><focusLast>yes</focusLast><underMouse>no</underMouse><focusDelay>200</focusDelay><raiseOnFocus>yes</raiseOnFocus></focus>
  <placement><policy>Smart</policy><center>yes</center><monitor>Primary</monitor><primaryMonitor>1</primaryMonitor></placement>
  <theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout><keepBorder>no</keepBorder><animateIconify>no</animateIconify></theme>
  <desktops><number>1</number><firstdesk>1</firstdesk><popupTime>0</popupTime></desktops>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <keybind key="C-A-S-s"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl settings</command></action></keybind>
    <keybind key="C-A-S-n"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl network</command></action></keybind>
    <keybind key="C-A-S-p"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl power</command></action></keybind>
    <keybind key="C-A-S-r"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl reconnect</command></action></keybind>
    <keybind key="C-A-S-d"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl disconnect</command></action></keybind>
    <keybind key="F12"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl menu</command></action></keybind>
    <keybind key="C-A-S-space"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl toggle</command></action></keybind>
  </keyboard>
  <mouse><dragThreshold>8</dragThreshold><doubleClickTime>400</doubleClickTime></mouse>
  <applications>
    <application class="*"><decor>no</decor></application>
  </applications>
</openbox_config>
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/session.sh" <<'__KIT_EOF__'
#!/bin/sh
# X session of the kiosk user: no desktop, only openbox (for hotkeys) + the launcher.
export GDK_BACKEND=x11 NO_AT_BRIDGE=1 GTK_A11Y=none LANG=C.UTF-8
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
xset s off -dpms s noblank 2>/dev/null
xsetroot -solid '#20232a' -cursor_name left_ptr 2>/dev/null
pulseaudio --start --exit-idle-time=-1 --log-target=syslog 2>/dev/null
( sleep 3; pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 85% ) >/dev/null 2>&1 &
openbox --config-file /opt/kiosk/rc.xml >/dev/null 2>&1 &
# "Install to PC" boot menu entry: show the installer instead of the kiosk
if grep -qw kiosk.install=1 /proc/cmdline; then exec /opt/kiosk/installer.py; fi
exec /opt/kiosk/kiosk.py
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/local/sbin"
cat > "$DEST/overlay/usr/local/sbin/kiosk-growdata" <<'__KIT_EOF__'
#!/bin/sh
# Unique host name per computer (DHCP servers and routers otherwise see many machines called "kiosk")
MAC=$(cat /sys/class/net/[ew]*/address 2>/dev/null | head -n 1 | tr -d ':')
[ -n "$MAC" ] && hostname "thin-$(echo "$MAC" | cut -c7-12)" 2>/dev/null

# Prepare persistent storage: grow the last (data) partition to fill the device,
# check/grow its filesystem, mount it on /data and bind NetworkManager profiles from it.
# Several KIOSKDATA partitions can be present (flash drive left plugged in after installing to the PC):
# use the one on the same disk as the running system.
ROOTSRC=$(findmnt -rn -o SOURCE /media/root-ro 2>/dev/null)
ROOTDISK=
[ -b "$ROOTSRC" ] && ROOTDISK=$(basename "$(readlink -f "/sys/class/block/$(basename "$ROOTSRC")/..")")
DEV=
for c in $(blkid -t LABEL=KIOSKDATA -o device 2>/dev/null); do
    [ -z "$DEV" ] && DEV=$c
    if [ -n "$ROOTDISK" ] && [ "$(basename "$(readlink -f "/sys/class/block/$(basename "$c")/..")")" = "$ROOTDISK" ]; then DEV=$c; break; fi
done
INSTALL=0; grep -qw kiosk.install=1 /proc/cmdline && INSTALL=1   # installer mode: leave the flash drive as it is
if [ -b "$DEV" ]; then
    SYS=/sys/class/block/$(basename "$DEV")
    PART=$(cat "$SYS/partition" 2>/dev/null)
    DISK=/dev/$(basename "$(readlink -f "$SYS/..")")
    DISK_SECT=$(blockdev --getsz "$DISK" 2>/dev/null)
    START=$(cat "$SYS/start" 2>/dev/null); SIZE=$(cat "$SYS/size" 2>/dev/null)
    GREW=0
    if [ $INSTALL = 0 ] && [ -n "$PART" ] && [ -n "$DISK_SECT" ] && [ $((DISK_SECT - START - SIZE)) -gt 8192 ]; then
        echo ", +" | sfdisk --no-reread -N "$PART" "$DISK" >/dev/null 2>&1
        partx -u "$DISK" >/dev/null 2>&1 || partprobe "$DISK" >/dev/null 2>&1
        udevadm settle --timeout=15 >/dev/null 2>&1
        GREW=1
    fi
    if [ $GREW = 1 ]; then
        e2fsck -fp "$DEV" >/dev/null 2>&1
        resize2fs "$DEV" >/dev/null 2>&1
    else
        e2fsck -p "$DEV" >/dev/null 2>&1
    fi
    mkdir -p /data
    mountpoint -q /data || mount -t ext4 -o noatime "$DEV" /data
    if mountpoint -q /data; then
        mkdir -p /data/nm /data/kiosk
        chown 1000:1000 /data/kiosk; chmod 700 /data/kiosk
        mkdir -p /etc/NetworkManager/system-connections
        mountpoint -q /etc/NetworkManager/system-connections || \
            mount --bind /data/nm /etc/NetworkManager/system-connections
        # Ubuntu's NetworkManager saves new connections as netplan YAML in /etc/netplan:
        # keep it on the data partition and regenerate the NM profiles before NetworkManager starts.
        mkdir -p /data/netplan /etc/netplan
        chmod 700 /data/netplan
        mountpoint -q /etc/netplan || mount --bind /data/netplan /etc/netplan
        netplan generate >/dev/null 2>&1
    fi
fi
exit 0
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/local/sbin"
cat > "$DEST/overlay/usr/local/sbin/kiosk-install" <<'__KIT_EOF__'
#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Install the thin client from the boot flash drive onto an internal disk of the PC.

  kiosk-install list            -> JSON list of disks the system can be installed on (no root needed)
  kiosk-install run DISK [nocfg] -> install (root; the GUI starts kiosk-install@DISK[_nocfg].service)

The installer only works when the system was booted from the "Install to PC" menu entry (kiosk.install=1).
Layout of the target disk is the same as on the flash drive (MBR: ESP FAT32, squashfs root, ext4 data),
the ESP and root are copied byte for byte and verified, the data partition fills the rest of the disk.
Progress is printed as lines: "PROGRESS <percent> <message>", then "DONE" or "ERROR <message>".
"""
import hashlib
import json
import os
import random
import re
import subprocess
import sys
import time

MIB = 1 << 20
MIN_DATA = 256 * MIB
MBR_MAX = (1 << 32) - 1            # sectors addressable by an MBR partition table
OLD_ID = "4b50d0c1"                # disk id the flash image is built with (referenced by grub.cfg)


def sh(cmd, check=True, timeout=300):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError("%s: %s" % (" ".join(cmd), r.stdout.strip()[-300:]))
    return r.stdout


def out(line):
    print(line, flush=True)


def progress(pct, msg):
    out("PROGRESS %d %s" % (pct, msg))


def part_path(disk, n):
    return "%s%s%d" % (disk, "p" if disk[-1].isdigit() else "", n)


def parent_disk(dev):
    """/dev/sda2 -> /dev/sda"""
    name = os.path.basename(os.path.realpath(dev))
    link = os.path.realpath("/sys/class/block/%s/.." % name)
    if os.path.exists("/sys/class/block/%s/partition" % name):
        return "/dev/" + os.path.basename(link)
    return "/dev/" + name


def sectors(dev):
    with open("/sys/class/block/%s/size" % os.path.basename(os.path.realpath(dev))) as f:
        return int(f.read())


def start_sector(dev):
    with open("/sys/class/block/%s/start" % os.path.basename(os.path.realpath(dev))) as f:
        return int(f.read())


def source_root():
    """The squashfs root partition of the flash drive we are running from."""
    src = sh(["findmnt", "-rn", "-o", "SOURCE", "/media/root-ro"], check=False).strip()
    if src.startswith("/dev/"):
        return os.path.realpath(src)
    m = re.search(r"root=PARTUUID=(\S+)", open("/proc/cmdline").read())
    if m and os.path.exists("/dev/disk/by-partuuid/" + m.group(1)):
        return os.path.realpath("/dev/disk/by-partuuid/" + m.group(1))
    raise RuntimeError("cannot find the boot device")


def source_layout():
    root = source_root()
    disk = parent_disk(root)
    esp = part_path(disk, 1)
    if not os.path.exists(esp):
        raise RuntimeError("cannot find the boot partition")
    return disk, esp, root


def needed_bytes():
    disk, esp, root = source_layout()
    return (start_sector(root) + sectors(root)) * 512 + MIN_DATA


def candidates():
    src_disk = source_layout()[0]
    need = needed_bytes()
    j = json.loads(sh(["lsblk", "-J", "-d", "-b", "-p", "-o", "NAME,SIZE,MODEL,VENDOR,TRAN,TYPE,RM,RO,SERIAL"]))
    res = []
    for d in j.get("blockdevices", []):
        if d.get("type") != "disk" or str(d.get("ro")) in ("1", "true", "True"):
            continue
        if d["name"] == src_disk or int(d.get("size") or 0) < need:
            continue
        res.append({"name": d["name"], "size": int(d["size"]),
                    "model": ((d.get("vendor") or "").strip() + " " + (d.get("model") or "").strip()).strip(),
                    "tran": d.get("tran") or "", "removable": str(d.get("rm")) in ("1", "true", "True")})
    return res


def cmd_list():
    print(json.dumps({"disks": candidates(), "need": needed_bytes()}))


# ------------------------------------------------------------------ install
def copy_verify(src, dst, size, base, span, label):
    """Copy `size` bytes src -> dst, then read dst back and compare. Progress goes from base to base+span percent."""
    h = hashlib.sha256()
    done = 0
    last = 0
    with open(src, "rb") as fi, open(dst, "r+b", buffering=0) as fo:
        while done < size:
            buf = fi.read(min(4 * MIB, size - done))
            if not buf:
                raise RuntimeError("short read from " + src)
            fo.write(buf)
            h.update(buf)
            done += len(buf)
            pct = base + int(span * 0.6 * done / size)
            if pct != last:
                last = pct
                progress(pct, label)
        os.fsync(fo.fileno())
    sh(["blockdev", "--flushbufs", dst], check=False)
    try:
        with open("/proc/sys/vm/drop_caches", "w") as f:
            f.write("3")
    except OSError:
        pass
    h2 = hashlib.sha256()
    done = 0
    with open(dst, "rb") as fo:
        while done < size:
            buf = fo.read(min(4 * MIB, size - done))
            if not buf:
                raise RuntimeError("short read back from " + dst)
            h2.update(buf)
            done += len(buf)
            pct = base + int(span * 0.6 + span * 0.4 * done / size)
            if pct != last:
                last = pct
                progress(pct, label + " (проверка / verifying)")
    if h.digest() != h2.digest():
        raise RuntimeError("verification failed for " + dst)


def umount_all(disk):
    for line in sh(["lsblk", "-ln", "-o", "NAME,MOUNTPOINTS", disk], check=False).splitlines():
        parts = line.split(None, 1)
        if len(parts) == 2:
            for mp in parts[1].split():
                sh(["umount", mp], check=False)
    sh(["swapoff", "-a"], check=False)


def wait_part(path, tries=60):
    for _ in range(tries):
        if os.path.exists("/sys/class/block/" + os.path.basename(path)) and os.path.exists(path):
            return
        time.sleep(0.5)
    raise RuntimeError("partition did not appear: " + path)


def cmd_run(disk, copy_cfg):
    if "kiosk.install=1" not in open("/proc/cmdline").read().split():
        raise RuntimeError("not in installer mode")
    if not re.fullmatch(r"/dev/[A-Za-z0-9]+", disk) or not os.path.exists("/sys/class/block/" + os.path.basename(disk)):
        raise RuntimeError("bad disk " + disk)
    if disk not in [c["name"] for c in candidates()]:
        raise RuntimeError("disk is not suitable: " + disk)
    src_disk, src_esp, src_root = source_layout()
    esp_sz, root_sz = sectors(src_esp) * 512, sectors(src_root) * 512
    esp_start, root_start = start_sector(src_esp), start_sector(src_root)
    total = sectors(disk)
    data_start = ((root_start + sectors(src_root)) + 2047) // 2048 * 2048
    data_size = min(total - data_start - 2048, MBR_MAX - data_start)
    new_id = "%08x" % random.randint(0x10000000, 0xfffffffe)

    progress(1, "Подготовка диска / Preparing the disk")
    umount_all(disk)
    for p in sh(["lsblk", "-ln", "-o", "PATH", disk], check=False).split():
        if p != disk:
            sh(["wipefs", "-a", "-f", p], check=False)
    sh(["wipefs", "-a", "-f", disk])                         # also removes the backup GPT at the end of the disk
    sh(["dd", "if=/dev/zero", "of=" + disk, "bs=1M", "count=1", "conv=fsync", "status=none"])
    # first MiB of the flash drive: MBR boot code + BIOS GRUB core.img
    sh(["dd", "if=" + src_disk, "of=" + disk, "bs=1M", "count=1", "conv=fsync", "status=none"])
    layout = ("label: dos\nlabel-id: 0x%s\nunit: sectors\n\n"
              "start=%d, size=%d, type=ef, bootable\n"
              "start=%d, size=%d, type=83\n"
              "start=%d, size=%d, type=83\n") % (
        new_id, esp_start, sectors(src_esp), root_start, sectors(src_root), data_start, data_size)
    r = subprocess.run(["sfdisk", "--no-reread", "--no-tell-kernel", disk], input=layout, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        raise RuntimeError("sfdisk: " + r.stdout[-300:])
    sh(["partx", "-d", disk], check=False)
    sh(["partx", "-a", disk], check=False)
    sh(["udevadm", "settle", "--timeout=20"], check=False)
    p1, p2, p3 = (part_path(disk, i) for i in (1, 2, 3))
    for p in (p1, p2, p3):
        wait_part(p)

    copy_verify(src_esp, p1, esp_sz, 3, 12, "Загрузочный раздел / Boot partition")
    copy_verify(src_root, p2, root_sz, 15, 70, "Система / System")

    progress(86, "Раздел данных / Data partition")
    sh(["mke2fs", "-q", "-F", "-t", "ext4", "-L", "KIOSKDATA", "-E", "root_owner=0:0", p3])
    os.makedirs("/mnt/inst-data", exist_ok=True)
    sh(["mount", "-t", "ext4", p3, "/mnt/inst-data"])
    try:
        for d, mode, own in (("kiosk", 0o700, (1000, 1000)), ("nm", 0o755, (0, 0)), ("netplan", 0o700, (0, 0))):
            path = "/mnt/inst-data/" + d
            os.makedirs(path, exist_ok=True)
            os.chmod(path, mode)
            os.chown(path, *own)
        if copy_cfg:
            for d in ("kiosk", "nm", "netplan"):
                if os.path.isdir("/data/" + d):
                    sh(["cp", "-a", "/data/%s/." % d, "/mnt/inst-data/%s/" % d], check=False)
        os.sync()
    finally:
        sh(["umount", "/mnt/inst-data"], check=False)

    progress(90, "Загрузчик / Boot loader")
    os.makedirs("/mnt/inst-esp", exist_ok=True)
    sh(["mount", "-t", "vfat", p1, "/mnt/inst-esp"])
    try:
        for d in ("boot/grub", "EFI/BOOT", "EFI/ubuntu"):
            path = "/mnt/inst-esp/%s/grub.cfg" % d
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as f:
                cfg = f.read()
            cfg = re.sub(r"#INSTALL-BEGIN.*?#INSTALL-END\n?", "", cfg, flags=re.S)   # no installer entry on the PC
            cfg = cfg.replace("PARTUUID=%s-" % OLD_ID, "PARTUUID=%s-" % new_id)     # unique disk id
            with open(path, "w", encoding="utf-8") as f:
                f.write(cfg)
        os.sync()
    finally:
        sh(["umount", "/mnt/inst-esp"], check=False)

    if os.path.isdir("/sys/firmware/efi") and sh(["which", "efibootmgr"], check=False).strip():
        progress(95, "Запись UEFI / UEFI boot entry")
        for line in sh(["efibootmgr"], check=False).splitlines():
            m = re.match(r"Boot([0-9A-F]{4})\*? Thin client", line)
            if m:
                sh(["efibootmgr", "-B", "-b", m.group(1)], check=False)
        sh(["efibootmgr", "-c", "-d", disk, "-p", "1", "-L", "Thin client",
            "-l", "\\EFI\\BOOT\\BOOTX64.EFI"], check=False)   # best effort: the fallback path boots anyway

    os.sync()
    progress(100, "Готово / Done")
    out("DONE")


def main():
    a = sys.argv[1:]
    try:
        if a[:1] == ["list"]:
            cmd_list()
        elif a[:1] == ["unit"] and len(a) == 2:      # instance name of kiosk-install@.service: "sda" or "sda_nocfg"
            name, _, flag = a[1].partition("_")
            cmd_run("/dev/" + name, flag != "nocfg")
        elif a[:1] == ["run"] and len(a) >= 2:
            cmd_run(a[1], not (len(a) > 2 and a[2] == "nocfg"))
        else:
            print(__doc__)
            return 2
    except Exception as e:  # noqa: BLE001
        out("ERROR %s" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/mk-test-image.sh" <<'__KIT_EOF__'
#!/bin/sh
# Copy of disk.img with a VNC profile preconfigured (10.0.2.2 = the host as seen from QEMU user-net)
# and a serial debug shell enabled on the kernel command line.
set -e
cd /work/build
cp disk.img test.img
rm -rf td; mkdir -p td/kiosk td/nm
cat > td/kiosk/config.json <<J
{"lang":"ru","default":"t1","autoreconnect":true,"keyboard":"us-ru-alt",
 "profiles":[{"id":"t1","name":"Test VNC","proto":"vnc","host":"10.0.2.2","port":"5900","user":"","password":"test123","domain":"","fullscreen":true,"multimon":false,"width":1280,"height":720,"sound":true,"clipboard":true,"usb":false,"ignorecert":true,"extra":""}]}
J
chown -R 1000:1000 td/kiosk; chmod 700 td/kiosk; chown 0:0 td/nm
rm -f tdata.img; mke2fs -q -t ext4 -L KIOSKDATA -E root_owner=0:0 -d td tdata.img 128M
START=$(sfdisk -d disk.img | awk '/disk.img3/ {gsub(",","",$4); print $4}')
dd if=tdata.img of=test.img bs=512 seek=$START conv=notrunc status=none
sed -e 's/ quiet loglevel=3/ loglevel=4 console=tty0 console=ttyS0,115200 systemd.debug-shell=\/dev\/ttyS0 systemd.mask=serial-getty@ttyS0.service/' /work/kit/boot/grub.cfg > /work/grub-debug.cfg
mcopy -o -i test.img@@1048576 /work/grub-debug.cfg ::/boot/grub/grub.cfg
for d in EFI/BOOT EFI/ubuntu; do mcopy -o -i test.img@@1048576 /work/grub-debug.cfg ::/$d/grub.cfg; done
echo TEST_IMAGE_OK start=$START
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/qmon.py" <<'__KIT_EOF__'
#!/usr/bin/env python3
import socket, sys, time
cmd = " ".join(sys.argv[1:])
s = socket.socket(socket.AF_UNIX); s.connect("/work/qmon"); s.settimeout(3)
try: s.recv(4096)
except Exception: pass
s.sendall((cmd + "\n").encode()); time.sleep(0.8)
try: print(s.recv(65536).decode(errors="replace")[-400:])
except Exception: pass
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/rdpsrv.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:98
exec freerdp-shadow-cli3 /port:3389 -auth -sec-nla > /work/rdpsrv.log 2>&1
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/run-qemu.sh" <<'__KIT_EOF__'
#!/bin/sh
# usage: [SNAP=on|off] run-qemu.sh bios|uefi [image] [vpc]
MODE=$1; IMG=${2:-/work/build/disk.img}; FMT=${3:-raw}
FW=""
if [ "$MODE" = uefi ]; then
  cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd /work/ovmf_vars.fd
  FW="-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd -drive if=pflash,format=raw,file=/work/ovmf_vars.fd -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on"
fi
rm -f /work/qmon /work/ser.sock
exec qemu-system-x86_64 -m 2048 -smp 1 $FW \
  -drive if=none,id=usb0,file=$IMG,format=$FMT,snapshot=${SNAP:-on} \
  -device qemu-xhci -device usb-storage,drive=usb0,bootindex=0 \
  -vga ${VGA:-std} -display none \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -device intel-hda -device hda-duplex \
  -monitor unix:/work/qmon,server,nowait -serial unix:/work/ser.sock,server,nowait
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/ser.py" <<'__KIT_EOF__'
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
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/uitest.py" <<'__KIT_EOF__'
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
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/uitest.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:99 NO_AT_BRIDGE=1 HOME=/tmp/kh
mkdir -p /tmp/kh; rm -f /tmp/kh/uitest.out
Xvfb :99 -screen 0 1366x768x24 >/dev/null 2>&1 &
XP=$!
sleep 2
/usr/bin/python3.12 /work/kit/test/uitest.py > /work/uitest.out 2>&1
kill $XP
echo done >> /work/uitest.out
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/vncsrv.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:98
Xvfb :98 -screen 0 1280x720x24 >/dev/null 2>&1 &
sleep 2
xsetroot -solid '#2a5a8a' 2>/dev/null
xclock -geometry 300x300+60+60 >/dev/null 2>&1 &
xterm -geometry 70x12+420+80 -e 'sh -c "echo REMOTE VNC DESKTOP OK; date; sleep 100000"' >/dev/null 2>&1 &
x11vnc -display :98 -rfbport 5900 -passwd test123 -forever -shared -noxdamage -quiet >/work/x11vnc.log 2>&1 &
wait
__KIT_EOF__
echo "== verifying unpacked files"
cat > "$DEST/.manifest.sha256" <<'__KIT_EOF__'
f4b103647855aa7053934355e698e9e3598f263430cb403499d02b42b45446a0  README.md
8d37e3a11f5e447201cef7a58b14e2afc8c2b121a1aae8d901cc5bc61e22a4c5  boot/early.cfg
8df535eb5edf71bfccd5a046562cac8a7939f09292da25a7bffe13d4fea10b6d  boot/grub.cfg
dd028468a5d7a13cf9e7776142400c8c110ded810d2b6f6d703eb6473d61fb31  build-all.sh
08f9ac29be737ac8912b27f37be6d4fdee81e347e849041bd8bc40d46a41533a  build-image.sh
42e99ac16387aee0ab9e72aebacf8327cfe896e93139f2a0d5c62718a15fef2e  build-rootfs.sh
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-dns-resolved.conf
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-globally-managed-devices.conf
daecdafe66e474402395c4fb23eb20bb1db1bf45fc8a1da89d286a57570a869e  overlay/etc/NetworkManager/conf.d/kiosk.conf
7a6730e8648c5d4168ba77af4b141db76c7c6abac8eb1becd4a4488b81d5b74b  overlay/etc/X11/xorg.conf.d/10-kiosk.conf
c20cd567970bb1fd7364af1e68baeb47ad8be67a8ab8766a1ff2031c5141d9cc  overlay/etc/fstab
48bef90bf3804ed0a3a3a2ad6cb6c2a0ccd06ab0d169e55aba89f92943add2de  overlay/etc/hostname
21f5338821e1921d916444ec33b1770db087c3f68b1122e7b64ab77745ed177d  overlay/etc/polkit-1/rules.d/50-kiosk-install.rules
8e1cebeaa97f7d2b59e078ffe5c6cb10ad144049277e37d83ef7cecfcf0a0afd  overlay/etc/polkit-1/rules.d/50-kiosk.rules
1a25306c51ebefbe547f20a43603bbbadf8f2464f510ff755445a7a70a1f2733  overlay/etc/sysctl.d/90-kiosk.conf
b86aaef6227a5824e04d89c3ce772d8479fadd5e6a1e13d908cce627bfd5f7cc  overlay/etc/systemd/journald.conf.d/kiosk.conf
9a8764b2132a80abcc30d5a6a30180a90177ba8eddf0741d0455349a5ddfded8  overlay/etc/systemd/logind.conf.d/kiosk.conf
4368449caebff4de8fb38f73787b63c7a575aa49862f6921de34a28d4764b8d3  overlay/etc/systemd/system/NetworkManager.service.d/kiosk.conf
41f6a7b7e7d48646734c2c937f4fc1eef56102048a63420d349bb6d2155af230  overlay/etc/systemd/system/kiosk-growdata.service
55b5a21eed1da4036179f980fb451706cd893e5e6e69d869df2e504437cdffb0  overlay/etc/systemd/system/kiosk-install@.service
9fbf7d8db6455969f2e62cba6087cdf04f5170f6553fa5bf34ea4ad3bcf19769  overlay/etc/systemd/system/kiosk.service
6a2a46a868a19fdbab9db2c85831059c428cfabc94ad9b461b8a6c4a4f07c6b4  overlay/etc/udev/rules.d/90-kiosk-usb.rules
1f17b5c77234ae4a3fd96e06cb281da61a6293b61740e927765bd5e47d2fe266  overlay/opt/kiosk/installer.py
59b18b2923bbff3fc2588823f06c363dc712dcc76bab6d8f5d9da72976cf89b4  overlay/opt/kiosk/kiosk.py
a903543768178e611125db6cdf98020817466892fb4da56a4b2b6df2f8a4cba3  overlay/opt/kiosk/rc.xml
a5ca420724b24e64d6e864d810f188d2691d4e7998475a4d9ffc23fa385245fd  overlay/opt/kiosk/session.sh
d4d40b3b3e3b1aab78c7ed02ab05398c6a91db8a94d9a13e4e6dd2a370a25918  overlay/usr/local/sbin/kiosk-growdata
46b7264725c9a1b41bc8abc91d82bca985b91321ea07bc8334d210f6c829ae6d  overlay/usr/local/sbin/kiosk-install
4a7733f237ed0ce1f06686ae02be449c15fcbfabc6c7a7123ea950c76660d837  test/mk-test-image.sh
e76eb83ffb324ff644b69fb65d8ab6cec97d35369d2a1056bc9513a397b5360a  test/qmon.py
d39714cda94e064594b9aac27d7931c744d1354fc4440fba6b3f3f8c2776fbd8  test/rdpsrv.sh
8f60e334c5e53654d1c6a2083341465866a11326e0d90520c91fa3faa25dc23d  test/run-qemu.sh
046a8b46568db8a62e395a65e470af520544396c4df7e9b5f68b93d3c2c96f13  test/ser.py
43bdaf2e4726e98fec849d41c687a8fb5ddca3feb96fb45524fa4b82b6d804ae  test/uitest.py
f666170a9c3910d292a7c41229b33be88c014765909be84f9a001322096c9da4  test/uitest.sh
35ecd03f14be2d2a19da60dd3594b28e7518e52bf15ada8a50718275b71eca1c  test/vncsrv.sh
__KIT_EOF__
( cd "$DEST" && sha256sum -c --quiet .manifest.sha256 ) || { echo "ERROR: the script was damaged during copying (checksum mismatch). Re-download it." >&2; exit 1; }
chmod +x "$DEST/build-all.sh" "$DEST/build-rootfs.sh" "$DEST/build-image.sh" "$DEST/overlay/opt/kiosk/kiosk.py" "$DEST/overlay/opt/kiosk/session.sh" "$DEST/overlay/opt/kiosk/installer.py" "$DEST/overlay/usr/local/sbin/kiosk-growdata" "$DEST/overlay/usr/local/sbin/kiosk-install"
[ -n "${KIT_ONLY:-}" ] && { echo "kit unpacked (KIT_ONLY set), not building"; exit 0; }
exec sh "$DEST/build-all.sh" "${1:-$PWD/out}"
