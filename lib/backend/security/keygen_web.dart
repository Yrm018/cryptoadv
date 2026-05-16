// ignore_for_file: uri_does_not_exist
import 'dart:convert';
import 'dart:js_util' as js_util; // ignore: uri_does_not_exist
import 'dart:typed_data';

/// Sur web : utilise window.crypto.subtle.generateKey() — non-bloquant,
/// rapide (~100ms) et natif au navigateur. Aucun freeze de l'UI.
Future<Map<String, String>> generateKeyPairPlatform() async {
  final crypto = js_util.getProperty<Object>(js_util.globalThis, 'crypto');
  final subtle = js_util.getProperty<Object>(crypto, 'subtle');

  // Paramètres RSA-OAEP 2048 bits
  final algorithm = js_util.jsify({
    'name': 'RSA-OAEP',
    'modulusLength': 2048,
    'publicExponent': Uint8List.fromList([1, 0, 1]), // 65537
    'hash': 'SHA-256',
  });

  // generateKey → Promise → Future (non-bloquant)
  final keyPair = await js_util.promiseToFuture<Object>(
    js_util.callMethod(subtle, 'generateKey', [
      algorithm,
      true,
      js_util.jsify(['encrypt', 'decrypt']),
    ]),
  );

  final publicKey  = js_util.getProperty<Object>(keyPair, 'publicKey');
  final privateKey = js_util.getProperty<Object>(keyPair, 'privateKey');

  // Exporter en JWK (JSON Web Key)
  final pubJwk = await js_util.promiseToFuture<Object>(
    js_util.callMethod(subtle, 'exportKey', ['jwk', publicKey]),
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

  String get(Object obj, String key) => js_util.getProperty<String>(obj, key);

  return {
    'pub': jsonEncode({
      'n': b64urlToHex(get(pubJwk,  'n')),
      'e': b64urlToHex(get(pubJwk,  'e')),
    }),
    'priv': jsonEncode({
      'n': b64urlToHex(get(privJwk, 'n')),
      'd': b64urlToHex(get(privJwk, 'd')),
      'p': b64urlToHex(get(privJwk, 'p')),
      'q': b64urlToHex(get(privJwk, 'q')),
    }),
  };
}