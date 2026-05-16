import 'package:flutter/foundation.dart';
import 'rsa_service.dart';

/// Sur mobile/desktop : génération dans un isolate séparé (ne bloque pas l'UI).
Future<Map<String, String>> generateKeyPairPlatform() =>
    compute(generateKeyPairIsolated, 2048);