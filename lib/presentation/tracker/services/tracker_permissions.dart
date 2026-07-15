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
      if (status.isGranted) return;

      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }

      throw Exception(
        'Нет разрешения Bluetooth для поиска трекера. ' 
        'На iPhone откройте Настройки → Спортотека → Bluetooth и включите доступ. ' 
        'Если переключателя Bluetooth нет, проверьте iOS/Runner/Info.plist: нужны NSBluetoothAlwaysUsageDescription и NSBluetoothPeripheralUsageDescription.',
      );
    }
  }


  static Future<String> diagnostics() async {
    final parts = <String>['platform=${Platform.operatingSystem}'];

    Future<void> addPermission(String label, Permission permission) async {
      try {
        final status = await permission.status;
        parts.add('$label=$status');
      } catch (e) {
        parts.add('$label=unknown($e)');
      }
    }

    // В текущей версии permission_handler в проекте нет getter `serviceStatus`.
    // Поэтому состояние системной геолокации не читаем напрямую, чтобы не ломать сборку.
    // Для Android всё равно проверяем разрешение locationWhenInUse, а если поиск BLE
    // ничего не видит, в debug подсказываем включить системную геолокацию вручную.
    void addServiceHint(String label) {
      parts.add('$label=not_checked_permission_handler_compat');
    }

    if (Platform.isAndroid) {
      await addPermission('bluetoothScan', Permission.bluetoothScan);
      await addPermission('bluetoothConnect', Permission.bluetoothConnect);
      await addPermission('locationWhenInUse', Permission.locationWhenInUse);
      addServiceHint('locationService');
    } else if (Platform.isIOS) {
      await addPermission('bluetooth', Permission.bluetooth);
      parts.add('iosSettings=Настройки → Спортотека → Bluetooth');
      parts.add('iosInfoPlist=NSBluetoothAlwaysUsageDescription/NSBluetoothPeripheralUsageDescription required');
    } else if (Platform.isMacOS) {
      await addPermission('bluetooth', Permission.bluetooth);
    }

    return parts.join(' · ');
  }

}
