# Echo

<img src="Assets/Echo.png" alt="Echo clipboard icon" width="128" />

A lightweight, native macOS clipboard history app. Find a previous clip, press Return, and paste it into the app you were using.

## Features

- Keeps your latest 300 text and image clips, plus pinned clips, locally on your Mac.
- Search history and filter by text or images.
- Compact, resizable popup near the text caret, with a mouse-position fallback.
- Navigate clips with arrow keys and paste with Return or a click.
- Customizable global shortcut; defaults to **⌘⇧V**.
- Pin frequently used clips at the top, or remove individual clips.
- Edit a text clip in place or save a fragment as a new clip.
- Give text clips searchable aliases and optionally hide their contents.
- Native light and dark appearance, keyboard focus indicators, and accessible controls.
- Settings and history clearing from the popup or menu bar.

## Requirements

macOS 13 or later and Apple's Swift toolchain (Xcode or Command Line Tools).
There are no third-party package dependencies.

## Build and run

```sh
git clone https://github.com/bufferBrew/echo.git
cd echo
./build.sh
open /Applications/Echo.app
```

The script builds a release binary, assembles and signs `Echo.app`, and installs it in `/Applications`. To build without installing:

```sh
./build.sh --no-install
open Echo.app
```

## Usage

1. Launch Echo; it lives in the menu bar.
2. Copy text or an image in any app.
3. Place the caret in your destination and press **⌘⇧V**, or click Echo's menu bar icon.
4. Search, use **↑/↓** to select a clip, then press **Return** to paste. Clicking a clip also pastes it.
5. Press **Escape** to dismiss, **⌘F** to focus search, or **⌘,** to open settings.

Automatic paste requires **System Settings → Privacy & Security → Accessibility → Echo**. Without permission, selecting a clip still copies it to the clipboard so you can paste with **⌘V**. Ad-hoc builds can require granting permission again after rebuilding; see [stable local signing](SIGNING.md).

## Clip actions

Open the **…** menu beside a clip, or right-click it:

- **Pin to Top / Unpin** keeps a clip available beyond normal history cleanup.
- **Edit Clip…** changes a text clip in place; **Edit as New Clip…** creates a separate entry and preserves the original.
- **Remove from History** deletes a clip and its saved image, if any.

In the text editor, add an optional **alias** for commonly used text. Enable **Hide clip contents** and provide an alias to display only that alias in the popup. Hidden clips are searchable by alias rather than their contents and still paste their full text. The editor masks hidden text until you choose **Show text in editor**.

Hiding is a display feature: history is stored **unencrypted** on your Mac. Echo is not a password vault. **Clear History…** removes pinned clips too. Removing history does not erase text already on the system clipboard or in another app.

## Local storage

History and images are stored in `~/Library/Application Support/Echo`. History is persisted as JSON and images as PNG files. The app has no network service or account; clips stay on your Mac. Clear saved clips using **Clear History…** in Echo's menu.

## Navigation checks

```sh
swiftc Sources/Echo/ClipboardItem.swift Sources/Echo/HistoryViewModel.swift Sources/Echo/HistoryStore.swift Tests/main.swift -o /tmp/echo-navigation-tests
/tmp/echo-navigation-tests
```

These checks cover filtering, selection, legacy history decoding, pinned retention, editing, hidden alias search, persistence, and image removal. Cross-app paste also requires a manual check in an editable destination with Accessibility permission enabled.
