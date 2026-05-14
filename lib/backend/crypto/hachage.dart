import 'dart:convert';
import 'package:crypto/crypto.dart';

String hashMessage(String message, {String algorithm = 'sha256'}) {
  final bytes = utf8.encode(message);
  return hashBytes(bytes, algorithm: algorithm);
}

String hashBytes(List<int> bytes, {String algorithm = 'sha256'}) {
  switch (algorithm.toLowerCase()) {
    case 'md5':
      return md5.convert(bytes).toString();
    case 'sha1':
      return sha1.convert(bytes).toString();
    case 'sha224':
      return sha224.convert(bytes).toString();
    case 'sha256':
      return sha256.convert(bytes).toString();
    case 'sha384':
      return sha384.convert(bytes).toString();
    case 'sha512':
      return sha512.convert(bytes).toString();
    default:
      throw ArgumentError('Algorithme non supporté : $algorithm');
  }
}