const router      = require('express').Router();
const pool        = require('../db');
const requireAuth = require('../middleware/auth');

// ── GET /users/me ──────────────────────────────────────────────────────────────
router.get('/me', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, email, username, first_name, last_name, photo_base64, public_key, created_at
       FROM users WHERE id = $1`,
      [req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Utilisateur introuvable' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err); res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ── GET /users/search?q=… ──────────────────────────────────────────────────────
router.get('/search', requireAuth, async (req, res) => {
  const q = (req.query.q || '').toLowerCase();
  if (!q) return res.json([]);
  try {
    const { rows } = await pool.query(
      `SELECT id, email, username, first_name, last_name, photo_base64, public_key
       FROM users
       WHERE (email ILIKE $1 OR username ILIKE $1) AND id != $2
       LIMIT 20`,
      [`%${q}%`, req.user.id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err); res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ── PATCH /users/me ────────────────────────────────────────────────────────────
router.patch('/me', requireAuth, async (req, res) => {
  const { firstName, lastName, photoBase64, publicKey } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE users SET
         first_name   = COALESCE($1, first_name),
         last_name    = COALESCE($2, last_name),
         photo_base64 = COALESCE($3, photo_base64),
         public_key   = COALESCE($4, public_key)
       WHERE id = $5
       RETURNING id, email, username, first_name, last_name, photo_base64, public_key`,
      [firstName || null, lastName || null, photoBase64 || null, publicKey || null, req.user.id]
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err); res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
