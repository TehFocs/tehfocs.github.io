# DemoLoop

**Turn your legacy iOS device into an authentic store-style demo unit.**

DemoLoop plays a fullscreen, looping video, hides everything else, keeps the screen awake and starts
itself after a reboot (or if it gets closed). A jailbreak tweak for iOS 6 - 8 by **TehFocs**.

> Not affiliated with or endorsed by Apple Inc.

*Русская версия ниже / Russian version below.*

## Features

- Fullscreen looping video (`.mp4`, `.mov`, `.m4v`), UI completely hidden
- **Automatic setup:** pick a video from Photos, DemoLoop copies it and starts playing
- **Manual setup:** drop a file into a folder, with built-in instructions (English / Russian)
- Starts by itself after boot and restarts if the app is closed
- Screen never sleeps, sound muted by default
- iPhone, iPod touch and iPad, iOS 6.0 - 8.4.1 (32-bit devices)

## Compatibility

A jailbreak is required. Only **32-bit (armv7)** devices are supported.

| Device | iOS | Status |
|---|---|---|
| iPhone 4 | 6.0, 7.0 (v1.0) | tested |
| iPad mini 1 | 8.4.1 | tested |
| iPhone 3GS / 4S / 5 / 5c, iPod touch 4 / 5, iPad 2 / 3 / 4 | 6 - 8 | should work, not tested yet |
| iPad 1 | **custom iOS 6.x firmware only** | should work, not tested yet |

Notes:
- The iPad 1 officially stops at iOS 5.1.1. It works only if you installed a custom iOS 6 firmware
  (for example with Legacy iOS Kit).
- "Choose from Photos" (automatic setup, v1.4) has been verified on an iPhone 4 with iOS 6.0 so far.
- Autostart needs the **Open** package (`com.conradkramer.open`). Cydia installs it as a dependency;
  if it does not, install it by hand.

## Install

### Option A: Cydia source (recommended)

Cydia -> **Sources** -> **Edit** -> **Add**, then enter:

```
https://tehfocs.github.io/
```

Open the source, tap **DemoLoop** -> **Install**. Updates will appear in Cydia -> **Changes**.

### Option B: .deb file

Download the latest `.deb` from the [Releases](../../releases) page or from the `debs/` folder, copy it to the
device (iFile / Filza / SFTP) and install it, or run `dpkg -i com.demoloop.app_*.deb` over SSH.
Use this if Cydia on a very old iOS cannot open the HTTPS source.

## Usage

1. Open **Demo Loop**. On the first launch you get a screen with two options:
   - **Automatic:** choose a video from Photos. DemoLoop copies it into its folder and starts the demo.
   - **Manual:** shows instructions for copying a video file into the folder yourself.
2. That's it. The video loops forever. After a reboot the demo starts by itself (about 30 seconds after the home screen appears).

Before leaving the device running: Settings -> General -> Auto-Lock -> **Never**, turn the passcode off and
keep it on a charger.

### Automatic setup (Photos)

- The video is copied (not moved), so you need free space equal to its size. DemoLoop checks this for you.
- The copy is saved as `DemoLoop-selected.mov` (or `.mp4`). It has priority over every other file in the folder.
  Delete it to go back to the other files.
- Videos that were synced from a computer may not show up in the picker. Copy such a file manually instead.

### Manual setup (folder)

Copy your video (`.mp4`, `.mov` or `.m4v`) into:

```
/Library/Application Support/DemoLoop/
```

Create the folder if it is missing (iFile / Filza). If there are several files, the first one by name is played.
The old folder `/var/mobile/Media/DemoLoop/` from v1.0 - 1.1 is still checked too.

### Controls

| Action | Result |
|---|---|
| 5 taps in the **top-left** corner | exit and pause the demo (open the app icon to resume) |
| 5 taps in the **top-right** corner | show the setup / instructions screen again |
| Home button | the app closes, the background service starts it again in about 5 seconds |

### Optional flag files

Create an empty file in the video folder:

| File | Effect |
|---|---|
| `fill` | crop the video to cover the whole screen (no black bars) |
| `pause` | created by the exit gesture; delete it (or open the app icon) to resume |

Sound is muted by default. A landscape video is rotated to fill the portrait screen, so lay the device on its side.

### Recommended video size

H.264 (MP4 / MOV), 24-30 fps, portrait orientation:

| Device | Video size |
|---|---|
| iPhone 3GS | 320x480 |
| iPhone 4, 4S, iPod touch 4 | 640x960 |
| iPhone 5, 5c, iPod touch 5 | 640x1136 |
| iPad 1 (custom iOS 6), iPad 2, iPad mini | 768x1024 |
| iPad 3, iPad 4 | 1080x1440 (the screen is 1536x2048, but video larger than 1080p may not play) |

