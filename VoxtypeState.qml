import QtQuick
import Quickshell
import Quickshell.Io

// Follows the Voxtype daemon state file: idle, recording, streaming, transcribing.
QtObject {
  id: root
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
  property string daemonState: "idle"
  readonly property string state: daemonState
  property bool suppressed: false
  readonly property bool listening: state === "recording" || state === "streaming"
  readonly property bool thinking: state === "transcribing"
  readonly property bool active: !suppressed && (listening || thinking)

  function load(text) {
    const value = String(text || "").trim()
    daemonState = ["recording", "streaming", "transcribing"].indexOf(value) >= 0 ? value : "idle"
  }

  property FileView stateFile: FileView {
    path: root.runtimeDir + "/voxtype/state"
    watchChanges: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.daemonState = "idle"
    onFileChanged: reload()
  }

  // Voxtype writes this while something asks for its indicator to be hidden.
  property FileView suppressionFile: FileView {
    path: root.runtimeDir + "/voxtype/osd_suppressed"
    watchChanges: true
    printErrors: false
    onLoaded: root.suppressed = true
    onLoadFailed: root.suppressed = false
    onFileChanged: reload()
  }
}
