class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String receiverId;
  final String receiverEmail;
  final String receiverName;
  final String cipherText; // Contient le texte ou le base64 du fichier chiffré
  final String nonce;
  final String mac;
  final String algorithm;
  final DateTime? createdAt;

  final String encryptionMode;
  final String encryptedAesKey;
  final String senderPlainText;

  // Nouveaux champs pour les fichiers
  final String type; // 'text', 'image', 'video', 'file'
  final String? fileName;
  final int? fileSize;

  /// Date à laquelle le destinataire a lu le message (null = non lu)
  final DateTime? readAt;

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
    this.encryptionMode = 'symmetric',
    this.encryptedAesKey = '',
    this.senderPlainText = '',
    this.type = 'text',
    this.fileName,
    this.fileSize,
    this.readAt,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['createdAt'];
    DateTime? createdAt;
    if (raw is String) createdAt = DateTime.tryParse(raw);
    if (raw is DateTime) createdAt = raw;

    final rawRead = map['readAt'];
    DateTime? readAt;
    if (rawRead is String) readAt = DateTime.tryParse(rawRead);
    if (rawRead is DateTime) readAt = rawRead;

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
      encryptionMode: map['encryptionMode'] ?? 'symmetric',
      encryptedAesKey: map['encryptedAesKey'] ?? '',
      senderPlainText: map['senderPlainText'] ?? '',
      type: map['type'] ?? 'text',
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      readAt: readAt,
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
        'encryptionMode': encryptionMode,
        'encryptedAesKey': encryptedAesKey,
        'senderPlainText': senderPlainText,
        'type': type,
        'fileName': fileName,
        'fileSize': fileSize,
        'readAt': readAt?.toIso8601String(),
      };
}
