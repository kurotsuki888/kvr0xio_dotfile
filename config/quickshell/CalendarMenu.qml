import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    visible: true
    implicitWidth: 380
    implicitHeight: 460
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    anchors.right: true
    margins.top: 36
    margins.right: 280

    Shortcut {
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    property date now: new Date()
    property int selectedYear: now.getFullYear()
    property int selectedMonth: now.getMonth() // 0-11

    property string timeStr: ""
    property string dateStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            win.now = new Date();
            var locale = Qt.locale("es_ES");
            win.timeStr = win.now.toLocaleTimeString(locale, "hh:mm:ss");
            var d = win.now.toLocaleDateString(locale, "dddd, d 'de' MMMM 'de' yyyy");
            win.dateStr = d.charAt(0).toUpperCase() + d.slice(1);
        }
    }

    // Month Names
    readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    function refreshCalendar() {
        gridModel.clear();
        var year = win.selectedYear;
        var month = win.selectedMonth;

        var realNow = new Date();
        var realYear = realNow.getFullYear();
        var realMonth = realNow.getMonth();
        var realDay = realNow.getDate();

        // 0 = Monday, ..., 6 = Sunday
        var firstDay = new Date(year, month, 1).getDay();
        var startOffset = (firstDay === 0) ? 6 : firstDay - 1;

        var prevMonthDays = new Date(year, month, 0).getDate();
        var currentMonthDays = new Date(year, month + 1, 0).getDate();

        // 42 cells grid (6 rows x 7 cols)
        for (var i = 0; i < 42; i++) {
            var dayNum = 0;
            var isCurrent = false;
            var isToday = false;

            if (i < startOffset) {
                dayNum = prevMonthDays - startOffset + i + 1;
                isCurrent = false;
            } else if (i < startOffset + currentMonthDays) {
                dayNum = i - startOffset + 1;
                isCurrent = true;
                if (year === realYear && month === realMonth && dayNum === realDay) {
                    isToday = true;
                }
            } else {
                dayNum = i - (startOffset + currentMonthDays) + 1;
                isCurrent = false;
            }

            gridModel.append({
                "dayNumber": dayNum,
                "isCurrentMonth": isCurrent,
                "isToday": isToday
            });
        }
    }

    Component.onCompleted: refreshCalendar()
    onSelectedMonthChanged: refreshCalendar()
    onSelectedYearChanged: refreshCalendar()

    ListModel {
        id: gridModel
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
            anchors.margins: 18
            spacing: 12

            // Digital Clock & Date Header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                radius: 14
                color: "#d9161b22"
                border.color: "#21262d"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.timeStr
                        font.pixelSize: 26
                        font.bold: true
                        color: "#89b4fa"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.dateStr
                        font.pixelSize: 11
                        color: "#a6adc8"
                    }
                }
            }

            // Month Navigation Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: win.monthNames[win.selectedMonth] + " " + win.selectedYear
                    font.pixelSize: 14
                    font.bold: true
                    color: "#f8fafc"
                    Layout.fillWidth: true
                }

                // Reset to Today Button
                Rectangle {
                    implicitWidth: 60; implicitHeight: 28; radius: 8
                    color: "#d9161b22"
                    border.color: "#313244"
                    Text { anchors.centerIn: parent; text: "Hoy"; font.pixelSize: 10; font.bold: true; color: "#89b4fa" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = new Date();
                            win.selectedYear = t.getFullYear();
                            win.selectedMonth = t.getMonth();
                        }
                    }
                }

                // Prev Month
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: 8
                    color: "#d9161b22"
                    border.color: "#313244"
                    Text { anchors.centerIn: parent; text: "❮"; font.pixelSize: 11; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.selectedMonth === 0) {
                                win.selectedMonth = 11;
                                win.selectedYear--;
                            } else {
                                win.selectedMonth--;
                            }
                        }
                    }
                }

                // Next Month
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: 8
                    color: "#d9161b22"
                    border.color: "#313244"
                    Text { anchors.centerIn: parent; text: "❯"; font.pixelSize: 11; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.selectedMonth === 11) {
                                win.selectedMonth = 0;
                                win.selectedYear++;
                            } else {
                                win.selectedMonth++;
                            }
                        }
                    }
                }
            }

            // Days of the Week Header (Lu, Ma, Mi, Ju, Vi, Sá, Do)
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]
                    delegate: Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: 11
                        font.bold: true
                        color: (index >= 5) ? "#f38ba8" : "#89b4fa"
                    }
                }
            }

            // Month Days Grid (7 columns x 6 rows)
            GridView {
                id: calendarGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: width / 7
                cellHeight: height / 6
                interactive: false
                model: gridModel

                delegate: Item {
                    width: calendarGrid.cellWidth
                    height: calendarGrid.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 4
                        height: width
                        radius: width / 2
                        color: model.isToday ? "#38bdf8" : (dayMouse.containsMouse ? "#313244" : "transparent")
                        border.color: model.isToday ? "#38bdf8" : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: model.dayNumber
                            font.pixelSize: 11
                            font.bold: model.isToday || model.isCurrentMonth
                            color: model.isToday ? "#0f172a" : (model.isCurrentMonth ? "#cdd6f4" : "#45475a")
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
