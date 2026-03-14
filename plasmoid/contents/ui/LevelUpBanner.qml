import QtQuick 2.15

Item {
    id: banner
    implicitWidth: bannerContent.implicitWidth + 16
    implicitHeight: 20
    opacity: 0
    scale: 0.7
    transformOrigin: Item.Center

    function show(newLevel) {
        levelLabel.text = "Lv." + newLevel
        banner.opacity = 0
        banner.scale = 0.7
        accentBg.opacity = 0.15
        showAnim.start()
    }

    Rectangle {
        id: accentBg
        anchors.fill: parent
        radius: 4
        color: root.accent
        opacity: 0

        SequentialAnimation on opacity {
            id: pulseAnim
            running: false; loops: 2
            NumberAnimation { to: 0.15; duration: 400 }
            NumberAnimation { to: 0.05; duration: 400 }
        }
    }

    Row {
        id: bannerContent
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: levelLabel
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.5
        }
    }

    SequentialAnimation {
        id: showAnim

        ParallelAnimation {
            NumberAnimation { target: banner; property: "scale"; from: 0.7; to: 1.0; duration: 400; easing.type: Easing.OutBack }
            NumberAnimation { target: banner; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        ScriptAction { script: pulseAnim.start() }

        PauseAnimation { duration: 2600 }

        NumberAnimation { target: banner; property: "opacity"; to: 0; duration: 800; easing.type: Easing.InQuad }
    }
}
