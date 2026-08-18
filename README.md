# finder-guard

> Block Finder's "type-to-search" popup (the black/white search box) on macOS.
> 阻止访达「打字即搜索」弹窗（黑框/白框）。

On macOS 26+, typing in Finder with **nothing selected** opens Finder's quick-search
panel. When used with a Chinese input method, the panel renders as an obnoxious
black box. Apple provides **no setting to disable it**.

This background daemon intercepts keystrokes at the system level: when **Finder is
frontmost, no text field is focused, and no file is selected**, it consumes
letter/digit key presses so Finder never starts type-to-search. The box never appears.

macOS 26 起，在访达中**未选中任何文件**时打字会弹出快速搜索面板，配合中文输入法时渲染成黑框，且系统没有关闭开关。
本程序在系统键盘层拦截：当**访达前台 + 无文本框焦点 + 未选中文件**时吞掉字母/数字键，让访达永远收不到打字，黑框不再出现。

## Features

- Blocks only the exact trigger condition of Finder's type-to-search
- Lets everything else through: typing in text fields / search box, rename-by-typing on selected files, all shortcuts (Cmd/Ctrl/Option), other apps
- Self-managed rotating log (`~/finder-guard/guard.log`, max 1 MB)
- Crash auto-restart & self-healing retry on missing permission (launchd `KeepAlive`)

## How it works

- `CGEventTap` (session-level keyboard interception)
- Decision cached every ~80 ms → negligible overhead
- AX messaging timeout (0.15 s) so a hung Finder can't stall typing
- Watchdog re-enables the tap if macOS ever disables it

## Requirements

- macOS 26+ (works on macOS 15+ too, where the box is less prominent)
- Xcode Command Line Tools (`swiftc`)
- Two permissions granted manually in System Settings (never requested by the app itself)

## Install

```bash
git clone https://github.com/ryanlonn555-lab/finder-guard.git
cd finder-guard
./build.sh          # compiles main.swift and ad-hoc signs the binary
./install.sh        # installs the launchd LaunchAgent (auto-start at login)
```

Then grant permissions in **System Settings**:

1. **Privacy & Security → Input Monitoring** → add the `finder-guard` binary
2. **Privacy & Security → Accessibility** → add the same binary

The daemon auto-starts, survives reboots, and restarts if it crashes.

## Verify it works

```bash
tail -f ~/finder-guard/guard.log     # you should see "finder-guard running (tap OK)."
```

Click the desktop (nothing selected) and type — nothing happens now; before it
would open the black search box. Typing in text fields is unaffected.

## Commands

```bash
# status / logs
cat ~/finder-guard/guard.log

# stop
launchctl bootout gui/$(id -u)/com.local.finder-guard

# start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.finder-guard.plist

# restart (after reinstalling/recompiling)
launchctl kickstart -k gui/$(id -u)/com.local.finder-guard
```

## Uninstall

```bash
./uninstall.sh
rm -rf ~/finder-guard
```

## Troubleshooting

- **Box is back** → `cat ~/finder-guard/guard.log`; if you see
  `cannot create event tap`, the permission is stale → re-toggle the two entries
  in System Settings (Off → On).
- **After a macOS major upgrade** → re-grant permissions; if still broken, the
  macOS API may have changed — the log will say so.
- **Recompiled the binary?** → code signature changes, TCC grants are bound to
  the signature → re-grant permissions again (this is by design, for security).

## Known limitations

- Finder's type-to-search / type-ahead file jump is intentionally disabled.
  Use `Cmd+Space` (Spotlight) to search instead.
- Rename-by-typing on a **selected** file still works (it's passed through).
- The program stores **no characters** (logs only key codes), makes **no network
  calls**, and touches no other apps.

## License

MIT
