import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/certificate_model.dart';
import 'rsa_service.dart';

class PkiService {
  static final _firestore = FirebaseFirestore.instance;

  // ─── CA Management ────────────────────────────────────────────

  static Future<Map<String, String>> _getOrCreateCa() async {
    final caDoc = await _firestore.collection('pki').doc('ca').get();
    if (caDoc.exists) {
      final d = caDoc.data()!;
      return {'pub': d['publicKey'] as String, 'priv': d['privateKey'] as String};
    }
    final pair = RsaService.generateKeyPair();
    final pub = RsaService.encodePublicKey(pair.publicKey);
    final priv = RsaService.encodePrivateKey(pair.privateKey);
    await _firestore.collection('pki').doc('ca').set({
      'publicKey': pub,
      'privateKey': priv,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return {'pub': pub, 'priv': priv};
  }

  static Future<String> getCaPublicKey() async {
    final ca = await _getOrCreateCa();
    return ca['pub']!;
  }

  // ─── Certificate Issuance ─────────────────────────────────────

  static Future<CertificateData> issueCertificate({
    required String userEmail,
    required String userUid,
    required String userPublicKeyJson,
  }) async {
    final ca = await _getOrCreateCa();
    final caPrivKey = RsaService.decodePrivateKey(ca['priv']!);

    final now = DateTime.now().toUtc();
    final expiry = now.add(const Duration(days: 365));
    final serial = _generateSerial();

    final tbs = _buildTbs(
      serial: serial,
      subject: userEmail,
      subjectUid: userUid,
      notBefore: now.toIso8601String(),
      notAfter: expiry.toIso8601String(),
      publicKey: userPublicKeyJson,
    );

    final sig = RsaService.sign(Uint8List.fromList(utf8.encode(tbs)), caPrivKey);

    final cert = CertificateData(
      serialNumber: serial,
      issuer: 'CryptoAdv-CA',
      subject: userEmail,
      subjectUid: userUid,
      notBefore: now.toIso8601String(),
      notAfter: expiry.toIso8601String(),
      publicKey: userPublicKeyJson,
      signature: base64Encode(sig),
    );

    await _firestore
        .collection('pki')
        .doc('certificates')
        .collection('issued')
        .doc(userUid)
        .set(cert.toMap());

    return cert;
  }

  // ─── Certificate Verification ─────────────────────────────────

  static Future<bool> verifyCertificate(CertificateData cert) async {
    if (!cert.isTemporallyValid) return false;
    final caPubKeyJson = await getCaPublicKey();
    final caPubKey = RsaService.decodePublicKey(caPubKeyJson);
    final tbs = _buildTbs(
      serial: cert.serialNumber,
      subject: cert.subject,
      subjectUid: cert.subjectUid,
      notBefore: cert.notBefore,
      notAfter: cert.notAfter,
      publicKey: cert.publicKey,
    );
    return RsaService.verify(
      Uint8List.fromList(utf8.encode(tbs)),
      base64Decode(cert.signature),
      caPubKey,
    );
  }

  static Future<CertificateData?> getCertificate(String uid) async {
    final doc = await _firestore
        .collection('pki')
        .doc('certificates')
        .collection('issued')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return CertificateData.fromMap(doc.data()!);
  }

  // ─── CRL Management ───────────────────────────────────────────

  static Future<void> revokeCertificate(String serialNumber) async {
    await _firestore.collection('pki').doc('crl').set({
      'revoked': FieldValue.arrayUnion([serialNumber]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<bool> isRevoked(String serialNumber) async {
    final doc = await _firestore.collection('pki').doc('crl').get();
    if (!doc.exists) return false;
    final revoked = List<String>.from(doc.data()?['revoked'] ?? []);
    return revoked.contains(serialNumber);
  }

  static Future<List<String>> getCrl() async {
    final doc = await _firestore.collection('pki').doc('crl').get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['revoked'] ?? []);
  }

  // ─── Helpers ──────────────────────────────────────────────────

  // Deterministic TBS (To Be Signed) certificate JSON — field order is fixed
  static String _buildTbs({
    required String serial,
    required String subject,
    required String subjectUid,
    required String notBefore,
    required String notAfter,
    required String publicKey,
  }) {
    final map = <String, dynamic>{};
    map['version'] = 3;
    map['serialNumber'] = serial;
    map['issuer'] = 'CryptoAdv-CA';
    map['subject'] = subject;
    map['subjectUid'] = subjectUid;
    map['notBefore'] = notBefore;
    map['notAfter'] = notAfter;
    map['publicKey'] = publicKey;
    return jsonEncode(map);
  }

  static String _generateSerial() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}