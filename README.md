# DemoLoop

Turn your legacy iOS device into an authentic store-style demo unit.

DemoLoop plays a fullscreen, looping video, hides everything else, keeps the screen awake and
starts itself after a reboot (or if it gets closed). A jailbreak tweak by **TehFocs**.

> Not affiliated with or endorsed by Apple Inc.

*Русская версия ниже / Russian version below.*

## Compatibility

iOS 6.0 - 8.4.1 on 32-bit (armv7) devices. A jailbreak is required.

| Device | iOS | Status |
|---|---|---|
| iPhone 4 | 6.0 (v1.3.x), 7.0 (v1.0) | tested |
| iPad mini 1 | 8.4.1 | tested |
| iPhone 3GS / 4S / 5 / 5c, iPod touch 4 / 5, iPad 2 / 3 / 4 | 6 - 8 | should work, not tested yet |

Autostart needs the **Open** package (`com.conradkramer.open`). Cydia pulls it in as a dependency;
if it does not, install it by hand.

## Install

**Option A - Cydia source.** Cydia -> Sources -> Edit -> Add:

```
https://<username>.github.io/<repo>/
```

Then open the source and install **DemoLoop**.

**Option B - .deb file.** Download the latest `.deb` (the `debs/` folder or the Releases page), copy it to
the device (iFile / Filza / SFTP) and install it, or run `dpkg -i com.demoloop.app_*.deb` over SSH.
Use this if Cydia on a very old iOS cannot open the HTTPS source.

## Usage

1. Copy your video (`.mp4`, `.mov` or `.m4v`) into `/Library/Application Support/DemoLoop/`
   (create the folder if it is missing). If there are several files, the first one by name is played.
2. Respring / reboot, or open **Demo Loop**. The video starts by itself and loops forever.
3. The first launch shows built-in instructions (English / Russian) with a detailed guide and video sizes.

Settings > General > Auto-Lock > **Never**, turn the passcode off and keep the device on a charger.

### Controls

| Action | Result |
|---|---|
| 5 taps in the top-left corner | exit and pause the demo (tap the app icon to resume) |
| 5 taps in the top-right corner | show the instructions again |
| Home button | the app closes, the background service restarts it in about 5 seconds |

### Optional flag files

Create an empty file in the video folder:

- `fill` - crop the video to cover the whole screen (no black bars)
- `pause` - created by the exit gesture; delete it, or open the app icon, to resume

Sound is muted by default. A landscape video is rotated to fill the portrait screen, so lay the device on its side.

### Recommended video size (H.264, MP4 / MOV, 24-30 fps, portrait)

| Device | Video |
|---|---|
| iPhone 3GS | 320x480 |
| iPhone 4, 4S, iPod touch 4 | 640x960 |
| iPhone 5, 5c, iPod touch 5 | 640x1136 |
| iPad 2, iPad mini | 768x1024 |
| iPad 3, iPad 4 | 1080x1440 (the screen is 1536x2048, but video larger than 1080p may not play) |

Convert any video with ffmpeg (iPad 2 / mini example, keeps the aspect ratio and adds black bars):

```
ffmpeg -i in.mp4 -vf "scale=768:1024:force_original_aspect_ratio=decrease,pad=768:1024:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -profile:v main -level 3.1 -crf 20 -c:a aac out.mp4
```

## How it works

- `DemoLoop.app` - an AVPlayer fullscreen loop, idle timer disabled, a watchdog that restarts playback.
- `/usr/libexec/demoloop-launcher` started by a LaunchDaemon - waits for SpringBoard, then keeps the app running
  while a video exists and there is no `pause` file. It also creates the video folder.

## Uninstall

Cydia -> Installed -> DemoLoop -> Remove. Your videos stay in the folder.

## Build from source

No Theos or Xcode needed. You need an iOS clang/ld toolchain (for example the one Theos downloads),
`iPhoneOS9.3.sdk` from [theos/sdks](https://github.com/theos/sdks) and `dpkg-deb`:

```
cd src
TOOLCHAIN=/path/to/toolchain/linux/iphone SDK=/path/to/iPhoneOS9.3.sdk ./build.sh
```

The `.deb` appears in `src/build/`. To publish it as a Cydia repo, copy it to `debs/` and run
`python3 update-repo.py`.

## Publish this repo on GitHub Pages

1. Push the contents of this folder to a GitHub repository.
2. Settings -> Pages -> Deploy from a branch -> `main` / `(root)`.
3. Your source is `https://<username>.github.io/<repo>/`.

---

## Русский

**DemoLoop** превращает старое iOS-устройство в демо-аппарат как в магазине: видео на весь экран по кругу,
экран не гаснет, после перезагрузки всё стартует само.

**Совместимость:** iOS 6.0 - 8.4.1, 32-битные устройства, нужен джейлбрейк. Проверено: iPhone 4 (iOS 6.0, 7.0),
iPad mini 1 (iOS 8.4.1). Остальные (iPhone 3GS/4S/5/5c, iPod touch 4/5, iPad 2/3/4) должны работать, но пока не проверялись.

**Установка:** добавь источник `https://<username>.github.io/<repo>/` в Cydia или скачай `.deb` из папки `debs/`
и поставь через iFile / Filza / `dpkg -i`. Для автозапуска нужен пакет **Open**.

**Использование:**
1. Положи видео (`.mp4`, `.mov` или `.m4v`) в `/Library/Application Support/DemoLoop/` (создай папку, если её нет).
2. Сделай респринг или перезагрузку, либо открой **Demo Loop**.
3. При первом запуске показывается инструкция (EN/RU) с подробным руководством и размерами видео.

**Жесты:** 5 тапов в левом верхнем углу - выход и пауза; 5 тапов в правом верхнем углу - показать инструкцию.
Файл `fill` в папке с видео обрезает видео на весь экран. Размеры видео для каждого устройства смотри в таблице выше.
