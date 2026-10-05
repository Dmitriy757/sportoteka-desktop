import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Transport layer for the iPhone/Android Sportoteka camera screen.
///
/// The actual camera widget can use the project's existing camera plugin and
/// pass JPEG frames here. This file deliberately has no dependency on a
/// specific camera package, so it is safe for macOS/Windows builds too.
class PhoneCameraLiveTransport {
  PhoneCameraLiveTransport({
    this.endpoint = 'wss://sportotekaapp.ru/ai/',
  });

  final String endpoint;
  WebSocket? _socket;
  String pairId = '';
  String pairToken = '';
  bool connected = false;
  bool streaming = false;

  Future<void> connectFromPairUrl(String pairUrl) async {
    final uri = Uri.tryParse(pairUrl);
    final token = uri?.queryParameters['pair'] ?? '';
    if (token.isEmpty) throw ArgumentError('Pair token not found in URL');
    await connect(token);
  }

  Future<void> connect(String token) async {
    pairToken = token;
    _socket = await WebSocket.connect(endpoint).timeout(const Duration(seconds: 10));
    connected = true;
    _socket!.add(jsonEncode({
      'action': 'claim_phone_pairing',
      'pair_token': token,
    }));

    await for (final raw in _socket!) {
      if (raw is! String) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final data = Map<String, dynamic>.from(decoded);
      if (data['type'] == 'phone_pairing_claimed') {
        pairId = '${data['pair_id'] ?? ''}';
        if (pairId.isEmpty) throw StateError('Server did not return pair_id');
        _socket!.add(jsonEncode({
          'action': 'start_phone_live',
          'pair_id': pairId,
          'pair_token': pairToken,
        }));
        streaming = true;
        return;
      }
      if (data['type'] == 'error') {
        throw StateError('${data['message'] ?? data['error'] ?? 'Pairing failed'}');
      }
    }
    throw StateError('Pairing connection closed');
  }

  void sendJpeg(Uint8List jpeg, {bool ack = false}) {
    final socket = _socket;
    if (!streaming || socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode({
      'action': 'phone_frame',
      'pair_id': pairId,
      'pair_token': pairToken,
      'jpeg_base64': base64Encode(jpeg),
      'ack': ack,
    }));
  }

  Future<void> finish() async {
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode({
        'action': 'stop_match',
      }));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await socket.close();
    }
    connected = false;
    streaming = false;
  }

  Future<void> closeWithoutStoppingMatch() async {
    await _socket?.close();
    connected = false;
    streaming = false;
  }
}
