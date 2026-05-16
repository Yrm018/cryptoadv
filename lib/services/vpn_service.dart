import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_service.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../backend/crypto/cryptavance.dart';
import '../backend/security/rsa_service.dart';
import '../backend/security/pki_service.dart';
import '../backend/security/keygen.dart';
import '../models/vpn_message_model.dart';
import '../models/certificate_model.dart';

class VpnDecryptResult {
  final String message;
  final bool signatureValid;
  final bool certificateValid;
  final bool certRevoked;
  final String senderEmail;
  final CertificateData? senderCert;

  const VpnDecryptResult({
    required this.message, required this.signatureValid,
    required this.certificateValid, required this.certRevoked,
    required this.senderEmail, required this.senderCert,
  });
}

class VpnService {
  final _db      = DatabaseService.instance;
  final _auth    = AuthService();
  final _network = NetworkService.instance;

  // Récupère l'utilisateur courant (async car hive)
  Future<LocalUser> _getUser() async {
    final u = await _auth.currentUser;
    if (u == null) throw Exception("Utilisateur non connecté");
    return u;
  }

  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${(t * 9301 + 49297) % 233280}';
  }

  // ─── Key & Certificate Management ────────────────────────────────────────

  Future<bool> hasKeys() async {
    final user = await _getUser();
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('rsa_priv_${user.id}');
  }

  Future<void> generateAndRegisterKeys() async {
    final user = await _getUser();

    // Web → window.crypto.subtle (non-bloquant, ~100ms)
    // Native → compute() dans un isolate séparé
    final keys = await generateKeyPairPlatform();
    final pubJson  = keys['pub']!;
    final privJson = keys['priv']!;

    // 1. Clé privée : stockée localement uniquement (jamais partagée)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rsa_priv_${user.id}', privJson);

    // 2. Clé publique : Hive local
    final userData = Map<String, dynamic>.from(_db.users.get(user.id) ?? {
      'id':    user.id,
      'email': user.email,
      'username': user.username,
    });
    userData['rsaPublicKey'] = pubJson;
    await _db.users.put(user.id, userData);

    // 3. Clé publique : uploadée sur le serveur EC2
    //    → les autres utilisateurs peuvent la récupérer via /users/search
    if (_network.isAuthenticated) {
      try {
        await _network.updateProfile(publicKey: pubJson);
      } catch (e) {
        debugPrint('[VpnService] Upload clé publique échoué: $e');
      }
    }

    // 4. Certificat X.509 local
    final cert = await PkiService.issueCertificate(
      userEmail: user.email,
      userUid:   user.id,
      userPublicKeyJson: pubJson,
    );
    userData['rsaCertSerial'] = cert.serialNumber;
    await _db.users.put(user.id, userData);
  }

  Future<CertificateData?> getMyCertificate() async {
    final user = await _getUser();
    return PkiService.getCertificate(user.id);
  }

  Future<String?> getMyPublicKey() async {
    final user = await _getUser();
    final data = _db.users.get(user.id);
    return data?['rsaPublicKey'] as String?;
  }

  // ─── Send Message ─────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String receiverEmail,
    required String message,
  }) async {
    final user = await _getUser();
    final prefs = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_${user.id}');
    if (privJson == null) {
      throw Exception('Clé privée introuvable — générez vos clés RSA d\'abord.');
    }

    final receiverUid = _findUidByEmail(receiverEmail);
    if (receiverUid == null) throw Exception('Aucun utilisateur trouvé.');

    final receiverData = Map<String, dynamic>.from(_db.users.get(receiverUid) ?? {});
    final receiverPubJson = receiverData['rsaPublicKey'] as String?;
    if (receiverPubJson == null) {
      throw Exception('Le destinataire n\'a pas encore généré ses clés RSA.');
    }

    final certSerial = (Map<String, dynamic>.from(_db.users.get(user.id) ?? {}))['rsaCertSerial'] as String? ?? '';

    final privKey = RsaService.decodePrivateKey(privJson);
    final receiverPubKey = RsaService.decodePublicKey(receiverPubJson);

    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final signature = RsaService.sign(msgBytes, privKey);
    final sigB64 = base64Encode(signature);

    final aesKeyBytes = Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final aesKeyStr = base64Encode(aesKeyBytes);

    final payload = '$message|SIG|$sigB64';
    final encrypted = await CryptoAvance.encryptMessage(message: payload, key: aesKeyStr);

    final encAesKey = RsaService.encryptWithPublicKey(aesKeyBytes, receiverPubKey);

    // Stocker dans hive (box vpn_<receiverUid> pour que le destinataire puisse le voir)
    final box = await _db.messagesBox('vpn_$receiverUid');
    final msgId = _generateId();
    await box.put(msgId, {
      'id': msgId,
      'senderId': user.id,
      'senderEmail': user.email,
      'receiverId': receiverUid,
      'receiverEmail': receiverEmail.trim().toLowerCase(),
      'encryptedAesKey': base64Encode(encAesKey),
      'cipherText': encrypted.cipherText,
      'nonce': encrypted.nonce,
      'mac': encrypted.mac,
      'senderCertSerial': certSerial,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ─── Receive & Decrypt ────────────────────────────────────────────────────

  Stream<List<VpnMessage>> getInbox() async* {
    final user = await _getUser();
    final box = await _db.messagesBox('vpn_${user.id}');

    final msgs = box.values
        .map((m) => VpnMessage.fromMap(m['id'] ?? '', Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    yield msgs;
  }

  Future<VpnDecryptResult> decryptAndVerify(VpnMessage msg) async {
    final user = await _getUser();
    final prefs = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_${user.id}');
    if (privJson == null) throw Exception('Clé privée introuvable.');

    final privKey = RsaService.decodePrivateKey(privJson);
    final encAesKey = base64Decode(msg.encryptedAesKey);
    final aesKeyBytes = RsaService.decryptWithPrivateKey(encAesKey, privKey);
    final aesKeyStr = base64Encode(aesKeyBytes);

    final payload = await CryptoAvance.decryptMessage(
      cipherText: msg.cipherText, nonce: msg.nonce, mac: msg.mac, key: aesKeyStr,
    );

    const sep = '|SIG|';
    final sepIdx = payload.lastIndexOf(sep);
    if (sepIdx < 0) throw Exception('Format de paquet invalide.');
    final plainMessage = payload.substring(0, sepIdx);
    final sigB64 = payload.substring(sepIdx + sep.length);
    final signature = base64Decode(sigB64);

    final cert = await PkiService.getCertificate(msg.senderId);
    bool certValid = false, certRevoked = false;
    if (cert != null) {
      certValid = await PkiService.verifyCertificate(cert);
      certRevoked = await PkiService.isRevoked(cert.serialNumber);
    }

    bool sigValid = false;
    if (cert != null && certValid && !certRevoked) {
      final senderPubKey = RsaService.decodePublicKey(cert.publicKey);
      sigValid = RsaService.verify(Uint8List.fromList(utf8.encode(plainMessage)), signature, senderPubKey);
    }

    return VpnDecryptResult(
      message: plainMessage, signatureValid: sigValid,
      certificateValid: certValid, certRevoked: certRevoked,
      senderEmail: msg.senderEmail, senderCert: cert,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String? _findUidByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final entry in _db.users.toMap().entries) {
      if (entry.value['email'] == normalized) return entry.key as String;
    }
    return null;
  }

  Future<void> revokeMyCertificate() async {
    final user = await _getUser();
    final data = _db.users.get(user.id);
    final serial = data?['rsaCertSerial'] as String?;
    if (serial == null) throw Exception('Aucun certificat trouvé.');
    await PkiService.revokeCertificate(serial);
  }

  Future<void> revokeUserByEmail(String email) async {
    final uid = _findUidByEmail(email);
    if (uid == null) throw Exception('Utilisateur introuvable.');
    final cert = await PkiService.getCertificate(uid);
    if (cert == null) throw Exception('Certificat introuvable.');
    await PkiService.revokeCertificate(cert.serialNumber);
  }

  Future<List<String>> getCrl() => PkiService.getCrl();
}
