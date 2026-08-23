SPORTOTEKA TRACKER V102 — CMR FLAGSHIP DENSITY
Date: 2026-08-12

Base: user archive "tracker 10".
Reference UI geometry: CMR Club Trainers panel (compact white workspace, thin dividers, minimal outer gutters).

Main changes:
1. Dashboard/Overview removed from visible Tracker navigation. Tracker opens on LIVE.
2. Desktop/tablet workspace outer gutters removed; light icon rail tightened.
3. LIVE desktop/tablet rebuilt as flagship split view:
   - map is permanently visible on the left;
   - team KPI strip directly under map;
   - player strip + selected player live details / team table on the right;
   - tablet keeps split view instead of stacking map and data vertically;
   - map layer uses existing player avatar markers and GPS tracks.
4. LIVE surfaces/header spacing reduced and shadows softened.
5. Devices desktop/tablet compacted:
   - duplicate page header removed;
   - large instruction banner removed;
   - roster starts immediately below 40px toolbar;
   - roster widened (desktop 390px, tablet 340px);
   - player names/avatars/status badges enlarged;
   - selected player's GPS and Polar assignment cards remain visible on right.
6. Analytics:
   - stage-based top loading strip with percentage instead of small top-right spinner;
   - cached analytics stays visible during reload;
   - per-session heavy Polar HR fallback only runs on Pulse tab;
   - heatmap fallback behavior from previous version retained (server heatmap only when GPS points absent);
   - palette/radii tightened to CMR flagship style.
7. Players page outer padding/grid gaps reduced to match the same dense workspace system.

No PHP/API/BLE protocol changes were introduced in this V102 design pass.
