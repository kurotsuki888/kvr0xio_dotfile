import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    visible: true
    implicitWidth: 400
    implicitHeight: 520
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 50

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    property bool isDnd: false
    property var notifList: []

    // Process to fetch dunst notification history
    Process {
        id: notifProc
        command: ["python3", "-c", "
import json, subprocess, re

def get_notifs():
    try:
        res = subprocess.check_output(['dunstctl', 'history']).decode('utf-8', errors='ignore')
        data = json.loads(res)
        notifications = data.get('data', [[]])[0]
        out = []
        for n in notifications[:12]:
            app = n.get('appname', {}).get('data', 'Notificación').strip() or 'Sistema'
            summary = n.get('summary', {}).get('data', '').strip() or 'Notificación'
            body = n.get('body', {}).get('data', '').strip()
            body_clean = re.sub(r'<[^<]+?>', '', body)
            nid = n.get('id', {}).get('data', 0)
            out.append({
                'id': nid,
                'app': app,
                'summary': summary,
                'body': body_clean
            })
        dnd_res = False
        try:
            dnd_res = 'true' in subprocess.check_output(['dunstctl', 'is-paused']).decode('utf-8', errors='ignore')
        except Exception:
            pass
        return {'dnd': dnd_res, 'notifications': out}
    except Exception as e:
        return {'dnd': False, 'notifications': [], 'error': str(e)}

print(json.dumps(get_notifs()))
"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    win.isDnd = parsed.dnd || false;
                    win.notifList = parsed.notifications || [];
                    notifModel.clear();
                    for (var i = 0; i < win.notifList.length; i++) {
                        notifModel.append(win.notifList[i]);
                    }
                } catch(e) {}
            }
        }
    }

    // Action Process
    Process {
        id: actionProc
        command: ["bash", "-c", "echo 'ok'"]
        stdout: SplitParser {
            onRead: data => {
                notifProc.running = true;
            }
        }
    }

    ListModel {
        id: notifModel
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: notifProc.running = true
    }

    Rectangle {
        id: container
        anchors.fill: parent
        color: "#d90d1117"
        border.color: "#30363d"
        border.width: 1.5
        radius: 18

        opacity: 0
        scale: 0.95
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Component.onCompleted: {
            container.opacity = 1
            container.scale = 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂚 Centro de Notificaciones"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#cba6f7"
                }

                Item { Layout.fillWidth: true }

                // Clear History Button
                Rectangle {
                    implicitWidth: 32; implicitHeight: 32; radius: 16
                    color: "#d9161b22"
                    border.color: "#21262d"
                    Text { anchors.centerIn: parent; text: "󰎟"; font.pixelSize: 14; color: "#f38ba8" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionProc.command = ["bash", "-c", "dunstctl history-clear"];
                            actionProc.running = true;
                        }
                    }
                }

                // Close Button
                Rectangle {
                    implicitWidth: 32; implicitHeight: 32; radius: 16
                    color: "#d9161b22"
                    border.color: "#21262d"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; font.bold: true; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }

            // Notification List Container
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#d9161b22"
                border.color: "#21262d"
                clip: true

                // Empty State
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: notifModel.count === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂛"
                        font.pixelSize: 38
                        color: "#6c7086"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Sin notificaciones recientes"
                        font.pixelSize: 12
                        color: "#9399b2"
                    }
                }

                // Scrollable Notifications List
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: notifModel.count > 0

                    ListView {
                        width: parent.width
                        spacing: 10
                        model: notifModel

                        delegate: Rectangle {
                            width: ListView.view.width - 6
                            implicitHeight: notifCol.implicitHeight + 20
                            radius: 12
                            color: "#181825"
                            border.color: "#313244"
                            border.width: 1

                            ColumnLayout {
                                id: notifCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "󰂚  " + model.app
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#cba6f7"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Dismiss single notification button
                                    Rectangle {
                                        implicitWidth: 20; implicitHeight: 20; radius: 10
                                        color: "transparent"
                                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: "#6c7086" }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                actionProc.command = ["bash", "-c", "dunstctl history-pop " + model.id];
                                                actionProc.running = true;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.summary
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#cdd6f4"
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.body
                                    font.pixelSize: 11
                                    color: "#a6adc8"
                                    wrapMode: Text.Wrap
                                    visible: model.body !== ""
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // DND Toggle Button
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: win.isDnd ? "#f38ba8" : "#d9161b22"
                border.color: win.isDnd ? "#f38ba8" : "#21262d"

                Behavior on color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: win.isDnd ? "󰂛" : "󰂚"; font.pixelSize: 15; color: win.isDnd ? "#0d1117" : "#cba6f7" }
                    Text { text: win.isDnd ? "Modo No Molestar Activo" : "Activar No Molestar"; font.pixelSize: 12; font.bold: true; color: win.isDnd ? "#0d1117" : "#cdd6f4" }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionProc.command = ["bash", "-c", "dunstctl set-paused toggle"];
                        actionProc.running = true;
                    }
                }
            }
        }
    }
}
