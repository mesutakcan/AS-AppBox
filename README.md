# AS AppBox

[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey_v2-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-GPL_v3-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.1-brightgreen.svg)](https://github.com/mesutakcan/AS-AppBox/releases)

![GitHub stars](https://img.shields.io/github/stars/mesutakcan/AS-AppBox?style=social)
![GitHub forks](https://img.shields.io/github/forks/mesutakcan/AS-AppBox?style=social)
![GitHub issues](https://img.shields.io/github/issues/mesutakcan/AS-AppBox)
[![Downloads](https://img.shields.io/github/downloads/mesutakcan/AS-AppBox/total)](https://github.com/mesutakcan/AS-AppBox/releases)

AS AppBox is an application manager that helps you organize and quickly launch your favorite programs. Built with AutoHotkey v2, it offers a modern and user-friendly interface.\
![Screenshot](docs/ScreenShot-1.png)

## Features

- Add and remove applications from your list
- Run selected applications with one click
- Filter applications with real-time search (with cue banner text)
- Save and load your application list (UTF-8 encoding)
- Drag and drop support for adding apps
- Context menu for quick actions
- Multiple view modes (list/icon with small and large icons)
- Open file locations in Explorer
- Copy the full path(s) of selected applications
- Column sorting (click column headers to sort, remembers preference)
- Window position, size, and view mode remembered across sessions
- Toolbar buttons with custom icons (via IconButton class)
- Compilable to standalone EXE (Ahk2Exe directives included)
- Automatic legacy encoding migration (ANSI → UTF-8)
- Atomic file saving (write to .tmp, then rename) for data safety
- Multi-item removal confirmation dialog
- Keyboard shortcuts help dialog

## Files

| File | Description |
|------|-------------|
| `AppBox.ahk` | Main application script |
| `IconButton.ahk` | Icon button class: custom buttons with icon support, grayscale on disabled, DPI-aware |
| `applist.txt` | Saved application list (auto-generated) |
| `settings.ini` | User preferences: window state, view mode, sort column (auto-generated) |
| `icons/` | Toolbar icon files (.ico) used by the application |

## Installation & Run

### Option 1: Run the compiled EXE (recommended)

1. Go to the [Releases](https://github.com/mesutakcan/AS-AppBox/releases) page.
2. Download the latest `AppBox.exe` file.
3. Double-click `AppBox.exe` to run. No installation or dependencies required.

> **Note:** The EXE is a standalone portable application. All icon files are embedded in the executable, so no additional files are needed.

### Option 2: Run from source (AHK script)

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download the project files:
   - [AppBox.ahk](src/AppBox.ahk): main script
   - [IconButton.ahk](src/IconButton.ahk): icon button class
   - `src/icons/` folder: toolbar icon files
3. Place all files in the same folder.
4. Double-click `AppBox.ahk` to run.

## Usage

- **Add:** Add new applications to your list (files or folders).
- **Remove:** Remove selected applications.
- **Run:** Launch selected applications.
- **Save:** Save your application list.
- **Switch view:** Cycle through four view modes: list with small icons, list with large icons, icon view with small icons, icon view with large icons.
- **Exit:** Exit the application.
- **Clear filter (×):** The small button next to the filter box clears the current filter text.

### Keyboard Shortcuts

#### Anywhere
| Key | Action |
|-----|--------|
| `Ctrl+F` | Go to the filter box |
| `Insert` | Add applications |
| `Ctrl+S` | Save list |
| Drag & drop | Add files or folders |

#### Filter Box
| Key | Action |
|-----|--------|
| `Esc` | Clear the filter |
| `Down` | Move to the list |

#### List
| Key | Action |
|-----|--------|
| `Enter` / `Numpad Enter` | Run selected |
| `Del` | Remove selected |
| `Ctrl+A` | Select all |
| `Esc` | Deselect all |
| Click column header | Sort the list |

## History

- **v1.1** : 2026-10-13
  - Added `IconButton.ahk`: custom button class with icon support, grayscale-on-disabled, and DPI awareness
  - Toolbar buttons now display custom icons (.ico files) instead of Segoe MDL2 Assets font characters
  - Added Ahk2Exe compiler directives for building standalone EXE
  - Replaced manual ImageList icon loading with Windows system icon list (`SHGetFileInfoW` with `SHGFI_SYSICONINDEX`) for faster, lower-memory icon display
  - Intelligent icon caching: per-extension cache for common file types, per-path cache for unique types (exe, lnk, ico, etc.)
  - Added `settings.ini` support: window position/size, view mode, and sort preferences are now saved and restored across sessions
  - Added column header click sorting with ascending/descending toggle
  - Added Keyboard Shortcuts dialog in Help menu
  - Added `Ctrl+F` shortcut to focus the filter box
  - Added cue banner (placeholder text) in the filter input
  - Filter box keyboard navigation: `Esc` clears filter, `Down` moves focus to the list
  - Added `Enter` / `Numpad Enter` hotkeys to run selected applications from the list
  - Debounced filter input (100 ms delay) for smoother typing experience
  - Context-sensitive hotkeys: `Del`, `Ctrl+A`, `Esc`, `Enter` only active when list is focused; `Insert` disabled while filter is focused
  - Atomic file saving: writes to `.tmp` file first, then renames for data safety
  - File saving and loading now use UTF-8 encoding
  - Automatic legacy encoding migration: detects ANSI-encoded list files and converts to UTF-8
  - Multi-item removal now shows a confirmation dialog
  - Close dialog now includes a Cancel option (in addition to Yes/No)
  - Save on close verifies success before exiting
  - `Run` now uses working directory parameter instead of `RunWait`
  - Duplicate checking uses `Map` (O(1) lookup) instead of linear array search
  - StatusBar shows filtered count (e.g., "5 of 12 app(s)")
  - StatusBar divided into parts for better information display
  - File selection dialog now allows selecting folders as well (`M35` flag)
  - Changed default font to Segoe UI
  - Improved minimum window size (540×570)
  - Window state saved on close (position, size)
  - Various code refactoring and improvements

- **v1.0** : 2025-04-25
  - First version

## Credits

- [IconButton](https://github.com/mesutakcan/IconButton): AHK v2 button class with icon support, grayscale on disabled, and DPI awareness. By Mesut Akcan.

## Contributing

Contributions are welcome! If you'd like to add features, fix bugs, or improve the code, feel free to open a pull request.

## Developer

Mesut Akcan
- [mesutakcan.blogspot.com](https://mesutakcan.blogspot.com)
- [youtube.com/mesutakcan](https://youtube.com/mesutakcan)
- [github.com/mesutakcan](https://github.com/mesutakcan)

