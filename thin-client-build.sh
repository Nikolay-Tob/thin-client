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
- **Заставка при загрузке:** логотип BIOS/UEFI компьютера (если он есть), под ним логотип и описание ООО ИК «СибИнТек». Баннер можно заменить без пересборки (см. ниже).
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

| ![Заставка UEFI](docs/screens/16-boot-splash-uefi.png) | ![Заставка BIOS](docs/screens/17-boot-splash-bios.png) |
|---|---|
| **Заставка при загрузке (UEFI):** сверху логотип прошивки (в эмуляторе это TianoCore), ниже баннер. | **Заставка без логотипа BIOS:** баннер по центру. Здесь показан баннер, заменённый с флешки. |

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

## Заставка и замена логотипа
При загрузке показывается логотип BIOS/UEFI (берётся из таблицы ACPI BGRT, у части компьютеров его нет), под ним баннер: логотип и описание компании.
Если логотипа BIOS нет, баннер выводится по центру. Встроенный баннер собран из `branding/logo-vertical.jpg` и `branding/text.txt`.

**Заменить баннер без пересборки:** положите PNG-файл (прозрачный фон, ширина до 1000 пикселей, светлый текст) на флешку по пути `branding/banner.png`
(раздел `KIOSKBOOT`, он виден в Windows как обычная флешка). Файл до 3 МБ. Если файла нет или он повреждён, показывается встроенный баннер.
Готовый баннер делает скрипт `tools/make-banner.py` (нужен Pillow):

    python3 tools/make-banner.py --logo logo.png --text text.txt --out banner.png

В `text.txt` первая строка — название, остальные — описание. Тёмный логотип скрипт инвертирует (жёлтый цвет остаётся); `--style plate` кладёт логотип на светлую плашку.
Чтобы изменить встроенный баннер, замените файлы в `branding/`, пересоберите баннер скриптом в `overlay/usr/share/plymouth/themes/sibintek/watermark.png` и соберите образ.
Не проверено на реальном железе: как выглядит логотип BIOS на конкретных материнских платах и экранах.

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
- **1.6** — заставка при загрузке: логотип BIOS/UEFI (если есть) и баннер ООО ИК «СибИнТек»; баннер заменяется файлом `branding/banner.png` на флешке; генератор баннера `tools/make-banner.py`.
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
USB redirection, multi-monitor, Russian/English UI. VNC: choice of client (TigerVNC / SSVNC), mouse cursor mode and image scaling (fit / stretch / 1:1 / percent). Boot splash: firmware (BIOS/UEFI) logo when available plus a company banner that can be replaced with `branding/banner.png` on the flash drive. Settings are stored on the flash drive (`KIOSKDATA` partition).
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
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
#INSTALL-BEGIN
if [ "$cyr" = 1 ]; then set install_title="Установка на ПК (Install to PC)"; else set install_title="Install to PC"; fi
menuentry "$install_title" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 kiosk.install=1 quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
#INSTALL-END
menuentry "Thin client (safe graphics, nomodeset)" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet splash loglevel=3 nomodeset vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
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

