import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
    enabled: voxState.listening && voxState.previewState === ""
    simulate: voxState.previewState === "recording"
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
    id: surfaces
    model: root.targetScreens
    delegate: GlowSurface {
      voxtype: voxState
      audio: audioLevel
      config: glowConfig
    }
  }

  // omarchy-shell edge-glow preview [recording|transcribing|idle] [seconds]
  IpcHandler {
    target: "edge-glow"

    function preview(state: string, seconds: string): string {
      const s = ["recording", "streaming", "transcribing"].indexOf(state) >= 0 ? state : ""
      voxState.previewState = s === "streaming" ? "recording" : s
      const secs = Math.max(1, Math.min(60, parseInt(seconds) || 8))
      previewTimer.interval = secs * 1000
      if (s) previewTimer.restart(); else previewTimer.stop()
      return s ? "previewing " + s + " for " + secs + "s" : "preview stopped"
    }

    function status(): string {
      return "state=" + voxState.state + " daemon=" + voxState.daemonState
        + " suppressed=" + voxState.suppressed + " palette=" + glowConfig.paletteMode
        + " monitor=" + glowConfig.monitor + " level=" + audioLevel.target.toFixed(2)
        + " screens=" + root.targetScreens.length + " surfaces=" + surfaces.instances.length
        + (surfaces.instances.length ? " visible=" + surfaces.instances[0].visible
           + " presence=" + surfaces.instances[0].presence.toFixed(2)
           + " anim=" + surfaces.instances[0].animationsOn : "")
    }
  }

  Timer {
    id: previewTimer
    onTriggered: voxState.previewState = ""
  }
}
