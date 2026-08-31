package com.example.sportoteka

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import com.hiennv.flutter_callkit_incoming.CallkitConnection
import android.telecom.CallAudioState
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.content.Context
import android.os.Build
import android.view.WindowManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val actionTrackerBleChannel = "sportoteka/action_tracker_ble"
    private val callAudioChannel = "sportoteka/call_audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, actionTrackerBleChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setTrackerKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(true)
                        }
                    }
                    "getBondedBluetoothDevices" -> {
                        try {
                            result.success(getBondedBluetoothDevicesForTracker())
                        } catch (e: SecurityException) {
                            result.error(
                                "bluetooth_permission",
                                e.message ?: "Нет Bluetooth-разрешения",
                                null
                            )
                        } catch (e: Exception) {
                            result.error(
                                "bluetooth_bonded_error",
                                e.message ?: e.toString(),
                                null
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            callAudioChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSpeaker" -> {
                    val enabled =
                        call.argument<Boolean>("enabled") ?: false
                    val callUuid =
                        call.argument<String>("callUuid") ?: ""

                    try {
                        setSportotekaCallSpeaker(
                            enabled = enabled,
                            callUuid = callUuid
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "call_audio_route",
                            e.message ?: e.toString(),
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }


    }


    @SuppressLint("MissingPermission")
    private fun setSportotekaCallSpeaker(
        enabled: Boolean,
        callUuid: String
    ) {
        val audioManager =
            getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Сначала находим self-managed Telecom Connection.
        val connection =
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                callUuid.isNotBlank()
            ) {
                CallkitConnection.find(callUuid)
            } else {
                null
            }

        // КРИТИЧНО:
        // сообщаем Android Telecom, что это именно VoIP.
        //
        // Без этого Telecom может использовать MODE_IN_CALL
        // и перетирать MODE_IN_COMMUNICATION, установленный
        // LiveKit/AudioManager.
        if (connection != null) {
            try {
                connection.setAudioModeIsVoip(true)

                Log.i(
                    "SPORTOTEKA_CALL_AUDIO",
                    "VoIP mode enabled uuid=$callUuid"
                )
            } catch (e: Exception) {
                Log.e(
                    "SPORTOTEKA_CALL_AUDIO",
                    "setAudioModeIsVoip error",
                    e
                )
            }
        }

        // WebRTC / LiveKit должен работать именно в communication mode.
        audioManager.mode =
            AudioManager.MODE_IN_COMMUNICATION

        // Сначала сообщаем Telecom желаемый route.
        if (connection != null) {
            val route =
                if (enabled) {
                    CallAudioState.ROUTE_SPEAKER
                } else {
                    CallAudioState.ROUTE_EARPIECE
                }

            try {
                @Suppress("DEPRECATION")
                connection.setAudioRoute(route)

                Log.i(
                    "SPORTOTEKA_CALL_AUDIO",
                    "Telecom route=$route speaker=$enabled uuid=$callUuid"
                )
            } catch (e: Exception) {
                Log.e(
                    "SPORTOTEKA_CALL_AUDIO",
                    "Telecom route error",
                    e
                )
            }
        } else {
            Log.w(
                "SPORTOTEKA_CALL_AUDIO",
                "CallkitConnection NOT FOUND uuid=$callUuid"
            )
        }

        // После Telecom выбираем физический communication device.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val targetType =
                if (enabled) {
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                } else {
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                }

            val target =
                audioManager.availableCommunicationDevices
                    .firstOrNull {
                        it.type == targetType && it.isSink
                    }

            if (target != null) {
                val result =
                    audioManager.setCommunicationDevice(target)

                Log.i(
                    "SPORTOTEKA_CALL_AUDIO",
                    "setCommunicationDevice " +
                        "result=$result " +
                        "type=${target.type} " +
                        "name=${target.productName} " +
                        "speaker=$enabled"
                )
            } else {
                Log.w(
                    "SPORTOTEKA_CALL_AUDIO",
                    "communication target not found " +
                        "type=$targetType speaker=$enabled"
                )

                if (!enabled) {
                    audioManager.clearCommunicationDevice()
                }
            }

            val current =
                audioManager.communicationDevice

            Log.i(
                "SPORTOTEKA_CALL_AUDIO",
                "FINAL mode=${audioManager.mode} " +
                    "deviceType=${current?.type} " +
                    "device=${current?.productName} " +
                    "speaker=$enabled"
            )
        } else {
            @Suppress("DEPRECATION")
            run {
                audioManager.isSpeakerphoneOn = enabled
            }

            Log.i(
                "SPORTOTEKA_CALL_AUDIO",
                "LEGACY mode=${audioManager.mode} " +
                    "speaker=${audioManager.isSpeakerphoneOn}"
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun getBondedBluetoothDevicesForTracker(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("Нет разрешения BLUETOOTH_CONNECT / Устройства поблизости")
        }

        val manager = getSystemService(BluetoothManager::class.java)
        val adapter = manager?.adapter ?: BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        val bondedDevices = adapter.bondedDevices ?: return emptyList()

        return bondedDevices.map { device ->
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
