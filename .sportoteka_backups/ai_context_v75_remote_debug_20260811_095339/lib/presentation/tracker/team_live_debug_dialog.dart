import 'dart:async';

import 'package:flutter/material.dart';

import 'services/team_tracker_live_coordinator.dart';

class TeamLiveDebugDialog extends StatefulWidget {
  final TeamTrackerLiveCoordinator coordinator;

  const TeamLiveDebugDialog({super.key, required this.coordinator});

  @override
  State<TeamLiveDebugDialog> createState() => _TeamLiveDebugDialogState();
}

class _TeamLiveDebugDialogState extends State<TeamLiveDebugDialog> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _age(DateTime? value) {
    if (value == null) return '—';
    final seconds = DateTime.now().difference(value).inSeconds;
    if (seconds < 0) return '0с';
    if (seconds < 60) return '${seconds}с';
    return '${seconds ~/ 60}м ${seconds % 60}с';
  }

  bool _ok(TeamTrackerChannelDebug row) {
    return row.bleReady &&
        row.liveSessionId != null &&
        row.lastError == null &&
        (row.lastRxAt == null ||
            DateTime.now().difference(row.lastRxAt!).inSeconds < 40);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.coordinator.debugRows;
    final ready = rows.where((row) => row.bleReady).length;
    final problems = rows.where((row) => !_ok(row)).length;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.monitor_heart_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debug командного Live',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      Text('Обновление каждую секунду',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                _HeaderBadge(
                    text: '$ready/${rows.length} BLE',
                    color: ready == rows.length && rows.isNotEmpty
                        ? Colors.green
                        : Colors.orange),
                const SizedBox(width: 7),
                _HeaderBadge(
                    text: '$problems проблем',
                    color: problems == 0 ? Colors.green : Colors.red),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text('Командная сессия ещё не запущена'))
                    : LayoutBuilder(builder: (context, constraints) {
                        if (constraints.maxWidth < 820) {
                          return ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) => _mobileCard(rows[index]),
                          );
                        }
                        return _desktopTable(rows);
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopTable(List<TeamTrackerChannelDebug> rows) {
    return Column(children: [
      const _DebugTableRow.header(),
      const Divider(height: 1),
      Expanded(
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final row = rows[index];
            return _DebugTableRow(
              row: row,
              ok: _ok(row),
              rxAge: _age(row.lastRxAt),
              gpsAge: _age(row.lastGpsAt),
            );
          },
        ),
      ),
    ]);
  }

  Widget _mobileCard(TeamTrackerChannelDebug row) {
    final ok = _ok(row);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF1FBF4) : const Color(0xFFFFF5F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(
              child: Text(row.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(row.bleReady ? 'BLE OK' : 'BLE OFF',
              style: TextStyle(
                  color: row.bleReady ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 7),
        Text('${row.deviceName} · ${row.deviceUuid}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 7),
        Text(
          'Live #${row.liveSessionId ?? '—'} · RX ${row.receivedPackets} (${_age(row.lastRxAt)}) · GPS ${row.savedPoints} (${_age(row.lastGpsAt)})',
        ),
        const SizedBox(height: 4),
        Text(
          'Скорость ${row.lastSpeedKmh.toStringAsFixed(1)} · max ${row.maxSpeedKmh.toStringAsFixed(1)} км/ч · ${row.totalDistanceM.toStringAsFixed(0)} м · восстановлений ${row.recoveryCount}',
        ),
        if (row.lastError != null) ...[
          const SizedBox(height: 6),
          Text(row.lastError!,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _DebugTableRow extends StatelessWidget {
  const _DebugTableRow({
    required this.row,
    required this.ok,
    required this.rxAge,
    required this.gpsAge,
  }) : header = false;

  const _DebugTableRow.header()
      : row = null,
        ok = false,
        rxAge = '',
        gpsAge = '',
        header = true;

  final TeamTrackerChannelDebug? row;
  final bool ok;
  final String rxAge;
  final String gpsAge;
  final bool header;

  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(
      fontSize: header ? 10.5 : 11,
      fontWeight: header ? FontWeight.w800 : FontWeight.w600,
      color: header ? Colors.black54 : Colors.black87,
    );
    Widget cell(String text, int flex, {Color? color, int maxLines = 1}) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Text(text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: color)),
          ),
        );

    if (header) {
      return Row(children: [
        const SizedBox(width: 28),
        cell('Игрок', 16),
        cell('Устройство', 14),
        cell('BLE / Live', 10),
        cell('RX', 9),
        cell('GPS', 9),
        cell('Скорость', 10),
        cell('Дистанция', 8),
        cell('Reconnect', 7),
        cell('Ошибка', 17),
      ]);
    }

    final r = row!;
    return Row(children: [
      SizedBox(
        width: 28,
        child: Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18, color: ok ? Colors.green : Colors.red),
      ),
      cell(r.playerName, 16),
      cell(r.deviceName, 14),
      cell('${r.bleReady ? 'OK' : 'OFF'} · #${r.liveSessionId ?? '—'}', 10,
          color: r.bleReady ? Colors.green : Colors.red),
      cell('${r.receivedPackets} · $rxAge', 9),
      cell('${r.savedPoints} · $gpsAge', 9),
      cell(
          '${r.lastSpeedKmh.toStringAsFixed(1)} / ${r.maxSpeedKmh.toStringAsFixed(1)}',
          10),
      cell('${r.totalDistanceM.toStringAsFixed(0)} м', 8),
      cell('${r.recoveryCount}', 7),
      cell(r.lastError ?? 'OK', 17,
          color: r.lastError == null ? null : Colors.red, maxLines: 2),
    ]);
  }
}
