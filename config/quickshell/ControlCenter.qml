import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "components"

PanelWindow {
    id: win
    visible: true
    implicitWidth: 700
    implicitHeight: 520
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 40

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    property string currentTab: "wifi"

    Rectangle {
        id: container
        anchors.fill: parent
        color: "#d90d1117"
        border.color: "#21262d"
        border.width: 2
        radius: 18

        opacity: 0
        scale: 0.95
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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
            implicitWidth: 28; implicitHeight: 28; radius: 14
            color: "#d9161b22"
            border.color: "#21262d"
            border.width: 1
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; font.bold: true; color: "#cdd6f4" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // View Content (WifiRadial or BluetoothRadial)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                WifiRadial {
                    anchors.centerIn: parent
                    visible: win.currentTab === "wifi"
                }

                BluetoothRadial {
                    anchors.centerIn: parent
                    visible: win.currentTab === "bt"
                }
            }

            // Bottom Navigation Bar (Matches screenshot bottom bar!)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                spacing: 12

                // Center Tab Buttons Container
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 320
                    implicitHeight: 46
                    radius: 12
                    color: "#d9161b22"
                    border.color: "#21262d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        // Wi-Fi Tab Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: win.currentTab === "wifi" ? "#38bdf8" : "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰤨"
                                    font.pixelSize: 16
                                    color: win.currentTab === "wifi" ? "#0f172a" : "#94a3b8"
                                }
                                Text {
                                    text: "Wi-Fi"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: win.currentTab === "wifi" ? "#0f172a" : "#f1f5f9"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.currentTab = "wifi"
                            }
                        }

                        // Bluetooth Tab Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: win.currentTab === "bt" ? "#38bdf8" : "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰂯"
                                    font.pixelSize: 16
                                    color: win.currentTab === "bt" ? "#0f172a" : "#94a3b8"
                                }
                                Text {
                                    text: "Bluetooth"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: win.currentTab === "bt" ? "#0f172a" : "#f1f5f9"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.currentTab = "bt"
                            }
                        }
                    }
                }


            }
        }
    }
}
