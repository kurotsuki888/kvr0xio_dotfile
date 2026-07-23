import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    visible: true
    implicitWidth: 360
    implicitHeight: 570
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 12

    Process {
        id: execProc
        command: ["bash", "-c", "echo ok"]
    }

    function runCmd(cmdStr) {
        execProc.command = ["bash", "-c", cmdStr];
        execProc.running = true;
    }

    function launchApp(cmdStr) {
        execProc.command = ["bash", "-c", "hyprctl dispatch exec \"" + cmdStr + "\""];
        execProc.running = true;
        closeTimer.start();
    }

    Timer {
        id: closeTimer
        interval: 100
        onTriggered: Qt.quit()
    }

    // Process to get current volume
    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v)) volSlider.value = v;
            }
        }
    }

    // Process to get current brightness
    Process {
        id: brightProc
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let b = parseInt(data.trim());
                if (!isNaN(b)) brightSlider.value = b;
            }
        }
    }

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    Rectangle {
        id: container
        anchors.fill: parent
        color: "#f20f111a"
        border.color: "#30363d"
        border.width: 1.5
        radius: 18

        opacity: 0
        scale: 0.96
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Component.onCompleted: {
            container.opacity = 1
            container.scale = 1
        }

        // Close button overlay
        Rectangle {
            z: 10
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            implicitWidth: 26; implicitHeight: 26; radius: 13
            color: "#21262d"
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; font.bold: true; color: "#cdd6f4" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Header Section with User Avatar & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 12
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "file:///home/kuro/.config/rofi/kurop_avatar.png"
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text { text: "kuro"; font.pixelSize: 15; font.bold: true; color: "#cdd6f4" }
                    Text { text: "Ajustes Rápidos"; font.pixelSize: 12; color: "#89b4fa" }
                }

                Item { Layout.fillWidth: true }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#21262d" }

            // Volume Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰕾  Volumen"; font.pixelSize: 13; font.bold: true; color: "#cdd6f4" }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(volSlider.value) + "%"; font.pixelSize: 12; color: "#89b4fa"; font.bold: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 8
                        color: "#21262d"
                        Text { anchors.centerIn: parent; text: "󰖁"; font.pixelSize: 14; color: "#f38ba8" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        }
                    }

                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: 50
                        onMoved: win.runCmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + Math.round(value) + "%")
                    }

                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 8
                        color: "#21262d"
                        Text { anchors.centerIn: parent; text: "󰓃"; font.pixelSize: 14; color: "#89b4fa" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.launchApp("env GTK_THEME=Adwaita:dark pavucontrol")
                        }
                    }
                }
            }

            // Brightness Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰃠  Brillo"; font.pixelSize: 13; font.bold: true; color: "#cdd6f4" }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(brightSlider.value) + "%"; font.pixelSize: 12; color: "#f9e2af"; font.bold: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Slider {
                        id: brightSlider
                        Layout.fillWidth: true
                        from: 5
                        to: 100
                        value: 80
                        onMoved: win.runCmd("brightnessctl set " + Math.round(value) + "%")
                    }
                }
            }

            // Bluetooth Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 10
                color: "#1e1e2e"
                border.color: "#313244"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text { text: "󰂯"; font.pixelSize: 18; color: "#89b4fa" }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { 
                            text: "Bluetooth"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                        }
                        Text { 
                            text: "Dispositivos"
                            font.pixelSize: 10
                            color: "#a6adc8"
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        implicitWidth: 64; implicitHeight: 30; radius: 6
                        color: "#313244"
                        Text { anchors.centerIn: parent; text: "Abrir"; font.pixelSize: 11; font.bold: true; color: "#cdd6f4" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.launchApp("~/.config/waybar/scripts/toggle-quickshell.sh ~/.config/quickshell/ControlCenter.qml")
                        }
                    }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#21262d" }

            // Power Buttons Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Lock
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: "#21262d"
                    Text { anchors.centerIn: parent; text: "🔒  Bloquear"; font.pixelSize: 11; font.bold: true; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.launchApp("hyprlock")
                    }
                }

                // Logout
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: "#21262d"
                    Text { anchors.centerIn: parent; text: "󰍃  Salir"; font.pixelSize: 11; font.bold: true; color: "#f5e0dc" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.launchApp("hyprctl dispatch exit")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Reboot
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: "#21262d"
                    Text { anchors.centerIn: parent; text: "󰜉  Reiniciar"; font.pixelSize: 11; font.bold: true; color: "#89b4fa" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.runCmd("systemctl reboot")
                    }
                }

                // Shutdown
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: "#21262d"
                    Text { anchors.centerIn: parent; text: "󰐥  Apagar"; font.pixelSize: 11; font.bold: true; color: "#f38ba8" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.runCmd("systemctl poweroff")
                    }
                }
            }
        }
    }
}
