import QtQuick
import Quickshell.Io

// Reads microphone frames from voxtype-audio-bridge (NDJSON: rms, peak, vad)
// and exposes a self-normalising 0..1 loudness for the glow to follow.
Item {
  id: root
  property bool enabled: false
  property real rms: 0
  property bool vad: false
  // Loudest recent frame; decays so quiet and loud mics both fill the range.
  property real reference: 0.05

  readonly property real target: {
    if (!enabled) return 0
    const n = Math.min(1, rms / Math.max(0.02, reference))
    return Math.pow(n, 0.8) * (vad ? 1 : 0.4)
  }

  function reset() { rms = 0; vad = false }

  function parse(line) {
    const value = String(line || "").trim()
    if (!value) return
    let frame
    try { frame = JSON.parse(value) } catch (e) { return }
    if (frame.status === "disconnected") { reset(); return }
    if (typeof frame.rms !== "number" || !isFinite(frame.rms)) return
    rms = Math.max(0, Math.min(1, frame.rms))
    vad = !!frame.vad
    reference = Math.max(rms, reference * 0.995)
  }

  onEnabledChanged: {
    retry.stop()
    bridge.running = enabled
    if (!enabled) reset()
  }

  Process {
    id: bridge
    command: ["/usr/bin/voxtype-audio-bridge"]
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => root.parse(data)
    }
    onRunningChanged: {
      if (!running) {
        root.reset()
        if (root.enabled) retry.restart()
      }
    }
  }

  Timer {
    id: retry
    interval: 1000
    onTriggered: if (root.enabled && !bridge.running) bridge.running = true
  }
}
