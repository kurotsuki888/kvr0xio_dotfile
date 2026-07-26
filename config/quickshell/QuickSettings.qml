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

    // Leer $HOME del sistema (más fiable que StandardPaths en Quickshell)
    Process {
        id: homeProc
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let h = data.trim();
                if (h.length > 0) {
                    win.homePath = h;
                    // Cargar avatar una vez que tenemos el path real
                    avatarImage.source = "file://" + win.homePath + "/.config/hypr/profile.png?t=" + Date.now();
                }
            }
        }
    }

    // Leer nombre del usuario del sistema
    Process {
        id: userProc
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let u = data.trim();
                if (u.length > 0) win.currentUser = u;
            }
        }
    }

    // Proceso para cambiar foto de perfil
    // Usa magick para convertir cualquier formato a PNG sRGB correcto
    Process {
        id: profileProc
        command: ["bash", "-c", "echo ok"]
        onExited: (exitCode, status) => {
            if (exitCode === 0) {
                win.profileStatus = "success";
                // Recargar imagen con cache-bust
                avatarImage.source = "";
                avatarImage.source = "file://" + win.homePath + "/.config/hypr/profile.png?t=" + Date.now();
                statusResetTimer.restart();
            } else if (exitCode === 1) {
                // Código 1 = el usuario canceló zenity (sin archivo elegido), no es error real
                win.profileStatus = "idle";
            } else {
                win.profileStatus = "error";
                win.profileError = "Error al convertir (cód. " + exitCode + ")";
                statusResetTimer.restart();
            }
        }
    }

    // Timer para auto-limpiar el estado de éxito/error
    Timer {
        id: statusResetTimer
        interval: 3000
        onTriggered: win.profileStatus = "idle"
    }

    // Ruta home leída del sistema
    property string homePath: ""
    // Ruta del perfil (construida una vez que homePath esté disponible)
    readonly property string avatarPath: homePath + "/.config/hypr/profile.png"
    // Nombre de usuario dinámico
    property string currentUser: "usuario"
    // Estado del proceso de cambio de foto: idle | loading | success | error
    property string profileStatus: "idle"
    // Mensaje de error si falla
    property string profileError: ""

    function runCmd(cmdStr) {
        execProc.command = ["bash", "-c", cmdStr];
        execProc.running = true;
    }

    function changeProfilePhoto() {
        win.profileStatus = "loading";
        win.profileError = "";
        profileProc.command = [
            "bash", "-c",
            // Zenity abre selector, si el usuario cancela sale con código 1
            // magick convierte cualquier formato (jpg, png, webp, avif, gif, bmp, tiff, heic...)
            "f=$(zenity --file-selection "
            + "--title='Elige tu foto de perfil' "
            + "--file-filter='Imágenes | *.jpg *.jpeg *.png *.webp *.avif *.gif *.bmp *.tiff *.heic *.JPG *.PNG' "
            + "2>/dev/null) || exit 1; "
            + "[ -z \"$f\" ] && exit 1; "
            + "magick \"$f\" -colorspace sRGB -type TrueColor ~/.config/hypr/profile.png || exit 2"
        ];
        profileProc.running = true;
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
                        id: avatarImage
                        anchors.fill: parent
                        // source se asigna dinámicamente en homeProc.onRead
                        source: ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text { id: usernameText; text: win.currentUser; font.pixelSize: 15; font.bold: true; color: "#cdd6f4" }
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

            // Separador
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#21262d"; opacity: 0.5 }

            // Botón cambiar foto de perfil
            Rectangle {
                id: photoBtn
                Layout.fillWidth: true
                implicitHeight: win.profileStatus === "error" ? 52 : 36
                radius: 8
                color: profileHover.containsMouse && win.profileStatus === "idle" ? "#1a313244" : "transparent"
                border.color: {
                    if (win.profileStatus === "error")   return "#f38ba8";
                    if (win.profileStatus === "success") return "#a6e3a1";
                    return "#30363d";
                }
                border.width: 1

                Behavior on color   { ColorAnimation  { duration: 120 } }
                Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 4

                    // Fila principal del botón
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text { text: "🖼"; font.pixelSize: 13; opacity: win.profileStatus === "loading" ? 0.4 : 1 }

                        Text {
                            text: "Cambiar foto de perfil"
                            font.pixelSize: 11
                            color: {
                                if (win.profileStatus === "success") return "#a6e3a1";
                                if (win.profileStatus === "error")   return "#f38ba8";
                                return "#7f849c";
                            }
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        // --- Indicador de estado ---

                        // Spinner de carga (solo visible en loading)
                        Rectangle {
                            id: spinner
                            visible: win.profileStatus === "loading"
                            implicitWidth: 14; implicitHeight: 14
                            radius: 7
                            color: "transparent"
                            border.color: "#89b4fa"
                            border.width: 2

                            // Arco animado encima
                            Rectangle {
                                width: 6; height: 6
                                radius: 3
                                color: "#89b4fa"
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: -2
                            }

                            RotationAnimator on rotation {
                                running: win.profileStatus === "loading"
                                from: 0; to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }

                        // Tick de éxito
                        Text {
                            visible: win.profileStatus === "success"
                            text: "✓"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#a6e3a1"
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // X de error
                        Text {
                            visible: win.profileStatus === "error"
                            text: "✗"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f38ba8"
                        }
                    }

                    // Fila de mensaje de error (solo visible en error)
                    Text {
                        visible: win.profileStatus === "error"
                        text: win.profileError
                        font.pixelSize: 9
                        color: "#f38ba8"
                        opacity: 0.8
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                MouseArea {
                    id: profileHover
                    anchors.fill: parent
                    cursorShape: win.profileStatus === "loading" ? Qt.BusyCursor : Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: win.profileStatus !== "loading"
                    onClicked: win.changeProfilePhoto()
                }
            }

            Item { Layout.preferredHeight: 2 }
        }
    }
}