# boot splash (Plymouth, theme "sibintek": firmware/BGRT logo + company banner); .debs + dpkg as the tree is pruned
if ! stage s7-splash; then
    log splash
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    chroot $R apt-get update -qq
    chroot $R sh -c 'cd /tmp && apt-get download plymouth libplymouth5 plymouth-label plymouth-theme-spinner && dpkg -i --force-depends /tmp/*.deb; rm -f /tmp/*.deb'
    # plymouth-theme-spinner ships the two-step plugin; its own themes are replaced by ours
    # two-step needs the stock UI images (lock.png etc.); take them from the spinner theme, without its animation and logo
    rm -rf /tmp/ply-img; mkdir -p /tmp/ply-img
    [ -d $R/usr/share/plymouth/themes/spinner ] && (cd $R/usr/share/plymouth/themes/spinner && for f in *.png; do
        case "$f" in animation-*|watermark.png) ;; *) cp "$f" /tmp/ply-img/;; esac; done)
    rm -rf $R/usr/share/plymouth/themes/sibintek $R/usr/share/plymouth/themes/spinner $R/usr/share/plymouth/themes/bgrt $R/usr/share/plymouth/themes/tribar
    mkdir -p $R/usr/share/plymouth/themes/sibintek && cp /tmp/ply-img/*.png $R/usr/share/plymouth/themes/sibintek/ 2>/dev/null || true
    # (no spinner: the theme has a single transparent animation frame, see overlay/)
    cp -a "$KIT/overlay/." $R/
    chmod 755 $R/etc/initramfs-tools/hooks/kiosk-branding $R/etc/initramfs-tools/scripts/init-premount/branding
    chroot $R update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/sibintek/sibintek.plymouth 200
    chroot $R update-alternatives --set default.plymouth /usr/share/plymouth/themes/sibintek/sibintek.plymouth
    # no splash on shutdown/reboot (faster, fewer moving parts)
    chroot $R systemctl mask plymouth-poweroff.service plymouth-reboot.service plymouth-halt.service plymouth-kexec.service 2>&1 | tail -1
    KVER=$(cat "$OUT/stamps/kver")
    log "initramfs with splash"
    chroot $R mkinitramfs -o /tmp/initrd.img $KVER
    cp $R/tmp/initrd.img "$OUT/bootfiles/initrd.img"; rm -f $R/tmp/initrd.img
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/plymouth* $R/boot/* 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s7-splash
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
cat > "$DEST/make-banner.py" <<'__KIT_EOF__'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор баннера загрузочной заставки (логотип + описание компании).

  python3 make-banner.py [--logo logo.png] [--text text.txt] [--out banner.png]

text.txt: первая строка — название (крупно), остальные — описание (мельче).
Тёмный логотип по умолчанию инвертируется (жёлтый остаётся), --style plate кладёт его на светлую плашку. Готовый banner.png положите на флешку в папку branding/ (раздел KIOSKBOOT) — он будет показан вместо встроенного.
Нужен Pillow (pip install pillow). Можно сделать баннер и в любом графическом редакторе: PNG с прозрачным фоном,
ширина до 1000 пикселей, светлый текст (фон заставки тёмный).
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

DEFAULT_TEXT = ("ООО ИК «СибИнТек»\n"
                "ИТ-интегратор ПАО «НК «Роснефть»\n"
                "Рабочее место на базе тонкого клиента")
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf", "C:/Windows/Fonts/segoeui%s.ttf",
         "/usr/share/fonts/truetype/noto/NotoSans-%s.ttf", "/Library/Fonts/Arial%s.ttf"]


def font(size, bold=False):
    for pat in FONTS:
        for suf in (("-Bold", "b", "Bold") if bold else ("", "", "Regular")):
            p = pat % suf if "%s" in pat else pat
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def invert_logo(src, accent=(246, 206, 69)):
    """Dark logo on white paper -> light logo on a transparent background; yellow parts keep their colour."""
    src = src.convert("RGB")
    w, h = src.size
    out = Image.new("RGBA", (w, h))
    px, po = src.load(), out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            mn, mx = min(r, g, b), max(r, g, b)
            a, sat = 1 - mn / 255, (mx - mn) / 255
            if sat > 0.4:                                   # yellow: full colour, the white-paper edge fades out
                po[x, y] = accent + (round(255 * min(1, a * 2.2)),)
            else:                                           # black/grey -> white, slightly bolder
                po[x, y] = (255, 255, 255, round(255 * min(1, a ** 0.75 * 1.1)))
    return out


def make(logo, text, placeholder=False, height=170, style="invert"):
    """Logo on a light rounded plate on the left (usual logos are dark), the description on the right."""
    lines = [l.rstrip() for l in text.splitlines() if l.strip()]
    title, rest = lines[0], lines[1:]
    f1, f2 = font(30, True), font(21)
    pad, gap = 12, 26
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    plate = None
    if logo and style == "invert":
        lg = invert_logo(logo)
        lg = lg.resize((max(1, round(lg.width * (height - 8) / lg.height)), height - 8), Image.LANCZOS)
        plate = Image.new("RGBA", (lg.width, height), (0, 0, 0, 0))
        plate.paste(lg, (0, 4), lg)
    elif logo:
        lg = logo.convert("RGBA")
        inner = height - 48                      # white margin around the logo
        lg = lg.resize((max(1, round(lg.width * inner / lg.height)), inner), Image.LANCZOS)
        plate = Image.new("RGBA", (lg.width + 48, height), (255, 255, 255, 255))
        plate.alpha_composite(lg, (24, 24))
        mask = Image.new("L", plate.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, plate.width - 1, plate.height - 1), radius=14, fill=255)
        plate.putalpha(mask)
    elif placeholder:
        plate = Image.new("RGBA", (height, height), (0, 0, 0, 0))
        d = ImageDraw.Draw(plate)
        for i in range(0, height, 14):
            for xy in ((i, 1, min(i + 7, height - 1), 1), (i, height - 2, min(i + 7, height - 1), height - 2),
                       (1, i, 1, min(i + 7, height - 1)), (height - 2, i, height - 2, min(i + 7, height - 1))):
                d.line(xy, fill=(255, 255, 255, 150), width=2)
        tw = d.textlength("ЛОГОТИП", font=f2)
        d.text(((height - tw) / 2, height / 2 - 14), "ЛОГОТИП", font=f2, fill=(255, 255, 255, 190))
    text_h = 46 + len(rest) * 28
    text_w = max([probe.textlength(title, font=f1)] + [probe.textlength(l, font=f2) for l in rest])
    x0 = pad + (plate.width + gap if plate else 0)
    w = int(x0 + text_w + pad)
    h = (plate.height if plate else text_h) + 2 * pad
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if plate:
        img.paste(plate, (pad, pad), plate)
        d.line((pad + plate.width + gap // 2, pad + 14, pad + plate.width + gap // 2, h - pad - 14), fill=(246, 206, 69, 255), width=3)
    ty = (h - text_h) // 2
    d.text((x0, ty), title, font=f1, fill=(255, 255, 255, 255))
    for i, l in enumerate(rest):
        d.text((x0, ty + 46 + i * 28), l, font=f2, fill=(205, 210, 218, 255))
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--logo")
    ap.add_argument("--text")
    ap.add_argument("--style", choices=("invert", "plate"), default="invert",
                    help="invert: light logo on the dark background (yellow kept); plate: original logo on a white plate")
    ap.add_argument("--out", default="banner.png")
    ap.add_argument("--placeholder", action="store_true", help="draw an empty frame where the logo goes (preview)")
    a = ap.parse_args()
    text = open(a.text, encoding="utf-8").read() if a.text else DEFAULT_TEXT
    logo = Image.open(a.logo) if a.logo else None
    make(logo, text, a.placeholder, style=a.style).save(a.out)
    print("saved", a.out)


if __name__ == "__main__":
    sys.exit(main())
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
mkdir -p "$DEST/overlay/etc/initramfs-tools/hooks"
cat > "$DEST/overlay/etc/initramfs-tools/hooks/kiosk-branding" <<'__KIT_EOF__'
#!/bin/sh
# initramfs hook: the second splash theme (no firmware logo) and the vfat driver for the branding override
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac
. /usr/share/initramfs-tools/hook-functions
T=/usr/share/plymouth/themes
mkdir -p "$DESTDIR$T/sibintek-nologo"
cp -p $T/sibintek-nologo/sibintek-nologo.plymouth "$DESTDIR$T/sibintek-nologo/"
# run the branding script right before plymouthd is started (the ORDER file does not guarantee that)
[ -f "$DESTDIR/scripts/init-premount/plymouth" ] && sed -i 's|^SPLASH="false"|/scripts/init-premount/branding \|\| true\nSPLASH="false"|' "$DESTDIR/scripts/init-premount/plymouth"
manual_add_modules vfat nls_cp437 nls_iso8859_1 nls_utf8
exit 0
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/initramfs-tools/scripts/init-premount"
cat > "$DEST/overlay/etc/initramfs-tools/scripts/init-premount/branding" <<'__KIT_EOF__'
#!/bin/sh
# Runs before plymouthd (alphabetical order inside the udev group):
#  1. no BIOS/UEFI logo (no ACPI BGRT) -> use the theme without the firmware background;
#  2. KIOSKBOOT partition of the boot disk (FAT, readable on Windows) holds branding/banner.png -> use it instead
#     of the built-in banner. Any failure is ignored: the built-in banner stays.
PREREQ="udev"
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac

[ -e /run/branding.done ] && exit 0
: > /run/branding.done
T=/usr/share/plymouth/themes
grep -qw splash /proc/cmdline || exit 0

if [ ! -e /sys/firmware/acpi/bgrt/image ] && [ -f /etc/plymouth/plymouthd.conf ]; then
    sed -i 's/^Theme=.*/Theme=sibintek-nologo/' /etc/plymouth/plymouthd.conf
