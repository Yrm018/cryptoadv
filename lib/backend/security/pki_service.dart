import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/certificate_model.dart';
import 'rsa_service.dart';
import 'keygen.dart';

/// PkiService — autorité de certification locale (hive).
/// La CA (clé + certs + CRL) est stockée dans un box hive dédié.
class PkiService {
  static const _pkiBoxName = 'pki';

  static Future<Box<Map>> get _box async {
    if (!Hive.isBoxOpen(_pkiBoxName)) {
      await Hive.openBox<Map>(_pkiBoxName);
    }
    return Hive.box<Map>(_pkiBoxName);
  }

  // ─── CA Management ────────────────────────────────────────────────────────

  static Future<Map<String, String>> _getOrCreateCa() async {
    final box = await _box;
    final existing = box.get('ca');
    if (existing != null) {
      final pub  = existing['publicKey']?.toString();
      final priv = existing['privateKey']?.toString();
      if (pub != null && priv != null) {
        return {'pub': pub, 'priv': priv};
      }
      // Corrupted CA entry — regenerate
      await box.delete('ca');
    }
    // Use platform key generation (Web Crypto on web, isolate on native)
    // to avoid blocking the JS event loop with synchronous PointyCastle crypto.
    final keys = await generateKeyPairPlatform();
    final pub  = keys['pub']!;
    final priv = keys['priv']!;
    await box.put('ca', {'publicKey': pub, 'privateKey': priv});
    return {'pub': pub, 'priv': priv};
  }

  static Future<String> getCaPublicKey() async {
    final ca = await _getOrCreateCa();
    return ca['pub']!;
  }

  // ─── Certificate Issuance ─────────────────────────────────────────────────

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
      serial: serial, subject: userEmail, subjectUid: userUid,
      notBefore: now.toIso8601String(), notAfter: expiry.toIso8601String(),
      publicKey: userPublicKeyJson,
    );

    final sig = RsaService.sign(Uint8List.fromList(utf8.encode(tbs)), caPrivKey);

    final cert = CertificateData(
      serialNumber: serial, issuer: 'CryptoAdv-CA', subject: userEmail,
      subjectUid: userUid, notBefore: now.toIso8601String(),
      notAfter: expiry.toIso8601String(), publicKey: userPublicKeyJson,
      signature: base64Encode(sig),
    );

    final box = await _box;
    await box.put('cert_$userUid', cert.toMap());
    return cert;
  }

  // ─── Certificate Verification ─────────────────────────────────────────────

  static Future<bool> verifyCertificate(CertificateData cert) async {
    if (!cert.isTemporallyValid) return false;
    final caPubKeyJson = await getCaPublicKey();
    final caPubKey = RsaService.decodePublicKey(caPubKeyJson);
    final tbs = _buildTbs(
      serial: cert.serialNumber, subject: cert.subject, subjectUid: cert.subjectUid,
      notBefore: cert.notBefore, notAfter: cert.notAfter, publicKey: cert.publicKey,
    );
    return RsaService.verify(
      Uint8List.fromList(utf8.encode(tbs)), base64Decode(cert.signature), caPubKey,
    );
  }

  static Future<CertificateData?> getCertificate(String uid) async {
    final box = await _box;
    final data = box.get('cert_$uid');
    if (data == null) return null;
    return CertificateData.fromMap(Map<String, dynamic>.from(data));
  }

  // ─── CRL Management ───────────────────────────────────────────────────────

  static Future<void> revokeCertificate(String serialNumber) async {
    final box = await _box;
    final crl = List<String>.from(box.get('crl')?['revoked'] ?? []);
    if (!crl.contains(serialNumber)) crl.add(serialNumber);
    await box.put('crl', {'revoked': crl});
  }

  static Future<bool> isRevoked(String serialNumber) async {
    final box = await _box;
    final crl = List<String>.from(box.get('crl')?['revoked'] ?? []);
    return crl.contains(serialNumber);
  }

  static Future<List<String>> getCrl() async {
    final box = await _box;
    return List<String>.from(box.get('crl')?['revoked'] ?? []);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _buildTbs({
    required String serial, required String subject, required String subjectUid,
    required String notBefore, required String notAfter, required String publicKey,
  }) {
    return jsonEncode({
      'version': 3, 'serialNumber': serial, 'issuer': 'CryptoAdv-CA',
      'subject': subject, 'subjectUid': subjectUid,
      'notBefore': notBefore, 'notAfter': notAfter, 'publicKey': publicKey,
    });
  }

  static String _generateSerial() {
    final rand = Random.secure();
    return List.generate(16, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
