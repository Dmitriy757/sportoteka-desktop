SPORTOTEKA TRACKER V85 — near-limit GPS spike / anchor fix
Date: 2026-08-13

WHY V84 COULD STILL SHOW 34–35.9 KM/H
V84 rejected speeds above 36 km/h, but in team Live the rejected raw GPS
coordinate was still used as the next speed-calculation anchor. When GPS jumped
away (>36) and then returned to the real route one second later, the return
segment could be 34–35.9 km/h and therefore pass the hard 36 km/h ceiling.

V85 FIX
1. Rejected GPS points never become the next anchor.
2. Speed 28–36 km/h is accepted only when acceleration is physically plausible
   (absolute acceleration <= 4.5 m/s^2).
3. Speed >=16 km/h also has a general acceleration ceiling of 7 m/s^2.
4. >36 km/h remains a hard rejection, not a clamp.
5. Stationary drift: <1.5 km/h or <0.35 m contributes 0 distance/speed.
6. GPS gap >10 s starts a new segment with zero connecting distance.
7. Duplicate/backwards GPS time is rejected without moving the anchor.
8. save_tracker_live_point.php independently validates raw coordinates server-side.
9. Raw coordinates + reject reason are retained for diagnostics where supported.
10. Server response returns authoritative safe speed/distance/max to V85 client.

SERVER FILES CHANGED
- save_tracker_live_point.php
- process_tracker_session.php
- tracker_report_analytics_lib.php
- repair_tracker_near_limit_spikes_v85.php (new)

SAFE DEPLOYMENT
1) Back up /var/www/sportoteka/api/tracker.
2) Replace the three runtime PHP files above and add the repair script.
3) Check syntax:
   php -l save_tracker_live_point.php
   php -l process_tracker_session.php
   php -l tracker_report_analytics_lib.php
   php -l repair_tracker_near_limit_spikes_v85.php
4) DRY RUN ONLY first:
   php repair_tracker_near_limit_spikes_v85.php
5) Review output before using --apply.

The dry run does not ALTER/UPDATE the database. --apply creates backup tables
before rewriting suspicious recent live/final session data.

IMPORTANT
Debug rows showing last RX / last GPS around 950 seconds and
"GPS sensor not connected" are a separate BLE/GATT connectivity issue. V85
fixes GPS speed/distance contamination; it does not by itself reconnect BLE.
