import 'dart:ui';
import 'package:flutter/material.dart';

import '../../data/models/ai_video_analysis_models.dart';
import 'tracking_models.dart';

List<PlayerTrack> mapServerTracksToPlayerTracks(List<AiTrackPacket> tracks) {
  return tracks.map((t) {
    final bbox = t.displayBBox ?? t.bbox;

    Rect? rect;
    if (bbox != null) {
      rect = Rect.fromLTRB(
        bbox.left,
        bbox.top,
        bbox.right,
        bbox.bottom,
      );
    }

    final point = t.imagePoint != null
        ? Offset(t.imagePoint!.x, t.imagePoint!.y)
        : rect != null
            ? Offset(rect.center.dx, rect.bottom)
            : Offset.zero;

    return PlayerTrack(
      id: t.trackId,
      boundPlayerId: t.playerId,
      boundPlayerName: t.playerName,
      color: t.teamTag == 'home'
          ? const Color(0xFF2563EB)
          : t.teamTag == 'away'
              ? const Color(0xFFDC2626)
              : Colors.redAccent,
      points: [
        TrackPoint(
          position: point,
          timeMs: 0,
          speed: t.speedKmh,
          vx: 0,
          vy: 0,
          ax: 0,
          ay: 0,
          rect: rect,
        ),
      ],
      createdAtMs: 0,
      lastSeenTimeMs: 0,
      speed: t.speedKmh,
      lockedBox: rect,
      teamTag: t.teamTag,
      jerseyNumber: t.jerseyNumber,
    );
  }).toList();
}