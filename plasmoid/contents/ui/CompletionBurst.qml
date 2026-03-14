import QtQuick 2.15

Item {
    id: burst
    width: 40; height: 40
    visible: false

    function trigger() {
        ring.scale = 0.5
        ring.opacity = 0.6
        burst.visible = true
        burstAnim.start()
    }

    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: 40; height: 40; radius: 20
        color: "transparent"
        border.color: root.accent
        border.width: 1.5
        opacity: 0
        scale: 0.5
    }

    ParallelAnimation {
        id: burstAnim

        NumberAnimation {
            target: ring; property: "scale"
            from: 0.5; to: 2.0
            duration: 400; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: ring; property: "opacity"
            from: 0.6; to: 0
            duration: 400; easing.type: Easing.OutCubic
        }

        onFinished: burst.visible = false
    }
}
