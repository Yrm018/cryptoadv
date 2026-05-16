/// Point d'entrée unique pour la génération de clés RSA.
/// - Web    → keygen_web.dart  (window.crypto.subtle, non-bloquant)
/// - Native → keygen_native.dart (PointyCastle dans un isolate)
export 'keygen_stub.dart'
    if (dart.library.html) 'keygen_web.dart'
    if (dart.library.io)   'keygen_native.dart';