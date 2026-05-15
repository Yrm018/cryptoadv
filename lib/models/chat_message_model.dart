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

  /// 'symmetric' (AES-GCM / ChaCha20 avec clé auto) ou 'asymmetric' (RSA+AES)
  final String encryptionMode;

  /// Clé AES chiffrée RSA — uniquement pour le mode asymétrique
  final String encryptedAesKey;

  /// Texte clair conservé côté expéditeur pour l'affichage des messages asymétriques envoyés
  final String senderPlainText;

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
    this.encryptionMode   = 'symmetric',
    this.encryptedAesKey  = '',
    this.senderPlainText  = '',
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['createdAt'];
    DateTime? createdAt;
    if (raw is String)   createdAt = DateTime.tryParse(raw);
    if (raw is DateTime) createdAt = raw;

    return ChatMessageModel(
      id:              id,
      conversationId:  map['conversationId']  ?? '',
      senderId:        map['senderId']        ?? '',
      senderEmail:     map['senderEmail']     ?? '',
      senderName:      map['senderName']      ?? '',
      receiverId:      map['receiverId']      ?? '',
      receiverEmail:   map['receiverEmail']   ?? '',
      receiverName:    map['receiverName']    ?? '',
      cipherText:      map['cipherText']      ?? '',
      nonce:           map['nonce']           ?? '',
      mac:             map['mac']             ?? '',
      algorithm:       map['algorithm']       ?? 'aes-gcm',
      createdAt:       createdAt,
      encryptionMode:  map['encryptionMode']  ?? 'symmetric',
      encryptedAesKey: map['encryptedAesKey'] ?? '',
      senderPlainText: map['senderPlainText'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'conversationId':  conversationId,
    'senderId':        senderId,
    'senderEmail':     senderEmail,
    'senderName':      senderName,
    'receiverId':      receiverId,
    'receiverEmail':   receiverEmail,
    'receiverName':    receiverName,
    'cipherText':      cipherText,
    'nonce':           nonce,
    'mac':             mac,
    'algorithm':       algorithm,
    'createdAt':       createdAt?.toIso8601String(),
    'encryptionMode':  encryptionMode,
    'encryptedAesKey': encryptedAesKey,
    'senderPlainText': senderPlainText,
  };
}
