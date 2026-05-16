require('dotenv').config();
const express   = require('express');
const http      = require('http');
const WebSocket = require('ws');
const cors      = require('cors');
const jwt       = require('jsonwebtoken');
const path      = require('path');

const authRoutes     = require('./routes/auth');
const usersRoutes    = require('./routes/users');
const pool           = require('./db');

const PORT       = process.env.PORT       || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'cryptoadv_secret_change_me';

// ── Express ───────────────────────────────────────────────────────────────────
const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// ── Map userId → WebSocket (déclaré ici pour être partagé avec les routes) ────
const clients = new Map();

function sendTo(userId, payload) {
  const ws = clients.get(String(userId));
  if (ws && ws.readyState === 1 /* OPEN */) {
    ws.send(JSON.stringify(payload));
    return true;
  }
  return false;
}

/// Récupère tous les contacts d'un utilisateur (partenaires de conv + membres de groupe)
async function getContacts(userId) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT
         CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END AS contact_id
       FROM conversations c
       WHERE c.user1_id = $1 OR c.user2_id = $1
       UNION
       SELECT DISTINCT gm2.user_id AS contact_id
       FROM group_members gm1
       JOIN group_members gm2 ON gm1.group_id = gm2.group_id AND gm2.user_id != $1
       WHERE gm1.user_id = $1`,
      [userId]
    );
    return rows.map(r => String(r.contact_id));
  } catch (_) {
    return [];
  }
}

/// Diffuse un événement de présence à tous les contacts en ligne
async function broadcastPresence(userId, type) {
  const contacts = await getContacts(userId);
  for (const cid of contacts) {
    sendTo(cid, { type, userId });
  }
}

// ── API Routes ────────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'ok', ts: new Date() }));

// Retourne quels userIds (parmi ceux passés en query) sont actuellement connectés
app.get('/presence', (req, res) => {
  const ids = (req.query.ids || '').split(',').filter(Boolean);
  const online = ids.filter(id => clients.has(id));
  res.json({ online });
});
app.use('/auth',     authRoutes);
app.use('/users',    usersRoutes);
// On passe sendTo aux routes messages pour la livraison en temps réel
app.use('/messages', require('./routes/messages')(sendTo));
app.use('/groups',   require('./routes/groups')(sendTo));

// ── Servir le Frontend Flutter Web ────────────────────────────────────────────
// On sert les fichiers statiques du dossier "public" (build/web)
app.use(express.static(path.join(__dirname, 'public')));

// Pour toutes les autres routes, on renvoie l'index.html (gestion du routing Flutter SPA)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ── HTTP server ───────────────────────────────────────────────────────────────
const server = http.createServer(app);

// ── WebSocket server ──────────────────────────────────────────────────────────
const wss = new WebSocket.Server({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  let userId = null;

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    switch (msg.type) {
      // ── Auth ────────────────────────────────────────────────────────────────
      case 'auth': {
        try {
          const decoded = jwt.verify(msg.token, JWT_SECRET);
          userId = String(decoded.id);
          clients.set(userId, ws);
          ws.send(JSON.stringify({ type: 'auth_ok', userId }));
          console.log(`[WS] Connected: ${userId}`);
          broadcastPresence(userId, 'user_online');
        } catch {
          ws.send(JSON.stringify({ type: 'auth_error', error: 'Token invalide' }));
          ws.close();
        }
        break;
      }

      // ── Message chat ────────────────────────────────────────────────────────
      case 'message': {
        if (!userId) return;
        const { receiverId, ...payload } = msg;
        sendTo(receiverId, { type: 'message', ...payload, senderId: userId });
        break;
      }

      // ── Signaling WebRTC (appels) ────────────────────────────────────────────
      case 'call_offer':
      case 'call_answer':
      case 'call_ice':
      case 'call_end':
      case 'call_reject': {
        if (!userId) return;
        const target = msg.targetId;
        sendTo(target, { ...msg, senderId: userId });
        break;
      }

      // ── Message groupe (livraison WS directe en backup) ─────────────────────
      case 'group_message': {
        if (!userId) return;
        // La livraison principale passe par REST POST /groups/:id/messages
        // Ce case sert de fallback si le client envoie directement en WS
        const { groupId: gid, ...gpayload } = msg;
        if (gid) sendTo(gid, { type: 'group_message', ...gpayload, senderId: userId });
        break;
      }

      // ── Ping ────────────────────────────────────────────────────────────────
      case 'ping':
        ws.send(JSON.stringify({ type: 'pong' }));
        break;
    }
  });

  ws.on('close', () => {
    if (userId) {
      clients.delete(userId);
      console.log(`[WS] Disconnected: ${userId}`);
      broadcastPresence(userId, 'user_offline');
    }
  });

  ws.on('error', (err) => console.error('[WS] Error:', err.message));
});

// ── Start ─────────────────────────────────────────────────────────────────────
server.listen(PORT, '0.0.0.0', () => {
  console.log(`CryptoAdv server running on port ${PORT}`);
  console.log(`  Web & REST  → http://0.0.0.0:${PORT}`);
  console.log(`  WS          → ws://0.0.0.0:${PORT}/ws`);
});
