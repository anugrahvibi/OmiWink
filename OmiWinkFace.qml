pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  property real faceSize: 18
  property color faceColor: "#e6e6e8"
  property color eyeColor: "#1f2029"
  property real gazeX: 0
  property real gazeY: 0
  property real blinkProgress: 0
  property real expression: 0
  property real pulse: 0

  width: faceSize
  height: faceSize
  transformOrigin: Item.Center
  scale: 1 + pulse * 0.055

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.faceColor
    antialiasing: true
  }

  Repeater {
    model: [0, 1]

    Rectangle {
      required property int index

      readonly property real openEyeHeight: root.faceSize
        * (0.36 + root.expression * 0.08)
      readonly property real openEyeWidth: root.faceSize
        * (0.17 + root.expression * 0.015)

      width: openEyeWidth
      height: openEyeHeight * (1 - root.blinkProgress)
        + root.faceSize * 0.04 * root.blinkProgress
      radius: width / 2
      x: root.faceSize * (index === 0 ? 0.25 : 0.60)
        + root.gazeX * root.faceSize * 0.20
      y: root.faceSize * 0.32
        + root.gazeY * root.faceSize * 0.18
        + (openEyeHeight - height) / 2
      color: root.eyeColor
      antialiasing: true
    }
  }
}
