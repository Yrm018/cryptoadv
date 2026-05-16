const router  = require('express').Router();
const pool    = require('../db');
const requireAuth = require('../middleware/auth');

/**
 * messages(sendTo) — factory qui reçoit la fonction sendTo du serveur WS
 * pour pouvoir livrer les messages en temps réel au destinataire.
 */
module.exports = function messagesRouter(sendTo) {

  // ── GET /messages/conversations ──────────────────────────────────────────────
  router.get('/conversations', requireAuth, async (req, res) => {
    try {
      const { rows } = await pool.query(
        `SELECT c.*,
                u.username AS other_username, u.first_name, u.last_name,
                u.photo_base64, u.email AS other_email, u.id AS other_id,
                (SELECT cipher_text FROM messages m
                 WHERE m.conversation_id = c.id
                 ORDER BY m.timestamp DESC LIMIT 1) AS last_cipher
         FROM conversations c
         JOIN users u ON u.id = CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END
         WHERE c.user1_id = $1 OR c.user2_id = $1
         ORDER BY c.created_at DESC`,
        [req.user.id]
      );
      res.json(rows);
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /messages/:conversationId ────────────────────────────────────────────
  router.get('/:conversationId', requireAuth, async (req, res) => {
    const { conversationId } = req.params;
    const limit  = parseInt(req.query.limit  || '50');
    const offset = parseInt(req.query.offset || '0');
    try {
      // Vérifier que l'utilisateur fait partie de la conversation
      const { rows: check } = await pool.query(
        `SELECT id FROM conversations WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)`,
        [conversationId, req.user.id]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      const { rows } = await pool.query(
        `SELECT * FROM messages
         WHERE conversation_id = $1
         ORDER BY timestamp ASC
         LIMIT $2 OFFSET $3`,
        [conversationId, limit, offset]
      );
      res.json(rows);
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── POST /messages ────────────────────────────────────────────────────────────
  router.post('/', requireAuth, async (req, res) => {
    const {
      id, conversationId, receiverId,
      cipherText, mode, algorithm, type,
      fileName, fileSize, encryptedAesKey, iv, signature
    } = req.body;

    if (!conversationId || !cipherText || !receiverId)
      return res.status(400).json({ error: 'Champs manquants (conversationId, cipherText, receiverId)' });

    try {
      // Créer la conversation si elle n'existe pas
      const [uid1, uid2] = [String(req.user.id), String(receiverId)].sort();
      await pool.query(
        `INSERT INTO conversations (id, user1_id, user2_id)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [conversationId, uid1, uid2]
      );

      const msgId = id || `${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
      const { rows } = await pool.query(
        `INSERT INTO messages
           (id, conversation_id, sender_id, cipher_text, mode, algorithm, type,
            file_name, file_size, encrypted_aes_key, iv, signature)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         ON CONFLICT (id) DO NOTHING
         RETURNING *`,
        [msgId, conversationId, req.user.id, cipherText,
         mode || 'sym', algorithm || 'AES', type || 'text',
         fileName || null, fileSize || null,
         encryptedAesKey || null, iv || null, signature || null]
      );

      const saved = rows[0];

      // ── Livraison temps réel si le destinataire est en ligne ────────────────
      if (saved) {
        const delivered = sendTo(String(receiverId), {
          type:           'message',
          id:             saved.id,
          conversationId: saved.conversation_id,
          senderId:       String(req.user.id),
          cipherText:     saved.cipher_text,
          mode:           saved.mode,
          algorithm:      saved.algorithm,
          msgType:        saved.type,
          fileName:       saved.file_name,
          fileSize:       saved.file_size,
          encryptedAesKey: saved.encrypted_aes_key,
          iv:             saved.iv,
          signature:      saved.signature,
          timestamp:      saved.timestamp,
        });
        console.log(`[MSG] ${req.user.id} → ${receiverId} | online: ${delivered}`);
      }

      res.status(201).json(saved || { id: msgId });
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  return router;
};
