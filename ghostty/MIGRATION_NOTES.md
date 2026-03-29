# iTerm2 to Ghostty Migration Notes

Discrepancies and features that could not be fully migrated.

## No Equivalent in Ghostty

### Status Bar
iTerm2 had a bottom status bar showing: clock (M/dd h:mm), username, hostname,
memory utilization, CPU utilization, and battery. Ghostty has no built-in status
bar. Alternatives: oh-my-posh prompt segments, tmux status line, or a
Ghostty custom shader (overkill).

### Visual Bell
iTerm2 flashed the screen and tab title on bell. Ghostty has no visual flash.
`bell-features = attention` bounces the dock icon as a substitute.

### Disable Escape Sequence Window Resizing
iTerm2 had `Disable Window Resizing = true` preventing programs from resizing
the terminal window via escape sequences. Ghostty has no equivalent toggle.

### Cursor Blend
iTerm2 had a cursor blend value of 0.4 controlling how the cursor color mixes
with the character underneath. Ghostty's `cursor-opacity` controls overall
cursor transparency which is different behavior. Left at default.

### Smart Selection on Double-Click
iTerm2 had `DoubleClickPerformsSmartSelection = true`. Ghostty uses standard
word-boundary double-click selection only (`selection-word-chars` can tune
boundaries but there is no smart/semantic selection).

### Pointer Actions (Middle-Click Paste)
iTerm2 had middle-click mapped to paste from clipboard and three-finger swipe
gestures for tab/window switching. Ghostty has no middle-click paste or gesture
support.

## Known Issues

### Background Transparency + Split Pane Dimming
Background transparency (`background-opacity`) interacts poorly with
`unfocused-split-opacity`. The focused (transparent) pane appears dimmer than the
unfocused pane because the dimming overlay adds an opaque fill that makes the
unfocused pane look brighter. This is the opposite of the intended behavior.
Transparency has been disabled for now. If re-enabling, set
`unfocused-split-opacity = 1` to disable dimming, or accept that split pane
focus indication won't work correctly with transparency.

## Behavioral Differences

### Option Key
iTerm2 had Option Key Sends = Normal (0) with per-key keyboard overrides for
word navigation (Option+Arrow, Option+Delete). Ghostty uses
`macos-option-as-alt = true` which makes ALL Option combos send Alt/Esc
sequences globally. This means special characters typed with Option (like ©, °,
™, é) are unavailable. Use `macos-option-as-alt = left` to keep the right
Option key for special characters if needed.

### Tab Style
iTerm2 used compact tabs (`TabViewType = 1`) with automatic theme matching
(`TabStyleWithAutomaticOption = 5`). Ghostty uses `macos-titlebar-style = tabs`
which integrates tabs into the native macOS titlebar. Visually different but
functionally equivalent.

### Scrollback
iTerm2 had truly unlimited scrollback. Ghostty's scrollback is byte-limited;
config uses 100MB (`scrollback-limit = 100000000`) as an approximation.

### Separate Light/Dark Mode Colors
iTerm2 stored independent color values for every element in light vs dark mode.
Ghostty uses the `theme = light:X,dark:Y` syntax which switches entire theme
files. The catppuccin-latte and catppuccin-mocha themes are close matches to the
iTerm2 dark/light colors but may not be pixel-identical since the iTerm2 profile
had its own color values per-mode.

## Numpad Keybindings
iTerm2 explicitly mapped numpad keys (0-9, *, +, -, ., /, Enter) to send their
literal characters. Ghostty handles numpad input correctly by default so no
explicit keybinds were needed.
