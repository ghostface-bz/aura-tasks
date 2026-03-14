# Changelog

## v0.6.0 — 2026-03-15

### Initial Public Release

**Core**
- Task management with natural language input (`#tags`, `!priority`, `tomorrow`, `daily`)
- SQLite local storage via QtQuick LocalStorage
- Recurring tasks (daily / weekly auto-respawn)
- Undo task completion from Done tab

**Gamification**
- XP system: 10–100 XP per task based on priority
- 10 levels: Novice → Singularity
- Daily streak tracking with consecutive-day counter
- 8 badges: First Task, 10 Tasks, Centurion, 3/7/30-Day Streak, Night Owl, Early Bird

**Pomodoro Timer**
- Per-task timer with 25m work / 5m break / 15m long break cycles
- 4-session tracking with visual dots
- Focus Shield mode: dedicated single-task zen timer
- Skip/next button to cycle focus task

**Focus Shield**
- Distraction-free single-task view
- Zen title styling (24px light weight)
- Breathing pulse animation on check circle
- Tags and due date display
- Empty state with 円 watermark and daily completion count

**Themes**
- Sumi 墨 — Japanese ink (default dark)
- Kon 紺 — Deep indigo
- Matsu 松 — Pine forest
- Sakura 桜 — Cherry blossom
- Ishi 石 — Stone granite
- Washi 和紙 — Paper (light mode)
- System — Adapts to KDE Plasma theme via Kirigami

**Animations**
- Focus Shield fade + scale entry/exit (300ms)
- Input row, tab bar, dividers: smooth opacity transitions (250ms)
- DailyRing: Canvas circular arc with animated fill
- XpPopup: slide + scale pop + fade
- LevelUpBanner: scale stamp entrance + accent pulse
- CompletionBurst: expanding ring on task completion
- Check circle: scale hover effect on TaskCard
- Input field: accent glow on focus

**Notifications**
- Desktop notifications via notify-send
- Pomodoro phase transitions (work → break → work)
- Level up alerts
- Badge unlock alerts
- Toggle via notificationsEnabled config
