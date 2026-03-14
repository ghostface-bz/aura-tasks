// Database.js — SQLite backend for Aura Tasks
// The db object is passed in from QML (LocalStorage.openDatabaseSync)

var _db = null

function initDb(db) {
    _db = db
    migrate(_db)
}

function migrate(db) {
    db.transaction(function(tx) {
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS tasks (" +
            "  id           TEXT PRIMARY KEY," +
            "  title        TEXT NOT NULL," +
            "  description  TEXT NOT NULL DEFAULT ''," +
            "  priority     INTEGER NOT NULL DEFAULT 2," +
            "  tags         TEXT NOT NULL DEFAULT '[]'," +
            "  due_date     INTEGER," +
            "  completed    INTEGER NOT NULL DEFAULT 0," +
            "  created_at   INTEGER NOT NULL," +
            "  completed_at INTEGER," +
            "  estimated_min INTEGER," +
            "  recurrence   TEXT," +
            "  pomodoros    INTEGER NOT NULL DEFAULT 0," +
            "  xp_value     INTEGER NOT NULL DEFAULT 25" +
            ")"
        )
        tx.executeSql("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)")
        tx.executeSql("CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_date)")
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS user_stats (" +
            "  id           INTEGER PRIMARY KEY DEFAULT 1," +
            "  total_xp     INTEGER NOT NULL DEFAULT 0," +
            "  level        INTEGER NOT NULL DEFAULT 1," +
            "  streak_days  INTEGER NOT NULL DEFAULT 0," +
            "  last_active  INTEGER," +
            "  tasks_done   INTEGER NOT NULL DEFAULT 0" +
            ")"
        )
        tx.executeSql("INSERT OR IGNORE INTO user_stats (id) VALUES (1)")
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS badges (" +
            "  id        TEXT PRIMARY KEY," +
            "  earned_at INTEGER NOT NULL" +
            ")"
        )
    })
}

function uuid4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16)
    })
}

function xpForPriority(p) {
    if (p === 1) return 10
    if (p === 3) return 50
    if (p === 4) return 100
    return 25
}

// ── Natural Language Input Parser ────────────────────────────────────
function parseTaskInput(text) {
    var result = { title: text, priority: 2, tags: [], due_date: 0, recurrence: null }

    // Extract tags: #work #personal etc
    var tagRe = /#(\w+)/g
    var match
    while ((match = tagRe.exec(text)) !== null)
        result.tags.push(match[1])
    result.title = result.title.replace(/#\w+/g, "").trim()

    // Extract priority: !low !high !urgent
    if (/!urgent/i.test(result.title)) { result.priority = 4; result.title = result.title.replace(/!urgent/gi, "").trim() }
    else if (/!high/i.test(result.title)) { result.priority = 3; result.title = result.title.replace(/!high/gi, "").trim() }
    else if (/!low/i.test(result.title)) { result.priority = 1; result.title = result.title.replace(/!low/gi, "").trim() }

    // Extract due date: "tomorrow", "next week", or date patterns
    var now = new Date()
    if (/\btomorrow\b/i.test(result.title)) {
        var tom = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
        result.due_date = Math.floor(tom.getTime() / 1000)
        result.title = result.title.replace(/\btomorrow\b/gi, "").trim()
    } else if (/\bnext week\b/i.test(result.title)) {
        var nw = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7)
        result.due_date = Math.floor(nw.getTime() / 1000)
        result.title = result.title.replace(/\bnext week\b/gi, "").trim()
    } else if (/\btoday\b/i.test(result.title)) {
        var td = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59)
        result.due_date = Math.floor(td.getTime() / 1000)
        result.title = result.title.replace(/\btoday\b/gi, "").trim()
    }

    // Extract recurrence: "daily", "every day", "weekly", "every week"
    if (/\b(every\s*day|daily)\b/i.test(result.title)) {
        result.recurrence = "daily"
        result.title = result.title.replace(/\b(every\s*day|daily)\b/gi, "").trim()
    } else if (/\b(every\s*week|weekly)\b/i.test(result.title)) {
        result.recurrence = "weekly"
        result.title = result.title.replace(/\b(every\s*week|weekly)\b/gi, "").trim()
    }

    // Clean up extra spaces
    result.title = result.title.replace(/\s+/g, " ").trim()
    return result
}

