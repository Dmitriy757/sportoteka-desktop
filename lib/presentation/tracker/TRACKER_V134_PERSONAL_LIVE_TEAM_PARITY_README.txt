SPORTOTEKA TRACKER V134 — PERSONAL LIVE / TEAM LIVE PARITY
Date: 2026-08-16

Changes in coach -> Personal trainings:

1. Personal Live now uses the same workspace split as Team Live:
   - left workspace 65%
   - 1 px vertical system divider
   - right Data / Journal panel 35%
   - both panels have exactly the same height
   - on tablet the split stays horizontal; only very narrow layouts stack.

2. Left Personal Live workspace:
   - map / heart-rate switch is a compact overlay, like Team Live controls
   - selected player's avatar + full surname-first name + LIVE state is visible over the map
   - map/pulse occupies the workspace instead of being wrapped in another large card
   - Team-Live-style timeline below the workspace
   - compact KPI strip below the timeline

3. Right panel:
   - Team-Live-style 36 px header
   - Data / Journal switch
   - no duplicated inner header
   - Journal shows Live/Review status, event counters and event list
   - selecting a journal event moves the map to the saved moment
   - one return-to-LIVE action when reviewing a moment.

4. Coach Personal header / navigation:
   - trainer header stays in one compact line with online/today/Polar/GPS/attention stats
   - player cards use surname-first display
   - resolved server roster is used for names and avatars.

5. Overview:
   - removed duplicate current-Live training card; current live work is only in the Live tab
   - Overview remains focused on archive, attention, quality and recent results.

6. Calendar / sessions:
   - roster photos are resolved from the server player directory
   - session rows show full surname-first player name
   - fallback name matching can restore a player's photo for older sessions where player_id/user_id differ.

7. Counter cleanup:
   - completed notification duplicates are collapsed to unique sessions for trainer-facing counts.

No PHP changes are required for this UI revision.
