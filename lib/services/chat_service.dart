import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../backend/crypto/cryptavance.dart'; // adapte le chemin si besoin

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('messages');

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getUserByEmail(
      String email,
      ) async {
    final normalizedEmail = email.trim().toLowerCase();

    final result = await _users
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return null;
    return result.docs.first;
  }

  String _buildConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _algoLabel(String algorithm) {
    switch (algorithm) {
      case 'chacha20':
        return 'ChaCha20-Poly1305';
      case 'aes-gcm':
      default:
        return 'AES-GCM';
    }
  }

  Future<String> getOrCreateConversation(
      String otherUserId,
      String otherUserEmail,
      ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("Utilisateur non connecté");
    }

    final conversationId = _buildConversationId(currentUser.uid, otherUserId);
    final conversationRef = _conversations.doc(conversationId);

    final existing = await conversationRef.get();
    if (existing.exists) {
      return conversationId;
    }

    final otherUserDoc = await _users.doc(otherUserId).get();
    final otherUserData = otherUserDoc.data();

    final currentEmail = (currentUser.email ?? '').trim().toLowerCase();
    final currentName =
    (currentUser.displayName ?? currentUser.email ?? 'Utilisateur').trim();

    final receiverEmail =
    (otherUserData?['email'] ?? otherUserEmail).toString().trim().toLowerCase();
    final receiverName =
    (otherUserData?['displayName'] ?? otherUserData?['name'] ?? otherUserEmail)
        .toString()
        .trim();

    final participantIds = [currentUser.uid, otherUserId];
    final participantEmails = [currentEmail, receiverEmail];
    final participantNames = [currentName, receiverName];

    await conversationRef.set({
      'participants': [currentUser.uid, otherUserId],
      'participantEmails': [currentEmail, receiverEmail],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': 'Conversation sécurisée',
      'type': 'direct',
    });

    return conversationId;
  }

  Stream<List<Map<String, dynamic>>> getRecentConversations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _conversations
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        final participants =
        List<String>.from(data['participants'] ?? const []);
        final participantEmails =
        List<String>.from(data['participantEmails'] ?? const []);

        int otherIndex =
        participants.indexWhere((id) => id != currentUser.uid);

        if (otherIndex < 0) {
          otherIndex = 0;
        }

        final email = participantEmails.length > otherIndex
            ? participantEmails[otherIndex]
            : 'Utilisateur';

        return {
          'conversationId': doc.id,
          'email': email,
          'name': email,
          'lastMessage': data['lastMessagePreview'] ?? 'Conversation sécurisée',
          'updatedAt': data['lastMessageAt'],
        };
      }).toList();
    });
  }
  Stream<List<ChatMessageModel>> getMessages(String conversationId) {
    return _messages
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> sendMessageToEmail({
    required String receiverEmail,
    required String text,
    required String encryptionKey,
    required String algorithm,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("Utilisateur non connecté");
    }

    final normalizedReceiverEmail = receiverEmail.trim().toLowerCase();
    final userDoc = await getUserByEmail(normalizedReceiverEmail);

    if (userDoc == null) {
      throw Exception("Aucun utilisateur trouvé avec cet email");
    }

    if (userDoc.id == currentUser.uid) {
      throw Exception("Tu ne peux pas t'envoyer un message à toi-même");
    }

    final receiverData = userDoc.data();
    final receiverId = userDoc.id;
    final receiverName =
    (receiverData['displayName'] ?? receiverData['name'] ?? normalizedReceiverEmail)
        .toString()
        .trim();

    final senderEmail = (currentUser.email ?? '').trim().toLowerCase();
    final senderName =
    (currentUser.displayName ?? currentUser.email ?? 'Utilisateur').trim();

    final conversationId = await getOrCreateConversation(
      receiverId,
      normalizedReceiverEmail,
    );

    final payload = await CryptoAvance.encryptMessage(
      message: text,
      key: encryptionKey,
      algorithm: algorithm,
    );

    await _messages.add({
      'conversationId': conversationId,
      'senderId': currentUser.uid,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverEmail': normalizedReceiverEmail,
      'receiverName': receiverName,
      'cipherText': payload.cipherText,
      'nonce': payload.nonce,
      'mac': payload.mac,
      'algorithm': payload.algorithm,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _conversations.doc(conversationId).set({
      'participants': [currentUser.uid, receiverId],
      'participantEmails': [senderEmail, normalizedReceiverEmail],
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': 'Message chiffré (${_algoLabel(payload.algorithm)})',
      'type': 'direct',
    }, SetOptions(merge: true));
  }

  Future<String> decryptMessage(
      ChatMessageModel message,
      String key,
      ) async {
    final trimmedKey = key.trim();

    if (trimmedKey.isEmpty) {
      throw Exception("Clé vide");
    }

    try {
      return await CryptoAvance.decryptMessage(
        cipherText: message.cipherText,
        nonce: message.nonce,
        mac: message.mac,
        key: trimmedKey,
        algorithm: message.algorithm.isEmpty ? 'aes-gcm' : message.algorithm,
      );
    } catch (_) {
      throw Exception("Impossible de déchiffrer le message");
    }
  }
}