function addTask(title, priority) {
    if (!_db) return ""
    var id = uuid4()
    var xp = xpForPriority(priority)
    var now = Math.floor(Date.now() / 1000)
    _db.transaction(function(tx) {
        tx.executeSql(
            "INSERT INTO tasks (id, title, priority, completed, created_at, xp_value) VALUES (?, ?, ?, 0, ?, ?)",
            [id, title, priority, now, xp]
        )
    })
    return id
}

function addTaskParsed(text) {
    if (!_db) return ""
    var parsed = parseTaskInput(text)
    if (parsed.title.length === 0) return ""
    var id = uuid4()
    var xp = xpForPriority(parsed.priority)
    var now = Math.floor(Date.now() / 1000)
    _db.transaction(function(tx) {
        tx.executeSql(
            "INSERT INTO tasks (id, title, priority, tags, due_date, recurrence, completed, created_at, xp_value) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)",
            [id, parsed.title, parsed.priority, JSON.stringify(parsed.tags), parsed.due_date || null, parsed.recurrence, now, xp]
        )
    })
    return id
}

function updateTask(id, title, priority) {
    if (!_db) return
    var xp = xpForPriority(priority)
    _db.transaction(function(tx) {
        tx.executeSql("UPDATE tasks SET title = ?, priority = ?, xp_value = ? WHERE id = ?",
            [title, priority, xp, id])
    })
}

function completeTask(id) {
    if (!_db) return 0
    var xp = 0
    _db.transaction(function(tx) {
        var now = Math.floor(Date.now() / 1000)
        tx.executeSql("UPDATE tasks SET completed = 1, completed_at = ? WHERE id = ?", [now, id])
        var rs = tx.executeSql("SELECT xp_value FROM tasks WHERE id = ?", [id])
        if (rs.rows.length > 0) xp = rs.rows.item(0).xp_value
        tx.executeSql("UPDATE user_stats SET total_xp = total_xp + ?, tasks_done = tasks_done + 1 WHERE id = 1", [xp])
        var statsRs = tx.executeSql("SELECT total_xp FROM user_stats WHERE id = 1")
        tx.executeSql("UPDATE user_stats SET level = ? WHERE id = 1", [xpToLevel(statsRs.rows.item(0).total_xp)])
        updateStreak(tx, now)
        spawnRecurring(tx, id)
    })
    checkAndAwardBadges()
    return xp
}

function uncompleteTask(id) {
    if (!_db) return
    _db.transaction(function(tx) {
        var rs = tx.executeSql("SELECT xp_value FROM tasks WHERE id = ?", [id])
        var xp = (rs.rows.length > 0) ? rs.rows.item(0).xp_value : 0
        tx.executeSql("UPDATE tasks SET completed = 0, completed_at = NULL WHERE id = ?", [id])
        tx.executeSql(
            "UPDATE user_stats SET total_xp = MAX(0, total_xp - ?), tasks_done = MAX(0, tasks_done - 1) WHERE id = 1",
            [xp]
        )
        var statsRs = tx.executeSql("SELECT total_xp FROM user_stats WHERE id = 1")
        tx.executeSql("UPDATE user_stats SET level = ? WHERE id = 1", [xpToLevel(statsRs.rows.item(0).total_xp)])
    })
}

