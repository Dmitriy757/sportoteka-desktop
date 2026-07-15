// Java-вариант для android/app/src/main/java/.../MainActivity.java.
// Package должен остаться тот же, что уже есть в вашем MainActivity.java.

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String ACTION_TRACKER_BLE_CHANNEL = "sportoteka/action_tracker_ble";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ACTION_TRACKER_BLE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("getBondedBluetoothDevices".equals(call.method)) {
                        try {
                            result.success(getBondedBluetoothDevicesForTracker());
                        } catch (SecurityException e) {
                            result.error("bluetooth_permission", e.getMessage(), null);
                        } catch (Exception e) {
                            result.error("bluetooth_bonded_error", e.getMessage(), null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private List<Map<String, Object>> getBondedBluetoothDevicesForTracker() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            throw new SecurityException("Нет разрешения BLUETOOTH_CONNECT / Устройства поблизости");
        }

        BluetoothManager manager = (BluetoothManager) getSystemService(BluetoothManager.class);
        BluetoothAdapter adapter = manager != null ? manager.getAdapter() : BluetoothAdapter.getDefaultAdapter();
        List<Map<String, Object>> result = new ArrayList<>();
        if (adapter == null || adapter.getBondedDevices() == null) return result;

        for (BluetoothDevice device : adapter.getBondedDevices()) {
            Map<String, Object> item = new HashMap<>();
            item.put("address", device.getAddress());
            item.put("id", device.getAddress());
            item.put("name", device.getName() == null ? "" : device.getName());
            item.put("type", bluetoothTypeName(device.getType()));
            item.put("bondState", bondStateName(device.getBondState()));
            result.add(item);
        }
        return result;
    }

    private String bluetoothTypeName(int type) {
        switch (type) {
            case BluetoothDevice.DEVICE_TYPE_CLASSIC: return "classic";
            case BluetoothDevice.DEVICE_TYPE_LE: return "le";
            case BluetoothDevice.DEVICE_TYPE_DUAL: return "dual";
            default: return "unknown";
        }
    }

    private String bondStateName(int state) {
        switch (state) {
            case BluetoothDevice.BOND_BONDED: return "bonded";
            case BluetoothDevice.BOND_BONDING: return "bonding";
            case BluetoothDevice.BOND_NONE: return "none";
            default: return String.valueOf(state);
        }
    }
}
