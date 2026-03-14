import QtQuick 2.15
import org.kde.plasma.plasma5support as P5Support

Item {
    id: notifier
    property bool enabled: true

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName) { disconnectSource(sourceName) }
    }

    function send(title, body, urgency) {
        if (!enabled) return
        var urg = urgency || "normal"
        var cmd = 'notify-send -a "Aura Tasks" -i view-task -u ' + urg +
                  ' ' + escapeShell(title) + ' ' + escapeShell(body)
        executable.connectSource(cmd)
    }

    function escapeShell(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }
}
