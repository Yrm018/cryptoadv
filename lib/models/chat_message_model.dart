// Import Firestore supprimé — on utilise DateTime standard partout
class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String receiverId;
  final String receiverEmail;
  final String receiverName;
  final String cipherText;
  final String nonce;
  final String mac;
  final String algorithm;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderEmail,
    required this.senderName,
    required this.receiverId,
    required this.receiverEmail,
    required this.receiverName,
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.algorithm,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    // Plus de Timestamp Firestore — createdAt est maintenant un String ISO 8601
    final raw = map['createdAt'];
    DateTime? createdAt;
    if (raw is String) createdAt = DateTime.tryParse(raw);
    if (raw is DateTime) createdAt = raw;

    return ChatMessageModel(
      id: id,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderName: map['senderName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverEmail: map['receiverEmail'] ?? '',
      receiverName: map['receiverName'] ?? '',
      cipherText: map['cipherText'] ?? '',
      nonce: map['nonce'] ?? '',
      mac: map['mac'] ?? '',
      algorithm: map['algorithm'] ?? 'aes-gcm',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'conversationId': conversationId,
    'senderId': senderId,
    'senderEmail': senderEmail,
    'senderName': senderName,
    'receiverId': receiverId,
    'receiverEmail': receiverEmail,
    'receiverName': receiverName,
    'cipherText': cipherText,
    'nonce': nonce,
    'mac': mac,
    'algorithm': algorithm,
    'createdAt': createdAt?.toIso8601String(),
  };

  ChatMessageModel copyWith({
    String? id, String? conversationId, String? senderId, String? senderEmail,
    String? senderName, String? receiverId, String? receiverEmail, String? receiverName,
    String? cipherText, String? nonce, String? mac, String? algorithm, DateTime? createdAt,
  }) => ChatMessageModel(
    id: id ?? this.id, conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId, senderEmail: senderEmail ?? this.senderEmail,
    senderName: senderName ?? this.senderName, receiverId: receiverId ?? this.receiverId,
    receiverEmail: receiverEmail ?? this.receiverEmail, receiverName: receiverName ?? this.receiverName,
    cipherText: cipherText ?? this.cipherText, nonce: nonce ?? this.nonce,
    mac: mac ?? this.mac, algorithm: algorithm ?? this.algorithm, createdAt: createdAt ?? this.createdAt,
  );
}
