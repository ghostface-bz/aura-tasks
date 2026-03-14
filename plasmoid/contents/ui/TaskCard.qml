import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import "js/Database.js" as DB

Item {
    id: card
    property var task
    property bool editing: false
    property string pomodoroState: "idle"
    property int pomodoroSession: 0
    property int secondsLeft: 25 * 60
    property bool pomodoroActive: pomodoroState !== "idle"

    signal completed(string taskId)
    signal deleted(string taskId)
    signal edited(string taskId, string newTitle, int newPriority)
    signal pomodoroTick(string taskId)
    signal pomodoroPhaseChanged(string taskId, string phase, int session)

    implicitHeight: editing ? editCol.height + 16 : 40
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Layout.fillWidth: true

    // Slide-in animation
    opacity: 0
    Component.onCompleted: { opacity = 1 }
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Rectangle {
        id: cardRect
        anchors.fill: parent
        color: hoverArea.containsMouse ? root.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        // ── Normal view ──────────────────────────────────────────────
        RowLayout {
            id: normalRow
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10
            visible: !card.editing

            // Priority dot
            Rectangle {
                width: 5; height: 5; radius: 2.5
                color: priorityColor(task.priority)
                opacity: DB.isDueOverdue(task.due_date) ? 1.0 : 0.8
            }

            // Check circle
            Rectangle {
                width: 18; height: 18; radius: 9
                color: "transparent"
                border.color: checkMouse.containsMouse ? root.accent : root.borderColor
                border.width: 1.5
                scale: checkMouse.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent; anchors.margins: 4; radius: 5
                    color: checkMouse.containsMouse ? root.accent : "transparent"
                    opacity: checkMouse.containsMouse ? 0.4 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                    id: checkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        completeAnim.start()
                        card.completed(task.id)
                    }
                }
            }

            // Title
            Text {
                Layout.fillWidth: true
                text: task.title
                color: root.textPrimary
                font.family: root.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            // Tags (inline, compact)
            Repeater {
                model: DB.parseTags(task.tags)
                delegate: Text {
                    text: modelData
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                    color: root.accent
                    opacity: 0.6
                }
            }

            // Due date
            Text {
                visible: task.due_date > 0
                text: DB.formatDueDate(task.due_date)
                font.family: root.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 0.5
                color: DB.isDueOverdue(task.due_date) ? root.danger : root.textSecondary
            }

            // XP (hover only)
            Text {
                text: "+" + task.xp_value
                font.family: root.fontFamily
                font.pixelSize: 10
                color: root.xpGold
                opacity: hoverArea.containsMouse ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Pomodoro timer (active)
            Text {
                visible: pomodoroActive
                text: {
                    var t = formatTime(secondsLeft)
                    var dots = ""
                    for (var i = 0; i < 4; i++) dots += (i < pomodoroSession) ? " \u25cf" : " \u25cb"
                    return t + dots
                }
                font.family: root.fontFamily; font.pixelSize: 9
                color: pomodoroState === "work" ? root.accent : root.success
                font.letterSpacing: 0.5
                ToolTip.text: pomodoroState === "work" ? "Working \u00b7 session " + (pomodoroSession + 1) + "/4 \u00b7 click to stop" : "Break \u00b7 click to stop"
                ToolTip.visible: pomTimerMouse.containsMouse; ToolTip.delay: 400
                MouseArea {
                    id: pomTimerMouse; anchors.fill: parent; anchors.margins: -4
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: stopPomodoro()
                }
            }

            // Pomodoro start (hover only, when idle)
            Text {
                visible: !pomodoroActive
                text: "\u25b6"; font.pixelSize: 9
                color: root.textSecondary
                opacity: hoverArea.containsMouse ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                ToolTip.text: "Start Pomodoro"
                ToolTip.visible: pomStartMouse.containsMouse; ToolTip.delay: 400
                MouseArea {
                    id: pomStartMouse; anchors.fill: parent; anchors.margins: -4
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: startPomodoro()
                }
            }

            // Edit button (hover only)
            Text {
                text: "\u270e"
                font.family: root.fontFamily
                font.pixelSize: 11
                color: root.textSecondary
                opacity: hoverArea.containsMouse ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: startEditing()
                }
            }

            // Delete button (hover only)
            Text {
                text: "\u00d7"
                font.family: root.fontFamily
                font.pixelSize: 14
                color: root.danger
                opacity: hoverArea.containsMouse ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.deleted(task.id)
                }
            }
        }

        // ── Edit view (inline expand) ────────────────────────────────
        ColumnLayout {
            id: editCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 12; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: card.editing

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Priority dot (clickable in edit mode)
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: priorityColor(editPriority)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var order = [1,2,3,4]
                            var idx = order.indexOf(editPriority)
                            editPriority = order[(idx + 1) % 4]
                        }
                    }
                }

                TextField {
                    id: editField
                    Layout.fillWidth: true
                    text: task.title
                    color: root.textPrimary
                    selectionColor: root.accent
                    selectedTextColor: root.textPrimary
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 4
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: editField.activeFocus ? root.accent : root.borderColor
                        }
                    }
                    Keys.onReturnPressed: saveEdit()
                    Keys.onEscapePressed: cancelEdit()
                }
            }

            // Hint text
            Text {
                text: "Enter to save \u00b7 Esc to cancel"
                font.family: root.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 0.5
                color: root.textSecondary
                opacity: 0.5
            }
        }

        // Bottom border
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: root.borderColor
            opacity: 0.5
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
        }
    }

    // ── Completion animation ─────────────────────────────────────────
    SequentialAnimation {
        id: completeAnim
        NumberAnimation { target: cardRect; property: "scale"; to: 1.02; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InCubic }
    }

    // ── Edit state ───────────────────────────────────────────────────
    property int editPriority: task ? task.priority : 2

    function startEditing() {
        editPriority = task.priority
        card.editing = true
        editField.text = task.title
        editField.forceActiveFocus()
        editField.selectAll()
    }

    function saveEdit() {
        var newTitle = editField.text.trim()
        if (newTitle.length > 0) {
            card.edited(task.id, newTitle, editPriority)
        }
        card.editing = false
    }

    function cancelEdit() {
        card.editing = false
    }

    // ── Pomodoro timer ───────────────────────────────────────────────
    Timer {
        id: pomTimer
        interval: 1000; repeat: true; running: pomodoroActive
        onTriggered: {
            if (secondsLeft > 0) {
                secondsLeft--
            } else {
                if (pomodoroState === "work") {
                    pomodoroSession++
                    pomodoroTick(task.id)
                    if (pomodoroSession >= 4) {
                        pomodoroState = "longBreak"
                        secondsLeft = 15 * 60
                        pomodoroPhaseChanged(task.id, "allDone", 4)
                        pomodoroSession = 0
                    } else {
                        pomodoroState = "shortBreak"
                        secondsLeft = 5 * 60
                        pomodoroPhaseChanged(task.id, "break", pomodoroSession)
                    }
                } else {
                    pomodoroState = "work"
                    secondsLeft = 25 * 60
                    pomodoroPhaseChanged(task.id, "work", pomodoroSession)
                }
            }
        }
    }

    function startPomodoro() {
        pomodoroState = "work"
        pomodoroSession = 0
        secondsLeft = 25 * 60
    }

    function stopPomodoro() {
        pomodoroState = "idle"
        pomodoroSession = 0
        secondsLeft = 25 * 60
    }

    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    function priorityColor(p) {
        switch (p) {
            case 1: return root.textSecondary
            case 3: return root.accent
            case 4: return root.danger
            default: return root.textPrimary
        }
    }

}
