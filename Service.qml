import QtQuick
import Quickshell
import Quickshell.Hyprland

// Edge Glow: an Apple Intelligence-style glow around the screen edge while
// Voxtype is dictating. Voxtype's own on-screen pill should be turned off
// ([osd] enabled = false in ~/.config/voxtype/config.toml).
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  GlowConfig { id: glowConfig }
  VoxtypeState { id: voxState }
  AudioLevel {
    id: audioLevel
    enabled: voxState.listening
  }

  readonly property var targetScreens: {
    const screens = Quickshell.screens || []
    if (glowConfig.monitor === "all") return screens
    const wanted = glowConfig.monitor === "focused"
      ? (Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : "")
      : glowConfig.monitor
    for (let i = 0; i < screens.length; ++i)
      if (String(screens[i].name || "") === wanted) return [screens[i]]
    return screens.length ? [screens[0]] : []
  }

  Variants {
    model: root.targetScreens
    delegate: GlowSurface {
      voxtype: voxState
      audio: audioLevel
      config: glowConfig
    }
  }
}
