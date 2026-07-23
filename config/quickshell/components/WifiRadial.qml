import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 660
    implicitHeight: 440

    property var networks: []
    property bool wifiPowered: true
    property bool connected: false
    property string activeSsid: ""
    property string activeIp: "Offline"
    property int activeSignal: 0
    property string activeSecurity: ""
    property bool isScanning: false
    property bool isBusy: false

    // Map to preserve dragged positions by SSID across model updates
    property var customPositions: ({})

    function saveCustomPosition(id, xVal, yVal) {
        var posMap = customPositions;
        posMap[id] = { x: xVal, y: yVal };
        customPositions = posMap;
    }

    // Password prompt dialog state
    property bool showPasswordPrompt: false
    property string targetSsid: ""
    property string passwordInput: ""
    property string connectError: ""

    Component.onCompleted: {
        wifiProc.running = true;
    }

    // Process to scan Wi-Fi networks and active status
    Process {
        id: wifiProc
        command: ["python3", "-c", "
import json, subprocess, socket

def get_wifi():
    try:
        radio = subprocess.check_output(['nmcli', 'radio', 'wifi']).decode('utf-8').strip()
        wifi_powered = (radio == 'enabled')

        networks = []
        active_wifi = None
        ip = 'Offline'

        if wifi_powered:
            saved = set()
            try:
                saved_lines = subprocess.check_output(['nmcli', '-t', '-f', 'NAME', 'connection', 'show']).decode('utf-8', errors='ignore').splitlines()
                saved = {s.strip() for s in saved_lines if s.strip()}
            except Exception:
                pass

            res = subprocess.check_output(['nmcli', '-t', '-f', 'ACTIVE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list', '--rescan', 'auto']).decode('utf-8', errors='ignore')
            seen = set()
            try:
                ip_res = subprocess.check_output(['hostname', '-I'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore').strip()
                if ip_res:
                    ip = ip_res.split()[0]
            except Exception:
                ip = 'Offline'

            for line in res.strip().split('\\n'):
                if not line: continue
                parts = line.split(':')
                if len(parts) < 4: continue
                active = parts[0].strip().lower() in ['sí', 'yes', 'true', '1']
                ssid = parts[1].strip()
                if not ssid or ssid in seen: continue
                seen.add(ssid)
                signal = int(parts[2].strip()) if parts[2].strip().isdigit() else 0
                security = parts[3].strip() or 'Abierta'
                item = {
                    'ssid': ssid,
                    'signal': signal,
                    'security': security,
                    'active': active,
                    'saved': ssid in saved
                }
                if active:
                    active_wifi = item
                networks.append(item)
            
            networks.sort(key=lambda x: (not x['active'], -x['signal']))

        return {
            'wifi_powered': wifi_powered,
            'connected': active_wifi is not None,
            'active_ssid': active_wifi['ssid'] if active_wifi else '',
            'active_ip': ip if active_wifi else 'Offline',
            'active_signal': active_wifi['signal'] if active_wifi else 0,
            'active_security': active_wifi['security'] if active_wifi else 'None',
            'networks': networks[:8]
        }
    except Exception as e:
        return {'wifi_powered': False, 'connected': False, 'active_ssid': '', 'active_ip': 'Offline', 'active_signal': 0, 'active_security': 'None', 'networks': [], 'error': str(e)}

print(json.dumps(get_wifi()))
"]
        stdout: SplitParser {
            onRead: data => {
                root.isScanning = false;
                try {
                    var parsed = JSON.parse(data.trim());
                    root.wifiPowered = parsed.wifi_powered !== undefined ? parsed.wifi_powered : true;
                    root.connected = parsed.connected || false;
                    root.activeSsid = parsed.active_ssid || "";
                    root.activeIp = parsed.active_ip || "Offline";
                    root.activeSignal = parsed.active_signal || 0;
                    root.activeSecurity = parsed.active_security || "";
                    root.networks = parsed.networks || [];
                    
                    cardsModel.clear();
                    if (root.wifiPowered) {
                        for (var i = 0; i < root.networks.length; i++) {
                            cardsModel.append(root.networks[i]);
                        }
                    }
                    rayCanvas.requestPaint();
                } catch(e) {}
            }
        }
    }

    // Toggle Power / Connect Action Process
    Process {
        id: actionProc
        command: ["bash", "-c", "echo 'ok'"]
        stdout: SplitParser {
            onRead: data => {
                var res = data.trim();
                if (res.includes("Error") || res.includes("error") || res.includes("failed") || res.includes("falló")) {
                    root.connectError = "Error al conectar. Revisa la clave.";
                } else {
                    root.showPasswordPrompt = false;
                    root.connectError = "";
                }
                root.isBusy = false;
                wifiProc.running = true;
            }
        }
    }

    // Process to force full Wi-Fi rescan
    Process {
        id: rescanProc
        command: ["bash", "-c", "nmcli dev wifi rescan"]
        stdout: SplitParser {
            onRead: data => {
                wifiProc.running = true;
            }
        }
    }

    Timer {
        id: rescanDelayTimer
        interval: 2800
        repeat: false
        onTriggered: {
            root.isScanning = false;
            wifiProc.running = true;
        }
    }

    ListModel {
        id: cardsModel
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.isScanning && !root.isBusy) {
                wifiProc.running = true;
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

    // Canvas to draw rays connecting center hub to floating cards
    Canvas {
        id: rayCanvas
        anchors.fill: parent
        z: 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!root.wifiPowered) return;

            var cX = centerHub.x + centerHub.width / 2;
            var cY = centerHub.y + centerHub.height / 2;

            for (var i = 0; i < cardsRepeater.count; i++) {
                var card = cardsRepeater.itemAt(i);
                if (card) {
                    var pX = card.x + card.width / 2;
                    var pY = card.y + card.height / 2;

                    ctx.beginPath();
                    ctx.moveTo(cX, cY);

                    var midX = (cX + pX) / 2;
                    var midY = (cY + pY) / 2;
                    ctx.quadraticCurveTo(midX, midY, pX, pY);

                    if (card.isNetworkActive) {
                        ctx.strokeStyle = "#38bdf8";
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

    // Re-scan Button (Top-left corner)
    Rectangle {
        id: rescanBtn
        z: 30
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        implicitHeight: 32
        implicitWidth: rescanRow.implicitWidth + 20
        radius: 16
        color: "#d9161b22"
        border.color: root.isScanning ? "#38bdf8" : "#30363d"
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            id: rescanRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                id: rescanIconText
                text: "󰑐"
                font.pixelSize: 14
                color: root.isScanning ? "#38bdf8" : "#89b4fa"
                rotation: 0

                NumberAnimation on rotation {
                    running: root.isScanning
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running) rescanIconText.rotation = 0;
                    }
                }
            }

            Text {
                text: root.isScanning ? "Buscando..." : "Escanear redes"
                font.pixelSize: 11
                font.bold: true
                color: root.isScanning ? "#38bdf8" : "#cdd6f4"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: root.isScanning ? Qt.WaitCursor : Qt.PointingHandCursor
            onClicked: {
                if (root.isScanning || root.isBusy) return;
                root.isScanning = true;
                rescanProc.command = ["bash", "-c", "nmcli dev wifi rescan"];
                rescanProc.running = true;
                rescanDelayTimer.start();
            }
        }
    }

    // Central Circle Hub (Power Toggle Button)
    Rectangle {
        id: centerHub
        z: 10
        width: 160
        height: 160
        radius: 80
        anchors.centerIn: parent
        color: root.isBusy ? "#2d3748" : (!root.wifiPowered ? "#181825" : (root.connected ? "#1e3a47" : "#1f2430"))
        border.color: root.isBusy ? "#f5e0dc" : (!root.wifiPowered ? "#475569" : (root.connected ? "#38bdf8" : "#89b4fa"))
        border.width: 3

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 4

            Text {
                id: hubIconText
                Layout.alignment: Qt.AlignHCenter
                text: root.isBusy ? "󰑮" : (!root.wifiPowered ? "󰤭" : (root.connected ? "󰤨" : "󰤥"))
                font.pixelSize: 34
                color: root.isBusy ? "#f5e0dc" : (!root.wifiPowered ? "#64748b" : (root.connected ? "#38bdf8" : "#89b4fa"))
                rotation: 0

                NumberAnimation on rotation {
                    running: root.isBusy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running) hubIconText.rotation = 0;
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 125
                text: root.isBusy ? "Procesando..." : (!root.wifiPowered ? "Wi-Fi Apagado" : (root.connected ? root.activeSsid : "Wi-Fi Encendido"))
                font.pixelSize: 12
                font.bold: true
                color: "#f8fafc"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 125
                text: root.isBusy ? "Espere..." : (!root.wifiPowered ? "Clic para encender" : (root.connected ? root.activeIp : "Clic para apagar"))
                font.pixelSize: 10
                color: root.isBusy ? "#f5e0dc" : (!root.wifiPowered ? "#64748b" : (root.connected ? "#38bdf8" : "#94a3b8"))
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
                var cmd = root.wifiPowered ? "nmcli radio wifi off" : "nmcli radio wifi on";
                actionProc.command = ["bash", "-c", cmd];
                actionProc.running = true;
            }
        }
    }

    // Floating Draggable Cards Repeater
    Repeater {
        id: cardsRepeater
        model: cardsModel

        delegate: Item {
            id: cardContainer
            z: isDragged ? 20 : 5
            opacity: root.isBusy ? 0.6 : 1.0

            property string cardId: model.ssid
            property bool isNetworkActive: model.active
            property string cardSsid: model.ssid
            property int cardSignal: model.signal
            property string cardSec: model.security
            property bool cardSaved: model.saved

            // Drag and Custom Position Tracking
            property real userX: (root.customPositions[cardId] !== undefined) ? root.customPositions[cardId].x : -1
            property real userY: (root.customPositions[cardId] !== undefined) ? root.customPositions[cardId].y : -1
            property bool isDragged: false
            property bool isPressed: false
            property real pressStartX: 0
            property real pressStartY: 0

            // Orbital geometry calculation based on signal percentage (% signal)
            property real countTotal: cardsRepeater.count > 0 ? cardsRepeater.count : 1
            property real signalVal: Math.max(5, Math.min(100, cardSignal))
            property real minR: 125 // Strongest signal (100%) - closest to center hub without touching
            property real maxR: 215 // Weakest signal (0%) - furthest away
            property real orbitR: maxR - ((signalVal / 100.0) * (maxR - minR))
            
            // Distributed angle with organic offset
            property real angleJitter: (index % 2 === 1 ? 0.15 : -0.15)
            property real baseAngle: (index / countTotal) * 2 * Math.PI - Math.PI / 2 + angleJitter
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
                color: cardContainer.isNetworkActive ? "#1e3a47" : "#d9161b22"
                border.color: cardContainer.isNetworkActive ? "#38bdf8" : (cardMouseArea.containsMouse ? "#89b4fa" : "#30363d")
                border.width: cardContainer.isNetworkActive ? 2 : 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: cardContainer.cardSignal > 70 ? "󰤨" : (cardContainer.cardSignal > 40 ? "󰤥" : "󰤢")
                        font.pixelSize: 18
                        color: cardContainer.isNetworkActive ? "#38bdf8" : "#89b4fa"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: cardContainer.cardSsid
                            font.pixelSize: 12
                            font.bold: true
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: cardContainer.isNetworkActive ? "Conectado" : (cardContainer.cardSaved ? "Guardada" : cardContainer.cardSignal + "% • " + cardContainer.cardSec)
                                font.pixelSize: 9
                                color: cardContainer.isNetworkActive ? "#38bdf8" : (cardContainer.cardSaved ? "#a6e3a1" : "#a6adc8")
                            }
                        }
                    }
                }

                MouseArea {
                    id: cardMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.isBusy ? Qt.WaitCursor : (cardContainer.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor)

                    onPressed: (mouse) => {
                        if (root.isBusy) return;
                        cardContainer.pressStartX = mouse.x;
                        cardContainer.pressStartY = mouse.y;
                        cardContainer.isPressed = true;
                        cardContainer.isDragged = false;
                    }

                    onPositionChanged: (mouse) => {
                        if (!cardContainer.isPressed || root.isBusy) return;
                        var dx = mouse.x - cardContainer.pressStartX;
                        var dy = mouse.y - cardContainer.pressStartY;
                        if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                            cardContainer.isDragged = true;
                            var currentBaseX = (cardContainer.userX >= 0 ? cardContainer.userX : cardContainer.baseX);
                            var currentBaseY = (cardContainer.userY >= 0 ? cardContainer.userY : cardContainer.baseY);
                            var targetX = Math.max(10, Math.min(root.width - cardContainer.width - 10, currentBaseX + dx));
                            var targetY = Math.max(10, Math.min(root.height - cardContainer.height - 10, currentBaseY + dy));
                            cardContainer.userX = targetX;
                            cardContainer.userY = targetY;
                            root.saveCustomPosition(cardContainer.cardId, targetX, targetY);
                        }
                    }

                    onReleased: (mouse) => {
                        if (root.isBusy) return;
                        cardContainer.isPressed = false;
                        if (!cardContainer.isDragged) {
                            // CLICKED! Connect action
                            if (cardContainer.isNetworkActive) return;
                            root.targetSsid = cardContainer.cardSsid;

                            if (cardContainer.cardSaved) {
                                // Connect to saved connection directly
                                root.isBusy = true;
                                actionProc.command = ["bash", "-c", "nmcli connection up '" + cardContainer.cardSsid + "'"];
                                actionProc.running = true;
                            } else if (cardContainer.cardSec.includes("WPA") || cardContainer.cardSec.includes("WEP")) {
                                // Show our internal password mini-menu dialog
                                root.passwordInput = "";
                                root.connectError = "";
                                showPassCheck.checked = false;
                                root.showPasswordPrompt = true;
                            } else {
                                // Connect to open network directly
                                root.isBusy = true;
                                actionProc.command = ["bash", "-c", "nmcli dev wifi connect '" + cardContainer.cardSsid + "'"];
                                actionProc.running = true;
                            }
                        } else {
                            cardContainer.isDragged = false;
                            root.saveCustomPosition(cardContainer.cardId, cardContainer.userX, cardContainer.userY);
                        }
                    }
                }
            }
        }
    }

    // Password Prompt Floating Mini-Menu Dialog (Prevents Gnome-Keyring / Linux prompt)
    Rectangle {
        id: passDialog
        z: 100
        anchors.centerIn: parent
        width: 340
        height: 190
        radius: 16
        color: "#181825"
        border.color: "#38bdf8"
        border.width: 1.5
        visible: root.showPasswordPrompt

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰤨  Conectar a " + root.targetSsid
                    font.pixelSize: 13
                    font.bold: true
                    color: "#f8fafc"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: "#313244"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPasswordPrompt = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 10
                color: "#11111b"
                border.color: passInputText.activeFocus ? "#38bdf8" : "#313244"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    TextInput {
                        id: passInputText
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        echoMode: showPassCheck.checked ? TextInput.Normal : TextInput.Password
                        font.pixelSize: 12
                        color: "#f8fafc"
                        focus: root.showPasswordPrompt
                        text: root.passwordInput
                        onTextChanged: root.passwordInput = text

                        Text {
                            text: "Contraseña WPA/WPA2..."
                            color: "#6c7086"
                            font.pixelSize: 12
                            visible: !passInputText.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: showPassCheck.checked ? "󰈈" : "󰈉"
                        font.pixelSize: 14
                        color: "#89b4fa"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showPassCheck.checked = !showPassCheck.checked
                        }
                    }
                }
            }

            CheckBox { id: showPassCheck; visible: false; checked: false }

            Text {
                text: root.connectError
                font.pixelSize: 10
                color: "#f38ba8"
                visible: root.connectError !== ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 8
                    color: "#313244"
                    Text { anchors.centerIn: parent; text: "Cancelar"; font.pixelSize: 11; color: "#cdd6f4" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPasswordPrompt = false
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 8
                    color: root.isBusy ? "#64748b" : "#38bdf8"
                    opacity: root.isBusy ? 0.7 : 1.0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.isBusy ? "󰑮" : "󰄬"
                            font.pixelSize: 12
                            color: "#0f172a"
                        }
                        Text {
                            text: root.isBusy ? "Conectando..." : "Conectar"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#0f172a"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.isBusy ? Qt.WaitCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (root.isBusy) return;
                            if (!root.passwordInput.trim()) {
                                root.connectError = "Ingresa la contraseña";
                                return;
                            }
                            root.isBusy = true;
                            root.connectError = "";
                            var cmd = "nmcli dev wifi connect '" + root.targetSsid + "' password '" + root.passwordInput + "' && nmcli connection modify '" + root.targetSsid + "' 802-11-wireless-security.psk-flags 0";
                            actionProc.command = ["bash", "-c", cmd];
                            actionProc.running = true;
                        }
                    }
                }
            }
        }
    }
}
