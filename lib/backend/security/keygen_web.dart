// ignore_for_file: uri_does_not_exist
import 'dart:convert';
import 'dart:math';
import 'dart:js_util' as js_util; // ignore: uri_does_not_exist
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Sur web : utilise window.crypto.subtle si disponible (HTTPS),
/// sinon fallback PointyCastle (HTTP — contexte non sécurisé).
Future<Map<String, String>> generateKeyPairPlatform() async {
  // crypto.subtle n'est disponible qu'en contexte sécurisé (HTTPS / localhost).
  // Sur HTTP, subtle est null → on utilise PointyCastle en fallback.
  final crypto = js_util.getProperty<Object?>(js_util.globalThis, 'crypto');
  final subtle = crypto != null
      ? js_util.getProperty<Object?>(crypto, 'subtle')
      : null;

  if (subtle == null) {
    return _generateWithPointyCastle();
  }

  // Paramètres RSA-OAEP 2048 bits
  final algorithm = js_util.jsify({
    'name': 'RSA-OAEP',
    'modulusLength': 2048,
    'publicExponent': Uint8List.fromList([1, 0, 1]), // 65537
    'hash': 'SHA-256',
  });

  // generateKey → Promise → Future (non-bloquant)
  final keyPair = await js_util.promiseToFuture<Object>(
    js_util.callMethod(subtle!, 'generateKey', [
      algorithm,
      true,
      js_util.jsify(['encrypt', 'decrypt']),
    ]),
  );

  final publicKey  = js_util.getProperty<Object>(keyPair, 'publicKey');
  final privateKey = js_util.getProperty<Object>(keyPair, 'privateKey');

  // Exporter en JWK (JSON Web Key)
  final pubJwk = await js_util.promiseToFuture<Object>(
    js_util.callMethod(subtle!, 'exportKey', ['jwk', publicKey]),
  );
  final privJwk = await js_util.promiseToFuture<Object>(
    js_util.callMethod(subtle, 'exportKey', ['jwk', privateKey]),
  );

  // Convertit base64url → hex (format de stockage de RsaService)
  String b64urlToHex(String b64url) {
    var b64 = b64url.replaceAll('-', '+').replaceAll('_', '/');
    final rem = b64.length % 4;
    if (rem != 0) b64 += '=' * (4 - rem);
    return base64Decode(b64)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // js_util.getProperty can return null across the JS boundary even when typed as String
  String getRequired(Object obj, String key) {
    final v = js_util.getProperty<Object?>(obj, key);
    if (v == null) throw Exception('JWK missing required field: $key');
    return v.toString();
  }

  return {
    'pub': jsonEncode({
      'n': b64urlToHex(getRequired(pubJwk,  'n')),
      'e': b64urlToHex(getRequired(pubJwk,  'e')),
    }),
    'priv': jsonEncode({
      'n': b64urlToHex(getRequired(privJwk, 'n')),
      'd': b64urlToHex(getRequired(privJwk, 'd')),
      'p': b64urlToHex(getRequired(privJwk, 'p')),
      'q': b64urlToHex(getRequired(privJwk, 'q')),
    }),
  };
}

/// Fallback PointyCastle — utilisé quand crypto.subtle n'est pas disponible
/// (contexte non sécurisé : HTTP sans localhost).
Map<String, String> _generateWithPointyCastle() {
  final rng = FortunaRandom();
  final seed = Uint8List.fromList(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  );
  rng.seed(KeyParameter(seed));

  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      rng,
    ));

  final pair     = keyGen.generateKeyPair();
  final pubKey   = pair.publicKey  as RSAPublicKey;
  final privKey  = pair.privateKey as RSAPrivateKey;

  return {
    'pub': jsonEncode({
      'n': pubKey.modulus!.toRadixString(16),
      'e': pubKey.exponent!.toRadixString(16),
    }),
    'priv': jsonEncode({
      'n': privKey.modulus!.toRadixString(16),
      'd': privKey.privateExponent!.toRadixString(16),
      'p': privKey.p!.toRadixString(16),
      'q': privKey.q!.toRadixString(16),
    }),
  };
}