import 'package:flutter/material.dart';

import 'services/team_tracker_live_coordinator.dart';

class TeamLiveDebugDialog extends StatelessWidget {
  final TeamTrackerLiveCoordinator coordinator;

  const TeamLiveDebugDialog({super.key, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    final rows = coordinator.debugRows;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.bug_report_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Debug командного Live', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Text('${rows.where((e) => e.bleReady).length}/${rows.length} BLE'),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Командная сессия ещё не запущена'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final ok = row.bleReady && row.liveSessionId != null && row.lastError == null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                                  color: ok ? Colors.green : Colors.red),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: Text(row.playerName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              Expanded(flex: 2, child: Text(row.deviceName)),
                              Expanded(flex: 3, child: Text(row.deviceUuid, overflow: TextOverflow.ellipsis)),
                              Expanded(child: Text(row.bleReady ? 'BLE OK' : 'BLE OFF')),
                              Expanded(child: Text('#${row.liveSessionId ?? '—'}')),
                              Expanded(child: Text('RX ${row.receivedPackets}')),
                              Expanded(child: Text('GPS ${row.savedPoints}')),
                              Expanded(flex: 2, child: Text(row.lastError ?? 'OK', overflow: TextOverflow.ellipsis)),
                            ]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
