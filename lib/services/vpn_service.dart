import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/crypto/cryptavance.dart';
import '../backend/security/rsa_service.dart';
import '../backend/security/pki_service.dart';
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
    required this.message,
    required this.signatureValid,
    required this.certificateValid,
    required this.certRevoked,
    required this.senderEmail,
    required this.senderCert,
  });
}

class VpnService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  String get _email => (_auth.currentUser!.email ?? '').trim().toLowerCase();

  // ─── Key & Certificate Management ─────────────────────────────

  Future<bool> hasKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('rsa_priv_$_uid');
  }

  Future<void> generateAndRegisterKeys() async {
    // Heavy computation: run in isolate to avoid blocking UI
    final keys = await compute(generateKeyPairIsolated, 2048);
    final pubJson = keys['pub']!;
    final privJson = keys['priv']!;

    // Store private key locally (never sent to server)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rsa_priv_$_uid', privJson);

    // Publish public key in Firestore
    await _firestore.collection('users').doc(_uid).set(
      {'rsaPublicKey': pubJson},
      SetOptions(merge: true),
    );

    // Request certificate from CA
    final cert = await PkiService.issueCertificate(
      userEmail: _email,
      userUid: _uid,
      userPublicKeyJson: pubJson,
    );

    await _firestore.collection('users').doc(_uid).set(
      {'rsaCertSerial': cert.serialNumber},
      SetOptions(merge: true),
    );
  }

  Future<CertificateData?> getMyCertificate() => PkiService.getCertificate(_uid);

  Future<String?> getMyPublicKey() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    return doc.data()?['rsaPublicKey'] as String?;
  }

  // ─── Send Message (Alice flow) ────────────────────────────────

  Future<void> sendMessage({
    required String receiverEmail,
    required String message,
  }) async {
    // Get our private key
    final prefs = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_$_uid');
    if (privJson == null) {
      throw Exception('Clé privée introuvable — générez vos clés RSA d\'abord.');
    }

    // Find receiver
    final receiverUid = await _findUidByEmail(receiverEmail);
    if (receiverUid == null) {
      throw Exception('Aucun utilisateur trouvé avec cet email.');
    }
    final receiverPubJson = await _getPublicKeyForUser(receiverUid);
    if (receiverPubJson == null) {
      throw Exception('Le destinataire n\'a pas encore généré ses clés RSA.');
    }

    // Get our cert serial for CRL checking by receiver
    final senderDoc = await _firestore.collection('users').doc(_uid).get();
    final certSerial = (senderDoc.data()?['rsaCertSerial'] as String?) ?? '';

    final privKey = RsaService.decodePrivateKey(privJson);
    final receiverPubKey = RsaService.decodePublicKey(receiverPubJson);

    // Step 1 — Sign the message with our RSA private key
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final signature = RsaService.sign(msgBytes, privKey);
    final sigB64 = base64Encode(signature);

    // Step 2 — Generate random AES-256 key
    final aesKeyBytes = Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final aesKeyStr = base64Encode(aesKeyBytes);

    // Step 3 — AES-GCM encrypt [message|SIG|signature]
    final payload = '$message|SIG|$sigB64';
    final encrypted = await CryptoAvance.encryptMessage(
      message: payload,
      key: aesKeyStr,
    );

    // Step 4 — RSA-OAEP encrypt the AES key with receiver's public key
    final encAesKey = RsaService.encryptWithPublicKey(aesKeyBytes, receiverPubKey);

    // Step 5 — Deposit packet in VPN channel (Firestore)
    final vpnMsg = VpnMessage(
      id: '',
      senderId: _uid,
      senderEmail: _email,
      receiverId: receiverUid,
      receiverEmail: receiverEmail.trim().toLowerCase(),
      encryptedAesKey: base64Encode(encAesKey),
      cipherText: encrypted.cipherText,
      nonce: encrypted.nonce,
      mac: encrypted.mac,
      senderCertSerial: certSerial,
      timestamp: null,
    );
    await _firestore.collection('vpn_messages').add(vpnMsg.toMap());
  }

  // ─── Receive & Decrypt (Bob flow) ─────────────────────────────

  Stream<List<VpnMessage>> getInbox() {
    return _firestore
        .collection('vpn_messages')
        .where('receiverId', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final msgs =
          snap.docs.map((d) => VpnMessage.fromMap(d.id, d.data())).toList();
      msgs.sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      return msgs;
    });
  }

  Future<VpnDecryptResult> decryptAndVerify(VpnMessage msg) async {
    // Step 1 — Get our private key
    final prefs = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_$_uid');
    if (privJson == null) throw Exception('Clé privée introuvable.');
    final privKey = RsaService.decodePrivateKey(privJson);

    // Step 2 — RSA-OAEP decrypt the AES key
    final encAesKey = base64Decode(msg.encryptedAesKey);
    final aesKeyBytes = RsaService.decryptWithPrivateKey(encAesKey, privKey);
    final aesKeyStr = base64Encode(aesKeyBytes);

    // Step 3 — AES-GCM decrypt the payload
    final payload = await CryptoAvance.decryptMessage(
      cipherText: msg.cipherText,
      nonce: msg.nonce,
      mac: msg.mac,
      key: aesKeyStr,
    );

    // Step 4 — Split message and signature
    const sep = '|SIG|';
    final sepIdx = payload.lastIndexOf(sep);
    if (sepIdx < 0) throw Exception('Format de paquet invalide.');
    final plainMessage = payload.substring(0, sepIdx);
    final sigB64 = payload.substring(sepIdx + sep.length);
    final signature = base64Decode(sigB64);

    // Step 5 — Verify sender's certificate (via CA)
    final cert = await PkiService.getCertificate(msg.senderId);
    bool certValid = false;
    bool certRevoked = false;

    if (cert != null) {
      certValid = await PkiService.verifyCertificate(cert);
      certRevoked = await PkiService.isRevoked(cert.serialNumber);
    }

    // Step 6 — Verify digital signature with sender's public key (from cert)
    bool sigValid = false;
    if (cert != null && certValid && !certRevoked) {
      final senderPubKey = RsaService.decodePublicKey(cert.publicKey);
      final msgBytes = Uint8List.fromList(utf8.encode(plainMessage));
      sigValid = RsaService.verify(msgBytes, signature, senderPubKey);
    }

    return VpnDecryptResult(
      message: plainMessage,
      signatureValid: sigValid,
      certificateValid: certValid,
      certRevoked: certRevoked,
      senderEmail: msg.senderEmail,
      senderCert: cert,
    );
  }

  // ─── Security Tests ───────────────────────────────────────────

  Future<void> revokeMyCertificate() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    final serial = doc.data()?['rsaCertSerial'] as String?;
    if (serial == null) throw Exception('Aucun certificat trouvé.');
    await PkiService.revokeCertificate(serial);
  }

  Future<void> revokeUserByEmail(String email) async {
    final uid = await _findUidByEmail(email);
    if (uid == null) throw Exception('Utilisateur introuvable.');
    final cert = await PkiService.getCertificate(uid);
    if (cert == null) throw Exception('Certificat introuvable pour cet utilisateur.');
    await PkiService.revokeCertificate(cert.serialNumber);
  }

  Future<List<String>> getCrl() => PkiService.getCrl();

  // ─── Helpers ──────────────────────────────────────────────────

  Future<String?> _findUidByEmail(String email) async {
    final result = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    return result.docs.first.id;
  }

  Future<String?> _getPublicKeyForUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['rsaPublicKey'] as String?;
  }
}