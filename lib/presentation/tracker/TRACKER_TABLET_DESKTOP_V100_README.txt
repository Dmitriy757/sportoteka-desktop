SPORTOTEKA TRACKER — TABLET/DESKTOP V100
Date: 2026-08-12

V100 continues the white tracker concept for desktop and tablet and keeps mobile work from previous versions.

Main changes:
1. Desktop/tablet Overview rebuilt closer to the approved concept: three equal top cards (today, player readiness, load), then recent sessions + quick actions.
2. Player cards are denser and more informative: avatar, number, role, explicit GPS/Polar assignment names, fresh HR, live readiness.
3. Devices workspace is more informative: team roster stays on the left; for selected player the right side immediately shows current GPS and Cardio/Polar H10 assignment, online state and Replace/Assign action; discovered devices remain below on the full remaining area.
4. Live field on desktop/tablet now overlays real player avatars above the heatmap/field canvas and keeps smooth marker movement and speed badges.
5. Live team KPI fallback added so speed/distance/max speed/sprints/load do not stay at zero merely because player↔session mapping has not resolved yet; it safely falls back to current local tracks or online live sessions.
6. History is now one calendar-first workspace based on the same calendar/session UI as Analytics; report opens for the selected session instead of forcing a second permanent report banner.
7. Analytics loading optimized: request memoization, cached last view while refreshing, and parallel GPS/heatmap/HR requests.
8. Spacing on the main desktop/tablet workspaces standardized and player/device grids tightened to fit the viewport more consistently.

Server APIs, BLE pool, GPS/Polar assignment functions and persistence endpoints are preserved.
