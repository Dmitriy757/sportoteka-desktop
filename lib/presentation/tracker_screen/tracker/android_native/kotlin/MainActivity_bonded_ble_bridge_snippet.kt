// Вставьте этот блок в ваш android/app/src/main/kotlin/.../MainActivity.kt.
// Package должен остаться тот же, что уже есть в вашем MainActivity.kt.
// Если MainActivity уже переопределяет configureFlutterEngine — просто добавьте
// MethodChannel(...) внутрь существующего configureFlutterEngine после super.

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val actionTrackerBleChannel = "sportoteka/action_tracker_ble"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, actionTrackerBleChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBondedBluetoothDevices" -> {
                        try {
                            result.success(getBondedBluetoothDevicesForTracker())
                        } catch (e: SecurityException) {
                            result.error("bluetooth_permission", e.message ?: "Нет Bluetooth-разрешения", null)
                        } catch (e: Exception) {
                            result.error("bluetooth_bonded_error", e.message ?: e.toString(), null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getBondedBluetoothDevicesForTracker(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("Нет разрешения BLUETOOTH_CONNECT / Устройства поблизости")
        }

        val manager = getSystemService(BluetoothManager::class.java)
        val adapter = manager?.adapter ?: BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        val bonded = adapter.bondedDevices ?: return emptyList()

        return bonded.map { device ->
            mapOf(
                "address" to device.address,
                "id" to device.address,
                "name" to (device.name ?: ""),
                "type" to bluetoothTypeName(device.type),
                "bondState" to bondStateName(device.bondState),
                "uuids" to (device.uuids?.map { it.uuid.toString() } ?: emptyList<String>())
            )
        }
    }

    private fun bluetoothTypeName(type: Int): String {
        return when (type) {
            BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
            BluetoothDevice.DEVICE_TYPE_LE -> "le"
            BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
            else -> "unknown"
        }
    }

    private fun bondStateName(state: Int): String {
        return when (state) {
            BluetoothDevice.BOND_BONDED -> "bonded"
            BluetoothDevice.BOND_BONDING -> "bonding"
            BluetoothDevice.BOND_NONE -> "none"
            else -> state.toString()
        }
    }
}
