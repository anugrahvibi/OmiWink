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
  property real wink: 0
  property real shiftX: 0
  property real shiftY: 0
  property int lastIdleAction: -1
  property bool idleActionRunning: false
  property bool cursorMovedDuringAction: false
  property real pendingCursorX: 0
  property real pendingCursorY: 0
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

    if (root.idleActionRunning) {
      root.pendingCursorX = deltaX / distance
      root.pendingCursorY = deltaY / distance
      root.cursorMovedDuringAction = true
      return
    }

    idleGlanceTimer.stop()
    glanceHoldTimer.stop()
    expressionTimer.stop()
    root.doubleTakePending = false
    cursorPauseTimer.restart()
    root.expression = 0
    root.pulse = 0
    root.wink = 0
    root.setGaze(deltaX / distance, deltaY / distance, 160)
  }

  function scheduleIdleGlance() {
    if (!root.active) return
    idleGlanceTimer.interval = 2800 + Math.floor(Math.random() * 3800)
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

    root.idleActionRunning = true
    root.cursorMovedDuringAction = false
    var choices = [0, 0, 0, 1, 2, 3, 5, 5].filter(function(value) { return value !== root.lastIdleAction })
    var action = choices[Math.floor(Math.random() * choices.length)]
    root.lastIdleAction = action
    var directions = [
      { x: -0.9, y: 0 },
      { x: 0.9, y: 0 },
      { x: -0.9, y: 0 },
      { x: 0.9, y: 0 },
      { x: 0, y: -0.7 },
      { x: 0, y: 0.7 }
    ]
    var direction = directions[Math.floor(Math.random() * directions.length)]

    root.currentGlanceX = direction.x
    root.currentGlanceY = direction.y
    root.doubleTakePending = action === 0 && Math.random() < 0.6
    if (action === 0) {
      root.setGaze(direction.x, direction.y, 180 + Math.floor(Math.random() * 120))
    } else if (action === 1) {
      root.expression = -0.45
    } else if (action === 2) {
      root.wink = Math.random() < 0.5 ? -1 : 1
    } else if (action === 3) {
      root.expression = 1
      root.pulse = 0.7
    } else if (action === 5) {
      root.shiftX = direction.x * 2
      root.shiftY = direction.y * 1.5
      root.setGaze(-direction.x * 0.5, -direction.y * 0.5, 260)
    }
    glanceHoldTimer.interval = 850 + Math.floor(Math.random() * 650)
    glanceHoldTimer.restart()
  }

  function advanceGlance() {
    if (!root.active) return

    if (root.doubleTakePending) {
      root.doubleTakePending = false
      root.setGaze(-root.currentGlanceX * 0.85,
        -root.currentGlanceY * 0.85, 140)
      glanceHoldTimer.interval = 390
      glanceHoldTimer.restart()
      return
    }

    root.setGaze(0, 0, 280)
    root.expression = 0
    root.pulse = 0
    root.wink = 0
    root.shiftX = 0
    root.shiftY = 0
    transitionPauseTimer.restart()
  }

  function stopMotion() {
    cursorPauseTimer.stop()
    idleGlanceTimer.stop()
    glanceHoldTimer.stop()
    expressionTimer.stop()
    transitionPauseTimer.stop()
    doubleBlinkTimer.stop()
    blinkAnimation.stop()
    root.gazeAnimated = false
    root.gazeX = 0
    root.gazeY = 0
    root.blinkProgress = 0
    root.expression = 0
    root.pulse = 0
    root.wink = 0
    root.shiftX = 0
    root.shiftY = 0
    root.blinkCountRemaining = 0
    root.doubleTakePending = false
    root.idleActionRunning = false
    root.cursorMovedDuringAction = false
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
    id: transitionPauseTimer
    interval: 400
    repeat: false
    onTriggered: {
      root.idleActionRunning = false
      if (root.cursorMovedDuringAction) {
        root.cursorMovedDuringAction = false
        root.setGaze(root.pendingCursorX, root.pendingCursorY, 200)
        cursorPauseTimer.restart()
      } else {
        root.scheduleIdleGlance()
      }
    }
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
      if (root.idleActionRunning || cursorPauseTimer.running) return
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

  Behavior on wink {
    enabled: root.active
    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
  }

  Behavior on shiftX {
    enabled: root.active
    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
  }
  Behavior on shiftY {
    enabled: root.active
    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
  }
}
