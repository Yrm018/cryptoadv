require('dotenv').config();
const express   = require('express');
const http      = require('http');
const WebSocket = require('ws');
const cors      = require('cors');
const jwt       = require('jsonwebtoken');
const path      = require('path');

const authRoutes     = require('./routes/auth');
const usersRoutes    = require('./routes/users');

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

// ── API Routes ────────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'ok', ts: new Date() }));
app.use('/auth',     authRoutes);
app.use('/users',    usersRoutes);
// On passe sendTo aux routes messages pour la livraison en temps réel
app.use('/messages', require('./routes/messages')(sendTo));

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
          userId = decoded.id;
          clients.set(userId, ws);
          ws.send(JSON.stringify({ type: 'auth_ok', userId }));
          console.log(`[WS] Connected: ${userId}`);
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
