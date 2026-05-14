import 'package:cloud_firestore/cloud_firestore.dart';

class VpnMessage {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String receiverEmail;
  final String encryptedAesKey; // AES-256 key encrypted with receiver's RSA public key
  final String cipherText;      // AES-GCM ciphertext of [message|SIG|base64sig]
  final String nonce;
  final String mac;
  final String senderCertSerial;
  final DateTime? timestamp;

  const VpnMessage({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.receiverEmail,
    required this.encryptedAesKey,
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.senderCertSerial,
    required this.timestamp,
  });

  factory VpnMessage.fromMap(String id, Map<String, dynamic> m) {
    final ts = m['timestamp'];
    return VpnMessage(
      id: id,
      senderId: m['senderId'] ?? '',
      senderEmail: m['senderEmail'] ?? '',
      receiverId: m['receiverId'] ?? '',
      receiverEmail: m['receiverEmail'] ?? '',
      encryptedAesKey: m['encryptedAesKey'] ?? '',
      cipherText: m['cipherText'] ?? '',
      nonce: m['nonce'] ?? '',
      mac: m['mac'] ?? '',
      senderCertSerial: m['senderCertSerial'] ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderEmail': senderEmail,
        'receiverId': receiverId,
        'receiverEmail': receiverEmail,
        'encryptedAesKey': encryptedAesKey,
        'cipherText': cipherText,
        'nonce': nonce,
        'mac': mac,
        'senderCertSerial': senderCertSerial,
        'timestamp': FieldValue.serverTimestamp(),
      };
}