Convert any video with [ffmpeg](https://ffmpeg.org) (iPad 2 / mini example; keeps the aspect ratio and adds black bars):

```
ffmpeg -i in.mp4 -vf "scale=768:1024:force_original_aspect_ratio=decrease,pad=768:1024:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -profile:v main -level 3.1 -crf 20 -c:a aac out.mp4
```

## Troubleshooting

| Problem | What to do |
|---|---|
| I only see the instructions screen | No video was found. Choose one from Photos or copy a file into the folder. |
| The video does not play | Use H.264 in an MP4 / MOV container and a size from the table above. Very large files can fail on old devices. |
| It does not start after a reboot | Make sure the **Open** package is installed, wait about 30 seconds after the home screen appears, and check that there is no `pause` file in the folder. |
| I cannot leave the demo | Tap 5 times in the top-left corner. |
| The folder does not exist | DemoLoop and its background service create it. If it is still missing, create it by hand. |
| Cydia cannot open the source | Very old iOS may not trust the HTTPS certificate. Install the `.deb` file (Option B). |
| Quality looks worse after choosing from Photos | Copy the original file into the folder manually. |

## How it works

- `DemoLoop.app` plays the video fullscreen with AVPlayer, keeps the idle timer disabled and has a watchdog that
  restarts playback if it stops.
- `/usr/libexec/demoloop-launcher`, started by a LaunchDaemon, waits for SpringBoard and then keeps the app running while
  a video exists and there is no `pause` file. It also creates the video folder.

## Uninstall

Cydia -> Installed -> DemoLoop -> Remove. Your videos stay in the folder.

## Build from source

No Theos or Xcode needed. You need an iOS clang/ld toolchain (for example the one Theos downloads),
`iPhoneOS9.3.sdk` from [theos/sdks](https://github.com/theos/sdks) and `dpkg-deb`:

```
cd src
TOOLCHAIN=/path/to/toolchain/linux/iphone SDK=/path/to/iPhoneOS9.3.sdk ./build.sh
```

The `.deb` appears in `src/build/`. To publish it in the Cydia repo, copy it to `debs/` and run `python3 update-repo.py`.

## Changelog

- **1.4** - first-launch screen (Automatic / Manual), automatic setup from Photos, free-space check, stricter folder permissions
- **1.3.1** - fixed overlapping screens on iOS 6
- **1.3** - settings-style instruction screen (English / Russian) with a detailed guide and video sizes, shown on first launch
- **1.2** - new icon, folder moved to `/Library/Application Support/DemoLoop`, any file name, fixed Cydia description
- **1.1** - iOS 6 support, iPhone 5 screen, iPad
- **1.0** - first version (iOS 7)

---

# DemoLoop (на русском)

**Превращает старое iOS-устройство в демо-аппарат, как в магазине.**

DemoLoop крутит видео на весь экран по кругу, прячет остальной интерфейс, не даёт экрану гаснуть и сам
запускается после перезагрузки или если его закрыли. Твик для iOS 6 - 8 от **TehFocs**.

> Не связан с Apple Inc. и не одобрен ею.

## Возможности

- Видео (`.mp4`, `.mov`, `.m4v`) на весь экран по кругу, интерфейс полностью скрыт
- **Автоматическая настройка:** выбираешь видео в галерее, DemoLoop копирует его и запускает
- **Ручная настройка:** кладёшь файл в папку, есть встроенная инструкция (русский / английский)
- Запускается сам после включения и перезапускается, если приложение закрыли
- Экран не гаснет, звук по умолчанию выключен
- iPhone, iPod touch и iPad, iOS 6.0 - 8.4.1 (32-битные устройства)

## Совместимость

Нужен джейлбрейк. Поддерживаются только **32-битные (armv7)** устройства.

| Устройство | iOS | Статус |
|---|---|---|
| iPhone 4 | 6.0, 7.0 (v1.0) | проверено |
| iPad mini 1 | 8.4.1 | проверено |
| iPhone 3GS / 4S / 5 / 5c, iPod touch 4 / 5, iPad 2 / 3 / 4 | 6 - 8 | должно работать, пока не проверялось |
| iPad 1 | **только кастомная прошивка iOS 6.x** | должно работать, пока не проверялось |

Примечания:
- Официально iPad 1 заканчивается на iOS 5.1.1. Твик работает, только если ты поставил кастомную прошивку iOS 6
  (например, через Legacy iOS Kit).
- Выбор из галереи (автоматическая настройка, v1.4) пока проверен на iPhone 4 с iOS 6.0.
- Для автозапуска нужен пакет **Open** (`com.conradkramer.open`). Cydia ставит его как зависимость,
  если нет, поставь вручную.

## Установка

### Вариант A: источник в Cydia (рекомендуется)

Cydia -> **Источники** -> **Правка** -> **Добавить**, введи:

```
https://tehfocs.github.io/
```

Открой источник, нажми **DemoLoop** -> **Установить**. Обновления появятся в Cydia на вкладке **Изменения**.

### Вариант B: .deb файл

Скачай последний `.deb` на странице [Releases](../../releases) или из папки `debs/`, скопируй на устройство
(iFile / Filza / SFTP) и установи, либо выполни по SSH `dpkg -i com.demoloop.app_*.deb`.
Подходит, если Cydia на очень старой iOS не открывает HTTPS-источник.

## Использование

1. Открой **Demo Loop**. При первом запуске появится экран с двумя вариантами:
   - **Автоматически:** выбираешь видео из галереи. DemoLoop копирует его в свою папку и запускает демо.
   - **Вручную:** инструкция, как самому положить видеофайл в папку.
2. Всё. Видео играет по кругу. После перезагрузки демо стартует само (примерно через 30 секунд после появления домашнего экрана).

Перед тем как оставить устройство работать: Настройки -> Основные -> Автоблокировка -> **Никогда**, отключи пароль
и поставь на зарядку.

### Автоматическая настройка (галерея)

- Видео копируется, а не переносится, поэтому нужно свободное место, равное его размеру. DemoLoop проверяет это сам.
- Копия сохраняется как `DemoLoop-selected.mov` (или `.mp4`) и главнее всех остальных файлов в папке.
  Удали её, чтобы вернуться к другим файлам.
- Видео, залитые с компьютера, могут не показываться в выборе. Такой файл скопируй вручную.

### Ручная настройка (папка)

Скопируй видео (`.mp4`, `.mov` или `.m4v`) в:

```
/Library/Application Support/DemoLoop/
```

Если папки нет, создай её (iFile / Filza). Если файлов несколько, играет первый по имени.
Старая папка `/var/mobile/Media/DemoLoop/` из версий 1.0 - 1.1 тоже проверяется.

### Управление

| Действие | Результат |
|---|---|
| 5 тапов в **левом верхнем** углу | выйти и поставить демо на паузу (открой иконку приложения, чтобы продолжить) |
| 5 тапов в **правом верхнем** углу | снова показать экран настройки и инструкцию |
| Кнопка Home | приложение закроется, служба запустит его снова секунд через 5 |

### Необязательные файлы-флаги

Создай пустой файл в папке с видео:

| Файл | Эффект |
|---|---|
| `fill` | обрезать видео и закрыть весь экран (без чёрных полос) |
| `pause` | создаётся жестом выхода; удали его (или открой иконку), чтобы продолжить |

Звук по умолчанию выключен. Горизонтальное видео поворачивается на весь вертикальный экран, поэтому положи устройство на бок.

### Рекомендуемый размер видео

H.264 (MP4 / MOV), 24-30 кадров/с, вертикальная ориентация:

| Устройство | Размер видео |
|---|---|
| iPhone 3GS | 320x480 |
| iPhone 4, 4S, iPod touch 4 | 640x960 |
| iPhone 5, 5c, iPod touch 5 | 640x1136 |
| iPad 1 (кастомная iOS 6), iPad 2, iPad mini | 768x1024 |
| iPad 3, iPad 4 | 1080x1440 (экран 1536x2048, но видео больше 1080p может не воспроизводиться) |

Команду для ffmpeg смотри в английской части выше.

## Если что-то не работает

| Проблема | Что делать |
|---|---|
| Вижу только экран с инструкцией | Видео не найдено. Выбери его в галерее или скопируй файл в папку. |
| Видео не играет | Используй H.264 в контейнере MP4 / MOV и размер из таблицы. Очень большие файлы на старых устройствах могут не идти. |
| Не запускается после перезагрузки | Проверь, что установлен пакет **Open**, подожди секунд 30 после появления домашнего экрана и убедись, что в папке нет файла `pause`. |
| Не могу выйти из демо | Сделай 5 тапов в левом верхнем углу. |
| Папки нет | DemoLoop и его служба создают её сами. Если всё равно нет, создай вручную. |
| Cydia не открывает источник | Очень старая iOS может не доверять HTTPS-сертификату. Поставь `.deb` (вариант B). |
| После выбора из галереи качество хуже | Скопируй оригинальный файл в папку вручную. |

## Удаление

Cydia -> Установлено -> DemoLoop -> Удалить. Твои видео останутся в папке.

## Список изменений

- **1.4** - экран первого запуска (Автоматически / Вручную), автоматическая настройка из галереи, проверка свободного места, более строгие права на папку
- **1.3.1** - исправлено наслоение экранов на iOS 6
- **1.3** - инструкция в стиле настроек (русский / английский) с подробным руководством и размерами видео, показывается при первом запуске
- **1.2** - новая иконка, папка перенесена в `/Library/Application Support/DemoLoop`, любое имя файла, исправлено описание в Cydia
- **1.1** - поддержка iOS 6, экран iPhone 5, iPad
- **1.0** - первая версия (iOS 7)
