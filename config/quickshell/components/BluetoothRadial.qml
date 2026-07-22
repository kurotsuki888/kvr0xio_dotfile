import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 660
    implicitHeight: 440

    property var devices: []
    property bool btPower: false
    property string statusText: "Cargando..."
    property bool isScanning: false
    property bool isBusy: false

    // Map to preserve dragged positions by device MAC across model updates
    property var customPositions: ({})

    function saveCustomPosition(id, xVal, yVal) {
        var posMap = customPositions;
        posMap[id] = { x: xVal, y: yVal };
        customPositions = posMap;
    }

    // Process to scan Bluetooth power and paired/detected devices
    Process {
        id: btProc
        command: ["python3", "-c", "
import json, subprocess, re

def get_bt():
    try:
        powered = False
        show_out = subprocess.check_output(['bluetoothctl', 'show']).decode('utf-8', errors='ignore')
        if 'Powered: yes' in show_out:
            powered = True

        devices = []
        if powered:
            dev_out = subprocess.check_output(['bluetoothctl', 'devices']).decode('utf-8', errors='ignore')
            for line in dev_out.strip().split('\\n'):
                if not line: continue
                m = re.match(r'Device\\s+([0-9A-FA-f:]+)\\s+(.*)', line)
                if m:
                    mac = m.group(1)
                    name = m.group(2).strip()
                    info = ''
                    try:
                        info = subprocess.check_output(['bluetoothctl', 'info', mac]).decode('utf-8', errors='ignore')
                    except Exception:
                        pass
                    connected = 'Connected: yes' in info
                    paired = 'Paired: yes' in info
                    
                    name_l = name.lower()
                    info_l = info.lower()
                    icon = '󰂯'
                    if 'headset' in info_l or 'audio' in info_l or 'audífono' in name_l or 'headphone' in name_l or 'headset' in name_l:
                        icon = '󰋋'
                    elif 'phone' in info_l or 'smartphone' in name_l or 'phone' in name_l:
                        icon = '󰂱'
                    elif 'tv' in info_l or 'television' in name_l or 'tv' in name_l:
                        icon = '󰔁'
                    elif 'speaker' in name_l or 'parlante' in name_l or 'jbl' in name_l:
                        icon = '󰓃'
                    elif 'gamepad' in info_l or 'controller' in name_l or 'joystick' in name_l:
                        icon = '󰊴'

                    devices.append({
                        'mac': mac,
                        'name': name,
                        'connected': connected,
                        'paired': paired,
                        'icon': icon
                    })
        
        devices.sort(key=lambda x: not x['connected'])
        return {'powered': powered, 'devices': devices[:6]}
    except Exception as e:
        return {'powered': False, 'devices': [], 'error': str(e)}

print(json.dumps(get_bt()))
"]
        stdout: SplitParser {
            onRead: data => {
                root.isScanning = false;
                try {
                    var parsed = JSON.parse(data.trim());
                    root.btPower = parsed.powered || false;
                    root.devices = parsed.devices || [];
                    root.statusText = root.btPower ? (root.devices.length > 0 ? "Bluetooth Activo" : "Sin dispositivos") : "Desactivado";

                    devsModel.clear();
                    if (root.btPower) {
                        for (var i = 0; i < root.devices.length; i++) {
                            devsModel.append(root.devices[i]);
                        }
                    }
                    rayCanvas.requestPaint();
                } catch(e) {}
            }
        }
    }

    // Action Process (Power toggle, Connect, Disconnect)
    Process {
        id: actionProc
        command: ["bash", "-c", "echo 'ok'"]
        stdout: SplitParser {
            onRead: data => {
                root.isBusy = false;
                btProc.running = true;
            }
        }
    }

    ListModel {
        id: devsModel
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.isScanning && !root.isBusy) {
                btProc.running = true;
            }
        }
    }

    // Floating Animation Time Counter
    property real floatTime: 0
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            root.floatTime += 0.04;
            rayCanvas.requestPaint();
        }
    }

    // Canvas to draw connecting rays
    Canvas {
        id: rayCanvas
        anchors.fill: parent
        z: 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!root.btPower) return;

            var cX = centerHub.x + centerHub.width / 2;
            var cY = centerHub.y + centerHub.height / 2;

            for (var i = 0; i < devsRepeater.count; i++) {
                var card = devsRepeater.itemAt(i);
                if (card) {
                    var pX = card.x + card.width / 2;
                    var pY = card.y + card.height / 2;

                    ctx.beginPath();
                    ctx.moveTo(cX, cY);

                    var midX = (cX + pX) / 2;
                    var midY = (cY + pY) / 2;
                    ctx.quadraticCurveTo(midX, midY, pX, pY);

                    if (card.isDeviceConnected) {
                        ctx.strokeStyle = "#a6e3a1";
                        ctx.lineWidth = 2.5;
                    } else {
                        ctx.strokeStyle = "#333b4d";
                        ctx.lineWidth = 1.5;
                    }
                    ctx.stroke();
                }
            }
        }
    }

    // Pulsing Outer Ring
    Rectangle {
        id: pulseRing
        z: 8
        width: 200; height: 200; radius: 100
        anchors.centerIn: centerHub
        color: "transparent"
        border.color: root.btPower ? "#89b4fa" : "transparent"
        border.width: 1.5
        opacity: 0.4

        SequentialAnimation {
            running: root.btPower
            loops: Animation.Infinite
            NumberAnimation { target: pulseRing; property: "scale"; from: 0.9; to: 1.25; duration: 1800; easing.type: Easing.OutQuad }
            NumberAnimation { target: pulseRing; property: "opacity"; from: 0.6; to: 0.0; duration: 600 }
            PropertyAction { target: pulseRing; property: "scale"; value: 0.9 }
            PropertyAction { target: pulseRing; property: "opacity"; value: 0.4 }
        }
    }

    // Central Circle Hub (Power Toggle Button)
    Rectangle {
        id: centerHub
        z: 10
        width: 150
        height: 150
        radius: 75
        anchors.centerIn: parent
        color: root.isBusy ? "#2d3748" : (root.btPower ? "#1e293b" : "#181825")
        border.color: root.isBusy ? "#f5e0dc" : (root.btPower ? "#89b4fa" : "#475569")
        border.width: 3

        Behavior on color { ColorAnimation { duration: 300 } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 4

            Text {
                id: hubBtIconText
                Layout.alignment: Qt.AlignHCenter
                text: root.isBusy ? "󰑮" : (root.btPower ? "󰂯" : "󰂲")
                font.pixelSize: 34
                color: root.isBusy ? "#f5e0dc" : (root.btPower ? "#89b4fa" : "#64748b")
                rotation: 0

                NumberAnimation on rotation {
                    running: root.isBusy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running) hubBtIconText.rotation = 0;
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 120
                text: root.isBusy ? "Procesando..." : (root.btPower ? "Bluetooth" : "Apagado")
                font.pixelSize: 12
                font.bold: true
                color: "#f8fafc"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 120
                text: root.isBusy ? "Espere..." : (root.btPower ? "Clic para apagar" : "Clic para encender")
                font.pixelSize: 10
                color: root.isBusy ? "#f5e0dc" : "#94a3b8"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: root.isBusy ? Qt.WaitCursor : Qt.PointingHandCursor
            onClicked: {
                if (root.isBusy) return;
                root.isBusy = true;
                var cmd = root.btPower ? "bluetoothctl power off && rfkill block bluetooth" : "rfkill unblock bluetooth && sleep 0.3 && bluetoothctl power on && bluetoothctl scan on";
                actionProc.command = ["bash", "-c", cmd];
                actionProc.running = true;
            }
        }
    }

    // Floating Draggable Devices Repeater
    Repeater {
        id: devsRepeater
        model: devsModel

        delegate: Item {
            id: devContainer
            z: isDragged ? 20 : 5
            opacity: root.isBusy ? 0.6 : 1.0

            property string devId: model.mac
            property bool isDeviceConnected: model.connected
            property string devMac: model.mac
            property string devName: model.name
            property string devIcon: model.icon
            property bool devPaired: model.paired

            // Drag and Custom Position Tracking
            property real userX: (root.customPositions[devId] !== undefined) ? root.customPositions[devId].x : -1
            property real userY: (root.customPositions[devId] !== undefined) ? root.customPositions[devId].y : -1
            property bool isDragged: false
            property bool isPressed: false
            property real pressStartX: 0
            property real pressStartY: 0

            // Orbital geometry calculation based on index
            property real countTotal: devsRepeater.count > 0 ? devsRepeater.count : 1
            property real baseAngle: (index / countTotal) * 2 * Math.PI - Math.PI / 2
            property real orbitR: 190
            property real baseX: (root.width / 2) + orbitR * Math.cos(baseAngle) - width / 2
            property real baseY: (root.height / 2) + orbitR * Math.sin(baseAngle) - height / 2

            // Subtle Sine Floating movement offset
            property real floatX: isDragged ? 0 : Math.sin(root.floatTime * 1.2 + index * 1.5) * 8
            property real floatY: isDragged ? 0 : Math.cos(root.floatTime * 1.5 + index * 1.2) * 8

            width: 145
            height: 54

            x: (userX >= 0 ? userX : baseX) + floatX
            y: (userY >= 0 ? userY : baseY) + floatY

            onXChanged: rayCanvas.requestPaint()
            onYChanged: rayCanvas.requestPaint()

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: devContainer.isDeviceConnected ? "#193725" : "#d9161b22"
                border.color: devContainer.isDeviceConnected ? "#a6e3a1" : (devMouseArea.containsMouse ? "#89b4fa" : "#30363d")
                border.width: devContainer.isDeviceConnected ? 2 : 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: devContainer.devIcon
                        font.pixelSize: 18
                        color: devContainer.isDeviceConnected ? "#a6e3a1" : "#89b4fa"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: devContainer.devName
                            font.pixelSize: 12
                            font.bold: true
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: devContainer.isDeviceConnected ? "Conectado" : (devContainer.devPaired ? "Conectar" : "Vincular")
                            font.pixelSize: 9
                            color: devContainer.isDeviceConnected ? "#a6e3a1" : "#a6adc8"
                        }
                    }
                }

                MouseArea {
                    id: devMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.isBusy ? Qt.WaitCursor : (devContainer.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor)

                    onPressed: (mouse) => {
                        if (root.isBusy) return;
                        devContainer.pressStartX = mouse.x;
                        devContainer.pressStartY = mouse.y;
                        devContainer.isPressed = true;
                        devContainer.isDragged = false;
                    }

                    onPositionChanged: (mouse) => {
                        if (!devContainer.isPressed || root.isBusy) return;
                        var dx = mouse.x - devContainer.pressStartX;
                        var dy = mouse.y - devContainer.pressStartY;
                        if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                            devContainer.isDragged = true;
                            var currentBaseX = (devContainer.userX >= 0 ? devContainer.userX : devContainer.baseX);
                            var currentBaseY = (devContainer.userY >= 0 ? devContainer.userY : devContainer.baseY);
                            var targetX = Math.max(10, Math.min(root.width - devContainer.width - 10, currentBaseX + dx));
                            var targetY = Math.max(10, Math.min(root.height - devContainer.height - 10, currentBaseY + dy));
                            devContainer.userX = targetX;
                            devContainer.userY = targetY;
                            root.saveCustomPosition(devContainer.devId, targetX, targetY);
                        }
                    }

                    onReleased: (mouse) => {
                        if (root.isBusy) return;
                        devContainer.isPressed = false;
                        if (!devContainer.isDragged) {
                            // CLICKED! Connect action
                            root.isBusy = true;
                            var cmd = devContainer.isDeviceConnected ? 
                                "bluetoothctl disconnect '" + devContainer.devMac + "'" : 
                                "bluetoothctl connect '" + devContainer.devMac + "'";
                            actionProc.command = ["bash", "-c", cmd];
                            actionProc.running = true;
                        } else {
                            devContainer.isDragged = false;
                            root.saveCustomPosition(devContainer.devId, devContainer.userX, devContainer.userY);
                        }
                    }
                }
            }
        }
    }
}
