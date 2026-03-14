import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.LocalStorage 2.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

import "js/Database.js" as DB

PlasmoidItem {
    id: root

    // ── Font ─────────────────────────────────────────────────────────
    FontLoader { id: dmSans; source: "fonts/DMSans.ttf" }
    readonly property string fontFamily: dmSans.status === FontLoader.Ready ? dmSans.name : "sans-serif"

    // ── Theme System ─────────────────────────────────────────────────
    property string themeName: Plasmoid.configuration.themeName ?? "sumi"

    readonly property var themes: ({
        "sumi":   { bg: "#0f0f0f", sf: "#1a1a1a", bd: "#262626", tp: "#e8e4df", ts: "#6b6560", ac: "#c8956c", ok: "#7a9e7e", gd: "#c8a96c", no: "#b85c5c", light: false },
        "kon":    { bg: "#0C0E18", sf: "#151827", bd: "#222842", tp: "#D8DDE8", ts: "#5B6178", ac: "#6B7FD7", ok: "#6A9E7A", gd: "#C9A84E", no: "#C45B5B", light: false },
        "matsu":  { bg: "#0B100D", sf: "#151D17", bd: "#243028", tp: "#DAE0D8", ts: "#6B7568", ac: "#6A9E72", ok: "#8AAE7E", gd: "#C4A85C", no: "#B85C5C", light: false },
        "sakura": { bg: "#12100F", sf: "#1E1A19", bd: "#302928", tp: "#E8DFD8", ts: "#7A6E68", ac: "#C48A8A", ok: "#7A9E7E", gd: "#C8A96C", no: "#B85050", light: false },
        "ishi":   { bg: "#111111", sf: "#1C1C1C", bd: "#2A2A2A", tp: "#E0E0E0", ts: "#6B6B6B", ac: "#8A8ABA", ok: "#7A9E7E", gd: "#C4B078", no: "#B85C5C", light: false },
        "washi":  { bg: "#F5F0E7", sf: "#EBE6DC", bd: "#D6D0C4", tp: "#2C2825", ts: "#8A8279", ac: "#B07D4F", ok: "#5C7A5E", gd: "#B89B5E", no: "#A84E4E", light: true }
    })

    readonly property var themeOrder: ["sumi", "kon", "matsu", "sakura", "ishi", "washi", "system"]
    readonly property var themeLabels: ({ "sumi": "Sumi \u58a8", "kon": "Kon \u7d3a", "matsu": "Matsu \u677e", "sakura": "Sakura \u685c", "ishi": "Ishi \u77f3", "washi": "Washi \u548c\u7d19", "system": "System" })

    readonly property bool isSystem: themeName === "system"
    readonly property var ct: themes[themeName] || themes["sumi"]

    // Helper: safely read Kirigami color
    function kc(prop, fb) { try { if (prop !== undefined) return prop } catch(e) {} return fb }

    Plasmoid.backgroundHints: isSystem ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground

    // ── Adaptive Color Tokens ────────────────────────────────────────
    readonly property color bgColor:       isSystem ? "transparent"                                        : ct.bg
    readonly property color surface:       isSystem ? Qt.rgba(kc(Kirigami.Theme.backgroundColor, "#1a1a1a").r, kc(Kirigami.Theme.backgroundColor, "#1a1a1a").g, kc(Kirigami.Theme.backgroundColor, "#1a1a1a").b, 0.4) : ct.sf
    readonly property color borderColor:   isSystem ? kc(Kirigami.Theme.separatorColor, "#262626")         : ct.bd
    readonly property color textPrimary:   isSystem ? kc(Kirigami.Theme.textColor, "#e8e4df")              : ct.tp
    readonly property color textSecondary: isSystem ? Qt.darker(kc(Kirigami.Theme.textColor, "#6b6560"), 1.5) : ct.ts
    readonly property color accent:        isSystem ? kc(Kirigami.Theme.highlightColor, "#c8956c")         : ct.ac
    readonly property color success:       isSystem ? kc(Kirigami.Theme.positiveTextColor, "#7a9e7e")      : ct.ok
    readonly property color xpGold:        isSystem ? kc(Kirigami.Theme.neutralTextColor, "#c8a96c")       : ct.gd
    readonly property color danger:        isSystem ? kc(Kirigami.Theme.negativeTextColor, "#b85c5c")      : ct.no

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Aura Tasks"
    toolTipSubText: taskCount + " active | Lv." + level

    // ── State ────────────────────────────────────────────────────────
    property int taskCount: 0
    property int completedToday: 0
    property int totalXp: 0
    property int level: 1
    property int streak: 0
    property int badgeCount: 0

    function xpFraction(lv, xp) {
        var t = [0,100,300,600,1000,1500,2100,2800,3600,4500,99999]
        var lo = t[Math.min(lv - 1, t.length - 2)]
        var hi = t[Math.min(lv, t.length - 1)]
        if (hi <= lo) return 1.0
        return Math.min(1.0, (xp - lo) / (hi - lo))
    }

    function cycleTheme() {
        var idx = themeOrder.indexOf(themeName)
        var next = themeOrder[(idx + 1) % themeOrder.length]
        Plasmoid.configuration.themeName = next
    }

    fullRepresentation: Item {
        id: fullRep
        implicitWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Kirigami.Units.gridUnit * 30

        // ── Models ───────────────────────────────────────────────────
        ListModel { id: taskListModel }
        ListModel { id: completedListModel }
        ListModel { id: badgesListModel }

        // ── Notifications ────────────────────────────────────────────
        Notify { id: notify; enabled: Plasmoid.configuration.notificationsEnabled ?? true }

        property bool focusMode: false

        // Focus pomodoro state
        property string focusPomState: "idle"
        property int focusPomSession: 0
        property int focusPomSeconds: 25 * 60

        Timer {
            id: focusPomTimer
            interval: 1000; repeat: true
            running: fullRep.focusPomState !== "idle"
            onTriggered: {
                if (fullRep.focusPomSeconds > 0) {
                    fullRep.focusPomSeconds--
                } else {
                    if (fullRep.focusPomState === "work") {
                        fullRep.focusPomSession++
                        if (taskListModel.count > 0)
                            DB.incrementPomodoro(taskListModel.get(0).id)
                        if (fullRep.focusPomSession >= 4) {
                            fullRep.focusPomState = "longBreak"
                            fullRep.focusPomSeconds = 15 * 60
                            notify.send("Pomodoro complete!", "All 4 sessions done. Take a long break.", "normal")
                            fullRep.focusPomSession = 0
                        } else {
                            fullRep.focusPomState = "shortBreak"
                            fullRep.focusPomSeconds = 5 * 60
                            notify.send("Time for a break", "Session " + fullRep.focusPomSession + "/4 complete. Take 5.", "normal")
                        }
                    } else {
                        fullRep.focusPomState = "work"
                        fullRep.focusPomSeconds = 25 * 60
                        notify.send("Back to focus", "Break's over. Ready for session " + (fullRep.focusPomSession + 1) + "?", "normal")
                    }
                }
            }
        }

        function refresh() {
            var tasks = DB.listActive()
            taskListModel.clear()
            for (var i = 0; i < tasks.length; i++)
                taskListModel.append(tasks[i])
            root.taskCount = tasks.length

            var done = DB.listCompletedToday()
            root.completedToday = done.length
            completedListModel.clear()
            for (var j = 0; j < done.length; j++)
                completedListModel.append(done[j])

            var stats = DB.getStats()
            root.totalXp = stats.totalXp
            root.level = stats.level
            root.streak = stats.streak
            root.badgeCount = DB.listBadges().length
            refreshBadges()
        }

        function refreshBadges() {
            var badges = DB.listBadges()
            badgesListModel.clear()
            for (var i = 0; i < badges.length; i++)
                badgesListModel.append({ badgeId: badges[i].id, icon: DB.badgeIcon(badges[i].id), label: DB.badgeLabel(badges[i].id) })
        }

        function handlePostComplete(prevLevel) {
            if (root.level > prevLevel) {
                levelUpBanner.show(root.level)
                notify.send("Level Up!", "You reached Lv." + root.level + " \u2014 " + DB.levelName(root.level), "low")
            }
            // Check for newly earned badges
            var allBadges = DB.listBadges()
            if (allBadges.length > root.badgeCount) {
                var newest = allBadges[allBadges.length - 1]
                notify.send("Badge Unlocked", DB.badgeIcon(newest.id) + " " + DB.badgeLabel(newest.id), "low")
            }
        }

        function addCurrentTask() {
            var txt = taskInput.text.trim()
            if (txt.length === 0) return
            DB.addTaskParsed(txt)
            refresh()
            taskInput.text = ""
        }

        Component.onCompleted: {
            DB.initDb(LocalStorage.openDatabaseSync("AuraTasks", "1.0", "Aura Tasks", 1000000))
            fullRep.refresh()
        }

        // ── Background ──────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: root.bgColor
            visible: !root.isSystem
        }

        // ── Main column ─────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 0

            // ── Header ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 12

                // Streak
                Text {
                    text: root.streak + "d"
                    font.family: root.fontFamily
                    font.pixelSize: 11; font.letterSpacing: 1.5
                    font.weight: Font.Medium
                    color: root.textSecondary; opacity: 0.7
                    ToolTip.text: root.streak + " day streak"
                    ToolTip.visible: streakMouse.containsMouse; ToolTip.delay: 400
                    MouseArea { id: streakMouse; anchors.fill: parent; hoverEnabled: true }
                }

                // Level
                Text {
                    text: "Lv." + root.level
                    font.family: root.fontFamily
                    font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 0.5
                    color: root.accent
                    ToolTip.text: DB.levelName(root.level) + " \u00b7 " + root.totalXp + " XP"
                    ToolTip.visible: lvlMouse.containsMouse; ToolTip.delay: 400
                    MouseArea { id: lvlMouse; anchors.fill: parent; hoverEnabled: true }
                }

                // XP bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 3; radius: 1.5; color: root.borderColor
                    Rectangle {
                        width: parent.width * root.xpFraction(root.level, root.totalXp)
                        height: parent.height; radius: 1.5; color: root.accent
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }

                // Daily count
                DailyRing {
                    done: root.completedToday
                    total: Math.max(1, root.taskCount + root.completedToday)
                }

                // Badges
                Text {
                    visible: root.badgeCount > 0
                    text: root.badgeCount + "\u2605"
                    font.family: root.fontFamily; font.pixelSize: 10; font.letterSpacing: 0.5
                    color: root.xpGold; opacity: 0.6
                    ToolTip.text: root.badgeCount + " badges earned"
                    ToolTip.visible: badgeMouse.containsMouse; ToolTip.delay: 400
                    MouseArea { id: badgeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: badgesPopup.visible = true }
                }

                LevelUpBanner { id: levelUpBanner }

                // Theme selector (click to cycle)
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.accent
                    opacity: themeToggleMouse.containsMouse ? 1.0 : 0.5
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: themeToggleMouse
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleTheme()
                    }

                    ToolTip.text: root.themeLabels[root.themeName] || root.themeName
                    ToolTip.visible: themeToggleMouse.containsMouse; ToolTip.delay: 300
                }

                // Focus Shield toggle
                Text {
                    text: "\u96c6"
                    font.family: root.fontFamily; font.pixelSize: 11
                    color: fullRep.focusMode ? root.accent : root.textSecondary
                    opacity: focusToggleMouse.containsMouse ? 1.0 : (fullRep.focusMode ? 0.9 : 0.4)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    MouseArea {
                        id: focusToggleMouse; anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: fullRep.focusMode = !fullRep.focusMode
                    }
                    ToolTip.text: fullRep.focusMode ? "Exit Focus" : "Focus Shield"
                    ToolTip.visible: focusToggleMouse.containsMouse; ToolTip.delay: 300
                }
            }

            // ── Divider ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10
                height: 1; color: root.borderColor
                opacity: fullRep.focusMode ? 0 : 0.4
                scale: fullRep.focusMode ? 0.96 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            // ── Input row ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                opacity: fullRep.focusMode ? 0 : 1
                scale: fullRep.focusMode ? 0.96 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                TextField {
                    id: taskInput
                    Layout.fillWidth: true; height: 36
                    placeholderText: "Add task...  #tag !high tomorrow"
                    placeholderTextColor: Qt.rgba(root.textSecondary.r, root.textSecondary.g, root.textSecondary.b, 0.5)
                    color: root.textPrimary; selectionColor: root.accent; selectedTextColor: root.textPrimary
                    font.family: root.fontFamily; font.pixelSize: 13
                    leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 6
                    background: Rectangle {
                        color: taskInput.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.04) : "transparent"
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: taskInput.activeFocus ? 1.5 : 1
                            color: taskInput.activeFocus ? root.accent : root.borderColor
                            opacity: taskInput.activeFocus ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on height { NumberAnimation { duration: 200 } }
                        }
                    }
                    Keys.onReturnPressed: fullRep.addCurrentTask()
                }

                Rectangle {
                    width: 28; height: 28; radius: 2
                    color: addBtnMouse.containsMouse ? root.accent : "transparent"
                    border.color: root.accent; border.width: 1
                    opacity: addBtnMouse.containsMouse ? 1.0 : 0.6
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent; text: "+"
                        color: addBtnMouse.containsMouse ? (root.isSystem ? root.bgColor : root.ct.bg) : root.accent
                        font.family: root.fontFamily; font.pixelSize: 16; font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: addBtnMouse; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: fullRep.addCurrentTask()
                    }
                }
            }

            // ── Tab bar ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 14; Layout.bottomMargin: 6
                spacing: 24
                opacity: fullRep.focusMode ? 0 : 1
                scale: fullRep.focusMode ? 0.96 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Repeater {
                    model: [
                        { label: "Active", cnt: root.taskCount },
                        { label: "Done",   cnt: root.completedToday }
                    ]
                    delegate: Item {
                        Layout.preferredHeight: 24
                        implicitWidth: tabLabel.implicitWidth
                        Text {
                            id: tabLabel
                            text: modelData.label + (modelData.cnt > 0 ? "  " + modelData.cnt : "")
                            font.family: root.fontFamily; font.pixelSize: 10
                            font.letterSpacing: 2; font.capitalization: Font.AllUppercase
                            font.weight: Font.Medium
                            color: viewStack.currentIndex === index ? root.textPrimary : root.textSecondary
                            opacity: viewStack.currentIndex === index ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: 2; radius: 1
                            color: root.accent
                            opacity: viewStack.currentIndex === index ? 1.0 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: viewStack.currentIndex = index
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true; height: 1; color: root.borderColor
                opacity: fullRep.focusMode ? 0 : 0.3
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            // ── Focus Shield view ──────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 0
                opacity: fullRep.focusMode ? 1 : 0
                scale: fullRep.focusMode ? 1.0 : 0.96
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                Item { Layout.fillHeight: true }

                Column {
                    Layout.fillWidth: true
                    spacing: 20
                    visible: taskListModel.count > 0

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 6; height: 6; radius: 3
                        color: {
                            if (taskListModel.count === 0) return root.borderColor
                            var p = taskListModel.get(0).priority
                            if (p === 1) return root.textSecondary
                            if (p === 3) return root.accent
                            if (p === 4) return root.danger
                            return root.textPrimary
                        }
                    }

                    // Zen title
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: taskListModel.count > 0 ? taskListModel.get(0).title : ""
                        font.family: root.fontFamily; font.pixelSize: 24
                        font.weight: Font.Light; font.letterSpacing: 1.0
                        lineHeight: 1.4; lineHeightMode: Text.ProportionalHeight
                        color: root.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - 40
                        wrapMode: Text.WordWrap
                    }

                    // Tags row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        visible: taskListModel.count > 0 && DB.parseTags(taskListModel.get(0).tags).length > 0

                        Repeater {
                            model: taskListModel.count > 0 ? DB.parseTags(taskListModel.get(0).tags) : []
                            delegate: Text {
                                text: modelData
                                font.family: root.fontFamily; font.pixelSize: 10
                                font.letterSpacing: 0.5
                                color: root.accent; opacity: 0.6
                            }
                        }
                    }

                    // Due date
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: taskListModel.count > 0 && taskListModel.get(0).due_date > 0
                        text: taskListModel.count > 0 ? DB.formatDueDate(taskListModel.get(0).due_date) : ""
                        font.family: root.fontFamily; font.pixelSize: 10
                        font.letterSpacing: 0.5
                        color: (taskListModel.count > 0 && DB.isDueOverdue(taskListModel.get(0).due_date)) ? root.danger : root.textSecondary
                        opacity: 0.6
                    }

                    // Check circle with breathing pulse
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40; height: 40

                        Rectangle {
                            id: focusCheckCircle
                            anchors.fill: parent; radius: 20
                            color: "transparent"
                            border.color: focusCompleteMouse.containsMouse ? root.accent : root.borderColor
                            border.width: 1.5
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            property real pulseOpacity: 1.0
                            opacity: focusCompleteMouse.containsMouse ? 1.0 : pulseOpacity

                            SequentialAnimation on pulseOpacity {
                                loops: Animation.Infinite
                                running: fullRep.focusMode && !focusCompleteMouse.containsMouse
                                NumberAnimation { to: 0.4; duration: 2000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"; font.pixelSize: 16
                                color: focusCompleteMouse.containsMouse ? root.accent : root.textSecondary
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        CompletionBurst {
                            id: focusBurst
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: focusCompleteMouse; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (taskListModel.count > 0) {
                                    var taskId = taskListModel.get(0).id
                                    var prevLevel = root.level
                                    var gained = DB.completeTask(taskId)
                                    focusBurst.trigger()
                                    fullRep.refresh()
                                    if (gained > 0) xpPopup.show(gained)
                                    fullRep.handlePostComplete(prevLevel)
                                }
                            }
                        }
                    }

                    // Focus pomodoro timer
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                if (focusPomState === "idle") return "\u25b6"
                                var m = Math.floor(focusPomSeconds / 60)
                                var s = focusPomSeconds % 60
                                var t = m + ":" + (s < 10 ? "0" + s : s)
                                var dots = ""
                                for (var i = 0; i < 4; i++) dots += (i < focusPomSession) ? " \u25cf" : " \u25cb"
                                return t + dots
                            }
                            font.family: root.fontFamily; font.pixelSize: focusPomState === "idle" ? 10 : 13
                            font.letterSpacing: 1
                            color: focusPomState === "work" ? root.accent : (focusPomState === "idle" ? root.textSecondary : root.success)
                            opacity: focusPomState === "idle" ? (focusPomMouse.containsMouse ? 0.7 : 0.3) : 0.8
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            MouseArea {
                                id: focusPomMouse; anchors.fill: parent; anchors.margins: -8
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (focusPomState === "idle") {
                                        focusPomState = "work"
                                        focusPomSession = 0
                                        focusPomSeconds = 25 * 60
                                    } else {
                                        focusPomState = "idle"
                                        focusPomSession = 0
                                        focusPomSeconds = 25 * 60
                                    }
                                }
                            }
                            ToolTip.text: focusPomState === "idle" ? "Start Pomodoro" : (focusPomState === "work" ? "Working \u00b7 session " + (focusPomSession + 1) + "/4 \u00b7 click to stop" : "Break \u00b7 click to stop")
                            ToolTip.visible: focusPomMouse.containsMouse; ToolTip.delay: 400
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: focusPomState !== "idle"
                            text: focusPomState === "work" ? "focus" : "break"
                            font.family: root.fontFamily; font.pixelSize: 9
                            font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase
                            color: root.textSecondary; opacity: 0.3
                        }
                    }

                    // Skip/next button
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u203a"
                        visible: taskListModel.count > 1
                        font.family: root.fontFamily; font.pixelSize: 18
                        color: root.textSecondary
                        opacity: skipMouse.containsMouse ? 0.8 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        MouseArea {
                            id: skipMouse; anchors.fill: parent; anchors.margins: -8
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (taskListModel.count > 1)
                                    taskListModel.move(0, taskListModel.count - 1, 1)
                            }
                        }
                        ToolTip.text: "Skip to next"
                        ToolTip.visible: skipMouse.containsMouse; ToolTip.delay: 400
                    }
                }

                // Empty state with 円 watermark
                Column {
                    visible: taskListModel.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u5186"
                        font.pixelSize: 64
                        color: root.textSecondary; opacity: 0.12
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "All clear"
                        font.family: root.fontFamily; font.pixelSize: 16
                        font.letterSpacing: 1; font.weight: Font.Light
                        color: root.textSecondary; opacity: 0.5
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.completedToday + " completed today"
                        font.family: root.fontFamily; font.pixelSize: 10
                        font.letterSpacing: 0.5
                        color: root.textSecondary; opacity: 0.3
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ── Task views ──────────────────────────────────────────
            StackLayout {
                id: viewStack
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.topMargin: 4
                opacity: fullRep.focusMode ? 0 : 1
                scale: fullRep.focusMode ? 0.96 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                currentIndex: 0

                // Active tasks
                Flickable {
                    clip: true; contentWidth: width; contentHeight: activeCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: activeCol; width: parent.width; spacing: 0

                        Repeater {
                            id: tasksRepeater; model: taskListModel
                            delegate: Item {
                                Layout.fillWidth: true
                                implicitHeight: taskCard.implicitHeight

                                TaskCard {
                                    id: taskCard
                                    anchors.left: parent.left; anchors.right: parent.right
                                    task: model
                                    onCompleted: function(taskId) {
                                        cardBurst.trigger()
                                        var prevLevel = root.level
                                        var gained = DB.completeTask(taskId)
                                        fullRep.refresh()
                                        if (gained > 0) xpPopup.show(gained)
                                        fullRep.handlePostComplete(prevLevel)
                                    }
                                    onDeleted: function(taskId) { DB.deleteTask(taskId); fullRep.refresh() }
                                    onEdited: function(taskId, newTitle, newPriority) { DB.updateTask(taskId, newTitle, newPriority); fullRep.refresh() }
                                    onPomodoroTick: function(taskId) { DB.incrementPomodoro(taskId) }
                                    onPomodoroPhaseChanged: function(taskId, phase, session) {
                                        if (phase === "break")
                                            notify.send("Time for a break", "Session " + session + "/4 complete. Take 5.", "normal")
                                        else if (phase === "allDone")
                                            notify.send("Pomodoro complete!", "All 4 sessions done. Take a long break.", "normal")
                                        else if (phase === "work")
                                            notify.send("Back to focus", "Break's over. Ready for session " + (session + 1) + "?", "normal")
                                    }
                                }

                                CompletionBurst {
                                    id: cardBurst
                                    anchors.left: parent.left; anchors.leftMargin: 42
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Empty state
                        Item {
                            visible: tasksRepeater.count === 0
                            Layout.fillWidth: true; implicitHeight: 160
                            Column {
                                anchors.centerIn: parent; spacing: 12
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "\u25ef"; font.pixelSize: 32
                                    color: root.textSecondary; opacity: 0.15
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No tasks yet"
                                    font.family: root.fontFamily; font.pixelSize: 13
                                    font.letterSpacing: 0.5; font.weight: Font.Light
                                    color: root.textSecondary; opacity: 0.6
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "press enter to add one"
                                    font.family: root.fontFamily; font.pixelSize: 10
                                    font.letterSpacing: 1; font.weight: Font.Light
                                    color: root.textSecondary; opacity: 0.3
                                }
                            }
                        }
                    }
                }

                // Completed today
                Flickable {
                    clip: true; contentWidth: width; contentHeight: doneCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: doneCol; width: parent.width; spacing: 0

                        Repeater {
                            id: completedRepeater; model: completedListModel
                            delegate: Rectangle {
                                Layout.fillWidth: true; implicitHeight: 40
                                color: doneHover.containsMouse ? root.surface : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10

                                    Text {
                                        text: doneHover.containsMouse ? "\u21a9" : "\u2713"
                                        font.pixelSize: 12
                                        color: doneHover.containsMouse ? root.accent : root.success
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { DB.uncompleteTask(model.id); fullRep.refresh() }
                                        }
                                        ToolTip.text: "Undo"
                                        ToolTip.visible: doneHover.containsMouse; ToolTip.delay: 400
                                    }
                                    Text {
                                        Layout.fillWidth: true; text: model.title
                                        font.family: root.fontFamily; font.pixelSize: 13; font.strikeout: true
                                        color: root.textSecondary; elide: Text.ElideRight; opacity: 0.7
                                    }
                                    Text {
                                        text: "+" + model.xp_value
                                        font.family: root.fontFamily; font.pixelSize: 10
                                        color: root.xpGold; opacity: 0.4
                                    }
                                }

                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.borderColor; opacity: 0.3 }
                                MouseArea { id: doneHover; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true; acceptedButtons: Qt.NoButton }
                            }
                        }

                        Item {
                            visible: completedRepeater.count === 0
                            Layout.fillWidth: true; implicitHeight: 160
                            Column {
                                anchors.centerIn: parent; spacing: 12
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\u25ef"; font.pixelSize: 32; color: root.textSecondary; opacity: 0.15 }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing completed today"
                                    font.family: root.fontFamily; font.pixelSize: 13; font.letterSpacing: 0.5; font.weight: Font.Light
                                    color: root.textSecondary; opacity: 0.6
                                }
                            }
                        }
                    }
                }
            }
        }

        // Badges popup overlay
        Rectangle {
            id: badgesPopup
            anchors.fill: parent
            visible: false; z: 100
            color: root.isSystem ? Qt.rgba(0, 0, 0, 0.9) : Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.95)

            MouseArea { anchors.fill: parent; onClicked: badgesPopup.visible = false }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 64
                spacing: 24

                Text {
                    text: "BADGES"
                    Layout.alignment: Qt.AlignHCenter
                    font.family: root.fontFamily; font.pixelSize: 11
                    font.letterSpacing: 4; font.capitalization: Font.AllUppercase
                    color: root.accent
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 3; columnSpacing: 24; rowSpacing: 20

                    Repeater {
                        model: badgesListModel
                        delegate: Column {
                            spacing: 6; width: 56
                            Layout.alignment: Qt.AlignHCenter

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.icon; font.pixelSize: 28
                                color: root.xpGold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.label
                                font.family: root.fontFamily; font.pixelSize: 9
                                font.letterSpacing: 0.5
                                color: root.textSecondary
                            }
                        }
                    }
                }

                Text {
                    visible: badgesListModel.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: "No badges earned yet"
                    font.family: root.fontFamily; font.pixelSize: 12
                    font.letterSpacing: 0.5
                    color: root.textSecondary; opacity: 0.4
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "tap to close"
                    font.family: root.fontFamily; font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.textSecondary; opacity: 0.3
                }
            }
        }

        // Overlays
        XpPopup { id: xpPopup; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16 }
    }
}
