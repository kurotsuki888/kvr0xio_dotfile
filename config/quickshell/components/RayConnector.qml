import QtQuick

Canvas {
    id: canvas
    anchors.fill: parent
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property color rayColor: "#3b4252"
    property real strokeWidth: 1.5

    onStartXChanged: requestPaint()
    onStartYChanged: requestPaint()
    onEndXChanged: requestPaint()
    onEndYChanged: requestPaint()
    onRayColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (startX === 0 && startY === 0 && endX === 0 && endY === 0) return;

        ctx.beginPath();
        ctx.moveTo(startX, startY);

        // Control point for smooth bezier curve
        var midX = (startX + endX) / 2;
        var midY = (startY + endY) / 2;
        ctx.quadraticCurveTo(midX, midY, endX, endY);

        ctx.strokeStyle = rayColor;
        ctx.lineWidth = strokeWidth;
        ctx.lineCap = "round";
        ctx.stroke();
    }
}
