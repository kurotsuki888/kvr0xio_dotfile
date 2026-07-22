import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    visible: true
    implicitWidth: 320
    implicitHeight: 400
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 12

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    Rectangle {
        id: container
        anchors.fill: parent
        color: "#d90d1117"
        border.color: "#30363d"
        border.width: 1.5
        radius: 16

        opacity: 0
        scale: 0.95
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
            anchors.margins: 10
            implicitWidth: 26; implicitHeight: 26; radius: 13
            color: "#d9161b22"
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; font.bold: true; color: "#cdd6f4" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Avatar Header
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 96
                implicitHeight: 96
                radius: 14
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

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "kuro"
                font.pixelSize: 14
                font.bold: true
                color: "#cdd6f4"
            }

            Item { Layout.preferredHeight: 4 } // Spacer

            // Action Buttons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Lock
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: "#d9161b22"
                    border.color: "#21262d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 10
                        Text { text: "🔒"; font.pixelSize: 14 }
                        Text { text: "Bloquear pantalla"; font.pixelSize: 12; font.bold: true; color: "#cdd6f4" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.exec(["hyprlock"]);
                            win.destroy();
                        }
                    }
                }

                // Logout
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: "#d9161b22"
                    border.color: "#21262d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 10
                        Text { text: "󰍃"; font.pixelSize: 15; color: "#f5e0dc" }
                        Text { text: "Cerrar sesión"; font.pixelSize: 12; font.bold: true; color: "#cdd6f4" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.exec(["hyprctl", "dispatch", "exit"]);
                            win.destroy();
                        }
                    }
                }

                // Reboot
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: "#d9161b22"
                    border.color: "#21262d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 10
                        Text { text: "󰜉"; font.pixelSize: 15; color: "#89b4fa" }
                        Text { text: "Reiniciar"; font.pixelSize: 12; font.bold: true; color: "#cdd6f4" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.exec(["systemctl", "reboot"]);
                            win.destroy();
                        }
                    }
                }

                // Shutdown
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: "#d9161b22"
                    border.color: "#21262d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 10
                        Text { text: "󰐥"; font.pixelSize: 15; color: "#f38ba8" }
                        Text { text: "Apagar PC"; font.pixelSize: 12; font.bold: true; color: "#f38ba8" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.exec(["systemctl", "poweroff"]);
                            win.destroy();
                        }
                    }
                }
            }
        }
    }
}