fi

ID=$(sed -n 's/.*root=PARTUUID=\([0-9a-fA-F]*\)-02.*/\1/p' /proc/cmdline | head -n1)
[ -n "$ID" ] || exit 0
n=0
while [ ! -e "/dev/disk/by-partuuid/$ID-01" ] && [ $n -lt 40 ]; do sleep 0.2; n=$((n+1)); done
[ -e "/dev/disk/by-partuuid/$ID-01" ] || exit 0
modprobe vfat 2>/dev/null
mkdir -p /run/esp
if mount -t vfat -o ro,noexec,nodev "/dev/disk/by-partuuid/$ID-01" /run/esp 2>/dev/null; then
    f=/run/esp/branding/banner.png
    if [ -f "$f" ] && [ "$(wc -c < "$f")" -le 3000000 ] && [ "$(head -c 4 "$f" | tail -c 3)" = "PNG" ]; then
        cp "$f" "$T/sibintek/watermark.png"
    fi
    umount /run/esp
fi
exit 0
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/plymouth"
cat > "$DEST/overlay/etc/plymouth/plymouthd.conf" <<'__KIT_EOF__'
[Daemon]
Theme=sibintek
ShowDelay=0
DeviceTimeout=8
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
After=plymouth-start.service systemd-user-sessions.service systemd-logind.service kiosk-growdata.service NetworkManager.service
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
ExecStartPre=-/usr/bin/plymouth quit --retain-splash
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

VERSION = "1.6"


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
mkdir -p "$DEST/overlay/usr/share/plymouth/themes/sibintek-nologo"
cat > "$DEST/overlay/usr/share/plymouth/themes/sibintek-nologo/sibintek-nologo.plymouth" <<'__KIT_EOF__'
[Plymouth Theme]
Name=Thin client (no firmware logo)
Description=Company banner in the middle of the screen (the PC has no BIOS logo)
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/sibintek
HorizontalAlignment=.5
VerticalAlignment=.78
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.45
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x15181d
BackgroundEndColor=0x15181d
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false
UseFirmwareBackground=false

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=false

[reboot]
UseEndAnimation=false
UseFirmwareBackground=false
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/share/plymouth/themes/sibintek"
base64 -d > "$DEST/overlay/usr/share/plymouth/themes/sibintek/animation-0001.png" <<'__KIT_EOF__'
iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAC0lEQVR4nGNgQAcAABIAAXfx+gAA
AAAASUVORK5CYII=
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/share/plymouth/themes/sibintek"
base64 -d > "$DEST/overlay/usr/share/plymouth/themes/sibintek/bgrt-fallback.png" <<'__KIT_EOF__'
iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAC0lEQVR4nGNgQAcAABIAAXfx+gAA
AAAASUVORK5CYII=
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/share/plymouth/themes/sibintek"
cat > "$DEST/overlay/usr/share/plymouth/themes/sibintek/sibintek.plymouth" <<'__KIT_EOF__'
[Plymouth Theme]
Name=Thin client (with firmware logo)
Description=Firmware (BIOS/UEFI) logo from ACPI BGRT, company banner below it
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/sibintek
HorizontalAlignment=.5
VerticalAlignment=.72
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.97
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x15181d
BackgroundEndColor=0x15181d
DialogClearsFirmwareBackground=false
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false
UseFirmwareBackground=true

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=true

