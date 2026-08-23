SPORTOTEKA Tracker — Tablet/Desktop Concept V96

Base: V95 + compile fix.

Fix:
- Dashboard "Последние сессии" no longer treats _sessions() widget-builder method as a List.
- Recent 5 sessions are loaded using the existing TrackerProApi.loadSessions(teamId, playerId:null, limit:5).
- Loading and empty states are preserved in the dashboard card.

Mobile V94 behavior and V95 tablet/desktop concept changes are preserved.
