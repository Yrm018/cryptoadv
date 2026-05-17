const router  = require('express').Router();
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const pool    = require('../db');

const JWT_SECRET  = process.env.JWT_SECRET  || 'cryptoadv_secret_change_me';
const JWT_EXPIRES = process.env.JWT_EXPIRES || '30d';

// ── POST /auth/register ────────────────────────────────────────────────────────
router.post('/register', async (req, res) => {
  const { email, username, firstName, lastName, password, publicKey } = req.body;
  if (!email || !username || !firstName || !lastName || !password)
    return res.status(400).json({ error: 'Champs manquants' });

  try {
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      `INSERT INTO users (email, username, first_name, last_name, password_hash, public_key)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, email, username, first_name, last_name, created_at`,
      [email.toLowerCase(), username.toLowerCase(), firstName, lastName, hash, publicKey || null]
    );
    const user  = rows[0];
    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: JWT_EXPIRES });
    res.status(201).json({ token, user });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email ou username déjà utilisé' });
    console.error(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ── POST /auth/login ───────────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { identifier, password } = req.body;
  if (!identifier || !password)
    return res.status(400).json({ error: 'Champs manquants' });

  try {
    const norm = identifier.trim().toLowerCase();
    const { rows } = await pool.query(
      `SELECT * FROM users WHERE email = $1 OR username = $1 LIMIT 1`,
      [norm]
    );
    if (!rows.length) return res.status(401).json({ error: 'Identifiant ou mot de passe incorrect' });

    const user = rows[0];
    const ok   = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Identifiant ou mot de passe incorrect' });

    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: JWT_EXPIRES });
    const { password_hash, ...safeUser } = user;
    res.json({ token, user: safeUser });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

module.exports = router;
