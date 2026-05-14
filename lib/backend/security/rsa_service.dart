import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class RsaService {
  static SecureRandom _buildSecureRandom() {
    final rng = FortunaRandom();
    final seed = Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    rng.seed(KeyParameter(seed));
    return rng;
  }

  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _buildSecureRandom(),
      ));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static String encodePublicKey(RSAPublicKey key) => jsonEncode({
        'n': key.modulus!.toRadixString(16),
        'e': key.exponent!.toRadixString(16),
      });

  static String encodePrivateKey(RSAPrivateKey key) => jsonEncode({
        'n': key.modulus!.toRadixString(16),
        'd': key.privateExponent!.toRadixString(16),
        'p': key.p!.toRadixString(16),
        'q': key.q!.toRadixString(16),
      });

  static RSAPublicKey decodePublicKey(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return RSAPublicKey(
      BigInt.parse(m['n'] as String, radix: 16),
      BigInt.parse(m['e'] as String, radix: 16),
    );
  }

  static RSAPrivateKey decodePrivateKey(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final n = BigInt.parse(m['n'] as String, radix: 16);
    final d = BigInt.parse(m['d'] as String, radix: 16);
    final p = BigInt.parse(m['p'] as String, radix: 16);
    final q = BigInt.parse(m['q'] as String, radix: 16);
    return RSAPrivateKey(n, d, p, q);
  }

  // RSA-OAEP-SHA256: encrypt AES key (32 bytes) with receiver's public key
  static Uint8List encryptWithPublicKey(Uint8List data, RSAPublicKey key) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(key));
    return cipher.process(data);
  }

  // RSA-OAEP-SHA256: decrypt AES key with own private key
  static Uint8List decryptWithPrivateKey(Uint8List data, RSAPrivateKey key) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(key));
    return cipher.process(data);
  }

  // SHA256withRSA PKCS1v15 signature
  static Uint8List sign(Uint8List data, RSAPrivateKey key) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(key));
    // RSASigner.generateSignature returns RSASignature at runtime
    final sig = signer.generateSignature(data);
    return (sig as dynamic).bytes as Uint8List;
  }

  static bool verify(Uint8List data, Uint8List signature, RSAPublicKey key) {
    try {
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(key));
      return signer.verifySignature(data, RSASignature(signature));
    } catch (_) {
      return false;
    }
  }

  static String fingerprint(String publicKeyJson) {
    final bytes = utf8.encode(publicKeyJson);
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0').toUpperCase();
  }
}

// Top-level for compute()
Map<String, String> generateKeyPairIsolated(int _) {
  final pair = RsaService.generateKeyPair();
  return {
    'pub': RsaService.encodePublicKey(pair.publicKey),
    'priv': RsaService.encodePrivateKey(pair.privateKey),
  };
}
