import QtQuick 2.15

Item {
    id: popup
    width: 60; height: 20
    opacity: 0
    scale: 0.8
    transformOrigin: Item.Bottom

    function show(amount) {
        xpText.text = "+" + amount + " xp"
        popAnim.stop()
        popup.y = 0
        popup.opacity = 1
        popup.scale = 0.8
        popAnim.start()
    }

    Text {
        id: xpText
        anchors.centerIn: parent
        color: root.xpGold
        font.family: root.fontFamily
        font.pixelSize: 12
        font.letterSpacing: 1
        opacity: 0.8
    }

    ParallelAnimation {
        id: popAnim

        NumberAnimation {
            target: popup; property: "y"
            from: 0; to: -40
            duration: 1000; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popup; property: "scale"
            from: 0.8; to: 1.0
            duration: 300; easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: popup; property: "opacity"
            from: 1; to: 0
            duration: 1200; easing.type: Easing.InQuad
        }
    }
}
