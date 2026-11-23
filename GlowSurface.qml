import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// One transparent, click-through overlay per screen that draws the edge glow.
PanelWindow {
  id: panel

  required property var modelData
  property var voxtype: null
  property var audio: null
  property var config: null

  readonly property bool dictating: voxtype ? voxtype.active : false
  readonly property bool active: dictating || held
  readonly property bool animationsOn: Style.duration(1000) > 0

  // Animated values, advanced once per frame.
  property real presence: 0
  property real reveal: 0
  property real level: 0
  property real thinking: 0
  property real clock: 0
  property real flowPhase: 0
  // Holds the glow through a brief idle blip between recording and transcribing.
  property bool held: false

  screen: modelData
  visible: active || presence > 0.002
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "kaicryan-edge-glow"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  onDictatingChanged: {
    if (dictating) { holdTimer.stop(); held = false }
    else if (presence > 0.05) { held = true; holdTimer.restart() }
  }

  Timer {
    id: holdTimer
    interval: 350
    onTriggered: panel.held = false
  }

  onActiveChanged: {
    // Replay the entrance sweep each time dictation starts from rest.
    if (active && presence < 0.05) reveal = animationsOn ? 0 : 1.3
  }

  function approach(current, target, dt, tauMs) {
    if (tauMs <= 0) return target
    return current + (target - current) * (1 - Math.exp(-dt * 1000 / tauMs))
  }

  FrameAnimation {
    running: panel.visible
    onTriggered: {
      const dt = Math.min(0.1, Math.max(0.001, frameTime))
      const on = panel.animationsOn
      const listening = panel.voxtype && panel.voxtype.listening
      const thinkingNow = panel.voxtype && panel.voxtype.thinking

      panel.presence = panel.approach(panel.presence, panel.active ? 1 : 0, dt,
        on ? (panel.active ? 160 : 420) : 0)
      if (panel.presence < 0.002 && !panel.active) panel.presence = 0

      // Entrance sweep: ~0.75 s ease-out from the bottom edge up both sides.
      if (panel.reveal < 1.3) panel.reveal = Math.min(1.3, panel.reveal + dt * (1.3 - panel.reveal * 0.8) * 2.4)

      const voice = listening && panel.audio ? panel.audio.target : 0
      panel.level = panel.approach(panel.level, voice, dt, voice > panel.level ? 70 : 240)
      panel.thinking = panel.approach(panel.thinking, thinkingNow ? 1 : 0, dt, 320)

      if (on) {
        const step = dt * (0.55 + 1.5 * panel.level + 0.9 * panel.thinking)
        panel.clock += step
        panel.flowPhase = (panel.flowPhase + step * (0.045 + 0.10 * panel.thinking)) % 1000
      }
    }
  }

  ShaderEffect {
    anchors.fill: parent
    visible: panel.presence > 0.002
    blending: true
    fragmentShader: Qt.resolvedUrl("glow.frag.qsb")

    readonly property var cols: panel.config ? panel.config.colors : []
    function c(i) { return cols.length ? cols[i % cols.length] : "#ffffff" }

    property size uResolution: Qt.size(width, height)
    property real uTime: panel.clock
    property real uFlow: panel.flowPhase
    property real uLevel: panel.level
    property real uThinking: panel.thinking
    property real uReveal: panel.reveal
    property real uPresence: panel.presence
    property real uWidth: panel.config ? panel.config.width : 34
    property real uIntensity: panel.config ? panel.config.intensity : 1
    property real uRadius: panel.config ? panel.config.radius : 14
    property color uC0: c(0)
    property color uC1: c(1)
    property color uC2: c(2)
    property color uC3: c(3)
    property color uC4: c(4)
    property color uC5: c(5)
  }
}
