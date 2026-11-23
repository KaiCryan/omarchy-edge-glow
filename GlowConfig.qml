import QtQuick
import Quickshell
import Quickshell.Io

// Optional settings in ~/.config/omarchy/edge-glow.json (reloads live):
//   palette    "apple" (default) or "theme" (follows the Omarchy theme)
//   width      glow depth in pixels (default 34)
//   intensity  brightness multiplier (default 1.0)
//   radius     corner radius in pixels (default 14)
//   monitor    "focused" (default), "all", or an output name such as "eDP-1"
QtObject {
  id: root

  // Apple Intelligence gradient (blue, violet, pink, orange), slightly softened and
  // brightened, and mirrored so it loops smoothly.
  readonly property var applePalette: ["#2FA0F6", "#CE77DE", "#F85472", "#F69D2B", "#F85472", "#CE77DE"]

  property string paletteMode: "apple"
  property real width: 34
  property real intensity: 1.0
  property real radius: 14
  property string monitor: "focused"
  property var themePalette: applePalette

  readonly property var colors: paletteMode === "theme" ? themePalette : applePalette

  function num(v, fallback, lo, hi) {
    return (typeof v === "number" && isFinite(v)) ? Math.max(lo, Math.min(hi, v)) : fallback
  }

  function apply(text) {
    let v = {}
    try { v = JSON.parse(text || "{}") || {} } catch (e) { v = {} }
    paletteMode = v.palette === "theme" ? "theme" : "apple"
    width = num(v.width, 34, 6, 160)
    intensity = num(v.intensity, 1.0, 0.1, 3)
    radius = num(v.radius, 14, 0, 80)
    monitor = typeof v.monitor === "string" && v.monitor.length < 64 ? v.monitor : "focused"
  }

  function token(text, name, fallback) {
    const m = new RegExp("^\\s*" + name + "\\s*=\\s*\"(#[0-9a-fA-F]{6})\"", "m").exec(text || "")
    return m ? m[1] : fallback
  }

  function applyTheme(text) {
    // Ordered to echo Apple's blue → violet → pink → coral → amber sweep.
    themePalette = [
      token(text, "blue", applePalette[0]),
      token(text, "magenta", applePalette[1]),
      token(text, "bright_magenta", token(text, "magenta", applePalette[2])),
      token(text, "red", applePalette[3]),
      token(text, "orange", applePalette[4]),
      token(text, "cyan", applePalette[5])
    ]
  }

  property FileView settingsFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/edge-glow.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("{}")
    onFileChanged: reload()
  }

  property FileView themeFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyTheme(text())
    onFileChanged: reload()
  }
}
