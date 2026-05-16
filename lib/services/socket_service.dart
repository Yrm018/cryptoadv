import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config/api_config.dart';

/// Types d'événements WebSocket
enum SocketEvent { message, callOffer, callAnswer, callIce, callEnd, callReject }

/// Service WebSocket — connexion temps réel avec le backend EC2
class SocketService extends ChangeNotifier {
  static final SocketService instance = SocketService._();
  SocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  String? _token;

  // Callbacks
  void Function(Map<String, dynamic>)? onMessage;
  void Function(Map<String, dynamic>)? onMessageRead;
  void Function(Map<String, dynamic>)? onCallOffer;
  void Function(Map<String, dynamic>)? onCallAnswer;
  void Function(Map<String, dynamic>)? onCallIce;
  void Function(Map<String, dynamic>)? onCallEnd;
  void Function(Map<String, dynamic>)? onCallReject;

  bool get isConnected => _connected;

  // ── Connexion ─────────────────────────────────────────────────────────────

  Future<void> connect(String token) async {
    _token = token;
    await disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      _sub = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone:  _handleDone,
      );

      // Authentification
      _send({ 'type': 'auth', 'token': token });
    } catch (e) {
      debugPrint('[WS] Connexion échouée: $e');
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    notifyListeners();
  }

  // ── Envoi ─────────────────────────────────────────────────────────────────

  void _send(Map<String, dynamic> payload) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendChatMessage({
    required String receiverId,
    required String conversationId,
    required String cipherText,
    required String mode,
    required String algorithm,
    String type = 'text',
    String? fileName,
    int?    fileSize,
    String? encryptedAesKey,
    String? iv,
    String? signature,
  }) {
    _send({
      'type':           'message',
      'receiverId':     receiverId,
      'conversationId': conversationId,
      'cipherText':     cipherText,
      'mode':           mode,
      'algorithm':      algorithm,
      'msgType':        type,
      if (fileName        != null) 'fileName':        fileName,
      if (fileSize        != null) 'fileSize':        fileSize,
      if (encryptedAesKey != null) 'encryptedAesKey': encryptedAesKey,
      if (iv              != null) 'iv':              iv,
      if (signature       != null) 'signature':       signature,
    });
  }

  // ── Signaling appels WebRTC ───────────────────────────────────────────────

  void sendCallOffer({required String targetId, required String callType, required Map<String, dynamic> sdp}) {
    _send({ 'type': 'call_offer', 'targetId': targetId, 'callType': callType, 'sdp': sdp });
  }

  void sendCallAnswer({required String targetId, required Map<String, dynamic> sdp}) {
    _send({ 'type': 'call_answer', 'targetId': targetId, 'sdp': sdp });
  }

  void sendIceCandidate({required String targetId, required Map<String, dynamic> candidate}) {
    _send({ 'type': 'call_ice', 'targetId': targetId, 'candidate': candidate });
  }

  void sendCallEnd({required String targetId}) {
    _send({ 'type': 'call_end', 'targetId': targetId });
  }

  void sendCallReject({required String targetId}) {
    _send({ 'type': 'call_reject', 'targetId': targetId });
  }

  void sendPing() => _send({ 'type': 'ping' });

  // ── Réception ─────────────────────────────────────────────────────────────

  void _handleMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try { msg = jsonDecode(raw as String); } catch(e) { return; }

    switch (msg['type']) {
      case 'auth_ok':
        _connected = true;
        notifyListeners();
        debugPrint('[WS] Authentifié ✓');
        break;
      case 'auth_error':
        debugPrint('[WS] Auth échouée: ${msg['error']}');
        break;
      case 'message':
        onMessage?.call(msg);
        break;
      case 'message_read':
        onMessageRead?.call(msg);
        break;
      case 'call_offer':
        onCallOffer?.call(msg);
        break;
      case 'call_answer':
        onCallAnswer?.call(msg);
        break;
      case 'call_ice':
        onCallIce?.call(msg);
        break;
      case 'call_end':
        onCallEnd?.call(msg);
        break;
      case 'call_reject':
        onCallReject?.call(msg);
        break;
      case 'pong':
        break;
    }
  }

  void _handleError(Object err) {
    debugPrint('[WS] Erreur: $err');
    _connected = false;
    notifyListeners();
    _reconnect();
  }

  void _handleDone() {
    debugPrint('[WS] Connexion fermée');
    _connected = false;
    notifyListeners();
    _reconnect();
  }

  // ── Reconnexion automatique ───────────────────────────────────────────────

  Timer? _reconnectTimer;

  void _reconnect() {
    _reconnectTimer?.cancel();
    if (_token == null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      debugPrint('[WS] Reconnexion...');
      if (_token != null) await connect(_token!);
    });
  }
}