function spawnRecurring(tx, id) {
    var rs = tx.executeSql("SELECT title, priority, tags, recurrence, xp_value FROM tasks WHERE id = ?", [id])
    if (rs.rows.length === 0) return
    var r = rs.rows.item(0)
    if (!r.recurrence) return
    var newId = uuid4()
    var now = Math.floor(Date.now() / 1000)
    var due = null
    if (r.recurrence === "daily") due = now + 86400
    else if (r.recurrence === "weekly") due = now + 7 * 86400
    tx.executeSql(
        "INSERT INTO tasks (id, title, priority, tags, due_date, recurrence, completed, created_at, xp_value) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)",
        [newId, r.title, r.priority, r.tags || "[]", due, r.recurrence, now, r.xp_value]
    )
}

function deleteTask(id) {
    if (!_db) return
    _db.transaction(function(tx) {
        tx.executeSql("DELETE FROM tasks WHERE id = ?", [id])
    })
}

function listActive() {
    if (!_db) return []
    var tasks = []
    _db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, title, description, priority, tags, due_date, completed, " +
            "created_at, completed_at, estimated_min, recurrence, pomodoros, xp_value " +
            "FROM tasks WHERE completed = 0 ORDER BY priority DESC, created_at ASC"
        )
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            tasks.push({
                id: r.id, title: r.title, description: r.description || "",
                priority: r.priority, tags: r.tags || "[]",
                due_date: r.due_date || 0, completed: false,
                created_at: r.created_at, completed_at: r.completed_at || 0,
                estimated_min: r.estimated_min || 0, recurrence: r.recurrence || "",
                pomodoros: r.pomodoros || 0, xp_value: r.xp_value
            })
        }
    })
    return tasks
}

function listCompletedToday() {
    if (!_db) return []
    var tasks = []
    var ts = todayStartTimestamp()
    _db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, title, description, priority, tags, due_date, completed, " +
            "created_at, completed_at, estimated_min, recurrence, pomodoros, xp_value " +
            "FROM tasks WHERE completed = 1 AND completed_at >= ? ORDER BY completed_at DESC", [ts]
        )
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            tasks.push({
                id: r.id, title: r.title, description: r.description || "",
                priority: r.priority, tags: r.tags || "[]",
                due_date: r.due_date || 0, completed: true,
                created_at: r.created_at, completed_at: r.completed_at || 0,
                estimated_min: r.estimated_min || 0, recurrence: r.recurrence || "",
                pomodoros: r.pomodoros || 0, xp_value: r.xp_value
            })
        }
    })
    return tasks
}

function incrementPomodoro(id) {
    if (!_db) return
    _db.transaction(function(tx) {
        tx.executeSql("UPDATE tasks SET pomodoros = pomodoros + 1 WHERE id = ?", [id])
    })
}

function getStats() {
    var stats = { totalXp: 0, level: 1, streak: 0, tasksDone: 0 }
    if (!_db) return stats
    _db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT total_xp, level, streak_days, tasks_done FROM user_stats WHERE id = 1")
        if (rs.rows.length > 0) {
            var r = rs.rows.item(0)
            stats.totalXp = r.total_xp; stats.level = r.level
            stats.streak = r.streak_days; stats.tasksDone = r.tasks_done
        }
    })
    return stats
}

// ── Badges ───────────────────────────────────────────────────────────

var BADGE_DEFS = [
    { id: "first_task",  check: function(s) { return s.tasksDone >= 1 } },
    { id: "ten_tasks",   check: function(s) { return s.tasksDone >= 10 } },
    { id: "centurion",   check: function(s) { return s.tasksDone >= 100 } },
    { id: "streak_3",    check: function(s) { return s.streak >= 3 } },
    { id: "streak_7",    check: function(s) { return s.streak >= 7 } },
    { id: "streak_30",   check: function(s) { return s.streak >= 30 } },
    { id: "night_owl",   check: function(s) { return s.tasksDone >= 1 && (new Date()).getHours() >= 22 } },
    { id: "early_bird",  check: function(s) { return s.tasksDone >= 1 && (new Date()).getHours() < 7 } }
]

