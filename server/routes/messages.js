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
                u.public_key,
                (SELECT type      FROM messages m WHERE m.conversation_id = c.id ORDER BY m.timestamp DESC LIMIT 1) AS last_type,
                (SELECT timestamp FROM messages m WHERE m.conversation_id = c.id ORDER BY m.timestamp DESC LIMIT 1) AS last_timestamp
         FROM conversations c
         JOIN users u ON u.id = CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END
         WHERE c.user1_id = $1 OR c.user2_id = $1
         ORDER BY COALESCE(
           (SELECT timestamp FROM messages m WHERE m.conversation_id = c.id ORDER BY m.timestamp DESC LIMIT 1),
           c.created_at
         ) DESC`,
        [req.user.id]
      );
      res.json(rows);
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /messages/conversations/:convId/key ──────────────────────────────────
  // Retourne la clé AES partagée pour cette conversation
  router.get('/conversations/:convId/key', requireAuth, async (req, res) => {
    const { convId } = req.params;
    try {
      const { rows } = await pool.query(
        `SELECT aes_key FROM conversations
         WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)`,
        [convId, String(req.user.id)]
      );
      if (!rows.length) return res.status(403).json({ error: 'Accès refusé' });
      res.json({ aes_key: rows[0].aes_key || null });
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── PUT /messages/conversations/:convId/key ───────────────────────────────────
  // Stocke la clé AES (premier arrivé = gagnant, pour éviter les conflits)
  router.put('/conversations/:convId/key', requireAuth, async (req, res) => {
    const { convId } = req.params;
    const { aes_key } = req.body;
    if (!aes_key) return res.status(400).json({ error: 'aes_key manquant' });
    try {
      // Vérifier l'appartenance
      const { rows: check } = await pool.query(
        `SELECT id, aes_key FROM conversations
         WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)`,
        [convId, String(req.user.id)]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      // Si la conversation n'existe pas encore, on la crée d'abord
      // (cas : clé poussée avant le premier message)
      if (!check[0]) {
        return res.status(404).json({ error: 'Conversation introuvable' });
      }

      // Premier arrivé gagnant : ne mettre à jour que si aes_key est encore NULL
      const { rows } = await pool.query(
        `UPDATE conversations
         SET aes_key = $2
         WHERE id = $1 AND (aes_key IS NULL OR aes_key = '')
         RETURNING aes_key`,
        [convId, aes_key]
      );

      // Si aucune ligne mise à jour → une clé existait déjà, on retourne la clé actuelle
      if (!rows.length) {
        const { rows: current } = await pool.query(
          `SELECT aes_key FROM conversations WHERE id = $1`, [convId]
        );
        return res.json({ aes_key: current[0]?.aes_key, conflict: true });
      }

      res.json({ aes_key: rows[0].aes_key });
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

  // ── PATCH /messages/:conversationId/read ─────────────────────────────────────
  // Marque les messages reçus comme lus et notifie l'expéditeur en WS
  router.patch('/:conversationId/read', requireAuth, async (req, res) => {
    const { conversationId } = req.params;
    try {
      // Vérifier appartenance
      const { rows: check } = await pool.query(
        `SELECT id FROM conversations WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)`,
        [conversationId, req.user.id]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      // Marquer comme lus tous les messages reçus (pas envoyés par moi) non encore lus
      const now = new Date().toISOString();
      const { rows: updated } = await pool.query(
        `UPDATE messages
         SET read_at = NOW()
         WHERE conversation_id = $1
           AND sender_id != $2
           AND read_at IS NULL
         RETURNING sender_id`,
        [conversationId, req.user.id]
      );

      // Notifier chaque expéditeur unique en temps réel
      const senderIds = [...new Set(updated.map(r => String(r.sender_id)))];
      for (const sid of senderIds) {
        sendTo(sid, { type: 'message_read', conversationId, readAt: now });
      }

      res.json({ updated: updated.length, readAt: now });
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── POST /messages ────────────────────────────────────────────────────────────
  router.post('/', requireAuth, async (req, res) => {
    const {
      id, conversationId, receiverId,
      cipherText, mode, algorithm, type,
      fileName, fileSize, encryptedAesKey, iv, mac, signature, aesKey
    } = req.body;

    if (!conversationId || !cipherText || !receiverId)
      return res.status(400).json({ error: 'Champs manquants (conversationId, cipherText, receiverId)' });

    try {
      // Créer la conversation si elle n'existe pas, et stocker la clé AES si fournie.
      // COALESCE garantit que la première clé posée ne sera jamais écrasée (first writer wins).
      const [uid1, uid2] = [String(req.user.id), String(receiverId)].sort();
      await pool.query(
        `INSERT INTO conversations (id, user1_id, user2_id, aes_key)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id) DO UPDATE
           SET aes_key = COALESCE(conversations.aes_key, EXCLUDED.aes_key)`,
        [conversationId, uid1, uid2, aesKey || null]
      );

      const msgId = id || `${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
      const { rows } = await pool.query(
        `INSERT INTO messages
           (id, conversation_id, sender_id, cipher_text, mode, algorithm, type,
            file_name, file_size, encrypted_aes_key, iv, mac, signature)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
         ON CONFLICT (id) DO NOTHING
         RETURNING *`,
        [msgId, conversationId, req.user.id, cipherText,
         mode || 'sym', algorithm || 'AES', type || 'text',
         fileName || null, fileSize || null,
         encryptedAesKey || null, iv || null, mac || null, signature || null]
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
          mac:            saved.mac,
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

  // ── DELETE /messages/conversation/:convId ─────────────────────────────────────
  // Supprime toute la conversation (messages + enregistrement) pour les 2 parties
  router.delete('/conversation/:convId', requireAuth, async (req, res) => {
    const { convId } = req.params;
    try {
      const { rows } = await pool.query(
        `SELECT user1_id, user2_id FROM conversations
         WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)`,
        [convId, String(req.user.id)]
      );
      if (!rows.length) return res.status(403).json({ error: 'Accès refusé' });

      const otherId = rows[0].user1_id === String(req.user.id)
        ? rows[0].user2_id : rows[0].user1_id;

      await pool.query(`DELETE FROM messages     WHERE conversation_id = $1`, [convId]);
      await pool.query(`DELETE FROM conversations WHERE id = $1`, [convId]);

      // Notifier l'autre utilisateur en temps réel
      sendTo(otherId, { type: 'conversation_deleted', conversationId: convId });

      res.json({ deleted: true });
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── DELETE /messages/:id ──────────────────────────────────────────────────────
  // Supprime un message pour tout le monde (expéditeur uniquement)
  router.delete('/:id', requireAuth, async (req, res) => {
    const { id } = req.params;
    try {
      const { rows } = await pool.query(
        `DELETE FROM messages WHERE id = $1 AND sender_id = $2
         RETURNING conversation_id`,
        [id, String(req.user.id)]
      );
      if (!rows.length) return res.status(403).json({ error: 'Non autorisé' });

      const convId = rows[0].conversation_id;
      const { rows: conv } = await pool.query(
        `SELECT user1_id, user2_id FROM conversations WHERE id = $1`, [convId]
      );
      if (conv.length) {
        const otherId = conv[0].user1_id === String(req.user.id)
          ? conv[0].user2_id : conv[0].user1_id;
        sendTo(otherId, { type: 'message_deleted', messageId: id, conversationId: convId });
      }

      res.json({ deleted: true });
    } catch (err) {
      console.error(err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  return router;
};
