import QtQuick 2.15

Item {
    id: ring
    property int done: 0
    property int total: 1
    property real progress: total > 0 ? done / total : 0

    implicitWidth: 28
    implicitHeight: 28

    Behavior on progress { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2
            var r = Math.min(cx, cy) - 2
            var startAngle = -Math.PI / 2

            // Background track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.lineWidth = 2
            ctx.strokeStyle = Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.3)
            ctx.stroke()

            // Progress arc
            if (ring.progress > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, startAngle + 2 * Math.PI * ring.progress)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)
                ctx.stroke()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: ring.done + "/" + ring.total
        font.family: root.fontFamily
        font.pixelSize: 8
        color: root.textSecondary
        opacity: 0.6
    }

    onProgressChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Connections {
        target: root
        function onAccentChanged() { canvas.requestPaint() }
        function onBorderColorChanged() { canvas.requestPaint() }
    }
}