function checkAndAwardBadges() {
    if (!_db) return []
    var newBadges = []
    var stats = getStats()
    _db.transaction(function(tx) {
        for (var i = 0; i < BADGE_DEFS.length; i++) {
            var b = BADGE_DEFS[i]
            if (b.check(stats)) {
                var existing = tx.executeSql("SELECT id FROM badges WHERE id = ?", [b.id])
                if (existing.rows.length === 0) {
                    tx.executeSql("INSERT INTO badges (id, earned_at) VALUES (?, ?)",
                        [b.id, Math.floor(Date.now() / 1000)])
                    newBadges.push(b.id)
                }
            }
        }
    })
    return newBadges
}

function listBadges() {
    if (!_db) return []
    var badges = []
    _db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, earned_at FROM badges ORDER BY earned_at ASC")
        for (var i = 0; i < rs.rows.length; i++)
            badges.push({ id: rs.rows.item(i).id, earned_at: rs.rows.item(i).earned_at })
    })
    return badges
}

function badgeLabel(id) {
    var labels = {
        "first_task": "First Task",
        "ten_tasks": "10 Tasks",
        "centurion": "100 Tasks",
        "streak_3": "3-Day Streak",
        "streak_7": "7-Day Streak",
        "streak_30": "30-Day Streak",
        "night_owl": "Night Owl",
        "early_bird": "Early Bird"
    }
    return labels[id] || id
}

function badgeIcon(id) {
    var icons = {
        "first_task": "\u4e00",
        "ten_tasks": "\u5341",
        "centurion": "\u767e",
        "streak_3": "\u706b",
        "streak_7": "\u708e",
        "streak_30": "\u9f8d",
        "night_owl": "\u6708",
        "early_bird": "\u671d"
    }
    return icons[id] || "\u25cf"
}

// ── XP / Levels ──────────────────────────────────────────────────────

var THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500]

function xpToLevel(xp) {
    for (var i = THRESHOLDS.length - 1; i >= 0; i--)
        if (xp >= THRESHOLDS[i]) return i + 1
    return 1
}

function levelName(level) {
    var n = ["", "Novice", "Apprentice", "Adept", "Expert", "Master",
             "Grandmaster", "Astral", "Nebula", "Cosmic", "Singularity"]
    return (level >= 1 && level < n.length) ? n[level] : "Singularity"
}

function updateStreak(tx, now) {
    var rs = tx.executeSql("SELECT last_active FROM user_stats WHERE id = 1")
    var lastActive = (rs.rows.length > 0) ? rs.rows.item(0).last_active : null
    var todayStart = todayStartTimestamp()
    var yesterdayStart = todayStart - 86400
    if (lastActive === null || lastActive === undefined)
        tx.executeSql("UPDATE user_stats SET streak_days = 1, last_active = ? WHERE id = 1", [now])
    else if (lastActive >= todayStart) { /* already counted */ }
    else if (lastActive >= yesterdayStart)
        tx.executeSql("UPDATE user_stats SET streak_days = streak_days + 1, last_active = ? WHERE id = 1", [now])
    else
        tx.executeSql("UPDATE user_stats SET streak_days = 1, last_active = ? WHERE id = 1", [now])
}

function todayStartTimestamp() {
    var now = new Date()
    return Math.floor(new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000)
}

function formatDueDate(timestamp) {
    if (!timestamp || timestamp === 0) return ""
    var d = new Date(timestamp * 1000)
    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var due = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    var diff = Math.floor((due - today) / 86400000)
    if (diff < 0) return "overdue"
    if (diff === 0) return "today"
    if (diff === 1) return "tomorrow"
    if (diff <= 7) return diff + "d"
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    return months[d.getMonth()] + " " + d.getDate()
}

function isDueOverdue(timestamp) {
    if (!timestamp || timestamp === 0) return false
    var d = new Date(timestamp * 1000)
    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    return d < today
}

function parseTags(tagsStr) {
    if (!tagsStr) return []
    try {
        var arr = JSON.parse(tagsStr)
        return Array.isArray(arr) ? arr : []
    } catch(e) { return [] }
}
