const router      = require('express').Router();
const pool        = require('../db');
const requireAuth = require('../middleware/auth');

module.exports = function groupsRouter(sendTo) {

  // ── POST /groups ─────────────────────────────────────────────────────────────
  // Créer un groupe et ajouter les membres initiaux
  router.post('/', requireAuth, async (req, res) => {
    const { name, description, memberIds = [], photoBase64 } = req.body;
    if (!name) return res.status(400).json({ error: 'name manquant' });

    const groupId = `grp_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
    const client  = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `INSERT INTO groups (id, name, description, photo_base64, created_by)
         VALUES ($1, $2, $3, $4, $5::uuid)`,
        [groupId, name, description || null, photoBase64 || null, req.user.id]
      );

      // Ajouter le créateur comme admin
      await client.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2::uuid, 'admin')
         ON CONFLICT (group_id, user_id) DO NOTHING`,
        [groupId, req.user.id]
      );

      // Ajouter les autres membres
      for (const uid of memberIds) {
        if (String(uid) === String(req.user.id)) continue;
        await client.query(
          `INSERT INTO group_members (group_id, user_id, role)
           VALUES ($1, $2::uuid, 'member')
           ON CONFLICT (group_id, user_id) DO NOTHING`,
          [groupId, String(uid)]
        );
      }

      await client.query('COMMIT');

      // Notifier les membres en temps réel
      const allMembers = [req.user.id, ...memberIds.map(String)];
      for (const uid of allMembers) {
        if (String(uid) !== String(req.user.id)) {
          sendTo(String(uid), { type: 'group_created', groupId, name });
        }
      }

      res.status(201).json({ id: groupId, name, description });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    } finally {
      client.release();
    }
  });

  // ── GET /groups ───────────────────────────────────────────────────────────────
  // Liste tous les groupes de l'utilisateur
  router.get('/', requireAuth, async (req, res) => {
    try {
      const { rows } = await pool.query(
        `SELECT g.*,
                gm.role,
                (SELECT COUNT(*) FROM group_members gm2 WHERE gm2.group_id = g.id) AS member_count,
                (SELECT type      FROM group_messages m WHERE m.group_id = g.id ORDER BY m.timestamp DESC LIMIT 1) AS last_type,
                (SELECT timestamp FROM group_messages m WHERE m.group_id = g.id ORDER BY m.timestamp DESC LIMIT 1) AS last_timestamp
         FROM groups g
         JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
         ORDER BY COALESCE(
           (SELECT timestamp FROM group_messages m WHERE m.group_id = g.id ORDER BY m.timestamp DESC LIMIT 1),
           g.created_at
         ) DESC`,
        [req.user.id]
      );
      res.json(rows);
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /groups/:groupId ──────────────────────────────────────────────────────
  router.get('/:groupId', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    try {
      const { rows } = await pool.query(
        `SELECT g.* FROM groups g
         JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
         WHERE g.id = $2`,
        [req.user.id, groupId]
      );
      if (!rows.length) return res.status(403).json({ error: 'Accès refusé' });
      res.json(rows[0]);
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /groups/:groupId/key ──────────────────────────────────────────────────
  router.get('/:groupId/key', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    try {
      const { rows } = await pool.query(
        `SELECT g.aes_key FROM groups g
         JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
         WHERE g.id = $2`,
        [req.user.id, groupId]
      );
      if (!rows.length) return res.status(403).json({ error: 'Accès refusé' });
      res.json({ aes_key: rows[0].aes_key || null });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── PUT /groups/:groupId/key ──────────────────────────────────────────────────
  // First writer wins
  router.put('/:groupId/key', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    const { aes_key } = req.body;
    if (!aes_key) return res.status(400).json({ error: 'aes_key manquant' });
    try {
      // Vérifier l'appartenance
      const { rows: check } = await pool.query(
        `SELECT g.aes_key FROM groups g
         JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
         WHERE g.id = $2`,
        [req.user.id, groupId]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      const { rows } = await pool.query(
        `UPDATE groups SET aes_key = $2
         WHERE id = $1 AND (aes_key IS NULL OR aes_key = '')
         RETURNING aes_key`,
        [groupId, aes_key]
      );

      if (!rows.length) {
        // Clé déjà existante → retourner la clé du serveur
        return res.json({ aes_key: check[0].aes_key, conflict: true });
      }
      res.json({ aes_key: rows[0].aes_key });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /groups/:groupId/members ──────────────────────────────────────────────
  router.get('/:groupId/members', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    try {
      // Vérifier appartenance
      const { rows: check } = await pool.query(
        `SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, req.user.id]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      const { rows } = await pool.query(
        `SELECT u.id, u.username, u.first_name, u.last_name,
                u.email, u.photo_base64, u.public_key,
                gm.role, gm.joined_at
         FROM group_members gm
         JOIN users u ON u.id = gm.user_id
         WHERE gm.group_id = $1
         ORDER BY gm.joined_at ASC`,
        [groupId]
      );
      res.json(rows);
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── POST /groups/:groupId/members ─────────────────────────────────────────────
  // Ajouter un membre (admin seulement)
  router.post('/:groupId/members', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    const { userId }  = req.body;
    if (!userId) return res.status(400).json({ error: 'userId manquant' });
    try {
      // Vérifier que l'appelant est admin
      const { rows: check } = await pool.query(
        `SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, req.user.id]
      );
      if (!check.length || check[0].role !== 'admin')
        return res.status(403).json({ error: 'Admin requis' });

      await pool.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'member') ON CONFLICT DO NOTHING`,
        [groupId, userId]
      );

      // Récupérer le nom du groupe pour notifier le nouvel ajouté
      const { rows: grp } = await pool.query(
        `SELECT name FROM groups WHERE id = $1`, [groupId]
      );
      sendTo(String(userId), { type: 'group_added', groupId, name: grp[0]?.name });

      res.json({ added: true });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── DELETE /groups/:groupId/members/:userId ───────────────────────────────────
  router.delete('/:groupId/members/:userId', requireAuth, async (req, res) => {
    const { groupId, userId } = req.params;
    const isSelf = String(userId) === String(req.user.id);
    try {
      if (!isSelf) {
        // Seul un admin peut exclure quelqu'un d'autre
        const { rows: check } = await pool.query(
          `SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2`,
          [groupId, req.user.id]
        );
        if (!check.length || check[0].role !== 'admin')
          return res.status(403).json({ error: 'Admin requis' });
      }

      await pool.query(
        `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, userId]
      );

      sendTo(String(userId), { type: 'group_removed', groupId });
      res.json({ removed: true });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── GET /groups/:groupId/messages ─────────────────────────────────────────────
  router.get('/:groupId/messages', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    const limit  = parseInt(req.query.limit  || '50');
    const offset = parseInt(req.query.offset || '0');
    try {
      const { rows: check } = await pool.query(
        `SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, req.user.id]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      const { rows } = await pool.query(
        `SELECT gm.*, u.username, u.first_name, u.last_name, u.photo_base64
         FROM group_messages gm
         JOIN users u ON u.id = gm.sender_id
         WHERE gm.group_id = $1
         ORDER BY gm.timestamp ASC
         LIMIT $2 OFFSET $3`,
        [groupId, limit, offset]
      );
      res.json(rows);
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── POST /groups/:groupId/messages ────────────────────────────────────────────
  router.post('/:groupId/messages', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    const { id, cipherText, algorithm, type, fileName, fileSize, iv, mac } = req.body;

    if (!cipherText) return res.status(400).json({ error: 'cipherText manquant' });

    try {
      const { rows: check } = await pool.query(
        `SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, req.user.id]
      );
      if (!check.length) return res.status(403).json({ error: 'Accès refusé' });

      const msgId = id || `gmsg_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
      const { rows } = await pool.query(
        `INSERT INTO group_messages
           (id, group_id, sender_id, cipher_text, algorithm, type,
            file_name, file_size, iv, mac)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (id) DO NOTHING
         RETURNING *`,
        [msgId, groupId, req.user.id, cipherText,
         algorithm || 'aes-gcm', type || 'text',
         fileName || null, fileSize || null, iv || null, mac || null]
      );

      const saved = rows[0];

      // Livrer à tous les membres en ligne (sauf l'expéditeur)
      if (saved) {
        const { rows: members } = await pool.query(
          `SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2`,
          [groupId, req.user.id]
        );
        for (const m of members) {
          sendTo(String(m.user_id), {
            type:       'group_message',
            id:         saved.id,
            groupId,
            senderId:   String(req.user.id),
            cipherText: saved.cipher_text,
            algorithm:  saved.algorithm,
            msgType:    saved.type,
            fileName:   saved.file_name,
            fileSize:   saved.file_size,
            iv:         saved.iv,
            mac:        saved.mac,
            timestamp:  saved.timestamp,
          });
        }
      }

      res.status(201).json(saved || { id: msgId });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── DELETE /groups/:groupId/messages/:msgId ──────────────────────────────────
  // Supprime un message pour tout le monde (expéditeur seulement)
  router.delete('/:groupId/messages/:msgId', requireAuth, async (req, res) => {
    const { groupId, msgId } = req.params;
    try {
      const { rows } = await pool.query(
        `DELETE FROM group_messages
         WHERE id = $1 AND group_id = $2 AND sender_id = $3::uuid
         RETURNING id`,
        [msgId, groupId, req.user.id]
      );
      if (!rows.length) return res.status(403).json({ error: 'Non autorisé' });

      // Notifier tous les membres en ligne
      const { rows: members } = await pool.query(
        `SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2::uuid`,
        [groupId, req.user.id]
      );
      for (const m of members) {
        sendTo(String(m.user_id), {
          type: 'group_message_deleted', messageId: msgId, groupId,
        });
      }

      res.json({ deleted: true });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err);
      res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  // ── DELETE /groups/:groupId ───────────────────────────────────────────────────
  // Supprimer le groupe entier (admin seulement)
  router.delete('/:groupId', requireAuth, async (req, res) => {
    const { groupId } = req.params;
    try {
      const { rows: check } = await pool.query(
        `SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2`,
        [groupId, req.user.id]
      );
      if (!check.length || check[0].role !== 'admin')
        return res.status(403).json({ error: 'Admin requis' });

      // Récupérer les membres avant suppression pour notifier
      const { rows: members } = await pool.query(
        `SELECT user_id FROM group_members WHERE group_id = $1`, [groupId]
      );

      await pool.query(`DELETE FROM group_messages WHERE group_id = $1`, [groupId]);
      await pool.query(`DELETE FROM group_members  WHERE group_id = $1`, [groupId]);
      await pool.query(`DELETE FROM groups          WHERE id = $1`,       [groupId]);

      for (const m of members) {
        if (String(m.user_id) !== String(req.user.id)) {
          sendTo(String(m.user_id), { type: 'group_deleted', groupId });
        }
      }

      res.json({ deleted: true });
    } catch (err) {
      console.error('[GROUPS ERROR]', err.message || err); res.status(500).json({ error: 'Erreur serveur' });
    }
  });

  return router;
};
