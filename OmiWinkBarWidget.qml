import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "anugrahvibi.omiwink"

  readonly property string cursorReaderPath: decodeURIComponent(
    String(Qt.resolvedUrl("omiwink_cursor_reader.py")).replace(/^file:\/\//, ""))
  readonly property var hostWindow: root.QsWindow.window
  readonly property string hostScreenName: hostWindow && hostWindow.screen
    ? String(hostWindow.screen.name || "") : ""
  readonly property var primaryScreen: Quickshell.screens.length > 0
    ? Quickshell.screens[0] : null
  readonly property bool cursorReaderOwner: primaryScreen !== null
    && root.hostScreenName === String(root.primaryScreen.name || "")
  readonly property bool faceVisible: root.cursorReaderOwner
    && root.monitorIsPowered(root.hostScreenName)

  property real cursorX: 0
  property real cursorY: 0
  property bool cursorInitialized: false
  property var monitorPowerStates: ({})
  property bool cursorReaderErrorLogged: false

  implicitWidth: faceButton.implicitWidth
  implicitHeight: faceButton.implicitHeight

  function monitorIsPowered(name) {
    var key = String(name || "")
    if (root.monitorPowerStates[key] !== undefined)
      return root.monitorPowerStates[key] === true
    return true
  }

  function anyMonitorIsPowered() {
    var screens = Quickshell.screens
    if (screens.length === 0) return false
    for (var i = 0; i < screens.length; i++) {
      if (root.monitorIsPowered(screens[i].name)) return true
    }
    return false
  }

  function refreshMonitorPowerStates() {
    if (!root.cursorReaderOwner) return

    try {
      Hyprland.refreshMonitors()
      Qt.callLater(function() {
        var states = ({})
        var monitors = Hyprland.monitors.values
        for (var i = 0; i < monitors.length; i++) {
          var monitor = monitors[i]
          var data = monitor.lastIpcObject
          var dpms = data ? data.dpmsStatus : undefined
          var isOn = dpms === undefined || dpms === true || dpms === 1
            || dpms === "1" || dpms === "true"
          states[String(monitor.name || "")] = isOn
        }
        var screens = Quickshell.screens
        for (var j = 0; j < screens.length; j++) {
          var name = String(screens[j].name || "")
          if (states[name] === undefined) states[name] = true
        }
        root.monitorPowerStates = states
      })
    } catch (error) {
      console.warn("omiwink: unable to refresh display power state")
    }
  }

  function markDisplaysAwake() {
    var states = ({})
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      states[String(screens[i].name || "")] = true
    root.monitorPowerStates = states
  }

  function handleIdleState(isIdle) {
    if (!root.cursorReaderOwner) return
    if (isIdle) {
      cursorReader.write("pause\n")
      root.refreshMonitorPowerStates()
    } else {
      root.markDisplaysAwake()
      cursorReader.write("resume\n")
    }
  }

  function handleCursorLine(line) {
    try {
      var position = JSON.parse(String(line))
      var nextX = Number(position.x)
      var nextY = Number(position.y)
      if (!isFinite(nextX) || !isFinite(nextY)) return

      var hadPosition = root.cursorInitialized
      var deltaX = hadPosition ? nextX - root.cursorX : 0
      var deltaY = hadPosition ? nextY - root.cursorY : 0
      root.cursorX = nextX
      root.cursorY = nextY
      root.cursorInitialized = true

      if (hadPosition) mascotMotion.cursorMoved(deltaX, deltaY)
    } catch (error) {
      if (!root.cursorReaderErrorLogged) {
        root.cursorReaderErrorLogged = true
        console.warn("omiwink: cursor reader data rejected: " + String(error))
      }
    }
  }

  WidgetButton {
    id: faceButton
    anchors.fill: root
    bar: root.bar
    text: ""
    horizontalMargin: 0
    fixedWidth: Style.bar.iconSlot
    fixedHeight: root.barSize
    hasVisualContent: true
    labelVisible: false
    interactive: false
    pressable: false
  }

  Item {
    id: faceContainer
    anchors.fill: parent

    OmiWinkFace {
      anchors.centerIn: faceContainer
      anchors.horizontalCenterOffset: mascotMotion.shiftX
      anchors.verticalCenterOffset: mascotMotion.shiftY
      visible: root.faceVisible
      faceSize: 18
      gazeX: mascotMotion.gazeX
      gazeY: mascotMotion.gazeY
      blinkProgress: mascotMotion.blinkProgress
      wink: mascotMotion.wink
      expression: mascotMotion.expression
      pulse: mascotMotion.pulse
      faceColor: root.bar ? root.bar.barForeground : "#e6e6e8"
      eyeColor: root.bar ? root.bar.background : "#1f2029"
    }
  }

  OmiWinkMotion {
    id: mascotMotion
    active: root.faceVisible
  }

  IdleMonitor {
    id: displayIdle
    enabled: root.cursorReaderOwner
    timeout: 0.25
    respectInhibitors: false
    onIsIdleChanged: root.handleIdleState(isIdle)
  }

  Timer {
    id: monitorPowerPoll
    interval: 1000
    repeat: true
    running: root.cursorReaderOwner && displayIdle.isIdle && root.anyMonitorIsPowered()
    onTriggered: root.refreshMonitorPowerStates()
  }

  Process {
    id: cursorReader
    command: ["python3", root.cursorReaderPath]
    running: root.cursorReaderOwner && root.cursorReaderPath !== ""
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) { root.handleCursorLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { console.warn("omiwink cursor reader: " + line) }
    }
    onStarted: write(displayIdle.isIdle ? "pause\n" : "resume\n")
  }

  Component.onCompleted: {
    root.refreshMonitorPowerStates()
    if (displayIdle.isIdle) root.handleIdleState(true)
  }
}
