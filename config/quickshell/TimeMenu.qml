import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    visible: true
    implicitWidth: 380
    implicitHeight: 480
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 200

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    property string currentTab: "sw" // "sw" (Stopwatch), "tm" (Timer), "al" (Alarm)

    // --- STOPWATCH STATE ---
    property bool swRunning: false
    property real swTimeMs: 0
    property real swLastTick: 0

    Timer {
        id: swTimer
        interval: 16 // ~60fps
        running: win.swRunning
        repeat: true
        onTriggered: {
            var now = Date.now();
            if (win.swLastTick > 0) {
                win.swTimeMs += (now - win.swLastTick);
            }
            win.swLastTick = now;
        }
    }

    ListModel { id: lapsModel }

    function formatSwTime(ms) {
        var totalSec = Math.floor(ms / 1000);
        var mins = Math.floor(totalSec / 60);
        var secs = totalSec % 60;
        var hundredths = Math.floor((ms % 1000) / 10);
        var mStr = (mins < 10 ? "0" : "") + mins;
        var sStr = (secs < 10 ? "0" : "") + secs;
        var hStr = (hundredths < 10 ? "0" : "") + hundredths;
        return mStr + ":" + sStr + "." + hStr;
    }

    // --- COUNTDOWN TIMER STATE ---
    property bool tmRunning: false
    property int tmTotalSec: 300 // default 5 min
    property int tmRemainingSec: 300

    Timer {
        id: tmTimer
        interval: 1000
        running: win.tmRunning
        repeat: true
        onTriggered: {
            if (win.tmRemainingSec > 0) {
                win.tmRemainingSec--;
            } else {
                win.tmRunning = false;
                Quickshell.exec(["bash", "-c", "notify-send -u critical 'Temporizador' '¡El tiempo ha terminado!'; paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"]);
            }
        }
    }

    function formatTmTime(totalSec) {
        var mins = Math.floor(totalSec / 60);
        var secs = totalSec % 60;
        var mStr = (mins < 10 ? "0" : "") + mins;
        var sStr = (secs < 10 ? "0" : "") + secs;
        return mStr + ":" + sStr;
    }

    // --- ALARM STATE ---
    ListModel { id: alarmModel }
    property string newAlarmTime: "08:00"

    Timer {
        interval: 10000 // Check every 10s
        running: true
        repeat: true
        onTriggered: {
            var now = new Date();
            var curH = (now.getHours() < 10 ? "0" : "") + now.getHours();
            var curM = (now.getMinutes() < 10 ? "0" : "") + now.getMinutes();
            var curStr = curH + ":" + curM;

            for (var i = 0; i < alarmModel.count; i++) {
                var item = alarmModel.get(i);
                if (item.enabled && item.time === curStr && !item.triggeredToday) {
                    alarmModel.setProperty(i, "triggeredToday", true);
                    Quickshell.exec(["bash", "-c", "notify-send -u critical 'Alarma (" + item.label + ")' '¡Es hora! (" + item.time + ")'; paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true"]);
                }
            }
        }
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

        // Close button overlay
        Rectangle {
            z: 10
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            implicitWidth: 28; implicitHeight: 28; radius: 14
            color: "#d9161b22"
            border.color: "#21262d"
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

            // Top Navigation Tab Bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: "#d9161b22"
                border.color: "#21262d"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    // Tab: Cronometro
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: win.currentTab === "sw" ? "#89b4fa" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󱎫 Cronómetro"
                            font.pixelSize: 11
                            font.bold: true
                            color: win.currentTab === "sw" ? "#0f172a" : "#cdd6f4"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.currentTab = "sw"
                        }
                    }

                    // Tab: Temporizador
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: win.currentTab === "tm" ? "#89b4fa" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰔛 Temporizador"
                            font.pixelSize: 11
                            font.bold: true
                            color: win.currentTab === "tm" ? "#0f172a" : "#cdd6f4"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.currentTab = "tm"
                        }
                    }

                    // Tab: Alarma
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: win.currentTab === "al" ? "#89b4fa" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰂞 Alarma"
                            font.pixelSize: 11
                            font.bold: true
                            color: win.currentTab === "al" ? "#0f172a" : "#cdd6f4"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.currentTab = "al"
                        }
                    }
                }
            }

            // --- TAB 1: CRONÓMETRO ---
            ColumnLayout {
                visible: win.currentTab === "sw"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // Stopwatch Display Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 120
                    radius: 14
                    color: "#d9161b22"
                    border.color: win.swRunning ? "#89b4fa" : "#21262d"
                    border.width: win.swRunning ? 2 : 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.formatSwTime(win.swTimeMs)
                            font.pixelSize: 36
                            font.bold: true
                            font.family: "JetBrains Mono"
                            color: win.swRunning ? "#89b4fa" : "#f8fafc"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.swRunning ? "En marcha" : "Detenido"
                            font.pixelSize: 10
                            color: win.swRunning ? "#89b4fa" : "#6c7086"
                        }
                    }
                }

                // Controls Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Start/Pause Button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 10
                        color: win.swRunning ? "#f38ba8" : "#89b4fa"
                        Text {
                            anchors.centerIn: parent
                            text: win.swRunning ? "󰏤 Pausar" : "󰐊 Iniciar"
                            font.pixelSize: 12; font.bold: true
                            color: "#0f172a"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.swRunning) {
                                    win.swRunning = false;
                                    win.swLastTick = 0;
                                } else {
                                    win.swLastTick = Date.now();
                                    win.swRunning = true;
                                }
                            }
                        }
                    }

                    // Lap Button
                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 38
                        radius: 10
                        color: "#d9161b22"
                        border.color: "#313244"
                        Text { anchors.centerIn: parent; text: "󰓗 Vuelta"; font.pixelSize: 11; color: "#cba6f7" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.swTimeMs > 0) {
                                    lapsModel.insert(0, { "lapNum": lapsModel.count + 1, "lapTime": win.formatSwTime(win.swTimeMs) });
                                }
                            }
                        }
                    }

                    // Reset Button
                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 38
                        radius: 10
                        color: "#d9161b22"
                        border.color: "#313244"
                        Text { anchors.centerIn: parent; text: "󰜉 Reiniciar"; font.pixelSize: 11; color: "#f38ba8" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.swRunning = false;
                                win.swLastTick = 0;
                                win.swTimeMs = 0;
                                lapsModel.clear();
                            }
                        }
                    }
                }

                // Laps List Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#d9161b22"
                    border.color: "#21262d"
                    clip: true

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        model: lapsModel

                        delegate: Rectangle {
                            width: ListView.view.width - 4
                            implicitHeight: 32
                            radius: 8
                            color: "#181825"
                            border.color: "#313244"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12

                                Text { text: "Vuelta " + model.lapNum; font.pixelSize: 11; color: "#a6adc8" }
                                Item { Layout.fillWidth: true }
                                Text { text: model.lapTime; font.pixelSize: 11; font.bold: true; font.family: "JetBrains Mono"; color: "#cdd6f4" }
                            }
                        }
                    }
                }
            }

            // --- TAB 2: TEMPORIZADOR ---
            ColumnLayout {
                visible: win.currentTab === "tm"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // Timer Display Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 120
                    radius: 14
                    color: "#d9161b22"
                    border.color: win.tmRunning ? "#38bdf8" : "#21262d"
                    border.width: win.tmRunning ? 2 : 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.formatTmTime(win.tmRemainingSec)
                            font.pixelSize: 42
                            font.bold: true
                            font.family: "JetBrains Mono"
                            color: win.tmRunning ? "#38bdf8" : "#f8fafc"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.tmRunning ? "Cuenta regresiva" : "Listo para iniciar"
                            font.pixelSize: 10
                            color: win.tmRunning ? "#38bdf8" : "#6c7086"
                        }
                    }
                }

                // Quick Preset Time Add Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "+1 min", sec: 60 },
                            { label: "+5 min", sec: 300 },
                            { label: "+10 min", sec: 600 },
                            { label: "+15 min", sec: 900 }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: 8
                            color: "#d9161b22"
                            border.color: "#313244"
                            Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11; font.bold: true; color: "#89b4fa" }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!win.tmRunning) {
                                        win.tmTotalSec += modelData.sec;
                                        win.tmRemainingSec = win.tmTotalSec;
                                    } else {
                                        win.tmRemainingSec += modelData.sec;
                                    }
                                }
                            }
                        }
                    }
                }

                // Controls Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Start/Pause Button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 10
                        color: win.tmRunning ? "#f38ba8" : "#38bdf8"
                        Text {
                            anchors.centerIn: parent
                            text: win.tmRunning ? "󰏤 Pausar" : "󰐊 Iniciar"
                            font.pixelSize: 12; font.bold: true
                            color: "#0f172a"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.tmRemainingSec <= 0) return;
                                win.tmRunning = !win.tmRunning;
                            }
                        }
                    }

                    // Reset Button
                    Rectangle {
                        implicitWidth: 90
                        implicitHeight: 38
                        radius: 10
                        color: "#d9161b22"
                        border.color: "#313244"
                        Text { anchors.centerIn: parent; text: "󰜉 Reiniciar"; font.pixelSize: 11; color: "#f38ba8" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.tmRunning = false;
                                win.tmTotalSec = 300;
                                win.tmRemainingSec = 300;
                            }
                        }
                    }
                }
            }

            // --- TAB 3: ALARMA ---
            ColumnLayout {
                visible: win.currentTab === "al"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Add Alarm Input Row
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 12
                    color: "#d9161b22"
                    border.color: "#21262d"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 8

                        Text { text: "󰂞 Hora:"; font.pixelSize: 12; font.bold: true; color: "#cba6f7" }

                        Rectangle {
                            implicitWidth: 80; implicitHeight: 30
                            radius: 6; color: "#11111b"; border.color: "#313244"
                            TextInput {
                                id: alarmTimeInput
                                anchors.centerIn: parent
                                text: win.newAlarmTime
                                font.pixelSize: 12; font.bold: true; font.family: "JetBrains Mono"; color: "#f8fafc"
                                onTextChanged: win.newAlarmTime = text
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 95; implicitHeight: 30; radius: 8
                            color: "#cba6f7"
                            Text { anchors.centerIn: parent; text: "+ Agregar"; font.pixelSize: 11; font.bold: true; color: "#0f172a" }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (alarmTimeInput.text.trim()) {
                                        alarmModel.append({
                                            "time": alarmTimeInput.text.trim(),
                                            "label": "Alarma",
                                            "enabled": true,
                                            "triggeredToday": false
                                        });
                                    }
                                }
                            }
                        }
                    }
                }

                // Alarms List Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#d9161b22"
                    border.color: "#21262d"
                    clip: true

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        model: alarmModel

                        delegate: Rectangle {
                            width: ListView.view.width - 4
                            implicitHeight: 48
                            radius: 10
                            color: "#181825"
                            border.color: model.enabled ? "#cba6f7" : "#313244"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: model.time
                                        font.pixelSize: 16; font.bold: true; font.family: "JetBrains Mono"
                                        color: model.enabled ? "#f8fafc" : "#6c7086"
                                    }
                                    Text {
                                        text: model.label
                                        font.pixelSize: 10; color: "#a6adc8"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Toggle Switch
                                Rectangle {
                                    implicitWidth: 40; implicitHeight: 22; radius: 11
                                    color: model.enabled ? "#cba6f7" : "#313244"

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: model.enabled ? 20 : 2
                                        color: "#0f172a"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: alarmModel.setProperty(index, "enabled", !model.enabled)
                                    }
                                }

                                // Delete Alarm Button
                                Rectangle {
                                    implicitWidth: 26; implicitHeight: 26; radius: 13
                                    color: "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: "#f38ba8" }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: alarmModel.remove(index)
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
