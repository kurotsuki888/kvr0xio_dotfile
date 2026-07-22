import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    visible: true
    width: 200
    height: 200
    color: "#1e1e2e"
    
    Text {
        anchors.centerIn: parent
        text: "Quickshell Test"
        color: "white"
    }
}
