import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class EncryptedPayload {
  final String cipherText;
  final String nonce;
  final String mac;
  final String algorithm;

  const EncryptedPayload({
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.algorithm,
  });

  Map<String, dynamic> toMap() {
    return {
      'cipherText': cipherText,
      'nonce': nonce,
      'mac': mac,
      'algorithm': algorithm,
    };
  }

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedPayload(
      cipherText: map['cipherText'] ?? '',
      nonce: map['nonce'] ?? '',
      mac: map['mac'] ?? '',
      algorithm: map['algorithm'] ?? 'aes-gcm',
    );
  }
}

class CryptoAvance {
  static final Cipher _aesGcm = AesGcm.with256bits();
  static final Cipher _chacha20 = Chacha20.poly1305Aead();

  static List<int> _normalizeKey(String key) {
    final keyBytes = utf8.encode(key);

    if (keyBytes.length == 32) {
      return keyBytes;
    }

    if (keyBytes.length > 32) {
      return keyBytes.sublist(0, 32);
    }

    final padded = List<int>.from(keyBytes);
    while (padded.length < 32) {
      padded.add(0);
    }
    return padded;
  }

  static List<int> generateNonce() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256));
  }

  static Cipher _getCipher(String algorithm) {
    switch (algorithm) {
      case 'chacha20':
        return _chacha20;
      case 'aes-gcm':
      default:
        return _aesGcm;
    }
  }

  static Future<EncryptedPayload> encryptMessage({
    required String message,
    required String key,
    String algorithm = 'aes-gcm',
  }) async {
    final cipher = _getCipher(algorithm);
    final secretKey = SecretKey(_normalizeKey(key));
    final nonce = generateNonce();

    final secretBox = await cipher.encrypt(
      utf8.encode(message),
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedPayload(
      cipherText: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
      algorithm: algorithm,
    );
  }

  static Future<String> decryptMessage({
    required String cipherText,
    required String nonce,
    required String mac,
    required String key,
    String algorithm = 'aes-gcm',
  }) async {
    final cipher = _getCipher(algorithm);
    final secretKey = SecretKey(_normalizeKey(key));

    final secretBox = SecretBox(
      base64Decode(cipherText),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );

    final clearBytes = await cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearBytes);
  }
}