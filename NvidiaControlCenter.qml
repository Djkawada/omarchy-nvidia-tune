import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

FloatingWindow {
  id: rootWindow
  title: "NVIDIA GPU Control & Profile Manager"
  color: Commons.Color.background
  implicitWidth: Style.space(980)
  implicitHeight: Style.space(680)
  minimumSize: Qt.size(Style.space(820), Style.space(560))

  property var pluginRoot: null
  signal closing()

  function requestClose() {
    rootWindow.visible = false
    rootWindow.closing()
  }

  onVisibleChanged: {
    if (!visible) {
      rootWindow.closing()
    }
  }

  // Selected profile for editing
  property string selectedProfileId: "tuned"
  property string editName: "Tuned (Undervolt & OC)"
  property int editCoreMax: 1950
  property int editMemOffset: 800
  property int editPowerLimit: 240
  property string editDesc: ""
  property bool isEditingNew: false

  // High-contrast secondary text colors for excellent legibility (avoids dim/dark muted grey)
  readonly property color textSecondary: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.78)
  readonly property color textDimmed: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.58)

  function loadProfileForEdit(p) {
    if (!p) return
    selectedProfileId = p.id || ""
    editName = p.name || ""
    editCoreMax = p.core_max !== undefined ? p.core_max : 1950
    editMemOffset = p.mem_offset !== undefined ? p.mem_offset : 0
    editPowerLimit = p.power_limit !== undefined ? p.power_limit : 220
    editDesc = p.description || ""
    isEditingNew = false
  }

  function startNewProfile() {
    selectedProfileId = "custom-" + Math.floor(Math.random() * 1000)
    editName = "My Custom Profile"
    editCoreMax = 1920
    editMemOffset = 600
    editPowerLimit = 220
    editDesc = "Custom tuned profile"
    isEditingNew = true
  }

  FocusScope {
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        rootWindow.requestClose()
        event.accepted = true
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      // Top Title Bar
      Row {
        width: parent.width
        height: Style.space(42)

        Row {
          spacing: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            source: Qt.resolvedUrl("assets/nvidia-active.svg")
            sourceSize.width: Style.space(28)
            sourceSize.height: Style.space(28)
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: rootWindow.pluginRoot ? rootWindow.pluginRoot.gpuName : "NVIDIA GeForce RTX 3070"
              font.pixelSize: 16
              font.bold: true
              color: Commons.Color.foreground
            }
            Text {
              text: "Driver: " + (rootWindow.pluginRoot ? rootWindow.pluginRoot.driverVersion : "615.78") + " • NVML Hardware Controller"
              font.pixelSize: 11
              color: Commons.Color.muted
            }
          }
        }

        Item {
          width: Math.max(8, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth)
          height: 1
        }

        Row {
          spacing: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter

          Button {
            text: "🔄 Refresh"
            height: Style.space(32)
            onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.refresh()
          }

          Button {
            text: "✕ Close"
            height: Style.space(32)
            onClicked: rootWindow.requestClose()
          }
        }
      }

      // Live Telemetry Cards Row
      Row {
        width: parent.width
        height: Style.space(72)
        spacing: Style.space(8)

        // Card: Core Clock
        Rectangle {
          width: (parent.width - Style.space(32)) / 5
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text { text: "CORE CLOCK"; font.pixelSize: 10; font.bold: true; color: rootWindow.textDimmed; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
              text: (rootWindow.pluginRoot ? rootWindow.pluginRoot.coreClock : 0) + " MHz"
              font.pixelSize: 16
              font.bold: true
              color: Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Cap: " + (rootWindow.pluginRoot && rootWindow.pluginRoot.activeProfile && rootWindow.pluginRoot.activeProfile.core_max > 0 ? (rootWindow.pluginRoot.activeProfile.core_max + " MHz") : "Stock Boost")
              font.pixelSize: 10
              font.bold: true
              color: rootWindow.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        // Card: Memory Clock & Offset
        Rectangle {
          width: (parent.width - Style.space(32)) / 5
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text { text: "VRAM CLOCK"; font.pixelSize: 10; font.bold: true; color: rootWindow.textDimmed; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
              text: (rootWindow.pluginRoot ? rootWindow.pluginRoot.memClock : 0) + " MHz"
              font.pixelSize: 16
              font.bold: true
              color: Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Offset: +" + (rootWindow.pluginRoot ? rootWindow.pluginRoot.memOffset : 0) + " MHz"
              font.pixelSize: 10
              font.bold: true
              color: (rootWindow.pluginRoot && rootWindow.pluginRoot.memOffset > 0) ? Commons.Color.accent : rootWindow.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        // Card: Temperature
        Rectangle {
          width: (parent.width - Style.space(32)) / 5
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text { text: "TEMPERATURE"; font.pixelSize: 10; font.bold: true; color: rootWindow.textDimmed; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
              readonly property int tVal: rootWindow.pluginRoot ? rootWindow.pluginRoot.gpuTemp : 0
              text: tVal + " °C"
              font.pixelSize: 16
              font.bold: true
              color: tVal < 65 ? Commons.Color.foreground : Commons.Color.urgent
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Fans: " + (rootWindow.pluginRoot ? rootWindow.pluginRoot.fanSpeed : 0) + "%"
              font.pixelSize: 10
              font.bold: true
              color: rootWindow.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        // Card: Power Draw
        Rectangle {
          width: (parent.width - Style.space(32)) / 5
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text { text: "POWER DRAW"; font.pixelSize: 10; font.bold: true; color: rootWindow.textDimmed; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
              text: (rootWindow.pluginRoot ? rootWindow.pluginRoot.powerWatts : 0) + " W"
              font.pixelSize: 16
              font.bold: true
              color: Commons.Color.accent
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Limit: " + (rootWindow.pluginRoot ? rootWindow.pluginRoot.powerLimit : 220) + " W"
              font.pixelSize: 10
              font.bold: true
              color: rootWindow.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        // Card: VRAM Utilization
        Rectangle {
          width: (parent.width - Style.space(32)) / 5
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 2
            Text { text: "VRAM USAGE"; font.pixelSize: 10; font.bold: true; color: rootWindow.textDimmed; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
              text: (rootWindow.pluginRoot ? rootWindow.pluginRoot.vramUsed : 0) + " MB"
              font.pixelSize: 16
              font.bold: true
              color: Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Total: " + (rootWindow.pluginRoot ? rootWindow.pluginRoot.vramTotal : 8192) + " MB"
              font.pixelSize: 10
              font.bold: true
              color: rootWindow.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }

      // Main Split Pane: Left (Profiles List) | Right (Profile Editor)
      Row {
        width: parent.width
        height: parent.height - Style.space(160)
        spacing: Style.space(12)

        // Left Pane: Profiles List
        Rectangle {
          width: Style.space(360)
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.04)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(8)

            Row {
              width: parent.width
              Text {
                text: "PROFILES (" + (rootWindow.pluginRoot ? rootWindow.pluginRoot.profiles.length : 0) + ")"
                font.pixelSize: 12
                font.bold: true
                color: Commons.Color.muted
                anchors.verticalCenter: parent.verticalCenter
              }
              Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - newBtn.implicitWidth); height: 1 }
              Button {
                id: newBtn
                text: "＋ New Profile"
                height: Style.space(26)
                onClicked: rootWindow.startNewProfile()
              }
            }

            ListView {
              id: profList
              width: parent.width
              height: parent.height - Style.space(40)
              clip: true
              spacing: Style.space(6)
              model: rootWindow.pluginRoot ? rootWindow.pluginRoot.profiles : []

              delegate: Rectangle {
                id: pDelegate
                width: profList.width
                height: Style.space(64)
                radius: Style.space(6)
                readonly property bool isActive: rootWindow.pluginRoot && rootWindow.pluginRoot.activeProfileId === modelData.id
                readonly property bool isSelected: rootWindow.selectedProfileId === modelData.id
                color: isActive ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15) : (isSelected ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.1) : (pMouse.containsMouse ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.06) : "transparent"))
                border.color: isActive ? Commons.Color.accent : (isSelected ? Commons.Color.foreground : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12))
                border.width: isActive || isSelected ? 1.5 : 1

                MouseArea {
                  id: pMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: rootWindow.loadProfileForEdit(modelData)
                }

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Column {
                    width: parent.width - applyBtn.implicitWidth - Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                      spacing: Style.space(6)
                      Text {
                        text: modelData.name || modelData.id
                        font.pixelSize: 13
                        font.bold: true
                        color: isActive ? Commons.Color.accent : Commons.Color.foreground
                      }
                      Rectangle {
                        visible: isActive
                        color: Commons.Color.accent
                        radius: 3
                        width: Style.space(46)
                        height: Style.space(16)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                          text: "ACTIVE"
                          font.pixelSize: 9
                          font.bold: true
                          color: Commons.Color.background
                          anchors.centerIn: parent
                        }
                      }
                    }

                    Text {
                      text: (modelData.core_max > 0 ? (modelData.core_max + " MHz") : "Stock Core") + " • +" + (modelData.mem_offset || 0) + " MHz Mem • " + (modelData.power_limit || 220) + "W"
                      font.pixelSize: 11
                      color: Commons.Color.muted
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }

                  Button {
                    id: applyBtn
                    text: isActive ? "✓ Active" : "Apply"
                    height: Style.space(28)
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !isActive
                    onClicked: {
                      if (rootWindow.pluginRoot) {
                        rootWindow.pluginRoot.applyProfile(modelData.id)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Right Pane: Profile Editor
        Rectangle {
          width: parent.width - Style.space(372)
          height: parent.height
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.04)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(12)

            Text {
              text: rootWindow.isEditingNew ? "CREATE NEW PROFILE" : ("EDIT PROFILE: " + rootWindow.editName)
              font.pixelSize: 13
              font.bold: true
              color: Commons.Color.accent
            }

            // Profile Name Input
            Column {
              width: parent.width
              spacing: 4
              Text { text: "Profile Display Name:"; font.pixelSize: 11; font.bold: true; color: rootWindow.textSecondary }
              TextField {
                width: parent.width
                height: Style.space(32)
                text: rootWindow.editName
                onTextChanged: rootWindow.editName = text
              }
            }

            // Core Clock Max Slider
            Column {
              width: parent.width
              spacing: 4
              Row {
                width: parent.width
                Text { text: "GPU Core Max Clock (Undervolt Cap):"; font.pixelSize: 11; font.bold: true; color: rootWindow.textSecondary }
                Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - coreValText.implicitWidth); height: 1 }
                Text {
                  id: coreValText
                  text: rootWindow.editCoreMax > 0 ? (rootWindow.editCoreMax + " MHz (~0.900V)") : "0 (Uncapped / Stock)"
                  font.pixelSize: 12
                  font.bold: true
                  color: Commons.Color.foreground
                }
              }
              Slider {
                width: parent.width
                from: 1600
                to: 2100
                stepSize: 10
                value: rootWindow.editCoreMax > 0 ? rootWindow.editCoreMax : 1950
                onMoved: rootWindow.editCoreMax = Math.round(value)
              }
              Row {
                spacing: Style.space(6)
                Button { text: "Stock (Uncapped)"; height: Style.space(24); onClicked: rootWindow.editCoreMax = 0 }
                Button { text: "1800 MHz (Silent)"; height: Style.space(24); onClicked: rootWindow.editCoreMax = 1800 }
                Button { text: "1920 MHz"; height: Style.space(24); onClicked: rootWindow.editCoreMax = 1920 }
                Button { text: "1950 MHz (Sweetspot)"; height: Style.space(24); onClicked: rootWindow.editCoreMax = 1950 }
                Button { text: "2050 MHz (OC)"; height: Style.space(24); onClicked: rootWindow.editCoreMax = 2050 }
              }
            }

            // Memory Clock Offset Slider
            Column {
              width: parent.width
              spacing: 4
              Row {
                width: parent.width
                Text { text: "VRAM Memory Offset (NVML):"; font.pixelSize: 11; font.bold: true; color: rootWindow.textSecondary }
                Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - memValText.implicitWidth); height: 1 }
                Text {
                  id: memValText
                  text: "+" + rootWindow.editMemOffset + " MHz"
                  font.pixelSize: 12
                  font.bold: true
                  color: Commons.Color.accent
                }
              }
              Slider {
                width: parent.width
                from: 0
                to: 1200
                stepSize: 50
                value: rootWindow.editMemOffset
                onMoved: rootWindow.editMemOffset = Math.round(value)
              }
              Row {
                spacing: Style.space(6)
                Button { text: "+0 MHz (Stock)"; height: Style.space(24); onClicked: rootWindow.editMemOffset = 0 }
                Button { text: "+400 MHz"; height: Style.space(24); onClicked: rootWindow.editMemOffset = 400 }
                Button { text: "+600 MHz"; height: Style.space(24); onClicked: rootWindow.editMemOffset = 600 }
                Button { text: "+800 MHz (Recommended)"; height: Style.space(24); onClicked: rootWindow.editMemOffset = 800 }
                Button { text: "+1000 MHz"; height: Style.space(24); onClicked: rootWindow.editMemOffset = 1000 }
              }
            }

            // Power Limit Slider
            Column {
              width: parent.width
              spacing: 4
              Row {
                width: parent.width
                Text { text: "GPU Power Limit Ceiling:"; font.pixelSize: 11; font.bold: true; color: rootWindow.textSecondary }
                Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - plValText.implicitWidth); height: 1 }
                Text {
                  id: plValText
                  text: rootWindow.editPowerLimit + " W"
                  font.pixelSize: 12
                  font.bold: true
                  color: Commons.Color.foreground
                }
              }
              Slider {
                width: parent.width
                from: 100
                to: 240
                stepSize: 5
                value: rootWindow.editPowerLimit
                onMoved: rootWindow.editPowerLimit = Math.round(value)
              }
              Row {
                spacing: Style.space(6)
                Button { text: "180 W (Eco)"; height: Style.space(24); onClicked: rootWindow.editPowerLimit = 180 }
                Button { text: "220 W (Stock)"; height: Style.space(24); onClicked: rootWindow.editPowerLimit = 220 }
                Button { text: "240 W (Max Headroom)"; height: Style.space(24); onClicked: rootWindow.editPowerLimit = 240 }
              }
            }

            Item { height: Style.space(4); width: 1 }

            // Action Buttons
            Row {
              spacing: Style.space(10)

              Button {
                text: "💾 Save Profile"
                height: Style.space(34)
                onClicked: {
                  if (rootWindow.pluginRoot) {
                    rootWindow.pluginRoot.saveProfile(
                      rootWindow.selectedProfileId,
                      rootWindow.editName,
                      rootWindow.editCoreMax,
                      rootWindow.editMemOffset,
                      rootWindow.editPowerLimit
                    )
                  }
                }
              }

              Button {
                text: "⚡ Save & Apply Now"
                height: Style.space(34)
                onClicked: {
                  if (rootWindow.pluginRoot) {
                    rootWindow.pluginRoot.saveProfile(
                      rootWindow.selectedProfileId,
                      rootWindow.editName,
                      rootWindow.editCoreMax,
                      rootWindow.editMemOffset,
                      rootWindow.editPowerLimit
                    )
                    rootWindow.pluginRoot.applyProfile(rootWindow.selectedProfileId)
                  }
                }
              }

              Button {
                text: "🗑 Delete Profile"
                height: Style.space(34)
                visible: rootWindow.selectedProfileId !== "tuned" && rootWindow.selectedProfileId !== "stock" && rootWindow.selectedProfileId !== "silent" && rootWindow.selectedProfileId !== "maximum"
                onClicked: {
                  if (rootWindow.pluginRoot) {
                    rootWindow.pluginRoot.deleteProfile(rootWindow.selectedProfileId)
                    rootWindow.loadProfileForEdit(rootWindow.pluginRoot.profiles[0])
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