[reboot]
UseEndAnimation=false
UseFirmwareBackground=true
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/share/plymouth/themes/sibintek"
base64 -d > "$DEST/overlay/usr/share/plymouth/themes/sibintek/watermark.png" <<'__KIT_EOF__'
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
smwRRVFKZK02ctJJJzXLz88vKikp2WW1WrMB7XrLsmzZuHFj9JZ98Pl83shrhdVqzY5YF1Nm3759
+3w+n3f//v27GjZsWLRr1649Ue0HvV5vqd5+rDZEUTxkbsWbE36/v8JisWTv2LFjR/Q5xhjmzp37
wmWXXXa9z+fz6vWDwWAg2RhUVVVCoZDfYrHYdIu/ztatW7cax1dRUeGL146OyWRiv/zyyzqv11uq
t2+1Wm2zZ89+7u67734xWX2CIAiCIGqfjBXbgQMHntGrV69BJSUlu3JzcxvpymMwGPRbrdake5vr
ympZWdneyZMnv/zmm2++t27dun3GMowxJsuyRVdoZFm2cJ7aeu+DDz54FwBYrVZbtGJrsViyostb
LBar1Wq16WVSGUMURQCQn5+fG+ukJEmSPhZRFKVUlXTGGF544YVpqqoqubm5jXSFUW/DbDabo+sY
ZbdarTaWjp+A1rZotVptEcXVJsuyFHVesNlseTabLS+ddmORm5tbEHk97Lq1atUq/7LLLru+rKxs
r81my0t1bkUjCMIh4zebzbJxfNHnY/Hkk0/ebrVabcFg0K/fg5KSkl3XXnvtXenKQxAEQRBE7ZCR
YisIAl566aV5qqoq+fn5RYCmNAKa8jl//vxpX3zxxSeSJImBQCCoK1aqqiqNGzduPGnSpCfy8/OL
dKuXqqrKk08++UT//v1HJuo3VbKysqQRI0bcqVs106mrK0833HDDgE8//fQbs9lsSmTxFASBhcNh
zhiDJEnipk2b9sUrG00q+mZxcbGte/fufX0+nzcTpa42qKysDC5cuHBOKBQKms1mSzgcDquqqoqi
KAKAJEmmrl279jIqvj/99NPCDRs2rMnKysoy+jsrihICgI0bN26O7uf6668frs8R/b58+OGH0+++
++7JgUAgxBhDrOcczjnX/WBFURQS+e4CB32e49G+ffvGN95446P6PfB6vaU2my2vXbt2bdPx+f6n
4nJ7bABMTod9f33LQhDpQvOXIP5ZZKTYFhYWZuXn5xfpP/TGZeZjjz224fbt272J6j/xxBNvvvvu
uy/riqyqqsoFF1xwpSzLo2tCURg5cuRFmdbVx/HRRx999ffffx+orixJSKrZ3n///bcDhy/t1ye7
du2qOP/886+Mp1gKgoCvvvpqwVlnnXWxPkf69u3b3xjklgzGGAYOHDhGdwuRZdkyZ86c54cMGTIh
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
WUwvrWH5UqE22k9nfDqOyOvmNPrR4yimQbNsXut02HkCI0Bp5DWTeZbpvU6Vmv6cV3HUKbbGlXhR
FNm0adPeMSpg11133ZDo1fp0rJx6Wx999NG3+/btS+qKsHXr1rU9evS48Lfffvu+Xbt2XXVra5cu
XeyLFi1KKWUIoG3I8NRTT71p3JDglltuuTW6XDrZJ/SxfPDBB0vS8fv9+OOP37/kkkuuDQaDGfsK
1yT69fjhhx/W16TlVA8QGzJkSJ/FixevBABZloV169b92aRJk9b6ds/vvvvu9wUFBdZU5sNRgL51
6J1Oh/3nqHO9oflvRt93FzR/s5Eut+fVGMu5oyOvyw2vp0PzZfvskIbcHgmaL6OxPADA6bDvgBZk
g6g68dLJLIO21DbO5fZ8neLSfCZ1UiISOPcRtOthhbYcmegzlIksS6Etm493uT2La8EdIaN7V8Nk
MkcTke78rbYMTofdD+DPSPT9KACX4FDFttbmYQrUxz32ALjU6bCHADzncnvOBXCJy+253umwR/ux
1rZ8tdF+OuPTldNLIv+mFChmYBS0ufOI02FflaRsfc6zZNT057yKI1qxjaWQGlNXdezYsWnz5s3t
+iYGJSUlu7766qvDlMlMUpGZzeaUr42qqnz8+PEjvvnmmzXBYDBgs9nynE5np2SKrXF4vXv37mSz
2fLKysr22my2vDVr1rg8Hs9hT0XR1yQcDif1OY2MJeUJYrFYDjH/Z+LKIYriIUsfGdyCw/oURZEp
ilJjH0zdX7esrKxcly8QCITPP//8HqtXr95p3HXs888//6hbt269jwKXhGTsjLze7nJ77gSwCQez
KDwYp85saP6jXQHMd7k9elR5K2hP2mdB82OcGSk/A8B4AANcbs+r0Kywf0OzYj4KoD2AA9Ci+6vD
C9CyDlwC4EOX2/MUgNUAvNCsLh0BDAEwx+mwv1eNOunwHLRd30IAXq4F+V8GcCO0NEVfuNyehwD8
ETnXEZq/3UuRYKZMqKt7l4hM5mgi0p2/acvgcnuegLak/Bk01wMRWgDSJGhWp+jv8tqeh4moj3u8
P6L06QyHloLqKZfb873TYXfXoXy10X5K44sotO2gpbjqDO1+f4bUKQDwOLT5m8pnoT7nWTJq+nNe
Rb3vMJUquvVRV2wZY3jooYce0s+JoiiNHz9+UCzFJxMf0XSV4RUrVhjTxODEE090GP+P44rAAM29
4sUXX3wLOBi8NGzYsMtjiRAdPBYdTBXLOJ3u+KPL18cGDbHGUVtKpaqqh1zTP//8c9esWbMe1y3F
wWDQ36VLl/OGDRvWu1YEqFtegvYjfgmAtdAeeLZAW0ZfBC0S9RAiltTroPkJXgwtargCmkI1MHJ8
nJ4qKZLcXF9tGAVtydwLzXLWO9L/NZkm3zbI9Te0pT8vNEXvG2jLzpWRsc2DllfUXJ06acr0jdNh
Z06HXY5ct5qWfws0q7YPwHnQsiDsi/x9A80ymbHBoq7uXRLSnqOJSHf+ZihDE2gKx8pI2wegpWC6
HFrU+wNRMtXqPEzEkXCPnQ77PmgKlQnAOy63J8twrlblq4vxJxhfN2jz7kpo8+4Gp8OezsY/baD5
2V8XWRVIJke9zbMUqNHPuZEaUVjqwhdTVzJ0hadx48a2fv36XePz+bw2my0vGAz6FyxYkKmVotro
2wHruV9tNltOqnU7dOjQxLghw549e7YtX758Uy2JetRSWxkKYrV700033avPOavVagsGg/6ZM2d+
UVRUdETk9s0Up7YD0hnQctvugaYg/QHti35wgnqzoO3Y9AG0L0YlUv9DAD0ivoXG8k9Dywf5KbQv
KAXaE/pcAN2cDvsHNTSez6Dlb30W2g+UD5pisQbAu9C+tN+tbp3aIkP5P4S2+cZ0aFaOILSo6K+g
3cPvqilTndy7BP1nNEeTtDkL6c3fdGWYCC1K/VdoSkQAWl7ON6Fds09jyFRv87C+73FEhm+hKfwn
QLMs1pl8dTH+OOPj0KzDcwGc7nTYX8+g6bedDvviNOQ4Yr7vouSq8c95tZgwYcJlnHNeWVlZziOY
zeZqKcmxlAuHw9FE70fvq1mzZjkAMG3atPsURQmVlpbu4ZzzyZMnx40+btmyZR7nnJeXl+/nnPMf
f/zxi+i+t23b9pdxTMXFxWkpMCaTiXHOeSAQ8HHO+SeffDLLOKY+ffp00tvXy+jX7LvvvvvIOJZL
Lrnk1Hj9dOnSpQXnnOtl586d+7zxvNlsFvR7oo/lmGOOyYrXXizGjBlzIeec79u3byfnnF9++eWn
J691KN99991Hxmuek5NjSl7rIA0bNjTrY1AUJcQ557Is18iD2Pjx4y8xjq9r164tY5UbOnToufo9
VRQlFAgEfB6P57foAMbqUPnreVz/q7FGCYIgCOJfSka/0LIsV5mtfT6fFwCaNm2al247Z555pt3j
8fz2448/frF27drfnE5n3JxlulXY7/crFotFGDNmzH/14B8AmDJlyltpDyQB6abV0l0k9OsRCAT8
xqXzWO4A4XCYN2zY0HzGGWf8R8+EEAwG/Z9++mm0I/W/jlhuB7VlsY3ndvLWW299uWnTptXGY23b
tu00ceLEun+aJAiCIAgiKRkptnv27NkdfWzMmDFXp9vOgAED+rdt27ZT586dz2nbtm2nYDB4yKYG
RoVDXxYWRZH16dOnq55aS5Zly/Tp0x8ybmJQE1RWVqbVXnFxcQPgoM/rtm3bDknhIYqiYHgvAZoy
fO211w7UxyKKojRp0qQhgUAgbiqraIU7OkgrTp10hpLRJhA1jb4NsizLlmj/6roiHA6jf//+58my
bNHnms/n8/7vf/+bfeyxx6aSjoogCIIgiDokI8V248aNWwDNiqr/6N9+++3P5ufnp+yAbDKZ2FVX
XTUhGAz6vV5vaTAY9B84cCBuzlZdGTzllFPsDz300LOiKEp6Yv177rnnsUzGkYS0tMH+/ftXbb+r
qqqydOnSuH5uoihKe/bs2eZ0Olvffffdz4uiKOmW5xkzZnyUucj/HEKhUFgPCtR3gOvcufNxdS2H
2+3e/vbbbz+jz3NdniVLliwTRfGo3JaMIAiCIP6pZKTYbt26dY9xpy9AixyfM2fOa6n82DPGcN99
911fWFjYVFVVxWaz5cmybNmzZ09FVLmqtnQldvr06fPatWvXTVVVxWq12hYuXDhn9+7dKW8Xmyrx
tmONRatWrRo+8cQTb0VcI7JFUZSWLl1qTF9y2HK3zWbLnTFjxjs2my3P5/N5ZVm2PPXUU5MqKyuP
iE0R6ptQKBRet27d78BBq+2MGTPeNZlMda5Mjhs37g497Zc+D1u2bNnu4YcfvrGuZSEIgiAIIj4Z
pYXZunVrqVGp1a1ZvXv3Hrx8+fKmN9544+jt27fvFQSBRXbtYoCm3FksFvn6668fdf311z9oVBRW
rly5zOfzJVXqmjRp0kZfurdarbYbbrhhfLI0UNHL94nysupjuvzyy3suXbr0V4vFIhvTQTHGmCAI
jHPOs7KyLP369Tv/3nvvnWrcWGH79u3rt2/ffiCRTFar1da2bdtOxowSjz322GGJnJMhCELS5fl0
U5dFZ7lItMtXgjaSpiFLRDgcxocffvhm27ZtT9KPtW7dusN33333f6NGjbqmvLzcr9+H6PvLGGPh
cDjMOYfVajV5PJ49Ru8KISr6K9n1KSsrC44ePbrfq6+++qnRJeH2229/dsaMGW+tW7cu47QkBEEQ
BEHUHBkptoFAIDxlypS7xo8f/4ieokq3qnXq1KnHt99+uzZZG7oiqG+Fe+utt16fiv6lK12yLFtW
rly57K+//kpbqUiU11VXTl977bWFqbanL5XrAWAXXnjh2ansfqaqqqJbnj/88MPpe/fu9aU8iDRI
N/9rtLKcSR7gVHx/k/Hyyy+/fvvttz/r9XpLc3NzC1RVVbp169Z75cqVCfODRpOXl2cuKyur8pmO
VmxTGd9rr732+UMPPbS5YcOGRUYXnB9//HFVUVFRcU1uHEEQBEEQRGZknMj7tttue+Laa6+912q1
2rxebymgKYURa2ogXm7biKVX1BVhm82Wt3379vWLFy92R5dljMHn83l9Pt8hrgY+n68iNze30bhx
44anorQxxuD1eksrKirKRFGUQqFQIPq83+/3BYNBv9GvM9mWsqKGZLPZ8gBN2R48ePBZv/3229bo
ssFgMBhvLPn5+Zabb775tqQDieD1ekv9fn9FxHJ4iF8y5/wQRVsURSldxTYUCgWDwaA/FAr5I9ck
bYut3++v1K9hMBj0ZxKPtnnz5tKpU6feN3bs2PuMY4q+hglk8FosFlswGDzEehzUqBpfKhZtVVV5
7969u//+++/bysrK9uq5bXNzcxs99thjEydNmvRU2gMkCIIgCOLIIS8vT/7yyy/f49Xg559/Xmiz
2WLmOD3jjDPaJqqbavBOx44di431SktL9xgNqKIosuqMobS0dM/TTz99a+PGjePmvr3iiit6xKu/
cePGVaku1ffq1au9se7y5cu/Mp435rHVadq0acqbRQDAzTffPNBYf+TIkX3SqQ8A69evX2lso1Gj
RpbktQ5HEAQMHTr0XGPO5HSx2WyHPMA98MADY43nzzzzTHuq8syePfu5WH2cccYZbTMZH+WxJQiC
IIiao9qBOIwxNGzY0OJwOFqdcMIJx1mtVmuyOuFwOLxp06YtK1asWLtly5YyHsdgZrVaxbZt2xb5
/f5gVlaWxWw2m0KhkGIymaQtW7bs3rFjR0qWO4vFInTt2vW48vLySlmWTWVlZd41a9Ycsnd3bm6u
zBhjPJ4wMcbNOYeiKGGfz6cks0jm5ubKbdq0KQoEAiGTySTp9bOyssxr167dtm/fvqTb4wFATk6O
qVOnTq28Xm+lyWSS9uzZU7Zx48b9Rrny8vLMjDGEw2FIkiSUlJT40rGYyrIsWK1WSVVVLooiq6ys
DIVCobQUr5ycHJMoigLnnAuCwEpLSwMpXtqYiKLIrFarqKdN069fIiJ9C2VlZYf0bTabhaysLJOq
qmFBEASv1xtM1ZVAkiTWoEEDWVVVrvfBGGOqqoa9Xm/agX9GhTbrlEWUZYEgCIIgqgH9kBJEPUKK
LUEQBEHUHDW3NyhBEARBEARB1COk2BIEQRAEQRD/CEixJQiCIAiCIP4RkGJLEARBEARB/CMgxZYg
CIIgCIL4R0CKLUEQBEEQBPGPgBRbgiAIgiAI4h8BKbYEQRAEQRDEPwJSbAmCIAiCIIh/BKTYEgRB
EARBEP8ISLElCIIgCIIg/hGQYksQBEEQBEH8IyDFliAIgiAIgvhHIGVcUZLYVVdd1es///nPpaIo
in6/3/fkk08+6XK5tnDOAQAmk4ndd9991xcUFBRKkiSbzWZLIBDwW63W7FGjRk2srKxUAaB58+YN
Jk2adH1eXl4jURRFn89XkZOTk/vGG2+89tlnn/2m99m6deuGEyZMuLZly5ZtFUUJvfXWW7M+/PDD
H8PhMAAgPz/fcuedd16Xl5eXL8uyJRwOqyaTSVZVVd23b9/uyZMnP1NRUaEwxjBp0qQhdrv9hOzs
7AbhcFj1+XwVeXl5+ddcc82EyspKpXPnzscGAoHQypUrdxjHnZeXZz7zzDM7fvzxx8sBoEuXLi12
7dpVumXLljJjOZPJxO6///5x77zzzvzff/99OwCccsopzYcNG3ZVbm5ufqSMvGXLlg1PP/30K7t3
7/ZFX2PGGB5++OEbvvrqq68XL168KtZ9aNGiRd6YMWOGNGvWrKWiKCFBEIR9+/btefDBB6eUlZUF
Y9UxmUzs8ccfn5Sbm9tQEARBUZRQOBxW/X6//+WXX56xZs2aPQDQs2fPditWrFi/f//+gLF+Tk6O
6Y477hgzY8aMORs2bCjRj3fv3r3NNddcc7WiKEpWVpZNEASxsrLS+913330ze/bsJQBgs9mkBx54
4Obc3NyGZrPZEgqFglarNeuHH3749rnnnpsHAFdccUWPnj17nhOZZ7IgCMIvv/zyw8yZMz/x+/2q
3p8gCPjPf/7TdfTo0dcHAgH/3r17dz799NMvrl27do8+Xx544IHJPp+vIhgMBsrLy8sbNWpUkJ2d
3eDLL7/8vxkzZnwuiiJ78MEHxzVt2rSFfv3C4XD4rbfeeuvrr79ebRy3JEmsX79+XUaPHn29oigh
r9db/sILL7zw448/boh1nQmCIAiCOAoQBAH79u3b+eKLL97ToUOHxu3bt2982mmntdm5c+emiRMn
DtLLZWVliZxzfs4557RzOp3HdunSpUWXLl1anHrqqa0lSWJ6uZ49e7b74osvZnfo0KFxly5dWnTr
1q1Vt27dWhUVFWXpZU466aQmnHM+YMCAU0844YTCjh07Fn/zzTcLvvzyy/cYY1Vl3G730pNOOqlJ
t27dWnXu3PnYLl26tOjUqVOzbdu2/dWsWbMcQFMY9+3bt/Pyyy8//eSTT27WtWvXlk6n89hu3bq1
kmVZAIDx48dfMmzYsPOix96uXbui995770X9/4kTJw7q0aOHPbrcpEmTBnPO+ZgxYy7Uj919993D
33vvvRc7dOjQuGvXri1POumkJsOHD+/NOedms/kw63lhYaGVc843bty4Sh+jkU6dOjXjnPO+ffue
fMoppzTv1q1bq06dOjXbsmXL2tatWzeMd/+ysrKkQCDg69q1a0u9nj6ukSNH9tHLvfzyy/9t27Zt
o+j6//vf/27W76vx+HPPPXfHY489NsHhcDTp3r17m5NPPrnZxIkTB61atepHvUyzZs1ydu7cuenk
k09ups+Hrl27tjT288UXX8z+73//O+qkk05qctppp7VxOp3HPvbYYxMCgYBPFMWqC/H+++9PXbVq
1Y+nnHJK844dOxafddZZx3POeffu3dsAQIMGDUzdu3dv065du6Knn376VrfbvdThcDTp0qVLi1at
WjUEAIvFInLO+RlnnNG2a9euLTt37nxst27dWm3ZsmXtqFGj+up9CYKAjRs3rpo9e/ZzHTt2LNbb
2bZt21/333//tfGudTIqfz2P63+ZtkEQBEEQRDU4/vjjCxctWjQ3+rgkSYxzznWl1Wq1im63e2my
9s4+++wT+/bte3KiMhs3blzVunXrfOMxQRDAOefZ2dkSALRv377xzTffPDBW/aeffvrWJk2a2ABN
sV21atWPRiUpmiuuuKLH5Zdffnr08TZt2uQ/99xzd+j/jxw5ss+pp57a2lgmOztb+vLLL9/r1atX
+6FDh56rH580adLgLl26tIhuc/bs2c+dcMIJhdHHr7/++v7nn3/+SQ8//PA4XXYjy5cv/yqWAjtx
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
u3bLhRdeeFn0cVEU2dixY++JVqAZY/GUah4MBgPRc5RzDrPZbNGV4d9//33VmWeeeWYsWTp27Nj1
wIEDZLElCIIgiHomI8X2559/XvfEE0+8VVBQYNV1BcYY+vTpc3JFRUW5z+dTAS3iXBRFSZZlIfKe
CYKASy655PQ///zTpSsToVAo1KpVqxaMsaoyoihW6SGcc8ydO/fFZ5555i6jJa6goMA6bNiw29eu
XbsL0HxzkwROVWkvJpNJzsnJkfU+9b9kYzeZTKIxo8DevXv3jhkzZtiAAQMGffvtt38mquvz+SqL
i4uPMfYpSRJ78sknn16yZMl3+nV85pln3unbt+9Fd99994vXXXfd/aNHj558//33T+/du3fXCRMm
VOWALS4utjVp0qT1b7/99rexH1mWZT2ALxZnn332SR6PZ2X0cVEUxcrKygr9/927d+95/PHHH8jJ
ycndsGHDIanWIpbOqhRX5557bsdFixa9C2j3XZIkxhhDo0aNsnNycnL1+8Y5R+PGjZvq9zjetY+2
uEazffv2sj59+lzVvn37KisqYwzDhg3rs2TJko+iH1oigYVxH3pMJhOTJIlJksQEQUDHjh2LO3bs
2D0QCKgAsGrVqr9vv/32Z4855pgs45zv2bNnu1atWrWrqKiotlsEQRAEQRD1RO/evR2cc15aWrrH
4/H8VllZWb5t27a/8vLyqpQdi8UiKIoS2rZt21+BQMCn/23btu2vnJycKsXr1FNPbc0551u2bFlb
WVlZXlpauodzzidMmFBlkZNlWVi6dOmnnHO+fv36lRs3blzFOec9e/as2v3qxBNPLIqVhB84dPMA
xhj+/PPP5ZWVleXl5eX7KysryysrK8sDgYDPYrHEdYkAtG1ap02bdp/+/2WXXXYa55zb7faC6LLt
2rUruuOOO67W/x87dux/OOd83759OwOBgK+8vHw/55y/9957L+qKXFFRUXa8ncZkWRZ27ty5SVcC
3W73Un2XLSOTJ08eEb2ZhY6+01lxcfFhuWQvuuiiLuPGjbtY/3/ChAmXcc55QUGBNbps//79u+ob
WDRq1MjCOec7d+7cZLyWlZWV5Tt37tzEOefnnXdeRwBo2rRpjj5vAoGAr7S0dI+iKCHjbm6LFi2a
W1xcnB1LfiN2u72Ac8537969ddWqVT+Wl5fv37Zt219ZWVmHuWG0b9++cawdwsxms2CUhxto06bN
IdfwtNNOa6OX/fPPP5cHAgHfzp07NxUWFh52fQiCIAiCOMqQJInl5+ebCwsLrQ0aNDDFUsZMJhOT
ZVnQX81m82E5SgVBgNlsFkwmE9P/dCuvEcYYsrKypIYNG5obNmxojrbyMcbiWvp0C2IsuYx/ycbM
GINxO2BBEKBvwxurrFFGURSZ2WwWjNcjus/o9qMx9hWvX6O1OxrdmhrvnFFeQRAQ75oYrayFhYXW
2bNnPxd9TWVZFkRRZJdffvnp/fv376qPL9Z1N/YTfa8SIYoiy8vLkxs2bGi22Wwx56DebzyLvCRJ
zGixNZlMLN48EgQBDRo0MOXn55ttNpuUqpwEQRAEQdQ+Gaf7AjTf15KSksPSRhkJhUIcB10AYvq0
hsNhGFNdxSvLOUdlZaVSWVkZL59o3KwJ0dkPouRKGc75IW2Fw2EEg8GY/qyc8+g8uzxqiTzmGBNl
ajD2Fa/fRL7D4XA4btqqiMssT6WssQ9BENimTZvWxbimHADWrVu3+fjjj28JVGWKiOv/Cxx+rxKh
qiovLS1NGrgVfS8y7S8cDuPAgQMJfYQJgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAI
giAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAI
giAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgiAIgji6+H/TkAfxGC984gAA
AABJRU5ErkJggg==
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
sed -e 's/ quiet splash loglevel=3/ splash loglevel=3 plymouth.ignore-serial-consoles console=tty0 console=ttyS0,115200 systemd.debug-shell=\/dev\/ttyS0 systemd.mask=serial-getty@ttyS0.service/' /work/kit/boot/grub.cfg > /work/grub-debug.cfg
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
4d430205a85bdb784ba1481e2668d5aa7e68eb64d1d4dcdd7180f934546e4900  README.md
8d37e3a11f5e447201cef7a58b14e2afc8c2b121a1aae8d901cc5bc61e22a4c5  boot/early.cfg
4565ee7716565c5ea7140532d2911ce5775854140107543c6f5e0bf2d933c5c1  boot/grub.cfg
dd028468a5d7a13cf9e7776142400c8c110ded810d2b6f6d703eb6473d61fb31  build-all.sh
08f9ac29be737ac8912b27f37be6d4fdee81e347e849041bd8bc40d46a41533a  build-image.sh
97af9a4cd0b685dfbcc0ffa1059f8dfe521a0d110f415cb1e8e6db49ffc882f4  build-rootfs.sh
e886c5e71db566ca3c99f97d6de4c4823ff141e7b225e23d3c79811d708eb3df  make-banner.py
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-dns-resolved.conf
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-globally-managed-devices.conf
daecdafe66e474402395c4fb23eb20bb1db1bf45fc8a1da89d286a57570a869e  overlay/etc/NetworkManager/conf.d/kiosk.conf
7a6730e8648c5d4168ba77af4b141db76c7c6abac8eb1becd4a4488b81d5b74b  overlay/etc/X11/xorg.conf.d/10-kiosk.conf
c20cd567970bb1fd7364af1e68baeb47ad8be67a8ab8766a1ff2031c5141d9cc  overlay/etc/fstab
48bef90bf3804ed0a3a3a2ad6cb6c2a0ccd06ab0d169e55aba89f92943add2de  overlay/etc/hostname
cbb744dfe78c96d93f84e4e2c6fcce992f8b52e40ee91d504322035bafed3ca4  overlay/etc/initramfs-tools/hooks/kiosk-branding
32a8e2543d8c40621207401aeea2d7a03e5aaf2d031239f474c0bc918b3f0de0  overlay/etc/initramfs-tools/scripts/init-premount/branding
6aa4e808e51d10a1b8a6f5cc72d1a850251c483a314da0d6f9d8e6923c0448ae  overlay/etc/plymouth/plymouthd.conf
21f5338821e1921d916444ec33b1770db087c3f68b1122e7b64ab77745ed177d  overlay/etc/polkit-1/rules.d/50-kiosk-install.rules
8e1cebeaa97f7d2b59e078ffe5c6cb10ad144049277e37d83ef7cecfcf0a0afd  overlay/etc/polkit-1/rules.d/50-kiosk.rules
1a25306c51ebefbe547f20a43603bbbadf8f2464f510ff755445a7a70a1f2733  overlay/etc/sysctl.d/90-kiosk.conf
b86aaef6227a5824e04d89c3ce772d8479fadd5e6a1e13d908cce627bfd5f7cc  overlay/etc/systemd/journald.conf.d/kiosk.conf
9a8764b2132a80abcc30d5a6a30180a90177ba8eddf0741d0455349a5ddfded8  overlay/etc/systemd/logind.conf.d/kiosk.conf
4368449caebff4de8fb38f73787b63c7a575aa49862f6921de34a28d4764b8d3  overlay/etc/systemd/system/NetworkManager.service.d/kiosk.conf
41f6a7b7e7d48646734c2c937f4fc1eef56102048a63420d349bb6d2155af230  overlay/etc/systemd/system/kiosk-growdata.service
55b5a21eed1da4036179f980fb451706cd893e5e6e69d869df2e504437cdffb0  overlay/etc/systemd/system/kiosk-install@.service
d4db23ce84e7d5022994b9d7371ea664ff9fd4d80140ec7a3a0f017a8a8405dd  overlay/etc/systemd/system/kiosk.service
6a2a46a868a19fdbab9db2c85831059c428cfabc94ad9b461b8a6c4a4f07c6b4  overlay/etc/udev/rules.d/90-kiosk-usb.rules
1f17b5c77234ae4a3fd96e06cb281da61a6293b61740e927765bd5e47d2fe266  overlay/opt/kiosk/installer.py
9faf7360378d45fafe220b7c60a7b2b9995166a744f90ea8f59f49260021e326  overlay/opt/kiosk/kiosk.py
a903543768178e611125db6cdf98020817466892fb4da56a4b2b6df2f8a4cba3  overlay/opt/kiosk/rc.xml
a5ca420724b24e64d6e864d810f188d2691d4e7998475a4d9ffc23fa385245fd  overlay/opt/kiosk/session.sh
d4d40b3b3e3b1aab78c7ed02ab05398c6a91db8a94d9a13e4e6dd2a370a25918  overlay/usr/local/sbin/kiosk-growdata
46b7264725c9a1b41bc8abc91d82bca985b91321ea07bc8334d210f6c829ae6d  overlay/usr/local/sbin/kiosk-install
ebc16ec94d925dc37f11ceeb5342fca23b66e5949e8a2020c6c0ebd03dff3a8e  overlay/usr/share/plymouth/themes/sibintek-nologo/sibintek-nologo.plymouth
980055f32603462384baae4a3dbfa580f0579627bb98c190f84443a047126613  overlay/usr/share/plymouth/themes/sibintek/animation-0001.png
980055f32603462384baae4a3dbfa580f0579627bb98c190f84443a047126613  overlay/usr/share/plymouth/themes/sibintek/bgrt-fallback.png
bc9d5b39c160104db283949e42ed5eb77b482e5bb4c72837431d0ecb80b02c02  overlay/usr/share/plymouth/themes/sibintek/sibintek.plymouth
31fb7c2f5de3fb524287e6f5c29fbf2d70d7b89c70ca04d6c46523d7c8702a1b  overlay/usr/share/plymouth/themes/sibintek/watermark.png
dc93ad2c237cc7438df51f4347afc98ab4f4dbc0767beb5c11146ba3b8d8594e  test/mk-test-image.sh
e76eb83ffb324ff644b69fb65d8ab6cec97d35369d2a1056bc9513a397b5360a  test/qmon.py
d39714cda94e064594b9aac27d7931c744d1354fc4440fba6b3f3f8c2776fbd8  test/rdpsrv.sh
8f60e334c5e53654d1c6a2083341465866a11326e0d90520c91fa3faa25dc23d  test/run-qemu.sh
046a8b46568db8a62e395a65e470af520544396c4df7e9b5f68b93d3c2c96f13  test/ser.py
43bdaf2e4726e98fec849d41c687a8fb5ddca3feb96fb45524fa4b82b6d804ae  test/uitest.py
f666170a9c3910d292a7c41229b33be88c014765909be84f9a001322096c9da4  test/uitest.sh
35ecd03f14be2d2a19da60dd3594b28e7518e52bf15ada8a50718275b71eca1c  test/vncsrv.sh
__KIT_EOF__
( cd "$DEST" && sha256sum -c --quiet .manifest.sha256 ) || { echo "ERROR: the script was damaged during copying (checksum mismatch). Re-download it." >&2; exit 1; }
chmod +x "$DEST/build-all.sh" "$DEST/build-rootfs.sh" "$DEST/build-image.sh" "$DEST/overlay/opt/kiosk/kiosk.py" "$DEST/overlay/opt/kiosk/session.sh" "$DEST/overlay/opt/kiosk/installer.py" "$DEST/overlay/usr/local/sbin/kiosk-growdata" "$DEST/overlay/usr/local/sbin/kiosk-install" "$DEST/overlay/etc/initramfs-tools/hooks/kiosk-branding" "$DEST/overlay/etc/initramfs-tools/scripts/init-premount/branding"
[ -n "${KIT_ONLY:-}" ] && { echo "kit unpacked (KIT_ONLY set), not building"; exit 0; }
exec sh "$DEST/build-all.sh" "${1:-$PWD/out}"
