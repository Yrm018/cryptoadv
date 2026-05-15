// Import Firestore supprimé — DateTime standard + ISO 8601
class VpnMessage {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String receiverEmail;
  final String encryptedAesKey;
  final String cipherText;
  final String nonce;
  final String mac;
  final String senderCertSerial;
  final DateTime? timestamp;

  const VpnMessage({
    required this.id, required this.senderId, required this.senderEmail,
    required this.receiverId, required this.receiverEmail,
    required this.encryptedAesKey, required this.cipherText,
    required this.nonce, required this.mac,
    required this.senderCertSerial, required this.timestamp,
  });

  factory VpnMessage.fromMap(String id, Map<String, dynamic> m) {
    final ts = m['timestamp'];
    return VpnMessage(
      id: id, senderId: m['senderId'] ?? '', senderEmail: m['senderEmail'] ?? '',
      receiverId: m['receiverId'] ?? '', receiverEmail: m['receiverEmail'] ?? '',
      encryptedAesKey: m['encryptedAesKey'] ?? '', cipherText: m['cipherText'] ?? '',
      nonce: m['nonce'] ?? '', mac: m['mac'] ?? '',
      senderCertSerial: m['senderCertSerial'] ?? '',
      timestamp: ts is String ? DateTime.tryParse(ts) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId, 'senderEmail': senderEmail,
    'receiverId': receiverId, 'receiverEmail': receiverEmail,
    'encryptedAesKey': encryptedAesKey, 'cipherText': cipherText,
    'nonce': nonce, 'mac': mac, 'senderCertSerial': senderCertSerial,
    'timestamp': timestamp?.toIso8601String(),
  };
}
