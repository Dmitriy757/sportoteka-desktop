import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class TrackerPermissions {
  static Future<void> ensureBlePermissions() async {
    if (Platform.isAndroid) {
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];

      final statuses = await permissions.request();
      final denied = statuses.entries.where((e) => !e.value.isGranted).toList();
      if (denied.isNotEmpty) {
        throw Exception('Нет разрешений Bluetooth/геолокации для поиска трекера');
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        throw Exception('Нет разрешения Bluetooth для подключения трекера');
      }
    }
  }
}
