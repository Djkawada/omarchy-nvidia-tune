import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "com.github.djkawada.nvidia-tune"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string ctlPath: Qt.resolvedUrl("bin/nvidia-tune-ctl").toString().replace(/^file:\/\//, "")

  // Live GPU Properties
  property string gpuName: "NVIDIA GeForce RTX 3070"
  property string driverVersion: "615.78"
  property int gpuTemp: 0
  property real powerWatts: 0.0
  property int powerLimit: 220
  property int coreClock: 0
  property int memClock: 0
  property int memOffset: 0
  property int fanSpeed: 0
  property int gpuUtil: 0
  property int memUtil: 0
  property int vramUsed: 0
  property int vramTotal: 8192

  // Profile Management State
  property string activeProfileId: "stock"
  property var activeProfile: null
  property bool isTuned: false
  property var profiles: []

  property bool panelOpen: false
  property bool controlCenterOpen: false

  // High-contrast secondary text colors for excellent legibility (avoids dim/dark muted grey)
  readonly property color textSecondary: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.78)
  readonly property color textDimmed: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.58)

  // Dismiss handler for PopupCard FocusGrab
  function close() {
    root.panelOpen = false
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyProfile(id) {
    applyProc.command = [root.ctlPath, "apply", id]
    applyProc.running = true
  }

  function toggleProfile() {
    toggleProc.command = [root.ctlPath, "toggle"]
    toggleProc.running = true
  }

  function saveProfile(id, name, coreMax, memOffset, powerLimit) {
    saveProc.command = [
      root.ctlPath,
      "save-profile",
      id,
      name,
      String(coreMax),
      String(memOffset),
      String(powerLimit)
    ]
    saveProc.running = true
  }

  function deleteProfile(id) {
    delProc.command = [root.ctlPath, "delete-profile", id]
    delProc.running = true
  }

  function openControlCenter() {
    root.panelOpen = false
    root.controlCenterOpen = true
  }

  function closeControlCenter() {
    root.controlCenterOpen = false
  }

  Loader {
    id: controlCenterLoader
    active: root.controlCenterOpen
    sourceComponent: Component {
      NvidiaControlCenter {
        pluginRoot: root
        visible: true
        onClosing: root.closeControlCenter()
      }
    }
  }

  Component.onCompleted: refresh()

  // Polling Timer: 800ms when open, 3500ms in background
  Timer {
    interval: (root.panelOpen || root.controlCenterOpen) ? 800 : 3500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Process Handlers ---
  Process {
    id: statusProc
    command: [root.ctlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          if (data.success) {
            if (data.gpu) {
              root.gpuName = data.gpu.name || "NVIDIA GPU"
              root.driverVersion = data.gpu.driver_version || ""
            }
            if (data.metrics) {
              root.gpuTemp = data.metrics.temperature || 0
              root.powerWatts = data.metrics.power_w || 0.0
              root.powerLimit = data.metrics.power_limit_w || 220
              root.coreClock = data.metrics.core_clock_mhz || 0
              root.memClock = data.metrics.mem_clock_mhz || 0
              root.memOffset = data.metrics.mem_offset_mhz || 0
              root.fanSpeed = data.metrics.fan_speed_pct || 0
              root.gpuUtil = data.metrics.gpu_utilization_pct || 0
              root.memUtil = data.metrics.mem_utilization_pct || 0
              root.vramUsed = data.metrics.vram_used_mb || 0
              root.vramTotal = data.metrics.vram_total_mb || 8192
            }
            root.activeProfileId = data.active_profile_id || "stock"
            root.activeProfile = data.active_profile || null
            root.isTuned = Boolean(data.is_tuned)
            root.profiles = data.profiles || []
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: toggleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: saveProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: delProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  // --- Top Bar Button ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: root.gpuName + "\n" + (root.isTuned ? ("Tuned: " + (root.activeProfile ? root.activeProfile.name : "Active")) : "Stock Profile") + "\nClock: " + root.coreClock + " MHz | Temp: " + root.gpuTemp + "°C | Power: " + root.powerWatts + "W"

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Image {
          anchors.centerIn: parent
          source: root.isTuned ? Qt.resolvedUrl("assets/nvidia-active.svg") : Qt.resolvedUrl("assets/nvidia-inactive.svg")
          sourceSize.width: Style.space(16)
          sourceSize.height: Style.space(16)
        }

        // Theme-adapted glowing indicator dot
        Rectangle {
          visible: root.isTuned
          width: Style.space(5)
          height: Style.space(5)
          radius: Style.space(2.5)
          color: Commons.Color.accent
          anchors.right: parent.right
          anchors.bottom: parent.bottom
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.openControlCenter()
      } else {
        root.panelOpen = !root.panelOpen
        if (root.panelOpen) root.refresh()
      }
    }
  }

  // --- Flyout Popup Panel ---
  PopupCard {
    id: popupPanel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.panelOpen
    onVisibleChanged: {
      if (!visible) root.panelOpen = false
    }
    contentWidth: popupPanel.fittedContentWidth(Style.space(460))
    contentHeight: popupPanel.fittedContentHeight(contentColumn.implicitHeight)

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(12)

      // Header Card
      Item {
        width: parent.width
        height: Style.space(38)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Image {
            source: root.isTuned ? Qt.resolvedUrl("assets/nvidia-active.svg") : Qt.resolvedUrl("assets/nvidia-inactive.svg")
            sourceSize.width: Style.space(26)
            sourceSize.height: Style.space(26)
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: root.gpuName
              font.pixelSize: 13
              font.bold: true
              color: Commons.Color.foreground
            }

            Text {
              text: root.isTuned ? ("Profile: " + (root.activeProfile ? root.activeProfile.name : "Tuned")) : "Stock Factory Defaults"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: root.isTuned ? Commons.Color.accent : root.textSecondary
            }
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          color: root.isTuned ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.08)
          border.color: root.isTuned ? Commons.Color.accent : Commons.Color.popups.border
          border.width: 1
          radius: Style.space(6)
          width: Style.space(70)
          height: Style.space(24)

          Text {
            anchors.centerIn: parent
            text: root.isTuned ? "TUNED" : "STOCK"
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: root.isTuned ? Commons.Color.accent : root.textSecondary
          }
        }
      }

      // Quick Telemetry Row (Theme-adaptive cards)
      Row {
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: (parent.width - Style.space(24)) / 4
          height: Style.space(56)
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
              text: "TEMP"
              font.pixelSize: 10
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textDimmed
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.gpuTemp + " °C"
              font.pixelSize: 13
              font.bold: true
              renderType: Text.NativeRendering
              color: root.gpuTemp < 65 ? Commons.Color.foreground : Commons.Color.urgent
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Fan " + root.fanSpeed + "%"
              font.pixelSize: 11
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        Rectangle {
          width: (parent.width - Style.space(24)) / 4
          height: Style.space(56)
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
              text: "POWER"
              font.pixelSize: 10
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textDimmed
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.powerWatts + " W"
              font.pixelSize: 13
              font.bold: true
              renderType: Text.NativeRendering
              color: Commons.Color.accent
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: "Cap " + root.powerLimit + "W"
              font.pixelSize: 11
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        Rectangle {
          width: (parent.width - Style.space(24)) / 4
          height: Style.space(56)
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
              text: "CORE"
              font.pixelSize: 10
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textDimmed
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.coreClock + " MHz"
              font.pixelSize: 13
              font.bold: true
              renderType: Text.NativeRendering
              color: Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.activeProfile && root.activeProfile.core_max > 0 ? ("Max " + root.activeProfile.core_max) : "Stock"
              font.pixelSize: 11
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textSecondary
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        Rectangle {
          width: (parent.width - Style.space(24)) / 4
          height: Style.space(56)
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
          radius: Style.space(6)
          border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
          border.width: 1

          Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
              text: "VRAM"
              font.pixelSize: 10
              font.bold: true
              renderType: Text.NativeRendering
              color: root.textDimmed
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.memClock + " MHz"
              font.pixelSize: 13
              font.bold: true
              renderType: Text.NativeRendering
              color: Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              text: root.memOffset > 0 ? ("+" + root.memOffset + " MHz") : "+0 MHz"
              font.pixelSize: 11
              font.bold: true
              renderType: Text.NativeRendering
              color: root.memOffset > 0 ? Commons.Color.accent : Commons.Color.foreground
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }

      // Quick Profile Selection List
      Rectangle {
        width: parent.width
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.04)
        radius: Style.space(6)
        border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
        border.width: 1
        implicitHeight: profCol.implicitHeight + Style.space(16)

        Column {
          id: profCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "PROFILES"
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: root.textDimmed
          }

          Repeater {
            model: root.profiles

            delegate: Rectangle {
              width: profCol.width
              height: Style.space(56)
              radius: Style.space(6)
              readonly property bool isActive: root.activeProfileId === modelData.id
              color: isActive ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.16) : (itemMouse.containsMouse ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.08) : "transparent")
              border.color: isActive ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.12)
              border.width: isActive ? 1.5 : 1

              MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyProfile(modelData.id)
              }

              // Left Info Column (Name + Specs)
              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                anchors.right: badgeContainer.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Row {
                  spacing: Style.space(6)
                  width: parent.width

                  Text {
                    text: isActive ? "●" : "○"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: isActive ? Commons.Color.accent : root.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.name || modelData.id
                    font.pixelSize: 13
                    font.bold: true
                    renderType: Text.NativeRendering
                    color: isActive ? Commons.Color.accent : Commons.Color.foreground
                    elide: Text.ElideRight
                    width: parent.width - Style.space(22)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Row {
                  spacing: Style.space(6)

                  Text {
                    text: modelData.core_max > 0 ? (modelData.core_max + " MHz Core") : "Stock Core"
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                    color: Commons.Color.foreground
                  }

                  Text {
                    text: "•"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: root.textDimmed
                  }

                  Text {
                    text: (modelData.mem_offset > 0 ? ("+" + modelData.mem_offset) : "+0") + " MHz VRAM"
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                    color: modelData.mem_offset > 0 ? Commons.Color.accent : Commons.Color.foreground
                  }

                  Text {
                    text: "•"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: root.textDimmed
                  }

                  Text {
                    text: (modelData.power_limit || 220) + "W Limit"
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                    color: Commons.Color.foreground
                  }
                }
              }

              // Right Badge / Status
              Item {
                id: badgeContainer
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(56)
                height: Style.space(22)

                Rectangle {
                  visible: isActive
                  anchors.fill: parent
                  color: Commons.Color.accent
                  radius: Style.space(4)
                  Text {
                    anchors.centerIn: parent
                    text: "ACTIVE"
                    font.pixelSize: 10
                    font.bold: true
                    renderType: Text.NativeRendering
                    color: Commons.Color.background
                  }
                }

                Text {
                  visible: !isActive && itemMouse.containsMouse
                  anchors.centerIn: parent
                  text: "Apply ↗"
                  font.pixelSize: 11
                  font.bold: true
                  renderType: Text.NativeRendering
                  color: Commons.Color.accent
                }
              }
            }
          }
        }
      }

      // Open Full Control Center Button
      Button {
        width: parent.width
        height: Style.space(34)
        text: "⚡ Open Profile Editor & Control Center ↗"
        selected: true
        onClicked: root.openControlCenter()
      }
    }
  }
}
