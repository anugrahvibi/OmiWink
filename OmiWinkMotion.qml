import QtQuick

Item {
  id: root
  width: 0
  height: 0
  visible: false

  property bool active: false
  property bool gazeAnimated: false
  property real gazeX: 0
  property real gazeY: 0
  property real blinkProgress: 0
  property real expression: 0
  property real pulse: 0
  property real currentGlanceX: 0
  property real currentGlanceY: 0
  property int gazeDuration: 180
  property int blinkCountRemaining: 0
  property int nextBlinkInterval: 3600
  property bool doubleTakePending: false

  function cursorMoved(deltaX, deltaY) {
    if (!root.active) return

    var distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if (distance < 0.5) return

    idleGlanceTimer.stop()
    glanceHoldTimer.stop()
    expressionTimer.stop()
    root.doubleTakePending = false
    cursorPauseTimer.restart()
    root.expression = 0
    root.pulse = 0
    root.gazeAnimated = false
    root.gazeX = deltaX / distance
    root.gazeY = deltaY / distance
  }

  function scheduleIdleGlance() {
    if (!root.active) return
    idleGlanceTimer.interval = 2800 + Math.floor(Math.random() * 2400)
    idleGlanceTimer.restart()
  }

  function setGaze(x, y, duration) {
    root.gazeDuration = duration
    root.gazeAnimated = true
    root.gazeX = x
    root.gazeY = y
  }

  function startIdleGlance() {
    if (!root.active) return

    var directions = [
      { x: -0.9, y: 0 },
      { x: 0.9, y: 0 },
      { x: 0, y: -0.95 },
      { x: 0, y: 0.95 }
    ]
    var direction = directions[Math.floor(Math.random() * directions.length)]

    root.currentGlanceX = direction.x
    root.currentGlanceY = direction.y
    root.doubleTakePending = Math.random() < 0.22
    root.setGaze(direction.x, direction.y, 170)
    root.expression = 1
    root.pulse = 1
    expressionTimer.interval = 360
    expressionTimer.restart()
    glanceHoldTimer.interval = 720 + Math.floor(Math.random() * 180)
    glanceHoldTimer.restart()
  }

  function advanceGlance() {
    if (!root.active) return

    if (root.doubleTakePending) {
      root.doubleTakePending = false
      root.setGaze(-root.currentGlanceX * 0.85,
        -root.currentGlanceY * 0.85, 140)
      root.expression = 1
      root.pulse = 0.72
      expressionTimer.interval = 300
      expressionTimer.restart()
      glanceHoldTimer.interval = 390
      glanceHoldTimer.restart()
      return
    }

    root.setGaze(0, 0, 220)
    root.expression = 0
    root.pulse = 0
    root.scheduleIdleGlance()
  }

  function stopMotion() {
    cursorPauseTimer.stop()
    idleGlanceTimer.stop()
    glanceHoldTimer.stop()
    expressionTimer.stop()
    doubleBlinkTimer.stop()
    blinkAnimation.stop()
    root.gazeAnimated = false
    root.gazeX = 0
    root.gazeY = 0
    root.blinkProgress = 0
    root.expression = 0
    root.pulse = 0
    root.blinkCountRemaining = 0
    root.doubleTakePending = false
  }

  onActiveChanged: Qt.callLater(function() {
    if (root.active)
      root.scheduleIdleGlance()
    else
      root.stopMotion()
  })

  Component.onCompleted: {
    if (root.active) root.scheduleIdleGlance()
  }

  Timer {
    id: cursorPauseTimer
    interval: 850
    repeat: false
    onTriggered: {
      if (!root.active) return
      root.setGaze(0, 0, 220)
      root.expression = 0
      root.pulse = 0
      root.scheduleIdleGlance()
    }
  }

  Timer {
    id: idleGlanceTimer
    interval: 3600
    repeat: false
    onTriggered: root.startIdleGlance()
  }

  Timer {
    id: glanceHoldTimer
    interval: 800
    repeat: false
    onTriggered: root.advanceGlance()
  }

  Timer {
    id: expressionTimer
    interval: 360
    repeat: false
    onTriggered: {
      root.expression = 0
      root.pulse = 0
    }
  }

  Timer {
    id: blinkTimer
    interval: root.nextBlinkInterval
    repeat: true
    running: root.active
    onTriggered: {
      root.nextBlinkInterval = 3200 + Math.floor(Math.random() * 3000)
      root.blinkCountRemaining = Math.random() < 0.18 ? 2 : 1
      blinkAnimation.restart()
    }
  }

  Timer {
    id: doubleBlinkTimer
    interval: 135
    repeat: false
    onTriggered: {
      if (root.active) blinkAnimation.restart()
    }
  }

  SequentialAnimation {
    id: blinkAnimation

    NumberAnimation {
      target: root
      property: "blinkProgress"
      to: 1
      duration: 70
      easing.type: Easing.InQuad
    }

    PauseAnimation { duration: 45 }

    NumberAnimation {
      target: root
      property: "blinkProgress"
      to: 0
      duration: 100
      easing.type: Easing.OutQuad
    }

    onFinished: {
      if (root.blinkCountRemaining > 1 && root.active) {
        root.blinkCountRemaining = 1
        doubleBlinkTimer.start()
      }
    }
  }

  Behavior on gazeX {
    enabled: root.gazeAnimated
    NumberAnimation { duration: root.gazeDuration; easing.type: Easing.OutCubic }
  }

  Behavior on gazeY {
    enabled: root.gazeAnimated
    NumberAnimation { duration: root.gazeDuration; easing.type: Easing.OutCubic }
  }

  Behavior on expression {
    enabled: root.active
    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
  }

  Behavior on pulse {
    enabled: root.active
    NumberAnimation { duration: 145; easing.type: Easing.OutCubic }
  }
}
